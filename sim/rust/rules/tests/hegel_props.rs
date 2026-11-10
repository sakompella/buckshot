//! Property tests over the public API of `buckshot-rules`, written with Hegel: random walks keep
//! the machine's invariants, steps are deterministic, external input never panics, and forged
//! tokens and arbitrary states are defined (no panic). Case counts are pinned per test (a pinned
//! count beats `HEGEL_TEST_CASES`); `HEGEL_SEED` replays a run and a failure replays from `.hegel/`.

use std::hint::black_box;

use buckshot_rules::testing::{any_u32, arbitrary_state, between, count, flag, many, num, seat, slots, supported_config, table};
use buckshot_rules::{
    AmountRule, Answer, Config, EnumMap, Event, HealthRule, IdleOption, Item, ItemRule, LegalMove, LoadRule, MenuInputs, Phase, Range,
    Request, RequestKind, RoundRules, RuleError, Seat, ShellRule, Slot, State, Stepped, World, request, start, step, step_event,
};
use hegel::TestCase;
use hegel::generators as gs;

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

/// What one answer does at one point: determinism, event equivalence and the
/// errors of a wrong or out-of-range event.
fn check_events(config: &Config, state: State, request: &Request, event: Event, answer: Answer, stepped: &Stepped) {
    assert_eq!(&step(config, state, answer), stepped, "step is not deterministic");
    assert_eq!(
        step_event(config, state, event).as_ref(),
        Ok(stepped),
        "the event differs from its answer"
    );
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
                step_event(config, state, Event::Draw(u32::MAX)),
                Ok(top),
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
            let top = menu.clamped(u32::MAX).map(|last| step(config, state, Answer::Choice(last)));
            assert!(
                top.is_some_and(|top| step_event(config, state, Event::Choose(u32::MAX)) == Ok(top)),
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

fn check_notes(stepped: &Stepped) {
    assert!(!stepped.notes.truncated(), "notes were truncated");
}

/// A walk's visited states.
#[derive(Default)]
struct Walked {
    states: Vec<State>,
}

/// Plays a reachable game of up to `steps` drawn answers, checking every invariant, and returns the states visited.
fn walk(tc: &TestCase, config: &Config, steps: usize) -> Walked {
    let mut current = start(config);
    let mut walked = Walked::default();
    check_notes(&current);
    walked.states.push(current.state);
    for _ in 0..steps {
        let state = current.state;
        check_state(config, &state);
        let request = request(config, &state);
        match &request {
            Request::Choose(menu) => check_menu(&state, menu),
            Request::Finished => {
                assert!(matches!(state.phase, Phase::Ended), "Finished outside the Ended phase");
            }
            Request::Draw { .. } | Request::Stuck => {}
        }
        let Some((event, answer)) = draw_answer(tc, &request) else {
            check_terminal(config, state);
            break;
        };
        let next = step(config, state, answer);
        check_notes(&next);
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

/// States with the same [`MenuInputs`] have the same request, whatever else
/// differs: the search reuses an Idle menu's answer across them.
#[hegel::test(test_cases = 256)]
fn menu_inputs_decide_the_request(tc: TestCase) {
    let config = supported_config(&tc, false);
    let table = config.table();
    let state = State {
        phase: Phase::Idle { seat: seat(&tc) },
        ..arbitrary_state(&tc, table)
    };
    let other = arbitrary_state(&tc, table);
    let twin = State {
        world: World {
            sawed: state.world.sawed,
            ..other.world
        },
        players: state.players,
        phase: state.phase,
        ..other
    };
    assert_eq!(
        MenuInputs::of(&twin),
        MenuInputs::of(&state),
        "the twin has the state's menu inputs"
    );
    assert_eq!(
        request(&config, &twin),
        request(&config, &state),
        "equal menu inputs, different requests"
    );
}

/// `Slots::items` lists the occupied slots' items in slot order.
#[hegel::test(test_cases = 256)]
fn slot_items_are_the_occupied_slots(tc: TestCase) {
    let slots = slots(&tc);
    let occupied: Vec<Item> = slots.entries().filter_map(|(_, item)| item).collect();
    assert_eq!(slots.items().collect::<Vec<_>>(), occupied, "items of {slots:?}");
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
        items: EnumMap::from_fn(|_| ItemRule {
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
