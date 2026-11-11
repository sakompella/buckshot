//! `bounded-v1`: the search over value boxes.
//!
//! Every node returns a box `[pub_lo, pub_hi] x [priv_lo, priv_hi]` that
//! holds its exact value pair. A caller passes the [`Need`] of each
//! coordinate, a window outside of which only the side of the value matters,
//! and a node skips the children that cannot matter to it (alpha-beta at
//! decisions, Star1 at chance nodes). A skipped child counts as the universal
//! box with a cut reach, so a reach is conservative. Leaves are always exact.
//!
//! Pruning contract:
//! - Unpruned, every need is exact and every box degenerate: the values are
//!   compat's, at a budget compat finishes within.
//! - Pruned, each root line gets a box of the private value: `score` is its
//!   low end and `upper` its high end. The best move and the chosen move
//!   (the menu index the caller names) are searched exactly, so their box is
//!   one point. Every other line's box is proved no better: its high end is
//!   below the best score if it comes earlier in the menu, at most the best
//!   score if later (a tie goes to the earlier move).
//! - Ties among an opponent's moves go to the first lowest public value, so
//!   its private value is the hull of the children that may be that move.
//!
//! Budget: only nodes count, one per world a move is played in, as in compat;
//! there is no fuel. A memo hit costs nothing. An iteration of the deepening
//! that would spend past the budget is abandoned, and the last finished one
//! stands, marked limited.
//!
//! Memo: a decision's box is stored under its full key (the public and the
//! private worlds, compared whole, not only their hash) and the depth it was
//! searched to. It serves a later visit only at that same remaining depth and
//! when its box meets the need of the visit: a reach without cut leaves proves
//! nothing about other depths once children are pruned.
//!
//! Round end: a world whose round was won is a settled leaf, even when the
//! winning move already began the next round, so the search scores the won
//! round and never the next round's start. A reload is a leaf valued by the
//! reload mode.

use std::iter;

use arrayvec::ArrayVec;
use buckshot_rules::{MENU_CAPACITY, Menu, Request, request};

use super::{Choice, Search, Span, Spent, Value, analysed, best_line, limited, lines_static, push_choices, static_value};
use crate::memo::{Kind, Stored, Tally, hash};
use crate::num::{Real, branch_window, len_u64};
use crate::types::{Analysis, Line, Reach};

/// The highest value: `millionths` clamps every sum to a million.
const TOP: u32 = 1_000_000;

/// The values a coordinate can take: `lo..=hi`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Bounds {
    pub lo: u32,
    pub hi: u32,
}

impl Bounds {
    const ANY: Self = Self { lo: 0, hi: TOP };

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
    /// A child that was not searched.
    const ANY: Self = Self {
        public: Bounds::ANY,
        private: Bounds::ANY,
        reach: Reach::Cut,
    };

    const fn exact(value: Value) -> Self {
        Self {
            public: Bounds::exact(value.public),
            private: Bounds::exact(value.private),
            reach: value.reach,
        }
    }
}

/// What a caller needs of a coordinate: its exact value when it lies
/// strictly between `lo` and `hi`, else only that it is at most `lo` or at
/// least `hi`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Window {
    lo: u32,
    hi: u32,
}

impl Window {
    const EXACT: Self = Self { lo: 0, hi: u32::MAX };
    const NONE: Self = Self { lo: u32::MAX, hi: 0 };

    const fn met(self, bounds: Bounds) -> bool {
        bounds.lo == bounds.hi || bounds.hi <= self.lo || bounds.lo >= self.hi
    }

    /// Whether the coordinate matters at all: an unsearched child would not do.
    const fn needed(self) -> bool {
        !self.met(Bounds::ANY)
    }
}

/// The windows of both coordinates.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Need {
    public: Window,
    private: Window,
}

impl Need {
    const EXACT: Self = Self {
        public: Window::EXACT,
        private: Window::EXACT,
    };

    const fn met(self, boxed: &Boxed) -> bool {
        self.public.met(boxed.public) && self.private.met(boxed.private)
    }

