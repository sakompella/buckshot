//! The search's memo and node tally (`player/memo.bend`). A key holds every
//! world's state (without the notes of the answer that reached it) and the
//! bits of its weight, so two beliefs share a key exactly when they hold the
//! same states with the same weights in the same order, as Bend's string keys do.

use std::collections::HashMap;

use buckshot_rules::State;

use crate::deal::Sums;
use crate::types::{Cached, Memo, Reach, World};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    Deal,
    Decision,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Key {
    kind: Kind,
    public: Vec<(u32, State)>,
    private: Vec<(u32, State)>,
}

fn spelled(worlds: &[World]) -> Vec<(u32, State)> {
    worlds.iter().map(|world| (world.weight.bits(), world.state)).collect()
}

impl Key {
    pub fn new(kind: Kind, public: &[World], private: &[World]) -> Self {
        Self {
            kind,
            public: spelled(public),
            private: spelled(private),
        }
    }
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
}

/// What the search has spent and found so far.
#[derive(Debug, Default)]
pub struct Tally {
    pub nodes: u64,
    memo: HashMap<Key, Stored>,
    pub cached: Cached,
}

impl Tally {
    pub fn find(&self, key: &Key) -> Option<Stored> {
        self.memo.get(key).copied()
    }

    /// `keep`: stores under `key`, in place of what it held before.
    pub fn keep(&mut self, key: Key, stored: Stored) {
        if self.memo.insert(key, stored).is_none() {
            match stored {
                Stored::Decision(_) => self.cached.entries = self.cached.entries.saturating_add(1),
                Stored::Deal(_) => self.cached.deals = self.cached.deals.saturating_add(1),
            }
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
