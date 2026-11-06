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
//!
//! With the `trace` feature (`cargo trace-test`) each tape also needs a
//! `<tape>.trace` from `bend-trace.mjs`: the Bend branches each call took, one
//! row per tape line. They are compared with the branches Rust took, as counts
//! per label: Bend binds before it enters an arm, so the order differs.

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::fmt::Debug;
use std::fs::File;
use std::io::{BufRead, BufReader, Lines};
use std::path::{Path, PathBuf};

use buckshot_rules::{
    AmountRule, Config, Event, FirstDeathCheck, GameEvent, HealthRule, ItemRule, LoadRule, Move, Note, Phase, Request, RoundRules, Secret,
    ShellRule, State, Table, request, start, step_event,
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
            "checking_first_death": w.checking_first_death == FirstDeathCheck::On, "item_amount": w.item_amount, "sawed": w.sawed,
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

fn get<'a>(v: &'a Value, key: &str) -> &'a Value {
    v.get(key).unwrap_or(&Value::Null)
}

fn dig<'a>(v: &'a Value, keys: &[&str]) -> &'a Value {
    keys.iter().fold(v, |v, key| get(v, key))
}

fn nat(v: &Value) -> Result<u32, String> {
    v.as_u64()
        .and_then(|n| u32::try_from(n).ok())
        .ok_or_else(|| format!("{} is not a Nat that fits u32", short(v)))
}

fn pos(v: &Value) -> Result<u32, String> {
    nat(get(v, "minus_one"))?
        .checked_add(1)
        .ok_or_else(|| format!("{} is not a Pos", short(v)))
}

fn name(v: &Value) -> Result<&str, String> {
    get(v, "$").as_str().ok_or_else(|| format!("{} is not a constructor", short(v)))
}

fn load_rule(l: &Value) -> Result<LoadRule, String> {
    let shells = get(l, "shells");
    let shells = match name(shells)? {
        "RandomShells" => ShellRule::Random,
        "FixedShells" => ShellRule::Fixed {
            live: nat(get(shells, "live"))?,
            blank: pos(get(shells, "blank"))?,
        },
        "AllLive" => ShellRule::AllLive {
            live: pos(get(shells, "live"))?,
        },
        other => return Err(format!("shells {other}")),
    };
    let items = get(l, "items");
    let items = match name(items)? {
        "RandomAmount" => AmountRule::Random,
        "FixedAmount" => AmountRule::Fixed(nat(get(items, "amount"))?),
        other => return Err(format!("amount {other}")),
    };
    Ok(LoadRule { shells, items })
}

fn item_rule(v: &Value, field: &str) -> Result<ItemRule, String> {
    let r = dig(v, &["items", field]);
    Ok(ItemRule {
        enabled: get(r, "enabled").as_bool().ok_or("enabled is not a Bool")?,
        per_player: nat(get(r, "per_player"))?,
        on_table: nat(get(r, "on_table"))?,
    })
}

fn round_rules(v: &Value) -> Result<RoundRules, String> {
    let health = get(v, "health");
    let health = match name(health)? {
        "RandomHealth" => HealthRule::Random,
        "FixedHealth" => HealthRule::Fixed(pos(get(health, "health"))?),
        other => return Err(format!("health {other}")),
    };
    let load = |key: &str| load_rule(dig(v, &["loads", key]));
    let mut items = Vec::new();
    for field in [
        "saw",
        "glass",
        "jammer",
        "cigarettes",
        "beer",
        "phone",
        "inverter",
        "adrenaline",
        "remote",
    ] {
        items.push(item_rule(v, field)?);
    }
    Ok(RoundRules {
        health,
        loads: [load("l0")?, load("l1")?, load("l2")?, load("l3")?],
        items: items.try_into().map_err(|_items| "nine items")?,
    })
}