    /// Exact where `boxed` falls short, as it was elsewhere.
    const fn tightened(self, boxed: &Boxed) -> Self {
        Self {
            public: if self.public.met(boxed.public) {
                self.public
            } else {
                Window::EXACT
            },
            private: if self.private.met(boxed.private) {
                self.private
            } else {
                Window::EXACT
            },
        }
    }
}

/// A decision's box, the depth it was searched to and the move that led it
/// (the highest private low end, or the first lowest public high end), which
/// a later search of the decision tries first.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BoxEntry {
    pub boxed: Boxed,
    pub depth: u32,
    pub lead: usize,
}

impl BoxEntry {
    /// A box is reused only at the depth it was searched to: a reach without
    /// cut leaves is no proof of depth independence once children are pruned.
    const fn serves(&self, depth: u32, need: Need) -> bool {
        self.depth == depth && need.met(&self.boxed)
    }
}

/// `decide` over boxes, the `pending` children after `children` unsearched.
/// The searcher's values are the highest public and the highest private
/// value; an opponent's are the first lowest public value's child's.
fn decide_boxes(mine: bool, children: &[Boxed], pending: usize) -> Option<Boxed> {
    let all = || children.iter().copied().chain(iter::repeat_n(Boxed::ANY, pending));
    let first = all().next()?;
    let reach = all().fold(Reach::Settled, |reach, child| reach.join(child.reach));
    let highest = |bounds: Bounds, other: Bounds| Bounds {
        lo: bounds.lo.max(other.lo),
        hi: bounds.hi.max(other.hi),
    };
    if mine {
        return Some(Boxed {
            public: all().map(|child| child.public).fold(first.public, highest),
            private: all().map(|child| child.private).fold(first.private, highest),
            reach,
        });
    }
    let public = all().map(|child| child.public).fold(first.public, |bounds, other| Bounds {
        lo: bounds.lo.min(other.lo),
        hi: bounds.hi.min(other.hi),
    });
    // Child j may be the first argmin unless an earlier child is surely no
    // higher or a later one surely lower.
    let mut private: Option<Bounds> = None;
    for (j, this) in all().enumerate() {
        let beaten = all()
            .enumerate()
            .any(|(k, other)| other.public.hi < this.public.lo || (k < j && other.public.hi <= this.public.lo));
        if !beaten {
            private = Some(private.map_or(this.private, |hull| hull.hull(this.private)));
        }
    }
    Some(Boxed {
        public,
        private: private?,
        reach,
    })
}

/// The decision's running state over the children searched so far, in any
/// order: the highest low ends (the searcher's) or the lowest public high end
/// and the first child in menu order that has it (an opponent's), from which
/// the next child's need follows.
#[derive(Clone, Copy, Debug)]
struct Running {
    public_lo: u32,
    private_lo: u32,
    public_hi: u32,
    lowest: usize,
}

impl Running {
    const START: Self = Self {
        public_lo: 0,
        private_lo: 0,
        public_hi: u32::MAX,
        lowest: usize::MAX,
    };

    /// With child `j` (its menu index) searched.
    fn add(self, j: usize, child: &Boxed) -> Self {
        let lower = child.public.hi < self.public_hi || (child.public.hi == self.public_hi && j < self.lowest);
        Self {
            public_lo: self.public_lo.max(child.public.lo),
            private_lo: self.private_lo.max(child.private.lo),
            public_hi: self.public_hi.min(child.public.hi),
            lowest: if lower { j } else { self.lowest },
        }
    }

    /// Child `j`'s need, or `None` when the children left cannot matter.
    fn next(self, mine: bool, j: usize, need: Need) -> Option<Need> {
        if mine {
            // A child at most the best low end so far changes no maximum.
            let raise = |window: Window, lo: u32| {
                if window.met(Bounds { lo, hi: TOP }) {
                    Window::NONE
                } else {
                    Window {
                        lo: window.lo.max(lo),
                        hi: window.hi,
                    }
                }
            };
            let next = Need {
                public: raise(need.public, self.public_lo),
                private: raise(need.private, self.private_lo),
            };
            return (next.public.needed() || next.private.needed()).then_some(next);
        }
        // A child at least the lowest public high end so far is not the first
        // argmin, nor one above it when it comes earlier in the menu. Telling
        // which child is needs its exact public value.
        let above = if j < self.lowest {
            self.public_hi.saturating_add(1)
        } else {
            self.public_hi
        };
        if need.private.needed() {
            return Some(Need {
                public: Window { lo: 0, hi: above },
                private: need.private,
            });
        }
        let public = Bounds {
            lo: 0,
            hi: self.public_hi.min(TOP),
        };
        (!need.public.met(public)).then_some(Need {
            public: Window {
                lo: need.public.lo,
                hi: need.public.hi.min(above),
            },
            private: Window::NONE,
        })
    }
}

