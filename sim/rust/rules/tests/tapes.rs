//! Replays Bend tapes of the simple machine (sim/bend-mp/test/rust-tapes.mjs)
//! and compares each step's state, request, next state and notes with Bend's.
//!
//! The test is ignored so a plain `cargo test` does not pass without Bend:
//! run `sim/rust/check.sh`, or set `RUST_TAPES` to a directory of `*.jsonl`
//! tapes, each with a `<tape>.manifest.json`, and pass `--include-ignored`.
//! It fails on an empty directory, an unreadable or malformed line, a step
//! without a game, a gap in a game's steps, a game without a terminal line,
//! truncated notes, an arena game that does not reach its end and a count
//! that differs from the manifest. A game stops at its first mismatch, which
//! is printed; games cut by the step cap are counted apart.

#![allow(
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects,
    reason = "a test harness: a malformed tape fails loudly"
)]

use std::collections::HashSet;
use std::fmt::Debug;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

use buckshot_rules::{
    AmountRule, Config, Event, GameEvent, HealthRule, ItemRule, LoadRule, Move, Note, Phase, Request, RoundRules, Secret, ShellRule, State,
    Table, request, start, step_event,
};
use serde_json::{Value, json};

fn tag(x: impl Debug) -> Value {
    json!({ "$": format!("{x:?}") })
}

fn list(items: impl IntoIterator<Item = Value>) -> Value {
    let items: Vec<Value> = items.into_iter().collect();
    items.into_iter().rev().fold(
        json!({ "$": "Nil" }),
        |tail, head| json!({ "$": "Con", "head": head, "tail": tail }),
    )
}

fn maybe(x: Option<Value>) -> Value {
    x.map_or_else(|| json!({ "$": "None" }), |value| json!({ "$": "Some", "value": value }))
}

fn ring<T: Copy>(ring: &buckshot_rules::Ring<T>, f: impl Fn(T) -> Value) -> Value {
    let name = match ring.table() {
        Table::TwoSeats => "Duo",
        Table::ThreeSeats => "Trio",
        Table::FourSeats => "Quad",
    };
    let mut object = serde_json::Map::new();
    object.insert("$".into(), name.into());
    for (seat, value) in ring.entries() {
        object.insert(format!("s{}", seat.index()), f(value));
    }
    Value::Object(object)
}

fn load(l: buckshot_rules::Load) -> Value {
    json!({ "$": "Load", "live": l.live, "blank": l.blank })
}

fn gun(g: buckshot_rules::Gun) -> Value {
    list(g.iter().map(tag))
}

fn deck(d: buckshot_rules::Deck) -> Value {
    list(d.iter().map(|b| json!({ "$": "Batch", "id": b.id, "load": load(b.load) })))
}

fn state(s: &State) -> Value {
    let w = &s.world;
    let slots = |slots: buckshot_rules::Slots| {
        let mut object = serde_json::Map::new();
        object.insert("$".into(), "Slots".into());
        for (slot, item) in slots.entries() {
            object.insert(format!("s{}", slot.index()), maybe(item.map(tag)));
        }
        Value::Object(object)
    };
    let phase = match s.phase {
        Phase::NeedSwap { load: l, shells, i } => json!({ "$": "NeedSwap", "load": load(l), "shells": gun(shells), "i": i }),
        Phase::Idle { seat } => json!({ "$": "Idle", "seat": tag(seat) }),
        Phase::Blocked { holder } => json!({ "$": "Blocked", "holder": maybe(holder.map(tag)) }),
        Phase::NeedTurnAmount { from, passing, winner } => {
            json!({ "$": "NeedTurnAmount", "from": tag(from), "passing": passing, "winner": maybe(winner.map(tag)) })
        }
        Phase::NeedItem { seat, first, second, rest } => {
            json!({ "$": "NeedItem", "seat": tag(seat), "first": tag(first), "second": tag(second), "rest": list(rest.iter().map(tag)) })
        }
        Phase::NeedPhone { seat, owner, slot } => json!({ "$": "NeedPhone", "seat": tag(seat), "owner": tag(owner), "slot": tag(slot) }),
        phase @ (Phase::NeedFirst | Phase::NeedHealth | Phase::NeedAmount | Phase::NeedBatch | Phase::Ended | Phase::Stalled) => tag(phase),
    };
    json!({
        "$": "State",
        "world": {
            "$": "World",
            "before_round": w.before_round, "round_index": w.round_index, "load_index": w.load_index,
            "first_sequence": w.first_sequence, "round_health": w.round_health, "first_turn": tag(w.first_turn),
            "turn": maybe(w.turn.map(tag)), "direction": tag(w.direction), "first_death": maybe(w.first_death.map(tag)),
            "checking_first_death": w.checking_first_death, "item_amount": w.item_amount, "sawed": w.sawed,
            "gun": gun(w.gun), "shown": load(w.shown),
            "decks": { "$": "Decks", "two": deck(w.decks.two), "three": deck(w.decks.three), "four": deck(w.decks.four) },
        },
        "players": ring(&s.players, |p| json!({ "$": "Seat", "health": p.health, "jam": tag(p.jam), "cash": p.cash, "slots": slots(p.slots) })),
        "phase": phase,
        "grabs": {
            "$": "Grabs",
            "distributing": s.grabs.distributing,
            "grabbing": ring(&s.grabs.grabbing, Value::from),
            "holding": ring(&s.grabs.holding, |h| maybe(h.map(tag))),
            "granted": ring(&s.grabs.granted, Value::from),
            "intake": ring(&s.grabs.intake, Value::from),
        },
    })
}

