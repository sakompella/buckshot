//! Bounded paranoid expectiminimax over a belief (`player/search.bend`,
//! ADR-0043). The searcher maximizes its private value; every opponent picks
//! the move that minimizes the public value. One fuel bounds every path, as
//! Bend's single `search` def does: each step spends a unit, and a step that
//! cannot run spends the iteration.
//!
//! The root's moves run one after another and must: each move's search
//! spends the fuel, the node budget and the memo the moves before it left,
//! so their results depend on that order.
//!
//! The search keeps its working data on stacks that only grow while a
//! subtree is searched and shrink back once it is done: the worlds of every
//! branch being searched, the branches, the moves of every open decision and
//! their scores. A subtree reads its part by [`Span`], so no node allocates.

use buckshot_rules::{Config, GameEvent, Label, Load, Move, Note, Notes, Request, Seat, Secret, Shell, draw_request, request, step_into};
use rayon::ThreadPool;

use crate::deal::{DealScratch, Sums, sampled};
use crate::evaluation::{known, sum};
use crate::machine::{answer_into, answer_reusing, round_won};
#[cfg(feature = "f32")]
use crate::memo::Entry;
use crate::memo::{Kind, Stored, Tally, hash};
#[cfg(feature = "f32")]
use crate::num::len_u64;
use crate::num::{Real, len_u32};
use crate::types::{Analysed, Analysis, Belief, Limits, Line, Memo, Pruning, Reach, Refusal, Reload, World};

mod bounded;

pub use bounded::{BoxEntry, KeyStats};

/// A run of a stack: `start..end`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Span {
    start: usize,
    end: usize,
}

impl Span {
    pub const fn from(start: usize, end: usize) -> Self {
        Self { start, end }
    }

    #[expect(
        clippy::indexing_slicing,
        reason = "`pushed` makes a span on the stack it reads, which shrinks only below the spans in use"
    )]
    pub fn of<T>(self, stack: &[T]) -> &[T] {
        &stack[self.start..self.end]
    }

    const fn is_empty(self) -> bool {
        self.start >= self.end
    }

    const fn len(self) -> usize {
        self.end.saturating_sub(self.start)
    }

    /// Item `at` of the span.
    #[expect(clippy::indexing_slicing, reason = "callers count `at` below the span's length")]
    fn at<T: Copy>(self, stack: &[T], at: usize) -> T {
        self.of(stack)[at]
    }
}

/// Pushes onto `stack` and returns the span of what `fill` pushed.
fn pushed<T>(stack: &mut Vec<T>, fill: impl FnOnce(&mut Vec<T>)) -> Span {
    let start = stack.len();
    fill(stack);
    Span::from(start, stack.len())
}

/// What in one world's notes depends on its hidden shells and deck.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Seen {
    Shell(Shell),
    Load(Load),
    Glimpse(Shell),
    Clue(u32, Shell),
}

/// `seen`: with `private` false only public events count; with true also my secrets.
fn seen(notes: &[Note], me: Seat, private: bool, into: &mut Vec<Seen>) {
    for note in notes {
        match *note {
            Note::Shown(GameEvent::Fired { shell, .. } | GameEvent::Ejected { shell, .. }) => into.push(Seen::Shell(shell)),
            Note::Shown(GameEvent::Loaded { load }) => into.push(Seen::Load(load)),
            Note::Told {
                seat,
                secret: Secret::Glimpse { shell },
            } if private && seat == me => into.push(Seen::Glimpse(shell)),
            Note::Told {
                seat,
                secret: Secret::Clue { position, shell },
            } if private && seat == me => into.push(Seen::Clue(position, shell)),
            Note::Shown(_) | Note::Told { .. } => {}
        }
    }
}

const NO_GROUP: usize = usize::MAX;

/// One world after a move, with what the public and the searcher observed
/// (spans of [`Buffers::seen`]) and the group it falls in.
#[derive(Clone, Copy, Debug)]
struct Out {
    world: World,
    public: Span,
    private: Span,
    group: usize,
}

