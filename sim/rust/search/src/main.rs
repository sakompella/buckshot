//! `buckshot-search [--depth N] [--budget N] [--reload static|sampled]
//! [--samples N] [--memo off|charged|free] [inputs.jsonl]`: one analysis row
//! per input decision, read from the path or stdin.

use std::error::Error;
use std::io::{BufRead, BufReader, Write};

use buckshot_search::{Analysis, Memo, Reload, analyse, parse};
use serde_json::{Value, json};

struct Args {
    depth: u32,
    budget: u64,
    reload: Reload,
    memo: Memo,
    path: Option<String>,
}

fn args() -> Result<Args, Box<dyn Error>> {
    let mut args = Args {
        depth: 6,
        budget: 20_000,
        reload: Reload::Static,
        memo: Memo::Off,
        path: None,
    };
    let mut sampled = false;
    let mut count = 256;
    let mut words = std::env::args().skip(1);
    while let Some(word) = words.next() {
        let mut value = || words.next().ok_or_else(|| format!("{word} needs a value"));
        match word.as_str() {
            "--depth" => args.depth = value()?.parse()?,
            "--budget" => args.budget = value()?.parse()?,
            "--samples" => count = value()?.parse()?,
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

fn row(args: &Args, input: &Value) -> Value {
    let (id, ordinal) = (&input["id"], &input["ordinal"]);
    let Some(line) = input["input"].as_str() else {
        return json!({"id": id, "ordinal": ordinal, "error": "no input"});
    };
    let position = match parse(line) {
        Ok(position) => position,
        Err(error) => return json!({"id": id, "ordinal": ordinal, "error": error.to_string()}),
    };
    match analyse(&position, args.depth, args.budget, args.reload, args.memo) {
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

fn main() -> Result<(), Box<dyn Error>> {
    let args = args()?;
    let reader: Box<dyn BufRead> = match &args.path {
        Some(path) => Box::new(BufReader::new(std::fs::File::open(path)?)),
        None => Box::new(std::io::stdin().lock()),
    };
    let mut out = std::io::stdout().lock();
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let input: Value = serde_json::from_str(&line)?;
        writeln!(out, "{}", row(&args, &input))?;
    }
    Ok(())
}
