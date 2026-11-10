# shellcheck shell=bash
# Sourced by check.sh, check-arena.sh and mutants.sh: `trap 'keep DIR REPRODUCE' EXIT`. On success the generated
# inputs in DIR go; on a failure they stay, as the dump that reproduces it, and REPRODUCE says how.
keep() {
  local status=$?
  if [ "$status" -eq 0 ]; then
    rm -rf "$1"
  else
    echo "== FAILED; its Bend inputs are kept in $1. Reproduce a failing test from sim/rust with" >&2
    echo "   $2" >&2
  fi
}
