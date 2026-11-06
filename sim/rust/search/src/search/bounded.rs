//! `bounded-v1`: the search over value boxes from `_work/wip/stage3-design.md`,
//! still unpruned. Every node returns a box `[pub_lo, pub_hi] x [priv_lo,
//! priv_hi]` holding its exact value pair; with every child searched, every
//! box is degenerate and the values are compat's.
//!
//! Budget: only nodes count, one per world a move is played in, as in compat;
//! there is no fuel. A memo hit costs nothing, and a decision's box is reused
//! only at the depth it was searched to. An iteration of the deepening
//! that would spend past the budget is abandoned, and the last finished one
//! stands, marked limited.

use std::collections::BTreeSet;
use std::hash::{DefaultHasher, Hash, Hasher};

use buckshot_rules::{Menu, Request, request};

use super::{Choice, Search, Searched, Span, Value, analysed, limited, lines_static, push_choices, static_value};
use crate::memo::{Kind, Stored, hash};
use crate::num::F32;
use crate::types::{Analysis, Line, Reach, World};

/// The values a coordinate can take: `lo..=hi`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Bounds {
    pub lo: u32,
    pub hi: u32,
}

impl Bounds {
    const fn exact(value: u32) -> Self {
        Self { lo: value, hi: value }
    }

    fn hull(self, other: Self) -> Self {
        Self {
            lo: self.lo.min(other.lo),
            hi: self.hi.max(other.hi),
        }
    }
}

/// A node's value box and the reach of its leaves.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Boxed {
    pub public: Bounds,
    pub private: Bounds,
    pub reach: Reach,
}

impl Boxed {
    const fn exact(value: Value) -> Self {
        Self {
            public: Bounds::exact(value.public),
            private: Bounds::exact(value.private),
            reach: value.reach,
        }
    }
}

/// A decision's box, the depth it was searched to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BoxEntry {
    pub boxed: Boxed,
    pub depth: u32,
}

impl BoxEntry {
    /// A box is reused only at the depth it was searched to: a reach without
    /// cut leaves is no proof of depth independence once children are pruned.
    const fn serves(&self, depth: u32) -> bool {
        self.depth == depth
    }
}

/// The decision nodes one search visited: every visit, and the distinct
/// belief keys among them. A key is a 64-bit `SipHash` of the exact memo
/// key, so two keys collide with odds near `n² / 2^65`.
#[derive(Clone, Debug, Default)]
pub struct KeyStats {
    pub visits: u64,
    pub keys: BTreeSet<u64>,
}

fn stats_key(public: &[World], private: &[World]) -> u64 {
    let mut hasher = DefaultHasher::new();
    for worlds in [public, private] {
        worlds.len().hash(&mut hasher);
        for world in worlds {
            world.weight.bits().hash(&mut hasher);
            world.state.hash(&mut hasher);
        }
    }
    hasher.finish()
}

fn known(searched: Searched) -> Option<Boxed> {
    match searched {
        Searched::Value(value) => Some(Boxed::exact(value)),
        Searched::Scores(_) | Searched::Spent => None,
    }
}

/// Whether child `j` can still be the first argmax (with `max`) or the first
/// argmin of its coordinate among `children`.
fn candidate(children: &[Boxed], j: usize, max: bool) -> bool {
    let Some(this) = children.get(j) else {
        return false;
    };
    !children.iter().enumerate().any(|(k, other)| {
        if max {
            let (beats, ties) = (other.private.lo > this.private.hi, other.private.lo >= this.private.hi);
            beats || (k < j && ties)
        } else {
            let (beats, ties) = (other.public.hi < this.public.lo, other.public.hi <= this.public.lo);
            beats || (k < j && ties)
        }
    })
}

/// `decide` over boxes. The searcher's private value is a candidate's and
/// its public value the best public one; an opponent's both are a
/// candidate's, its public value the lowest one.
fn decide_boxes(mine: bool, children: &[Boxed]) -> Option<Boxed> {
    let first = children.first()?;
    let mut chosen: Option<Boxed> = None;
    for (j, child) in children.iter().enumerate() {
        if candidate(children, j, mine) {
            chosen = Some(chosen.map_or(*child, |hull| Boxed {
                public: hull.public.hull(child.public),
                private: hull.private.hull(child.private),
                reach: hull.reach,
            }));
        }
    }
    let chosen = chosen?;
    let rest = children.get(1..).unwrap_or(&[]);
    let public = if mine {
        rest.iter().fold(first.public, |best, child| Bounds {
            lo: best.lo.max(child.public.lo),
            hi: best.hi.max(child.public.hi),
        })
    } else {
        rest.iter().fold(first.public, |best, child| Bounds {
            lo: best.lo.min(child.public.lo),
            hi: best.hi.min(child.public.hi),
        })
    };
    let reach = children.iter().fold(Reach::Settled, |reach, child| reach.join(child.reach));
    Some(Boxed {
        public,
        private: chosen.private,
        reach,
    })
}

