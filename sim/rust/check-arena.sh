#!/usr/bin/env bash
# The extended parity check: replays recorded arena matches through Bend and
# the Rust machine. Not part of check.sh, because the arena database is
# private tournament data that never enters the repository.
#   sim/rust/check-arena.sh --db PATH [MATCHES]   (or BUCKSHOT_ARENA_DB=PATH)
# MATCHES (default 12) are taken across tournaments; the check fails unless
# every one is replayed and agrees.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
# Outside Nix, needs cargo (rustup reads rust-toolchain.toml), node, bun and Bend.
if [ -z "${IN_NIX_SHELL:-}" ] && command -v nix >/dev/null; then
  exec nix develop "$root" -c bash "$0" "$@"
fi

db=${BUCKSHOT_ARENA_DB:-}
if [ "${1:-}" = --db ]; then
  db=${2:?--db needs a path}
  shift 2
fi
[ -n "$db" ] || { echo "check-arena.sh: --db PATH or BUCKSHOT_ARENA_DB names the arena database" >&2; exit 2; }
matches=${1:-12}

# The arena tapes replay recorded matches through web/generated/rules.mjs.
(cd "$root/web" && nice -n 10 bun run rules >/dev/null)

tapes=$(mktemp -d /tmp/rust-arena-XXXXXX)
trap 'rm -rf "$tapes"' EXIT
echo "== $matches recorded arena matches -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" --seeds 1 --arena "$matches" --spread --db "$db" --dir "$tapes"

cd "$here"
echo "== tape replay, f64 seats-2-4"
RUST_TAPES="$tapes" nice -n 10 cargo test --release --no-default-features --features f64,seats-2-4 --test tapes \
  -- --include-ignored --nocapture
echo "== arena check passed"
