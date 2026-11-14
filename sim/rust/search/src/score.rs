//! `buckshot-search score`: the production regret rows (docs/arena/analysis/regret.md, The `regret` table).
//!
//! Reads the rows `web/scripts/rust-search-inputs.ts` writes (each decision's position with Bend's menu, Bend's move
//! codes and the agent's move), searches each decision the regret database has no row for under this run's evaluator
//! and settings, and adds its row. A decision Bend and Rust disagree on (Bend wins, so either is a bug to fix) gets no
//! row but a dump that reproduces it, and the command fails once every input is read. `tools/arena/score_regret.py`
//! creates the tables, picks the decisions and records the build.

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use buckshot_search::{Analysed, Analysis, InfoSet, ParseError, Pruning, Reload, analyse_batch};
use rayon::ThreadPool;
use rusqlite::{Connection, OpenFlags, Transaction, params};
use rustc_hash::FxHashSet;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::{CHUNK, Evaluator, Outcome, Search, code, outcome};

/// A round win, in the search's millionths.
const WIN: u32 = 1_000_000;

#[derive(clap::Args)]
pub struct ScoreArgs {
    /// The regret database to add rows to (`score_regret.py` creates its tables).
    #[arg(long)]
    out: PathBuf,
    /// The analysis database, read only: each decision's player.
    #[arg(long)]
    source: PathBuf,
    /// Directory for the dumps of decisions Bend and Rust disagree on.
    #[arg(long)]
    bugs: PathBuf,
    /// rust-search-inputs.ts rows.
    #[arg(required = true)]
    inputs: Vec<PathBuf>,
}

/// A rust-search-inputs.ts row; a position Bend's player refuses has no menu and codes, and its reason as `invalid`.
#[derive(Deserialize)]
struct Position {
    id: String,
    ordinal: i64,
    input: String,
    menu: Option<Vec<String>>,
    codes: Option<Vec<String>>,
    invalid: Option<String>,
    chosen: String,
}

/// The run a row belongs to: the regret table's key past the decision.
struct Run {
    evaluator: String,
    max_depth: u32,
    budget: i64,
    reload: &'static str,
    samples: u32,
}

impl Run {
    fn of(search: &Search) -> Result<Self> {
        if search.evaluator != Evaluator::BoundedV1 || search.pruning != Pruning::Off {
            bail!(
                "score needs --unpruned, the {} search with every move's value exact",
                Evaluator::BoundedV1.id()
            );
        }
        let (reload, samples) = match search.reload {
            Reload::Static => ("static", 0),
            Reload::Sampled { count } => ("sampled", count),
        };
        Ok(Self {
            evaluator: format!("{}-unpruned", Evaluator::BoundedV1.id()),
            max_depth: search.limits.depth,
            budget: i64::try_from(search.limits.budget)?,
            reload,
            samples,
        })
    }

    /// The decisions `out` has a row for in this run.
    fn done(&self, out: &Connection) -> Result<FxHashSet<(String, i64)>> {
        let mut query = out.prepare(
            "SELECT match_id, ordinal FROM regret WHERE evaluator = ?1 AND max_depth = ?2 AND budget = ?3 AND reload = ?4 AND samples = ?5",
        )?;
        let rows = query.query_map(
            params![self.evaluator, self.max_depth, self.budget, self.reload, self.samples],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }
}

/// A root move's value as the `values_json` column holds it.
#[derive(Serialize)]
struct MoveValue<'a> {
    label: &'a str,
    score: u32,
}

/// The columns of a row Bend and Rust agree on; `searched` is none for a fallback (depth 0: values, no regret).
struct Row {
    values_json: String,
    limited: bool,
    nodes: i64,
    searched: Option<Searched>,
}

struct Searched {
    best: String,
    best_score: u32,
    chosen_score: u32,
    exact: bool,
    depth: u32,
}

