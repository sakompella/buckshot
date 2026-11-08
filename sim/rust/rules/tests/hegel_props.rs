//! Property tests over the public API of `buckshot-rules`, written with Hegel: random walks keep
//! the machine's invariants, steps are deterministic, external input never panics, and forged
//! tokens and arbitrary states are defined (no panic). Case counts are pinned per test (a pinned
//! count beats `HEGEL_TEST_CASES`); `HEGEL_SEED` replays a run and a failure replays from `.hegel/`.

#![expect(
    clippy::panic,
    clippy::expect_used,
    reason = "Hegel reports a failed property by panic, so the helpers panic instead of returning a Result; clippy.toml only exempts #[test] fns"
)]

use std::hint::black_box;

use buckshot_rules::{
    AmountRule, Answer, Config, Deck, Decks, Direction, Event, FirstDeathCheck, Grabs, Gun, HealthRule, IdleOption, Item, ItemRule, Items,
    Jam, LegalMove, Load, LoadRule, MENU_CAPACITY, NOTES_CAPACITY, Phase, Range, Request, RequestKind, Ring, RoundRules, RuleError, Seat,
    SeatRecord, Shell, ShellRule, Slot, Slots, State, Stepped, Table, World, request, start, step, step_event,
};
use hegel::generators as gs;
use hegel::{Hegel, Settings, TestCase};

const SEATS: [Seat; 4] = [Seat::Seat0, Seat::Seat1, Seat::Seat2, Seat::Seat3];

// Generators
// ==========

fn flag(tc: &TestCase) -> bool {
    tc.draw_silent(gs::booleans())
}

fn between(tc: &TestCase, lo: u32, hi: u32) -> u32 {
    tc.draw_silent(gs::integers::<u32>().min_value(lo).max_value(hi))
}

fn count(tc: &TestCase, lo: usize, hi: usize) -> usize {
    tc.draw_silent(gs::integers::<usize>().min_value(lo).max_value(hi))
}

fn pick<T: Clone + Send + Sync>(tc: &TestCase, from: &[T]) -> T {
    tc.draw_silent(gs::sampled_from(from.to_vec()))
}

fn maybe<T>(tc: &TestCase, make: impl FnOnce(&TestCase) -> T) -> Option<T> {
    flag(tc).then(|| make(tc))
}

fn many<T>(tc: &TestCase, lo: usize, hi: usize, mut make: impl FnMut(&TestCase) -> T) -> Vec<T> {
    (0..count(tc, lo, hi)).map(|_| make(tc)).collect()
}

fn table(tc: &TestCase) -> Table {
    pick(tc, &[Table::TwoSeats, Table::ThreeSeats, Table::FourSeats])
}

fn seat(tc: &TestCase) -> Seat {
    pick(tc, &SEATS)
}

fn item(tc: &TestCase) -> Item {
    pick(tc, &Item::ORDER)
}

fn shell(tc: &TestCase) -> Shell {
    pick(tc, &[Shell::Live, Shell::Blank])
}

fn any_u32(tc: &TestCase) -> u32 {
    tc.draw_silent(gs::integers::<u32>())
}

/// Mostly small numbers, sometimes anything.
fn num(tc: &TestCase) -> u32 {
    match count(tc, 0, 10) {
        0..8 => between(tc, 0, 9),
        8..10 => between(tc, 0, 199),
        _ => any_u32(tc),
    }
}

