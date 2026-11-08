//! The compatibility evaluator against the current Bend player (rows name its
//! build in `reference`, which must be one build for the whole oracle): every row of
//! the files in `RUST_SEARCH_ORACLE` (written by `sim/rust/search-oracle.sh`;
//! a row's `js` field is the Bend player's analysis) must come out of the CLI
//! with the same best move, node and memo counts and line values:
//! `static.jsonl` with the default flags, `sampled.jsonl` with
//! `--reload sampled --samples 32`, `memo.jsonl` with `--memo charged`,
//! `sampled-memo.jsonl` with both and `budget.jsonl` with `--budget 300`,
//! where most rows run out of budget. The f32 build only; `sim/rust/check.sh`
//! runs it with `--include-ignored`. `production.rs` holds the pinned
//! historical reference, `pruning.rs` the bounded-v1 checks of both builds.
#![cfg(feature = "f32")]

mod common;

use common::{cli, oracle_dir, oracle_rows, scores};
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
#[ignore = "needs RUST_SEARCH_ORACLE; run by sim/rust/check.sh"]
fn compat_matches_bend() {
    let dir = oracle_dir().unwrap();
    let runs: [(&str, &[&str]); 5] = [
        ("static.jsonl", &[]),
        ("sampled.jsonl", &["--reload", "sampled", "--samples", "32"]),
        ("memo.jsonl", &["--memo", "charged"]),
        (
            "sampled-memo.jsonl",
            &["--reload", "sampled", "--samples", "32", "--memo", "charged"],
        ),
        ("budget.jsonl", &["--budget", "300"]),
    ];
    let mut compared = 0_usize;
    let mut references = std::collections::BTreeSet::new();
    for (name, flags) in runs {
        let (text, want) = oracle_rows(&dir, name).unwrap();
        let got = cli(flags, &text).unwrap();
        for (row, bend) in got.iter().zip(&want) {
            references.insert(bend["reference"].as_str().unwrap_or_default().to_owned());
            assert_eq!(shared(row), shared(&bend["js"]), "{name}: {} at {}", bend["id"], bend["ordinal"]);
            compared = compared.saturating_add(1);
        }
    }
    assert!(
        references.len() == 1 && !references.contains(""),
        "the oracle's rows name {references:?} as their Bend player"
    );
    println!("compat matches the current Bend player {references:?} on {compared} decisions");
}

/// Unpruned, bounded-v1's line values and best move are compat's, and so
/// Bend's, on every row neither search cuts by its budget.
#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run by sim/rust/check.sh"]
fn unpruned_bounded_matches_compat() {
    let (text, _) = oracle_rows(&oracle_dir().unwrap(), "static.jsonl").unwrap();
    let compat_rows = cli(&[], &text).unwrap();
    let unpruned_rows = cli(&["--evaluator", "bounded-v1-f32", "--unpruned"], &text).unwrap();
    let mut compared = 0_u32;
    for (compat, unpruned) in compat_rows.iter().zip(&unpruned_rows) {
        if [compat, unpruned].iter().any(|row| row["limited"] != Value::Bool(false)) {
            continue;
        }
        compared = compared.saturating_add(1);
        let id = (&compat["id"], &compat["ordinal"]);
        assert_eq!(scores(unpruned), scores(compat), "unpruned line values at {id:?}");
        assert_eq!(unpruned["best"], compat["best"], "unpruned best at {id:?}");
    }
    assert!(compared >= 6, "only {compared} rows within both budgets");
}
