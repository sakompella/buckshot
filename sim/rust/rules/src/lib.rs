//! The Buckshot simple machine (`sim/bend-mp/simple/`), mirrored from Bend.
//!
//! Bend is the source of truth: every function here follows one Bend def,
//! and each match arm starts with `branch!` naming the Bend branch it
//! mirrors (see [`branch::B`]). The core never allocates: the state is a
//! flat `Copy` value, and notes and menus live in fixed buffers. Each buffer
//! is sized for its most entries, and one that filled up would panic rather
//! than drop an entry; notes, which no rule bounds, are flagged as truncated.
//!
//! The `seats-2-4` feature (default) holds every table; `seats-2` holds only
//! the two-seat table, so a ring stores two seats.
//!
//! [`step`] is infallible and trusts its caller: the [`Answer`] token must come
//! from the state's own [`Request`] (a precondition the types do not enforce,
//! since tokens can be made and reused). [`step_event`] is for external input:
//! it validates a raw number into a token with Bend's clamp.

#[cfg(all(feature = "seats-2-4", feature = "seats-2"))]
compile_error!("the features `seats-2-4` and `seats-2` exclude each other");
#[cfg(not(any(feature = "seats-2-4", feature = "seats-2")))]
compile_error!("enable one of the features `seats-2-4` (default) and `seats-2`");

use arrayvec::ArrayVec;

use crate::branch::B;

/// Names the Bend branch a match arm mirrors; its first statement. Records
/// the branch under the `trace` feature and compiles to nothing otherwise.
macro_rules! branch {
    ($b:expr) => {{
        #[cfg(feature = "trace")]
        $crate::branch::record($b);
        #[cfg(not(feature = "trace"))]
        let _: $crate::branch::B = $b;
    }};
}

mod branch;
mod domain;
mod items;
mod machine;
mod point;
mod rules;
mod state;

#[cfg(feature = "trace")]
pub use branch::take_trace;
pub use domain::{
    AmountRule, Config, Damage, Direction, DrawValue, GameEvent, Gun, HealthRule, Item, ItemRule, Items, Label, Load, LoadRule, Note,
    PHONE_CAP, Range, Ring, RoundRules, Seat, Seats, Secret, Shell, ShellRule, Slot, Slots, Table, prize,
};
pub use machine::{initial, start, step, step_into};
pub use point::{MenuInputs, draw_request, request};
pub use rules::{alive, load_actual, load_next, predecessor, world_load_rule};
pub use state::{Batch, Deck, Decks, FirstDeathCheck, Grabs, Jam, Phase, Players, SeatRecord, State, World};

/// A whole move as the agent tools name it (simple/state.bend `Move`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Move {
    Shoot { target: Seat },
    Use { item: Item },
    Jam { target: Seat },
    Steal { owner: Seat, item: Item },
    StealJam { owner: Seat, target: Seat },
}

/// A move with the slots it acts on (simple/state.bend `IdleOption`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum IdleOption {
    ShootAt {
        target: Seat,
    },
    UseSlot {
        slot: Slot,
        item: Item,
    },
    JamWith {
        slot: Slot,
        target: Seat,
    },
    StealWith {
        adrenaline: Slot,
        owner: Seat,
        slot: Slot,
        item: Item,
    },
    StealJamWith {
        adrenaline: Slot,
        owner: Seat,
        slot: Slot,
        target: Seat,
    },
}

impl IdleOption {
    /// `option.move`.
    #[must_use]
    pub fn to_move(self) -> Move {
        match self {
            Self::ShootAt { target } => {
                branch!(B::SimplePointOptionMoveShootAt);
                Move::Shoot { target }
            }
            Self::UseSlot { item, .. } => {
                branch!(B::SimplePointOptionMoveUseSlot);
                Move::Use { item }
            }
            Self::JamWith { target, .. } => {
                branch!(B::SimplePointOptionMoveJamWith);
                Move::Jam { target }
            }
            Self::StealWith { owner, item, .. } => {
                branch!(B::SimplePointOptionMoveStealWith);
                Move::Steal { owner, item }
            }
            Self::StealJamWith { owner, target, .. } => {
                branch!(B::SimplePointOptionMoveStealJamWith);
                Move::StealJam { owner, target }
            }
        }
    }
}