fn move_json(m: Move) -> Value {
    match m {
        Move::Shoot { target } => json!({ "$": "Shoot", "target": tag(target) }),
        Move::Use { item } => json!({ "$": "Use", "item": tag(item) }),
        Move::Jam { target } => json!({ "$": "Jam", "target": tag(target) }),
        Move::Steal { owner, item } => json!({ "$": "Steal", "owner": tag(owner), "item": tag(item) }),
        Move::StealJam { owner, target } => json!({ "$": "StealJam", "owner": tag(owner), "target": tag(target) }),
    }
}

fn request_json(r: &Request) -> Value {
    match r {
        Request::Draw { label, range } => {
            json!({ "$": "Draw", "label": tag(label), "range": { "$": "Range", "lo": range.lo, "extra": range.extra } })
        }
        Request::Choose(menu) => {
            let mut moves = menu.moves().map(|m| move_json(m.to_move()));
            let head = moves.next().unwrap_or(Value::Null);
            json!({ "$": "Choose", "seat": tag(menu.seat()), "moves": { "$": "NonEmpty", "head": head, "tail": list(moves) } })
        }
        Request::Finished => json!({ "$": "Finished" }),
        Request::Stuck => json!({ "$": "Stuck" }),
    }
}

fn event_json(e: GameEvent) -> Value {
    match e {
        GameEvent::RoundBegan { round, health, first } => {
            json!({ "$": "RoundBegan", "round": round, "health": health, "first": tag(first) })
        }
        GameEvent::GrabbingBegan { seats } => json!({ "$": "GrabbingBegan", "seats": list(seats.iter().map(tag)) }),
        GameEvent::Granted { seat, item } => json!({ "$": "Granted", "seat": tag(seat), "item": tag(item) }),
        GameEvent::Placed { seat, slot, item } => json!({ "$": "Placed", "seat": tag(seat), "slot": tag(slot), "item": tag(item) }),
        GameEvent::GrabbingEnded { seat } => json!({ "$": "GrabbingEnded", "seat": tag(seat) }),
        GameEvent::DistributionDone => json!({ "$": "DistributionDone" }),
        GameEvent::Loaded { load: l } => json!({ "$": "Loaded", "load": load(l) }),
        GameEvent::TurnSkipped { seat } => json!({ "$": "TurnSkipped", "seat": tag(seat) }),
        GameEvent::JamLifted { seat } => json!({ "$": "JamLifted", "seat": tag(seat) }),
        GameEvent::TurnGiven { seat } => json!({ "$": "TurnGiven", "seat": tag(seat) }),
        GameEvent::PickedUp { seat } => json!({ "$": "PickedUp", "seat": tag(seat) }),
        GameEvent::Fired {
            shooter,
            target,
            shell,
            captured,
            applied,
            health,
        } => json!({
            "$": "Fired", "shooter": tag(shooter), "target": tag(target), "shell": tag(shell),
            "captured": tag(captured), "applied": applied, "health": health,
        }),
        GameEvent::Died { seat } => json!({ "$": "Died", "seat": tag(seat) }),
        GameEvent::Used { seat, owner, slot, item } => {
            json!({ "$": "Used", "seat": tag(seat), "owner": tag(owner), "slot": tag(slot), "item": tag(item) })
        }
        GameEvent::Healed { seat, health } => json!({ "$": "Healed", "seat": tag(seat), "health": health }),
        GameEvent::Ejected { seat, shell } => json!({ "$": "Ejected", "seat": tag(seat), "shell": tag(shell) }),
        GameEvent::Inverted { seat } => json!({ "$": "Inverted", "seat": tag(seat) }),
        GameEvent::JamApplied { by, target } => json!({ "$": "JamApplied", "by": tag(by), "target": tag(target) }),
        GameEvent::DirectionFlipped { direction } => json!({ "$": "DirectionFlipped", "direction": tag(direction) }),
        GameEvent::RoundWon { seat, prize } => json!({ "$": "RoundWon", "seat": tag(seat), "prize": prize }),
        GameEvent::MatchConcluded => json!({ "$": "MatchConcluded" }),
    }
}

