//! Property tests over the public API of `buckshot-rules`: random walks keep the machine's
//! invariants, steps are deterministic, external input never panics, and forged tokens and
//! arbitrary states are defined (no panic). Set `PROPTEST_CASES` to scale the case counts.

use std::cell::{Cell, RefCell};
use std::fmt::Debug;
use std::hint::black_box;

use buckshot_rules::{
    AmountRule, Answer, Config, Deck, Decks, Direction, Event, FirstDeathCheck, Grabs, Gun, HealthRule, IdleOption, Item, ItemRule, Items,
    Jam, LegalMove, Load, LoadRule, MENU_CAPACITY, NOTES_CAPACITY, Phase, Range, Request, RequestKind, Ring, RoundRules, RuleError, Seat,
    SeatRecord, Shell, ShellRule, Slot, Slots, State, Stepped, Table, World, request, start, step, step_event,
};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::TestRunner;

const SEATS: [Seat; 4] = [Seat::Seat0, Seat::Seat1, Seat::Seat2, Seat::Seat3];

fn config(cases: u32) -> ProptestConfig {
    let cases = std::env::var("PROPTEST_CASES").ok().and_then(|v| v.parse().ok()).unwrap_or(cases);
    ProptestConfig {
        cases,
        failure_persistence: None,
        ..ProptestConfig::default()
    }
}

// Strategies
// ==========

fn table() -> impl Strategy<Value = Table> {
    prop_oneof![Just(Table::TwoSeats), Just(Table::ThreeSeats), Just(Table::FourSeats)]
}

fn seat() -> impl Strategy<Value = Seat> {
    prop::sample::select(SEATS.to_vec())
}

fn item() -> impl Strategy<Value = Item> {
    prop::sample::select(Item::ORDER.to_vec())
}

fn shell() -> impl Strategy<Value = Shell> {
    prop_oneof![Just(Shell::Live), Just(Shell::Blank)]
}

/// Mostly small numbers, sometimes anything.
fn num() -> impl Strategy<Value = u32> {
    prop_oneof![8 => 0u32..10, 2 => 0u32..200, 1 => any::<u32>()]
}

fn item_rules(heavy: bool) -> impl Strategy<Value = [ItemRule; 9]> {
    let rule = if heavy {
        (prop::bool::weighted(0.3), Just(8u32), Just(32u32)).boxed()
    } else {
        (
            prop::bool::weighted(0.75),
            prop_oneof![1u32..=3, 1u32..=8],
            prop_oneof![1u32..=8, Just(32u32)],
        )
            .boxed()
    };
    prop::array::uniform9(rule.prop_map(|(enabled, per_player, on_table)| ItemRule {
        enabled,
        per_player,
        on_table,
    }))
}

fn load_rule(heavy: bool) -> impl Strategy<Value = LoadRule> {
    let shells = prop_oneof![
        Just(ShellRule::Random),
        (0u32..=7, 1u32..=8).prop_map(|(live, blank)| ShellRule::Fixed { live, blank }),
        (1u32..=8).prop_map(|live| ShellRule::AllLive { live }),
    ];
    let items = if heavy {
        Just(AmountRule::Fixed(8)).boxed()
    } else {
        prop_oneof![Just(AmountRule::Random), (0u32..=8).prop_map(AmountRule::Fixed)].boxed()
    };
    (shells, items).prop_map(|(shells, items)| LoadRule { shells, items })
}

fn round_rules(heavy: bool) -> impl Strategy<Value = RoundRules> {
    let health = prop_oneof![Just(HealthRule::Random), (1u32..=5).prop_map(HealthRule::Fixed)];
    (health, prop::array::uniform4(load_rule(heavy)), item_rules(heavy)).prop_map(|(health, loads, items)| RoundRules {
        health,
        loads,
        items,
    })
}

/// A config inside the supported domain: what `rust-tapes.mjs` plays.
fn supported_config(heavy: bool) -> impl Strategy<Value = Config> {
    (table(), vec(round_rules(heavy), 1..=3)).prop_filter_map("a valid plan", |(table, rounds)| Config::new(table, &rounds).ok())
}

fn ring<T: Copy + Debug + 'static>(table: Table, values: impl Strategy<Value = T>) -> impl Strategy<Value = Ring<T>> {
    prop::array::uniform4(values).prop_map(move |values| {
        SEATS
            .iter()
            .zip(values)
            .fold(Ring::fill(table, values[0]), |ring, (seat, value)| ring.set(*seat, value))
    })
}

