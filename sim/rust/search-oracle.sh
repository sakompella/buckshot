#!/usr/bin/env bash
# Writes the search oracle: synthetic decisions with the current Bend player's
# analyses (web/scripts/rust-search-synth.ts), the files search/tests/oracle.rs
# and search/tests/pruning.rs read from RUST_SEARCH_ORACLE. Fixed seeds, no
# recorded games. Used by check.sh and mutants.sh.
#   bash sim/rust/search-oracle.sh DIR [TABLES]
# TABLES is the synth script's --tables (default 2,3,4). With 2 alone, for the
# seats-2 build, the static, memo and budget files play three times the games,
# so they keep their size; the sampled files are two-seat only either way.
set -euo pipefail

dir=$1
tables=${2:-2,3,4}
here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
scale=1
[ "$tables" = 2 ] && scale=3

mkdir -p "$dir"
cd "$root/web"
nice -n 10 bun run rules >/dev/null
synth() {
  local name=$1 games=$2
  shift 2
  nice -n 10 bun scripts/rust-search-synth.ts --out "$dir/$name" --tables "$tables" --games "$games" "$@"
}
synth static.jsonl $((2 * scale)) --per-game 3 --seed 1
synth sampled.jsonl 3 --per-game 3 --seed 2 --reload sampled --samples 32
synth memo.jsonl $((2 * scale)) --per-game 3 --seed 3 --memo charged
synth sampled-memo.jsonl 4 --per-game 3 --seed 4 --reload sampled --samples 32 --memo charged
synth budget.jsonl $((2 * scale)) --per-game 3 --seed 5 --budget 300
