#!/usr/bin/env bash
# The pre-commit checks for the Rust workspace, one per hook in
# sim/rust/pre-commit-config.json:
#   bash sim/rust/hooks.sh fmt|clippy|check|branch-map
# Plain cargo (rustup reads rust-toolchain.toml). Where Nix is installed and
# this is not already the dev shell, the check runs in the dev shell.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
if [ -z "${IN_NIX_SHELL:-}" ] && command -v nix >/dev/null; then
  exec nix develop "$here/../.." -c bash "$0" "$@"
fi

cd "$here"
case ${1:-} in
  fmt) cargo fmt --all --check ;;
  clippy)
    # shellcheck source=features.sh
    source features.sh
    for features in "${feature_sets[@]}"; do
      echo "cargo clippy $features"
      # shellcheck disable=SC2086
      nice -n 10 cargo clippy --workspace --all-targets $features -- -D warnings
    done
    ;;
  # The clippy sets name every feature; this checks the defaults name one of them.
  check) nice -n 10 cargo check --workspace --all-targets ;;
  branch-map) nice -n 10 cargo branch-map check ;;
  *) echo "usage: hooks.sh fmt|clippy|check|branch-map" >&2; exit 2 ;;
esac
