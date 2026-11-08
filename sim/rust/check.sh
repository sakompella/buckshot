#!/usr/bin/env bash
# The parity gate for sim/rust: Rust must agree with Bend (Bend wins any disagreement).
# Plays fresh Bend tapes and synthetic Bend player analyses with fixed seeds,
# then runs fmt, clippy and the tests, including the tape replay and the search
# oracle. Needs no recorded games; check-arena.sh replays those. Any failure
# fails the script.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
# Outside Nix, needs cargo (rustup reads rust-toolchain.toml), node, bun and Bend.
if [ -z "${IN_NIX_SHELL:-}" ] && command -v nix >/dev/null; then
  exec nix develop "$root" -c bash "$0" "$@"
fi

tapes=$(mktemp -d -t rust-parity-XXXXXX)
trap 'rm -rf "$tapes"' EXIT
echo "== Bend tapes -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" \
  --seeds 1,2 --random 12 --items 8 --wild 8 --edge 2 --perturb 150 --dir "$tapes"
echo "== Bend player analyses -> $tapes/search, $tapes/search-2"
bash "$here/search-oracle.sh" "$tapes/search"
bash "$here/search-oracle.sh" "$tapes/search-2" 2

cd "$here"
echo "== cargo fmt --check"
cargo fmt --check
# shellcheck source=features.sh
source "$here/features.sh"
for features in "${feature_sets[@]}"; do
  echo "== cargo clippy $features"
  # shellcheck disable=SC2086
  cargo clippy --workspace --all-targets $features -- -D warnings
done

echo "== cargo branch-map check"
cargo branch-map check

echo "== Bend branch traces"
cargo branch-map instrument "$tapes/traced"
nice -n 10 node "$root/sim/bend-mp/test/bend-trace.mjs" "$tapes/traced" "$tapes"/*.jsonl

# Each table build replays the tapes; seats-2 skips the wider tables' games and
# reads the two-seat search oracle. The ignored tests are the ones that need
# RUST_TAPES or RUST_SEARCH_ORACLE, so every run includes them.
# CI=true makes the Hegel properties deterministic and keeps them off .hegel/.
for seats in seats-2-4 seats-2; do
  oracle="$tapes/search"
  [ "$seats" = seats-2 ] && oracle="$tapes/search-2"
  echo "== cargo test --release, f64 $seats (tape replay against $tapes, search oracle $oracle)"
  CI=true RUST_TAPES="$tapes" RUST_SEARCH_ORACLE="$oracle" nice -n 10 cargo test --release --no-default-features --features "f64,$seats" \
    -- --include-ignored --nocapture
  echo "== cargo test --release, f32 $seats (search oracle $oracle)"
  RUST_SEARCH_ORACLE="$oracle" nice -n 10 cargo test --release --no-default-features --features "f32,$seats" -p buckshot-search \
    -- --include-ignored --nocapture
  echo "== cargo trace-test, $seats (tape replay with the branch trace comparison)"
  RUST_TAPES="$tapes" nice -n 10 cargo trace-test --no-default-features --features "f64,$seats" \
    -- --include-ignored --nocapture
done
echo "== parity gate passed"