/// Root move `j`'s private window against the best exact score so far and
/// its move: an earlier move must be proved strictly lower, since a tie goes
/// to the earlier move, and a later one no higher.
const fn root_window(j: usize, best: Option<(usize, u32)>) -> Window {
    match best {
        Some((b, score)) => Window {
            lo: if j < b { score.saturating_sub(1) } else { score },
            hi: u32::MAX,
        },
        None => Window::EXACT,
    }
}

/// A probability-weighted sum of one end of a coordinate, in Bend's order.
struct Fold {
    public: Real,
    private: Real,
}

impl Fold {
    const ZERO: Self = Self {
        public: Real::ZERO,
        private: Real::ZERO,
    };

    fn add(self, public_p: Real, private_p: Real, public: u32, private: u32) -> Self {
        Self {
            public: self.public.add(public_p.mul(Real::from_u32(public))),
            private: self.private.add(private_p.mul(Real::from_u32(private))),
        }
    }
}

impl Search<'_> {
    /// `node.task` over boxes.
    fn bounded_node(&mut self, depth: u32, beliefs: (Span, Span), need: Need) -> Result<Boxed, Spent> {
        let (public, private) = beliefs;
        let Some(first) = public.of(&self.worlds).first().copied() else {
            return Ok(Boxed::exact(Value {
                public: 0,
                private: 0,
                reach: Reach::Settled,
            }));
        };
        if first.won.is_some() {
            return Ok(Boxed::exact(self.leaf(public, private, Reach::Settled)));
        }
        match (request(self.config, &first.state), depth.checked_sub(1)) {
            (Request::Choose(menu), Some(child)) => self.bounded_decision(menu.seat() == self.me, child, beliefs, &menu, need),
            (Request::Draw { .. }, _) => self.reload_leaf(public, private).map(Boxed::exact),
            (Request::Choose(_), None) | (Request::Finished | Request::Stuck, _) => {
                Ok(Boxed::exact(self.leaf(public, private, Reach::Cut)))
            }
        }
    }

    fn bounded_decision(&mut self, mine: bool, depth: u32, beliefs: (Span, Span), menu: &Menu, need: Need) -> Result<Boxed, Spent> {
        let (public, private) = beliefs;
        let key = {
            let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
            let key = hash(Kind::Decision, public_worlds, private_worlds);
            let stored = match self.tally.find(key, Kind::Decision, public_worlds, private_worlds) {
                Some(Stored::Box(entry)) => Some(entry),
                Some(Stored::Deal(_)) | None => None,
                #[cfg(feature = "f32")]
                Some(Stored::Decision(_)) => None,
            };
            if let Some(entry) = stored
                && entry.serves(depth, need)
            {
                self.tally.hit(0);
                return Ok(entry.boxed);
            }
            (key, stored.map_or(0, |entry| entry.lead))
        };
        let (key, lead) = key;
        let choices = push_choices(menu, &mut self.choices);
        let result = self.bounded_choose(mine, depth, beliefs, (choices, lead), need);
        self.choices.truncate(choices.start);
        let (value, leader) = result?;
        let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
        self.tally.keep(
            key,
            Kind::Decision,
            (public_worlds, private_worlds),
            Stored::Box(BoxEntry {
                boxed: value,
                depth,
                lead: leader,
            }),
        );
        Ok(value)
    }

    /// A decision's box and the move that led it: `lead` first, then the
    /// other moves in menu order, each searched for the need the moves before
    /// it leave, until the rest cannot matter.
    fn bounded_choose(
        &mut self,
        mine: bool,
        depth: u32,
        beliefs: (Span, Span),
        order: (Span, usize),
        need: Need,
    ) -> Result<(Boxed, usize), Spent> {
        let (choices, lead) = order;
        let moves: ArrayVec<Choice, MENU_CAPACITY> = choices.of(&self.choices).iter().copied().collect();
        let count = moves.len();
        let lead = if self.prune && lead < count { lead } else { 0 };
        let mark = self.boxes.len();
        let mut running = Running::START;
        for (j, choice) in lead_first(&moves, lead) {
            let child_need = if self.prune {
                match running.next(mine, j, need) {
                    Some(child_need) => child_need,
                    None => break,
                }
            } else {
                Need::EXACT
            };
            let boxed = match self.bounded_option(depth, beliefs, choice.index, child_need) {
                Ok(boxed) => boxed,
                Err(spent) => {
                    self.boxes.truncate(mark);
                    return Err(spent);
                }
            };
            running = running.add(j, &boxed);
            self.boxes.push(boxed);
        }
        // Back to menu order: the unsearched moves are any, and the lead moves back to its place.
        self.boxes.resize(mark.saturating_add(count), Boxed::ANY);
        let children = self.boxes.split_at_mut(mark).1;
        children.split_at_mut(lead.saturating_add(1)).0.rotate_left(1);
        #[expect(
            clippy::expect_used,
            reason = "a menu has a move, and the first lowest public high end is never beaten"
        )]
        let decided = decide_boxes(mine, children, 0).expect("a decision has a box");
        let leader = if mine {
            children
                .iter()
                .enumerate()
                .rev()
                .max_by_key(|(_, child)| child.private.lo)
                .map_or(0, |(j, _)| j)
        } else {
            running.lowest.min(count.saturating_sub(1))
        };
        self.boxes.truncate(mark);
        Ok((decided, leader))
    }

    fn bounded_option(&mut self, depth: u32, beliefs: (Span, Span), index: u32, need: Need) -> Result<Boxed, Spent> {
        let (public, private) = beliefs;
        let worlds = len_u64(public.len().saturating_add(private.len()));
        let spent = self.tally.nodes.saturating_add(worlds);
        if spent > self.budget {
            return Err(Spent);
        }
        self.tally.nodes = spent;
        let mark = self.worlds.len();
        let branches = self.outcomes(public, private, index);
        let result = self.bounded_branches(depth, branches, need);
        self.branches.truncate(branches.start);
        self.worlds.truncate(mark);
        result
    }

    /// The box of the branch sums. Its low ends are the sums of the low ends
    /// in Bend's order, its high ends of the high ends; with probabilities
    /// and values non-negative, f32 addition and multiplication round
    /// monotonically, so they bound the exact sum. Once the branches left,
    /// at any values, cannot move a needed coordinate across its window, they
    /// are skipped. A pruned sum that still misses its need (the slack of
    /// [`branch_window`] fell short) is searched again, exactly where it fell short.
    fn bounded_branches(&mut self, depth: u32, branches: Span, need: Need) -> Result<Boxed, Spent> {
        let mark = self.boxes.len();
        for at in 0..branches.len() {
            if self.prune && need.met(&self.branch_sum(branches, mark)) {
                break;
            }
            let child_need = if self.prune {
                self.branch_need(branches, mark, at, need)
            } else {
                Need::EXACT
            };
            let branch = branches.at(&self.branches, at);
            let child = match self.bounded_node(depth, (branch.public, branch.private), child_need) {
                Ok(child) => child,
                Err(spent) => {
                    self.boxes.truncate(mark);
                    return Err(spent);
                }
            };
            self.boxes.push(child);
        }
        let sum = self.branch_sum(branches, mark);
        self.boxes.truncate(mark);
        if need.met(&sum) {
            Ok(sum)
        } else {
            self.bounded_branches(depth, branches, need.tightened(&sum))
        }
    }

    /// The branch sums, with the branches searched so far on
    /// [`Search::boxes`] from `mark` and the rest unsearched.
    fn branch_sum(&self, branches: Span, mark: usize) -> Boxed {
        let searched = self.boxes.split_at(mark).1;
        let (mut lo, mut hi) = (Fold::ZERO, Fold::ZERO);
        let mut reach = Reach::Settled;
        let children = searched.iter().copied().chain(iter::repeat(Boxed::ANY));
        for (branch, child) in branches.of(&self.branches).iter().zip(children) {
            lo = lo.add(branch.public_p, branch.private_p, child.public.lo, child.private.lo);
            hi = hi.add(branch.public_p, branch.private_p, child.public.hi, child.private.hi);
            reach = reach.join(child.reach);
        }
        Boxed {
            public: Bounds {
                lo: lo.public.millionths(),
                hi: hi.public.millionths(),
            },
            private: Bounds {
                lo: lo.private.millionths(),
                hi: hi.private.millionths(),
            },
            reach,
        }
    }

    /// Branch `at` of `branches`' need: each needed coordinate's [`branch_window`].
    fn branch_need(&self, branches: Span, mark: usize, at: usize, need: Need) -> Need {
        let searched = self.boxes.split_at(mark).1;
        let window = |window: Window, term: fn(&super::Branch, &Boxed) -> (Real, u32, u32)| {
            if !window.needed() {
                return Window::NONE;
            }
            let children = searched.iter().copied().chain(iter::repeat(Boxed::ANY));
            let terms = branches
                .of(&self.branches)
                .iter()
                .zip(children)
                .map(|(branch, child)| term(branch, &child));
            let (lo, hi) = branch_window((window.lo, window.hi), terms, at);
            Window { lo, hi }
        };
        Need {
            public: window(need.public, |branch, child| (branch.public_p, child.public.lo, child.public.hi)),
            private: window(need.private, |branch, child| (branch.private_p, child.private.lo, child.private.hi)),
        }
    }

    /// Iterative deepening over boxes. A line scores its private low end, with
    /// its high end as `upper`. Pruned, each iteration searches the last
    /// one's best move first, then the rest in menu order, each against the
    /// best exact score so far; `chosen` is searched exactly.
    pub(super) fn bounded_root(&mut self, depth: u32, beliefs: (Span, Span), choices: Span, chosen: Option<u32>) -> Analysis {
        let static_lines = lines_static(choices.of(&self.choices), static_value(beliefs.1.of(&self.worlds), self.me));
        if depth == 0 {
            return analysed(static_lines, &Tally::default(), 0, false);
        }
        let mut completed = analysed(static_lines, &Tally::default(), 0, true);
        let mut lead = 0;
        for current in 0..depth {
            let Ok(lines) = self.bounded_lines(current, beliefs, choices, (lead, chosen)) else {
                return limited(completed, &self.tally);
            };
            if let Some((best, _)) = best_line(&lines) {
                lead = best;
            }
            completed = analysed(lines, &self.tally, current.saturating_add(1), false);
        }
        completed
    }

    /// One iteration's lines, in menu order; `order` is the move searched
    /// first and the chosen move's index.
    fn bounded_lines(&mut self, depth: u32, beliefs: (Span, Span), choices: Span, order: (usize, Option<u32>)) -> Result<Vec<Line>, Spent> {
        let (lead, chosen) = order;
        let moves: ArrayVec<Choice, MENU_CAPACITY> = choices.of(&self.choices).iter().copied().collect();
        let lead = if self.prune { lead } else { 0 };
        let mut found: ArrayVec<(usize, Boxed), MENU_CAPACITY> = ArrayVec::new();
        let mut best: Option<(usize, u32)> = None;
        for (j, choice) in lead_first(&moves, lead) {
            let window = if self.prune && Some(choice.index) != chosen {
                root_window(j, best)
            } else {
                Window::EXACT
            };
            let need = Need {
                public: Window::NONE,
                private: window,
            };
            let boxed = self.bounded_option(depth, beliefs, choice.index, need)?;
            let (lo, hi) = (boxed.private.lo, boxed.private.hi);
            if lo == hi && best.is_none_or(|(b, score)| lo > score || (lo == score && j < b)) {
                best = Some((j, lo));
            }
            found.push((j, boxed));
        }
        found.sort_unstable_by_key(|&(j, _)| j);
        Ok(moves
            .iter()
            .zip(found)
            .map(|(choice, (_, boxed))| Line {
                index: choice.index,
                r#move: choice.r#move,
                score: boxed.private.lo,
                upper: boxed.private.hi,
                reach: boxed.reach,
            })
            .collect())
    }
}

