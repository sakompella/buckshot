//! The shared domain of `sim/bend-mp/domain.bend`, as small `Copy` values.
//!
//! Bend's lists of seats, items and shells become fixed-size values here: a
//! seat list holds at most four seats, an item list is a subsequence of
//! [`Item::ORDER`], and the gun is a bit string of at most [`Gun::CAPACITY`]
//! shells.

use num_enum::{IntoPrimitive, TryFromPrimitive};

use crate::branch::B;

/// A fixed socket identity (domain.bend `Seat`), numbered from 0.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, IntoPrimitive, TryFromPrimitive)]
#[repr(u8)]
pub enum Seat {
    Seat0,
    Seat1,
    Seat2,
    Seat3,
}

impl Seat {
    #[must_use]
    pub fn index(self) -> usize {
        usize::from(u8::from(self))
    }
}

/// How many players sit at the table (domain.bend `Table`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Table {
    TwoSeats,
    #[cfg(feature = "seats-2-4")]
    ThreeSeats,
    #[cfg(feature = "seats-2-4")]
    FourSeats,
}

impl Table {
    /// `table.seats`: the seated sockets in ascending order.
    #[must_use]
    pub fn seats(self) -> Seats {
        match self {
            Self::TwoSeats => {
                branch!(B::DomainTableSeatsTwoSeats);
                Seats {
                    seats: [Seat::Seat1, Seat::Seat3, Seat::Seat0, Seat::Seat0],
                    len: 2,
                }
            }
            #[cfg(feature = "seats-2-4")]
            Self::ThreeSeats => {
                branch!(B::DomainTableSeatsThreeSeats);
                Seats {
                    seats: [Seat::Seat0, Seat::Seat1, Seat::Seat2, Seat::Seat0],
                    len: 3,
                }
            }
            #[cfg(feature = "seats-2-4")]
            Self::FourSeats => {
                branch!(B::DomainTableSeatsFourSeats);
                Seats {
                    seats: [Seat::Seat0, Seat::Seat1, Seat::Seat2, Seat::Seat3],
                    len: 4,
                }
            }
        }
    }

    /// The table of `seats` seats, if this build has it.
    #[must_use]
    pub const fn of_seats(seats: u64) -> Option<Self> {
        match seats {
            2 => Some(Self::TwoSeats),
            #[cfg(feature = "seats-2-4")]
            3 => Some(Self::ThreeSeats),
            #[cfg(feature = "seats-2-4")]
            4 => Some(Self::FourSeats),
            _ => None,
        }
    }

    #[must_use]
    pub fn has(self, seat: Seat) -> bool {
        let sockets: u8 = match self {
            Self::TwoSeats => 0b1010,
            #[cfg(feature = "seats-2-4")]
            Self::ThreeSeats => 0b0111,
            #[cfg(feature = "seats-2-4")]
            Self::FourSeats => 0b1111,
        };
        sockets.wrapping_shr(u32::from(u8::from(seat))) & 1 != 0
    }
}

/// A list of at most four seats, in the order they were pushed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Seats {
    seats: [Seat; 4],
    len: u8,
}

impl Seats {
    pub const EMPTY: Self = Self {
        seats: [Seat::Seat0; 4],
        len: 0,
    };

    /// Appends `seat`. Every list is drawn from one table's seats.
    ///
    /// # Panics
    ///
    /// On a fifth seat, which no table has, rather than drop it.
    pub fn push(&mut self, seat: Seat) {
        let free = self.seats.get_mut(usize::from(self.len));
        assert!(free.is_some(), "a seat list outgrew one table's seats");
        if let Some(free) = free {
            *free = seat;
            self.len = self.len.saturating_add(1);
        }
    }

    /// Appends `seat` unless it is already in the list.
    pub fn insert(&mut self, seat: Seat) {
        if !self.contains(seat) {
            self.push(seat);
        }
    }

    /// `List.append` of two lists of seats.
    #[must_use]
    pub fn joined(first: &[Seat], second: &[Seat]) -> Self {
        first.iter().chain(second).fold(Self::EMPTY, |mut all, seat| {
            all.push(*seat);
            all
        })
    }