/// Outs that observed the same, the first one's observation as the key.
#[derive(Clone, Copy, Debug)]
struct Group {
    key: Span,
    mass: Real,
}

/// The buffers one move's play writes: the notes of the answer and of a
/// phone draw after it, and what every out observed.
#[derive(Debug, Default)]
struct Buffers {
    notes: Notes,
    later: Notes,
    seen: Vec<Seen>,
    overflow: bool,
}

impl Buffers {
    /// An out with what the move's notes and the phone's draw's notes showed.
    fn out(&mut self, me: Seat, world: World) -> Out {
        let parts = [self.notes.as_slice(), self.later.as_slice()];
        let public = pushed(&mut self.seen, |into| {
            for part in parts {
                seen(part, me, false, into);
            }
        });
        let private = pushed(&mut self.seen, |into| {
            for part in parts {
                seen(part, me, true, into);
            }
        });
        Out {
            world,
            public,
            private,
            group: NO_GROUP,
        }
    }

    /// `settle`: a move ends at a choice, a draw or the end of the round;
    /// only the phone's draw is expanded. [`Buffers::notes`] hold the move's
    /// notes, none if no move was played.
    fn settle(&mut self, config: &Config, me: Seat, world: World, outs: &mut Vec<Out>) {
        if let Some((Label::PhoneIndex, range)) = draw_request(config, &world.state) {
            let count = range.extra.wrapping_add(2);
            let weight = world.weight.div(Real::from_u32(count));
            for k in (0..count).rev() {
                let out = if let Some(state) = answer_into(config, &world.state, k, &mut self.later) {
                    self.overflow |= self.later.truncated();
                    let won = round_won(self.later.as_slice());
                    self.out(me, World { state, weight, won })
                } else {
                    self.later.clear();
                    self.out(me, World { weight, ..world })
                };
                outs.push(out);
            }
        } else {
            self.later.clear();
            let out = self.out(me, world);
            outs.push(out);
        }
    }

    /// `play`: every world after move `index`.
    fn play(&mut self, config: &Config, me: Seat, worlds: &[World], index: u32, outs: &mut Vec<Out>) {
        outs.clear();
        let mut menu = None;
        for world in worlds {
            let answer = answer_reusing(config, &world.state, index, &mut menu);
            if let Some(state) = answer.map(|answer| step_into(config, world.state, answer, &mut self.notes)) {
                self.overflow |= self.notes.truncated();
                let won = round_won(self.notes.as_slice());
                let after = World {
                    state,
                    weight: world.weight,
                    won,
                };
                self.settle(config, me, after, outs);
            } else {
                self.notes.clear();
                self.settle(config, me, *world, outs);
            }
        }
    }
}

/// `group`: outs by observation (the private one with `private`), in order
/// of first appearance. With `within`, only outs whose public observation is
/// `within` take part; the rest get no group.
fn group(outs: &mut [Out], seen: &[Seen], private: bool, within: Option<Span>, groups: &mut Vec<Group>) {
    groups.clear();
    for out in outs {
        out.group = NO_GROUP;
        if within.is_some_and(|key| out.public.of(seen) != key.of(seen)) {
            continue;
        }
        let key = if private { out.private } else { out.public };
        let observed = key.of(seen);
        if let Some((at, found)) = groups.iter_mut().enumerate().find(|(_, group)| group.key.of(seen) == observed) {
            found.mass = found.mass.add(out.world.weight);
            out.group = at;
        } else {
            out.group = groups.len();
            groups.push(Group {
                key,
                mass: out.world.weight,
            });
        }
    }
}

/// `worlds.of`: the outs of group `at`, normalized by its mass.
fn worlds_of(outs: &[Out], at: usize, mass: Real, into: &mut Vec<World>) -> Span {
    pushed(into, |into| {
        into.extend(outs.iter().filter(|out| out.group == at).map(|out| World {
            weight: out.world.weight.div(mass),
            ..out.world
        }));
    })
}

/// One observation after a move: the public belief, one private belief inside it, and their probabilities.
#[derive(Clone, Copy, Debug)]
struct Branch {
    public: Span,
    private: Span,
    public_p: Real,
    private_p: Real,
}

