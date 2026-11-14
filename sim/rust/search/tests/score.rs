//! `buckshot-search score` on golden decisions: the rows it writes, the rerun that skips them, and the dump of a
//! decision whose moves are not Bend's menu. Each row must carry the search's own analysis of the position, as the
//! CLI's default mode writes it.

use std::path::Path;
use std::process::{Command, Output};

use anyhow::{Context as _, Result, ensure};
use rusqlite::Connection;
use serde_json::{Value, json};

#[cfg(feature = "f64")]
const EVALUATOR: &[&str] = &[];
#[cfg(feature = "f32")]
const EVALUATOR: &[&str] = &["--evaluator", "bounded-v1-f32"];
const FLAGS: [&str; 11] = [
    "--unpruned",
    "--depth",
    "6",
    "--budget",
    "20000",
    "--reload",
    "sampled",
    "--samples",
    "256",
    "--threads",
    "2",
];

/// The golden decision `id`: its number line and the production lines (label, score).
fn golden(id: &str) -> Result<(String, Vec<(String, u32)>)> {
    let text = std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/golden/decisions.jsonl"))?;
    let row: Value = text
        .lines()
        .map(serde_json::from_str::<Value>)
        .find(|row| row.as_ref().is_ok_and(|row| row["id"] == id))
        .context("no such golden decision")??;
    let lines = serde_json::from_value(row.pointer("/production/lines").context("no lines")?.clone())?;
    Ok((row.get("input").and_then(Value::as_str).context("no input")?.to_owned(), lines))
}

/// The CLI's analysis of a golden decision: per root move its menu label, code and score, then best, depth and nodes.
struct Analysis {
    input: String,
    lines: Vec<(String, String, u32)>,
    best: usize,
    depth: u64,
    nodes: u64,
}

fn analyse(id: &str) -> Result<Analysis> {
    let (input, golden) = golden(id)?;
    let analysed = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(EVALUATOR)
        .args(FLAGS)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .spawn()
        .and_then(|mut child| {
            use std::io::Write as _;
            let mut stdin = child.stdin.take().ok_or(std::io::ErrorKind::BrokenPipe)?;
            writeln!(stdin, "{}", json!({"id": id, "input": input}))?;
            drop(stdin);
            child.wait_with_output()
        })?;
    let row: Value = serde_json::from_slice(&analysed.stdout)?;
    let lines = row
        .get("lines")
        .and_then(Value::as_array)
        .context("no lines")?
        .iter()
        .zip(golden)
        .map(|(line, (label, _))| {
            Ok((
                label,
                line.get("code").and_then(Value::as_str).context("no code")?.to_owned(),
                u32::try_from(line.get("score").and_then(Value::as_u64).context("no score")?)?,
            ))
        })
        .collect::<Result<_>>()?;
    Ok(Analysis {
        input,
        lines,
        best: usize::try_from(row.get("best").and_then(Value::as_u64).context("no best")?)?,
        depth: row.get("depth").and_then(Value::as_u64).context("no depth")?,
        nodes: row.get("nodes").and_then(Value::as_u64).context("no nodes")?,
    })
}

/// A rust-search-inputs.ts row for a golden decision, with Rust's own move codes unless `codes` overrides them.
fn position(id: &str, analysis: &Analysis, chosen: &str, codes: Option<Vec<&str>>) -> String {
    let menu: Vec<&str> = analysis.lines.iter().map(|(label, _, _)| label.as_str()).collect();
    let own: Vec<&str> = analysis.lines.iter().map(|(_, code, _)| code.as_str()).collect();
    json!({"id": id, "ordinal": 1, "me": 0, "table": 2, "shells": 2, "input": analysis.input, "menu": menu,
           "codes": codes.unwrap_or(own), "chosen": chosen})
    .to_string()
}

fn databases(dir: &Path, ids: &[&str]) -> Result<()> {
    let source = Connection::open(dir.join("source.sqlite"))?;
    source.execute_batch("CREATE TABLE decisions (match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT)")?;
    for id in ids {
        source.execute("INSERT INTO decisions VALUES (?1, 1, 'B', 'agent')", [id])?;
    }
    Connection::open(dir.join("out.sqlite"))?.execute_batch(
        "CREATE TABLE regret (match_id TEXT, ordinal INTEGER, player TEXT, label TEXT, evaluator TEXT, max_depth INTEGER,
         budget INTEGER, reload TEXT, samples INTEGER, status TEXT, reason TEXT, values_json TEXT, best TEXT, best_score INTEGER,
         chosen_score INTEGER, regret INTEGER, exact INTEGER, depth INTEGER, limited INTEGER, nodes INTEGER, ms REAL)",
    )?;
    Ok(())
}

fn score(dir: &Path, inputs: &str) -> Result<Output> {
    std::fs::write(dir.join("inputs.jsonl"), inputs)?;
    let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(EVALUATOR)
        .args(FLAGS)
        .arg("score")
        .args(["--out", "out.sqlite", "--source", "source.sqlite", "--bugs", "bugs", "inputs.jsonl"])
        .current_dir(dir)
        .output()?;
    Ok(out)
}

