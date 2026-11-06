// Records which mapped Bend branches each tape step takes, for the Rust
// trace comparison (sim/rust/check.sh).
//
//   node bend-trace.mjs TRACED_DIR TAPE.jsonl...
//
// TRACED_DIR is the output of `cargo branch-map instrument TRACED_DIR`: the
// Bend tree with br.arm/br.pick around each mapped branch, and labels.json.
// This builds it, makes br.arm record its id and br.pick record the arm it
// takes (and evaluate only that arm, as Rust does), and replays each tape.
// It writes TAPE.jsonl.trace (JSONL; not *.jsonl, which is a tape): first
//   {untraced: [label...]}
// the labels whose ids no longer appear in the built JS (Bend folds a match
// whose arms are all literals, like domain:prize, into a lookup table), then
// one line per tape line:
//   {game, step, start?: counts, request: counts, answer?: counts}
// where counts maps a branch label to the times it was taken in that call.
// Bend evaluates strictly, so a call also counts branches of work whose
// result it discards; Rust skips that work, so Rust's count for a label is at
// most Bend's, not equal to it.
// A traced step whose next state differs from the tape's is an error: the
// instrumentation must not change the machine.
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { build, normalize } from './machine-items-lib.mjs';

const [tracedDir, ...tapes] = process.argv.slice(2);
if (!tracedDir || tapes.length === 0) throw new Error('usage: node bend-trace.mjs TRACED_DIR TAPE.jsonl...');
const labels = JSON.parse(readFileSync(join(tracedDir, 'labels.json'), 'utf8'));

// Rewrites each `$..._br_pick(id, c, t, f)` call to `(__pick(id, c) ? (t) : (f))`.
function lazyPicks(js) {
  const call = /\$\w*br_pick\(/g;
  let out = '', from = 0, found;
  while ((found = call.exec(js))) {
    if (js.slice(Math.max(0, found.index - 9), found.index) === 'function ') continue;
    const args = [];
    let depth = 0, at = found.index + found[0].length, start = at;
    for (; ; at++) {
      const c = js[at];
      if (c === '(' || c === '[' || c === '{') depth++;
      else if (c === ')' && depth === 0) { args.push(js.slice(start, at)); break; }
      else if (c === ')' || c === ']' || c === '}') depth--;
      else if (c === ',' && depth === 0) { args.push(js.slice(start, at)); start = at + 1; }
      else if (c === '"') { at++; while (js[at] !== '"') at += js[at] === '\\' ? 2 : 1; }
    }
    if (args.length !== 4) throw new Error(`br.pick with ${args.length} arguments at ${found.index}`);
    const [id, c, t, f] = args;
    out += `${js.slice(from, found.index)}(__pick(${id}, ${c}) ? (${t}) : (${f}))`;
    from = at + 1;
    call.lastIndex = from;
  }
  return out + js.slice(from);
}

const dir = mkdtempSync(join(tmpdir(), 'bend-trace-'));
let SA, untraced;
try {
  const url = build(dir, 'traced', resolve(tracedDir, 'simple-abstract.bend'));
  const path = new URL(url).pathname;
  let js = readFileSync(path, 'utf8');
  const arms = /function (\$\w*br_arm)\(_id_0, _x_0\) \{\n {2}return _x_0;\n\}/g;
  const armCount = (js.match(arms) ?? []).length;
  js = js.replace(arms, 'function $1(_id_0, _x_0) {\n  __trace.push(_id_0);\n  return _x_0;\n}');
  js = lazyPicks(js);
  if (armCount === 0 || !js.includes('__pick(')) throw new Error('found no br.arm or br.pick to trace');
  const seen = new Set([...js.matchAll(/_br_arm\((\d+),|__pick\((\d+),/g)].map(m => Number(m[1] ?? m[2])));
  untraced = labels.filter((l, id) => !seen.has(id) && !(l.endsWith(':False') && seen.has(labels.indexOf(l.replace(/:False$/, ':True')))));
  js = `const __trace = globalThis.__bendTrace = [];\nconst __pick = (id, c) => (__trace.push(c ? id : -1 - id), c);\n${js}`;
  const traced = join(dir, 'traced-run.mjs');
  writeFileSync(traced, js);
  SA = (await import(pathToFileURL(traced).href)).default;
} finally {
  rmSync(dir, { recursive: true });
}

const N = name => SA[`simple/main:${name}`];
const trace = globalThis.__bendTrace;
const label = id => (id >= 0 ? labels[id] : labels[-1 - id].replace(/:True$/, ':False'));
function counted(run) {
  trace.length = 0;
  const value = run();
  const counts = {};
  for (const id of trace) counts[label(id)] = (counts[label(id)] ?? 0) + 1;
  return [value, counts];
}

for (const tape of tapes) {
  const lines = readFileSync(tape, 'utf8').split('\n').filter(Boolean).map(line => JSON.parse(line));
  const out = [JSON.stringify({ untraced })];
  let differ = 0;
  for (const line of lines) {
    const row = { game: line.game, step: line.step };
    if (line.config) row.start = counted(() => N('start')(line.config))[1];
    row.request = counted(() => N('request')(line.state))[1];
    if (!line.terminal) {
      const [answered, counts] = counted(() => N('answer')(line.state, line.event.n));
      row.answer = counts;
      if (JSON.stringify(normalize(answered.state)) !== JSON.stringify(line.next)) differ++;
    }
    out.push(JSON.stringify(row));
  }
  writeFileSync(`${tape}.trace`, `${out.join('\n')}\n`);
  console.log(`${tape}: ${out.length - 1} lines traced, ${differ} next states differ from the tape; untraced: ${untraced.join(' ') || 'none'}`);
  if (differ > 0) process.exitCode = 1;
}