/// `millionths` of a static sum.
fn static_value(worlds: &[World], me: Seat) -> u32 {
    sum(worlds, me, known(worlds)).millionths()
}

/// A belief with no private worlds copies the public value.
fn static_private(worlds: &[World], me: Seat, public: u32) -> u32 {
    if worlds.is_empty() { public } else { static_value(worlds, me) }
}

#[derive(Clone, Copy, Debug)]
struct Choice {
    index: u32,
    r#move: Move,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Value {
    public: u32,
    private: u32,
    reach: Reach,
}

#[cfg(feature = "f32")]
#[derive(Clone, Copy, Debug)]
struct Scored {
    choice: Choice,
    value: Value,
}

/// The node budget ran out (or an answer's notes outgrew their buffer, which
/// [`Buffers::overflow`] records).
#[derive(Clone, Copy, Debug)]
struct Spent;

/// A search's result; scores are a span of [`Search::scored`].
#[cfg(feature = "f32")]
#[derive(Clone, Copy, Debug)]
enum Searched {
    Value(Value),
    #[cfg(feature = "f32")]
    Scores(Span),
    Spent,
}

/// A decision's value goes into the memo under the beliefs' hash, with the nodes spent before it began.
#[cfg(feature = "f32")]
#[derive(Clone, Copy, Debug)]
struct Keep {
    hash: u64,
    start: u64,
}

/// A decision's choices are a span of [`Search::choices`].
#[cfg(feature = "f32")]
enum Task {
    Known(Searched),
    Decide {
        mine: bool,
        keep: Option<Keep>,
        depth: u32,
        choices: Span,
    },
}

fn push_choices(menu: &buckshot_rules::Menu, into: &mut Vec<Choice>) -> Span {
    pushed(into, |into| {
        into.extend(menu.moves().enumerate().map(|(index, legal)| Choice {
            index: len_u32(index),
            r#move: legal.to_move(),
        }));
    })
}

/// `decide`: the searcher takes its best private value, and the public
/// believes it takes its best public one; an opponent takes the lowest
/// public value. Ties keep the first move.
#[cfg(feature = "f32")]
fn decide(mine: bool, scored: &[Scored]) -> Searched {
    let Some((first, rest)) = scored.split_first() else {
        return Searched::Spent;
    };
    let chosen = rest.iter().fold(first, |best, s| {
        let better = if mine {
            s.value.private > best.value.private
        } else {
            s.value.public < best.value.public
        };
        if better { s } else { best }
    });
    let public_best = rest.iter().fold(first.value.public, |best, s| best.max(s.value.public));
    let reach = scored.iter().fold(Reach::Settled, |reach, s| reach.join(s.value.reach));
    Searched::Value(Value {
        public: if mine { public_best } else { chosen.value.public },
        private: chosen.value.private,
        reach,
    })
}

/// One move's play, reused by every move: the outs under each belief and their groups.
#[derive(Debug, Default)]
struct Scratch {
    buffers: Buffers,
    public_outs: Vec<Out>,
    private_outs: Vec<Out>,
    groups: Vec<Group>,
    private_groups: Vec<Group>,
}

/// A search whose answers' notes outgrew their buffer, whose values are therefore not Bend's.
struct Search<'a> {
    config: &'a Config,
    me: Seat,
    budget: u64,
    #[cfg(feature = "f32")]
    fuel: u64,
    reload: Reload,
    memo: Memo,
    pool: Option<&'a ThreadPool>,
    tally: Tally,
    worlds: Vec<World>,
    branches: Vec<Branch>,
    choices: Vec<Choice>,
    #[cfg(feature = "f32")]
    scored: Vec<Scored>,
    scratch: Scratch,
    deal: DealScratch,
    boxes: Vec<bounded::Boxed>,
    stats: Option<KeyStats>,
    prune: bool,
}

