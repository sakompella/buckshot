//! bounded-v1's pruning against its own unpruned search, in both builds, on
//! the decisions in `RUST_SEARCH_ORACLE` (`sim/rust/search-oracle.sh`): static
//! leaves (`static.jsonl`) and sampled leaves (`sampled.jsonl`). Pruned, the
//! best move and its value are the unpruned ones and every line's box holds
//! the unpruned value; the chosen move is exact; the budget is spent exactly.
//! The compared rows must include a private observation, a round end and,
//! with wider tables, several opponents (where opponent ties arise).
//! `sim/rust/check.sh` runs it with `--include-ignored`.

mod common;

use buckshot_search::{BoundedV1, InfoSet};
use common::{cli, oracle_dir, oracle_rows, scores};
use serde_json::Value;

/// What the compared rows covered.
#[derive(Default)]
struct Covered {
    rows: u32,
    private: u32,
    round_ends: u32,
    wide: u32,
}

/// Checks the pruned rows of one oracle file against the unpruned ones.
fn compare(name: &str, flags: &[&str], covered: &mut Covered) -> Result<(), String> {
    let (text, inputs) = oracle_rows(&oracle_dir()?, name)?;
    let run = |extra: &[&str]| cli(&[&["--evaluator", BoundedV1::ID], flags, extra].concat(), &text);
    let (unpruned_rows, pruned_rows) = (run(&["--unpruned"])?, run(&[])?);
    let best = |row: &Value| scores(row).into_iter().max_by_key(Value::as_u64);
    let lines = |row: &Value| row["lines"].as_array().cloned().unwrap_or_default();
    let mut problems = Vec::new();
    for ((input, unpruned), pruned) in inputs.iter().zip(&unpruned_rows).zip(&pruned_rows) {
        if [unpruned, pruned].iter().any(|row| row["limited"] != Value::Bool(false)) {
            continue;
        }
        let id = format!("{name} {} {}", input["id"], input["ordinal"]);
        if pruned["best"] != unpruned["best"] || best(pruned) != best(unpruned) {
            problems.push(format!(
                "{id}: pruned best {} {:?}, unpruned {} {:?}",
                pruned["best"],
                best(pruned),
                unpruned["best"],
                best(unpruned)
            ));
        }
        let (pruned_lines, unpruned_lines) = (lines(pruned), lines(unpruned));
        if pruned_lines.len() != unpruned_lines.len() {
            problems.push(format!(
                "{id}: {} pruned lines, {} unpruned",
                pruned_lines.len(),
                unpruned_lines.len()
            ));
        }
        for (j, (boxed, exact)) in pruned_lines.iter().zip(&unpruned_lines).enumerate() {
            let (lo, hi, value) = (boxed["score"].as_u64(), boxed["upper"].as_u64(), exact["score"].as_u64());
            if !(lo <= value && value <= hi) || (boxed["exact"] == Value::Bool(true) && lo != value) {
                problems.push(format!(
                    "{id}: line {j} box {lo:?}..={hi:?} (exact {}) misses {value:?}",
                    boxed["exact"]
                ));
            }
        }
        let info = InfoSet::parse(input["input"].as_str().unwrap_or_default()).map_err(|error| format!("{id}: {error}"))?;
        covered.rows = covered.rows.saturating_add(1);
        if info.has_private_clue() {
            covered.private = covered.private.saturating_add(1);
        }
        if unpruned_lines.iter().any(|line| line["reach"] == "settled") {
            covered.round_ends = covered.round_ends.saturating_add(1);
        }
        if input["table"].as_u64() > Some(2) {
            covered.wide = covered.wide.saturating_add(1);
        }
    }
    if problems.is_empty() { Ok(()) } else { Err(problems.join("\n")) }
}

