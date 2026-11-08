//! The simple machine as the player drives it (`simple/main.bend`'s `answer`
//! and `request`), with the round winner its notes announce.

use buckshot_rules::{Answer, Config, GameEvent, MenuInputs, Note, Notes, Request, Seat, State, request, step_into};

/// `exact`'s note: the first `RoundWon`.
pub fn round_won(notes: &[Note]) -> Option<Seat> {
    notes.iter().find_map(|note| match *note {
        Note::Shown(GameEvent::RoundWon { seat, .. }) => Some(seat),
        Note::Shown(_) | Note::Told { .. } => None,
    })
}

/// The answer `M.answer(state, n)` gives at `request`: a draw takes the n-th
/// value of its range, a choice the n-th move (the last past the end); an end
/// takes none.
pub fn token(request: &Request, n: u32) -> Option<Answer> {
    match request {
        Request::Draw { range, .. } => Some(Answer::Draw(range.value(n))),
        Request::Choose(menu) => menu.clamped(n).map(Answer::Choice),
        Request::Finished | Request::Stuck => None,
    }
}

/// The answer `M.answer(state, n)` takes, as [`token`] of the state's
/// request. `last` holds an earlier state's Idle menu inputs and its answer at
/// the same `n`; a state with the same inputs reuses that answer.
pub fn answer_reusing(config: &Config, state: &State, n: u32, last: &mut Option<(MenuInputs, Option<Answer>)>) -> Option<Answer> {
    let inputs = MenuInputs::of(state);
    if let (Some(inputs), Some((seen, answer))) = (inputs, last.as_ref())
        && inputs == *seen
    {
        return *answer;
    }
    let answer = token(&request(config, state), n);
    if let Some(inputs) = inputs {
        *last = Some((inputs, answer));
    }
    answer
}

/// `M.answer(state, n)` with its notes written into `notes`; `None` where
/// the state stands, with no notes.
pub fn answer_into(config: &Config, state: &State, n: u32, notes: &mut Notes) -> Option<State> {
    let answer = token(&request(config, state), n)?;
    Some(step_into(config, *state, answer, notes))
}

/// The reuse `play` relies on, as a Hegel property: one Idle menu answer,
/// reused across worlds that share the seat, the players and `sawed`, gives
/// the same answers as a plain per-world `token` would (the rules crate's
/// `tests/hegel_props.rs` in style; the generators here are trimmed to the
/// states the reuse reads).
#[cfg(test)]
mod reuse {
    use buckshot_rules::{
        AmountRule, Config, Deck, Decks, Direction, FirstDeathCheck, Grabs, Gun, HealthRule, IdleOption, Item, ItemRule, Jam, Load,
        LoadRule, MenuInputs, Phase, Request, Ring, RoundRules, Seat, SeatRecord, Shell, ShellRule, Slot, Slots, State, Table, World,
        request,
    };
    use hegel::TestCase;
    use hegel::generators as gs;

    use super::{answer_reusing, token};

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

    fn table(tc: &TestCase) -> Table {
        #[cfg(feature = "seats-2-4")]
        let tables = [Table::TwoSeats, Table::ThreeSeats, Table::FourSeats];
        #[cfg(not(feature = "seats-2-4"))]
        let tables = [Table::TwoSeats];
        pick(tc, &tables)
    }

    fn item(tc: &TestCase) -> Item {
        pick(tc, &Item::ORDER)
    }

    fn shell(tc: &TestCase) -> Shell {
        pick(tc, &[Shell::Live, Shell::Blank])
    }

    fn gun(tc: &TestCase) -> Gun {
        Gun::from_shells(many(tc, 0, 64, shell)).expect("64 shells fit the gun")
    }

    fn direction(tc: &TestCase) -> Direction {
        pick(tc, &[Direction::Clockwise, Direction::CounterClockwise])
    }