/// A probability-weighted sum of one end of a coordinate, in Bend's order.
struct Fold {
    public: F32,
    private: F32,
}

impl Fold {
    const ZERO: Self = Self {
        public: F32::ZERO,
        private: F32::ZERO,
    };

    fn add(self, public_p: F32, private_p: F32, public: u32, private: u32) -> Self {
        Self {
            public: self.public.add(public_p.mul(F32::from_u32(public))),
            private: self.private.add(private_p.mul(F32::from_u32(private))),
        }
    }
}

impl Search<'_> {
    /// `node.task` over boxes; `None` once the budget is spent.
    fn bounded_node(&mut self, depth: u32, public: Span, private: Span) -> Option<Boxed> {
        let Some(first) = public.of(&self.worlds).first().copied() else {
            return Some(Boxed::exact(Value {
                public: 0,
                private: 0,
                reach: Reach::Settled,
            }));
        };
        if first.won.is_some() {
            return known(self.leaf(public, private, Reach::Settled));
        }
        match (request(self.config, &first.state), depth.checked_sub(1)) {
            (Request::Choose(menu), Some(child)) => self.bounded_decision(menu.seat() == self.me, child, (public, private), &menu),
            (Request::Draw { .. }, _) => known(self.reload_leaf(public, private)),
            (Request::Choose(_), None) | (Request::Finished | Request::Stuck, _) => known(self.leaf(public, private, Reach::Cut)),
        }
    }

    fn bounded_decision(&mut self, mine: bool, depth: u32, beliefs: (Span, Span), menu: &Menu) -> Option<Boxed> {
        let (public, private) = beliefs;
        let key = {
            let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
            if let Some(stats) = &mut self.stats {
                stats.visits = stats.visits.saturating_add(1);
                stats.keys.insert(stats_key(public_worlds, private_worlds));
            }
            let key = hash(Kind::Decision, public_worlds, private_worlds);
            if let Some(Stored::Box(entry)) = self.tally.find(key, Kind::Decision, public_worlds, private_worlds)
                && entry.serves(depth)
            {
                self.tally.hit(0);
                return Some(entry.boxed);
            }
            key
        };
        let choices = push_choices(menu, &mut self.choices);
        let result = self.bounded_moves(depth, public, private, choices);
        self.choices.truncate(choices.start);
        let (mark, boxes) = result?;
        let decided = decide_boxes(mine, boxes.of(&self.boxes));
        self.boxes.truncate(mark);
        let value = decided?;
        let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
        self.tally.keep(
            key,
            Kind::Decision,
            (public_worlds, private_worlds),
            Stored::Box(BoxEntry { boxed: value, depth }),
        );
        Some(value)
    }

    /// Every move's box, in menu order, pushed onto [`Search::boxes`]. On
    /// `None` the stack is back where it was.
    fn bounded_moves(&mut self, depth: u32, public: Span, private: Span, choices: Span) -> Option<(usize, Span)> {
        let mark = self.boxes.len();
        for at in choices.start..choices.end {
            let Some(choice) = self.choices.get(at).copied() else {
                break;
            };
            let Some(boxed) = self.bounded_option(depth, public, private, choice.index) else {
                self.boxes.truncate(mark);
                return None;
            };
            self.boxes.push(boxed);
        }
        Some((mark, Span::from(mark, self.boxes.len())))
    }

    fn bounded_option(&mut self, depth: u32, public: Span, private: Span, index: u32) -> Option<Boxed> {
        let worlds = u64::try_from(public.len().saturating_add(private.len())).unwrap_or(u64::MAX);
        let spent = self.tally.nodes.saturating_add(worlds);
        if spent > self.budget {
            return None;
        }
        self.tally.nodes = spent;
        let mark = self.worlds.len();
        let branches = self.outcomes(public, private, index);
        let result = self.bounded_branches(depth, branches);
        self.branches.truncate(branches.start);
        self.worlds.truncate(mark);
        result
    }

    /// The branch sums on both ends of both coordinates, each in Bend's
    /// order. With probabilities and values non-negative, f32 addition and
    /// multiplication round monotonically, so the low sums bound the exact
    /// one from below and the high sums from above.
    fn bounded_branches(&mut self, depth: u32, branches: Span) -> Option<Boxed> {
        let (mut lo, mut hi) = (Fold::ZERO, Fold::ZERO);
        let mut reach = Reach::Settled;
        for at in branches.start..branches.end {
            let branch = self.branches.get(at).copied()?;
            let child = self.bounded_node(depth, branch.public, branch.private)?;
            lo = lo.add(branch.public_p, branch.private_p, child.public.lo, child.private.lo);
            hi = hi.add(branch.public_p, branch.private_p, child.public.hi, child.private.hi);
            reach = reach.join(child.reach);
        }
        Some(Boxed {
            public: Bounds {
                lo: lo.public.millionths(),
                hi: hi.public.millionths(),
            },
            private: Bounds {
                lo: lo.private.millionths(),
                hi: hi.private.millionths(),
            },
            reach,
        })
    }

    /// Iterative deepening over boxes. A line scores its private low end, with
    /// its high end as `upper`.
    pub(super) fn bounded_root(&mut self, depth: u32, public: Span, private: Span, choices: Span) -> Analysis {
        let static_lines = lines_static(choices.of(&self.choices), static_value(private.of(&self.worlds), self.me));
        if depth == 0 {
            return analysed(static_lines, &crate::memo::Tally::default(), 0, false);
        }
        let mut completed = analysed(static_lines, &crate::memo::Tally::default(), 0, true);
        for current in 0..depth {
            if let Some(stats) = &mut self.stats {
                *stats = KeyStats::default();
            }
            let Some((mark, boxes)) = self.bounded_moves(current, public, private, choices) else {
                return limited(completed, &self.tally);
            };
            let lines = choices
                .of(&self.choices)
                .iter()
                .zip(boxes.of(&self.boxes))
                .map(|(choice, boxed): (&Choice, &Boxed)| Line {
                    index: choice.index,
                    r#move: choice.r#move,
                    score: boxed.private.lo,
                    upper: boxed.private.hi,
                    reach: boxed.reach,
                })
                .collect();
            self.boxes.truncate(mark);
            completed = analysed(lines, &self.tally, current.saturating_add(1), false);
        }
        completed
    }
}

