//! The CLI: one analysis row per input decision, read from a jsonl path or stdin.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::num::NonZero;
use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use buckshot_rules::Move;
use buckshot_search::{Analysis, BoundedV1, InfoSet, KeyStats, Limits, Pruning, Reload, analyse_batch};
#[cfg(feature = "f32")]
use buckshot_search::{Compat, Memo, Searcher};
use clap::builder::PossibleValue;
use clap::{Parser, ValueEnum};
use rayon::{ThreadPool, ThreadPoolBuilder};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

const AFTER_HELP: &str = "\
The decisions run in parallel on a pool of --threads workers (never rayon's
global pool), and so do the deals of a sampled leaf. Each decision's root
moves run one after another: they share the fuel, the node budget and the
memo, so a move's result depends on the moves before it. Every row is the one
a single thread gives, in input order. Every row records its `evaluator` id.";

/// One JSON row per input decision ({id, ordinal, input, chosenIndex?}), read from the path or stdin.
///
/// Each line names its root move twice: by `code`, as native.bend's show.move
/// prints it, and by `move`, as Bend writes a Move.
#[derive(Parser)]
#[command(name = "buckshot-search", after_help = AFTER_HELP)]
struct Args {
    /// Decisions deep.
    #[arg(long, default_value_t = 6)]
    depth: u32,
    /// Nodes per decision.
    #[arg(long, default_value_t = 20_000)]
    budget: u64,
    /// How a leaf at a reload is valued.
    #[arg(long, value_enum, default_value_t = ReloadRule::Static)]
    reload: ReloadRule,
    /// Deals per sampled leaf, with --reload sampled [default: 256].
    #[arg(long)]
    samples: Option<u32>,
    /// How compat reuses a finished node [default: off].
    #[cfg(feature = "f32")]
    #[arg(long, value_enum)]
    memo: Option<MemoRule>,
    /// Worker threads [default: half the cores, at least 1].
    #[arg(long, default_value_t = default_threads(), hide_default_value = true)]
    threads: NonZero<usize>,
    /// compat (the f32 build only, and its default) is Bend's search, bit for
    /// bit. bounded-v1-f32 or bounded-v1-f64, whichever matches the build (the
    /// f64 build's default), is the box search: lines add `upper`, the high end
    /// of the private value's box, and `exact`, whether the score is exact at
    /// the row's depth. The best move and the row's `chosenIndex` move (a menu
    /// index, if given) are exact; every other line's box is proved no better.
    /// Its budget counts nodes only (no fuel) and memo hits are free.
    #[arg(long, default_value_t = Evaluator::DEFAULT)]
    evaluator: Evaluator,
    /// With bounded-v1-*: search every child, every box exact.
    #[arg(long)]
    unpruned: bool,
    /// With bounded-v1-*: count the decision belief keys (the exact memo key)
    /// of each decision's deepest iteration. Rows add visits, distinct,
    /// inMatch (keys an earlier decision of the same id saw) and elsewhere
    /// (keys an earlier decision of another id saw), and a summary goes to stderr.
    #[arg(long)]
    stats: bool,
    /// The input rows [default: stdin].
    path: Option<PathBuf>,
}

fn default_threads() -> NonZero<usize> {
    let cores = std::thread::available_parallelism().map_or(1, NonZero::get);
    NonZero::new(cores >> 1).unwrap_or(NonZero::<usize>::MIN)
}

#[derive(Clone, Copy, PartialEq, Eq, ValueEnum)]
enum ReloadRule {
    Static,
    Sampled,
}

#[cfg(feature = "f32")]
#[derive(Clone, Copy, ValueEnum)]
enum MemoRule {
    Off,
    Charged,
    Free,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Evaluator {
    #[cfg(feature = "f32")]
    Compat,
    BoundedV1,
}

impl Evaluator {
    #[cfg(feature = "f32")]
    const DEFAULT: Self = Self::Compat;
    #[cfg(not(feature = "f32"))]
    const DEFAULT: Self = Self::BoundedV1;
    #[cfg(feature = "f32")]
    const ALL: &[Self] = &[Self::Compat, Self::BoundedV1];
    #[cfg(not(feature = "f32"))]
    const ALL: &[Self] = &[Self::BoundedV1];