    fn deck(tc: &TestCase, of: Table) -> Deck {
        let last = u32::try_from(of.deck().len()).map_or(0, |len| len.saturating_sub(1));
        let ids = tc.draw_silent(gs::vecs(gs::integers::<u32>().max_value(last)).max_size(11));
        Deck::of_ids(of, ids).expect("ids within the deck")
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
            first_turn: pick(tc, &SEATS),
            turn: maybe(tc, |tc| pick(tc, &SEATS)),
            first_death: maybe(tc, |tc| pick(tc, &SEATS)),
            direction: direction(tc),
            gun: gun(tc),
            shown: Load {
                live: num(tc),
                blank: num(tc),
            },
            decks: Decks {
                two: deck(tc, Table::TwoSeats),
                #[cfg(feature = "seats-2-4")]
                three: deck(tc, Table::ThreeSeats),
                #[cfg(feature = "seats-2-4")]
                four: deck(tc, Table::FourSeats),
            },
        }
    }

    /// A config inside the supported domain: the plans `rust-tapes.mjs` plays.
    fn supported_config(tc: &TestCase) -> Config {
        let table = table(tc);
        let load = |t: &TestCase| LoadRule {
            shells: ShellRule::Fixed {
                live: between(t, 0, 7),
                blank: between(t, 1, 8),
            },
            items: AmountRule::Fixed(between(t, 0, 8)),
        };
        let rounds: Vec<RoundRules> = many(tc, 1, 3, |tc| RoundRules {
            health: HealthRule::Fixed(between(tc, 1, 5)),
            loads: std::array::from_fn(|_| load(tc)),
            items: std::array::from_fn(|_| ItemRule {
                enabled: tc.draw_silent(gs::weighted_booleans(0.75)),
                per_player: between(tc, 1, 8),
                on_table: 32,
            }),
        });
        tc.note(&format!("{table:?} {rounds:?}"));
        Config::new(table, &rounds).unwrap_or_else(|error| panic!("a supported plan is valid: {error}"))
    }

    fn ring<T: Copy>(tc: &TestCase, of: Table, mut make: impl FnMut(&TestCase) -> T) -> Ring<T> {
        let values: [T; 4] = std::array::from_fn(|_| make(tc));
        SEATS
            .iter()
            .zip(values)
            .fold(Ring::fill(of, values[0]), |ring, (seat, value)| ring.set(*seat, value))
    }

    fn grabs(tc: &TestCase, of: Table) -> Grabs {
        Grabs {
            distributing: flag(tc),
            grabbing: ring(tc, of, flag),
            holding: ring(tc, of, |tc| maybe(tc, item)),
            granted: ring(tc, of, num),
            intake: ring(tc, of, flag),
        }
    }

    /// A seat with an empty slot now and then.
    fn loose_slots(tc: &TestCase) -> Slots {
        Slot::ORDER
            .iter()
            .fold(Slots::EMPTY, |slots, slot| slots.put(*slot, maybe(tc, item)))
    }

    /// A seat with every slot filled: Adrenaline, a Jammer and a Beer ahead of
    /// the rest, so a table of them keeps a thief stocked for steals and jams.
    fn rich_slots(tc: &TestCase) -> Slots {
        let fixed = [Item::Adrenaline, Item::Jammer, Item::Beer];
        Slot::ORDER.iter().enumerate().fold(Slots::EMPTY, |slots, (i, slot)| {
            let held = fixed.get(i).copied().unwrap_or_else(|| item(tc));
            slots.put(*slot, Some(held))
        })
    }

    /// Alive, unjammed, with full slots: a `rich` seat always holds the
    /// Adrenaline, the Jammer and the Beer of `rich_slots`.
    fn seat_record(tc: &TestCase, rich: bool) -> SeatRecord {
        SeatRecord {
            health: if rich { between(tc, 1, 8) } else { num(tc) },
            jam: if rich {
                Jam::Free
            } else {
                pick(tc, &[Jam::Free, Jam::Jammed, Jam::JammedSkipped])
            },
            cash: num(tc),
            slots: if rich { rich_slots(tc) } else { loose_slots(tc) },
        }
    }

    /// An Idle world at the table: `rich` seats guarantee a menu of steals and
    /// jams, loose ones mostly idle on their shots; a loose seat may be away
    /// from the table, where the request is `Stuck`.
    fn idle(tc: &TestCase, of: Table, rich: bool) -> State {
        let seated = || SEATS.iter().copied().filter(|seat| of.has(*seat)).collect::<Vec<_>>();
        let seat = if rich { pick(tc, &seated()) } else { pick(tc, &SEATS) };
        State {
            world: world(tc),
            players: ring(tc, of, |tc| seat_record(tc, rich)),
            grabs: grabs(tc, of),
            phase: Phase::Idle { seat },
        }
    }

    /// A second world that shares the state's menu inputs — the Idle request
    /// reads the seat, the players and `sawed` — over a fresh world and grabs.
    fn twin(tc: &TestCase, of: Table, base: &State) -> State {
        let other = idle(tc, of, false);
        State {
            world: World {
                sawed: base.world.sawed,
                ..other.world
            },
            players: base.players,
            phase: base.phase,
            grabs: other.grabs,
        }
    }

    /// A state away from Idle: draws, ended and stuck games, whose answers no
    /// cache may keep.
    fn elsewhere(tc: &TestCase, of: Table) -> State {
        let phase = match count(tc, 0, 5) {
            0 => Phase::NeedFirst,
            1 => Phase::NeedHealth,
            2 => Phase::NeedAmount,
            3 => Phase::Ended,
            4 => Phase::Stalled,
            _ => Phase::Blocked {
                holder: maybe(tc, |tc| pick(tc, &SEATS)),
            },
        };
        State {
            phase,
            ..idle(tc, of, false)
        }
    }

    /// The answer index `play` shares over every world of one belief: mostly
    /// within a menu, sometimes past its end.
    fn move_index(tc: &TestCase) -> u32 {
        match count(tc, 0, 3) {
            0..2 => between(tc, 0, 11),
            _ => any_u32(tc),
        }
    }

    /// The moves that make a menu non-trivial: a jam, a steal or a steal-jam.
    fn steals_or_jams(request: &Request) -> bool {
        let Request::Choose(menu) = request else {
            return false;
        };
        menu.moves().any(|legal| {
            matches!(
                legal.option(),
                IdleOption::JamWith { .. } | IdleOption::StealWith { .. } | IdleOption::StealJamWith { .. }
            )
        })
    }

    /// The worlds of one `play` call, in order: a menu-rich world and the twin
    /// that shares its menu inputs, then loose worlds, each maybe followed by
    /// its twin, with away-from-Idle worlds between them.
    fn sequence(tc: &TestCase, of: Table) -> Vec<State> {
        let mut sequence = Vec::new();
        let rich = idle(tc, of, true);
        // A rich world always answers to a menu of steals and jams, and its
        // twin exercises the reuse on menu inputs `last` still holds.
        let sibling = twin(tc, of, &rich);
        assert_eq!(
            MenuInputs::of(&sibling),
            MenuInputs::of(&rich),
            "the twin must share the rich world's menu inputs"
        );
        sequence.push(rich);
        sequence.push(sibling);
        for _ in 0..count(tc, 2, 8) {
            if flag(tc) {
                sequence.push(elsewhere(tc, of));
            }
            let state = idle(tc, of, false);
            if let Some(shared_world) = flag(tc).then(|| twin(tc, of, &state)) {
                assert_eq!(
                    MenuInputs::of(&shared_world),
                    MenuInputs::of(&state),
                    "the twin must share the world's menu inputs"
                );
                sequence.push(state);
                sequence.push(shared_world);
            } else {
                sequence.push(state);
            }
        }
        sequence
    }

    #[hegel::test(test_cases = 256)]
    fn reused_answers_match_the_per_world_answer(tc: TestCase) {
        let config = supported_config(&tc);
        let sequence = sequence(&tc, config.table());
        let index = move_index(&tc);
        let mut menus = 0u32;
        let mut last = None;
        for state in &sequence {
            let request = request(&config, state);
            let reused = answer_reusing(&config, state, index, &mut last);
            let plain = token(&request, index);
            assert_eq!(reused, plain, "the reused answer differs from the plain one at {state:?}");
            if steals_or_jams(&request) {
                menus = menus.saturating_add(1);
            }
        }
        assert!(menus > 0, "no generated world had a menu with a steal or a jam");
    }
}
