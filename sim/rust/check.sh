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

# The arena tapes replay recorded matches through web/generated/rules.mjs.
echo "== web rules build"
(cd "$root/web" && nice -n 10 bun run rules >/dev/null)

tapes=$(mktemp -d /tmp/rust-parity-XXXXXX)
echo "== Bend tapes -> $tapes"
nice -n 10 node "$root/sim/bend-mp/test/rust-tapes.mjs" \
  --seeds 1,2 --random 12 --items 8 --wild 8 --edge 2 --arena 12 --spread --perturb 150 --dir "$tapes"

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

# Each table build replays the tapes; seats-2 skips the wider tables' games.
# CI=true makes the Hegel properties deterministic and keeps them off .hegel/.
for seats in seats-2-4 seats-2; do
  echo "== cargo test --release, f64 $seats (tape replay against $tapes)"
  CI=true RUST_TAPES="$tapes" nice -n 10 cargo test --release --no-default-features --features "f64,$seats" \
    -- --include-ignored --nocapture
  echo "== cargo test --release, f32 $seats"
  nice -n 10 cargo test --release --no-default-features --features "f32,$seats" -p buckshot-search
  echo "== cargo trace-test, $seats (tape replay with the branch trace comparison)"
  RUST_TAPES="$tapes" nice -n 10 cargo trace-test --no-default-features --features "f64,$seats" \
    -- --include-ignored --nocapture
done
rm -rf "$tapes"
echo "== parity gate passed"