    /// The id rows record; bounded-v1's names the build's arithmetic.
    const fn id(self) -> &'static str {
        match self {
            #[cfg(feature = "f32")]
            Self::Compat => "compat",
            Self::BoundedV1 => BoundedV1::ID,
        }
    }
}

impl ValueEnum for Evaluator {
    fn value_variants<'a>() -> &'a [Self] {
        Self::ALL
    }

    fn to_possible_value(&self) -> Option<PossibleValue> {
        Some(PossibleValue::new(self.id()))
    }
}

impl std::fmt::Display for Evaluator {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.id())
    }
}

/// The search every decision gets, from the arguments.
struct Search {
    evaluator: Evaluator,
    limits: Limits,
    reload: Reload,
    #[cfg(feature = "f32")]
    memo: Memo,
    pruning: Pruning,
    stats: bool,
}

impl Search {
    fn of(args: &Args) -> Result<Self> {
        let reload = match (args.reload, args.samples) {
            (ReloadRule::Static, None) => Reload::Static,
            (ReloadRule::Static, Some(_)) => bail!("--samples needs --reload sampled"),
            (ReloadRule::Sampled, count) => Reload::Sampled {
                count: count.unwrap_or(256),
            },
        };
        #[cfg(feature = "f32")]
        let memo = match (args.evaluator, args.memo) {
            (Evaluator::BoundedV1, Some(_)) => bail!("--memo needs --evaluator compat"),
            (Evaluator::Compat, _) if args.stats || args.unpruned => {
                bail!("--stats and --unpruned need --evaluator {}", BoundedV1::ID)
            }
            (_, None | Some(MemoRule::Off)) => Memo::Off,
            (_, Some(MemoRule::Charged)) => Memo::Charged,
            (_, Some(MemoRule::Free)) => Memo::Free,
        };
        Ok(Self {
            evaluator: args.evaluator,
            limits: Limits {
                depth: args.depth,
                budget: args.budget,
            },
            reload,
            #[cfg(feature = "f32")]
            memo,
            pruning: if args.unpruned { Pruning::Off } else { Pruning::On },
            stats: args.stats,
        })
    }

    /// One decision's analysis, and its keys with `--stats`.
    fn analyse(&self, pool: &ThreadPool, info: &InfoSet, chosen: Option<u32>) -> (Analysis, Option<KeyStats>) {
        match self.evaluator {
            #[cfg(feature = "f32")]
            Evaluator::Compat => {
                let searcher = Compat {
                    reload: self.reload,
                    memo: self.memo,
                    pool: Some(pool),
                };
                (searcher.analyse(info, self.limits), None)
            }
            Evaluator::BoundedV1 => {
                let searcher = BoundedV1 {
                    reload: self.reload,
                    pruning: self.pruning,
                    pool: Some(pool),
                };
                if self.stats {
                    let (analysis, stats) = searcher.analyse_with_stats(info, self.limits, chosen);
                    (analysis, Some(stats))
                } else {
                    (searcher.analyse_chosen(info, self.limits, chosen), None)
                }
            }
        }
    }
}

/// Decisions read and analysed at a time.
const CHUNK: usize = 512;

/// An input row; `id` and `ordinal` are echoed as they are.
#[derive(Deserialize)]
struct Decision {
    id: Value,
    ordinal: Option<Value>,
    input: String,
    #[serde(rename = "chosenIndex")]
    chosen: Option<u32>,
}

#[derive(Serialize)]
struct Row<'a> {
    id: &'a Value,
    ordinal: &'a Option<Value>,
    evaluator: &'static str,
    #[serde(flatten)]
    outcome: Outcome,
    #[serde(skip_serializing_if = "Option::is_none")]
    stats: Option<Counts>,
}

