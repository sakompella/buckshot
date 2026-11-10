//! The simple machine's state (`simple/state.bend`, with sm's `World`,
//! `Players` and `Grabs` records from `sm/state.bend`). The match config is
//! not here: it is passed beside the state by reference.

use crate::branch::B;
use crate::domain::{Direction, Gun, Item, Items, Load, Ring, Seat, Slot, Slots, Table};

/// A seat's jammer state (sm/state.bend `Jam`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Jam {
    Free,
    Jammed,
    JammedSkipped,
}

impl Jam {
    /// `jam.jammed`.
    #[must_use]
    pub fn jammed(self) -> bool {
        match self {
            Self::Free => {
                branch!(B::SmStateJamJammedFree);
                false
            }
            Self::Jammed | Self::JammedSkipped => {
                branch!(B::SmStateJamJammedAny);
                true
            }
        }
    }
}

/// One seat's record (sm/state.bend `Seat`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct SeatRecord {
    pub health: u32,
    pub jam: Jam,
    pub cash: u32,
    pub slots: Slots,
}

impl SeatRecord {
    /// The seat that [`players_seat`] reads for a seat missing from the ring.
    pub const FRESH: Self = Self {
        health: 100,
        jam: Jam::Free,
        cash: 0,
        slots: Slots::EMPTY,
    };
}

/// One record per seated socket (sm/state.bend `Players`).
pub type Players = Ring<SeatRecord>;

/// `players.seat` with `seat.found`: a seat missing from the ring reads as a fresh seat.
#[must_use]
pub fn players_seat(players: &Players, seat: Seat) -> SeatRecord {
    if let Some(record) = players.get(seat) {
        branch!(B::SmStateSeatFoundSome);
        record
    } else {
        branch!(B::SmStateSeatFoundNone);
        SeatRecord::FRESH
    }
}

/// Item distribution flags (sm/state.bend `Grabs`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Grabs {
    pub distributing: bool,
    pub grabbing: Ring<bool>,
    pub holding: Ring<Option<Item>>,
    pub granted: Ring<u32>,
    pub intake: Ring<bool>,
}

/// A sequence batch: its index in the full deck and its load (sm/state.bend `Batch`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Batch {
    pub id: u32,
    pub load: Load,
}

/// One table's remaining deck. Batches only ever leave a full deck, so the
/// deck is the set of batch ids still in it, listed in id order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Deck {
    table: Table,
    ids: u16,
}

/// Batch `id`'s bit: every table's deck holds fewer than 16 batches.
const fn bit(id: u32) -> u16 {
    match 1u16.checked_shl(id) {
        Some(b) => b,
        None => 0,
    }
}

impl Deck {
    /// `batches(table.deck(table), 0)`.
    #[must_use]
    pub fn full(table: Table) -> Self {
        let mut ids = 0u16;
        for (id, _) in (0u32..).zip(table.deck()) {
            branch!(B::SmRulesBatchesCons);
            ids |= bit(id);
        }
        branch!(B::SmRulesBatchesNil);
        Self { table, ids }
    }

    /// A deck of the given batch ids, or `None` if one is past the table's deck.
    #[must_use]
    pub fn of_ids(table: Table, ids: impl IntoIterator<Item = u32>) -> Option<Self> {
        let full = Self::full(table).ids;
        let ids = ids.into_iter().try_fold(0u16, |acc, id| Some(acc | u16::checked_shl(1, id)?))?;
        (ids & !full == 0).then_some(Self { table, ids })
    }

    /// The batches of this deck whose ids pass `keep`.
    #[must_use]
    pub fn filtered(self, keep: impl Fn(u32) -> bool) -> Self {
        let ids = (0u32..16).filter(|id| keep(*id)).fold(0u16, |acc, id| acc | bit(id));
        Self {
            ids: self.ids & ids,
            ..self
        }
    }

    /// The deck without batch `id`.
    #[must_use]
    pub const fn without(self, id: u32) -> Self {
        Self {
            ids: self.ids & !bit(id),
            ..self
        }
    }