fn slots() -> impl Strategy<Value = Slots> {
    prop::array::uniform8(prop::option::of(item())).prop_map(|cells| {
        Slot::ORDER
            .iter()
            .zip(cells)
            .fold(Slots::EMPTY, |slots, (slot, cell)| slots.put(*slot, cell))
    })
}

fn load() -> impl Strategy<Value = Load> {
    (num(), num()).prop_map(|(live, blank)| Load { live, blank })
}

fn gun() -> impl Strategy<Value = Gun> {
    vec(shell(), 0..70).prop_map(Gun::from_shells)
}

fn direction() -> impl Strategy<Value = Direction> {
    prop_oneof![Just(Direction::Clockwise), Just(Direction::CounterClockwise)]
}

fn items() -> impl Strategy<Value = Items> {
    vec(item(), 0..9).prop_map(|items| items.into_iter().fold(Items::EMPTY, Items::with))
}

fn deck(table: Table) -> impl Strategy<Value = Deck> {
    vec(0u32..12, 0..12).prop_map(move |ids| Deck::of_ids(table, ids))
}

fn world() -> BoxedStrategy<World> {
    let check = prop_oneof![Just(FirstDeathCheck::Off), Just(FirstDeathCheck::On)];
    let flags = (any::<bool>(), any::<bool>(), check, any::<bool>());
    let counts = (num(), num(), num(), num());
    let seats = (seat(), prop::option::of(seat()), prop::option::of(seat()), direction());
    let gear = (gun(), load());
    let decks = (deck(Table::TwoSeats), deck(Table::ThreeSeats), deck(Table::FourSeats));
    (flags, counts, seats, gear, decks)
        .prop_map(
            |(
                (before_round, first_sequence, checking_first_death, sawed),
                (round_index, load_index, round_health, item_amount),
                (first_turn, turn, first_death, direction),
                (gun, shown),
                (two, three, four),
            )| {
                World {
                    before_round,
                    round_index,
                    load_index,
                    first_sequence,
                    round_health,
                    first_turn,
                    turn,
                    direction,
                    first_death,
                    checking_first_death,
                    item_amount,
                    sawed,
                    gun,
                    shown,
                    decks: Decks { two, three, four },
                }
            },
        )
        .boxed()
}

fn seat_record() -> impl Strategy<Value = SeatRecord> {
    let jam = prop_oneof![Just(Jam::Free), Just(Jam::Jammed), Just(Jam::JammedSkipped)];
    (num(), jam, num(), slots()).prop_map(|(health, jam, cash, slots)| SeatRecord { health, jam, cash, slots })
}

fn grabs(table: Table) -> impl Strategy<Value = Grabs> {
    (
        any::<bool>(),
        ring(table, any::<bool>()),
        ring(table, prop::option::of(item())),
        ring(table, num()),
        ring(table, any::<bool>()),
    )
        .prop_map(|(distributing, grabbing, holding, granted, intake)| Grabs {
            distributing,
            grabbing,
            holding,
            granted,
            intake,
        })
}

fn phase() -> BoxedStrategy<Phase> {
    prop_oneof![
        Just(Phase::NeedFirst),
        Just(Phase::NeedHealth),
        Just(Phase::NeedAmount),
        Just(Phase::NeedBatch),
        (load(), gun(), num()).prop_map(|(load, shells, i)| Phase::NeedSwap { load, shells, i }),
        seat().prop_map(|seat| Phase::Idle { seat }),
        Just(Phase::Ended),
        prop::option::of(seat()).prop_map(|holder| Phase::Blocked { holder }),
        Just(Phase::Stalled),
        (seat(), any::<bool>(), prop::option::of(seat())).prop_map(|(from, passing, winner)| Phase::NeedTurnAmount {
            from,
            passing,
            winner
        }),
        (seat(), item(), item(), items()).prop_map(|(seat, first, second, rest)| Phase::NeedItem { seat, first, second, rest }),
        (seat(), seat(), prop::sample::select(Slot::ORDER.to_vec())).prop_map(|(seat, owner, slot)| Phase::NeedPhone { seat, owner, slot }),
    ]
    .boxed()
}

fn arbitrary_state(table: Table) -> BoxedStrategy<State> {
    (world(), ring(table, seat_record()), grabs(table), phase())
        .prop_map(|(world, players, grabs, phase)| State {
            world,
            players,
            grabs,
            phase,
        })
        .boxed()
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

fn check_menu(state: &State, menu: &buckshot_rules::Menu) -> Result<(), TestCaseError> {
    let table = state.players.table();
    let me = menu.seat();
    prop_assert!(!menu.is_empty());
    prop_assert!(menu.len() <= MENU_CAPACITY);
    prop_assert!(table.has(me));
    prop_assert!(alive(state, me), "{me:?} is dead at a Choose");
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
        prop_assert!(ok, "{:?} is not backed by the state", legal.option());
    }
    Ok(())
}

