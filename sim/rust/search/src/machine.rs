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
/// the same answers as a plain per-world `token` would.
#[cfg(test)]
mod reuse {
    use buckshot_rules::testing::{any_u32, between, count, flag, grabs, item, many, maybe, num, pick, ring, seat, slots, table, world};
    use buckshot_rules::{
        AmountRule, Config, EnumMap, HealthRule, IdleOption, Item, ItemRule, Jam, LoadRule, MenuInputs, Phase, Request, RoundRules,
        SeatRecord, ShellRule, Slot, Slots, State, Table, World, request,
    };
    use hegel::TestCase;
    use hegel::generators as gs;

    use super::{answer_reusing, token};

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
            items: EnumMap::from_fn(|_| ItemRule {
                enabled: tc.draw_silent(gs::weighted_booleans(0.75)),
                per_player: between(tc, 1, 8),
                on_table: 32,
            }),
        });
        tc.note(&format!("{table:?} {rounds:?}"));
        Config::new(table, &rounds).unwrap_or_else(|error| panic!("a supported plan is valid: {error}"))
    }

    /// A seat with every slot filled: Adrenaline, a Jammer and a Beer ahead of
    /// the rest, so a table of them keeps a thief stocked for steals and jams.
    fn rich_slots(tc: &TestCase) -> Slots {
        let fixed = [Item::Adrenaline, Item::Jammer, Item::Beer];
        let rest = std::iter::repeat_with(|| item(tc));
        Slot::ORDER
            .iter()
            .zip(fixed.into_iter().chain(rest))
            .fold(Slots::EMPTY, |slots, (slot, held)| slots.put(*slot, Some(held)))
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
            slots: if rich { rich_slots(tc) } else { slots(tc) },
        }
    }

    /// An Idle world at the table: `rich` seats guarantee a menu of steals and
    /// jams, loose ones mostly idle on their shots; a loose seat may be away
    /// from the table, where the request is `Stuck`.
    fn idle(tc: &TestCase, of: Table, rich: bool) -> State {
        let seat = if rich { pick(tc, of.seats().as_slice()) } else { seat(tc) };
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
            _ => Phase::Blocked { holder: maybe(tc, seat) },
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
