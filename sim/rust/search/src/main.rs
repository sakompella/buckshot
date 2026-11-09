//! The CLI: one analysis row per input decision, read from a jsonl path or stdin.

use std::error::Error;
use std::io::{BufRead, BufReader, Write};

use std::collections::{BTreeSet, HashMap};

use buckshot_rules::Move;
use buckshot_search::{Analysis, BoundedV1, InfoSet, KeyStats, Limits, Memo, Reload, analyse_batch};
#[cfg(feature = "f32")]
use buckshot_search::{Compat, Searcher};
use rayon::{ThreadPool, ThreadPoolBuilder};
use serde_json::{Value, json};

const HELP: &str = "\
buckshot-search [options] [inputs.jsonl]

One JSON row per input decision ({id, ordinal, input}), read from the path or stdin.
Each line names its root move by `code`, as native.bend's show.move prints it.

  --depth N              decisions deep (6)
  --budget N             nodes per decision (20000)
  --reload static|sampled
                         how a leaf at a reload is valued (static)
  --samples N            deals per sampled leaf (256)
  --memo off|charged|free
                         how a finished node is reused (off)
  --threads N            worker threads (half the cores, at least 1)
  --evaluator ID         compat: Bend's search, bit for bit; the f32 build only,
                         and its default.
                         bounded-v1-f32 or bounded-v1-f64, whichever matches
                         the build (the f64 build's default): the box search.
                         Lines add `upper`, the high end of the private
                         value's box, and `exact`, whether the score is exact
                         at the row's depth. The best move and the row's
                         `chosenIndex` move (a menu index, if given) are
                         exact; every other line's box is proved no better.
                         Its budget counts nodes only (no fuel), memo hits
                         are free and --memo does not apply.
  --unpruned             with bounded-v1-*: search every child, every box exact.
  --stats                with bounded-v1-*: count the decision belief keys
                         (the exact memo key) of each decision's deepest
                         iteration; rows add visits, distinct, inMatch (keys
                         an earlier decision of the same id saw) and
                         elsewhere (keys an earlier other id saw), and a
                         summary goes to stderr.

The decisions run in parallel on a pool of --threads workers (never rayon's
global pool), and so do the deals of a sampled leaf. Each decision's root
moves run one after another: they share the fuel, the node budget and the
memo, so a move's result depends on the moves before it. Every row is the one
a single thread gives, in input order. Every row records its `evaluator` id.
";

/// Decisions read and analysed at a time.
const CHUNK: usize = 512;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Evaluator {
    #[cfg(feature = "f32")]
    Compat,
    BoundedV1,
}

#[cfg(feature = "f32")]
const BOUNDED_V1: &str = "bounded-v1-f32";
#[cfg(not(feature = "f32"))]
const BOUNDED_V1: &str = "bounded-v1-f64";

impl Evaluator {
    #[cfg(feature = "f32")]
    const DEFAULT: Self = Self::Compat;
    #[cfg(not(feature = "f32"))]
    const DEFAULT: Self = Self::BoundedV1;

    /// The id rows record; bounded-v1's names the build's arithmetic.
    const fn id(self) -> &'static str {
        match self {
            #[cfg(feature = "f32")]
            Self::Compat => "compat",
            Self::BoundedV1 => BOUNDED_V1,
        }
    }

    fn parse(id: &str) -> Result<Self, String> {
        match id {
            #[cfg(feature = "f32")]
            "compat" => Ok(Self::Compat),
            _ if id == BOUNDED_V1 => Ok(Self::BoundedV1),
            other => Err(format!("unknown evaluator {other} in the {} build", buckshot_search::ARITHMETIC)),
        }
    }
}

struct Args {
    evaluator: Evaluator,
    stats: bool,
    unpruned: bool,
    limits: Limits,
    reload: Reload,
    memo: Memo,
    threads: usize,
    path: Option<String>,
    help: bool,
}

fn default_threads() -> usize {
    std::thread::available_parallelism()
        .map_or(1, std::num::NonZero::get)
        .checked_div(2)
        .unwrap_or(1)
        .max(1)
}

