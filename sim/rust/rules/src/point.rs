//! `simple/point.bend`: the request at a point and a seat's Idle menu.

use arrayvec::ArrayVec;

use crate::domain::{Config, Seat};
use crate::state::State;
use crate::{IdleOption, MENU_CAPACITY, Menu, Request};

/// `options`: every legal move of `seat`, in menu order (shots, uses, jams,
/// steals, steal-jams).
pub(crate) fn options(config: &Config, state: &State, seat: Seat) -> ArrayVec<IdleOption, MENU_CAPACITY> {
    let _ = (config, state, seat);
    ArrayVec::new()
}

/// `request`.
#[must_use]
pub fn request(config: &Config, state: &State) -> Request {
    let _ = (config, state);
    Request::Stuck
}

impl Menu {
    pub(crate) const fn new(seat: Seat, options: ArrayVec<IdleOption, MENU_CAPACITY>) -> Self {
        Self { seat, options }
    }
}