fn check_state(config: &Config, state: &State) -> Result<(), TestCaseError> {
    let world = &state.world;
    prop_assert!(world.round_index < config.plan_length());
    if !matches!(state.phase, Phase::NeedAmount) && world.round_health > 0 {
        for (seat, record) in state.players.entries() {
            prop_assert!(
                record.health <= world.round_health,
                "{seat:?} has {} of {}",
                record.health,
                world.round_health
            );
        }
    }
    let total = world.shown.live.saturating_add(world.shown.blank);
    prop_assert!(world.gun.len() <= total, "gun of {} over shown {:?}", world.gun.len(), world.shown);
    Ok(())
}

fn check_step(before: &State, after: &State) -> Result<(), TestCaseError> {
    prop_assert!(after.world.round_index >= before.world.round_index);
    for (seat, record) in after.players.entries() {
        let old = before.players.get(seat).map_or(0, |old| old.cash);
        prop_assert!(record.cash >= old, "{seat:?} lost cash");
    }
    Ok(())
}

fn some<T>(value: Option<T>) -> Result<T, TestCaseError> {
    value.ok_or_else(|| TestCaseError::fail("expected a value"))
}

fn external(config: &Config, state: State, event: Event) -> Result<Stepped, TestCaseError> {
    step_event(config, state, event).map_err(|error| TestCaseError::fail(format!("{event:?} at a valid request: {error}")))
}

/// What one answer does at one point: determinism, event equivalence and the
/// errors of a wrong or out-of-range event.
fn check_events(
    config: &Config,
    state: State,
    request: &Request,
    event: Event,
    answer: Answer,
    stepped: &Stepped,
) -> Result<(), TestCaseError> {
    prop_assert_eq!(&step(config, state, answer), stepped);
    prop_assert_eq!(&external(config, state, event)?, stepped);
    match request {
        Request::Draw { range, .. } => {
            prop_assert_eq!(
                step_event(config, state, Event::Choose(0)),
                Err(RuleError::WrongEvent {
                    expected: RequestKind::Draw,
                    got: RequestKind::Choose
                })
            );
            let top = step(config, state, Answer::Draw(range.value(range.extra.saturating_add(1))));
            prop_assert_eq!(external(config, state, Event::Draw(u32::MAX))?, top);
        }
        Request::Choose(menu) => {
            prop_assert_eq!(
                step_event(config, state, Event::Draw(0)),
                Err(RuleError::WrongEvent {
                    expected: RequestKind::Choose,
                    got: RequestKind::Draw
                })
            );
            let last = some(menu.clamped(u32::MAX))?;
            let top = step(config, state, Answer::Choice(last));
            prop_assert_eq!(external(config, state, Event::Choose(u32::MAX))?, top);
        }
        Request::Finished | Request::Stuck => {}
    }
    Ok(())
}

fn check_terminal(config: &Config, state: State) -> Result<(), TestCaseError> {
    let unchanged = Stepped {
        state,
        notes: buckshot_rules::Notes::default(),
    };
    for event in [Event::Draw(0), Event::Draw(u32::MAX), Event::Choose(0), Event::Choose(u32::MAX)] {
        prop_assert_eq!(step_event(config, state, event), Ok(unchanged.clone()));
    }
    Ok(())
}

fn note_sizes(stepped: &Stepped, walked: &mut Walked) -> Result<(), TestCaseError> {
    prop_assert!(!stepped.notes.truncated());
    walked.max_notes = walked.max_notes.max(stepped.notes.as_slice().len());
    Ok(())
}

/// A walk's visited states and the largest menu and notes it saw.
#[derive(Default)]
struct Walked {
    states: Vec<State>,
    max_menu: usize,
    max_notes: usize,
    finished: bool,
}