    /// `List.reverse`.
    #[must_use]
    pub fn reversed(self) -> Self {
        self.iter().rev().fold(Self::EMPTY, |mut all, seat| {
            all.push(seat);
            all
        })
    }

    #[must_use]
    pub fn as_slice(&self) -> &[Seat] {
        self.seats.get(..usize::from(self.len)).unwrap_or_default()
    }

    #[must_use]
    pub fn iter(&self) -> impl DoubleEndedIterator<Item = Seat> + Clone + '_ {
        self.as_slice().iter().copied()
    }

    #[must_use]
    pub fn len(&self) -> usize {
        usize::from(self.len)
    }

    #[must_use]
    pub const fn is_empty(&self) -> bool {
        self.len == 0
    }

    #[must_use]
    pub fn first(&self) -> Option<Seat> {
        self.iter().next()
    }

    #[must_use]
    pub fn contains(&self, seat: Seat) -> bool {
        self.iter().any(|s| s == seat)
    }
}

/// One value per seated socket (domain.bend `Ring`: `Duo`, `Trio`, `Quad`).
/// The table is part of the value, so a ring never holds an unseated socket.
/// The `seats-2` build stores only the two-seat table's sockets.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Ring<T> {
    table: Table,
    cells: [T; RING_CELLS],
}

#[cfg(feature = "seats-2-4")]
const RING_CELLS: usize = 4;
#[cfg(not(feature = "seats-2-4"))]
const RING_CELLS: usize = 2;

/// A seat's cell in a ring: its socket, or in the `seats-2` build its
/// socket's half (the two-seat table sits at sockets 1 and 3).
#[cfg(feature = "seats-2-4")]
fn ring_cell(seat: Seat) -> usize {
    seat.index()
}

#[cfg(not(feature = "seats-2-4"))]
fn ring_cell(seat: Seat) -> usize {
    seat.index().wrapping_shr(1)
}

impl<T: Copy> Ring<T> {
    /// `ring.fill`.
    #[must_use]
    pub const fn fill(table: Table, value: T) -> Self {
        Self {
            table,
            cells: [value; RING_CELLS],
        }
    }

    #[must_use]
    pub const fn table(&self) -> Table {
        self.table
    }

    /// `ring.get`: `None` exactly when the seat is not at this table.
    #[must_use]
    pub fn get(&self, seat: Seat) -> Option<T> {
        if !self.table.has(seat) {
            return None;
        }
        self.cells.get(ring_cell(seat)).copied()
    }

    /// `ring.set`: a seat not at this table leaves the ring unchanged.
    #[must_use]
    pub fn set(mut self, seat: Seat, value: T) -> Self {
        if !self.table.has(seat) {
            return self;
        }
        if let Some(cell) = self.cells.get_mut(ring_cell(seat)) {
            *cell = value;
        }
        self
    }

    /// `ring.entries`: every seat with its value, in ascending socket order.
    pub fn entries(&self) -> impl DoubleEndedIterator<Item = (Seat, T)> + '_ {
        let seats = self.table.seats();
        seats
            .seats
            .into_iter()
            .take(seats.len())
            .filter_map(move |seat| Some((seat, self.get(seat)?)))
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Shell {
    Live,
    Blank,
}

/// A shell composition, live count first (domain.bend `Load`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Load {
    pub live: u32,
    pub blank: u32,
}

/// A list of shells, head first, as bits (1 is live). [`Config::new`]
/// rejects any fixed load longer than [`Gun::CAPACITY`], and every deck load
/// is shorter, so no reachable list is cut.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Default)]
pub struct Gun {
    bits: u64,
    len: u32,
}

const fn bit(i: u32) -> u64 {
    match 1u64.checked_shl(i) {
        Some(b) => b,
        None => 0,
    }
}

impl Gun {
    pub const CAPACITY: u32 = 64;
    pub const EMPTY: Self = Self { bits: 0, len: 0 };

