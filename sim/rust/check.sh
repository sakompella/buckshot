#!/usr/bin/env bash
# The parity gate for sim/rust: Rust must agree with Bend (Bend wins any disagreement).
# Plays fresh Bend tapes with fixed seeds, then runs fmt, clippy and the tests,
# including the tape replay. Any failure fails the script.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
if [ -z "${IN_NIX_SHELL:-}" ]; then
  exec nix develop "$root" -c bash "$0" "$@"
fi

tapes=$(mktemp -d /tmp/rust-parity-XXXXXX)
echo "== Bend tapes -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" \
  --seeds 1,2 --random 12 --items 8 --wild 8 --edge 2 --arena 12 --spread --dir "$tapes"

cd "$here"
echo "== cargo fmt --check"
cargo fmt --check
echo "== cargo clippy"
cargo clippy --all-targets --all-features -- -D warnings

# BRANCH-MAP CHECK: add the branch-map step here (it must fail this script on any failure).

echo "== cargo test --release (tape replay against $tapes)"
RUST_TAPES="$tapes" nice -n 10 cargo test --release -- --include-ignored --nocapture
rm -rf "$tapes"
echo "== parity gate passed"
