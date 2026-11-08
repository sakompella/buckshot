# Every valid feature set of the workspace, for clippy and the tests (sourced by
# check.sh and .githooks/pre-commit): arithmetic by tables by trace. Never
# --all-features: `f64` (default) and `f32` exclude each other, as do
# `seats-2-4` (default) and `seats-2`, and buckshot-rules' `trace` changes what
# `branch!` expands to.
feature_sets=()
for arithmetic in f64 f32; do
  for seats in seats-2-4 seats-2; do
    for trace in "" ",buckshot-rules/trace"; do
      feature_sets+=("--no-default-features --features $arithmetic,$seats$trace")
    done
  done
done
