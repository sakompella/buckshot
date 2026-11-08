//! The compat evaluator against the production regret rows: a small
//! committed set of decisions (`tests/production/`) scored by the evaluator
//! the regret corpus was built with. `reference.json` names it: evaluator id,
//! source commit and file hash, Bend version and settings. The test checks
//! that it is the pinned reference before it compares a row. The f32 build only.
#![cfg(feature = "f32")]

use std::process::Command;

use serde_json::{Value, json};

const DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/production");
/// The production evaluator and its settings, and the CLI flags that are those settings.
const EVALUATOR: &str = "a3962092b561cfb4";
const SOURCE_COMMIT: &str = "03978b0f3d1bea52188fdae49547d4f3d9288ad3";
const FLAGS: [&str; 10] = [
    "--evaluator",
    "compat",
    "--depth",
    "6",
    "--budget",
    "20000",
    "--reload",
    "static",
    "--memo",
    "off",
];

fn settings() -> Value {
    json!({"depth": 6, "budget": 20000, "reload": "static", "samples": 0, "memo": "off"})
}

#[test]
fn compat_matches_the_production_evaluator() {
    let reference: Value = serde_json::from_str(&std::fs::read_to_string(format!("{DIR}/reference.json")).unwrap()).unwrap();
    assert_eq!(
        reference["evaluator"], EVALUATOR,
        "the rows are not the pinned production evaluator's"
    );
    assert_eq!(reference["source"]["commit"], SOURCE_COMMIT, "the production source commit");
    assert_eq!(reference["settings"], settings(), "the production settings");
    let path = format!("{DIR}/decisions.jsonl");
    let want: Vec<Value> = std::fs::read_to_string(&path)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(
        reference["decisions"].as_u64(),
        u64::try_from(want.len()).ok(),
        "decisions.jsonl against reference.json"
    );
    let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(FLAGS)
        .args(["--threads", "2", &path])
        .output()
        .unwrap();
    assert!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
    let got: Vec<Value> = String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(got.len(), want.len(), "one row per decision");
    for (row, decision) in got.iter().zip(&want) {
        let production = &decision["production"];
        let lines = production["lines"].as_array().unwrap();
        let best = usize::try_from(row["best"].as_u64().unwrap()).unwrap();
        let rust = json!({
            "scores": row["lines"].as_array().unwrap().iter().map(|line| line["score"].clone()).collect::<Vec<_>>(),
            "best": lines.get(best).map(|line| line[0].clone()),
            "depth": row["depth"], "limited": row["limited"], "nodes": row["nodes"],
        });
        let bend = json!({
            "scores": lines.iter().map(|line| line[1].clone()).collect::<Vec<_>>(),
            "best": production["best"],
            "depth": production["depth"], "limited": production["limited"], "nodes": production["nodes"],
        });
        assert_eq!(rust, bend, "{}", decision["id"]);
    }
    println!("compat matches production evaluator {EVALUATOR} on {} decisions", want.len());
}
