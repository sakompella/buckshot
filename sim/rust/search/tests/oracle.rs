//! The compatibility evaluator against Bend's player: every row of the files
//! in `RUST_SEARCH_ORACLE` (written by `web/scripts/rust-search-synth.ts`,
//! whose `js` field is the Bend player's analysis) must come out of the CLI
//! with the same best move, node and memo counts and line values: `static.jsonl` with
//! the default flags, `sampled.jsonl` with `--reload sampled --samples 32`,
//! `memo.jsonl` with `--memo charged`. bounded-v1 is checked against compat on `static.jsonl`.
//! The f32 build only; run by `sim/rust/mutants.sh`.
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
        "memo": [row["entries"], row["hits"], row["deals"], row["dealHits"]],
        "lines": lines,
    })
}

#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run sim/rust/mutants.sh"]
fn compat_matches_bend() {
    let dir = std::env::var("RUST_SEARCH_ORACLE").expect("RUST_SEARCH_ORACLE names a directory of rust-search-synth.ts files");
    let runs: [(&str, &[&str]); 3] = [
        ("static.jsonl", &[]),
        ("sampled.jsonl", &["--reload", "sampled", "--samples", "32"]),
        ("memo.jsonl", &["--memo", "charged"]),
    ];
    for (name, flags) in runs {
        let path = format!("{dir}/{name}");
        let text = std::fs::read_to_string(&path).expect("a readable oracle file");
        let want: Vec<Value> = text.lines().map(|line| serde_json::from_str(line).expect("a JSON row")).collect();
        let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
            .args(flags)
            .args(["--threads", "2", &path])
            .output()
            .expect("the CLI runs");
        assert!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
        let got: Vec<Value> = String::from_utf8_lossy(&out.stdout)
            .lines()
            .map(|line| serde_json::from_str(line).expect("a JSON row"))
            .collect();
        assert_eq!(got.len(), want.len(), "{name}: one row per input");
        assert!(!want.is_empty(), "{name}: an empty oracle file");
        for (row, bend) in got.iter().zip(&want) {
            assert_eq!(shared(row), shared(&bend["js"]), "{name}: {} at {}", bend["id"], bend["ordinal"]);
        }
    }
}

fn scores(row: &Value) -> Vec<Value> {
    row["lines"]
        .as_array()
        .map(|lines| lines.iter().map(|line| line["score"].clone()).collect())
        .unwrap_or_default()
}

/// bounded-v1 against compat, and so against Bend: unpruned, every line's
/// value is compat's; pruned, the best move and its value are the unpruned
/// ones. Rows either search cuts by its budget are left out.
#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run sim/rust/mutants.sh"]
fn bounded_matches_compat() {
    let dir = std::env::var("RUST_SEARCH_ORACLE").expect("RUST_SEARCH_ORACLE names a directory of rust-search-synth.ts files");
    let path = format!("{dir}/static.jsonl");
    let rows = |flags: &[&str]| -> Vec<Value> {
        let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
            .args(flags)
            .args(["--threads", "2", &path])
            .output()
            .expect("the CLI runs");
        assert!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
        String::from_utf8_lossy(&out.stdout)
            .lines()
            .map(|line| serde_json::from_str(line).expect("a JSON row"))
            .collect()
    };
    let compat_rows = rows(&[]);
    let unpruned_rows = rows(&["--evaluator", "bounded-v1-f32", "--unpruned"]);
    let pruned_rows = rows(&["--evaluator", "bounded-v1-f32"]);
    assert_eq!(
        (unpruned_rows.len(), pruned_rows.len()),
        (compat_rows.len(), compat_rows.len()),
        "one row per input"
    );
    let best = |row: &Value| {
        row["lines"]
            .as_array()
            .and_then(|lines| lines.iter().map(|line| &line["score"]).max_by_key(|score| score.as_u64()))
            .cloned()
    };
    let mut compared = 0_u32;
    for ((compat, unpruned), pruned) in compat_rows.iter().zip(&unpruned_rows).zip(&pruned_rows) {
        if [compat, unpruned, pruned].iter().any(|row| row["limited"] != Value::Bool(false)) {
            continue;
        }
        compared = compared.saturating_add(1);
        let id = (&compat["id"], &compat["ordinal"]);
        assert_eq!(scores(unpruned), scores(compat), "unpruned line values at {id:?}");
        assert_eq!(unpruned["best"], compat["best"], "unpruned best at {id:?}");
        assert_eq!(pruned["best"], unpruned["best"], "pruned best at {id:?}");
        assert_eq!(best(pruned), best(unpruned), "pruned best value at {id:?}");
    }
    assert!(compared >= 6, "only {compared} rows within both budgets");
}
