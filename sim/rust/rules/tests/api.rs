//! The public helpers the tape replay does not reach: menu lookups, the
//! shell list and item set builders, rings at unseated sockets and range
//! enumeration. The rules themselves are checked against Bend by `tapes.rs`;
//! these pin the helpers that consumers such as `buckshot-search` call.

use buckshot_rules::{
    AmountRule, Answer, Config, Deck, Event, Gun, HealthRule, Item, ItemRule, Items, Load, LoadRule, Move, Notes, Phase, Range, Request,
    Ring, RoundRules, RuleError, Seat, Shell, ShellRule, State, Table, request, start, step, step_event, step_into,
};

fn config(table: Table) -> Result<Config, RuleError> {
    let round = RoundRules {
        health: HealthRule::Fixed(3),
        loads: [LoadRule {
            shells: ShellRule::Random,
            items: AmountRule::Fixed(4),
        }; 4],
        items: [ItemRule {
            enabled: true,
            per_player: 8,
            on_table: 32,
        }; 9],
    };
    Config::new(table, &[round, round])
}

/// Plays a few games with fixed answers, checks every menu's helpers against
/// its own move list, and steps a reused notes buffer alongside.
#[test]
fn menu_helpers_agree_with_the_move_list() {
    let mut menus = 0_u32;
    for (table, seed) in [(Table::TwoSeats, 1_u32), (Table::ThreeSeats, 2), (Table::FourSeats, 3)] {
        let config = config(table).expect("a valid config");
        let mut state = start(&config).state;
        let mut n = seed;
        let mut buffer = Notes::default();
        for _ in 0..600_u32 {
            n = n.wrapping_mul(1_103_515_245).wrapping_add(12_345);
            let pick = n >> 16_u32;
            let answer = match request(&config, &state) {
                Request::Choose(menu) => {
                    menus = menus.wrapping_add(1);
                    let moves: Vec<Move> = menu.moves().map(buckshot_rules::LegalMove::to_move).collect();
                    assert_eq!(menu.len(), moves.len(), "len counts the moves");
                    assert!(!menu.is_empty(), "a Choose menu has a move");
                    for wanted in &moves {
                        let first = moves.iter().position(|m| m == wanted);
                        assert_eq!(menu.find(*wanted), first, "find names the first entry making {wanted:?}");
                    }
                    let absent = Move::Jam { target: Seat::Seat0 };
                    if !moves.contains(&absent) {
                        assert_eq!(menu.find(absent), None, "find of a move not on the menu");
                    }
                    let by_event = step_event(&config, state, Event::Choose(pick)).unwrap_or_else(|e| panic!("a Choose event: {e}"));
                    let legal = menu.clamped(pick).unwrap_or_else(|| panic!("a non-empty menu clamps"));
                    assert_eq!(
                        by_event,
                        step(&config, state, Answer::Choice(legal)),
                        "step_event clamps as clamped does"
                    );
                    Answer::Choice(legal)
                }
                Request::Draw { range, .. } => Answer::Draw(range.value(pick)),
                Request::Finished | Request::Stuck => break,
            };
            let stepped = step(&config, state, answer);
            let into = step_into(&config, state, answer, &mut buffer);
            assert_eq!(
                (into, &buffer),
                (stepped.state, &stepped.notes),
                "step_into replaces the buffer's notes"
            );
            state = stepped.state;
        }
    }
    assert!(menus > 30, "the games reached menus ({menus})");
}

#[test]
fn guns_keep_their_shells_in_order() {
    let shells: Vec<Shell> = (0..70_u32)
        .map(|i| if i.is_multiple_of(3) { Shell::Live } else { Shell::Blank })
        .collect();
    for len in [0_usize, 1, 5, 63, 64, 70] {
        let part = shells.get(..len).unwrap_or(&shells);
        let gun = Gun::from_shells(part.iter().copied());
        let kept = len.min(64);
        assert_eq!(
            usize::try_from(gun.len()).ok(),
            Some(kept),
            "from_shells keeps at most the capacity"
        );
        assert_eq!(gun.is_empty(), kept == 0, "is_empty");
        for (i, shell) in part.iter().take(kept).enumerate() {
            assert_eq!(gun.nth(u32::try_from(i).unwrap_or(u32::MAX)), Some(*shell), "shell {i} of {len}");
        }
        assert_eq!(gun.nth(u32::try_from(kept).unwrap_or(u32::MAX)), None, "nothing past the end");
    }
    let full = Gun::from_shells(shells.iter().copied());
    let pushed = full.push_front(Shell::Live);
    assert_eq!(pushed.len(), 64, "a full gun stays at the capacity");
    assert_eq!(pushed.nth(0), Some(Shell::Live), "push_front puts the shell first");
    assert_eq!(pushed.nth(1), full.nth(0), "and moves the rest back");
}