#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run by sim/rust/check.sh"]
fn pruned_matches_unpruned() {
    let mut covered = Covered::default();
    compare("static.jsonl", &[], &mut covered).unwrap();
    let static_rows = covered.rows;
    compare("sampled.jsonl", &["--reload", "sampled", "--samples", "32"], &mut covered).unwrap();
    let sampled_rows = covered.rows.saturating_sub(static_rows);
    println!(
        "pruned matches unpruned on {static_rows} static and {sampled_rows} sampled decisions: {} with a private observation, {} reaching a round end, {} at a wider table",
        covered.private, covered.round_ends, covered.wide
    );
    assert!(static_rows >= 6 && sampled_rows >= 3, "too few rows within budget");
    assert!(covered.private > 0, "no compared decision has a private observation");
    assert!(covered.round_ends > 0, "no compared decision reaches a round end");
    if cfg!(feature = "seats-2-4") {
        assert!(covered.wide > 0, "no compared decision at a table of three or four");
    }
}

/// bounded-v1 searches a row's chosen move exactly even where pruning would
/// cut it, and a search that spends exactly its budget finishes while one
/// node less cuts it.
#[test]
#[ignore = "needs RUST_SEARCH_ORACLE; run by sim/rust/check.sh"]
fn bounded_keeps_the_chosen_move_exact_and_its_budget() {
    let (inputs, _) = oracle_rows(&oracle_dir().unwrap(), "static.jsonl").unwrap();
    let unbounded = ["--evaluator", BoundedV1::ID, "--budget", "1000000000"];
    let pruned_rows = cli(&unbounded, &inputs).unwrap();
    // The chosen move is one plain pruning leaves inexact.
    let with_chosen: String = inputs
        .lines()
        .zip(&pruned_rows)
        .filter_map(|(input, pruned)| {
            let chosen = pruned["lines"]
                .as_array()?
                .iter()
                .position(|line| line["exact"] == Value::Bool(false))?;
            let mut row: Value = serde_json::from_str(input).expect("a JSON row");
            row["chosenIndex"] = chosen.into();
            Some(format!("{row}\n"))
        })
        .collect();
    let chosen_rows = cli(&unbounded, &with_chosen).unwrap();
    let plain = |input: &Value| {
        pruned_rows
            .iter()
            .find(|row| row["id"] == input["id"] && row["ordinal"] == input["ordinal"])
            .expect("the plain row")
    };
    for (input, row) in with_chosen.lines().zip(&chosen_rows) {
        let input: Value = serde_json::from_str(input).expect("a JSON row");
        let chosen = usize::try_from(input["chosenIndex"].as_u64().expect("a chosen index")).expect("a menu index");
        let (line, boxed) = (&row["lines"][chosen], &plain(&input)["lines"][chosen]);
        assert_eq!(line["exact"], Value::Bool(true), "chosen line at {:?}", input["id"]);
        let (value, lo, hi) = (line["score"].as_u64(), boxed["score"].as_u64(), boxed["upper"].as_u64());
        assert!(
            lo <= value && value <= hi,
            "chosen line {value:?} outside {lo:?}..={hi:?} at {:?}",
            input["id"]
        );
    }
    assert!(chosen_rows.len() >= 3, "only {} rows with an inexact line", chosen_rows.len());

    // A search that spends exactly its budget finishes; one node less cuts it.
    let (input, nodes) = inputs
        .lines()
        .zip(&pruned_rows)
        .filter(|(_, row)| row["limited"] == Value::Bool(false))
        .filter_map(|(input, row)| Some((input, row["nodes"].as_u64()?)))
        .max_by_key(|&(_, nodes)| nodes)
        .expect("a row within budget");
    let input = format!("{input}\n");
    let at = |budget: u64| {
        cli(&["--evaluator", BoundedV1::ID, "--budget", &budget.to_string()], &input)
            .unwrap()
            .remove(0)
    };
    let exact = at(nodes);
    assert_eq!(
        (&exact["limited"], exact["nodes"].as_u64()),
        (&Value::Bool(false), Some(nodes)),
        "at its budget"
    );
    let short = at(nodes.saturating_sub(1));
    assert_eq!(short["limited"], Value::Bool(true), "one node short");
    assert!(short["nodes"].as_u64() < Some(nodes), "one node short spends less");
}
