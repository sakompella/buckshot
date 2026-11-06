//! The CLI: one analysis row per input decision, read from a jsonl path or stdin.

use std::error::Error;
use std::io::{BufRead, BufReader, Write};

use buckshot_search::{Analysis, Limits, Memo, Position, Reload, analyse_batch, parse};
use rayon::{ThreadPool, ThreadPoolBuilder};
use serde_json::{Value, json};

const HELP: &str = "\
buckshot-search [options] [inputs.jsonl]

One JSON row per input decision ({id, ordinal, input}), read from the path or stdin.

  --depth N              decisions deep (6)
  --budget N             nodes per decision (20000)
  --reload static|sampled
                         how a leaf at a reload is valued (static)
  --samples N            deals per sampled leaf (256)
  --memo off|charged|free
                         how a finished node is reused (off)
  --threads N            worker threads (half the cores, at least 1)

The decisions run in parallel on a pool of --threads workers (never rayon's
global pool), and so do the deals of a sampled leaf. Each decision's root
moves run one after another: they share the fuel, the node budget and the
memo, so a move's result depends on the moves before it. Every row is the one
a single thread gives, in input order.
";

/// Decisions read and analysed at a time.
const CHUNK: usize = 512;

struct Args {
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
    Ok(args)
}

/// An input's id and ordinal, and its position or why it has none.
struct Input {
    id: Value,
    ordinal: Value,
    position: Result<Position, String>,
}

fn input(row: &Value) -> Input {
    let position = match row["input"].as_str() {
        Some(line) => parse(line).map_err(|error| error.to_string()),
        None => Err("no input".to_owned()),
    };
    Input {
        id: row["id"].clone(),
        ordinal: row["ordinal"].clone(),
        position,
    }
}

fn analysed(id: &Value, ordinal: &Value, analysis: &Analysis) -> Value {
    match analysis {
        Analysis::Analysed(done) => {
            let lines: Vec<Value> = done
                .lines
                .iter()
                .map(|l| json!({"score": l.score, "reach": l.reach.name()}))
                .collect();
            json!({
                "id": id, "ordinal": ordinal, "lines": lines, "best": done.best, "nodes": done.nodes,
                "depth": done.depth, "limited": done.limited,
                "entries": done.cached.entries, "hits": done.cached.hits,
                "deals": done.cached.deals, "dealHits": done.cached.deal_hits,
            })
        }
        Analysis::Invalid { reason, nodes } => json!({"id": id, "ordinal": ordinal, "error": reason, "nodes": nodes}),
    }
}

/// The rows of a chunk of inputs, in input order.
fn rows(args: &Args, pool: &ThreadPool, inputs: &[Input]) -> Vec<Value> {
    let positions: Vec<Position> = inputs.iter().filter_map(|input| input.position.clone().ok()).collect();
    let mut done = analyse_batch(&positions, args.limits, args.reload, args.memo, pool).into_iter();
    inputs
        .iter()
        .map(|input| match &input.position {
            Ok(_) => match done.next() {
                Some(analysis) => analysed(&input.id, &input.ordinal, &analysis),
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
    let mut lines = reader.lines();
    loop {
        let line = lines.next().transpose()?;
        if let Some(line) = &line
            && !line.trim().is_empty()
        {
            chunk.push(input(&serde_json::from_str(line)?));
        }
        if chunk.len() >= CHUNK || (line.is_none() && !chunk.is_empty()) {
            for row in rows(&args, &pool, &chunk) {
                writeln!(out, "{row}")?;
            }
            chunk.clear();
        }
        if line.is_none() {
            return Ok(());
        }
    }
}
