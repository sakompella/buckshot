//! Hegel generators for the rules' types, shared by this crate's property
//! tests and buckshot-search's (the `testing` feature).

#![expect(clippy::panic, clippy::expect_used, reason = "Hegel reports a failed property by panic")]

use hegel::TestCase;
use hegel::generators as gs;

use crate::{
    AmountRule, Config, Deck, Decks, Direction, EnumMap, FirstDeathCheck, Grabs, Gun, HealthRule, Item, ItemRule, Items, Jam, Load,
    LoadRule, Phase, Ring, RoundRules, Seat, SeatRecord, Shell, ShellRule, Slot, Slots, State, Table, World,
};

pub fn flag(tc: &TestCase) -> bool {
    tc.draw_silent(gs::booleans())
}

pub fn between(tc: &TestCase, lo: u32, hi: u32) -> u32 {
    tc.draw_silent(gs::integers::<u32>().min_value(lo).max_value(hi))
}

pub fn count(tc: &TestCase, lo: usize, hi: usize) -> usize {
    tc.draw_silent(gs::integers::<usize>().min_value(lo).max_value(hi))
}

pub fn pick<T: Clone + Send + Sync>(tc: &TestCase, from: &[T]) -> T {
    tc.draw_silent(gs::sampled_from(from.to_vec()))
}

pub fn maybe<T>(tc: &TestCase, make: impl FnOnce(&TestCase) -> T) -> Option<T> {
    flag(tc).then(|| make(tc))
}

pub fn many<T>(tc: &TestCase, lo: usize, hi: usize, mut make: impl FnMut(&TestCase) -> T) -> Vec<T> {
    (0..count(tc, lo, hi)).map(|_| make(tc)).collect()
}

pub fn table(tc: &TestCase) -> Table {
    #[cfg(feature = "seats-2-4")]
    let tables = [Table::TwoSeats, Table::ThreeSeats, Table::FourSeats];
    #[cfg(not(feature = "seats-2-4"))]
    let tables = [Table::TwoSeats];
    pick(tc, &tables)
}

pub fn seat(tc: &TestCase) -> Seat {
    pick(tc, &Seat::ALL)
}

pub fn item(tc: &TestCase) -> Item {
    pick(tc, &Item::ORDER)
}

pub fn shell(tc: &TestCase) -> Shell {
    pick(tc, &[Shell::Live, Shell::Blank])
}

pub fn any_u32(tc: &TestCase) -> u32 {
    tc.draw_silent(gs::integers::<u32>())
}

/// Mostly small numbers, sometimes anything.
pub fn num(tc: &TestCase) -> u32 {
    match count(tc, 0, 10) {
        0..8 => between(tc, 0, 9),
        8..10 => between(tc, 0, 199),
        _ => any_u32(tc),
    }
}

pub fn item_rules(tc: &TestCase, heavy: bool) -> [ItemRule; 9] {
    std::array::from_fn(|_| {
        if heavy {
            ItemRule {
                enabled: tc.draw_silent(gs::weighted_booleans(0.3)),
                per_player: 8,
                on_table: 32,
            }
        } else {
            ItemRule {
                enabled: tc.draw_silent(gs::weighted_booleans(0.75)),
                per_player: between(tc, 1, if flag(tc) { 3 } else { 8 }),
                on_table: if flag(tc) { between(tc, 1, 8) } else { 32 },
            }
        }
    })
}

pub fn load_rule(tc: &TestCase, heavy: bool) -> LoadRule {
    let shells = match count(tc, 0, 2) {
        0 => ShellRule::Random,
        1 => ShellRule::Fixed {
            live: between(tc, 0, 7),
            blank: between(tc, 1, 8),
        },
        _ => ShellRule::AllLive { live: between(tc, 1, 8) },
    };
    let items = if heavy || flag(tc) {
        AmountRule::Fixed(if heavy { 8 } else { between(tc, 0, 8) })
    } else {
        AmountRule::Random
    };
    LoadRule { shells, items }
}

pub fn round_rules(tc: &TestCase, heavy: bool) -> RoundRules {
    let health = if flag(tc) {
        HealthRule::Random
    } else {
        HealthRule::Fixed(between(tc, 1, 5))
    };
    RoundRules {
        health,
        loads: std::array::from_fn(|_| load_rule(tc, heavy)),
        items: EnumMap::from_array(item_rules(tc, heavy)),
    }
}

