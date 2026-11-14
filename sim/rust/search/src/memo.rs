//! The search's memo and node tally (`player/memo.bend`). A key holds every
//! world's state (without the notes of the answer that reached it) and the
//! bits of its weight, so two beliefs share a key exactly when they hold the
//! same states with the same weights in the same order, as Bend's string keys do.
//!
//! The memo is indexed by a hash of the key, but every lookup compares the
//! whole key: two keys that share a hash stay apart, as they do in Bend. The
//! key is copied out of the beliefs only when an entry is stored. A key holds
//! each world's state as an index into the memo's [`States`], which keeps
//! every distinct state once: the beliefs of nearby nodes share most states.

use std::hash::{BuildHasher, Hash, Hasher};

use buckshot_rules::State;
use hashbrown::HashTable;
use hashbrown::hash_table::Entry as Slot;
use rustc_hash::{FxBuildHasher, FxHasher};

use crate::deal::Sums;
use crate::num::Bits;
use crate::search::BoxEntry;
use crate::types::{Cached, World};
#[cfg(feature = "f32")]
use crate::types::{Memo, Reach};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    Deal,
    Decision,
}

/// Every distinct state the memo's keys hold, each once, by index; the index
/// table holds each state's hash beside its index.
#[derive(Debug, Default)]
struct States {
    all: Vec<State>,
    index: HashTable<(u64, u32)>,
}

impl States {
    fn get(&self, id: u32) -> Option<&State> {
        self.all.get(usize::try_from(id).ok()?)
    }

    /// The index of `state`, added if it is new.
    fn id(&mut self, state: State) -> u32 {
        let hash = FxBuildHasher.hash_one(state);
        let Self { all, index } = self;
        let held = |id: u32| usize::try_from(id).ok().and_then(|id| all.get(id)) == Some(&state);
        match index.entry(hash, |&(_, id)| held(id), |&(hash, _)| hash) {
            Slot::Occupied(found) => found.get().1,
            Slot::Vacant(free) => {
                #[expect(clippy::expect_used, reason = "a memo never holds 2^32 states")]
                let id = u32::try_from(all.len()).expect("fewer than 2^32 states");
                all.push(state);
                free.insert((hash, id));
                id
            }
        }
    }
}

/// A key with its [`hash`], which a rehash of the memo reuses: the public
/// worlds, then the private ones, each as its weight's bits and its state's
/// index in [`States`].
#[derive(Debug)]
struct Key {
    hash: u64,
    kind: Kind,
    public: u32,
    worlds: Box<[(Bits, u32)]>,
}

fn same(held: &[(Bits, u32)], worlds: &[World], states: &States) -> bool {
    held.len() == worlds.len()
        && held
            .iter()
            .zip(worlds)
            .all(|(&(bits, id), world)| bits == world.weight.bits() && states.get(id) == Some(&world.state))
}

impl Key {
    fn new(hash: u64, kind: Kind, beliefs: (&[World], &[World]), states: &mut States) -> Self {
        let (public, private) = beliefs;
        #[expect(clippy::expect_used, reason = "a belief never holds 2^32 worlds")]
        let count = u32::try_from(public.len()).expect("fewer than 2^32 worlds");
        Self {
            hash,
            kind,
            public: count,
            worlds: public
                .iter()
                .chain(private)
                .map(|world| (world.weight.bits(), states.id(world.state)))
                .collect(),
        }
    }

    fn is(&self, kind: Kind, beliefs: (&[World], &[World]), states: &States) -> bool {
        let (public, private) = beliefs;
        let Some((held_public, held_private)) = usize::try_from(self.public)
            .ok()
            .and_then(|count| self.worlds.split_at_checked(count))
        else {
            return false;
        };
        self.kind == kind && same(held_public, public, states) && same(held_private, private, states)
    }
}

/// The index of a key: its kind, then each belief's length and worlds.
pub fn hash(kind: Kind, public: &[World], private: &[World]) -> u64 {
    let mut hasher = FxHasher::default();
    kind.hash(&mut hasher);
    for worlds in [public, private] {
        worlds.len().hash(&mut hasher);
        for world in worlds {
            world.weight.bits().hash(&mut hasher);
            world.state.hash(&mut hasher);
        }
    }
    hasher.finish()
}