/// Room for every Idle menu: at most 4 shots, 8 uses, 3 jams, 24 steals
/// (3 owners by 8 slots) and 9 steal-jams (`point.rs` checks the sum).
pub const MENU_CAPACITY: usize = 64;

/// One seat's legal moves at an Idle point, in Bend's menu order.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Menu {
    seat: Seat,
    options: ArrayVec<IdleOption, MENU_CAPACITY>,
}

impl Menu {
    #[must_use]
    pub const fn seat(&self) -> Seat {
        self.seat
    }

    #[must_use]
    pub const fn len(&self) -> usize {
        self.options.len()
    }

    #[must_use]
    pub const fn is_empty(&self) -> bool {
        self.options.is_empty()
    }

    /// The legal moves, in menu order.
    pub fn moves(&self) -> impl Iterator<Item = LegalMove> + '_ {
        self.options.iter().map(|option| LegalMove { option: *option })
    }

    /// The move at `index`, clamped to the last move as Bend's `answer.request` does.
    #[must_use]
    pub fn clamped(&self, index: u32) -> Option<LegalMove> {
        let last = self.options.len().checked_sub(1)?;
        let at = usize::try_from(index).map_or(last, |i| i.min(last));
        self.options.get(at).map(|option| LegalMove { option: *option })
    }

    /// The index of the first menu entry that makes `wanted`.
    #[must_use]
    pub fn find(&self, wanted: Move) -> Option<usize> {
        self.options.iter().position(|option| option.to_move() == wanted)
    }
}

/// A legal move of some state's [`Menu`]. Nothing ties it to that state:
/// [`step`] on another state is defined (no panic) but plays the move's
/// slots as given, which may not be legal there.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct LegalMove {
    option: IdleOption,
}

impl LegalMove {
    #[must_use]
    pub const fn option(self) -> IdleOption {
        self.option
    }

    #[must_use]
    pub fn to_move(self) -> Move {
        self.option.to_move()
    }
}

/// What the machine asks for at a request point (simple/state.bend `Request`).
#[derive(Clone, Debug, PartialEq, Eq)]
#[expect(clippy::large_enum_variant, reason = "the menu is stored inline so a step never allocates")]
pub enum Request {
    Draw { label: Label, range: Range },
    Choose(Menu),
    Finished,
    Stuck,
}

/// An answer token for [`step`]: a value from a Draw request's range or a
/// move from a Choose request's menu. Tokens are `Copy` and not tied to the
/// state they came from; see [`step`] for what the caller must pass.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Answer {
    Draw(DrawValue),
    Choice(LegalMove),
}

/// A raw answer from outside (a tape, a replay, a CLI): the Nat Bend's
/// `answer(state, n)` takes, tagged with the request kind it is meant for.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Event {
    Draw(u32),
    Choose(u32),
}

/// The kind of a request point, for errors.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum RequestKind {
    Draw,
    Choose,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum RuleError {
    #[error("invalid config: {0}")]
    Config(&'static str),
    #[error("a {got:?} answer at a {expected:?} request")]
    WrongEvent { expected: RequestKind, got: RequestKind },
}

/// Room for one answer's notes. One answer can run a whole distribution
/// (at most 68 passes of a few notes each) and a round start; 256 is above
/// that bound.
pub const NOTES_CAPACITY: usize = 256;

/// An answer's notes, oldest first.
#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct Notes {
    notes: ArrayVec<Note, NOTES_CAPACITY>,
    truncated: bool,
}

