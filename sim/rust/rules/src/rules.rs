//! `sm/rules.bend`: turn order, jammers, loads, shots and the winner.
//! List plumbing (`nth`, `replace`, `remove`, `swap`, `repeat`,
//! `load.shells`, `batches`) lives on the domain and state types.

use crate::domain::{AmountRule, Config, Damage, Direction, HealthRule, Load, LoadRule, RoundRules, Seat, Seats, Shell, ShellRule};
use crate::state::{Jam, Players, SeatRecord, World};

/// sm/state.bend `JamResult`: what a seat's jammer does when its turn comes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum JamResult {
    Act { players: Players },
    Lift { players: Players },
    Skip { players: Players },
}

/// `alive`.
fn alive(hp: u32) -> bool {
    match hp {
        0 => {
            bend_arm!("sm/rules:alive:0n");
            false
        }
        1.. => {
            bend_arm!("sm/rules:alive:1n+rest");
            true
        }
    }
}

/// `living` (and `targets`, the same filter): the living seats, in ring order.
fn living(players: &Players) -> Seats {
    let mut seats = Seats::EMPTY;
    for (seat, record) in players.entries() {
        if alive(record.health) {
            bend_arm!("sm/rules:living:D.At{seat, 1n+hp} <> rest");
            seats.push(seat);
        } else {
            bend_arm!("sm/rules:living:D.At{seat, 0n} <> rest");
        }
    }
    seats
}

/// `aim.targets`: every living seat, in ring order: who an aiming seat may shoot.
pub(crate) fn aim_targets(players: &Players) -> Seats {
    living(players)
}

/// `turn_candidates`: the living seats and `current`, in ring order.
fn turn_candidates(players: &Players, current: Seat) -> Seats {
    let mut seats = Seats::EMPTY;
    for (seat, record) in players.entries() {
        let keep = alive(record.health) | (seat == current);
        if keep {
            bend_arm!("sm/rules:seats.keep:True{}");
            seats.push(seat);
        } else {
            bend_arm!("sm/rules:seats.keep:False{}");
        }
    }
    seats
}

/// `successor`: the seat after `current` in `seats`, cycling; `current` when `seats` is empty.
fn successor(seats: impl Iterator<Item = Seat> + Clone, current: Seat) -> Seat {
    let mut list = seats.clone();
    let Some(head) = list.next() else {
        bend_arm!("sm/rules:successor:Nil{}");
        return current;
    };
    bend_arm!("sm/rules:successor:+head <> rest");
    let mut pairs = seats.clone().zip(seats.skip(1));
    pairs.find(|(seat, _)| *seat == current).map_or(head, |(_, next)| next)
}

/// `next_turn` with `traversal`.
pub(crate) fn next_turn(players: &Players, direction: Direction, current: Seat) -> Seat {
    let candidates = turn_candidates(players, current);
    match direction {
        Direction::Clockwise => {
            bend_arm!("sm/rules:traversal:D.Clockwise{}");
            successor(candidates.iter(), current)
        }
        Direction::CounterClockwise => {
            bend_arm!("sm/rules:traversal:D.CounterClockwise{}");
            successor(candidates.iter().rev(), current)
        }
    }
}

fn set_jam(players: Players, seat: Seat, jam: Jam) -> Players {
    let record = players.get(seat).unwrap_or(SeatRecord::FRESH);
    players.set(seat, SeatRecord { jam, ..record })
}

/// `jam` with `jam.state`.
pub(crate) fn jam(players: Players, seat: Seat) -> JamResult {
    match players.get(seat).map_or(Jam::Free, |record| record.jam) {
        Jam::Free => {
            bend_arm!("sm/rules:jam.state:S.Free{}");
            JamResult::Act { players }
        }
        Jam::Jammed => {
            bend_arm!("sm/rules:jam.state:S.Jammed{}");
            JamResult::Skip { players: set_jam(players, seat, Jam::JammedSkipped) }
        }
        Jam::JammedSkipped => {
            bend_arm!("sm/rules:jam.state:S.JammedSkipped{}");
            JamResult::Lift { players: set_jam(players, seat, Jam::Free) }
        }
    }
}

/// `jam_rank`: the seats whose next turn is skipped; grant skips at most this many seats.
pub(crate) fn jam_rank(players: &Players) -> u32 {
    let mut rank = 0u32;
    for (_, record) in players.entries() {
        match record.jam {
            Jam::Jammed => {
                bend_arm!("sm/rules:jam_rank.bit:S.Jammed{}");
                rank = rank.saturating_add(1);
            }
            Jam::Free | Jam::JammedSkipped => {
                bend_arm!("sm/rules:jam_rank.bit:_");
            }
        }
    }
    rank
}

/// `predecessor`.
pub(crate) fn predecessor(n: u32) -> u32 {
    match n.checked_sub(1) {
        None => {
            bend_arm!("sm/rules:predecessor:0n");
            0
        }
        Some(n) => {
            bend_arm!("sm/rules:predecessor:1n+n");
            n
        }
    }
}