    /// `load.shells`: the live shells, then the blank ones.
    ///
    /// # Panics
    ///
    /// On a load past [`Gun::CAPACITY`] shells, which [`Config::new`] rejects,
    /// rather than cut it.
    #[must_use]
    pub fn of_load(load: Load) -> Self {
        let total = load.live.saturating_add(load.blank);
        assert!(total <= Self::CAPACITY, "a load outgrew the gun");
        let bits = (0..load.live).fold(0, |bits, i| bits | bit(i));
        Self { bits, len: total }
    }

    /// Builds a list from shells, head first, or `None` past [`Gun::CAPACITY`] shells.
    pub fn from_shells(shells: impl IntoIterator<Item = Shell>) -> Option<Self> {
        let mut gun = Self::EMPTY;
        for shell in shells {
            if gun.len >= Self::CAPACITY {
                return None;
            }
            if shell == Shell::Live {
                gun.bits |= bit(gun.len);
            }
            gun.len = gun.len.saturating_add(1);
        }
        Some(gun)
    }

    #[must_use]
    pub const fn len(self) -> u32 {
        self.len
    }

    #[must_use]
    pub const fn is_empty(self) -> bool {
        self.len == 0
    }

    /// `nth`.
    #[must_use]
    pub const fn nth(self, i: u32) -> Option<Shell> {
        if i >= self.len {
            return None;
        }
        Some(if self.bits & bit(i) == 0 { Shell::Blank } else { Shell::Live })
    }

    /// The head and the rest, or `None` for the empty list.
    #[must_use]
    pub const fn split_first(self) -> Option<(Shell, Self)> {
        match self.nth(0) {
            None => None,
            Some(shell) => Some((
                shell,
                Self {
                    bits: self.bits >> 1,
                    len: self.len.saturating_sub(1),
                },
            )),
        }
    }

    /// `shell <> self`.
    ///
    /// # Panics
    ///
    /// On a full list (unreachable: see the type) rather than drop its last shell.
    #[must_use]
    pub const fn push_front(self, shell: Shell) -> Self {
        assert!(self.len < Self::CAPACITY, "a shell list outgrew the gun");
        let len = self.len.saturating_add(1);
        let live = match shell {
            Shell::Live => 1,
            Shell::Blank => 0,
        };
        Self {
            bits: (self.bits << 1) | live,
            len,
        }
    }

    /// `G.swap`: swaps positions `i` and `j` when both exist, else unchanged.
    #[must_use]
    pub fn swap(self, i: u32, j: u32) -> Self {
        if let (Some(a), Some(b)) = (self.nth(i), self.nth(j)) {
            branch!(B::SmRulesSwapFoundSomeSome);
            self.set(i, b).set(j, a)
        } else {
            branch!(B::SmRulesSwapFoundAny);
            self
        }
    }

    const fn set(self, i: u32, shell: Shell) -> Self {
        let bits = match shell {
            Shell::Live => self.bits | bit(i),
            Shell::Blank => self.bits & !bit(i),
        };
        Self { bits, len: self.len }
    }

    pub fn iter(self) -> impl Iterator<Item = Shell> {
        (0..self.len()).filter_map(move |i| self.nth(i))
    }
}

/// domain.bend `Item`, numbered in `item.order()`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, IntoPrimitive, TryFromPrimitive)]
#[repr(u8)]
pub enum Item {
    Saw,
    Glass,
    Jammer,
    Cigarettes,
    Beer,
    Phone,
    Inverter,
    Adrenaline,
    Remote,
}

impl Item {
    /// `item.order()`: Godot's resource order. Item-choice draws index it.
    pub const ORDER: [Self; 9] = [
        Self::Saw,
        Self::Glass,
        Self::Jammer,
        Self::Cigarettes,
        Self::Beer,
        Self::Phone,
        Self::Inverter,
        Self::Adrenaline,
        Self::Remote,
    ];

    /// The position in [`Item::ORDER`].
    #[must_use]
    pub fn rank(self) -> u32 {
        u32::from(u8::from(self))
    }