fn args() -> Result<Args, Box<dyn Error>> {
    let mut args = Args {
        limits: Limits { depth: 6, budget: 20_000 },
        reload: Reload::Static,
        memo: Memo::Off,
        evaluator: Evaluator::DEFAULT,
        stats: false,
        unpruned: false,
        threads: default_threads(),
        path: None,
        help: false,
    };
    let mut sampled = false;
    let mut count = 256;
    let mut words = std::env::args().skip(1);
    while let Some(word) = words.next() {
        let mut value = || words.next().ok_or_else(|| format!("{word} needs a value"));
        match word.as_str() {
            "-h" | "--help" => args.help = true,
            "--stats" => args.stats = true,
            "--unpruned" => args.unpruned = true,
            "--evaluator" => {
                args.evaluator = Evaluator::parse(&value()?)?;
            }
            "--depth" => args.limits.depth = value()?.parse()?,
            "--budget" => args.limits.budget = value()?.parse()?,
            "--samples" => count = value()?.parse()?,
            "--threads" => args.threads = value()?.parse::<usize>()?.max(1),
            "--reload" => {
                sampled = match value()?.as_str() {
                    "static" => false,
                    "sampled" => true,
                    other => return Err(format!("unknown reload {other}").into()),
                };
            }
            "--memo" => {
                args.memo = match value()?.as_str() {
                    "off" => Memo::Off,
                    "charged" => Memo::Charged,
                    "free" => Memo::Free,
                    other => return Err(format!("unknown memo {other}").into()),
                };
            }
            _ => args.path = Some(word),
        }
    }
    if sampled {
        args.reload = Reload::Sampled { count };
    }
    if (args.stats || args.unpruned) && args.evaluator != Evaluator::BoundedV1 {
        return Err(format!("--stats and --unpruned need --evaluator {BOUNDED_V1}").into());
    }
    Ok(args)
}

/// An input's id and ordinal, and its position or why it has none.
struct Input {
    id: Value,
    ordinal: Value,
    info: Result<InfoSet, String>,
    chosen: Option<u32>,
}

