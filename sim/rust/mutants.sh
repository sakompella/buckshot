#!/usr/bin/env bash
# Mutation testing for sim/rust with cargo-mutants (settings in .cargo/mutants.toml).
# Too slow for check.sh or the pre-commit hook (see AGENTS.md for the chunks).
# Writes the oracles once: a small fixed set of Bend tapes (RUST_TAPES) and
# synthetic decisions with the Bend player's analyses (RUST_SEARCH_ORACLE, from
# search-oracle.sh, read by search/tests/oracle.rs and pruning.rs). Then runs cargo mutants with any
# extra arguments, for example:
#   bash sim/rust/mutants.sh --package buckshot-rules --file rules/src/items.rs
#   bash sim/rust/mutants.sh --package buckshot-search --no-default-features --features f32,seats-2-4 --shard 0/2
# Results land in sim/rust/mutants.out/ (gitignored). Fails when a mutant survives.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
# Outside Nix, needs cargo (rustup reads rust-toolchain.toml), node, bun and Bend.
if [ -z "${IN_NIX_SHELL:-}" ] && command -v nix >/dev/null; then
  exec nix develop "$root" -c bash "$0" "$@"
fi

tapes=$(mktemp -d /tmp/rust-mutants-XXXXXX)
trap 'rm -rf "$tapes"' EXIT
echo "== Bend tapes -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" \
  --seeds 1 --random 4 --items 3 --wild 3 --edge 1 --perturb 40 --dir "$tapes"
echo "== Bend player analyses -> $tapes/search"
bash "$here/search-oracle.sh" "$tapes/search"

cd "$here"
# CI=true makes the Hegel properties deterministic and keeps them off .hegel/.
CI=true RUST_TAPES="$tapes" RUST_SEARCH_ORACLE="$tapes/search" nice -n 10 cargo mutants --jobs "${MUTANTS_JOBS:-3}" "$@"