    /// `item.dealt_at`: at exactly two seats the remote is never dealt.
    #[must_use]
    pub fn dealt_at(self, table: Table) -> bool {
        match (table, self) {
            (Table::TwoSeats, Self::Remote) => {
                branch!(B::DomainItemDealtAtTwoSeatsRemote);
                false
            }
            #[cfg(feature = "seats-2-4")]
            (Table::TwoSeats | Table::ThreeSeats | Table::FourSeats, _) => {
                branch!(B::DomainItemDealtAtAny);
                true
            }
            #[cfg(not(feature = "seats-2-4"))]
            (Table::TwoSeats, _) => {
                branch!(B::DomainItemDealtAtAny);
                true
            }
        }
    }
}

/// A subsequence of [`Item::ORDER`], as a bit set: the shape of every pool.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Default)]
pub struct Items(u16);

impl Items {
    pub const EMPTY: Self = Self(0);

    #[must_use]
    pub fn with(self, item: Item) -> Self {
        Self(self.0 | (1 << item.rank()))
    }

    #[must_use]
    pub fn contains(self, item: Item) -> bool {
        self.0 & (1 << item.rank()) != 0
    }

    #[must_use]
    pub const fn len(self) -> u32 {
        self.0.count_ones()
    }

    #[must_use]
    pub const fn is_empty(self) -> bool {
        self.0 == 0
    }

    pub fn iter(self) -> impl Iterator<Item = Item> {
        Item::ORDER.into_iter().filter(move |item| self.contains(*item))
    }

    /// `nth` over the list in order.
    #[must_use]
    pub fn nth(self, n: u32) -> Option<Item> {
        self.iter().nth(usize::try_from(n).ok()?)
    }

    /// The first item and the rest.
    #[must_use]
    pub fn split_first(self) -> Option<(Item, Self)> {
        let first = self.iter().next()?;
        Some((first, Self(self.0 & !(1 << first.rank()))))
    }
}

/// One of a seat's eight inventory slots (domain.bend `Slot`), numbered from 0.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, IntoPrimitive, TryFromPrimitive)]
#[repr(u8)]
pub enum Slot {
    Slot0,
    Slot1,
    Slot2,
    Slot3,
    Slot4,
    Slot5,
    Slot6,
    Slot7,
}

impl Slot {
    /// `slot.order()`.
    pub const ORDER: [Self; 8] = [
        Self::Slot0,
        Self::Slot1,
        Self::Slot2,
        Self::Slot3,
        Self::Slot4,
        Self::Slot5,
        Self::Slot6,
        Self::Slot7,
    ];

    #[must_use]
    pub fn index(self) -> usize {
        usize::from(u8::from(self))
    }
}

/// A seat's inventory (domain.bend `Slots`): four bits per slot, slot 0
/// lowest, each 0 for an empty slot or 1 plus the item's rank.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct Slots(u32);

/// A slot's content by its four bits.
const SLOT_CONTENT: [Option<Item>; 16] = [
    None,
    Some(Item::Saw),
    Some(Item::Glass),
    Some(Item::Jammer),
    Some(Item::Cigarettes),
    Some(Item::Beer),
    Some(Item::Phone),
    Some(Item::Inverter),
    Some(Item::Adrenaline),
    Some(Item::Remote),
    None,
    None,
    None,
    None,
    None,
    None,
];

impl Slots {
    pub const EMPTY: Self = Self(0);

    fn shift(slot: Slot) -> u32 {
        u32::from(u8::from(slot)).wrapping_mul(4)
    }

    /// `slots.get`.
    #[must_use]
    pub fn get(&self, slot: Slot) -> Option<Item> {
        let bits = self.0.wrapping_shr(Self::shift(slot)) & 0xF;
        SLOT_CONTENT.get(usize::try_from(bits).unwrap_or(0)).copied().flatten()
    }

    /// `slots.put`.
    #[must_use]
    pub fn put(self, slot: Slot, value: Option<Item>) -> Self {
        let bits = value.map_or(0, |item| item.rank().wrapping_add(1));
        let shift = Self::shift(slot);
        Self((self.0 & !0xFu32.wrapping_shl(shift)) | bits.wrapping_shl(shift))
    }