impl Search<'_> {
    /// `outcomes`: the branches after move `index`, from normalized beliefs,
    /// pushed onto [`Search::branches`] with their worlds on [`Search::worlds`].
    fn outcomes(&mut self, public: Span, private: Span, index: u32) -> Span {
        let Scratch {
            buffers,
            public_outs,
            private_outs,
            groups,
            private_groups,
        } = &mut self.scratch;
        buffers.seen.clear();
        buffers.play(self.config, self.me, private.of(&self.worlds), index, private_outs);
        buffers.play(self.config, self.me, public.of(&self.worlds), index, public_outs);
        let seen = buffers.seen.as_slice();
        group(public_outs, seen, false, None, groups);
        let start = self.branches.len();
        for (at, public_group) in groups.iter().enumerate() {
            let public_worlds = worlds_of(public_outs, at, public_group.mass, &mut self.worlds);
            group(private_outs, seen, true, Some(public_group.key), private_groups);
            if private_groups.is_empty() {
                self.branches.push(Branch {
                    public: public_worlds,
                    private: Span::default(),
                    public_p: public_group.mass,
                    private_p: Real::ZERO,
                });
            } else {
                let mut public_p = public_group.mass;
                for (at_private, private_group) in private_groups.iter().enumerate() {
                    let private_worlds = worlds_of(private_outs, at_private, private_group.mass, &mut self.worlds);
                    self.branches.push(Branch {
                        public: public_worlds,
                        private: private_worlds,
                        public_p,
                        private_p: private_group.mass,
                    });
                    public_p = Real::ZERO;
                }
            }
        }
        Span::from(start, self.branches.len())
    }

    fn leaf(&self, public: Span, private: Span, reach: Reach) -> Value {
        let value = static_value(public.of(&self.worlds), self.me);
        Value {
            public: value,
            private: static_private(private.of(&self.worlds), self.me, value),
            reach,
        }
    }

    /// `node.expected`: with no private worlds the private value is the public one.
    fn expected(sums: Sums, private: Span) -> Value {
        let value = sums.public.millionths();
        Value {
            public: value,
            private: if private.is_empty() { value } else { sums.private.millionths() },
            reach: Reach::Reloads,
        }
    }

    /// `node.reload`: a deal leaf's value depends on its beliefs alone, so the memo keeps it whatever the depth.
    fn reload_leaf(&mut self, public: Span, private: Span) -> Result<Value, Spent> {
        let count = match self.reload {
            Reload::Static => return Ok(self.leaf(public, private, Reach::Reloads)),
            Reload::Sampled { count } => count,
        };
        let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
        let key = match self.memo {
            Memo::Off => None,
            Memo::Charged | Memo::Free => {
                let key = hash(Kind::Deal, public_worlds, private_worlds);
                if let Some(Stored::Deal(sums)) = self.tally.find(key, Kind::Deal, public_worlds, private_worlds) {
                    self.tally.deal_hit();
                    return Ok(Self::expected(sums, private));
                }
                Some(key)
            }
        };
        let Some(sums) = sampled(
            self.config,
            (public_worlds, private_worlds),
            self.me,
            count,
            self.pool,
            &mut self.deal,
        ) else {
            self.scratch.buffers.overflow = true;
            return Err(Spent);
        };
        if let Some(key) = key {
            self.tally
                .keep(key, Kind::Deal, (public_worlds, private_worlds), Stored::Deal(sums));
        }
        Ok(Self::expected(sums, private))
    }
}