fn config(v: &Value) -> Result<Config, String> {
    let table = match name(get(v, "table"))? {
        "TwoSeats" => Table::TwoSeats,
        "ThreeSeats" => Table::ThreeSeats,
        "FourSeats" => Table::FourSeats,
        other => return Err(format!("table {other}")),
    };
    let plan = get(v, "plan");
    let rounds = ["r0", "r1", "r2"]
        .iter()
        .filter_map(|key| plan.get(*key))
        .map(round_rules)
        .collect::<Result<Vec<_>, _>>()?;
    Config::new(table, &rounds).map_err(|e| e.to_string())
}

/// Takes the state at `key` out of a tape line, without the config and log, which the Rust state does not hold.
fn take_state(line: &mut Value, key: &str) -> Value {
    let mut v = line.get_mut(key).map(Value::take).unwrap_or_default();
    if let Some(world) = v.get_mut("world").and_then(Value::as_object_mut) {
        world.remove("config");
    }
    if let Some(object) = v.as_object_mut() {
        object.remove("log");
    }
    v
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
    if s.chars().count() > 300 {
        format!("{}...", s.chars().take(300).collect::<String>())
    } else {
        s
    }
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

fn bump(n: &mut usize) {
    *n = n.saturating_add(1);
}

fn take_trace() -> Vec<&'static str> {
    #[cfg(feature = "trace")]
    {
        buckshot_rules::take_trace()
    }
    #[cfg(not(feature = "trace"))]
    {
        Vec::new()
    }
}

/// The rows of a tape's `.trace` file, the labels either side has reached and
/// the calls whose label counts differ.
#[derive(Default)]
struct Trace {
    rows: Option<Lines<BufReader<File>>>,
    bend: BTreeSet<String>,
    rust: BTreeSet<&'static str>,
    calls: usize,
    differing: usize,
    examples: Vec<String>,
    labels: BTreeMap<String, usize>,
}

impl Trace {
    fn open(tape: &Path) -> Result<Self, String> {
        if !cfg!(feature = "trace") {
            return Ok(Self::default());
        }
        let path = format!("{}.trace", tape.display());
        let file = File::open(&path).map_err(|e| format!("{path}: {e}"))?;
        Ok(Self {
            rows: Some(BufReader::new(file).lines()),
            ..Self::default()
        })
    }

    /// The row of the tape line `game` `step`; `None` without the `trace` feature.
    fn row(&mut self, game: &str, step: u64) -> Result<Option<Value>, String> {
        let Some(rows) = &mut self.rows else { return Ok(None) };
        let line = rows
            .next()
            .ok_or_else(|| format!("the trace has no row for {game} step {step}"))?
            .map_err(|e| format!("trace: {e}"))?;
        let row: Value = serde_json::from_str(&line).map_err(|e| format!("trace: {e}"))?;
        if get(&row, "game") != game || get(&row, "step") != step {
            return Err(format!(
                "trace row {} step {} where {game} step {step} was expected",
                get(&row, "game"),
                get(&row, "step")
            ));
        }
        Ok(Some(row))
    }

    fn finish(&mut self) -> Result<(), String> {
        match self.rows.as_mut().and_then(Iterator::next) {
            Some(_) => Err("the trace has more rows than the tape has lines".into()),
            None => Ok(()),
        }
    }

