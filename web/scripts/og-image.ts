import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { inflateSync } from "node:zlib";

import { Effect } from "effect";

import { decodeFindingsData } from "../src/findings/data.ts";
import { ogCard } from "../src/findings/og.ts";
import { runMain, ScriptError } from "../src/script.ts";

// Writes web/online/og.png, the card a shared link shows, from web/online/data with resvg (in `nix develop`) and the
// page's own fonts. The PNG is committed: it holds only numbers the post states.

const ONLINE = join(import.meta.dir, "../online");

const FONTS = ["ebg-600", "cousine-700"];

const read = (name: string): string => readFileSync(join(ONLINE, "data", `${name}.json`), "utf8");

/** The WOFF 1.0 font at `path` as the TrueType file it wraps, since resvg reads only the latter: each table inflated and laid out again. */
const sfntOf = (path: string): Buffer => {
  const woff = readFileSync(path);
  const count = woff.readUInt16BE(12);

  const tables = Array.from({ length: count }, (_, index) => {
    const at = 44 + index * 20;
    const [offset, packed, length] = [woff.readUInt32BE(at + 4), woff.readUInt32BE(at + 8), woff.readUInt32BE(at + 12)];
    const raw = woff.subarray(offset, offset + packed);

    return { tag: woff.readUInt32BE(at), checksum: woff.readUInt32BE(at + 16), data: packed < length ? inflateSync(raw) : raw };
  });

  const power = 2 ** Math.floor(Math.log2(count));
  const header = Buffer.alloc(12 + count * 16);
  let offset = header.length;

  header.writeUInt32BE(woff.readUInt32BE(4), 0);
  header.writeUInt16BE(count, 4);
  header.writeUInt16BE(power * 16, 6);
  header.writeUInt16BE(Math.log2(power), 8);
  header.writeUInt16BE((count - power) * 16, 10);

  const bodies = tables.flatMap(({ tag, checksum, data }, index) => {
    const at = 12 + index * 16;
    const padding = Buffer.alloc((4 - (data.length % 4)) % 4);

    header.writeUInt32BE(tag, at);
    header.writeUInt32BE(checksum, at + 4);
    header.writeUInt32BE(offset, at + 8);
    header.writeUInt32BE(data.length, at + 12);
    offset += data.length + padding.length;

    return [data, padding];
  });

  return Buffer.concat([header, ...bodies]);
};

const program = Effect.gen(function* () {
  const resvg = Bun.which("resvg");

  if (resvg === null) { return yield* ScriptError.make({ message: "resvg not found: run inside `nix develop`", exitCode: 1 }); }

  const { findings } = yield* Effect.try({ try: () => decodeFindingsData(read("summary"), read("findings")), catch: (cause) => ScriptError.make({ message: `web/online/data does not decode: ${String(cause)}`, exitCode: 1 }) });
  const dir = mkdtempSync(join(tmpdir(), "og-"));
  const svg = join(dir, "og.svg");

  const fonts = FONTS.flatMap((name) => {
    const path = join(dir, `${name}.ttf`);

    writeFileSync(path, sfntOf(join(ONLINE, "fonts", `${name}.woff`)));

    return ["--use-font-file", path];
  });

  writeFileSync(svg, ogCard(findings));

  const run = Bun.spawnSync([resvg, ...fonts, svg, join(ONLINE, "og.png")], { stdout: "inherit", stderr: "inherit" });

  return run.exitCode === 0 ? 0 : yield* ScriptError.make({ message: `resvg exited ${String(run.exitCode)}`, exitCode: 1 });
});

await runMain(program);