fn note_json(n: &Note) -> Value {
    match *n {
        Note::Shown(e) => json!({ "$": "Shown", "event": event_json(e) }),
        Note::Told { seat, secret } => {
            let secret = match secret {
                Secret::Glimpse { shell } => json!({ "$": "Glimpse", "shell": tag(shell) }),
                Secret::Clue { position, shell } => json!({ "$": "Clue", "position": position, "shell": tag(shell) }),
                Secret::NoClue => json!({ "$": "NoClue" }),
                Secret::EmptyBriefcase => json!({ "$": "EmptyBriefcase" }),
            };
            json!({ "$": "Told", "seat": tag(seat), "secret": secret })
        }
    }
}

// Config decoding
// ===============

fn nat(v: &Value) -> u32 {
    u32::try_from(v.as_u64().expect("a Nat")).expect("a Nat that fits u32")
}

fn pos(v: &Value) -> u32 {
    nat(&v["minus_one"]) + 1
}

fn name(v: &Value) -> &str {
    v["$"].as_str().expect("a constructor")
}

fn round_rules(v: &Value) -> RoundRules {
    let health = match name(&v["health"]) {
        "RandomHealth" => HealthRule::Random,
        "FixedHealth" => HealthRule::Fixed(pos(&v["health"]["health"])),
        other => panic!("health {other}"),
    };
    let load = |l: &Value| {
        let shells = match name(&l["shells"]) {
            "RandomShells" => ShellRule::Random,
            "FixedShells" => ShellRule::Fixed {
                live: nat(&l["shells"]["live"]),
                blank: pos(&l["shells"]["blank"]),
            },
            "AllLive" => ShellRule::AllLive {
                live: pos(&l["shells"]["live"]),
            },
            other => panic!("shells {other}"),
        };
        let items = match name(&l["items"]) {
            "RandomAmount" => AmountRule::Random,
            "FixedAmount" => AmountRule::Fixed(nat(&l["items"]["amount"])),
            other => panic!("amount {other}"),
        };
        LoadRule { shells, items }
    };
    let loads = &v["loads"];
    let item = |field: &str| {
        let r = &v["items"][field];
        ItemRule {
            enabled: r["enabled"].as_bool().expect("a Bool"),
            per_player: nat(&r["per_player"]),
            on_table: nat(&r["on_table"]),
        }
    };
    RoundRules {
        health,
        loads: [load(&loads["l0"]), load(&loads["l1"]), load(&loads["l2"]), load(&loads["l3"])],
        items: [
            "saw",
            "glass",
            "jammer",
            "cigarettes",
            "beer",
            "phone",
            "inverter",
            "adrenaline",
            "remote",
        ]
        .map(item),
    }
}

fn config(v: &Value) -> Config {
    let table = match name(&v["table"]) {
        "TwoSeats" => Table::TwoSeats,
        "ThreeSeats" => Table::ThreeSeats,
        "FourSeats" => Table::FourSeats,
        other => panic!("table {other}"),
    };
    let plan = &v["plan"];
    let rounds: Vec<RoundRules> = ["r0", "r1", "r2"].iter().filter_map(|k| plan.get(*k)).map(round_rules).collect();
    Config::new(table, &rounds).expect("a valid config")
}

/// Drops from a tape's state the config and log, which the Rust state does not hold.
fn strip(v: &mut Value) {
    if let Some(world) = v["world"].as_object_mut() {
        world.remove("config");
    }
    if let Some(object) = v.as_object_mut() {
        object.remove("log");
    }
}

