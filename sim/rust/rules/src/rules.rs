//! `sm/rules.bend`: turn order, jammers, loads, shots and the winner.
//! List plumbing (`nth`, `replace`, `remove`, `swap`, `repeat`,
//! `load.shells`, `batches`) lives on the domain and state types.

use crate::branch::B;
use crate::domain::{AmountRule, Config, Damage, Direction, HealthRule, Load, LoadRule, RoundRules, Seat, Seats, Shell, ShellRule};
use crate::state::{Jam, Players, SeatRecord, World, players_seat};

/// sm/state.bend `JamResult`: what a seat's jammer does when its turn comes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum JamResult {
    Act { players: Players },
    Lift { players: Players },
    Skip { players: Players },
}

/// `alive`.
pub(crate) fn alive(hp: u32) -> bool {
    if hp == 0 {
        branch!(B::SmRulesAliveZero);
        false
    } else {
        branch!(B::SmRulesAliveSucc);
        true
    }
}

/// `living` (and `targets`, the same filter): the living seats, in ring order.
fn living(players: &Players) -> Seats {
    let mut seats = Seats::EMPTY;
    for (seat, record) in players.entries() {
        if alive(record.health) {
            branch!(B::SmRulesLivingAtSuccCons);
            seats.push(seat);
        } else {
            branch!(B::SmRulesLivingAtZeroCons);
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
        let keep = alive(record.health) || seat == current;
        if keep {
            branch!(B::SmRulesSeatsKeepTrue);
            seats.push(seat);
        } else {
            branch!(B::SmRulesSeatsKeepFalse);
        }
    }
    seats
}

/// `successor`: the seat after `current` in `seats`, cycling; `current` when `seats` is empty.
fn successor(seats: impl Iterator<Item = Seat> + Clone, current: Seat) -> Seat {
    let mut list = seats.clone();
    let Some(head) = list.next() else {
        branch!(B::SmRulesSuccessorNil);
        return current;
    };
    branch!(B::SmRulesSuccessorCons);
    let mut pairs = seats.clone().zip(seats.skip(1));
    pairs.find(|(seat, _)| *seat == current).map_or(head, |(_, next)| next)
}

/// `next_turn` with `traversal`.
pub(crate) fn next_turn(players: &Players, direction: Direction, current: Seat) -> Seat {
    let candidates = turn_candidates(players, current);
    match direction {
        Direction::Clockwise => {
            branch!(B::SmRulesTraversalClockwise);
            successor(candidates.iter(), current)
        }
        Direction::CounterClockwise => {
            branch!(B::SmRulesTraversalCounterClockwise);
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
            branch!(B::SmRulesJamStateFree);
            JamResult::Act { players }
        }
        Jam::Jammed => {
            branch!(B::SmRulesJamStateJammed);
            JamResult::Skip {
                players: set_jam(players, seat, Jam::JammedSkipped),
            }
        }
        Jam::JammedSkipped => {
            branch!(B::SmRulesJamStateJammedSkipped);
            JamResult::Lift {
                players: set_jam(players, seat, Jam::Free),
            }
        }
    }
}

/// `jam_rank`: the seats whose next turn is skipped; grant skips at most this many seats.
pub(crate) fn jam_rank(players: &Players) -> u32 {
    let mut rank = 0u32;
    for (_, record) in players.entries() {
        match record.jam {
            Jam::Jammed => {
                branch!(B::SmRulesJamRankBitJammed);
                rank = rank.saturating_add(1);
            }
            Jam::Free | Jam::JammedSkipped => {
                branch!(B::SmRulesJamRankBitAny);
            }
        }
    }
    rank
}

/// `predecessor`.
pub(crate) fn predecessor(n: u32) -> u32 {
    match n.checked_sub(1) {
        None => {
            branch!(B::SmRulesPredecessorZero);
            0
        }
        Some(n) => {
            branch!(B::SmRulesPredecessorSucc);
            n
        }
    }
}

/// `world.rules`: the round's rules, or the default round past the plan.
pub(crate) fn world_rules(config: &Config, world: &World) -> RoundRules {
    if let Some(round) = config.round(world.round_index) {
        branch!(B::SmRulesValueOrSome);
        *round
    } else {
        branch!(B::SmRulesValueOrNone);
        RoundRules::default_round()
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
            branch!(B::SmRulesRulesLoadLoadRulesZero);
            a
        }
        1 => {
            branch!(B::SmRulesRulesLoadLoadRulesOne);
            b
        }
        2 => {
            branch!(B::SmRulesRulesLoadLoadRulesTwo);
            c
        }
        3.. => {
            branch!(B::SmRulesRulesLoadLoadRules);
            d
        }
    }
}

/// `load.actual`.
pub(crate) fn load_actual(rule: LoadRule, sampled: Load) -> Load {
    match rule.shells {
        ShellRule::Random => {
            branch!(B::SmRulesLoadActualLoadRuleRandomShells);
            sampled
        }
        ShellRule::Fixed { live, blank } => {
            branch!(B::SmRulesLoadActualLoadRuleFixedShells);
            Load { live, blank }
        }
        ShellRule::AllLive { live } => {
            branch!(B::SmRulesLoadActualLoadRuleAllLive);
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
            branch!(B::SmRulesLoadNextTrue);
            0
        }
        (false, 0) => {
            branch!(B::SmRulesLoadNextFalseZero);
            1
        }
        (false, 1) => {
            branch!(B::SmRulesLoadNextFalseOne);
            2
        }
        (false, 2) => {
            branch!(B::SmRulesLoadNextFalseTwo);
            3
        }
        (false, 3..) => {
            branch!(B::SmRulesLoadNextFalse);
            0
        }
    }
}

/// `round.next`. The round index stays below the plan length (at most 3).
pub(crate) fn round_next(before: bool, index: u32) -> u32 {
    if before {
        branch!(B::SmRulesRoundNextTrue);
        0
    } else {
        branch!(B::SmRulesRoundNextFalse);
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
        branch!(B::SmRulesCapturedTrue);
        Damage::Double
    } else {
        branch!(B::SmRulesCapturedFalse);
        Damage::Single
    }
}

/// `shot.health`.
pub(crate) fn shot_health(shell: Shell, hp: u32, damage: Damage) -> u32 {
    match shell {
        Shell::Blank => {
            branch!(B::SmRulesShotHealthBlank);
            hp
        }
        Shell::Live => {
            branch!(B::SmRulesShotHealthLive);
            subtract(hp, damage.amount())
        }
    }
}

/// `shot.passes`: a blank at oneself keeps the turn.
pub(crate) fn shot_passes(shell: Shell, same: bool) -> bool {
    match (shell, same) {
        (Shell::Blank, true) => {
            branch!(B::SmRulesShotPassesBlankTrue);
            false
        }
        (Shell::Live, _) | (Shell::Blank, false) => {
            branch!(B::SmRulesShotPassesAny);
            true
        }
    }
}

/// `winner` with `winner.only`: the only living seat.
pub(crate) fn winner(players: &Players) -> Option<Seat> {
    let seats = living(players);
    if seats.len() == 1 {
        branch!(B::SmRulesWinnerOnlyConsNil);
        seats.first()
    } else {
        branch!(B::SmRulesWinnerOnlyAny);
        None
    }
}
