#!/usr/bin/env bash
# Mutation testing for sim/rust with cargo-mutants (settings in .cargo/mutants.toml).
# Too slow for check.sh or the pre-commit hook (see AGENTS.md for the chunks).
# Writes the oracles once: a small fixed set of Bend tapes (RUST_TAPES) and
# synthetic decisions with the Bend player's analyses (RUST_SEARCH_ORACLE, read
# by the f32 build's search/tests/oracle.rs). Then runs cargo mutants with any
# extra arguments, for example:
#   bash sim/rust/mutants.sh --package buckshot-rules --file rules/src/items.rs
#   bash sim/rust/mutants.sh --package buckshot-search --no-default-features --features f32 --shard 0/2
# Results land in sim/rust/mutants.out/ (gitignored). Fails when a mutant survives.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
if [ -z "${IN_NIX_SHELL:-}" ]; then
  exec nix develop "$root" -c bash "$0" "$@"
fi

tapes=$(mktemp -d /tmp/rust-mutants-XXXXXX)
trap 'rm -rf "$tapes"' EXIT
echo "== Bend tapes -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" \
  --seeds 1 --random 4 --items 3 --wild 3 --edge 1 --perturb 40 --dir "$tapes"
echo "== Bend player analyses -> $tapes/search"
mkdir "$tapes/search"
(cd "$root/web" && nice -n 10 bun run rules >/dev/null &&
  nice -n 10 bun scripts/rust-search-synth.ts --out "$tapes/search/static.jsonl" --games 2 --per-game 3 --seed 1 &&
  nice -n 10 bun scripts/rust-search-synth.ts --out "$tapes/search/sampled.jsonl" --games 3 --per-game 3 --seed 2 \
    --reload sampled --samples 32)

cd "$here"
# CI=true makes the Hegel properties deterministic and keeps them off .hegel/.
CI=true RUST_TAPES="$tapes" RUST_SEARCH_ORACLE="$tapes/search" nice -n 10 cargo mutants --jobs "${MUTANTS_JOBS:-3}" "$@"