/// A config inside the supported domain: what `rust-tapes.mjs` plays.
///
/// # Panics
///
/// If the plan is invalid, a bug in the generator.
pub fn supported_config(tc: &TestCase, heavy: bool) -> Config {
    let table = table(tc);
    let rounds = many(tc, 1, 3, |tc| round_rules(tc, heavy));
    tc.note(&format!("{table:?} {rounds:?}"));
    Config::new(table, &rounds).unwrap_or_else(|error| panic!("a supported plan is valid: {error}"))
}

pub fn ring<T: Copy>(tc: &TestCase, table: Table, mut make: impl FnMut(&TestCase) -> T) -> Ring<T> {
    Ring::from_fn(table, |_| make(tc))
}

pub fn slots(tc: &TestCase) -> Slots {
    Slot::ORDER
        .iter()
        .fold(Slots::EMPTY, |slots, slot| slots.put(*slot, maybe(tc, item)))
}

pub fn load(tc: &TestCase) -> Load {
    Load {
        live: num(tc),
        blank: num(tc),
    }
}

/// # Panics
///
/// Never: 64 shells fit the gun.
pub fn gun(tc: &TestCase) -> Gun {
    Gun::from_shells(many(tc, 0, 64, shell)).expect("64 shells fit the gun")
}

pub fn direction(tc: &TestCase) -> Direction {
    pick(tc, &[Direction::Clockwise, Direction::CounterClockwise])
}

pub fn items(tc: &TestCase) -> Items {
    many(tc, 0, 8, item).into_iter().fold(Items::EMPTY, Items::with)
}

/// # Panics
///
/// Never: the ids are within the deck.
pub fn deck(tc: &TestCase, table: Table) -> Deck {
    let last = u32::try_from(table.deck().len()).map_or(0, |len| len.saturating_sub(1));
    let ids = tc.draw_silent(gs::vecs(gs::integers::<u32>().max_value(last)).max_size(11));
    Deck::of_ids(table, ids).expect("ids within the deck")
}

pub fn world(tc: &TestCase) -> World {
    World {
        before_round: flag(tc),
        first_sequence: flag(tc),
        checking_first_death: pick(tc, &[FirstDeathCheck::Off, FirstDeathCheck::On]),
        sawed: flag(tc),
        round_index: num(tc),
        load_index: num(tc),
        round_health: num(tc),
        item_amount: num(tc),
        first_turn: seat(tc),
        turn: maybe(tc, seat),
        first_death: maybe(tc, seat),
        direction: direction(tc),
        gun: gun(tc),
        shown: load(tc),
        decks: Decks {
            two: deck(tc, Table::TwoSeats),
            #[cfg(feature = "seats-2-4")]
            three: deck(tc, Table::ThreeSeats),
            #[cfg(feature = "seats-2-4")]
            four: deck(tc, Table::FourSeats),
        },
    }
}

pub fn seat_record(tc: &TestCase) -> SeatRecord {
    SeatRecord {
        health: num(tc),
        jam: pick(tc, &[Jam::Free, Jam::Jammed, Jam::JammedSkipped]),
        cash: num(tc),
        slots: slots(tc),
    }
}

pub fn grabs(tc: &TestCase, table: Table) -> Grabs {
    Grabs {
        distributing: flag(tc),
        grabbing: ring(tc, table, flag),
        holding: ring(tc, table, |tc| maybe(tc, item)),
        granted: ring(tc, table, num),
        intake: ring(tc, table, flag),
    }
}

pub fn phase(tc: &TestCase) -> Phase {
    match count(tc, 0, 11) {
        0 => Phase::NeedFirst,
        1 => Phase::NeedHealth,
        2 => Phase::NeedAmount,
        3 => Phase::NeedBatch,
        4 => Phase::NeedSwap {
            load: load(tc),
            shells: gun(tc),
            i: num(tc),
        },
        5 => Phase::Idle { seat: seat(tc) },
        6 => Phase::Ended,
        7 => Phase::Blocked { holder: maybe(tc, seat) },
        8 => Phase::Stalled,
        9 => Phase::NeedTurnAmount {
            from: seat(tc),
            passing: flag(tc),
            winner: maybe(tc, seat),
        },
        10 => Phase::NeedItem {
            seat: seat(tc),
            first: item(tc),
            second: item(tc),
            rest: items(tc),
        },
        _ => Phase::NeedPhone {
            seat: seat(tc),
            owner: seat(tc),
            slot: pick(tc, &Slot::ORDER),
        },
    }
}

pub fn arbitrary_state(tc: &TestCase, table: Table) -> State {
    State {
        world: world(tc),
        players: ring(tc, table, seat_record),
        grabs: grabs(tc, table),
        phase: phase(tc),
    }
}