fn item_rules(tc: &TestCase, heavy: bool) -> [ItemRule; 9] {
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

fn load_rule(tc: &TestCase, heavy: bool) -> LoadRule {
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

fn round_rules(tc: &TestCase, heavy: bool) -> RoundRules {
    let health = if flag(tc) {
        HealthRule::Random
    } else {
        HealthRule::Fixed(between(tc, 1, 5))
    };
    RoundRules {
        health,
        loads: std::array::from_fn(|_| load_rule(tc, heavy)),
        items: item_rules(tc, heavy),
    }
}

/// A config inside the supported domain: what `rust-tapes.mjs` plays.
fn supported_config(tc: &TestCase, heavy: bool) -> Config {
    let table = table(tc);
    let rounds = many(tc, 1, 3, |tc| round_rules(tc, heavy));
    tc.note(&format!("{table:?} {rounds:?}"));
    Config::new(table, &rounds).unwrap_or_else(|error| panic!("a supported plan is valid: {error}"))
}

fn ring<T: Copy>(tc: &TestCase, table: Table, mut make: impl FnMut(&TestCase) -> T) -> Ring<T> {
    let values: [T; 4] = std::array::from_fn(|_| make(tc));
    SEATS
        .iter()
        .zip(values)
        .fold(Ring::fill(table, values[0]), |ring, (seat, value)| ring.set(*seat, value))
}

fn slots(tc: &TestCase) -> Slots {
    Slot::ORDER
        .iter()
        .fold(Slots::EMPTY, |slots, slot| slots.put(*slot, maybe(tc, item)))
}

fn load(tc: &TestCase) -> Load {
    Load {
        live: num(tc),
        blank: num(tc),
    }
}

fn gun(tc: &TestCase) -> Gun {
    Gun::from_shells(many(tc, 0, 64, shell)).expect("64 shells fit the gun")
}

fn direction(tc: &TestCase) -> Direction {
    pick(tc, &[Direction::Clockwise, Direction::CounterClockwise])
}

fn items(tc: &TestCase) -> Items {
    many(tc, 0, 8, item).into_iter().fold(Items::EMPTY, Items::with)
}

fn deck(tc: &TestCase, table: Table) -> Deck {
    let last = u32::try_from(table.deck().len()).map_or(0, |len| len.saturating_sub(1));
    let ids = tc.draw_silent(gs::vecs(gs::integers::<u32>().max_value(last)).max_size(11));
    Deck::of_ids(table, ids).expect("ids within the deck")
}

fn world(tc: &TestCase) -> World {
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
            three: deck(tc, Table::ThreeSeats),
            four: deck(tc, Table::FourSeats),
        },
    }
}

fn seat_record(tc: &TestCase) -> SeatRecord {
    SeatRecord {
        health: num(tc),
        jam: pick(tc, &[Jam::Free, Jam::Jammed, Jam::JammedSkipped]),
        cash: num(tc),
        slots: slots(tc),
    }
}

fn grabs(tc: &TestCase, table: Table) -> Grabs {
    Grabs {
        distributing: flag(tc),
        grabbing: ring(tc, table, flag),
        holding: ring(tc, table, |tc| maybe(tc, item)),
        granted: ring(tc, table, num),
        intake: ring(tc, table, flag),
    }
}