#[derive(Serialize)]
#[serde(untagged)]
enum Outcome {
    Analysed(Analysed),
    Refused { error: String, nodes: u64 },
    Unread { error: String },
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Analysed {
    lines: Vec<Line>,
    best: u32,
    nodes: u64,
    depth: u32,
    limited: bool,
    entries: u64,
    hits: u64,
    deals: u64,
    deal_hits: u64,
}

/// A root move's line; `upper` and `exact` with bounded-v1 only.
#[derive(Serialize)]
struct Line {
    code: String,
    r#move: Value,
    score: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    upper: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    exact: Option<bool>,
    reach: &'static str,
}

/// A move as native.bend's `show.move` prints it (`moveCode` in web/src/analysis/native-input.ts).
fn code(step: Move) -> String {
    match step {
        Move::Shoot { target } => format!("0.{}", u8::from(target)),
        Move::Use { item } => format!("1.{}", u8::from(item)),
        Move::Jam { target } => format!("2.{}", u8::from(target)),
        Move::Steal { owner, item } => format!("3.{}.{}", u8::from(owner), u8::from(item)),
        Move::StealJam { owner, target } => format!("4.{}.{}", u8::from(owner), u8::from(target)),
    }
}

/// A root move as Bend writes it (sm `Move`, `{"$": "Shoot", "target": {"$": "Seat1"}}`), so a caller can check the
/// moves against Bend's menu.
fn move_json(choice: Move) -> Value {
    let node = |name: String| json!({"$": name});
    match choice {
        Move::Shoot { target } => json!({"$": "Shoot", "target": node(format!("{target:?}"))}),
        Move::Use { item } => json!({"$": "Use", "item": node(format!("{item:?}"))}),
        Move::Jam { target } => json!({"$": "Jam", "target": node(format!("{target:?}"))}),
        Move::Steal { owner, item } => json!({"$": "Steal", "owner": node(format!("{owner:?}")), "item": node(format!("{item:?}"))}),
        Move::StealJam { owner, target } => {
            json!({"$": "StealJam", "owner": node(format!("{owner:?}")), "target": node(format!("{target:?}"))})
        }
    }
}

fn outcome(analysis: Analysis, evaluator: Evaluator) -> Outcome {
    let bounded = evaluator == Evaluator::BoundedV1;
    match analysis {
        Ok(done) => Outcome::Analysed(Analysed {
            lines: done
                .lines
                .iter()
                .map(|line| Line {
                    code: code(line.r#move),
                    r#move: move_json(line.r#move),
                    score: line.score,
                    upper: bounded.then_some(line.upper),
                    exact: bounded.then_some(line.score == line.upper),
                    reach: line.reach.name(),
                })
                .collect(),
            best: done.best,
            nodes: done.nodes,
            depth: done.depth,
            limited: done.limited,
            entries: done.cached.entries,
            hits: done.cached.hits,
            deals: done.cached.deals,
            deal_hits: done.cached.deal_hits,
        }),
        Err(refusal) => Outcome::Refused {
            error: refusal.to_string(),
            nodes: refusal.nodes(),
        },
    }
}

#[derive(Clone, Copy, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct Counts {
    visits: u64,
    distinct: usize,
    in_match: usize,
    elsewhere: usize,
}

#[derive(Serialize)]
struct Summary {
    #[serde(flatten)]
    counts: Counts,
    matches: usize,
    keys: usize,
}

/// The ids that saw each belief key, ids numbered in first-seen order.
#[derive(Default)]
struct Seen {
    ids: HashMap<String, usize>,
    owners: HashMap<u64, Vec<usize>>,
    total: Counts,
}

impl Seen {
    /// Counts a decision's keys against the earlier decisions', then adds them.
    fn add(&mut self, id: &Value, stats: &KeyStats) -> Counts {
        let next = self.ids.len();
        let me = *self.ids.entry(id.to_string()).or_insert(next);
        let mut counts = Counts {
            visits: stats.visits,
            distinct: stats.keys.len(),
            ..Counts::default()
        };
        for key in &stats.keys {
            let owners = self.owners.entry(*key).or_default();
            let mine = owners.contains(&me);
            counts.in_match = counts.in_match.saturating_add(usize::from(mine));
            counts.elsewhere = counts
                .elsewhere
                .saturating_add(usize::from(owners.iter().any(|owner| *owner != me)));
            if !mine {
                owners.push(me);
            }
        }
        self.total = Counts {
            visits: self.total.visits.saturating_add(counts.visits),
            distinct: self.total.distinct.saturating_add(counts.distinct),
            in_match: self.total.in_match.saturating_add(counts.in_match),
            elsewhere: self.total.elsewhere.saturating_add(counts.elsewhere),
        };
        counts
    }

