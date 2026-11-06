//! `sm/items.bend`: item pools, distribution needs, and the use, jam and
//! steal options. Every function that reads sm's records (`S.State`) takes
//! the config and the simple state, since the config is not in the state.

use arrayvec::ArrayVec;

use crate::domain::{AmountRule, Config, Direction, Item, Items, Seat, Seats, Shell, Slot, Slots};
use crate::state::{Grabs, Players, State};

/// sm/state.bend `IdleOption::UseAt` (`uses` only makes these).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct UseAt {
    pub slot: Slot,
    pub item: Item,
}

pub(crate) type Uses = ArrayVec<UseAt, 8>;

/// sm/state.bend `StealOption::Pick`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Pick {
    pub owner: Seat,
    pub slot: Slot,
    pub item: Item,
}

/// At most three owners with eight slots each.
pub(crate) type Picks = ArrayVec<Pick, 24>;

/// sm/state.bend `GrabOption`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum GrabOption {
    TakeItem,
    PutAt { slot: Slot },
}

pub(crate) type GrabOptions = ArrayVec<GrabOption, 9>;

/// `seat.health`.
pub(crate) fn seat_health(players: &Players, seat: Seat) -> u32 {
    let _ = (players, seat);
    0
}

/// `seat.slots`.
pub(crate) fn seat_slots(players: &Players, seat: Seat) -> Slots {
    let _ = (players, seat);
    Slots::EMPTY
}

/// `seat.holding`.
pub(crate) fn seat_holding(grabs: &Grabs, seat: Seat) -> Option<Item> {
    let _ = (grabs, seat);
    None
}

/// `grabs.open_all`.
pub(crate) fn grabs_open_all(seats: Seats, grabs: Grabs) -> Grabs {
    let _ = seats;
    grabs
}

/// `grabs.stop_intake`.
pub(crate) fn grabs_stop_intake(grabs: Grabs, seat: Seat) -> Grabs {
    let _ = seat;
    grabs
}

/// `grabs.give`.
pub(crate) fn grabs_give(grabs: Grabs, seat: Seat, item: Item) -> Grabs {
    let _ = (seat, item);
    grabs
}

/// `grabs.close`.
pub(crate) fn grabs_close(grabs: Grabs, seat: Seat) -> Grabs {
    let _ = seat;
    grabs
}

/// `grabs.placed`.
pub(crate) fn grabs_placed(grabs: Grabs, seat: Seat) -> Grabs {
    let _ = seat;
    grabs
}

/// `pool`: the items `seat` may still be granted, in item order.
pub(crate) fn pool(config: &Config, state: &State, seat: Seat) -> Items {
    let _ = (config, state, seat);
    Items::EMPTY
}

/// `begin.seats`.
pub(crate) fn begin_seats(config: &Config, state: &State, new_round: bool, amount: u32) -> Seats {
    let _ = (config, state, new_round, amount);
    Seats::EMPTY
}

/// One seat's entry of `grab.needs` (empty for a seat not at the table).
pub(crate) fn grab_needs(config: &Config, state: &State, seat: Seat) -> GrabOptions {
    let _ = (config, state, seat);
    GrabOptions::new()
}

/// `placing.last`.
pub(crate) fn placing_last(config: &Config, state: &State, seat: Seat) -> bool {
    let _ = (config, state, seat);
    false
}

/// `finished`.
pub(crate) fn finished(config: &Config, state: &State) -> bool {
    let _ = (config, state);
    true
}

/// `stalled.seats`.
pub(crate) fn stalled_seats(config: &Config, state: &State, placing: Seat) -> Seats {
    let _ = (config, state, placing);
    Seats::EMPTY
}

/// `holders` over the holding ring.
pub(crate) fn holders(grabs: &Grabs) -> bool {
    let _ = grabs;
    false
}

/// `amount.live`.
pub(crate) const fn amount_live(rule: AmountRule, distributing: bool, reload: bool) -> bool {
    let _ = (rule, distributing, reload);
    false
}

/// `reload.wanted`.
pub(crate) fn reload_wanted(config: &Config, state: &State, winner: Option<Seat>) -> bool {
    let _ = (config, state, winner);
    false
}

/// `jam.for`: the seats `by` may jam.
pub(crate) fn jam_for(config: &Config, state: &State, by: Seat) -> Seats {
    let _ = (config, state, by);
    Seats::EMPTY
}

/// `steal.for`.
pub(crate) fn steal_for(config: &Config, state: &State, thief: Seat) -> Picks {
    let _ = (config, state, thief);
    Picks::new()
}

/// `uses`.
pub(crate) fn uses(config: &Config, state: &State, seat: Seat) -> Uses {
    let _ = (config, state, seat);
    Uses::new()
}

/// `ends_turn`.
pub(crate) const fn ends_turn(item: Item, length: u32) -> bool {
    let _ = (item, length);
    false
}

/// `invert`.
pub(crate) const fn invert(shell: Shell) -> Shell {
    match shell {
        Shell::Live => {
            bend_arm!("sm/items:invert:D.Live{}");
            Shell::Blank
        }
        Shell::Blank => {
            bend_arm!("sm/items:invert:D.Blank{}");
            Shell::Live
        }
    }
}

/// `flip`.
pub(crate) const fn flip(direction: Direction) -> Direction {
    match direction {
        Direction::Clockwise => {
            bend_arm!("sm/items:flip:D.Clockwise{}");
            Direction::CounterClockwise
        }
        Direction::CounterClockwise => {
            bend_arm!("sm/items:flip:D.CounterClockwise{}");
            Direction::Clockwise
        }
    }
}
