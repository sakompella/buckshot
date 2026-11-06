//! The static evaluation (`player/evaluation.bend`).

use buckshot_rules::{Item, Seat, SeatRecord, Shell, Slots, State, alive};

use crate::belief::clue_holds;
use crate::num::F32;
use crate::types::World;

const fn item_weight(item: Item) -> u32 {
    match item {
        Item::Saw => 65,
        Item::Glass => 60,
        Item::Jammer => 90,
        Item::Cigarettes => 75,
        Item::Beer => 25,
        Item::Phone => 30,
        Item::Inverter => 45,
        Item::Adrenaline => 80,
        Item::Remote => 15,
    }
}

fn slots_weight(slots: Slots) -> u32 {
    slots
        .entries()
        .fold(0, |sum, (_, item)| sum.wrapping_add(item.map_or(0, item_weight)))
}

/// `seat.weight`: Bend's U32 arithmetic wraps.
fn seat_weight(player: SeatRecord, tempo: bool) -> u32 {
    if player.health == 0 {
        return 0;
    }
    let base = player
        .health
        .wrapping_mul(100)
        .wrapping_add(slots_weight(player.slots))
        .wrapping_add(if tempo { 35 } else { 0 });
    base.wrapping_sub(if player.jam.jammed() { base.min(50) } else { 0 })
}

/// `state.estimate`: my share of the table's weight, in millionths.
fn estimate(state: &State, me: Seat, knowledge: bool) -> u32 {
    let players = state.players;
    let turn = state.world.turn;
    let own = players.get(me).unwrap_or(SeatRecord::FRESH);
    let bonus = if knowledge && alive(own.health) { 25 } else { 0 };
    let weight = seat_weight(own, turn == Some(me)).wrapping_add(bonus);
    let total = players
        .entries()
        .fold(0u32, |sum, (seat, player)| {
            sum.wrapping_add(seat_weight(player, turn == Some(seat)))
        })
        .wrapping_add(bonus);
    F32::per_million(weight, total.max(1))
}

/// `state`: the exact value of a won round, else the estimate.
pub fn state_value(state: &State, won: Option<Seat>, me: Seat, knowledge: bool) -> u32 {
    match won {
        Some(seat) if seat == me => 1_000_000,
        Some(_) => 0,
        None => estimate(state, me, knowledge),
    }
}

fn same_chamber(worlds: &[World], shell: Shell) -> bool {
    worlds.iter().all(|world| clue_holds(world.state.world.gun, 0, shell))
}

/// `known`: every world agrees on the chambered shell.
pub fn known(worlds: &[World]) -> bool {
    !worlds.is_empty() && (same_chamber(worlds, Shell::Live) || same_chamber(worlds, Shell::Blank))
}

/// `sum`: the probability-weighted value, folded from the last world.
pub fn sum(worlds: &[World], me: Seat, knowledge: bool) -> F32 {
    F32::sum_right(
        worlds
            .iter()
            .map(|world| world.weight.mul(F32::from_u32(state_value(&world.state, world.won, me, knowledge)))),
    )
}
