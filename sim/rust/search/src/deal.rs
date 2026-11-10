//! The sampled reload leaf (`player/deal.bend`, Sampled deals): the static
//! value averaged over `count` deals drawn from each start, seeded by the
//! start's key so a leaf draws the same deals whenever it is valued.

use std::collections::BTreeMap;

use arrayvec::ArrayVec;
use buckshot_rules::{Config, Grabs, Item, Notes, Phase, Players, Request, Seat, Shell, State, World as Records, request, step_into};
use rayon::ThreadPool;
use rayon::iter::{IntoParallelIterator, ParallelExtend, ParallelIterator};

use crate::evaluation::state_value;
use crate::machine::{round_won, token};
use crate::num::Real;
use crate::types::World;

/// Probability times static value, summed over the deals, under the public and the private belief.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Sums {
    pub public: Real,
    pub private: Real,
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

fn seat_code(seat: Seat) -> u32 {
    u32::from(u8::from(seat))
}

fn maybe_seat_code(seat: Option<Seat>) -> u32 {
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

/// The most codes a key holds: a phase (a `NeedItem` with every item), six
/// counters, a deck's batches (a deck is 16 bits), the turn, four seats with
/// every item's count and the grabs.
const KEY_CAPACITY: usize = 4 + Item::ORDER.len() + 6 + 16 + 3 + 4 * (2 + Item::ORDER.len()) + 1 + 4 * 4;

/// A start's key: `push` and `extend` panic past [`KEY_CAPACITY`] rather than cut it.
type DealKey = ArrayVec<u32, KEY_CAPACITY>;

fn put_shells(key: &mut DealKey, gun: buckshot_rules::Gun) {
    let live = gun.live();
    key.push(live);
    key.push(gun.len().wrapping_sub(live));
}

fn put_phase(key: &mut DealKey, phase: Phase) {
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

fn put_seats(key: &mut DealKey, players: &Players) {
    for (_, player) in players.entries() {
        key.extend([player.health, jam_code(player.jam)]);
        for item in Item::ORDER {
            let copies = player.slots.entries().filter(|(_, held)| *held == Some(item)).count();
            key.push(crate::num::len_u32(copies));
        }
    }
}

fn put_grabs(key: &mut DealKey, grabs: &Grabs) {
    key.push(u32::from(grabs.distributing));
    key.extend(grabs.grabbing.entries().map(|(_, b)| u32::from(b)));
    key.extend(grabs.holding.entries().map(|(_, item)| item_code(item)));
    key.extend(grabs.granted.entries().map(|(_, n)| n));
    key.extend(grabs.intake.entries().map(|(_, b)| u32::from(b)));
}

/// `key(state, True)`: everything a deal's draws write, with the slots and the gun as counts.
fn key(config: &Config, state: &State) -> DealKey {
    let world: &Records = &state.world;
    let mut key = DealKey::new();
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

fn deal_value(state: &State, won: Option<Seat>, me: Seat) -> Real {
    Real::from_u32(state_value(state, won, me, chamber_known(state.world.gun)))
}

/// A two-seat deal draws at most 19 times, so this fuel is never spent.
const DEAL_FUEL: u32 = 64;

/// `sample.deal`: word `n` of the deal's stream answers its n-th draw. The
/// winner is the one the last answer's notes announce.
fn sample_deal(config: &Config, start: &Start, seed: u32, notes: &mut Notes) -> Option<(State, Option<Seat>)> {
    let mut state = start.state;
    let mut won = start.won;
    let mut n = 0u32;
    for _ in 0..DEAL_FUEL {
        let at = request(config, &state);
        let Request::Draw { range, .. } = at else {
            break;
        };
        let count = range.extra.wrapping_add(2);
        let k = mix(seed ^ mix(n)).checked_rem(count).unwrap_or(0);
        if let Some(answer) = token(&at, k) {
            state = step_into(config, state, answer, notes);
            if notes.truncated() {
                return None;
            }
            won = round_won(notes.as_slice());
        }
        n = n.wrapping_add(1);
    }
    Some((state, won))
}

#[derive(Clone, Copy, Debug)]
struct Start {
    state: State,
    won: Option<Seat>,
    public: Real,
    private: Real,
}

/// The buffers a sampled leaf reuses: the merged starts and one start's deal values.
#[derive(Debug, Default)]
pub struct DealScratch {
    starts: BTreeMap<DealKey, Start>,
    values: Vec<Option<Real>>,
    notes: Notes,
}

/// One deal's static value, `None` if an answer's notes outgrew their buffer.
fn deal(config: &Config, start: &Start, seed: u32, k: u32, me: Seat, notes: &mut Notes) -> Option<Real> {
    let (state, won) = sample_deal(config, start, mix(seed ^ k), notes)?;
    Some(deal_value(&state, won, me))
}

/// `sampled`: the starts merged by key, in key order, each valued by its mean
/// over `count` deals; `None` if an answer's notes outgrew their buffer.
///
/// With a pool the deals of a start run in parallel. A deal reads only its
/// start and its seed, and the memo and the fuel are not touched here, so the
/// values are the same ones; they are collected by index and summed in the
/// order Bend sums them, from the last deal to the first.
pub fn sampled(
    config: &Config,
    beliefs: (&[World], &[World]),
    me: Seat,
    count: u32,
    pool: Option<&ThreadPool>,
    scratch: &mut DealScratch,
) -> Option<Sums> {
    let (public, private) = beliefs;
    let DealScratch { starts, values, notes } = scratch;
    starts.clear();
    let weighted = public
        .iter()
        .map(|world| (world, world.weight, Real::ZERO))
        .chain(private.iter().map(|world| (world, Real::ZERO, world.weight)));
    for (world, p, q) in weighted {
        let (state, won) = (world.state, world.won);
        starts
            .entry(key(config, &world.state))
            .and_modify(|start| {
                *start = Start {
                    state,
                    won,
                    public: start.public.add(p),
                    private: start.private.add(q),
                };
            })
            .or_insert(Start {
                state,
                won,
                public: p,
                private: q,
            });
    }
    let n = Real::from_u32(count);
    let mut sums = Sums {
        public: Real::ZERO,
        private: Real::ZERO,
    };
    for (key, start) in starts.iter() {
        let seed = key_seed(key, SEED);
        values.clear();
        match pool {
            Some(pool) => pool.install(|| {
                values.par_extend(
                    (0..count)
                        .into_par_iter()
                        .map_init(Notes::default, |own, k| deal(config, start, seed, k, me, own)),
                );
            }),
            None => values.extend((0..count).map(|k| deal(config, start, seed, k, me, notes))),
        }
        let total = values
            .iter()
            .rev()
            .try_fold(Real::ZERO, |total, value| value.map(|value| total.add(value)))?;
        let value = total.div(n);
        sums = Sums {
            public: sums.public.add(start.public.mul(value)),
            private: sums.private.add(start.private.mul(value)),
        };
    }
    Some(sums)
}

#[cfg(test)]
mod tests {
    use buckshot_rules::{Gun, Load, Seat, State, World as Records, initial};

    use super::deal_value;
    use crate::search::tests::config;

    /// `chamber.known`: a dealt gun of one shell kind tells the chamber, so its
    /// deal takes the knowledge bonus; a mixed or empty gun does not.
    #[test]
    fn a_one_kind_gun_is_valued_as_known() {
        let start = initial(&config().expect("a valid config"));
        let value = |live, blank| {
            let gun = Gun::of_load(Load { live, blank });
            deal_value(
                &State {
                    world: Records { gun, ..start.world },
                    ..start
                },
                None,
                Seat::Seat1,
            )
        };
        assert_eq!(value(3, 0), value(0, 3), "all live and all blank are both known");
        assert!(value(3, 0).to_u32() > value(2, 1).to_u32(), "a one-kind gun beats a mixed one");
        assert_eq!(value(0, 0), value(2, 1), "an empty gun is not known");
    }
}
