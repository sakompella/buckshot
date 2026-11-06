//! The sampled reload leaf (`player/deal.bend`, Sampled deals): the static
//! value averaged over `count` deals drawn from each start, seeded by the
//! start's key so a leaf draws the same deals whenever it is valued.

use std::collections::BTreeMap;

use buckshot_rules::{Config, Grabs, Item, Phase, Players, Seat, Shell, State, World as Records};

use crate::evaluation::state_value;
use crate::machine::{Stepped, answer, draw_range};
use crate::num::F32;
use crate::types::World;

/// Probability times static value, summed over the deals, under the public and the private belief.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Sums {
    pub public: F32,
    pub private: F32,
}

/// `mix`: a 32-bit finalizer.
#[must_use]
pub const fn mix(x: u32) -> u32 {
    let x1 = x ^ (x >> 16_u32);
    let x2 = x1.wrapping_mul(2_146_121_005);
    let x3 = x2 ^ (x2 >> 15_u32);
    let x4 = x3.wrapping_mul(2_221_713_035);
    x4 ^ (x4 >> 16_u32)
}

/// The FNV offset basis, an arbitrary nonzero start.
const SEED: u32 = 2_166_136_261;

const fn seat_code(seat: Seat) -> u32 {
    match seat {
        Seat::Seat0 => 0,
        Seat::Seat1 => 1,
        Seat::Seat2 => 2,
        Seat::Seat3 => 3,
    }
}

const fn maybe_seat_code(seat: Option<Seat>) -> u32 {
    match seat {
        None => 9,
        Some(seat) => seat_code(seat),
    }
}

/// `item.godot_id`.
pub const fn godot_id(item: Item) -> u32 {
    match item {
        Item::Saw => 1,
        Item::Glass => 2,
        Item::Jammer => 3,
        Item::Cigarettes => 4,
        Item::Beer => 5,
        Item::Phone => 6,
        Item::Inverter => 9,
        Item::Adrenaline => 8,
        Item::Remote => 10,
    }
}

const fn item_code(item: Option<Item>) -> u32 {
    match item {
        None => 0,
        Some(item) => godot_id(item),
    }
}

const fn jam_code(jam: buckshot_rules::Jam) -> u32 {
    match jam {
        buckshot_rules::Jam::Free => 0,
        buckshot_rules::Jam::Jammed => 1,
        buckshot_rules::Jam::JammedSkipped => 2,
    }
}

fn put_shells(key: &mut Vec<u32>, gun: buckshot_rules::Gun) {
    let live = crate::num::len_u32(gun.iter().filter(|shell| *shell == Shell::Live).count());
    key.push(live);
    key.push(gun.len().wrapping_sub(live));
}

fn put_phase(key: &mut Vec<u32>, phase: Phase) {
    match phase {
        Phase::NeedBatch => key.push(1),
        Phase::NeedSwap { load, shells, i } => {
            key.extend([2, load.live, load.blank]);
            put_shells(key, shells);
            key.push(i);
        }
        Phase::Idle { seat } => key.extend([3, seat_code(seat)]),
        Phase::NeedTurnAmount { from, passing, winner } => {
            key.extend([4, seat_code(from), u32::from(passing), maybe_seat_code(winner)]);
        }
        Phase::NeedItem { seat, first, second, rest } => {
            key.extend([5, seat_code(seat), godot_id(first), godot_id(second)]);
            key.extend(rest.iter().map(godot_id));
        }
        Phase::NeedFirst
        | Phase::NeedHealth
        | Phase::NeedAmount
        | Phase::Ended
        | Phase::Blocked { .. }
        | Phase::Stalled
        | Phase::NeedPhone { .. } => key.push(6),
    }
}

fn put_seats(key: &mut Vec<u32>, players: &Players) {
    for (_, player) in players.entries() {
        key.extend([player.health, jam_code(player.jam)]);
        for item in Item::ORDER {
            let copies = player.slots.entries().filter(|(_, held)| *held == Some(item)).count();
            key.push(crate::num::len_u32(copies));
        }
    }
}