/// Bend's search, in the `f32` build only.
#[cfg(feature = "f32")]
impl Search<'_> {
    /// `node.choose`: an entry serves when its value holds at this depth and,
    /// unless reuse is free, the nodes its search spent still fit the budget.
    fn choose(&mut self, mine: bool, depth: u32, public: Span, private: Span, menu: &buckshot_rules::Menu) -> Task {
        let keep = match self.memo {
            Memo::Off => None,
            Memo::Charged | Memo::Free => {
                let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
                let key = hash(Kind::Decision, public_worlds, private_worlds);
                if let Some(Stored::Decision(entry)) = self.tally.find(key, Kind::Decision, public_worlds, private_worlds) {
                    let charge = entry.charge(self.memo);
                    if entry.serves(depth) && self.tally.nodes.saturating_add(charge) <= self.budget {
                        self.tally.hit(charge);
                        return Task::Known(Searched::Value(Value {
                            public: entry.public,
                            private: entry.private,
                            reach: entry.reach,
                        }));
                    }
                }
                Some(Keep {
                    hash: key,
                    start: self.tally.nodes,
                })
            }
        };
        Task::Decide {
            mine,
            keep,
            depth,
            choices: push_choices(menu, &mut self.choices),
        }
    }

    /// `node.task`: a choice with depth left is a decision; a won round, a
    /// reload or no depth left is evaluated. A move that won the round is a
    /// leaf even when the next round already began and waits on a choice.
    fn node_task(&mut self, depth: u32, public: Span, private: Span) -> Task {
        let Some(first) = public.of(&self.worlds).first().copied() else {
            return Task::Known(Searched::Value(Value {
                public: 0,
                private: 0,
                reach: Reach::Settled,
            }));
        };
        if first.won.is_some() {
            return Task::Known(Searched::Value(self.leaf(public, private, Reach::Settled)));
        }
        match (request(self.config, &first.state), depth.checked_sub(1)) {
            (Request::Choose(menu), Some(child)) => self.choose(menu.seat() == self.me, child, public, private, &menu),
            (Request::Draw { .. }, _) => Task::Known(self.reload_leaf(public, private).map_or(Searched::Spent, Searched::Value)),
            (Request::Choose(_), None) | (Request::Finished | Request::Stuck, _) => {
                Task::Known(Searched::Value(self.leaf(public, private, Reach::Cut)))
            }
        }
    }

    fn node(&mut self, fuel: u64, depth: u32, public: Span, private: Span) -> Searched {
        let Some(fuel) = fuel.checked_sub(1) else {
            return Searched::Spent;
        };
        match self.node_task(depth, public, private) {
            Task::Known(result) => {
                if fuel == 0 {
                    Searched::Spent
                } else {
                    result
                }
            }
            Task::Decide {
                mine,
                keep,
                depth,
                choices,
            } => {
                let result = self.decide(fuel, mine, keep, depth, (public, private), choices);
                self.choices.truncate(choices.start);
                result
            }
        }
    }

    fn decide(&mut self, fuel: u64, mine: bool, keep: Option<Keep>, depth: u32, beliefs: (Span, Span), choices: Span) -> Searched {
        let (public, private) = beliefs;
        let Some(fuel) = fuel.checked_sub(1) else {
            return Searched::Spent;
        };
        let result = match self.moves(fuel, depth, public, private, choices) {
            Searched::Scores(scores) => {
                let decided = decide(mine, scores.of(&self.scored));
                self.scored.truncate(scores.start);
                decided
            }
            other @ (Searched::Value(_) | Searched::Spent) => other,
        };
        if let (Some(Keep { hash, start }), Searched::Value(value)) = (keep, result) {
            let entry = Entry {
                public: value.public,
                private: value.private,
                reach: value.reach,
                depth,
                cost: self.tally.nodes.saturating_sub(start),
            };
            let (public_worlds, private_worlds) = (public.of(&self.worlds), private.of(&self.worlds));
            self.tally
                .keep(hash, Kind::Decision, (public_worlds, private_worlds), Stored::Decision(entry));
        }
        result
    }

    /// The moves of a decision in menu order, scored onto [`Search::scored`].
    /// A move costs one node per world it is played in; a move the budget
    /// cannot pay for spends the iteration.
    fn moves(&mut self, fuel: u64, depth: u32, public: Span, private: Span, choices: Span) -> Searched {
        let mut fuel = fuel;
        let start = self.scored.len();
        for at in 0..choices.len() {
            let choice = choices.at(&self.choices, at);
            let after = fuel.checked_sub(1);
            let result = match after {
                Some(after) => self.option(after, depth, public, private, choice.index),
                None => Searched::Spent,
            };
            let (Some(next), Searched::Value(value)) = (after.and_then(|after| after.checked_sub(1)), result) else {
                self.scored.truncate(start);
                return Searched::Spent;
            };
            self.scored.push(Scored { choice, value });
            fuel = next;
        }
        if fuel == 0 {
            self.scored.truncate(start);
            Searched::Spent
        } else {
            Searched::Scores(Span::from(start, self.scored.len()))
        }
    }

    fn option(&mut self, fuel: u64, depth: u32, public: Span, private: Span, index: u32) -> Searched {
        let worlds = len_u64(public.len().saturating_add(private.len()));
        let spent = self.tally.nodes.saturating_add(worlds);
        if spent > self.budget {
            return Searched::Spent;
        }
        self.tally.nodes = spent;
        let mark = self.worlds.len();
        let branches = self.outcomes(public, private, index);
        let result = self.branches(fuel, depth, branches);
        self.branches.truncate(branches.start);
        self.worlds.truncate(mark);
        result
    }

    /// The branch sums: probability times value under each belief, and the branches' reach.
    fn branches(&mut self, fuel: u64, depth: u32, branches: Span) -> Searched {
        let mut fuel = fuel;
        let mut public = Real::ZERO;
        let mut private = Real::ZERO;
        let mut reach = Reach::Settled;
        for at in 0..branches.len() {
            let branch = branches.at(&self.branches, at);
            let Some(after) = fuel.checked_sub(1) else {
                return Searched::Spent;
            };
            let result = self.node(after, depth, branch.public, branch.private);
            let (Some(next), Searched::Value(value)) = (after.checked_sub(1), result) else {
                return Searched::Spent;
            };
            public = public.add(branch.public_p.mul(Real::from_u32(value.public)));
            private = private.add(branch.private_p.mul(Real::from_u32(value.private)));
            reach = reach.join(value.reach);
            fuel = next;
        }
        if fuel == 0 {
            Searched::Spent
        } else {
            Searched::Value(Value {
                public: public.millionths(),
                private: private.millionths(),
                reach,
            })
        }
    }

    fn lines(&self, scores: Span) -> Vec<Line> {
        scores
            .of(&self.scored)
            .iter()
            .map(|s| Line {
                index: s.choice.index,
                r#move: s.choice.r#move,
                score: s.value.private,
                upper: s.value.private,
                reach: s.value.reach,
            })
            .collect()
    }

    /// `root` with `deepen`: iterative deepening, the tally running on across
    /// depths. Only a finished iteration replaces the completed analysis.
    fn root(&mut self, depth: u32, public: Span, private: Span, choices: Span) -> Analysis {
        let static_lines = lines_static(choices.of(&self.choices), static_value(private.of(&self.worlds), self.me));
        if depth == 0 {
            return analysed(static_lines, &Tally::default(), 0, false);
        }
        let mut completed = analysed(static_lines, &Tally::default(), 0, true);
        let mut current = 0u32;
        let mut steps = depth;
        loop {
            let scores = match self.moves(self.fuel, current, public, private, choices) {
                Searched::Scores(scores) => scores,
                Searched::Value(_) | Searched::Spent => return limited(completed, &self.tally),
            };
            current = current.saturating_add(1);
            let done = analysed(self.lines(scores), &self.tally, current, false);
            self.scored.truncate(scores.start);
            let Some(rest) = steps.checked_sub(1).filter(|rest| *rest > 0) else {
                return done;
            };
            steps = rest;
            completed = done;
        }
    }
}

