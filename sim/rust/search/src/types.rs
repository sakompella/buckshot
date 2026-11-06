//! The player's types (`player/types.bend`).

use buckshot_rules::{Move, Seat, State};

use crate::num::F32;

/// How a leaf at a reload is valued: by the static evaluation before the
/// draw, or by that evaluation's mean over `count` deals drawn at random.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Reload {
    Static,
    Sampled { count: u32 },
}

/// How the search reuses a node it has already finished (memo.bend).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Memo {
    Off,
    Charged,
    Free,
}

/// What the leaves below a value were: all the end of the round, the end of
/// the round or a reload, or some ran out of depth.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Reach {
    Settled,
    Reloads,
    Cut,
}

impl Reach {
    /// `reach.join`.
    #[must_use]
    pub const fn join(self, other: Self) -> Self {
        match (self, other) {
            (Self::Cut, _) | (_, Self::Cut) => Self::Cut,
            (Self::Reloads, _) | (_, Self::Reloads) => Self::Reloads,
            (Self::Settled, Self::Settled) => Self::Settled,
        }
    }

    /// The name the JS player gives it.
    #[must_use]
    pub const fn name(self) -> &'static str {
        match self {
            Self::Settled => "settled",
            Self::Reloads => "reloads",
            Self::Cut => "cut",
        }
    }
}

/// The search bounds: decisions deep and nodes spent.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Limits {
    pub depth: u32,
    pub budget: u64,
}

/// The difficulty knob (`Level`): search bounds, a gap and a seed for the pick.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Level {
    pub limits: Limits,
    pub gap: u32,
    pub seed: u32,
}

/// The decision nodes and reload leaves the memo holds, and how often each was reused.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Cached {
    pub entries: u64,
    pub hits: u64,
    pub deals: u64,
    pub deal_hits: u64,
}

/// One root move's score (its private value) and reach.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Line {
    pub index: u32,
    pub r#move: Move,
    pub score: u32,
    pub reach: Reach,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Analysed {
    pub lines: Vec<Line>,
    pub best: u32,
    pub score: u32,
    pub nodes: u64,
    pub depth: u32,
    pub limited: bool,
    pub cached: Cached,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Analysis {
    Analysed(Analysed),
    Invalid { reason: &'static str, nodes: u64 },
}

/// One possible world and its probability. `won` is the first round winner
/// in the notes of the answer that reached it: Bend keeps those notes in the
/// state, and a won round can already have begun the next one.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct World {
    pub state: State,
    pub weight: F32,
    pub won: Option<Seat>,
}

/// The public belief, the searcher's private belief, the searcher and the round.
#[derive(Clone, Debug, PartialEq)]
pub struct Belief {
    pub public: Vec<World>,
    pub private: Vec<World>,
    pub me: Seat,
    pub round: u32,
}