/// The path to the first difference between two JSON values.
fn first_diff(a: &Value, b: &Value, path: &str) -> Option<String> {
    if a == b {
        return None;
    }
    match (a, b) {
        (Value::Object(x), Value::Object(y)) => {
            for key in x.keys().chain(y.keys().filter(|key| !x.contains_key(*key))) {
                if let Some(diff) = first_diff(
                    x.get(key).unwrap_or(&Value::Null),
                    y.get(key).unwrap_or(&Value::Null),
                    &format!("{path}.{key}"),
                ) {
                    return Some(diff);
                }
            }
            None
        }
        _ => Some(format!("{path}: rust {} bend {}", short(a), short(b))),
    }
}

fn short(v: &Value) -> String {
    let s = v.to_string();
    if s.len() > 300 { format!("{}...", &s[..300]) } else { s }
}

#[derive(Default)]
struct Tally {
    games: usize,
    capped: usize,
    lines: usize,
    steps: usize,
    matched: usize,
    problems: Vec<String>,
}

struct Game {
    id: String,
    cfg: Config,
    state: State,
    next_step: u64,
    agrees: bool,
}

fn field<'a>(v: &'a Value, key: &str, at: &str) -> Result<&'a Value, String> {
    v.get(key).ok_or_else(|| format!("{at}: no \"{key}\""))
}

fn replay(path: &Path, tally: &mut Tally) -> Result<(), String> {
    let file = std::fs::File::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut current: Option<Game> = None;
    let mut seen = HashSet::new();
    for (index, line) in BufReader::new(file).lines().enumerate() {
        let at = format!("{}:{}", path.display(), index + 1);
        let line = line.map_err(|e| format!("{at}: {e}"))?;
        let mut v: Value = serde_json::from_str(&line).map_err(|e| format!("{at}: {e}"))?;
        tally.lines += 1;
        let id = field(&v, "game", &at)?
            .as_str()
            .ok_or_else(|| format!("{at}: \"game\" is not a string"))?
            .to_owned();
        let id = id.as_str();
        let step = field(&v, "step", &at)?
            .as_u64()
            .ok_or_else(|| format!("{at}: \"step\" is not a number"))?;
        if v.get("config").is_some() {
            if let Some(unfinished) = &current {
                return Err(format!("{at}: game {} has no terminal line", unfinished.id));
            }
            if step != 0 || !seen.insert(id.to_owned()) {
                return Err(format!("{at}: game {id} starts at step {step} or repeats an earlier game"));
            }
            let cfg = config(&v["config"]);
            let state = start(&cfg).state;
            tally.games += 1;
            current = Some(Game {
                id: id.to_owned(),
                cfg,
                state,
                next_step: 0,
                agrees: true,
            });
        }
        let game = current
            .as_mut()
            .ok_or_else(|| format!("{at}: step line of game {id} without an active game"))?;
        if game.id != id {
            return Err(format!("{at}: line of game {id} while game {} has no terminal line", game.id));
        }
        if step != game.next_step {
            return Err(format!("{at}: game {id} step {step} where step {} was expected", game.next_step));
        }
        game.next_step += 1;
        let terminal = v.get("terminal").is_some();
        if !terminal {
            tally.steps += 1;
        }
        if game.agrees {
            match compare(game, &mut v, terminal, &at) {
                Ok(()) => {}
                Err(mismatch) => {
                    tally.problems.push(mismatch);
                    game.agrees = false;
                }
            }
        }
        if game.agrees && !terminal {
            tally.matched += 1;
        }
        if terminal {
            let capped = v.get("capped").is_some_and(|c| c == true);
            let open = !matches!(v["request"]["$"].as_str(), Some("Finished" | "Stuck"));
            if capped != open {
                return Err(format!(
                    "{at}: game {id} ends on a {} request but capped is {capped}",
                    v["request"]["$"]
                ));
            }
            tally.capped += usize::from(capped);
            let arena = v.get("arena");
            if id.starts_with("arena-") != arena.is_some() {
                return Err(format!("{at}: game {id} and its arena report do not go together"));
            }
            if let Some(report) = arena
                && report["ended"] != true
            {
                tally
                    .problems
                    .push(format!("{id}: the arena game does not reach its recorded end: {}", short(report)));
            }
            current = None;
        }
    }
    match current {
        Some(unfinished) => Err(format!("{}: game {} has no terminal line", path.display(), unfinished.id)),
        None => Ok(()),
    }
}