    #[must_use]
    pub const fn len(self) -> u32 {
        self.ids.count_ones()
    }

    #[must_use]
    pub const fn is_empty(self) -> bool {
        self.ids == 0
    }

    pub fn iter(self) -> impl Iterator<Item = Batch> {
        (0u32..)
            .zip(self.table.deck())
            .filter(move |(id, _)| self.ids & bit(*id) != 0)
            .map(|(id, &load)| Batch { id, load })
    }

    /// `nth`.
    #[must_use]
    pub fn nth(self, index: u32) -> Option<Batch> {
        self.iter().nth(usize::try_from(index).ok()?)
    }

    /// `remove`: the deck without its `index`-th batch (unchanged past the end).
    #[must_use]
    pub fn remove(self, index: u32) -> Self {
        match self.nth(index) {
            Some(batch) => Self {
                table: self.table,
                ids: self.ids & !bit(batch.id),
            },
            None => self,
        }
    }
}

/// One deck per table size (sm/state.bend `Decks`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Decks {
    pub two: Deck,
    #[cfg(feature = "seats-2-4")]
    pub three: Deck,
    #[cfg(feature = "seats-2-4")]
    pub four: Deck,
}

impl Decks {
    /// `decks.full()`.
    #[must_use]
    pub fn full() -> Self {
        Self {
            two: Deck::full(Table::TwoSeats),
            #[cfg(feature = "seats-2-4")]
            three: Deck::full(Table::ThreeSeats),
            #[cfg(feature = "seats-2-4")]
            four: Deck::full(Table::FourSeats),
        }
    }

    /// `decks.get`.
    #[must_use]
    pub const fn get(self, table: Table) -> Deck {
        match table {
            Table::TwoSeats => self.two,
            #[cfg(feature = "seats-2-4")]
            Table::ThreeSeats => self.three,
            #[cfg(feature = "seats-2-4")]
            Table::FourSeats => self.four,
        }
    }

    /// `decks.set`.
    #[must_use]
    pub const fn set(mut self, table: Table, deck: Deck) -> Self {
        match table {
            Table::TwoSeats => self.two = deck,
            #[cfg(feature = "seats-2-4")]
            Table::ThreeSeats => self.three = deck,
            #[cfg(feature = "seats-2-4")]
            Table::FourSeats => self.four = deck,
        }
        self
    }
}

/// sm/state.bend `checking_first_death`: whether the next death is recorded as
/// the round's first.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FirstDeathCheck {
    Off,
    On,
}

/// sm/state.bend `World`, without its config.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct World {
    pub before_round: bool,
    pub round_index: u32,
    pub load_index: u32,
    pub first_sequence: bool,
    pub round_health: u32,
    pub first_turn: Seat,
    pub turn: Option<Seat>,
    pub direction: Direction,
    pub first_death: Option<Seat>,
    pub checking_first_death: FirstDeathCheck,
    pub item_amount: u32,
    pub sawed: bool,
    pub gun: Gun,
    pub shown: Load,
    pub decks: Decks,
}

/// simple/state.bend `Phase`. `Blocked` and `Stalled` are game states (the
/// machine is stuck), not errors.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Phase {
    NeedFirst,
    NeedHealth,
    NeedAmount,
    NeedBatch,
    NeedSwap {
        load: Load,
        shells: Gun,
        i: u32,
    },
    Idle {
        seat: Seat,
    },
    Ended,
    Blocked {
        holder: Option<Seat>,
    },
    Stalled,
    NeedTurnAmount {
        from: Seat,
        passing: bool,
        winner: Option<Seat>,
    },
    /// The pool is `first <> second <> rest`, a subsequence of `Item::ORDER`.
    NeedItem {
        seat: Seat,
        first: Item,
        second: Item,
        rest: Items,
    },
    NeedPhone {
        seat: Seat,
        owner: Seat,
        slot: Slot,
    },
}

/// simple/state.bend `State` without its log: an answer's notes come back
/// in [`crate::Stepped`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct State {
    pub world: World,
    pub players: Players,
    pub grabs: Grabs,
    pub phase: Phase,
}
