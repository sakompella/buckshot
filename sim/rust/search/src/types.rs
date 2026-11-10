//! The player's types (`player/types.bend`).

use buckshot_rules::{Move, Seat, State};

use crate::num::Real;

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

/// The decision nodes and reload leaves the memo holds, and how often each was reused.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Cached {
    pub entries: u64,
    pub hits: u64,
    pub deals: u64,
    pub deal_hits: u64,
}

/// One root move's score (its private value, or the low end of its box),
/// the high end of its box and its reach. Compat's lines are exact: `upper`
/// is the score.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Line {
    pub index: u32,
    pub r#move: Move,
    pub score: u32,
    pub upper: u32,
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

/// Why a position has no analysis: Bend's `Analysis.Invalid` reasons, with
/// the nodes spent where a search ran.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum Refusal {
    #[error("the sampled leaf needs at least one deal")]
    NoDeals,
    #[error("a leaf that deals the reload takes two seats only")]
    SampledNeedsTwoSeats,
    #[error("requires an Idle board and a shown load of at most ten shells")]
    Board,
    #[error("public log has no consistent shell/deck belief")]
    NoPublicBelief,
    #[error("private log has no consistent shell/deck belief")]
    NoPrivateBelief,
    #[error("the position is not a choice")]
    NotAChoice,
    #[error("it is not this player's turn")]
    NotMyTurn,
    #[error("the budget's fuel outgrows 64 bits")]
    Fuel,
    #[error("no legal move")]
    NoLegalMove { nodes: u64 },
    #[error("an answer's notes outgrew their buffer")]
    NotesOverflow { nodes: u64 },
}

impl Refusal {
    /// The nodes spent before the refusal.
    #[must_use]
    pub const fn nodes(self) -> u64 {
        match self {
            Self::NoLegalMove { nodes } | Self::NotesOverflow { nodes } => nodes,
            Self::NoDeals
            | Self::SampledNeedsTwoSeats
            | Self::Board
            | Self::NoPublicBelief
            | Self::NoPrivateBelief
            | Self::NotAChoice
            | Self::NotMyTurn
            | Self::Fuel => 0,
        }
    }
}

/// `Analysis`: the analysis, or why there is none.
pub type Analysis = Result<Analysed, Refusal>;

/// Whether bounded-v1 skips children that cannot change its result.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Pruning {
    On,
    Off,
}

/// One possible world and its probability. `won` is the first round winner
/// in the notes of the answer that reached it: Bend keeps those notes in the
/// state, and a won round can already have begun the next one.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct World {
    pub state: State,
    pub weight: Real,
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