    /// Compares the labels Rust took in one call with the row's `call` entry and records a difference.
    fn check(&mut self, row: Option<&Value>, call: &str, rust: &[&'static str], at: &str) -> Result<(), String> {
        let Some(row) = row else { return Ok(()) };
        let bend = row
            .get(call)
            .and_then(Value::as_object)
            .ok_or_else(|| format!("{at}: the trace row has no \"{call}\" entry"))?;
        let mut counts: BTreeMap<&str, (u64, u64)> = BTreeMap::new();
        for label in rust {
            let rust_count = &mut counts.entry(label).or_default().0;
            *rust_count = rust_count.saturating_add(1);
        }
        for (label, n) in bend {
            counts.entry(label).or_default().1 = n.as_u64().ok_or_else(|| format!("{at}: bad count for {label}"))?;
        }
        self.bend.extend(bend.keys().cloned());
        self.rust.extend(rust.iter().copied());
        bump(&mut self.calls);
        let differing: Vec<(&str, u64, u64)> = counts
            .iter()
            .filter(|(_, (rust_count, bend_count))| rust_count != bend_count)
            .map(|(label, (rust_count, bend_count))| (*label, *bend_count, *rust_count))
            .collect();
        if !differing.is_empty() {
            bump(&mut self.differing);
            for (label, _, _) in &differing {
                bump(self.labels.entry(format!("{call} {label}")).or_default());
            }
            if self.examples.len() < 3 {
                let labels: Vec<String> = differing
                    .iter()
                    .map(|(label, bend_count, rust_count)| format!("{label} bend {bend_count} rust {rust_count}"))
                    .collect();
                self.examples.push(format!("{at} {call} branches differ: {}", labels.join("; ")));
            }
        }
        Ok(())
    }

    fn summary(&self) -> Option<String> {
        if self.differing == 0 {
            return None;
        }
        let mut labels: Vec<(&String, &usize)> = self.labels.iter().collect();
        labels.sort_by(|a, b| b.1.cmp(a.1));
        let top: Vec<String> = labels.iter().take(8).map(|(label, n)| format!("{label} ({n})")).collect();
        Some(format!(
            "trace: {} of {} calls take different branch counts; most often {}; first {:?}",
            self.differing,
            self.calls,
            top.join(", "),
            self.examples
        ))
    }
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

fn replay(path: &Path, tally: &mut Tally, trace: &mut Trace) -> Result<(), String> {
    let file = File::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut current: Option<Game> = None;
    let mut seen = HashSet::new();
    for (index, line) in BufReader::new(file).lines().enumerate() {
        let at = format!("{}:{}", path.display(), index.saturating_add(1));
        let line = line.map_err(|e| format!("{at}: {e}"))?;
        let mut v: Value = serde_json::from_str(&line).map_err(|e| format!("{at}: {e}"))?;
        bump(&mut tally.lines);
        let id = field(&v, "game", &at)?
            .as_str()
            .ok_or_else(|| format!("{at}: \"game\" is not a string"))?
            .to_owned();
        let id = id.as_str();
        let step = field(&v, "step", &at)?
            .as_u64()
            .ok_or_else(|| format!("{at}: \"step\" is not a number"))?;
        let mut started = Vec::new();
        if v.get("config").is_some() {
            if let Some(unfinished) = &current {
                return Err(format!("{at}: game {} has no terminal line", unfinished.id));
            }
            if step != 0 || !seen.insert(id.to_owned()) {
                return Err(format!("{at}: game {id} starts at step {step} or repeats an earlier game"));
            }
            let cfg = config(get(&v, "config")).map_err(|e| format!("{at}: {id}: {e}"))?;
            take_trace();
            let state = start(&cfg).state;
            started = take_trace();
            bump(&mut tally.games);
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
        game.next_step = game.next_step.saturating_add(1);
        let terminal = v.get("terminal").is_some();
        if !terminal {
            bump(&mut tally.steps);
        }
        let row = trace.row(id, step)?;
        if game.agrees {
            let started = if step == 0 {
                trace.check(row.as_ref(), "start", &started, &format!("{at} {id}"))
            } else {
                Ok(())
            };
            match started
                .map_err(|diff| format!("{at} {id} {diff}"))
                .and_then(|()| compare(game, &mut v, terminal, &at, row.as_ref(), trace))
            {
                Ok(()) => {}
                Err(mismatch) => {
                    tally.problems.push(mismatch);
                    game.agrees = false;
                }
            }
        }
        if game.agrees && !terminal {
            bump(&mut tally.matched);
        }
        if terminal {
            let capped = v.get("capped").is_some_and(|c| c == true);
            let ended_on = dig(&v, &["request", "$"]);
            let open = !matches!(ended_on.as_str(), Some("Finished" | "Stuck"));
            if capped != open {
                return Err(format!("{at}: game {id} ends on a {ended_on} request but capped is {capped}"));
            }
            tally.capped = tally.capped.saturating_add(usize::from(capped));
            let arena = v.get("arena");
            if id.starts_with("arena-") != arena.is_some() {
                return Err(format!("{at}: game {id} and its arena report do not go together"));
            }
            if let Some(report) = arena
                && get(report, "ended") != true
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
        None => trace.finish(),
    }
}

/// Compares one line with Rust's state, request and (for a step) next state and notes; advances the game on a step.
fn compare(game: &mut Game, v: &mut Value, terminal: bool, at: &str, row: Option<&Value>, trace: &mut Trace) -> Result<(), String> {
    let mismatch = |what: &str, diff: String| format!("{at} {} {what}: {diff}", game.id);
    if game.next_step == 1 {
        let bend = take_state(v, "state");
        if let Some(diff) = first_diff(&state(&game.state), &bend, "state") {
            return Err(mismatch("state", diff));
        }
    }
    take_trace();
    let asked = request(&game.cfg, &game.state);
    trace.check(row, "request", &take_trace(), &format!("{at} {}", game.id))?;
    if let Some(diff) = first_diff(&request_json(&asked), get(v, "request"), "request") {
        return Err(mismatch("request", diff));
    }
    if terminal {
        return Ok(());
    }
    let n = nat(dig(v, &["event", "n"]))?;
    let event = if dig(v, &["event", "kind"]) == "Draw" {
        Event::Draw(n)
    } else {
        Event::Choose(n)
    };
    take_trace();
    let stepped = step_event(&game.cfg, game.state, event).map_err(|error| mismatch("answer", error.to_string()))?;
    trace.check(row, "answer", &take_trace(), &format!("{at} {}", game.id))?;
    if stepped.notes.truncated() {
        return Err(mismatch("notes", "Rust's notes were truncated".into()));
    }
    let notes = list(stepped.notes.as_slice().iter().map(note_json));
    let bend = take_state(v, "next");
    if let Some(diff) = first_diff(&state(&stepped.state), &bend, "next") {
        return Err(mismatch("next", diff));
    }
    if let Some(diff) = first_diff(&notes, get(v, "notes"), "notes") {
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
        if get(&manifest, key).as_u64() != u64::try_from(got).ok() {
            tally
                .problems
                .push(format!("manifest {key} {} but the tape has {got}", get(&manifest, key)));
        }
    }
    if tally.games == 0 {
        tally.problems.push("the tape has no games".into());
    }
    Ok(format!(
        "{} from {} Bend files, sha256 {}",
        get(&manifest, "mode").as_str().unwrap_or("?"),
        dig(&manifest, &["bend", "files"]),
        dig(&manifest, &["bend", "sha256"]).as_str().unwrap_or("?")
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
    let (mut bend_labels, mut rust_labels) = (BTreeSet::new(), BTreeSet::<&str>::new());
    for path in paths {
        let mut tally = Tally::default();
        let replayed = Trace::open(&path).and_then(|mut trace| {
            replay(&path, &mut tally, &mut trace)?;
            bend_labels.extend(trace.bend.iter().cloned());
            rust_labels.extend(trace.rust.iter().copied());
            tally.problems.extend(trace.summary());
            Ok(())
        });
        if let Err(error) = replayed {
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
    if cfg!(feature = "trace") {
        let bend_only: Vec<&String> = bend_labels.iter().filter(|label| !rust_labels.contains(label.as_str())).collect();
        let rust_only: Vec<&&str> = rust_labels.iter().filter(|label| !bend_labels.contains(**label)).collect();
        println!(
            "branches reached: {} by Bend, {} by Rust; Bend only {bend_only:?}; Rust only {rust_only:?}",
            bend_labels.len(),
            rust_labels.len()
        );
    }
    assert!(!failed, "the Rust machine differs from Bend's tapes (see above)");
}
