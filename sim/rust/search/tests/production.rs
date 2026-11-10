//! The compat evaluator against the production regret rows: a small
//! committed set of decisions (`tests/production/`) scored by the evaluator
//! the regret corpus was built with. `reference.json` names it: evaluator id,
//! source commit and file hash, Bend version and the settings the CLI runs
//! with. The f32 build only.
#![cfg(feature = "f32")]

use std::process::Command;

use serde_json::{Value, json};

const DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/production");

/// The CLI flags of the production settings in `reference.json`.
fn flags(settings: &Value) -> Vec<String> {
    let mut flags = vec![String::from("--evaluator"), String::from("compat")];
    for key in ["depth", "budget", "reload", "memo"] {
        let value = &settings[key];
        flags.push(format!("--{key}"));
        flags.push(value.as_str().map_or_else(|| value.to_string(), str::to_owned));
    }
    if settings["samples"] != 0_u32 {
        flags.extend([String::from("--samples"), settings["samples"].to_string()]);
    }
    flags
}

#[test]
fn compat_matches_the_production_evaluator() {
    let reference: Value = serde_json::from_str(&std::fs::read_to_string(format!("{DIR}/reference.json")).unwrap()).unwrap();
    let path = format!("{DIR}/decisions.jsonl");
    let want: Vec<Value> = std::fs::read_to_string(&path)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(flags(&reference["settings"]))
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
    println!(
        "compat matches production evaluator {} on {} decisions",
        reference["evaluator"],
        want.len()
    );
}
