import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

export const list = xs => xs.reduceRight((tail, head) => ({ $: 'Con', head, tail }), { $: 'Nil' });
export const array = xs => { const out = []; for (; xs.$ === 'Con'; xs = xs.tail) out.push(xs.head); return out; };
export const bool = value => Boolean(value);
export function load() {
  const dir = mkdtempSync(join(tmpdir(), 'backshot-'));
  const file = join(dir, 'search.mjs');
  const build = spawnSync(process.env.BEND ?? 'bend', [new URL('./search.bend', import.meta.url).pathname, '-o', file], { encoding: 'utf8' });
  if (build.status !== 0) { rmSync(dir, { recursive: true, force: true }); throw Error(build.stdout + build.stderr); }
  return import(file).then(({ default: lib }) => ({ lib, close: () => rmSync(dir, { recursive: true, force: true }) }));
}
const itemCodes = { a: 2, b: 3, f: 4, c: 5, e: 6, h: 7, s: 8, i: 9, m: 10 };
export const items = text => list([...text.toLowerCase()].flatMap(c => c in itemCodes ? [itemCodes[c]] : []));
export function position(lib, input, fixed) {
  const n = (key, fallback) => input[key] ?? fallback;
  const shells = { unknown: 0, live: 1, blank: 2 };
  const shellName = input.shell ?? 'unknown';
  if (typeof shellName !== 'string' || !Object.hasOwn(shells, shellName)) throw Error('shell must be unknown, live or blank');
  const shell = shells[shellName];
  const flag = (key, fallback) => {
    const value = input[key] ?? fallback;
    if (typeof value !== 'boolean') throw Error(`${key} must be true or false`);
    return value;
  };
  for (const key of ['maxHealth', 'dealerHp', 'playerHp', 'live', 'blank', 'cuffs']) {
    if (key in input && (!Number.isSafeInteger(input[key]) || input[key] < 0)) throw Error(`${key} must be a nonnegative safe integer`);
  }
  if (fixed && (n('live', 1) + n('blank', 1) > 8 || n('cuffs', 0) > 2 ||
    shell === 1 && n('live', 1) === 0 || shell === 2 && n('blank', 1) === 0)) throw Error('inconsistent shell counts or cuffs');
  return lib['state:initial'](bool(fixed), flag('playerTurn', true), n('maxHealth', 3), n('dealerHp', 3), n('playerHp', 3), n('live', 1), n('blank', 1), shell, n('cuffs', 0), flag('sawed', false), items(input.dealerItems ?? ''), items(input.playerItems ?? ''));
}
export function plain(lib, result) {
  if (result.$ === 'Fail') return { error: result.error };
  const a = result.value;
  return { move: a.move.$ === 'None' ? null : lib['model:move.name'](a.move.value), value: lib['rational:show'](a.value), path: array(a.path).map(lib['model:move.name']), nodes: Number(a.nodes) };
}
