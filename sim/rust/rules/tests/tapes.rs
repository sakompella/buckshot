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
//! per label. Bend is strict and also counts branches of work it discards, so the test is
//! that every branch Rust takes in a call, Bend takes too; the counts are reported.
//! It needs the run's `traced/labels.json`, and the labels the trace cannot
//! see or no tape reaches must be the reviewed ones in `trace-coverage.json`.

use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::fmt::Debug;
use std::fs::File;
use std::io::{BufRead, BufReader, Lines};
use std::path::{Path, PathBuf};

use buckshot_rules::{
    AmountRule, Config, Deck, Decks, Direction, Event, FirstDeathCheck, GameEvent, Grabs, Gun, HealthRule, Item, ItemRule, Items, Jam,
    Load, LoadRule, Move, Note, Phase, Request, Ring, RoundRules, Seat, SeatRecord, Secret, Shell, ShellRule, Slot, Slots, State, Table,
    World, request, start, step_event,
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
        #[cfg(feature = "seats-2-4")]
        Table::ThreeSeats => "Trio",
        #[cfg(feature = "seats-2-4")]
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
        object.insert("boxed".into(), json!({ "$": "Boxed" }));
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
            "decks": decks(w.decks),
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

/// The config, and whether this build has its table. A table the build
/// lacks gets a two-seat stand-in for a game that is skipped.
fn config(v: &Value) -> Result<(Config, bool), String> {
    let (table, built) = match name(get(v, "table"))? {
        "TwoSeats" => (Table::TwoSeats, true),
        #[cfg(feature = "seats-2-4")]
        "ThreeSeats" => (Table::ThreeSeats, true),
        #[cfg(feature = "seats-2-4")]
        "FourSeats" => (Table::FourSeats, true),
        #[cfg(not(feature = "seats-2-4"))]
        "ThreeSeats" | "FourSeats" => (Table::TwoSeats, false),
        other => return Err(format!("table {other}")),
    };
    let plan = get(v, "plan");
    let rounds = ["r0", "r1", "r2"]
        .iter()
        .filter_map(|key| plan.get(*key))
        .map(round_rules)
        .collect::<Result<Vec<_>, _>>()?;
    Ok((Config::new(table, &rounds).map_err(|e| e.to_string())?, built))
}

// State decoding, for games that start from a perturbed state
// ============================================================

fn tag_of<T: Copy + Debug>(v: &Value, all: &[T]) -> Result<T, String> {
    let n = name(v)?;
    all.iter()
        .copied()
        .find(|x| format!("{x:?}") == n)
        .ok_or_else(|| format!("unknown {n}"))
}

const SEATS: [Seat; 4] = [Seat::Seat0, Seat::Seat1, Seat::Seat2, Seat::Seat3];

fn boolean(v: &Value) -> Result<bool, String> {
    v.as_bool().ok_or_else(|| format!("{} is not a Bool", short(v)))
}

fn cons(v: &Value) -> Result<Vec<&Value>, String> {
    let mut out = Vec::new();
    let mut at = v;
    loop {
        match name(at)? {
            "Nil" => return Ok(out),
            "Con" => {
                out.push(get(at, "head"));
                at = get(at, "tail");
            }
            other => return Err(format!("list {other}")),
        }
    }
}

fn maybe_of<T>(v: &Value, f: impl Fn(&Value) -> Result<T, String>) -> Result<Option<T>, String> {
    match name(v)? {
        "None" => Ok(None),
        "Some" => f(get(v, "value")).map(Some),
        other => Err(format!("option {other}")),
    }
}

fn seat_of(v: &Value) -> Result<Seat, String> {
    tag_of(v, &SEATS)
}

fn load_of(v: &Value) -> Result<Load, String> {
    Ok(Load {
        live: nat(get(v, "live"))?,
        blank: nat(get(v, "blank"))?,
    })
}

fn gun_of(v: &Value) -> Result<Gun, String> {
    let shells = cons(v)?
        .into_iter()
        .map(|shell| tag_of(shell, &[Shell::Live, Shell::Blank]))
        .collect::<Result<Vec<_>, _>>()?;
    Gun::from_shells(shells).ok_or_else(|| format!("a gun past {} shells", Gun::CAPACITY))
}

fn item_of(v: &Value) -> Result<Item, String> {
    tag_of(v, &Item::ORDER)
}

fn deck_of(table: Table, v: &Value) -> Result<Deck, String> {
    let ids = cons(v)?
        .into_iter()
        .map(|batch| nat(get(batch, "id")))
        .collect::<Result<Vec<_>, _>>()?;
    Deck::of_ids(table, ids).ok_or_else(|| String::from("a batch id past the table's deck"))
}

fn ring_of<T: Copy>(table: Table, v: &Value, fill: T, f: impl Fn(&Value) -> Result<T, String>) -> Result<Ring<T>, String> {
    let object = v.as_object().ok_or("a ring is not an object")?;
    let mut ring = Ring::fill(table, fill);
    for (key, value) in object.iter().filter(|(key, _)| key.as_str() != "$") {
        let seat = key
            .strip_prefix('s')
            .and_then(|n| n.parse::<usize>().ok())
            .and_then(|n| SEATS.get(n))
            .ok_or_else(|| format!("ring key {key}"))?;
        ring = ring.set(*seat, f(value)?);
    }
    Ok(ring)
}

fn slots_of(v: &Value) -> Result<Slots, String> {
    let mut slots = Slots::EMPTY;
    for slot in Slot::ORDER {
        slots = slots.put(slot, maybe_of(get(v, &format!("s{}", slot.index())), item_of)?);
    }
    Ok(slots)
}

fn phase_of(v: &Value) -> Result<Phase, String> {
    let seat = |key: &str| seat_of(get(v, key));
    Ok(match name(v)? {
        "NeedFirst" => Phase::NeedFirst,
        "NeedHealth" => Phase::NeedHealth,
        "NeedAmount" => Phase::NeedAmount,
        "NeedBatch" => Phase::NeedBatch,
        "Ended" => Phase::Ended,
        "Stalled" => Phase::Stalled,
        "NeedSwap" => Phase::NeedSwap {
            load: load_of(get(v, "load"))?,
            shells: gun_of(get(v, "shells"))?,
            i: nat(get(v, "i"))?,
        },
        "Idle" => Phase::Idle { seat: seat("seat")? },
        "Blocked" => Phase::Blocked {
            holder: maybe_of(get(v, "holder"), seat_of)?,
        },
        "NeedTurnAmount" => Phase::NeedTurnAmount {
            from: seat("from")?,
            passing: boolean(get(v, "passing"))?,
            winner: maybe_of(get(v, "winner"), seat_of)?,
        },
        "NeedItem" => Phase::NeedItem {
            seat: seat("seat")?,
            first: item_of(get(v, "first"))?,
            second: item_of(get(v, "second"))?,
            rest: cons(get(v, "rest"))?
                .into_iter()
                .try_fold(Items::EMPTY, |rest, item| item_of(item).map(|item| rest.with(item)))?,
        },
        "NeedPhone" => Phase::NeedPhone {
            seat: seat("seat")?,
            owner: seat("owner")?,
            slot: tag_of(get(v, "slot"), &Slot::ORDER)?,
        },
        other => return Err(format!("phase {other}")),
    })
}

/// The Rust state of a tape's state, which may be one no game reaches. It
/// need not be representable: the caller compares it back with the tape's.
fn state_of(table: Table, v: &Value) -> Result<State, String> {
    let w = get(v, "world");
    let g = get(v, "grabs");
    let decks = get(w, "decks");
    let seat_record = |p: &Value| {
        Ok(SeatRecord {
            health: nat(get(p, "health"))?,
            jam: tag_of(get(p, "jam"), &[Jam::Free, Jam::Jammed, Jam::JammedSkipped])?,
            cash: nat(get(p, "cash"))?,
            slots: slots_of(get(p, "slots"))?,
        })
    };
    Ok(State {
        world: World {
            before_round: boolean(get(w, "before_round"))?,
            round_index: nat(get(w, "round_index"))?,
            load_index: nat(get(w, "load_index"))?,
            first_sequence: boolean(get(w, "first_sequence"))?,
            round_health: nat(get(w, "round_health"))?,
            first_turn: seat_of(get(w, "first_turn"))?,
            turn: maybe_of(get(w, "turn"), seat_of)?,
            direction: tag_of(get(w, "direction"), &[Direction::Clockwise, Direction::CounterClockwise])?,
            first_death: maybe_of(get(w, "first_death"), seat_of)?,
            checking_first_death: if boolean(get(w, "checking_first_death"))? {
                FirstDeathCheck::On
            } else {
                FirstDeathCheck::Off
            },
            item_amount: nat(get(w, "item_amount"))?,
            sawed: boolean(get(w, "sawed"))?,
            gun: gun_of(get(w, "gun"))?,
            shown: load_of(get(w, "shown"))?,
            decks: Decks {
                two: deck_of(Table::TwoSeats, get(decks, "two"))?,
                #[cfg(feature = "seats-2-4")]
                three: deck_of(Table::ThreeSeats, get(decks, "three"))?,
                #[cfg(feature = "seats-2-4")]
                four: deck_of(Table::FourSeats, get(decks, "four"))?,
            },
        },
        players: ring_of(table, get(v, "players"), SeatRecord::FRESH, seat_record)?,
        grabs: Grabs {
            distributing: boolean(get(g, "distributing"))?,
            grabbing: ring_of(table, get(g, "grabbing"), false, boolean)?,
            holding: ring_of(table, get(g, "holding"), None, |h| maybe_of(h, item_of))?,
            granted: ring_of(table, get(g, "granted"), 0, nat)?,
            intake: ring_of(table, get(g, "intake"), false, boolean)?,
        },
        phase: phase_of(get(v, "phase"))?,
    })
}

/// Takes the state at `key` out of a tape line, without the config and log, which the Rust state does not hold.
#[cfg(feature = "seats-2-4")]
fn decks(decks: Decks) -> Value {
    json!({ "$": "Decks", "two": deck(decks.two), "three": deck(decks.three), "four": deck(decks.four) })
}

#[cfg(not(feature = "seats-2-4"))]
fn decks(decks: Decks) -> Value {
    json!({ "$": "Decks", "two": deck(decks.two) })
}

fn take_state(line: &mut Value, key: &str) -> Value {
    let mut v = line.get_mut(key).map(Value::take).unwrap_or_default();
    // The seats-2 build has no three- and four-seat decks; a two-seat game
    // never draws from them.
    #[cfg(not(feature = "seats-2-4"))]
    if let Some(decks) = v.pointer_mut("/world/decks").and_then(Value::as_object_mut) {
        decks.remove("three");
        decks.remove("four");
    }
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
    skipped: usize,
    /// Skipped games on a table this build lacks (the seats-2 build).
    other_table: usize,
    skipped_steps: usize,
    skip_reasons: Vec<String>,
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
    excess: u64,
    untraced: BTreeSet<String>,
    untimed: BTreeSet<String>,
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
        let untimed_path = tape.with_file_name("traced").join("untimed.json");
        let untimed: Vec<String> = std::fs::read_to_string(&untimed_path)
            .map_err(|e| format!("{}: {e}", untimed_path.display()))
            .and_then(|text| serde_json::from_str(&text).map_err(|e| format!("{}: {e}", untimed_path.display())))?;
        let mut rows = BufReader::new(file).lines();
        let header = rows
            .next()
            .ok_or_else(|| format!("{path} is empty"))?
            .map_err(|e| format!("{path}: {e}"))?;
        let header: Value = serde_json::from_str(&header).map_err(|e| format!("{path}: {e}"))?;
        let untraced = get(&header, "untraced")
            .as_array()
            .ok_or_else(|| format!("{path}: the first line is not an untraced header"))?
            .iter()
            .filter_map(|label| label.as_str().map(str::to_owned))
            .collect();
        Ok(Self {
            rows: Some(rows),
            untraced,
            untimed: untimed.into_iter().collect(),
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
        let mut over = Vec::new();
        for (label, (rust_count, bend_count)) in &counts {
            if self.untraced.contains(*label) || self.untimed.contains(*label) {
                continue;
            }
            match rust_count.cmp(bend_count) {
                Ordering::Greater if *bend_count == 0 => over.push((*label, format!("{label} rust {rust_count} bend 0"))),
                Ordering::Greater | Ordering::Equal => {}
                Ordering::Less => self.excess = self.excess.saturating_add(bend_count.saturating_sub(*rust_count)),
            }
        }
        if !over.is_empty() {
            bump(&mut self.differing);
            for (label, _) in &over {
                bump(self.labels.entry(format!("{call} {label}")).or_default());
            }
            if self.examples.len() < 3 {
                self.examples.push(format!(
                    "{at} {call} Rust takes a branch Bend does not: {}",
                    over.iter().map(|(_, text)| text.as_str()).collect::<Vec<_>>().join("; ")
                ));
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
        let top: Vec<String> = labels.iter().take(40).map(|(label, n)| format!("{label} ({n})")).collect();
        Some(format!(
            "trace: Rust takes a branch Bend does not in {} of {} calls; most often {}; first {:?}",
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
    skipped: bool,
}

fn field<'a>(v: &'a Value, key: &str, at: &str) -> Result<&'a Value, String> {
    v.get(key).ok_or_else(|| format!("{at}: no \"{key}\""))
}

/// The game a step-0 line starts, and the branches Rust took to start it. A
/// perturbed state Rust cannot represent starts a game that is skipped.
fn begin(v: &Value, id: &str, at: &str, from_state: bool, tally: &mut Tally) -> Result<(Game, Vec<&'static str>), String> {
    let (cfg, built) = config(get(v, "config")).map_err(|e| format!("{at}: {id}: {e}"))?;
    take_trace();
    let mut started = Vec::new();
    let (state, skipped) = if !built {
        bump(&mut tally.other_table);
        if tally.skip_reasons.len() < 5 {
            tally.skip_reasons.push(format!("{id}: a table this build lacks"));
        }
        (start(&cfg).state, true)
    } else if from_state {
        let mut tape = v.clone();
        let bend = take_state(&mut tape, "state");
        let parsed = state_of(cfg.table(), get(v, "state")).and_then(|parsed| match first_diff(&state(&parsed), &bend, "state") {
            None => Ok(parsed),
            Some(diff) => Err(diff),
        });
        match parsed {
            Ok(parsed) => (parsed, false),
            Err(reason) => {
                if tally.skip_reasons.len() < 5 {
                    tally.skip_reasons.push(format!("{id}: {reason}"));
                }
                (start(&cfg).state, true)
            }
        }
    } else {
        let state = start(&cfg).state;
        started = take_trace();
        (state, false)
    };
    bump(&mut tally.games);
    if skipped {
        bump(&mut tally.skipped);
    }
    let game = Game {
        id: id.to_owned(),
        cfg,
        state,
        next_step: 0,
        agrees: !skipped,
        skipped,
    };
    Ok((game, started))
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
        let from_state = v.get("from_state").is_some();
        let mut started = Vec::new();
        if v.get("config").is_some() {
            if let Some(unfinished) = &current {
                return Err(format!("{at}: game {} has no terminal line", unfinished.id));
            }
            if step != 0 || !seen.insert(id.to_owned()) {
                return Err(format!("{at}: game {id} starts at step {step} or repeats an earlier game"));
            }
            let (game, first_branches) = begin(&v, id, &at, from_state, tally)?;
            started = first_branches;
            current = Some(game);
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
            if game.skipped {
                bump(&mut tally.skipped_steps);
            }
        }
        let row = trace.row(id, step)?;
        if game.agrees {
            let started = if step == 0 && !from_state {
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

/// The tapes in `dir`, sorted; an unset (empty) or tapeless directory is an
/// error, so the replay never passes having compared nothing.
fn tape_paths(dir: &str) -> Result<Vec<PathBuf>, String> {
    if dir.is_empty() {
        return Err(String::from(
            "RUST_TAPES must name a directory of Bend tapes; run sim/rust/check.sh",
        ));
    }
    let mut paths = Vec::new();
    for entry in std::fs::read_dir(dir).map_err(|e| format!("RUST_TAPES {dir}: {e}"))? {
        let path = entry.map_err(|e| format!("RUST_TAPES {dir}: {e}"))?.path();
        if path.extension().is_some_and(|x| x == "jsonl") {
            paths.push(path);
        }
    }
    paths.sort();
    if paths.is_empty() {
        return Err(format!("no *.jsonl tapes in {dir}"));
    }
    Ok(paths)
}

/// Bend reaches a few perturbed states Rust cannot hold (a deck load with no
/// blank); more than a quarter of a tape's games means the state decoder broke.
/// Games on a table this build lacks do not count.
fn too_many_skipped(tally: &Tally) -> Option<String> {
    let unrepresentable = tally.skipped.saturating_sub(tally.other_table);
    let games = tally.games.saturating_sub(tally.other_table);
    (unrepresentable.saturating_mul(4) > games).then(|| format!("{unrepresentable} of {games} games skipped as unrepresentable"))
}

// Bug: the replay passed with RUST_TAPES unset (f2ae6ba made it fail closed).
#[test]
fn replay_fails_without_rust_tapes() {
    assert_eq!(tape_paths("").ok(), None);
}

// Bug: a directory with no tapes compared nothing and passed (f2ae6ba).
#[test]
fn replay_fails_on_a_directory_without_tapes() {
    let dir = std::env::temp_dir().join(format!("rust-tapes-empty-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("a temp dir");
    let paths = tape_paths(dir.to_str().expect("a UTF-8 temp path"));
    std::fs::remove_dir(&dir).expect("the temp dir is removed");
    assert_eq!(paths.ok(), None);
}

// Bug: a broken state decoder skipped every perturbed game and still passed (rust-mutants, Gun::from_shells).
#[test]
fn replay_fails_when_over_a_quarter_of_games_are_skipped() {
    let tally = |games, skipped, other_table| Tally {
        games,
        skipped,
        other_table,
        ..Tally::default()
    };
    assert_eq!(too_many_skipped(&tally(40, 10, 0)), None);
    assert!(too_many_skipped(&tally(40, 11, 0)).is_some());
    // The seats-2 build skips every wider table's game; only the rest count.
    assert_eq!(too_many_skipped(&tally(40, 30, 28)), None);
    assert!(too_many_skipped(&tally(40, 32, 28)).is_some());
}

// Bug: arena game ids repeated across tournaments (5352abe, rust-tapes.mjs); the replay must refuse a repeated id.
#[test]
#[ignore = "needs RUST_TAPES; run sim/rust/check.sh"]
fn a_repeated_game_id_fails_the_replay() {
    let dir = std::env::var("RUST_TAPES").unwrap_or_default();
    let first = tape_paths(&dir)
        .unwrap_or_else(|error| panic!("{error}"))
        .into_iter()
        .next()
        .expect("a tape");
    let text = std::fs::read_to_string(&first).expect("a readable tape");
    let game: Vec<&str> = text.lines().take_while(|line| !line.contains("\"terminal\"")).collect();
    let terminal = text.lines().nth(game.len()).expect("the first game's terminal line");
    let once = [game.as_slice(), &[terminal]].concat().join("\n");
    let path = std::env::temp_dir().join(format!("rust-tapes-repeat-{}.jsonl", std::process::id()));
    std::fs::write(&path, format!("{once}\n{once}\n")).expect("a temp tape");
    let replayed = replay(&path, &mut Tally::default(), &mut Trace::default());
    std::fs::remove_file(&path).expect("the temp tape is removed");
    let error = replayed.expect_err("a repeated game id fails");
    assert!(error.contains("repeats an earlier game"), "{error}");
}

// Bug: steal.owner built steal.slots for the stealer's own items too (938dc73); only the traced replay catches it.
#[test]
#[ignore = "needs RUST_TAPES; run sim/rust/check.sh"]
fn tapes_match_bend() {
    let dir = std::env::var("RUST_TAPES").unwrap_or_default();
    let paths = tape_paths(&dir).unwrap_or_else(|error| panic!("{error}"));
    let mut failed = false;
    let (mut games, mut capped, mut matched, mut skipped) = (0, 0, 0, 0_usize);
    let (mut bend_labels, mut rust_labels) = (BTreeSet::new(), BTreeSet::<&str>::new());
    let (mut untraced, mut excess) = (BTreeSet::new(), 0_u64);
    for path in paths {
        let mut tally = Tally::default();
        let replayed = Trace::open(&path).and_then(|mut trace| {
            replay(&path, &mut tally, &mut trace)?;
            untraced.extend(trace.untraced.iter().cloned());
            excess = excess.saturating_add(trace.excess);
            bend_labels.extend(trace.bend.iter().cloned());
            rust_labels.extend(trace.rust.iter().copied());
            tally.problems.extend(trace.summary());
            Ok(())
        });
        if let Err(error) = replayed {
            tally.problems.push(error);
        }
        tally.problems.extend(too_many_skipped(&tally));
        let source = check_manifest(&path, &mut tally).unwrap_or_else(|error| {
            tally.problems.push(error);
            String::from("no manifest")
        });
        println!(
            "{}: {} games ({} capped, {} skipped as unrepresentable in Rust), {} of {} Bend steps matched [{source}]",
            path.display(),
            tally.games,
            tally.capped,
            tally.skipped,
            tally.matched,
            tally.steps.saturating_sub(tally.skipped_steps)
        );
        for reason in &tally.skip_reasons {
            println!("  skipped {reason}");
        }
        for problem in &tally.problems {
            println!("  {problem}");
        }
        failed |= !tally.problems.is_empty() || tally.matched.saturating_add(tally.skipped_steps) != tally.steps;
        games += tally.games;
        capped += tally.capped;
        matched += tally.matched;
        skipped = skipped.saturating_add(tally.skipped);
    }
    println!("total: {games} games ({capped} capped, {skipped} skipped as unrepresentable), {matched} genuine Bend steps compared");
    if cfg!(feature = "trace") {
        let every = all_labels(&format!("{dir}/traced/labels.json")).unwrap_or_else(|error| panic!("{error}"));
        let bend_only: Vec<&String> = bend_labels.iter().filter(|label| !rust_labels.contains(label.as_str())).collect();
        let neither: BTreeSet<String> = every
            .iter()
            .filter(|label| !bend_labels.contains(*label) && !rust_labels.contains(label.as_str()) && !untraced.contains(*label))
            .cloned()
            .collect();
        println!("trace: Bend took {excess} more branch hits than Rust (work Bend's strict evaluation discards), not a failure");
        println!("untraced (folded away by Bend's compiler): {untraced:?}");
        println!(
            "branches reached: {} by Bend, {} by Rust; reached by Bend only {bend_only:?}; reached by neither {neither:?}",
            bend_labels.len(),
            rust_labels.len()
        );
        let reviewed = |list| reviewed(COVERAGE, list).unwrap_or_else(|error| panic!("{error}"));
        let mut problems = differences("untraced", &reviewed("untraced"), &untraced);
        // The two-seat build skips the wider tables' games, so it reaches less.
        if cfg!(feature = "seats-2-4") {
            problems.extend(differences("unreached", &reviewed("unreached"), &neither));
        }
        for problem in &problems {
            println!("  {problem}");
        }
        failed |= !problems.is_empty();
    }
    assert!(!failed, "the Rust machine differs from Bend's tapes (see above)");
}

/// The reviewed branch labels the traced replay may miss, each with its
/// reason: `untraced`, the labels Bend's compiler folds away so the trace
/// cannot see them, and `unreached`, the labels no gate tape reaches. Both
/// must equal what the replay finds, so coverage cannot shrink unnoticed.
const COVERAGE: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/trace-coverage.json");

/// Every mapped label, from `branch-map instrument`'s `labels.json`.
fn all_labels(path: &str) -> Result<Vec<String>, String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    let labels: Vec<String> = serde_json::from_str(&text).map_err(|e| format!("{path}: {e}"))?;
    if labels.is_empty() {
        return Err(format!("{path}: no labels"));
    }
    Ok(labels)
}

/// The labels of one list of the coverage file; each needs a reason.
fn reviewed(path: &str, list: &str) -> Result<BTreeSet<String>, String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    let value: Value = serde_json::from_str(&text).map_err(|e| format!("{path}: {e}"))?;
    let entries = value
        .get(list)
        .and_then(Value::as_object)
        .ok_or_else(|| format!("{path}: no {list} object"))?;
    if let Some(label) = entries
        .iter()
        .find_map(|(label, reason)| reason.as_str().is_none_or(str::is_empty).then_some(label))
    {
        return Err(format!("{path}: {list} {label} has no reason"));
    }
    Ok(entries.keys().cloned().collect())
}

/// How the labels found differ from the reviewed ones.
fn differences(list: &str, reviewed: &BTreeSet<String>, found: &BTreeSet<String>) -> Vec<String> {
    let new = found
        .difference(reviewed)
        .map(|label| format!("{label} is {list} but not in trace-coverage.json: review it and add it with a reason"));
    let stale = reviewed
        .difference(found)
        .map(|label| format!("trace-coverage.json lists {label} as {list}, but it is not: remove it"));
    new.chain(stale).collect()
}

// Bug: a missing labels.json read as no labels, and every unreached branch passed (rust-integration review).
#[test]
fn missing_trace_labels_fail() {
    all_labels("/nonexistent/labels.json").unwrap_err();
}

// Bug: labels the trace could not see were exempted automatically (rust-integration review).
#[test]
fn coverage_must_match_the_reviewed_lists() {
    let set = |labels: &[&str]| labels.iter().map(|label| (*label).to_owned()).collect::<BTreeSet<String>>();
    assert!(differences("unreached", &set(&["a", "b"]), &set(&["a", "b"])).is_empty());
    assert_eq!(
        differences("unreached", &set(&["a"]), &set(&["a", "b"])).len(),
        1,
        "a new unreached label"
    );
    assert_eq!(
        differences("unreached", &set(&["a", "b"]), &set(&["a"])).len(),
        1,
        "a stale reviewed label"
    );
    for list in ["untraced", "unreached"] {
        assert!(reviewed(COVERAGE, list).is_ok(), "{list}");
    }
}
