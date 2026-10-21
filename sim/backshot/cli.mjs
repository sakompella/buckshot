#!/usr/bin/env bun
import { load, position, plain, bool } from './runtime.mjs';

// One JSON position on stdin, one JSON result per depth on stdout.
const fixed = !process.argv.includes('--reference');
const depthArg = process.argv.find(a => a.startsWith('--depth='));
const depth = depthArg ? Number(depthArg.slice(8)) : 18;
if (!Number.isSafeInteger(depth) || depth < 0) throw Error('depth must be a nonnegative integer');
const input = JSON.parse(await Bun.stdin.text());
const { lib, close } = await load();
try {
  const state = position(lib, input, fixed);
  for (const d of depthArg ? [depth] : Array.from({ length: depth }, (_, i) => i + 1)) {
    const result = plain(lib, lib.search(bool(fixed), BigInt(d), state));
    console.log(JSON.stringify({ depth: d, ...result }));
  }
} finally { close(); }
