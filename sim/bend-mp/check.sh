#!/usr/bin/env bash
# Gates for sim/bend-mp. One line per gate, then PASS or FAIL; exits nonzero on
# any failure. Uses $BEND if set, else `bend` on PATH.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEND="${BEND:-bend}"
export BEND

failed=0
report() {
  local status="$1" gate="$2" detail="${3:-}"
  if [[ "$status" == ok ]]; then
    printf 'ok    %s%s\n' "$gate" "${detail:+ ($detail)}"
  else
    printf 'FAIL  %s: %s\n' "$gate" "$detail"
    failed=1
  fi
}

# FUZZ_SKIP switches fuzz properties off (fuzz_mutations.py sets it for its own runs); exported here it would weaken the gates.
if [[ -n "${FUZZ_SKIP:-}" ]]; then
  report fail "FUZZ_SKIP is set" "'$FUZZ_SKIP' would skip fuzz properties in every gate; unset it"
  echo FAIL
  exit 1
fi

bend_files() {
  find "$here" -name '*.bend' -type f
}

# Import lines of the .bend files under the given paths, as "file:line: text".
imports_under() {
  grep -rnHE --include='*.bend' '^[[:space:]]*import[[:space:]]' "$@" || true
}

gate_domain() {
  if ! command -v "$BEND" >/dev/null 2>&1; then
    report fail domain.bend "no bend at '$BEND'"
    return
  fi
  local out
  out="$("$BEND" "$here/domain.bend" --verdict 2>&1)"
  if [[ $? -eq 0 && "$out" == *"ALL PROOFS CHECK"* ]]; then
    report ok domain.bend "ALL PROOFS CHECK"
  else
    report fail domain.bend "$(printf '%s' "$out" | head -20)"
  fi
}

gate_unsafe() {
  local hits
  hits="$(bend_files | xargs grep -nE '@unsafe|def[[:space:]]+[A-Za-z0-9_.]+\?[[:space:]]*\(' 2>/dev/null || true)"
  if [[ -z "$hits" ]]; then
    report ok "no @unsafe or def name?("
  else
    report fail "no @unsafe or def name?(" "$hits"
  fi
}

# gate_imports LABEL only|never PATTERN PATH...: with `only`, every import
# under the paths is Base or a module matching PATTERN (a regex alternation of
# paths); with `never`, no imported path contains PATTERN.
gate_imports() {
  local label="$1" mode="$2" pattern="$3" bad
  shift 3
  if [[ "$mode" == only ]]; then
    bad="$(imports_under "$@" | grep -vE ":[0-9]+:[[:space:]]*import[[:space:]]+(Base|($pattern)[[:space:]]+as[[:space:]]+[A-Za-z0-9_]+)[[:space:]]*\$" || true)"
  else
    bad="$(imports_under "$@" | grep -E "import[[:space:]]+[^[:space:]]*($pattern)" || true)"
  fi
  if [[ -z "$bad" ]]; then
    report ok "$label"
  else
    report fail "$label" "$bad"
  fi
}

gate_driver_smoke() {
  local out
  out="$("$BEND" "$here/test/driver-smoke.bend" 2>&1)"
  if [[ $? -eq 0 && "$(printf '%s\n' "$out" | grep -c ' finished=64 stuck=0 exhausted=0$')" -eq 3 ]]; then
    report ok "driver smoke" "3 table sizes, 0 stuck, 0 exhausted"
  else
    report fail "driver smoke" "$(printf '%s' "$out" | head -20)"
  fi
}

gate_simple_smoke() {
  local out
  out="$("$BEND" "$here/test/simple-smoke.bend" 2>&1)"
  if [[ $? -eq 0 && "$(printf '%s\n' "$out" | grep -c '^simple smoke [234] finished=64 stuck=0 exhausted=0$')" -eq 3 ]]; then
    report ok "simple smoke" "3 table sizes, 0 stuck, 0 exhausted"
  else
    report fail "simple smoke" "$(printf '%s' "$out" | head -20)"
  fi
}

# Each named law must be stated in the laws file.
gate_required_laws() {
  local label="$1" file="$2" missing=() name
  shift 2
  for name in "$@"; do
    if [[ ! -f "$here/$file" ]] || ! grep -qE "^law[[:space:]]+${name}[[:space:]]*:" "$here/$file"; then
      missing+=("$name")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    report ok "$label" "$# required"
  else
    report fail "$label" "missing from $file: ${missing[*]}"
  fi
}