    /// The items of the occupied slots, in slot order.
    pub fn items(self) -> impl Iterator<Item = Item> {
        let mut rest = self.0;
        core::iter::from_fn(move || {
            let at = rest.trailing_zeros() & !3;
            let bits = rest.checked_shr(at)? & 0xF;
            rest &= !0xFu32.wrapping_shl(at);
            SLOT_CONTENT.get(usize::try_from(bits).unwrap_or(0)).copied().flatten()
        })
    }

    /// Every slot with its content, in slot order.
    pub fn entries(&self) -> impl Iterator<Item = (Slot, Option<Item>)> + '_ {
        Slot::ORDER.into_iter().map(|slot| (slot, self.get(slot)))
    }
}

impl core::fmt::Debug for Slots {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_list().entries(self.entries().map(|(_, item)| item)).finish()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Direction {
    Clockwise,
    CounterClockwise,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Damage {
    Single,
    Double,
}

impl Damage {
    #[must_use]
    pub fn amount(self) -> u32 {
        match self {
            Self::Single => {
                branch!(B::DomainDamageAmountSingle);
                1
            }
            Self::Double => {
                branch!(B::DomainDamageAmountDouble);
                2
            }
        }
    }
}

// Match configuration
// ===================

/// A starting health rule. `Fixed` holds the health itself (Bend's `Pos`, so at least 1).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum HealthRule {
    Random,
    Fixed(u32),
}

/// A load's shells. `blank` of `Fixed` and `live` of `AllLive` are Bend `Pos` values (at least 1).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShellRule {
    Random,
    Fixed { live: u32, blank: u32 },
    AllLive { live: u32 },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AmountRule {
    Random,
    Fixed(u32),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct LoadRule {
    pub shells: ShellRule,
    pub items: AmountRule,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct ItemRule {
    pub enabled: bool,
    pub per_player: u32,
    pub on_table: u32,
}

/// One round's rules. `items` is indexed by [`Item::rank`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct RoundRules {
    pub health: HealthRule,
    pub loads: [LoadRule; 4],
    pub items: [ItemRule; 9],
}

impl RoundRules {
    /// `rules.item`.
    #[must_use]
    pub fn item(&self, item: Item) -> ItemRule {
        self.items
            .get(usize::try_from(item.rank()).unwrap_or(0))
            .copied()
            .unwrap_or(ItemRule {
                enabled: false,
                per_player: 0,
                on_table: 0,
            })
    }

    /// `config.default_round()`: `MP_MatchCustomization`'s defaults.
    #[must_use]
    pub const fn default_round() -> Self {
        const fn rule(per_player: u32, on_table: u32) -> ItemRule {
            ItemRule {
                enabled: true,
                per_player,
                on_table,
            }
        }
        let load = LoadRule {
            shells: ShellRule::Random,
            items: AmountRule::Random,
        };
        Self {
            health: HealthRule::Random,
            loads: [load; 4],
            items: [
                rule(2, 32),
                rule(2, 32),
                rule(1, 1),
                rule(1, 32),
                rule(8, 32),
                rule(8, 32),
                rule(4, 32),
                rule(4, 32),
                rule(1, 2),
            ],
        }
    }
}

/// The match configuration (domain.bend `Config`): the table and one to three rounds.
/// It never changes during a match, so it lives outside [`crate::State`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Config {
    table: Table,
    rounds: [RoundRules; 3],
    len: u8,
}

impl Config {
    /// A configuration for `rounds` (one to three), each fixed load at most [`Gun::CAPACITY`] shells.
    ///
    /// # Errors
    ///
    /// [`crate::RuleError::Config`] when the plan length, a `Pos` field or a load size is out of bounds.
    pub fn new(table: Table, rounds: &[RoundRules]) -> Result<Self, crate::RuleError> {
        let invalid = |reason| Err(crate::RuleError::Config(reason));
        let (len, first) = match rounds {
            [first] | [first, _] | [first, _, _] => (rounds.len(), *first),
            [] | [_, _, _, _, ..] => return invalid("a plan has one to three rounds"),
        };
        for round in rounds {
            if matches!(round.health, HealthRule::Fixed(0)) {
                return invalid("a fixed health is positive");
            }
            for load in round.loads {
                let ok = match load.shells {
                    ShellRule::Random => true,
                    ShellRule::Fixed { live, blank } => blank >= 1 && live.saturating_add(blank) <= Gun::CAPACITY,
                    ShellRule::AllLive { live } => (1..=Gun::CAPACITY).contains(&live),
                };
                if !ok {
                    return invalid("a fixed load has 1 to 64 shells");
                }
            }
        }
        let mut all = [first; 3];
        for (cell, round) in all.iter_mut().zip(rounds) {
            *cell = *round;
        }
        Ok(Self {
            table,
            rounds: all,
            len: u8::try_from(len).unwrap_or(3),
        })
    }