/// Plays a reachable game, checking every invariant, and returns the states visited.
fn walk(config: &Config, answers: &[u32]) -> Result<Walked, TestCaseError> {
    let mut current = start(config);
    let mut walked = Walked::default();
    note_sizes(&current, &mut walked)?;
    walked.states.push(current.state);
    for n in answers {
        let state = current.state;
        check_state(config, &state)?;
        let request = request(config, &state);
        match &request {
            Request::Choose(menu) => {
                check_menu(&state, menu)?;
                walked.max_menu = walked.max_menu.max(menu.len());
            }
            Request::Finished => {
                prop_assert!(matches!(state.phase, Phase::Ended));
                walked.finished = true;
            }
            Request::Draw { .. } | Request::Stuck => {}
        }
        let Some((event, answer)) = answer_for(&request, *n) else {
            check_terminal(config, state)?;
            break;
        };
        let next = step(config, state, answer);
        note_sizes(&next, &mut walked)?;
        check_events(config, state, &request, event, answer, &next)?;
        check_step(&state, &next.state)?;
        walked.states.push(next.state);
        current = next;
    }
    Ok(walked)
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

const ANSWERS: usize = 400;

proptest! {
    #![proptest_config(config(512))]

    #[test]
    fn walks_hold_invariants(config in supported_config(false), answers in vec(any::<u32>(), ANSWERS)) {
        walk(&config, &answers)?;
    }

    #[test]
    fn forged_tokens_do_not_panic(
        a in supported_config(false),
        b in supported_config(false),
        a_answers in vec(any::<u32>(), 120),
        b_answers in vec(any::<u32>(), 120),
        n in any::<u32>(),
    ) {
        let from_a = walk(&a, &a_answers)?.states;
        let from_b = walk(&b, &b_answers)?.states;
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
}

proptest! {
    #![proptest_config(config(256))]

    #[test]
    fn arbitrary_states_do_not_panic(
        (config, state) in (supported_config(false), table()).prop_flat_map(|(config, table)| (Just(config), arbitrary_state(table))),
        range in (any::<u32>(), any::<u32>()).prop_map(|(lo, extra)| Range { lo, extra }),
        n in any::<u32>(),
        answers in vec(any::<u32>(), 40),
    ) {
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
}

fn wild_round() -> impl Strategy<Value = RoundRules> {
    let shells = prop_oneof![
        Just(ShellRule::Random),
        (num(), num()).prop_map(|(live, blank)| ShellRule::Fixed { live, blank }),
        num().prop_map(|live| ShellRule::AllLive { live }),
    ];
    let amount = prop_oneof![Just(AmountRule::Random), num().prop_map(AmountRule::Fixed)];
    let load = (shells, amount).prop_map(|(shells, items)| LoadRule { shells, items });
    let rule = (any::<bool>(), num(), num()).prop_map(|(enabled, per_player, on_table)| ItemRule {
        enabled,
        per_player,
        on_table,
    });
    let health = prop_oneof![Just(HealthRule::Random), num().prop_map(HealthRule::Fixed)];
    (health, prop::array::uniform4(load), prop::array::uniform9(rule)).prop_map(|(health, loads, items)| RoundRules {
        health,
        loads,
        items,
    })
}

proptest! {
    #![proptest_config(config(512))]

    #[test]
    fn config_validation_matches_the_domain(table in table(), rounds in vec(wild_round(), 0..6)) {
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
                prop_assert!(valid);
                prop_assert_eq!(config.rounds().len(), rounds.len());
                black_box(start(&config));
            }
            Err(error) => {
                prop_assert!(!valid);
                prop_assert!(matches!(error, RuleError::Config(_)));
            }
        }
    }
}

#[test]
fn menus_and_notes_stay_in_capacity() {
    let seen = RefCell::new(Walked::default());
    let games = Cell::<usize>::new(0);
    let finished = Cell::<usize>::new(0);
    let strategy = (prop_oneof![supported_config(true), supported_config(false)], vec(any::<u32>(), 600));
    TestRunner::new(config(1000))
        .run(&strategy, |(config, answers)| {
            let walked = walk(&config, &answers)?;
            let mut seen = seen.borrow_mut();
            seen.max_menu = seen.max_menu.max(walked.max_menu);
            seen.max_notes = seen.max_notes.max(walked.max_notes);
            finished.set(finished.get().saturating_add(usize::from(walked.finished)));
            games.set(games.get().saturating_add(1));
            Ok(())
        })
        .unwrap();
    let (menu, notes) = (seen.borrow().max_menu, seen.borrow().max_notes);
    println!(
        "{} walks, {} finished; max menu {menu}/{MENU_CAPACITY}, max notes {notes}/{NOTES_CAPACITY}",
        games.get(),
        finished.get()
    );
    assert!(menu < MENU_CAPACITY && notes < NOTES_CAPACITY);
}

proptest! {
    #![proptest_config(config(128))]

    #[test]
    fn wild_valid_configs_do_not_panic(
        table in table(),
        rounds in vec(wild_round(), 1..=3),
        answers in vec(any::<u32>(), 200),
    ) {
        if let Ok(config) = Config::new(table, &rounds) {
            let mut state = start(&config).state;
            for n in &answers {
                let request = request(&config, &state);
                let Some((_, answer)) = answer_for(&request, *n) else { break };
                state = step(&config, state, answer).state;
            }
        }
    }
}