/// The first line with the highest score, and its place.
fn best_line(lines: &[Line]) -> Option<(usize, &Line)> {
    lines.iter().enumerate().fold(None, |best, (j, line)| match best {
        Some((_, top)) if line.score <= top.score => best,
        _ => Some((j, line)),
    })
}

fn analysed(lines: Vec<Line>, tally: &Tally, depth: u32, limited: bool) -> Analysis {
    let Some((_, best)) = best_line(&lines) else {
        return Err(Refusal::NoLegalMove { nodes: tally.nodes });
    };
    let (index, score) = (best.index, best.score);
    Ok(Analysed {
        lines,
        best: index,
        score,
        nodes: tally.nodes,
        depth,
        limited,
        cached: tally.cached,
    })
}

fn limited(completed: Analysis, tally: &Tally) -> Analysis {
    match completed {
        Ok(done) => Ok(Analysed {
            nodes: tally.nodes,
            limited: true,
            cached: tally.cached,
            ..done
        }),
        Err(Refusal::NoLegalMove { .. }) => Err(Refusal::NoLegalMove { nodes: tally.nodes }),
        Err(refusal) => Err(refusal),
    }
}

/// Every move scores the static value of the belief, with no move played.
fn lines_static(choices: &[Choice], score: u32) -> Vec<Line> {
    choices
        .iter()
        .map(|choice| Line {
            index: choice.index,
            r#move: choice.r#move,
            score,
            upper: score,
            reach: Reach::Cut,
        })
        .collect()
}