    fn summary(&self) -> Value {
        json!({"summary": Summary { counts: self.total, matches: self.ids.len(), keys: self.owners.len() }})
    }
}

/// Writes the rows of a chunk of decisions, in input order.
fn write_rows(out: &mut impl Write, search: &Search, pool: &ThreadPool, decisions: &[Decision], seen: &mut Seen) -> Result<()> {
    let done = analyse_batch(decisions, pool, |decision| match InfoSet::parse(&decision.input) {
        Ok(info) => {
            let (analysis, stats) = search.analyse(pool, &info, decision.chosen);
            (outcome(analysis, search.evaluator), stats)
        }
        Err(error) => (Outcome::Unread { error: error.to_string() }, None),
    });
    for (decision, (outcome, stats)) in decisions.iter().zip(done) {
        let row = Row {
            id: &decision.id,
            ordinal: &decision.ordinal,
            evaluator: search.evaluator.id(),
            outcome,
            stats: stats.map(|stats| seen.add(&decision.id, &stats)),
        };
        serde_json::to_writer(&mut *out, &row)?;
        writeln!(out)?;
    }
    Ok(())
}

fn main() -> Result<()> {
    let args = Args::parse();
    let search = Search::of(&args)?;
    let pool = ThreadPoolBuilder::new().num_threads(args.threads.get()).build()?;
    let reader: Box<dyn BufRead> = match &args.path {
        Some(path) => Box::new(BufReader::new(
            std::fs::File::open(path).with_context(|| path.display().to_string())?,
        )),
        None => Box::new(std::io::stdin().lock()),
    };
    let mut out = std::io::stdout().lock();
    let mut chunk = Vec::with_capacity(CHUNK);
    let mut seen = Seen::default();
    for (n, line) in reader.lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        chunk.push(serde_json::from_str(&line).with_context(|| format!("input line {}", n.saturating_add(1)))?);
        if chunk.len() >= CHUNK {
            write_rows(&mut out, &search, &pool, &chunk, &mut seen)?;
            chunk.clear();
        }
    }
    write_rows(&mut out, &search, &pool, &chunk, &mut seen)?;
    if search.stats {
        eprintln!("{}", seen.summary());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use buckshot_search::KeyStats;
    use serde_json::json;

    use super::Seen;

    /// A key counts as elsewhere when any earlier decision of another id saw
    /// it, not only its first owner: for ids A, B, A the last A sees B's keys.
    #[test]
    fn elsewhere_counts_every_earlier_owner() {
        let stats = KeyStats {
            visits: 2,
            keys: [1, 2].into(),
        };
        let mut seen = Seen::default();
        let counts: Vec<_> = ["A", "B", "A"]
            .map(|id| seen.add(&json!(id), &stats))
            .iter()
            .map(|c| (c.distinct, c.in_match, c.elsewhere))
            .collect();
        assert_eq!(counts, [(2, 0, 0), (2, 0, 2), (2, 2, 2)], "(distinct, inMatch, elsewhere)");
    }
}