    #[must_use]
    pub const fn table(&self) -> Table {
        self.table
    }

    /// `plan.length`.
    #[must_use]
    pub fn plan_length(&self) -> u32 {
        u32::from(self.len)
    }

    /// `plan.round`.
    #[must_use]
    pub fn round(&self, index: u32) -> Option<&RoundRules> {
        if index >= self.plan_length() {
            return None;
        }
        self.rounds.get(usize::try_from(index).ok()?)
    }

    /// The rounds of the plan.
    #[must_use]
    pub fn rounds(&self) -> &[RoundRules] {
        self.rounds.get(..usize::from(self.len)).unwrap_or(&[])
    }
}

// Requests
// ========

/// The semantic draw sites (domain.bend `Label`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Label {
    FirstSeat,
    StartingHealth,
    ItemAmount,
    ItemChoice,
    SequenceBatch,
    ShuffleSwap,
    PhoneIndex,
}

/// The inclusive draw range `lo..=lo + extra + 1` (domain.bend `Range`).
/// Its fields are public: any range can be made, so a [`DrawValue`] is in its
/// range but is not tied to a state's request.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Range {
    pub lo: u32,
    pub extra: u32,
}

/// A drawn value inside a [`Range`]. Only [`Range::value`] makes one. It
/// keeps no record of the request it was drawn for.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct DrawValue(u32);

impl DrawValue {
    #[must_use]
    pub const fn get(self) -> u32 {
        self.0
    }
}

impl Range {
    /// `draw.value`: `lo + min(n, extra + 1)`, so every answer names an in-range value.
    #[must_use]
    pub const fn value(self, n: u32) -> DrawValue {
        let top = self.extra.saturating_add(1);
        DrawValue(self.lo.saturating_add(if n < top { n } else { top }))
    }

    /// Every value of the range, lowest first.
    pub fn values(self) -> impl Iterator<Item = DrawValue> {
        (0..=self.extra.saturating_add(1)).map(move |n| self.value(n))
    }
}

/// The ranges of domain.bend's per-table constants.
impl Table {
    /// `table.health_range`.
    #[must_use]
    pub fn health_range(self) -> Range {
        match self {
            Self::TwoSeats => {
                branch!(B::DomainTableHealthRangeTwoSeats);
                Range { lo: 3, extra: 0 }
            }
            #[cfg(feature = "seats-2-4")]
            Self::ThreeSeats => {
                branch!(B::DomainTableHealthRangeThreeSeats);
                Range { lo: 4, extra: 0 }
            }
            #[cfg(feature = "seats-2-4")]
            Self::FourSeats => {
                branch!(B::DomainTableHealthRangeFourSeats);
                Range { lo: 3, extra: 1 }
            }
        }
    }

    /// `table.amount_range`.
    #[must_use]
    pub fn amount_range(self) -> Range {
        match self {
            Self::TwoSeats => {
                branch!(B::DomainTableAmountRangeTwoSeats);
                Range { lo: 2, extra: 1 }
            }
            #[cfg(feature = "seats-2-4")]
            Self::ThreeSeats => {
                branch!(B::DomainTableAmountRangeThreeSeats);
                Range { lo: 3, extra: 1 }
            }
            #[cfg(feature = "seats-2-4")]
            Self::FourSeats => {
                branch!(B::DomainTableAmountRangeFourSeats);
                Range { lo: 3, extra: 0 }
            }
        }
    }