/// The moves with their menu index, `lead` first and the rest in menu order.
fn lead_first(moves: &[Choice], lead: usize) -> impl Iterator<Item = (usize, Choice)> {
    let order = moves.iter().copied().enumerate();
    order.clone().skip(lead).take(1).chain(order.filter(move |&(j, _)| j != lead))
}

#[cfg(test)]
mod tests {
    use super::{Bounds, BoxEntry, Boxed, Need, Running, TOP, Window, decide_boxes, root_window};
    use crate::num::{Real, branch_window};
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
        assert_eq!(decide_boxes(true, &children, 0), Some(exact(900_000, 900_000)), "max pub, max priv");
    }

    #[test]
    fn an_opponent_tied_on_public_keeps_the_first_childs_private() {
        let children = [exact(300_000, 100_000), exact(300_000, 800_000), exact(500_000, 0)];
        assert_eq!(decide_boxes(false, &children, 0), Some(exact(300_000, 100_000)), "first argmin pub");
    }

    #[test]
    fn an_opponent_child_that_may_be_lowest_widens_the_private_value() {
        let children = [
            boxed((300_000, 300_000), (100_000, 100_000), Reach::Settled),
            boxed((200_000, 400_000), (700_000, 700_000), Reach::Settled),
            boxed((300_000, 300_000), (900_000, 900_000), Reach::Settled),
        ];
        let expected = boxed((200_000, 300_000), (100_000, 700_000), Reach::Settled);
        assert_eq!(
            decide_boxes(false, &children, 0),
            Some(expected),
            "the third ties the first and is out"
        );
    }

    #[test]
    fn the_searchers_values_lie_between_the_highest_ends() {
        let children = [
            boxed((0, 0), (400_000, 600_000), Reach::Settled),
            boxed((0, 0), (500_000, 900_000), Reach::Cut),
            boxed((0, 0), (0, 300_000), Reach::Settled),
        ];
        let expected = boxed((0, 0), (500_000, 900_000), Reach::Cut);
        assert_eq!(decide_boxes(true, &children, 0), Some(expected), "the reach joins all");
    }

    #[test]
    fn a_pruned_child_counts_as_any_value_and_a_cut_reach() {
        let children = [exact(800_000, 900_000)];
        let expected = boxed((800_000, TOP), (900_000, TOP), Reach::Cut);
        assert_eq!(decide_boxes(true, &children, 1), Some(expected), "one pruned child");
        let lowest = boxed((0, 800_000), (0, TOP), Reach::Cut);
        assert_eq!(
            decide_boxes(false, &children, 1),
            Some(lowest),
            "an opponent's pruned child may be lower"
        );
    }

    #[test]
    fn the_searcher_stops_once_both_needed_values_fail_high() {
        let need = Need {
            public: Window { lo: 0, hi: 500_000 },
            private: Window { lo: 0, hi: 600_000 },
        };
        let after = |child: Boxed| Running::START.add(0, &child).next(true, 1, need);
        let raised = Need {
            public: Window::NONE,
            private: Window { lo: 400_000, hi: 600_000 },
        };
        assert_eq!(after(exact(700_000, 400_000)), Some(raised), "public is settled, private raised");
        assert_eq!(after(exact(700_000, 600_000)), None, "both settled");
    }

    #[test]
    fn an_opponent_needs_exact_public_values_below_the_lowest_while_private_matters() {
        let need = Need {
            public: Window { lo: 500_000, hi: TOP },
            private: Window::EXACT,
        };
        let running = Running::START.add(0, &exact(300_000, 100_000));
        let next = Need {
            public: Window { lo: 0, hi: 300_000 },
            private: Window::EXACT,
        };
        assert_eq!(
            running.next(false, 1, need),
            Some(next),
            "a lower public value changes the private value"
        );
        let public_only = Need {
            private: Window::NONE,
            ..need
        };
        assert_eq!(running.next(false, 1, public_only), None, "public is settled below 500000");
    }

    #[test]
    fn an_opponent_move_searched_late_but_earlier_in_the_menu_wins_a_tie() {
        let running = Running::START.add(2, &exact(300_000, 100_000));
        let need = Need {
            public: Window::NONE,
            private: Window::EXACT,
        };
        let window = |j| running.next(false, j, need).map(|next| next.public);
        assert_eq!(
            window(1),
            Some(Window { lo: 0, hi: 300_001 }),
            "an earlier move tied at 300000 is the first argmin"
        );
        assert_eq!(window(3), Some(Window { lo: 0, hi: 300_000 }), "a later one is not");
    }

    #[test]
    fn an_earlier_root_move_must_be_strictly_lower() {
        let best = Some((2, 700_000));
        assert_eq!(root_window(1, best), Window { lo: 699_999, hi: u32::MAX }, "earlier");
        assert_eq!(root_window(3, best), Window { lo: 700_000, hi: u32::MAX }, "later");
        assert!(
            !root_window(1, best).met(Bounds { lo: 600_000, hi: 700_000 }),
            "an earlier tie is not ruled out"
        );
        assert!(root_window(3, best).met(Bounds { lo: 600_000, hi: 700_000 }), "a later tie loses");
    }

    #[test]
    fn a_later_opponent_move_tied_on_public_loses_to_an_earlier_one_visited_after_it() {
        let need = Need {
            public: Window::NONE,
            private: Window::EXACT,
        };
        let visits = [(2, exact(300_000, 900_000)), (0, exact(500_000, 0)), (1, exact(300_000, 100_000))];
        let mut running = Running::START;
        let mut menu = [Boxed::ANY; 3];
        for (j, child) in visits {
            assert!(running.next(false, j, need).is_some(), "move {j} is searched");
            running = running.add(j, &child);
            if let Some(slot) = menu.get_mut(j) {
                *slot = child;
            }
        }
        assert_eq!(running.lowest, 1, "the first lowest in menu order leads next time");
        assert_eq!(
            decide_boxes(false, &menu, 0),
            Some(exact(300_000, 100_000)),
            "move 1's private value"
        );
    }

    #[test]
    fn a_box_serves_only_at_its_own_depth_and_when_it_meets_the_need() {
        let entry = BoxEntry {
            boxed: boxed((0, TOP), (200_000, 300_000), Reach::Cut),
            depth: 3,
            lead: 0,
        };
        let below = Need {
            public: Window::NONE,
            private: Window { lo: 300_000, hi: u32::MAX },
        };
        assert_eq!(
            [2, 3, 4].map(|depth| entry.serves(depth, below)),
            [false, true, false],
            "depths 2, 3, 4"
        );
        assert!(!entry.serves(3, Need::EXACT), "an inexact box for an exact need");
    }

    #[test]
    fn a_branch_outside_its_window_settles_the_sum() {
        let half = Real::ONE.div(Real::from_u32(2));
        let terms = [(half, 0, TOP), (half, 400_000, 400_000)];
        let (lo, hi) = branch_window((300_000, 600_000), terms.into_iter(), 0);
        let sum = |value: u32| half.mul(Real::from_u32(value)).add(half.mul(Real::from_u32(400_000))).millionths();
        assert!(sum(lo) <= 300_000 && sum(hi) >= 600_000, "{lo}: {}, {hi}: {}", sum(lo), sum(hi));
        assert!(lo > 150_000 && hi < 850_000, "the window is not empty: {lo}..{hi}");
    }

    #[test]
    fn the_low_and_high_sums_bracket_the_exact_sum() {
        let (p, q) = (Real::from_u32(1).div(Real::from_u32(3)), Real::from_u32(2).div(Real::from_u32(3)));
        let sum = |a: u32, b: u32| super::Fold::ZERO.add(p, p, a, a).add(q, q, b, b).public.millionths();
        let (lo, mid, hi) = (sum(100_000, 200_000), sum(150_000, 250_000), sum(200_000, 300_000));
        assert!(lo <= mid && mid <= hi, "{lo} <= {mid} <= {hi}");
    }
}
