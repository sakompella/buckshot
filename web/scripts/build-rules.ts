import { existsSync } from "node:fs";

// Builds the Bend JS entry for the UI into generated/rules.mjs.
// Bend comes from $BEND, else `bend` on PATH, else the pinned Nix store build.

const PINNED_BEND = "/nix/store/szxlh9bw7pb8jp7gp8biw6j84r0fc2i3-bend-2.0.36/bin/bend";

const source = new URL("../../sim/bend-mp/web.bend", import.meta.url).pathname;

const output = new URL("../generated/rules.mjs", import.meta.url).pathname;

const bend = process.env["BEND"] ?? Bun.which("bend") ?? (existsSync(PINNED_BEND) ? PINNED_BEND : undefined);

if (bend === undefined) {
  console.error("bend not found: set BEND to a Bend 2.0.36 binary");
  process.exit(1);
}

const build = Bun.spawnSync([bend, source, "-o", output], { stdout: "inherit", stderr: "inherit" });

process.exit(build.exitCode);
