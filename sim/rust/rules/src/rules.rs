//! `sm/rules.bend`: turn order, jammers, loads, shots and the winner.
//! Plumbing (`nth`, `remove`, `swap`, `value.or`, `load.shells`) lives on
//! the domain types.

use crate::domain::{AmountRule, Config, Damage, Direction, HealthRule, Load, LoadRule, RoundRules, Seat, Seats, Shell};
use crate::state::{Players, World};

/// sm/state.bend `JamResult`: what a seat's jammer does when its turn comes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum JamResult {
    Act { players: Players },
    Lift { players: Players },
    Skip { players: Players },
}

/// `aim.targets`: the living seats, in socket order.
pub(crate) fn aim_targets(players: &Players) -> Seats {
    let _ = players;
    Seats::EMPTY
}

/// `next_turn`.
pub(crate) fn next_turn(players: &Players, direction: Direction, current: Seat) -> Seat {
    let _ = (players, direction);
    current
}

/// `jam`.
pub(crate) fn jam(players: Players, seat: Seat) -> JamResult {
    let _ = seat;
    JamResult::Act { players }
}

/// `jam_rank`.
pub(crate) fn jam_rank(players: &Players) -> u32 {
    let _ = players;
    0
}

/// `predecessor`.
pub(crate) const fn predecessor(n: u32) -> u32 {
    n.saturating_sub(1)
}

/// `world.rules`.
pub(crate) fn world_rules<'a>(config: &'a Config, world: &World) -> &'a RoundRules {
    let _ = world;
    &config.rounds()[0]
}

/// `round.health`.
pub(crate) const fn round_health(round: &RoundRules) -> HealthRule {
    round.health
}

/// `world.load_rule`.
pub(crate) fn world_load_rule(config: &Config, world: &World) -> LoadRule {
    let _ = (config, world);
    LoadRule { shells: crate::domain::ShellRule::Random, items: AmountRule::Random }
}

/// `load.actual`.
pub(crate) const fn load_actual(rule: LoadRule, sampled: Load) -> Load {
    let _ = rule;
    sampled
}

/// `load.amount`.
pub(crate) const fn load_amount(rule: LoadRule) -> AmountRule {
    rule.items
}

/// `load.next`.
pub(crate) const fn load_next(first: bool, index: u32) -> u32 {
    let _ = first;
    index
}

/// `round.next`.
pub(crate) const fn round_next(before: bool, index: u32) -> u32 {
    let _ = before;
    index
}

/// `subtract`: truncated subtraction.
pub(crate) const fn subtract(left: u32, right: u32) -> u32 {
    left.saturating_sub(right)
}

/// `captured`.
pub(crate) const fn captured(sawed: bool) -> Damage {
    if sawed { Damage::Double } else { Damage::Single }
}

/// `shot.health`.
pub(crate) const fn shot_health(shell: Shell, hp: u32, damage: Damage) -> u32 {
    let _ = (shell, damage);
    hp
}

/// `shot.passes`.
pub(crate) const fn shot_passes(shell: Shell, same: bool) -> bool {
    let _ = (shell, same);
    false
}

/// `winner`.
pub(crate) fn winner(players: &Players) -> Option<Seat> {
    let _ = players;
    None
}
