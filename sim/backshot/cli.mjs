#!/usr/bin/env bun
import { load, position, plain, bool } from './runtime.mjs';

// One JSON position on stdin, one JSON result per depth on stdout.
const args = process.argv.slice(2);
const unknown = args.filter(a => a !== '--reference' && !/^--depth=\d+$/.test(a));
if (unknown.length > 0) throw Error(`unknown or malformed arguments: ${unknown.join(' ')}`);
const fixed = !args.includes('--reference');
const depthArg = args.find(a => a.startsWith('--depth='));
const depth = depthArg ? Number(depthArg.slice(8)) : 18;
if (!Number.isSafeInteger(depth)) throw Error('depth must be a nonnegative safe integer');
const input = JSON.parse(await Bun.stdin.text());
const { lib, close } = await load();
try {
  const state = position(lib, input, fixed);
  for (const d of depthArg ? [depth] : Array.from({ length: depth }, (_, i) => i + 1)) {
    const result = plain(lib, lib.search(bool(fixed), d, state));
    console.log(JSON.stringify({ depth: d, ...result }));
  }
} finally { close(); }