#[test]
fn a_loaded_gun_holds_the_live_shells_first() {
    let gun = Gun::of_load(Load { live: 2, blank: 3 });
    let shells: Vec<Option<Shell>> = (0..6).map(|i| gun.nth(i)).collect();
    let want = [
        Some(Shell::Live),
        Some(Shell::Live),
        Some(Shell::Blank),
        Some(Shell::Blank),
        Some(Shell::Blank),
        None,
    ];
    assert_eq!(shells, want, "live shells, then blanks");
}

#[test]
fn item_sets_know_when_they_are_empty() {
    assert!(Items::EMPTY.is_empty(), "the empty set");
    for item in Item::ORDER {
        assert!(!Items::EMPTY.with(item).is_empty(), "a set holding {item:?}");
    }
}

#[test]
fn rings_ignore_sockets_off_the_table() {
    let ring = Ring::fill(Table::TwoSeats, 1_u8);
    for seat in [Seat::Seat0, Seat::Seat2] {
        assert_eq!(ring.get(seat), None, "{seat:?} is not at a two-seat table");
        assert_eq!(ring.set(seat, 2), ring, "setting {seat:?} leaves the ring unchanged");
        assert!(!Table::TwoSeats.has(seat), "has {seat:?}");
    }
    assert!(!Table::ThreeSeats.has(Seat::Seat3), "has Seat3 at three seats");
    assert_eq!(
        ring.set(Seat::Seat1, 2).get(Seat::Seat1),
        Some(2),
        "a seated socket takes the value"
    );
}

#[test]
fn a_range_lists_every_value() {
    let values: Vec<u32> = Range { lo: 3, extra: 2 }.values().map(buckshot_rules::DrawValue::get).collect();
    assert_eq!(values, [3, 4, 5, 6], "lo through lo + extra + 1");
}

/// Bend's `answer.idle` leaves the state alone when the seat to move is not
/// at the table, which only a forged state can hold.
#[test]
fn an_unseated_seat_to_move_is_stuck() {
    let config = config(Table::TwoSeats).expect("a valid config");
    let mut state = start(&config).state;
    let mut n = 7_u32;
    while !matches!(state.phase, Phase::Idle { .. }) {
        n = n.wrapping_mul(1_103_515_245).wrapping_add(12_345);
        let answer = match request(&config, &state) {
            Request::Draw { range, .. } => Answer::Draw(range.value(n >> 16_u32)),
            other @ (Request::Choose(_) | Request::Finished | Request::Stuck) => panic!("a draw before the first move, got {other:?}"),
        };
        state = step(&config, state, answer).state;
    }
    let forged = State {
        phase: Phase::Idle { seat: Seat::Seat0 },
        ..state
    };
    assert_eq!(request(&config, &forged), Request::Stuck, "no menu for an unseated seat");
    for event in [Event::Choose(0), Event::Draw(0)] {
        let stepped = step_event(&config, forged, event).expect("an answer at a stuck point");
        assert_eq!(stepped.state, forged, "{event:?} leaves the state alone");
        assert!(stepped.notes.as_slice().is_empty(), "{event:?} makes no notes");
    }
}

#[test]
fn deck_ids_form_a_set_inside_the_table_deck() {
    for table in [Table::TwoSeats, Table::ThreeSeats, Table::FourSeats] {
        let deck = Deck::of_ids(table, [2, 0, 2, 15, 40]);
        let ids: Vec<u32> = deck.iter().map(|batch| batch.id).collect();
        assert_eq!(ids, [0, 2], "{table:?}: repeats and ids past the deck drop");
        assert_eq!(deck.len(), 2, "{table:?}: len");
    }
}