fn input(row: &Value) -> Input {
    let info = match row["input"].as_str() {
        Some(line) => InfoSet::parse(line).map_err(|error| error.to_string()),
        None => Err("no input".to_owned()),
    };
    Input {
        id: row["id"].clone(),
        ordinal: row["ordinal"].clone(),
        info,
        chosen: row["chosenIndex"].as_u64().and_then(|index| u32::try_from(index).ok()),
    }
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

fn analysed(id: &Value, ordinal: &Value, analysis: &Analysis, evaluator: Evaluator) -> Value {
    match analysis {
        Analysis::Analysed(done) => {
            let lines: Vec<Value> = done
                .lines
                .iter()
                .map(|l| match evaluator {
                    #[cfg(feature = "f32")]
                    Evaluator::Compat => json!({"code": code(l.r#move), "score": l.score, "reach": l.reach.name()}),
                    Evaluator::BoundedV1 => {
                        json!({"code": code(l.r#move), "score": l.score, "upper": l.upper, "exact": l.score == l.upper, "reach": l.reach.name()})
                    }
                })
                .collect();
            json!({
                "id": id, "ordinal": ordinal, "evaluator": evaluator.id(), "lines": lines, "best": done.best, "nodes": done.nodes,
                "depth": done.depth, "limited": done.limited,
                "entries": done.cached.entries, "hits": done.cached.hits,
                "deals": done.cached.deals, "dealHits": done.cached.deal_hits,
            })
        }
        Analysis::Invalid { reason, nodes } => {
            json!({"id": id, "ordinal": ordinal, "evaluator": evaluator.id(), "error": reason, "nodes": nodes})
        }
    }
}

/// Belief keys seen so far, by the id of the decision that saw them.
#[derive(Default)]
struct Seen {
    by_match: HashMap<String, BTreeSet<u64>>,
    all: HashMap<u64, String>,
    visits: u64,
    distinct: u64,
    in_match: u64,
    elsewhere: u64,
}

impl Seen {
    /// Counts a decision's keys against the earlier decisions', then adds them.
    fn add(&mut self, id: &Value, stats: &KeyStats) -> Value {
        let id = id.to_string();
        let earlier = self.by_match.get(&id);
        let in_match = stats
            .keys
            .iter()
            .filter(|key| earlier.is_some_and(|seen| seen.contains(*key)))
            .count();
        let elsewhere = stats
            .keys
            .iter()
            .filter(|key| self.all.get(*key).is_some_and(|other| *other != id))
            .count();
        let distinct = stats.keys.len();
        let counts = [distinct, in_match, elsewhere].map(|n| u64::try_from(n).unwrap_or(u64::MAX));
        self.visits = self.visits.saturating_add(stats.visits);
        self.distinct = self.distinct.saturating_add(counts[0]);
        self.in_match = self.in_match.saturating_add(counts[1]);
        self.elsewhere = self.elsewhere.saturating_add(counts[2]);
        for key in &stats.keys {
            self.all.entry(*key).or_insert_with(|| id.clone());
        }
        self.by_match.entry(id).or_default().extend(stats.keys.iter().copied());
        json!({"visits": stats.visits, "distinct": counts[0], "inMatch": counts[1], "elsewhere": counts[2]})
    }

    fn summary(&self) -> Value {
        json!({
            "visits": self.visits, "distinct": self.distinct, "inMatch": self.in_match, "elsewhere": self.elsewhere,
            "matches": self.by_match.len(), "keys": self.all.len(),
        })
    }
}

/// The rows of a chunk of inputs, in input order.
fn rows(args: &Args, pool: &ThreadPool, inputs: &[Input], seen: &mut Seen) -> Vec<Value> {
    let items: Vec<(InfoSet, Option<u32>)> = inputs
        .iter()
        .filter_map(|input| input.info.clone().ok().map(|info| (info, input.chosen)))
        .collect();
    let done: Vec<(Analysis, Option<KeyStats>)> = match args.evaluator {
        #[cfg(feature = "f32")]
        Evaluator::Compat => {
            let searcher = Compat {
                reload: args.reload,
                memo: args.memo,
                pool: Some(pool),
            };
            analyse_batch(&items, pool, |(info, _)| (searcher.analyse(info, args.limits), None))
        }
        Evaluator::BoundedV1 => {
            let searcher = BoundedV1 {
                reload: args.reload,
                prune: !args.unpruned,
                pool: Some(pool),
            };
            analyse_batch(&items, pool, |(info, chosen)| {
                searcher.analyse_chosen(info, args.limits, *chosen, args.stats)
            })
        }
    };
    let mut done = done.into_iter();
    inputs
        .iter()
        .map(|input| match &input.info {
            Ok(_) => match done.next() {
                Some((analysis, stats)) => {
                    let mut row = analysed(&input.id, &input.ordinal, &analysis, args.evaluator);
                    if let (Some(stats), Value::Object(fields)) = (stats, &mut row) {
                        fields.insert("stats".to_owned(), seen.add(&input.id, &stats));
                    }
                    row
                }
                None => json!({"id": input.id, "ordinal": input.ordinal, "error": "no analysis"}),
            },
            Err(error) => json!({"id": input.id, "ordinal": input.ordinal, "error": error}),
        })
        .collect()
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = args()?;
    let mut out = std::io::stdout().lock();
    if args.help {
        write!(out, "{HELP}")?;
        return Ok(());
    }
    let pool = ThreadPoolBuilder::new().num_threads(args.threads).build()?;
    let reader: Box<dyn BufRead> = match &args.path {
        Some(path) => Box::new(BufReader::new(std::fs::File::open(path)?)),
        None => Box::new(std::io::stdin().lock()),
    };
    let mut chunk = Vec::with_capacity(CHUNK);
    let mut seen = Seen::default();
    let mut lines = reader.lines();
    loop {
        let line = lines.next().transpose()?;
        if let Some(line) = &line
            && !line.trim().is_empty()
        {
            chunk.push(input(&serde_json::from_str(line)?));
        }
        if chunk.len() >= CHUNK || (line.is_none() && !chunk.is_empty()) {
            for row in rows(&args, &pool, &chunk, &mut seen) {
                writeln!(out, "{row}")?;
            }
            chunk.clear();
        }
        if line.is_none() {
            if args.stats {
                eprintln!("{}", json!({"summary": seen.summary()}));
            }
            return Ok(());
        }
    }
}
