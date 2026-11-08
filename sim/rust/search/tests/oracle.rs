//! The compatibility evaluator against Bend's player: every row of
//! `RUST_SEARCH_ORACLE` (written by `web/scripts/rust-search-synth.ts`, whose
//! `js` field is the Bend player's analysis) must come out of the CLI with the
//! same best move, node count and line values. The f32 build only; run by
//! `sim/rust/mutants.sh`.
#![cfg(feature = "f32")]

use std::process::Command;

use serde_json::Value;

/// The fields Bend's analysis and the CLI's row share.
fn shared(row: &Value) -> Value {
    let lines: Vec<Value> = row["lines"]
        .as_array()
        .map(|lines| lines.iter().map(|line| serde_json::json!([line["score"], line["reach"]])).collect())
        .unwrap_or_default();
    serde_json::json!({
        "best": row["best"],
        "nodes": row["nodes"],
        "depth": row["depth"],
        "limited": row["limited"],
        "lines": lines,
    })
}

#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run sim/rust/mutants.sh"]
fn compat_matches_bend() {
    let path = std::env::var("RUST_SEARCH_ORACLE").expect("RUST_SEARCH_ORACLE names a rust-search-synth.ts file");
    let text = std::fs::read_to_string(&path).expect("a readable oracle file");
    let want: Vec<Value> = text.lines().map(|line| serde_json::from_str(line).expect("a JSON row")).collect();
    let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(["--threads", "2", &path])
        .output()
        .expect("the CLI runs");
    assert!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
    let got: Vec<Value> = String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(|line| serde_json::from_str(line).expect("a JSON row"))
        .collect();
    assert_eq!(got.len(), want.len(), "one row per input");
    assert!(!want.is_empty(), "an empty oracle file");
    for (row, bend) in got.iter().zip(&want) {
        assert_eq!(shared(row), shared(&bend["js"]), "{} at {}", bend["id"], bend["ordinal"]);
    }
}