fn put_grabs(key: &mut Vec<u32>, grabs: &Grabs) {
    key.push(u32::from(grabs.distributing));
    key.extend(grabs.grabbing.entries().map(|(_, b)| u32::from(b)));
    key.extend(grabs.holding.entries().map(|(_, item)| item_code(item)));
    key.extend(grabs.granted.entries().map(|(_, n)| n));
    key.extend(grabs.intake.entries().map(|(_, b)| u32::from(b)));
}

/// `key(state, True)`: everything a deal's draws write, with the slots and the gun as counts.
fn key(config: &Config, state: &State) -> Vec<u32> {
    let world: &Records = &state.world;
    let mut key = Vec::with_capacity(64);
    put_phase(&mut key, state.phase);
    key.push(world.load_index);
    key.push(u32::from(world.first_sequence));
    put_shells(&mut key, world.gun);
    key.extend([world.shown.live, world.shown.blank]);
    key.extend(world.decks.get(config.table()).iter().map(|batch| batch.id));
    key.extend([world.item_amount, maybe_seat_code(world.turn), seat_code(world.first_turn)]);
    put_seats(&mut key, &state.players);
    put_grabs(&mut key, &state.grabs);
    key
}

fn key_seed(key: &[u32], seed: u32) -> u32 {
    key.iter().fold(seed, |seed, code| mix(seed ^ code))
}

/// `chamber.known`: every order of the gun agrees on the chamber.
fn chamber_known(gun: buckshot_rules::Gun) -> bool {
    !gun.is_empty() && (gun.iter().all(|s| s == Shell::Live) || gun.iter().all(|s| s == Shell::Blank))
}

fn deal_value(state: &State, won: Option<Seat>, me: Seat) -> F32 {
    F32::from_u32(state_value(state, won, me, chamber_known(state.world.gun)))
}

/// A two-seat deal draws at most 19 times, so this fuel is never spent.
const DEAL_FUEL: u32 = 64;

/// `sample.deal`: word `n` of the deal's stream answers its n-th draw.
fn sample_deal(config: &Config, start: Stepped, seed: u32) -> Stepped {
    let mut at = start;
    let mut n = 0u32;
    for _ in 0..DEAL_FUEL {
        let Some(range) = draw_range(config, &at.state) else {
            break;
        };
        let count = range.extra.wrapping_add(2);
        let k = mix(seed ^ mix(n)).checked_rem(count).unwrap_or(0);
        at = answer(config, at, k);
        n = n.wrapping_add(1);
    }
    at
}

struct Start {
    at: Stepped,
    public: F32,
    private: F32,
}

/// `sampled`: the starts merged by key, in key order, each valued by its mean over `count` deals.
pub fn sampled(config: &Config, public: &[World], private: &[World], me: Seat, count: u32) -> Sums {
    let mut starts: BTreeMap<Vec<u32>, Start> = BTreeMap::new();
    let weighted = public
        .iter()
        .map(|world| (world, world.weight, F32::ZERO))
        .chain(private.iter().map(|world| (world, F32::ZERO, world.weight)));
    for (world, p, q) in weighted {
        let at = Stepped {
            state: world.state,
            won: world.won,
        };
        starts
            .entry(key(config, &world.state))
            .and_modify(|start| {
                *start = Start {
                    at,
                    public: start.public.add(p),
                    private: start.private.add(q),
                };
            })
            .or_insert(Start { at, public: p, private: q });
    }
    let n = F32::from_u32(count);
    starts.iter().fold(
        Sums {
            public: F32::ZERO,
            private: F32::ZERO,
        },
        |sums, (key, start)| {
            let seed = key_seed(key, SEED);
            let total = (0..count).rev().fold(F32::ZERO, |total, k| {
                let dealt = sample_deal(config, start.at, mix(seed ^ k));
                total.add(deal_value(&dealt.state, dealt.won, me))
            });
            let value = total.div(n);
            Sums {
                public: sums.public.add(start.public.mul(value)),
                private: sums.private.add(start.private.mul(value)),
            }
        },
    )
}