impl Notes {
    pub(crate) fn clear(&mut self) {
        self.notes.clear();
        self.truncated = false;
    }

    pub(crate) fn push(&mut self, note: Note) {
        if self.notes.try_push(note).is_err() {
            self.truncated = true;
        }
    }

    #[must_use]
    pub fn as_slice(&self) -> &[Note] {
        &self.notes
    }

    /// Whether notes past [`NOTES_CAPACITY`] were dropped. Never set by a reachable state.
    #[must_use]
    pub const fn truncated(&self) -> bool {
        self.truncated
    }
}

/// The state after an answer and the answer's notes (domain.bend `Stepped`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Stepped {
    pub state: State,
    pub notes: Notes,
}

/// Validates a raw answer against the state's request and steps (Bend's
/// `answer`). A Draw's number is clamped into its range and a Choose's index
/// to the last move, as Bend does; at a Finished or Stuck point the state
/// comes back unchanged with no notes, as Bend's `answer` does.
///
/// # Errors
///
/// [`RuleError::WrongEvent`] for a Draw answer at a Choose point or the reverse.
pub fn step_event(config: &Config, state: State, event: Event) -> Result<Stepped, RuleError> {
    // `answer.at`: at Idle the request's menu and the choice's menu are one list.
    if let Phase::Idle { seat } = state.phase {
        branch!(B::SimpleMainAnswerAtIdle);
        answer_idle(config, state, seat, event)
    } else {
        branch!(B::SimpleMainAnswerAtAny);
        answer_request(config, state, event)
    }
}

/// `answer.idle`: the n-th move of `seat`'s menu, clamped to the last.
fn answer_idle(config: &Config, state: State, seat: Seat, event: Event) -> Result<Stepped, RuleError> {
    let seated = config.table().has(seat);
    let options = point::options(&state, seat);
    if seated && !options.is_empty() {
        branch!(B::SimpleMainAnswerIdleTrueCons);
        match event {
            Event::Choose(n) => {
                let menu = Menu { seat, options };
                Ok(menu.clamped(n).map_or_else(
                    || Stepped {
                        state,
                        notes: Notes::default(),
                    },
                    |legal| machine::pick(config, state, seat, legal.option()),
                ))
            }
            Event::Draw(_) => Err(RuleError::WrongEvent {
                expected: RequestKind::Choose,
                got: RequestKind::Draw,
            }),
        }
    } else {
        branch!(B::SimpleMainAnswerIdleAny);
        Ok(Stepped {
            state,
            notes: Notes::default(),
        })
    }
}

/// `answer.request`.
fn answer_request(config: &Config, state: State, event: Event) -> Result<Stepped, RuleError> {
    let unchanged = Stepped {
        state,
        notes: Notes::default(),
    };
    match request(config, &state) {
        Request::Finished => {
            branch!(B::SimpleMainAnswerRequestFinished);
            Ok(unchanged)
        }
        Request::Stuck => {
            branch!(B::SimpleMainAnswerRequestStuck);
            Ok(unchanged)
        }
        Request::Draw { range, .. } => {
            branch!(B::SimpleMainAnswerRequestDraw);
            match event {
                Event::Draw(n) => Ok(step(config, state, Answer::Draw(range.value(n)))),
                Event::Choose(_) => Err(RuleError::WrongEvent {
                    expected: RequestKind::Draw,
                    got: RequestKind::Choose,
                }),
            }
        }
        Request::Choose(menu) => {
            branch!(B::SimpleMainAnswerRequestChooseNonEmpty);
            match event {
                Event::Choose(n) => Ok(menu
                    .clamped(n)
                    .map_or(unchanged, |legal| step(config, state, Answer::Choice(legal)))),
                Event::Draw(_) => Err(RuleError::WrongEvent {
                    expected: RequestKind::Choose,
                    got: RequestKind::Draw,
                }),
            }
        }
    }
}