fn phase(tc: &TestCase) -> Phase {
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

fn arbitrary_state(tc: &TestCase, table: Table) -> State {
    State {
        world: world(tc),
        players: ring(tc, table, seat_record),
        grabs: grabs(tc, table),
        phase: phase(tc),
    }
}

// The walk
// ========

/// A draw's raw number: mostly inside the range, sometimes anything.
fn raw_draw(range: Range, n: u32) -> u32 {
    if n.is_multiple_of(16) {
        n
    } else {
        let span = u64::from(range.extra).saturating_add(2);
        u32::try_from(u64::from(n >> 4).checked_rem(span).unwrap_or(0)).unwrap_or(0)
    }
}

fn raw_choice(len: usize, n: u32) -> u32 {
    if n.is_multiple_of(16) {
        n
    } else {
        (n >> 4).checked_rem(u32::try_from(len).unwrap_or(1)).unwrap_or(0)
    }
}

/// Draws the next answer to a request: mostly in range, sometimes a wild raw number the machine must clamp.
fn draw_answer(tc: &TestCase, request: &Request) -> Option<(Event, Answer)> {
    let wild = tc.draw_silent(gs::weighted_booleans(0.0625));
    match request {
        Request::Draw { range, .. } => {
            let raw = if wild {
                any_u32(tc)
            } else {
                between(tc, 0, range.extra.saturating_add(1))
            };
            Some((Event::Draw(raw), Answer::Draw(range.value(raw))))
        }
        Request::Choose(menu) => {
            let raw = if wild {
                any_u32(tc)
            } else {
                between(tc, 0, u32::try_from(menu.len().saturating_sub(1)).unwrap_or(0))
            };
            Some((Event::Choose(raw), Answer::Choice(menu.clamped(raw)?)))
        }
        Request::Finished | Request::Stuck => None,
    }
}

/// The raw event and the token a request's answer to `n` makes.
fn answer_for(request: &Request, n: u32) -> Option<(Event, Answer)> {
    match request {
        Request::Draw { range, .. } => {
            let raw = raw_draw(*range, n);
            Some((Event::Draw(raw), Answer::Draw(range.value(raw))))
        }
        Request::Choose(menu) => {
            let raw = raw_choice(menu.len(), n);
            Some((Event::Choose(raw), Answer::Choice(menu.clamped(raw)?)))
        }
        Request::Finished | Request::Stuck => None,
    }
}

fn alive(state: &State, seat: Seat) -> bool {
    state.players.get(seat).is_some_and(|record| record.health > 0)
}

fn check_menu(state: &State, menu: &buckshot_rules::Menu) {
    let table = state.players.table();
    let me = menu.seat();
    assert!(!menu.is_empty(), "empty menu");
    assert!(menu.len() <= MENU_CAPACITY, "menu of {} over capacity", menu.len());
    assert!(table.has(me), "{me:?} is not at the table");
    assert!(alive(state, me), "{me:?} is dead at a Choose");
    let holds = |owner: Seat, slot: Slot, item: Item| state.players.get(owner).is_some_and(|record| record.slots.get(slot) == Some(item));
    for legal in menu.moves() {
        let ok = match legal.option() {
            IdleOption::ShootAt { target } => table.has(target) && alive(state, target),
            IdleOption::UseSlot { slot, item } => holds(me, slot, item),
            IdleOption::JamWith { slot, target } => holds(me, slot, Item::Jammer) && table.has(target),
            IdleOption::StealWith {
                adrenaline,
                owner,
                slot,
                item,
            } => holds(me, adrenaline, Item::Adrenaline) && holds(owner, slot, item) && owner != me,
            IdleOption::StealJamWith {
                adrenaline,
                owner,
                slot,
                target,
            } => holds(me, adrenaline, Item::Adrenaline) && holds(owner, slot, Item::Jammer) && owner != me && table.has(target),
        };
        assert!(ok, "{:?} is not backed by the state", legal.option());
    }
}

fn check_state(config: &Config, state: &State) {
    let world = &state.world;
    assert!(
        world.round_index < config.plan_length(),
        "round {} past the plan",
        world.round_index
    );
    if !matches!(state.phase, Phase::NeedAmount) && world.round_health > 0 {
        for (seat, record) in state.players.entries() {
            assert!(
                record.health <= world.round_health,
                "{seat:?} has {} of {}",
                record.health,
                world.round_health
            );
        }
    }
    let total = world.shown.live.saturating_add(world.shown.blank);
    assert!(world.gun.len() <= total, "gun of {} over shown {:?}", world.gun.len(), world.shown);
}

fn check_step(before: &State, after: &State) {
    assert!(after.world.round_index >= before.world.round_index, "the round index went back");
    for (seat, record) in after.players.entries() {
        let old = before.players.get(seat).map_or(0, |old| old.cash);
        assert!(record.cash >= old, "{seat:?} lost cash");
    }
}

fn external(config: &Config, state: State, event: Event) -> Stepped {
    step_event(config, state, event).unwrap_or_else(|error| panic!("{event:?} at a valid request: {error}"))
}

/// What one answer does at one point: determinism, event equivalence and the
/// errors of a wrong or out-of-range event.
fn check_events(config: &Config, state: State, request: &Request, event: Event, answer: Answer, stepped: &Stepped) {
    assert_eq!(&step(config, state, answer), stepped, "step is not deterministic");
    assert_eq!(&external(config, state, event), stepped, "the event differs from its answer");
    match request {
        Request::Draw { range, .. } => {
            assert_eq!(
                step_event(config, state, Event::Choose(0)),
                Err(RuleError::WrongEvent {
                    expected: RequestKind::Draw,
                    got: RequestKind::Choose
                }),
                "a Choose at a Draw"
            );
            let top = step(config, state, Answer::Draw(range.value(range.extra.saturating_add(1))));
            assert_eq!(
                external(config, state, Event::Draw(u32::MAX)),
                top,
                "a huge draw is not the top of the range"
            );
        }
        Request::Choose(menu) => {
            assert_eq!(
                step_event(config, state, Event::Draw(0)),
                Err(RuleError::WrongEvent {
                    expected: RequestKind::Choose,
                    got: RequestKind::Draw
                }),
                "a Draw at a Choose"
            );
            let last = menu.clamped(u32::MAX).expect("a menu is not empty");
            let top = step(config, state, Answer::Choice(last));
            assert_eq!(
                external(config, state, Event::Choose(u32::MAX)),
                top,
                "a huge choice is not the last move"
            );
        }
        Request::Finished | Request::Stuck => {}
    }
}

fn check_terminal(config: &Config, state: State) {
    let unchanged = Stepped {
        state,
        notes: buckshot_rules::Notes::default(),
    };
    for event in [Event::Draw(0), Event::Draw(u32::MAX), Event::Choose(0), Event::Choose(u32::MAX)] {
        assert_eq!(
            step_event(config, state, event),
            Ok(unchanged.clone()),
            "{event:?} moved a finished game"
        );
    }
}

fn note_sizes(stepped: &Stepped, walked: &mut Walked) {
    assert!(!stepped.notes.truncated(), "notes were truncated");
    walked.max_notes = walked.max_notes.max(stepped.notes.as_slice().len());
}

/// A walk's visited states and the largest menu and notes it saw.
#[derive(Default)]
struct Walked {
    states: Vec<State>,
    max_menu: usize,
    max_notes: usize,
    finished: bool,
}

/// Plays a reachable game of up to `steps` drawn answers, checking every invariant, and returns the states visited.
fn walk(tc: &TestCase, config: &Config, steps: usize) -> Walked {
    let mut current = start(config);
    let mut walked = Walked::default();
    note_sizes(&current, &mut walked);
    walked.states.push(current.state);
    for _ in 0..steps {
        let state = current.state;
        check_state(config, &state);
        let request = request(config, &state);
        match &request {
            Request::Choose(menu) => {
                check_menu(&state, menu);
                walked.max_menu = walked.max_menu.max(menu.len());
            }
            Request::Finished => {
                assert!(matches!(state.phase, Phase::Ended), "Finished outside the Ended phase");
                walked.finished = true;
            }
            Request::Draw { .. } | Request::Stuck => {}
        }
        let Some((event, answer)) = draw_answer(tc, &request) else {
            check_terminal(config, state);
            break;
        };
        let next = step(config, state, answer);
        note_sizes(&next, &mut walked);
        check_events(config, state, &request, event, answer, &next);
        check_step(&state, &next.state);
        walked.states.push(next.state);
        current = next;
    }
    walked
}

/// Plays from any state without checking invariants: only that nothing panics.
fn wander(config: &Config, state: State, answers: &[u32]) {
    let mut state = state;
    for n in answers {
        let request = request(config, &state);
        let Some((event, answer)) = answer_for(&request, *n) else {
            black_box(step_event(config, state, Event::Draw(*n)).is_ok());
            break;
        };
        black_box(step_event(config, state, event).is_ok());
        state = step(config, state, answer).state;
    }
}

const STEPS: usize = 400;

#[hegel::test(test_cases = 512)]
fn walks_hold_invariants(tc: TestCase) {
    let config = supported_config(&tc, false);
    walk(&tc, &config, STEPS);
}

#[hegel::test(test_cases = 512)]
fn forged_tokens_do_not_panic(tc: TestCase) {
    let a = supported_config(&tc, false);
    let b = supported_config(&tc, false);
    let from_a = walk(&tc, &a, 120).states;
    let from_b = walk(&tc, &b, 120).states;
    let n = any_u32(&tc);
    let moves: Vec<LegalMove> = from_a
        .iter()
        .filter_map(|state| match request(&a, state) {
            Request::Choose(menu) => Some(menu.moves().collect::<Vec<_>>()),
            Request::Draw { .. } | Request::Finished | Request::Stuck => None,
        })
        .flat_map(|moves| [moves.first().copied(), moves.last().copied()])
        .flatten()
        .collect();
    let ranges: Vec<Range> = from_a
        .iter()
        .filter_map(|state| match request(&a, state) {
            Request::Draw { range, .. } => Some(range),
            Request::Choose(_) | Request::Finished | Request::Stuck => None,
        })
        .collect();
    for state in from_b.iter().step_by(3) {
        for legal in &moves {
            for config in [&a, &b] {
                black_box(step(config, *state, Answer::Choice(*legal)));
            }
        }
        for range in &ranges {
            for config in [&a, &b] {
                black_box(step(config, *state, Answer::Draw(range.value(n))));
            }
        }
    }
}

#[hegel::test(test_cases = 256)]
fn arbitrary_states_do_not_panic(tc: TestCase) {
    let config = supported_config(&tc, false);
    let table = table(&tc);
    let state = arbitrary_state(&tc, table);
    let range = Range {
        lo: any_u32(&tc),
        extra: any_u32(&tc),
    };
    let n = any_u32(&tc);
    let answers = tc.draw_silent(gs::vecs(gs::integers::<u32>()).min_size(40).max_size(40));
    black_box(step_event(&config, state, Event::Draw(n)).is_ok());
    black_box(step_event(&config, state, Event::Choose(n)).is_ok());
    black_box(step(&config, state, Answer::Draw(range.value(n))));
    if let Request::Choose(menu) = request(&config, &state) {
        for legal in menu.moves() {
            black_box(step(&config, state, Answer::Choice(legal)));
        }
    }
    wander(&config, state, &answers);
}

fn wild_round(tc: &TestCase) -> RoundRules {
    let health = if flag(tc) { HealthRule::Random } else { HealthRule::Fixed(num(tc)) };
    let load = |t: &TestCase| LoadRule {
        shells: match count(t, 0, 2) {
            0 => ShellRule::Random,
            1 => ShellRule::Fixed {
                live: num(t),
                blank: num(t),
            },
            _ => ShellRule::AllLive { live: num(t) },
        },
        items: if flag(t) { AmountRule::Random } else { AmountRule::Fixed(num(t)) },
    };
    RoundRules {
        health,
        loads: std::array::from_fn(|_| load(tc)),
        items: std::array::from_fn(|_| ItemRule {
            enabled: flag(tc),
            per_player: num(tc),
            on_table: num(tc),
        }),
    }
}

#[hegel::test(test_cases = 512)]
fn config_validation_matches_the_domain(tc: TestCase) {
    let table = table(&tc);
    let rounds = many(&tc, 0, 5, wild_round);
    let valid = (1..=3).contains(&rounds.len())
        && rounds.iter().all(|round| {
            !matches!(round.health, HealthRule::Fixed(0))
                && round.loads.iter().all(|load| match load.shells {
                    ShellRule::Random => true,
                    ShellRule::Fixed { live, blank } => blank >= 1 && u64::from(live).saturating_add(u64::from(blank)) <= 64,
                    ShellRule::AllLive { live } => (1..=64).contains(&live),
                })
        });
    match Config::new(table, &rounds) {
        Ok(config) => {
            assert!(valid, "an invalid plan was accepted");
            assert_eq!(config.rounds().len(), rounds.len(), "the plan lost rounds");
            black_box(start(&config));
        }
        Err(error) => {
            assert!(!valid, "a valid plan was rejected: {error}");
            assert!(matches!(error, RuleError::Config(_)), "a config error was expected, got {error}");
        }
    }
}

#[test]
fn menus_and_notes_stay_in_capacity() {
    let mut seen = Walked::default();
    let (mut games, mut finished) = (0_usize, 0_usize);
    Hegel::new(|tc| {
        let config = supported_config(&tc, flag(&tc));
        let walked = walk(&tc, &config, 600);
        seen.max_menu = seen.max_menu.max(walked.max_menu);
        seen.max_notes = seen.max_notes.max(walked.max_notes);
        finished = finished.saturating_add(usize::from(walked.finished));
        games = games.saturating_add(1);
    })
    .settings(Settings::new().test_cases(1000))
    .run();
    let (menu, notes) = (seen.max_menu, seen.max_notes);
    println!("{games} walks, {finished} finished; max menu {menu}/{MENU_CAPACITY}, max notes {notes}/{NOTES_CAPACITY}");
    // A quarter of each capacity stays free (last seen: menu 37/64, notes 77/256).
    let within = |most: usize, capacity: usize| most.saturating_mul(4) <= capacity.saturating_mul(3);
    assert!(
        within(menu, MENU_CAPACITY) && within(notes, NOTES_CAPACITY),
        "a capacity lost its margin"
    );
}

#[hegel::test(test_cases = 128)]
fn wild_valid_configs_do_not_panic(tc: TestCase) {
    let table = table(&tc);
    let rounds = many(&tc, 1, 3, wild_round);
    let answers = tc.draw_silent(gs::vecs(gs::integers::<u32>()).min_size(200).max_size(200));
    if let Ok(config) = Config::new(table, &rounds) {
        let mut state = start(&config).state;
        for n in &answers {
            let request = request(&config, &state);
            let Some((_, answer)) = answer_for(&request, *n) else { break };
            state = step(&config, state, answer).state;
        }
    }
}