/// Which search runs over a belief.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Mode {
    /// Bend's search, bit for bit.
    #[cfg(feature = "f32")]
    Compat,
    /// The box search, pruned or not, the chosen move (a menu index) searched
    /// exactly, gathering the decision keys of its deepest iteration with `stats`.
    Bounded {
        pruning: Pruning,
        chosen: Option<u32>,
        stats: bool,
    },
}

/// A built belief's analysis under `mode`, with its key stats if asked for.
pub(crate) fn run(
    config: &Config,
    belief: &Belief,
    limits: Limits,
    leaves: (Reload, Memo),
    pool: Option<&ThreadPool>,
    mode: Mode,
) -> (Analysis, Option<KeyStats>) {
    let (reload, memo) = leaves;
    let Some(first) = belief.public.first() else {
        return (Err(Refusal::NoPublicBelief), None);
    };
    let menu = match request(config, &first.state) {
        Request::Choose(menu) => menu,
        Request::Draw { .. } | Request::Finished | Request::Stuck => return (Err(Refusal::NotAChoice), None),
    };
    if menu.seat() != belief.me {
        return (Err(Refusal::NotMyTurn), None);
    }
    // `fuel`: Bend's Nat cannot overflow; a budget whose fuel outgrows u64 is refused.
    #[cfg(feature = "f32")]
    let fuel = match mode {
        #[cfg(feature = "f32")]
        Mode::Compat => match limits.budget.checked_mul(8).and_then(|fuel| fuel.checked_add(64)) {
            Some(fuel) => fuel,
            None => return (Err(Refusal::Fuel), None),
        },
        Mode::Bounded { .. } => 0,
    };
    let mut search = Search {
        config,
        me: belief.me,
        budget: limits.budget,
        #[cfg(feature = "f32")]
        fuel,
        reload,
        memo,
        pool,
        tally: Tally::default(),
        worlds: Vec::new(),
        branches: Vec::new(),
        choices: Vec::new(),
        #[cfg(feature = "f32")]
        scored: Vec::new(),
        scratch: Scratch::default(),
        deal: DealScratch::default(),
        boxes: Vec::new(),
        stats: matches!(mode, Mode::Bounded { stats: true, .. }).then(KeyStats::default),
        prune: matches!(mode, Mode::Bounded { pruning: Pruning::On, .. }),
    };
    let public = pushed(&mut search.worlds, |into| into.extend_from_slice(&belief.public));
    let private = pushed(&mut search.worlds, |into| into.extend_from_slice(&belief.private));
    let choices = push_choices(&menu, &mut search.choices);
    let analysis = match mode {
        #[cfg(feature = "f32")]
        Mode::Compat => search.root(limits.depth, public, private, choices),
        Mode::Bounded { chosen, .. } => search.bounded_root(limits.depth, (public, private), choices, chosen),
    };
    if search.scratch.buffers.overflow {
        return (Err(Refusal::NotesOverflow { nodes: search.tally.nodes }), search.stats);
    }
    (analysis, search.stats)
}

#[cfg(test)]
pub(crate) mod tests {
    use buckshot_rules::{AmountRule, Config, EnumMap, HealthRule, ItemRule, LoadRule, RoundRules, RuleError, ShellRule, Table};