/// A decision node's value, the depth it was searched to, and the nodes that search spent.
#[cfg(feature = "f32")]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Entry {
    pub public: u32,
    pub private: u32,
    pub reach: Reach,
    pub depth: u32,
    pub cost: u64,
}

#[cfg(feature = "f32")]
impl Entry {
    /// `entry.serves`: a value with no cut leaf holds at any greater depth.
    pub const fn serves(&self, depth: u32) -> bool {
        match self.reach {
            Reach::Cut => self.depth == depth,
            Reach::Settled | Reach::Reloads => self.depth <= depth,
        }
    }

    /// `entry.cost`.
    pub const fn charge(&self, memo: Memo) -> u64 {
        match memo {
            Memo::Free => 0,
            Memo::Off | Memo::Charged => self.cost,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Stored {
    #[cfg(feature = "f32")]
    Decision(Entry),
    Deal(Sums),
    Box(BoxEntry),
}

/// What the search has spent and found so far.
#[derive(Debug, Default)]
pub struct Tally {
    pub nodes: u64,
    memo: HashTable<(Key, Stored)>,
    states: States,
    pub cached: Cached,
}

impl Tally {
    /// What is stored under the key of `kind` and the beliefs; `hash` is its [`hash`].
    pub fn find(&self, hash: u64, kind: Kind, public: &[World], private: &[World]) -> Option<Stored> {
        self.memo
            .find(hash, |(key, _)| key.is(kind, (public, private), &self.states))
            .map(|(_, stored)| *stored)
    }

    /// `keep`: stores under the key, in place of what it held before.
    pub fn keep(&mut self, hash: u64, kind: Kind, beliefs: (&[World], &[World]), stored: Stored) {
        let Self { memo, states, cached, .. } = self;
        match memo.entry(hash, |(key, _)| key.is(kind, beliefs, states), |(key, _)| key.hash) {
            Slot::Occupied(mut held) => {
                held.get_mut().1 = stored;
                return;
            }
            Slot::Vacant(free) => {
                free.insert((Key::new(hash, kind, beliefs, states), stored));
            }
        }
        match stored {
            #[cfg(feature = "f32")]
            Stored::Decision(_) => cached.entries = cached.entries.saturating_add(1),
            Stored::Box(_) => cached.entries = cached.entries.saturating_add(1),
            Stored::Deal(_) => cached.deals = cached.deals.saturating_add(1),
        }
    }

    /// `tally.hit`.
    pub const fn hit(&mut self, cost: u64) {
        self.nodes = self.nodes.saturating_add(cost);
        self.cached.hits = self.cached.hits.saturating_add(1);
    }

    /// `tally.deal_hit`.
    pub const fn deal_hit(&mut self) {
        self.cached.deal_hits = self.cached.deal_hits.saturating_add(1);
    }
}

#[cfg(test)]
mod tests {
    use buckshot_rules::{Event, initial, step_event};

    use super::{Kind, Stored, Tally};
    use crate::deal::Sums;
    use crate::num::Real;
    use crate::search::tests::config;
    use crate::types::World;

    /// Two keys that share a hash stay apart: a lookup compares every world's
    /// weight and state, as Bend's string keys do.
    #[test]
    fn keys_sharing_a_hash_stay_apart() {
        let config = config().expect("a valid config");
        let state = initial(&config);
        let other = step_event(&config, state, Event::Draw(0)).expect("a draw").state;
        assert_ne!(state, other, "the draw changes the state");
        let world = |at| World {
            state: at,
            weight: Real::ONE,
            won: None,
        };
        let half = World {
            weight: Real::ONE.div(Real::from_u32(2)),
            ..world(state)
        };
        let kept = [world(state)];
        let mut tally = Tally::default();
        tally.keep(
            7,
            Kind::Deal,
            (&kept, &kept),
            Stored::Deal(Sums {
                public: Real::ONE,
                private: Real::ONE,
            }),
        );
        assert!(tally.find(7, Kind::Deal, &kept, &kept).is_some(), "the same key");
        for probe in [vec![world(other)], vec![half], vec![world(state), world(state)], vec![]] {
            assert_eq!(tally.find(7, Kind::Deal, &probe, &kept), None, "public {probe:?}");
            assert_eq!(tally.find(7, Kind::Deal, &kept, &probe), None, "private {probe:?}");
        }
        assert_eq!(tally.find(7, Kind::Decision, &kept, &kept), None, "another kind");
    }
}