/// `world.rules`: the round's rules, or the default round past the plan.
pub(crate) fn world_rules(config: &Config, world: &World) -> RoundRules {
    match config.round(world.round_index) {
        Some(round) => {
            bend_arm!("sm/rules:value.or:Some{x}");
            *round
        }
        None => {
            bend_arm!("sm/rules:value.or:None{}");
            RoundRules::default_round()
        }
    }
}

/// `round.health`.
pub(crate) const fn round_health(round: &RoundRules) -> HealthRule {
    round.health
}

/// `world.load_rule` with `rules.load`.
pub(crate) fn world_load_rule(config: &Config, world: &World) -> LoadRule {
    let [a, b, c, d] = world_rules(config, world).loads;
    match world.load_index {
        0 => {
            bend_arm!("sm/rules:rules.load:D.LoadRules{a, _, _, _} 0n");
            a
        }
        1 => {
            bend_arm!("sm/rules:rules.load:D.LoadRules{_, b, _, _} 1n");
            b
        }
        2 => {
            bend_arm!("sm/rules:rules.load:D.LoadRules{_, _, c, _} 2n");
            c
        }
        3.. => {
            bend_arm!("sm/rules:rules.load:D.LoadRules{_, _, _, d} _");
            d
        }
    }
}

/// `load.actual`.
pub(crate) fn load_actual(rule: LoadRule, sampled: Load) -> Load {
    match rule.shells {
        ShellRule::Random => {
            bend_arm!("sm/rules:load.actual:D.LoadRule{D.RandomShells{}, _}");
            sampled
        }
        ShellRule::Fixed { live, blank } => {
            bend_arm!("sm/rules:load.actual:D.LoadRule{D.FixedShells{live, blank}, _}");
            Load { live, blank }
        }
        ShellRule::AllLive { live } => {
            bend_arm!("sm/rules:load.actual:D.LoadRule{D.AllLive{live}, _}");
            Load { live, blank: 0 }
        }
    }
}

/// `load.amount`.
pub(crate) const fn load_amount(rule: LoadRule) -> AmountRule {
    rule.items
}

/// `load.next`.
pub(crate) fn load_next(first: bool, index: u32) -> u32 {
    match (first, index) {
        (true, _) => {
            bend_arm!("sm/rules:load.next:True{} _");
            0
        }
        (false, 0) => {
            bend_arm!("sm/rules:load.next:False{} 0n");
            1
        }
        (false, 1) => {
            bend_arm!("sm/rules:load.next:False{} 1n");
            2
        }
        (false, 2) => {
            bend_arm!("sm/rules:load.next:False{} 2n");
            3
        }
        (false, 3..) => {
            bend_arm!("sm/rules:load.next:False{} _");
            0
        }
    }
}

/// `round.next`. The round index stays below the plan length (at most 3).
pub(crate) fn round_next(before: bool, index: u32) -> u32 {
    if before {
        bend_arm!("sm/rules:round.next:True{}");
        0
    } else {
        bend_arm!("sm/rules:round.next:False{}");
        index.saturating_add(1)
    }
}

/// `subtract`: truncated subtraction.
pub(crate) const fn subtract(left: u32, right: u32) -> u32 {
    left.saturating_sub(right)
}

/// `captured`.
pub(crate) fn captured(sawed: bool) -> Damage {
    if sawed {
        bend_arm!("sm/rules:captured:True{}");
        Damage::Double
    } else {
        bend_arm!("sm/rules:captured:False{}");
        Damage::Single
    }
}

/// `shot.health`.
pub(crate) fn shot_health(shell: Shell, hp: u32, damage: Damage) -> u32 {
    match shell {
        Shell::Blank => {
            bend_arm!("sm/rules:shot.health:D.Blank{}");
            hp
        }
        Shell::Live => {
            bend_arm!("sm/rules:shot.health:D.Live{}");
            subtract(hp, damage.amount())
        }
    }
}

/// `shot.passes`: a blank at oneself keeps the turn.
pub(crate) fn shot_passes(shell: Shell, same: bool) -> bool {
    match (shell, same) {
        (Shell::Blank, true) => {
            bend_arm!("sm/rules:shot.passes:D.Blank{} True{}");
            false
        }
        (Shell::Live, _) | (Shell::Blank, false) => {
            bend_arm!("sm/rules:shot.passes:_ _");
            true
        }
    }
}

/// `winner` with `winner.only`: the only living seat.
pub(crate) fn winner(players: &Players) -> Option<Seat> {
    let seats = living(players);
    if seats.len() == 1 {
        bend_arm!("sm/rules:winner.only:seat <> Nil{}");
        seats.first()
    } else {
        bend_arm!("sm/rules:winner.only:_");
        None
    }
}