    /// Two seats at 2 health, a one-shell live load and no items.
    pub(crate) fn config() -> Result<Config, RuleError> {
        let load = LoadRule {
            shells: ShellRule::AllLive { live: 1 },
            items: AmountRule::Fixed(0),
        };
        let round = RoundRules {
            health: HealthRule::Fixed(2),
            loads: [load; 4],
            items: EnumMap::from_fn(|_| ItemRule::OFF),
        };
        Config::new(Table::TwoSeats, &[round, round, round])
    }

    /// Bend's search, in the `f32` build only.
    #[cfg(feature = "f32")]
    mod compat {
        use buckshot_rules::{Config, Deck, Event, Move, Request, RuleError, SeatRecord, State, initial, request, step_event};

        use super::config;
        use crate::num::Real;
        use crate::search::{Mode, run};
        use crate::types::{Analysis, Belief, Limits, Memo, Reach, Reload, World};

        /// The compat analysis of a belief built by hand.
        fn analyse_belief(config: &Config, belief: &Belief, limits: Limits, reload: Reload, memo: Memo) -> Analysis {
            run(config, belief, limits, (reload, memo), None, Mode::Compat).0
        }

        /// The first choice of the match, each seat at 1 health and one batch left in the deck.
        fn at_one_health(config: &Config) -> Result<State, RuleError> {
            let mut state = initial(config);
            for _ in 0..64_u32 {
                if matches!(request(config, &state), Request::Choose(_)) {
                    break;
                }
                state = step_event(config, state, Event::Draw(0))?.state;
            }
            let players = state.players.entries().fold(state.players, |all, (seat, record)| {
                all.set(seat, SeatRecord { health: 1, ..record })
            });
            let world = buckshot_rules::World {
                decks: state
                    .world
                    .decks
                    .set(config.table(), Deck::full(config.table()).filtered(|id| id == 0)),
                ..state.world
            };
            Ok(State { world, players, ..state })
        }

        /// The scores of shooting the opponent and shooting myself, and whether
        /// the opponent's shot begins the next round at a choice.
        type Shots = (bool, Option<(u32, Reach)>, Option<(u32, Reach)>);

        fn shots() -> Result<Shots, RuleError> {
            let config = config()?;
            let state = at_one_health(&config)?;
            let Request::Choose(menu) = request(&config, &state) else {
                return Err(RuleError::Config("the fixture should start at a choice"));
            };
            let me = menu.seat();
            let shoot = menu
                .moves()
                .position(|legal| matches!(legal.to_move(), Move::Shoot { target } if target != me));
            let index = shoot.and_then(|at| u32::try_from(at).ok()).unwrap_or(u32::MAX);
            let won = step_event(&config, state, Event::Choose(index))?;
            let next_round = matches!(request(&config, &won.state), Request::Choose(_));
            let world = World {
                state,
                weight: Real::ONE,
                won: None,
            };
            let belief = Belief {
                public: vec![world],
                private: vec![world],
                me,
                round: 0,
            };
            let Ok(done) = analyse_belief(&config, &belief, Limits { depth: 4, budget: 20_000 }, Reload::Static, Memo::Off) else {
                return Err(RuleError::Config("the fixture should analyse"));
            };
            let at = |own: bool| {
                done.lines
                    .iter()
                    .find(|line| matches!(line.r#move, Move::Shoot { target } if (target == me) == own))
                    .map(|line| (line.score, line.reach))
            };
            Ok((next_round, at(false), at(true)))
        }

        /// Shooting the opponent wins the round and begins the next one in the
        /// same step; the search must score the won round, not the next round's start.
        // Bug: the round-edge winner (rust-search stage 1, P1.1) scored the next round's start.
        #[test]
        fn a_won_round_is_settled_when_the_next_round_begins_at_once() {
            let expected = (true, Some((1_000_000, Reach::Settled)), Some((0, Reach::Settled)));
            assert_eq!(shots(), Ok(expected), "(next round at a choice, opponent shot, own shot)");
        }
    }
}