gate_roundtrip() {
  local out
  out="$(bun "$here/test/domain-roundtrip.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "js round trip" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "js round trip" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_core_scenarios() {
  local out
  out="$(bun "$here/test/core-scenarios.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "reference core scenarios" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "reference core scenarios" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_item_scenarios() {
  local out
  out="$(bun "$here/test/item-scenarios.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "reference item scenarios" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "reference item scenarios" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_machine_scenarios() {
  local out
  out="$(bun "$here/test/machine-core.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "machine core scenarios" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "machine core scenarios" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_machine_items() {
  local out
  out="$(bun "$here/test/machine-items.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "machine item scenarios" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "machine item scenarios" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_machine_item_fuzz() {
  local out
  out="$(bun "$here/test/machine-items-fuzz.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "machine item law fuzz" "$(printf '%s' "$out" | tail -1 | cut -c1-200)"
  else
    report fail "machine item law fuzz" "$(printf '%s' "$out" | tail -20 | cut -c1-600)"
  fi
}

gate_simple_fuzz() {
  local out
  out="$(bun "$here/test/simple-fuzz.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "simple machine fuzz" "$(printf '%s' "$out" | tail -1 | cut -c1-200)"
  else
    report fail "simple machine fuzz" "$(printf '%s' "$out" | tail -20 | cut -c1-600)"
  fi
}

gate_player() {
  local out
  out="$(bun "$here/test/player.mjs" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "minimax player properties" "$(printf '%s' "$out" | tail -1 | cut -c1-200)"
  else
    report fail "minimax player properties" "$(printf '%s' "$out" | tail -20 | cut -c1-600)"
  fi
}

gate_fuzz_mutations() {
  local out
  out="$(python3 "$here/tools/fuzz_mutations.py" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "item fuzz mutations" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "item fuzz mutations" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_generated() {
  local out
  out="$(python3 "$here/tools/proof_cases.py" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "generated proof bodies" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "generated proof bodies" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_simple_proofs() {
  local out
  out="$("$BEND" "$here/SIMPLE-PROOF.bend" --verdict 2>&1)"
  if [[ $? -eq 0 && "$out" == *"ALL PROOFS CHECK"* && "$out" != *"SOME PROOFS FAIL"* ]]; then
    report ok "SIMPLE-PROOF.bend" "ALL PROOFS CHECK"
  else
    report fail "SIMPLE-PROOF.bend" "$(printf '%s' "$out" | head -20)"
  fi
}

gate_proofs() {
  local out
  out="$("$BEND" "$here/PROOF.bend" --verdict 2>&1)"
  if [[ $? -eq 0 && "$out" == *"ALL PROOFS CHECK"* && "$out" != *"SOME PROOFS FAIL"* ]]; then
    report ok "PROOF.bend" "ALL PROOFS CHECK"
  else
    report fail "PROOF.bend" "$(printf '%s' "$out" | head -20)"
  fi
}

gate_mutations() {
  local out
  out="$(python3 "$here/mutate.py" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "machine mutations" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "machine mutations" "$(printf '%s' "$out" | tail -20)"
  fi
}

gate_simple_mutations() {
  local out
  out="$(python3 "$here/tools/simple_mutations.py" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "simple mutations" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "simple mutations" "$(printf '%s' "$out" | tail -20)"
  fi
}

# The Rust mirror of the rules (sim/rust) must agree with Bend: a Bend change
# that the Rust port does not follow fails here (branch map hash, tapes, traces).
gate_rust() {
  local out
  out="$(bash "$here/../rust/check.sh" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "rust parity gate" "$(printf '%s' "$out" | grep -E 'Bend steps|branch trace' | tail -2 | tr '\n' ' ' | cut -c1-200)"
  else
    report fail "rust parity gate" "$(printf '%s' "$out" | tail -20 | cut -c1-600)"
  fi
}

gate_domain
gate_unsafe
gate_imports "ai/ imports only Base and domain" only '\.\./domain\.bend' "$here/ai"
gate_imports "sm/ imports only Base, domain and siblings" only '\.\./domain\.bend|\./[A-Za-z0-9_-]+\.bend' "$here/sm"
gate_imports "simple/ imports only Base, domain, sm's state, rules and items, and siblings" only '\.\./domain\.bend|\.\./sm/(state|rules|items)\.bend|\./[A-Za-z0-9_-]+\.bend' "$here/simple"
gate_imports "player/ imports only Base, domain, sm's state, rules and items, simple/ and siblings" only '\.\./domain\.bend|\.\./sm/(state|rules|items)\.bend|\.\./simple/[A-Za-z0-9_-]+\.bend|\./[A-Za-z0-9_-]+\.bend' "$here/player"
gate_imports "driver, view and the JS entries never import ref/ or abstract" never 'ref/|abstract\.bend' "$here/driver.bend" "$here/web.bend" "$here/analysis.bend" "$here/view.bend"
gate_imports "LAWS.bend never imports ref/" never 'ref/' "$here/LAWS.bend"
gate_imports "SIMPLE-LAWS.bend never imports ref/" never 'ref/' "$here/SIMPLE-LAWS.bend"
gate_driver_smoke
gate_simple_smoke
gate_required_laws "required laws" LAWS.bend step_matches run_matches reachable_valid start_matches games_match state_roundtrip jam_skip_once turn_traversal observe_matches legal_exact legal_accepted privacy
gate_required_laws "required simple laws" SIMPLE-LAWS.bend simple_start simple_refines simple_roundtrip simple_valid simple_reachable_valid simple_run_refines simple_observe simple_privacy simple_complete
gate_generated
gate_proofs
gate_simple_proofs
gate_roundtrip
gate_core_scenarios
gate_item_scenarios
gate_machine_scenarios
gate_machine_items
gate_machine_item_fuzz
gate_simple_fuzz
gate_player
gate_mutations
gate_fuzz_mutations
gate_simple_mutations
gate_rust

if [[ $failed -eq 0 ]]; then
  echo PASS
else
  echo FAIL
  exit 1
fi