/// The regret rows `out.sqlite` holds, every column, in insertion order.
fn stored_rows(dir: &Path) -> Result<Vec<Value>> {
    let out = Connection::open(dir.join("out.sqlite"))?;
    let mut query = out.prepare(
        "SELECT match_id, player, label, evaluator, max_depth, budget, reload, samples, status, values_json, best, best_score,
                chosen_score, regret, exact, depth, limited, nodes, reason, ms FROM regret ORDER BY rowid",
    )?;
    let rows = query
        .query_map([], |row| {
            Ok(json!([
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, i64>(4)?,
                row.get::<_, i64>(5)?,
                row.get::<_, String>(6)?,
                row.get::<_, i64>(7)?,
                row.get::<_, String>(8)?,
                row.get::<_, String>(9)?,
                row.get::<_, String>(10)?,
                row.get::<_, i64>(11)?,
                row.get::<_, i64>(12)?,
                row.get::<_, i64>(13)?,
                row.get::<_, i64>(14)?,
                row.get::<_, i64>(15)?,
                row.get::<_, i64>(16)?,
                row.get::<_, i64>(17)?,
                row.get::<_, Option<String>>(18)?,
                row.get::<_, Option<f64>>(19)?,
            ]))
        })?
        .collect::<rusqlite::Result<_>>()?;
    Ok(rows)
}

#[test]
fn score_writes_the_regret_rows_and_dumps_a_disagreement() -> Result<()> {
    let dir = std::env::temp_dir().join(format!("buckshot-search-score-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;
    databases(&dir, &["golden-82", "golden-299", "golden-138", "golden-54"])?;
    // Chosen: a worse move, a settled loss beside a settled win (exact), and the best move.
    let cases = [
        ("golden-82", "Shoot yourself", 0_i64),
        ("golden-299", "Shoot yourself", 1_i64),
        ("golden-138", "Shoot Player B", 0_i64),
    ];
    let searched = cases.map(|(id, _, _)| analyse(id));
    let mut agreed = Vec::new();
    for ((id, chosen, _), analysis) in cases.iter().zip(&searched) {
        let analysis = analysis.as_ref().map_err(|error| anyhow::anyhow!("{error}"))?;
        agreed.push(position(id, analysis, chosen, None));
    }
    let broken = position("golden-54", &analyse("golden-54")?, "Shoot yourself", Some(vec!["0.0", "0.0"]));
    let first = score(&dir, &format!("{}\n{broken}\n", agreed.join("\n")))?;
    ensure!(!first.status.success(), "a disagreement fails the run");
    let summary: Value = serde_json::from_slice(&first.stdout)?;
    let evaluator = format!("{}-unpruned", EVALUATOR.get(1).copied().unwrap_or("bounded-v1-f64"));
    ensure!(summary == json!({"rows": 3_i64, "evaluator": evaluator}), "summary {summary}");
    let dump: Value = serde_json::from_str(&std::fs::read_to_string(dir.join("bugs/golden-54-1.json"))?)?;
    ensure!(
        dump["reason"]
            .as_str()
            .is_some_and(|reason| reason.starts_with("Rust's root moves")),
        "dump {dump}"
    );
    ensure!(dump["fed"]["chosen"] == "Shoot yourself", "the dump holds the input row: {dump}");

    let rows = stored_rows(&dir)?;
    let mut expected = Vec::new();
    for ((id, chosen, exact), analysis) in cases.iter().zip(searched) {
        let analysis = analysis?;
        let values: Vec<Value> = analysis
            .lines
            .iter()
            .map(|(label, _, score)| json!({"label": label, "score": score}))
            .collect();
        let (best, _, best_score) = analysis.lines.get(analysis.best).context("no best line")?;
        let (_, _, chosen_score) = analysis
            .lines
            .iter()
            .find(|(label, _, _)| label == chosen)
            .context("no chosen line")?;
        expected.push(json!([
            id,
            "B",
            chosen,
            evaluator,
            6_i64,
            20_000_i64,
            "sampled",
            256_i64,
            "searched",
            Value::from(values).to_string(),
            best,
            best_score,
            chosen_score,
            i64::from(*best_score) - i64::from(*chosen_score),
            exact,
            analysis.depth,
            0_i64,
            analysis.nodes,
            null,
            null
        ]));
    }
    ensure!(rows == expected, "rows {rows:?}");

    let rerun = score(&dir, &format!("{}\n", agreed.join("\n")))?;
    ensure!(rerun.status.success(), "{}", String::from_utf8_lossy(&rerun.stderr));
    ensure!(
        serde_json::from_slice::<Value>(&rerun.stdout)?["rows"] == 0_i64,
        "a rerun skips the scored decisions"
    );
    std::fs::remove_dir_all(&dir)?;
    Ok(())
}

#[test]
fn score_needs_the_unpruned_search() -> Result<()> {
    let dir = std::env::temp_dir().join(format!("buckshot-search-score-pruned-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;
    databases(&dir, &[])?;
    std::fs::write(dir.join("inputs.jsonl"), "")?;
    let out = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(EVALUATOR)
        .args([
            "--threads",
            "1",
            "score",
            "--out",
            "out.sqlite",
            "--source",
            "source.sqlite",
            "--bugs",
            "bugs",
            "inputs.jsonl",
        ])
        .current_dir(&dir)
        .output()?;
    std::fs::remove_dir_all(&dir)?;
    ensure!(
        !out.status.success() && String::from_utf8_lossy(&out.stderr).contains("--unpruned"),
        "a pruned search writes no rows"
    );
    Ok(())
}