#[cfg(test)]
mod tests {
    use super::{Bounds, BoxEntry, Boxed, Fold, decide_boxes};
    use crate::num::F32;
    use crate::types::Reach;

    fn exact(public: u32, private: u32) -> Boxed {
        Boxed {
            public: Bounds::exact(public),
            private: Bounds::exact(private),
            reach: Reach::Settled,
        }
    }

    fn boxed(public: (u32, u32), private: (u32, u32), reach: Reach) -> Boxed {
        Boxed {
            public: Bounds {
                lo: public.0,
                hi: public.1,
            },
            private: Bounds {
                lo: private.0,
                hi: private.1,
            },
            reach,
        }
    }

    #[test]
    fn the_searcher_takes_each_coordinates_maximum_on_its_own() {
        let children = [exact(900_000, 100_000), exact(100_000, 900_000)];
        assert_eq!(decide_boxes(true, &children), Some(exact(900_000, 900_000)), "max pub, max priv");
    }

    #[test]
    fn an_opponent_tied_on_public_keeps_the_first_childs_private() {
        let children = [exact(300_000, 100_000), exact(300_000, 800_000), exact(500_000, 0)];
        assert_eq!(decide_boxes(false, &children), Some(exact(300_000, 100_000)), "first argmin pub");
    }

    #[test]
    fn the_searcher_tied_on_private_keeps_the_first_child() {
        let children = [exact(200_000, 700_000), exact(600_000, 700_000)];
        assert_eq!(
            decide_boxes(true, &children),
            Some(exact(600_000, 700_000)),
            "max pub over all, first argmax priv"
        );
    }

    #[test]
    fn a_box_that_may_still_win_widens_the_result() {
        let children = [
            boxed((0, 0), (400_000, 600_000), Reach::Settled),
            boxed((0, 0), (500_000, 900_000), Reach::Cut),
            boxed((0, 0), (0, 300_000), Reach::Settled),
        ];
        let expected = boxed((0, 0), (400_000, 900_000), Reach::Cut);
        assert_eq!(
            decide_boxes(true, &children),
            Some(expected),
            "the third child is out; the reach joins all"
        );
    }

    #[test]
    fn a_later_child_equal_to_an_earlier_low_end_is_out() {
        let children = [
            boxed((100_000, 100_000), (500_000, 500_000), Reach::Settled),
            boxed((100_000, 200_000), (200_000, 500_000), Reach::Settled),
        ];
        let expected = boxed((100_000, 200_000), (500_000, 500_000), Reach::Settled);
        assert_eq!(decide_boxes(true, &children), Some(expected), "a tie goes to the earlier child");
    }

    #[test]
    fn a_box_serves_only_at_its_own_depth() {
        let entry = BoxEntry {
            boxed: exact(1, 1),
            depth: 3,
        };
        assert_eq!([2, 3, 4].map(|depth| entry.serves(depth)), [false, true, false], "depths 2, 3, 4");
    }

    #[test]
    fn the_low_and_high_sums_bracket_the_exact_sum() {
        let (p, q) = (F32::from_u32(1).div(F32::from_u32(3)), F32::from_u32(2).div(F32::from_u32(3)));
        let sum = |a: u32, b: u32| Fold::ZERO.add(p, p, a, a).add(q, q, b, b).public.millionths();
        let (lo, mid, hi) = (sum(100_000, 200_000), sum(150_000, 250_000), sum(200_000, 300_000));
        assert!(lo <= mid && mid <= hi, "{lo} <= {mid} <= {hi}");
    }
}
