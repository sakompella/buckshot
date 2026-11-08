# Every valid feature set of the workspace, for clippy and the tests (sourced by
# check.sh and .githooks/pre-commit). Never --all-features: buckshot-search's
# `f64` (default) and `f32` exclude each other, and buckshot-rules' `trace`
# changes what `branch!` expands to.
feature_sets=(
  ""
  "--features buckshot-rules/trace"
  "--no-default-features --features f32"
  "--no-default-features --features f32,buckshot-rules/trace"
)
