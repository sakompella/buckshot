//! The search's memo and node tally (`player/memo.bend`). A key holds every
//! world's state (without the notes of the answer that reached it) and the
//! bits of its weight, so two beliefs share a key exactly when they hold the
//! same states with the same weights in the same order, as Bend's string keys do.
//!
//! The memo is indexed by a hash of the key, but every lookup compares the
//! whole key: two keys that share a hash stay apart, as they do in Bend. The
//! key is copied out of the beliefs only when an entry is stored.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hash, Hasher};

use buckshot_rules::State;
use rustc_hash::FxHasher;

use crate::deal::Sums;
use crate::search::BoxEntry;
use crate::types::{Cached, Memo, Reach, World};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    Deal,
    Decision,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Key {
    kind: Kind,
    public: Vec<(u32, State)>,
    private: Vec<(u32, State)>,
}

fn spelled(worlds: &[World]) -> Vec<(u32, State)> {
    worlds.iter().map(|world| (world.weight.bits(), world.state)).collect()
}

fn same(spelled: &[(u32, State)], worlds: &[World]) -> bool {
    spelled.len() == worlds.len()
        && spelled
            .iter()
            .zip(worlds)
            .all(|((bits, state), world)| *bits == world.weight.bits() && *state == world.state)
}

impl Key {
    fn new(kind: Kind, public: &[World], private: &[World]) -> Self {
        Self {
            kind,
            public: spelled(public),
            private: spelled(private),
        }
    }

    fn is(&self, kind: Kind, public: &[World], private: &[World]) -> bool {
        self.kind == kind && same(&self.public, public) && same(&self.private, private)
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
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Entry {
    pub public: u32,
    pub private: u32,
    pub reach: Reach,
    pub depth: u32,
    pub cost: u64,
}

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
    Decision(Entry),
    Deal(Sums),
    Box(BoxEntry),
}

/// What the search has spent and found so far.
#[derive(Debug, Default)]
pub struct Tally {
    pub nodes: u64,
    memo: HashMap<u64, Vec<(Key, Stored)>, BuildHasherDefault<FxHasher>>,
    pub cached: Cached,
}

impl Tally {
    /// What is stored under the key of `kind` and the beliefs; `hash` is its [`hash`].
    pub fn find(&self, hash: u64, kind: Kind, public: &[World], private: &[World]) -> Option<Stored> {
        self.memo
            .get(&hash)?
            .iter()
            .find(|(key, _)| key.is(kind, public, private))
            .map(|(_, stored)| *stored)
    }

    /// `keep`: stores under the key, in place of what it held before.
    pub fn keep(&mut self, hash: u64, kind: Kind, beliefs: (&[World], &[World]), stored: Stored) {
        let (public, private) = beliefs;
        let bucket = self.memo.entry(hash).or_default();
        if let Some((_, held)) = bucket.iter_mut().find(|(key, _)| key.is(kind, public, private)) {
            *held = stored;
            return;
        }
        bucket.push((Key::new(kind, public, private), stored));
        match stored {
            Stored::Decision(_) | Stored::Box(_) => self.cached.entries = self.cached.entries.saturating_add(1),
            Stored::Deal(_) => self.cached.deals = self.cached.deals.saturating_add(1),
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