/// The row of a decision, or why Bend's analysis of it and Rust's disagree.
fn row_of(position: &Position, analysis: &Result<Analysis, ParseError>) -> Result<Row, String> {
    let Some(menu) = &position.menu else {
        return Err(format!(
            "Bend's player refuses a position the game reached: {}",
            position.invalid.as_deref().unwrap_or_default()
        ));
    };
    let done: &Analysed = match analysis {
        Ok(Ok(done)) => done,
        Ok(Err(refusal)) => return Err(format!("Rust refuses a position Bend analysed: {refusal}")),
        Err(error) => return Err(format!("Rust refuses a position Bend analysed: {error}")),
    };
    let codes: Vec<String> = done.lines.iter().map(|line| code(line.r#move)).collect();
    if position.codes.as_ref() != Some(&codes) || menu.len() != codes.len() {
        return Err(format!("Rust's root moves {codes:?} are not Bend's {:?}", position.codes));
    }
    let values: Vec<MoveValue> = menu
        .iter()
        .zip(&done.lines)
        .map(|(label, line)| MoveValue { label, score: line.score })
        .collect();
    let mut row = Row {
        values_json: serde_json::to_string(&values).map_err(|error| error.to_string())?,
        limited: done.limited,
        nodes: i64::try_from(done.nodes).map_err(|error| error.to_string())?,
        searched: None,
    };
    if done.depth == 0 {
        return Ok(row);
    }
    let best = usize::try_from(done.best).ok().and_then(|best| values.get(best));
    let chosen = values.iter().find(|value| value.label == position.chosen);
    let (Some(best), Some(chosen)) = (best, chosen) else {
        return Err(format!(
            "Rust's best move {} or the chosen {:?} is not on Bend's menu",
            done.best, position.chosen
        ));
    };
    let certain = |score: u32| score == 0 || score == WIN;
    row.searched = Some(Searched {
        best: best.label.to_owned(),
        best_score: best.score,
        chosen_score: chosen.score,
        exact: certain(best.score) && certain(chosen.score),
        depth: done.depth,
    });
    Ok(row)
}

fn insert(tx: &Transaction, run: &Run, position: &Position, player: &str, row: &Row) -> Result<()> {
    let searched = row.searched.as_ref();
    let regret = searched.map(|s| i64::from(s.best_score).saturating_sub(i64::from(s.chosen_score)));
    tx.prepare_cached(
        "INSERT INTO regret (match_id, ordinal, player, label, evaluator, max_depth, budget, reload, samples, status, values_json, \
         best, best_score, chosen_score, regret, exact, depth, limited, nodes) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19)",
    )?
    .execute(params![
        position.id,
        position.ordinal,
        player,
        position.chosen,
        run.evaluator,
        run.max_depth,
        run.budget,
        run.reload,
        run.samples,
        if searched.is_some() { "searched" } else { "fallback" },
        row.values_json,
        searched.map(|s| s.best.as_str()),
        searched.map(|s| s.best_score),
        searched.map(|s| s.chosen_score),
        regret,
        searched.map(|s| s.exact),
        searched.map_or(0, |s| s.depth),
        row.limited,
        row.nodes,
    ])?;
    Ok(())
}

/// Writes what reproduces a disagreement: the input row as read, Rust's whole result and the command.
fn dump(bugs: &Path, position: &Position, reason: &str, line: &str, rust: &Outcome) -> Result<PathBuf> {
    std::fs::create_dir_all(bugs)?;
    let path = bugs.join(format!("{}-{}.json", position.id, position.ordinal));
    let fed: Value = serde_json::from_str(line)?;
    let report = json!({
        "match_id": position.id,
        "ordinal": position.ordinal,
        "reason": reason,
        "fed": fed,
        "rust": rust,
        "command": std::env::args().collect::<Vec<_>>(),
    });
    let mut text = serde_json::to_string_pretty(&report)?;
    text.push('\n');
    std::fs::write(&path, text)?;
    Ok(path)
}

/// One `score` run's state.
struct Scoring<'a> {
    search: &'a Search,
    pool: &'a ThreadPool,
    run: Run,
    out: Connection,
    source: Connection,
    bugs: PathBuf,
    dumps: Vec<PathBuf>,
}

/// Searches and writes one chunk of decisions in one transaction. Returns the rows written.
fn write_chunk(ctx: &mut Scoring, chunk: Vec<(Position, String)>) -> Result<u64> {
    let (search, pool) = (ctx.search, ctx.pool);
    let analyses = analyse_batch(&chunk, pool, |(position, _)| {
        InfoSet::parse(&position.input).map(|info| search.analyse(pool, &info, None))
    });
    let tx = ctx.out.transaction()?;
    let mut written = 0_u64;
    for ((position, line), analysis) in chunk.into_iter().zip(analyses) {
        match row_of(&position, &analysis) {
            Ok(row) => {
                let player: String = ctx
                    .source
                    .prepare_cached("SELECT player FROM decisions WHERE match_id = ?1 AND ordinal = ?2 AND by_whom = 'agent'")?
                    .query_row(params![position.id, position.ordinal], |found| found.get(0))
                    .with_context(|| format!("no agent decision {} {} in --source", position.id, position.ordinal))?;
                insert(&tx, &ctx.run, &position, &player, &row)?;
                written = written.saturating_add(1);
            }
            Err(reason) => {
                let rust = match analysis {
                    Ok(result) => outcome(result, ctx.search.evaluator),
                    Err(error) => Outcome::Unread { error: error.to_string() },
                };
                ctx.dumps.push(dump(&ctx.bugs, &position, &reason, &line, &rust)?);
            }
        }
    }
    tx.commit()?;
    Ok(written)
}

/// Adds a row for every input decision `--out` has none for in this run, and prints the rows written and their evaluator.
pub fn run(args: &ScoreArgs, search: &Search, pool: &ThreadPool) -> Result<()> {
    let run = Run::of(search)?;
    let out = Connection::open(&args.out).with_context(|| args.out.display().to_string())?;
    let source =
        Connection::open_with_flags(&args.source, OpenFlags::SQLITE_OPEN_READ_ONLY).with_context(|| args.source.display().to_string())?;
    let done = run.done(&out)?;
    let mut ctx = Scoring {
        search,
        pool,
        run,
        out,
        source,
        bugs: args.bugs.clone(),
        dumps: Vec::new(),
    };
    let mut written = 0_u64;
    for path in &args.inputs {
        let reader = BufReader::new(File::open(path).with_context(|| path.display().to_string())?);
        let mut chunk = Vec::with_capacity(CHUNK);
        for (n, line) in reader.lines().enumerate() {
            let line = line?;
            if line.trim().is_empty() {
                continue;
            }
            let position: Position =
                serde_json::from_str(&line).with_context(|| format!("{} line {}", path.display(), n.saturating_add(1)))?;
            if done.contains(&(position.id.clone(), position.ordinal)) {
                continue;
            }
            chunk.push((position, line));
            if chunk.len() >= CHUNK {
                written = written.saturating_add(write_chunk(&mut ctx, std::mem::take(&mut chunk))?);
                eprintln!("{written} rows");
            }
        }
        written = written.saturating_add(write_chunk(&mut ctx, chunk)?);
    }
    println!("{}", json!({ "rows": written, "evaluator": ctx.run.evaluator }));
    if !ctx.dumps.is_empty() {
        let paths: Vec<String> = ctx.dumps.iter().map(|path| path.display().to_string()).collect();
        bail!("Bend and Rust disagree on {} decisions; dumps:\n{}", paths.len(), paths.join("\n"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use buckshot_rules::{Move, Seat};
    use buckshot_search::{Analysed, Cached, Line, Reach, Refusal};

    use super::{Position, row_of};

    fn position(menu: Option<Vec<&str>>, codes: Option<Vec<&str>>) -> Position {
        let owned = |list: Vec<&str>| list.into_iter().map(str::to_owned).collect();
        Position {
            id: String::from("m"),
            ordinal: 1,
            input: String::new(),
            menu: menu.map(owned),
            codes: codes.map(owned),
            invalid: Some(String::from("not a choice")),
            chosen: String::from("Shoot yourself"),
        }
    }

    fn analysed(depth: u32) -> Analysed {
        let line = |index, target, score| Line {
            index,
            r#move: Move::Shoot { target },
            score,
            upper: score,
            reach: Reach::Settled,
        };
        Analysed {
            lines: vec![line(0, Seat::Seat0, 250_000), line(1, Seat::Seat1, 750_000)],
            best: 1,
            score: 750_000,
            nodes: 9,
            depth,
            limited: true,
            cached: Cached::default(),
        }
    }

    #[test]
    fn a_depth_zero_analysis_is_a_fallback_with_values() {
        let menu = Some(vec!["Shoot yourself", "Shoot Player B"]);
        let row = row_of(&position(menu, Some(vec!["0.0", "0.1"])), &Ok(Ok(analysed(0)))).ok();
        let row = row
            .as_ref()
            .map(|row| (row.values_json.as_str(), row.limited, row.nodes, row.searched.is_none()));
        let values = r#"[{"label":"Shoot yourself","score":250000},{"label":"Shoot Player B","score":750000}]"#;
        assert_eq!(row, Some((values, true, 9, true)), "a fallback row");
    }

    #[test]
    fn refusals_on_either_side_are_disagreements() {
        let refused = row_of(&position(None, None), &Ok(Ok(analysed(3)))).err();
        assert_eq!(
            refused.as_deref(),
            Some("Bend's player refuses a position the game reached: not a choice"),
            "Bend refuses"
        );
        let menu = Some(vec!["Shoot yourself", "Shoot Player B"]);
        let rust = row_of(&position(menu, Some(vec!["0.0", "0.1"])), &Ok(Err(Refusal::NotMyTurn))).err();
        assert_eq!(
            rust.as_deref(),
            Some("Rust refuses a position Bend analysed: it is not this player's turn"),
            "Rust refuses"
        );
    }

    #[test]
    fn a_settled_best_beside_an_unsettled_choice_is_not_exact() {
        let mut done = analysed(3);
        if let Some(best) = done.lines.get_mut(1) {
            best.score = super::WIN;
        }
        let menu = Some(vec!["Shoot yourself", "Shoot Player B"]);
        let row = row_of(&position(menu, Some(vec!["0.0", "0.1"])), &Ok(Ok(done))).ok();
        let searched = row.as_ref().and_then(|row| row.searched.as_ref());
        let found = searched.map(|s| (s.best.as_str(), s.best_score, s.chosen_score, s.exact, s.depth));
        assert_eq!(
            found,
            Some(("Shoot Player B", 1_000_000, 250_000, false, 3)),
            "only both scores settled make a row exact"
        );
    }

    #[test]
    fn a_shorter_menu_is_a_disagreement() {
        let row = row_of(
            &position(Some(vec!["Shoot yourself"]), Some(vec!["0.0", "0.1"])),
            &Ok(Ok(analysed(3))),
        );
        assert!(row.is_err(), "Bend's menu has one move, Rust two");
    }
}