/// Compares one line with Rust's state, request and (for a step) next state and notes; advances the game on a step.
fn compare(game: &mut Game, v: &mut Value, terminal: bool, at: &str) -> Result<(), String> {
    let mismatch = |what: &str, diff: String| format!("{at} {} {what}: {diff}", game.id);
    if game.next_step == 1 {
        strip(&mut v["state"]);
        if let Some(diff) = first_diff(&state(&game.state), &v["state"], "state") {
            return Err(mismatch("state", diff));
        }
    }
    if let Some(diff) = first_diff(&request_json(&request(&game.cfg, &game.state)), &v["request"], "request") {
        return Err(mismatch("request", diff));
    }
    if terminal {
        return Ok(());
    }
    let n = nat(&v["event"]["n"]);
    let event = if v["event"]["kind"] == "Draw" {
        Event::Draw(n)
    } else {
        Event::Choose(n)
    };
    let stepped = step_event(&game.cfg, game.state, event).map_err(|error| mismatch("answer", error.to_string()))?;
    if stepped.notes.truncated() {
        return Err(mismatch("notes", "Rust's notes were truncated".into()));
    }
    let notes = list(stepped.notes.as_slice().iter().map(note_json));
    strip(&mut v["next"]);
    if let Some(diff) = first_diff(&state(&stepped.state), &v["next"], "next") {
        return Err(mismatch("next", diff));
    }
    if let Some(diff) = first_diff(&notes, &v["notes"], "notes") {
        return Err(mismatch("notes", diff));
    }
    game.state = stepped.state;
    Ok(())
}

fn check_manifest(path: &Path, tally: &mut Tally) -> Result<String, String> {
    let manifest_path = format!("{}.manifest.json", path.display());
    let text = std::fs::read_to_string(&manifest_path).map_err(|e| format!("{manifest_path}: {e}"))?;
    let manifest: Value = serde_json::from_str(&text).map_err(|e| format!("{manifest_path}: {e}"))?;
    for (key, got) in [
        ("games", tally.games),
        ("steps", tally.steps),
        ("capped", tally.capped),
        ("lines", tally.lines),
    ] {
        if manifest[key].as_u64() != u64::try_from(got).ok() {
            tally
                .problems
                .push(format!("manifest {key} {} but the tape has {got}", manifest[key]));
        }
    }
    if tally.games == 0 {
        tally.problems.push("the tape has no games".into());
    }
    Ok(format!(
        "{} from {} Bend files, sha256 {}",
        manifest["mode"].as_str().unwrap_or("?"),
        manifest["bend"]["files"],
        manifest["bend"]["sha256"].as_str().unwrap_or("?")
    ))
}

#[test]
#[ignore = "needs RUST_TAPES; run sim/rust/check.sh"]
fn tapes_match_bend() {
    let dir = std::env::var("RUST_TAPES").expect("RUST_TAPES must name a directory of Bend tapes; run sim/rust/check.sh");
    let mut paths: Vec<PathBuf> = std::fs::read_dir(&dir)
        .expect("RUST_TAPES is a readable directory")
        .map(|entry| entry.expect("a readable directory entry").path())
        .filter(|path| path.extension().is_some_and(|x| x == "jsonl"))
        .collect();
    paths.sort();
    assert!(!paths.is_empty(), "no *.jsonl tapes in {dir}");
    let mut failed = false;
    let (mut games, mut capped, mut matched) = (0, 0, 0);
    for path in paths {
        let mut tally = Tally::default();
        if let Err(error) = replay(&path, &mut tally) {
            tally.problems.push(error);
        }
        let source = check_manifest(&path, &mut tally).unwrap_or_else(|error| {
            tally.problems.push(error);
            String::from("no manifest")
        });
        println!(
            "{}: {} games ({} capped), {} of {} Bend steps matched [{source}]",
            path.display(),
            tally.games,
            tally.capped,
            tally.matched,
            tally.steps
        );
        for problem in &tally.problems {
            println!("  {problem}");
        }
        failed |= !tally.problems.is_empty() || tally.matched != tally.steps;
        games += tally.games;
        capped += tally.capped;
        matched += tally.matched;
    }
    println!("total: {games} games ({capped} capped), {matched} genuine Bend steps compared");
    assert!(!failed, "the Rust machine differs from Bend's tapes (see above)");
}