    /// `table.deck`: the ordered sequence batches.
    #[must_use]
    pub fn deck(self) -> &'static [Load] {
        const fn l(live: u32, blank: u32) -> Load {
            Load { live, blank }
        }
        const TWO: [Load; 9] = [l(1, 2), l(2, 1), l(2, 2), l(3, 2), l(1, 1), l(2, 3), l(3, 3), l(3, 1), l(4, 2)];
        #[cfg(feature = "seats-2-4")]
        const THREE: [Load; 10] = [
            l(2, 3),
            l(3, 2),
            l(3, 3),
            l(4, 3),
            l(2, 2),
            l(3, 4),
            l(4, 4),
            l(4, 2),
            l(3, 1),
            l(1, 1),
        ];
        #[cfg(feature = "seats-2-4")]
        const FOUR: [Load; 10] = [
            l(3, 4),
            l(3, 2),
            l(3, 3),
            l(4, 3),
            l(2, 2),
            l(3, 4),
            l(4, 4),
            l(4, 2),
            l(3, 1),
            l(2, 1),
        ];
        match self {
            Self::TwoSeats => {
                branch!(B::DomainTableDeckTwoSeats);
                &TWO
            }
            #[cfg(feature = "seats-2-4")]
            Self::ThreeSeats => {
                branch!(B::DomainTableDeckThreeSeats);
                &THREE
            }
            #[cfg(feature = "seats-2-4")]
            Self::FourSeats => {
                branch!(B::DomainTableDeckFourSeats);
                &FOUR
            }
        }
    }
}

/// `prize`: by round index, not plan length.
#[must_use]
pub fn prize(round: u32) -> u32 {
    match round {
        0 => {
            branch!(B::DomainPrizeZero);
            70000
        }
        1 => {
            branch!(B::DomainPrizeOne);
            75000
        }
        2 => {
            branch!(B::DomainPrizeTwo);
            80000
        }
        3.. => {
            branch!(B::DomainPrizeAny);
            0
        }
    }
}

/// `phone.cap()`: the phone announces at most the seventh shell.
pub const PHONE_CAP: u32 = 7;

// Events
// ======

/// Public events (domain.bend `GameEvent`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum GameEvent {
    RoundBegan {
        round: u32,
        health: u32,
        first: Seat,
    },
    GrabbingBegan {
        seats: Seats,
    },
    Granted {
        seat: Seat,
        item: Item,
    },
    Placed {
        seat: Seat,
        slot: Slot,
        item: Item,
    },
    GrabbingEnded {
        seat: Seat,
    },
    DistributionDone,
    Loaded {
        load: Load,
    },
    TurnSkipped {
        seat: Seat,
    },
    JamLifted {
        seat: Seat,
    },
    TurnGiven {
        seat: Seat,
    },
    PickedUp {
        seat: Seat,
    },
    Fired {
        shooter: Seat,
        target: Seat,
        shell: Shell,
        captured: Damage,
        applied: u32,
        health: u32,
    },
    Died {
        seat: Seat,
    },
    Used {
        seat: Seat,
        owner: Seat,
        slot: Slot,
        item: Item,
    },
    Healed {
        seat: Seat,
        health: u32,
    },
    Ejected {
        seat: Seat,
        shell: Shell,
    },
    Inverted {
        seat: Seat,
    },
    JamApplied {
        by: Seat,
        target: Seat,
    },
    DirectionFlipped {
        direction: Direction,
    },
    RoundWon {
        seat: Seat,
        prize: u32,
    },
    MatchConcluded,
}

/// Results shown only to one seat (domain.bend `Secret`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Secret {
    Glimpse { shell: Shell },
    Clue { position: u32, shell: Shell },
    NoClue,
    EmptyBriefcase,
}

/// One note of an answer (domain.bend `Note`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Note {
    Shown(GameEvent),
    Told { seat: Seat, secret: Secret },
}
