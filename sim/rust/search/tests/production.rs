//! The production regret rows against the evaluators that wrote them: small
//! committed sets of decisions, each with a `reference.json` that names the
//! evaluator, its source and the settings the CLI runs with. No match ids or
//! player names.
//!
//! - `tests/production/`: the Bend rows, which `compat` (f32 build) must
//!   reproduce.
//! - `tests/golden/`: the production `bounded-v1-f64` unpruned rows, which the
//!   f64 build must reproduce bit for bit. The evaluator id rests on this set,
//!   not on a hash of the sources (ADR-0052): a change that keeps it keeps the
//!   id, and a change meant to move a value bumps `BoundedV1::ID` and
//!   regenerates the set.

use std::process::Command;

use serde_json::{Value, json};

/// The CLI flags of a reference's settings.
fn flags(settings: &Value) -> Vec<String> {
    let mut flags = Vec::new();
    if settings["unpruned"] == true {
        flags.push(String::from("--unpruned"));
    }
    for key in ["evaluator", "depth", "budget", "reload", "memo"] {
        let Some(value) = settings.get(key) else { continue };
        flags.push(format!("--{key}"));
        flags.push(value.as_str().map_or_else(|| value.to_string(), str::to_owned));
    }
    if settings["samples"] != 0_u32 {
        flags.extend([String::from("--samples"), settings["samples"].to_string()]);
    }
    flags
}

/// Runs the CLI on `dir`'s decisions with its reference settings and checks
/// every line's score, the best move, depth, cut and node count. Gives the
/// reference and the evaluator id each row recorded. A macro, so that its
/// unwraps and indexing sit in the test that expands it.
macro_rules! reproduce {
    ($dir:literal, $threads:literal) => {{
        let dir = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/", $dir);
        let reference: Value = serde_json::from_str(&std::fs::read_to_string(format!("{dir}/reference.json")).unwrap()).unwrap();
        let path = format!("{dir}/decisions.jsonl");
        let want: Vec<Value> = std::fs::read_to_string(&path)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
            .args(flags(&reference["settings"]))
            .args(["--threads", $threads, &path])
            .output()
            .unwrap();
        assert!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
        let got: Vec<Value> = String::from_utf8_lossy(&out.stdout)
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(got.len(), want.len(), "one row per decision");
        assert_eq!(reference["decisions"], want.len(), "reference.json counts the decisions");
        for (row, decision) in got.iter().zip(&want) {
            let production = &decision["production"];
            let lines = production["lines"].as_array().unwrap();
            let best = usize::try_from(row["best"].as_u64().unwrap()).unwrap();
            let rust = json!({
                "scores": row["lines"].as_array().unwrap().iter().map(|line| line["score"].clone()).collect::<Vec<_>>(),
                "best": lines.get(best).map(|line| line[0].clone()),
                "depth": row["depth"], "limited": row["limited"], "nodes": row["nodes"],
            });
            let recorded = json!({
                "scores": lines.iter().map(|line| line[1].clone()).collect::<Vec<_>>(),
                "best": production["best"],
                "depth": production["depth"], "limited": production["limited"], "nodes": production["nodes"],
            });
            assert_eq!(rust, recorded, "{}", decision["id"]);
        }
        println!("{dir}: reproduces {} on {} decisions", reference["evaluator"], want.len());
        let ids: Vec<Value> = got.iter().map(|row| row["evaluator"].clone()).collect();
        (reference, ids)
    }};
}

#[cfg(feature = "f32")]
#[test]
fn compat_matches_the_production_evaluator() {
    reproduce!("production", "2");
}

#[cfg(feature = "f64")]
#[test]
#[ignore = "half a minute in a release build: check.sh runs it"]
fn bounded_v1_reproduces_the_golden_set() {
    let (reference, ids) = reproduce!("golden", "4");
    let id = buckshot_search::BoundedV1::ID;
    assert!(ids.iter().all(|row| *row == id), "every row records {id}");
    assert_eq!(
        reference["evaluator"],
        format!("{id}-unpruned"),
        "the golden set pins this evaluator id"
    );
}
