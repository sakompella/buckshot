#!/usr/bin/env bash
# Gates for sim/bend-mp. One line per gate, then PASS or FAIL; exits nonzero on
# any failure. Uses $BEND if set, else `bend` on PATH.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEND="${BEND:-bend}"
export BEND

required_laws=(step_matches run_matches start_matches state_roundtrip jam_skip_once turn_traversal observe_matches legal_exact legal_accepted privacy)

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

bend_files() {
  find "$here" -name '*.bend' -type f
}

# Import lines of the .bend files under a path, as "file: line". Empty when the
# path does not exist yet.
imports_under() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  grep -rnE --include='*.bend' '^[[:space:]]*import[[:space:]]' "$path" || true
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

gate_ai_imports() {
  local bad
  bad="$(imports_under "$here/ai" | grep -vE ':[0-9]+:[[:space:]]*import[[:space:]]+(Base|\.\./domain\.bend[[:space:]]+as[[:space:]]+[A-Za-z0-9_]+)[[:space:]]*$' || true)"
  if [[ -z "$bad" ]]; then
    report ok "ai/ imports only Base and domain"
  else
    report fail "ai/ imports only Base and domain" "$bad"
  fi
}

gate_sm_imports() {
  local bad
  bad="$(imports_under "$here/sm" | grep -vE ':[0-9]+:[[:space:]]*import[[:space:]]+(Base|(\.\./domain\.bend|\./[A-Za-z0-9_-]+\.bend)[[:space:]]+as[[:space:]]+[A-Za-z0-9_]+)[[:space:]]*$' || true)"
  if [[ -z "$bad" ]]; then
    report ok "sm/ imports only Base, domain and siblings"
  else
    report fail "sm/ imports only Base, domain and siblings" "$bad"
  fi
}

gate_driver_imports() {
  local bad
  bad="$(imports_under "$here/driver.bend" | grep -E 'import[[:space:]]+[^[:space:]]*(ref/|abstract\.bend)' || true)"
  if [[ -z "$bad" ]]; then
    report ok "driver never imports ref/ or abstract"
  else
    report fail "driver never imports ref/ or abstract" "$bad"
  fi
}

gate_driver_smoke() {
  local out
  out="$("$BEND" "$here/test/driver-smoke.bend" 2>&1)"
  if [[ $? -eq 0 && "$(printf '%s\n' "$out" | grep -c ' played=64 stuck=0 exhausted=0$')" -eq 3 ]]; then
    report ok "driver smoke" "3 table sizes, 0 stuck, 0 exhausted"
  else
    report fail "driver smoke" "$(printf '%s' "$out" | head -20)"
  fi
}

gate_laws() {
  local laws="$here/LAWS.bend" missing=() name
  for name in ${required_laws[@]+"${required_laws[@]}"}; do
    if [[ ! -f "$laws" ]] || ! grep -qE "^law[[:space:]]+${name}[[:space:]]*:" "$laws"; then
      missing+=("$name")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    report ok "required laws" "${#required_laws[@]} required"
  else
    report fail "required laws" "missing from LAWS.bend: ${missing[*]}"
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

gate_ref_api() {
  local out
  out="$(python3 "$here/tools/ref_api.py" 2>&1)"
  if [[ $? -eq 0 ]]; then
    report ok "generated reference API" "$(printf '%s' "$out" | tail -1)"
  else
    report fail "generated reference API" "$(printf '%s' "$out" | tail -20)"
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

gate_domain
gate_unsafe
gate_ai_imports
gate_sm_imports
gate_driver_imports
gate_driver_smoke
gate_laws
gate_generated
gate_ref_api
gate_proofs
gate_roundtrip
gate_core_scenarios
gate_item_scenarios
gate_machine_scenarios
gate_machine_items
gate_machine_item_fuzz
gate_mutations
gate_fuzz_mutations

if [[ $failed -eq 0 ]]; then
  echo PASS
else
  echo FAIL
  exit 1
fi
