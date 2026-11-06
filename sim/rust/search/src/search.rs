//! Bounded paranoid expectiminimax over a belief (`player/search.bend`,
//! ADR-0043). The searcher maximizes its private value; every opponent picks
//! the move that minimizes the public value. One fuel bounds every path, as
//! Bend's single `search` def does: each step spends a unit, and a step that
//! cannot run spends the iteration.

use buckshot_rules::{Config, GameEvent, Label, Load, Move, Note, Request, Seat, Secret, Shell, Table, request};

use crate::belief::build;
use crate::deal::{Sums, sampled};
use crate::evaluation::{known, sum};
use crate::machine::{answer_notes, round_won};
use crate::memo::{Entry, Key, Kind, Stored, Tally};
use crate::num::{F32, len_u32};
use crate::position::Position;
use crate::types::{Analysed, Analysis, Belief, Line, Memo, Reach, Reload, World};

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

/// One world after a move, with what the public and the searcher observed.
#[derive(Clone, Debug)]
struct Out {
    world: World,
    public: Vec<Seen>,
    private: Vec<Seen>,
}

struct Group {
    key: Vec<Seen>,
    outs: Vec<Out>,
    mass: F32,
}

/// `group`: outs by observation, in order of first appearance.
fn group(outs: impl IntoIterator<Item = Out>, private: bool) -> Vec<Group> {
    let mut groups: Vec<Group> = Vec::new();
    for out in outs {
        let key = if private { &out.private } else { &out.public };
        match groups.iter_mut().find(|group| group.key == *key) {
            Some(found) => {
                found.mass = found.mass.add(out.world.weight);
                found.outs.push(out);
            }
            None => groups.push(Group {
                key: key.clone(),
                mass: out.world.weight,
                outs: vec![out],
            }),
        }
    }
    groups
}

/// `worlds.of`: the outs, normalized by their mass.
fn worlds_of(outs: &[Out], mass: F32) -> Vec<World> {
    outs.iter()
        .map(|out| World {
            weight: out.world.weight.div(mass),
            ..out.world
        })
        .collect()
}

/// One observation after a move: the public belief, one private belief inside it, and their probabilities.
struct Branch {
    public: Vec<World>,
    private: Vec<World>,
    public_p: F32,
    private_p: F32,
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

#[derive(Clone, Copy, Debug)]
struct Scored {
    choice: Choice,
    value: Value,
}

enum Searched {
    Value(Value),
    Scores(Vec<Scored>),
    Spent,
}

/// A decision's value goes into the memo under `key`, with the nodes spent before it began.
struct Keep {
    key: Key,
    start: u64,
}

enum Task {
    Known(Searched),
    Decide {
        mine: bool,
        keep: Option<Keep>,
        depth: u32,
        choices: Vec<Choice>,
    },
}

fn choices(menu: &buckshot_rules::Menu) -> Vec<Choice> {
    menu.moves()
        .enumerate()
        .map(|(index, legal)| Choice {
            index: len_u32(index),
            r#move: legal.to_move(),
        })
        .collect()
}

/// `decide`: the searcher takes its best private value, and the public
/// believes it takes its best public one; an opponent takes the lowest
/// public value. Ties keep the first move.
fn decide(mine: bool, result: Searched) -> Searched {
    match result {
        Searched::Scores(scored) => {
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
        Searched::Value(_) | Searched::Spent => result,
    }
}

struct Search<'a> {
    config: &'a Config,
    me: Seat,
    budget: u64,
    reload: Reload,
    memo: Memo,
    tally: Tally,
}

impl Search<'_> {
    fn out(&self, world: World, notes: &[Note], later: &[Note]) -> Out {
        let mut public = Vec::new();
        let mut private = Vec::new();
        for part in [notes, later] {
            seen(part, self.me, false, &mut public);
            seen(part, self.me, true, &mut private);
        }
        Out { world, public, private }
    }

    /// `settle`: a move ends at a choice, a draw or the end of the round; only the phone's draw is expanded.
    fn settle(&self, world: World, notes: &[Note], outs: &mut Vec<Out>) {
        match request(self.config, &world.state) {
            Request::Draw {
                label: Label::PhoneIndex,
                range,
            } => {
                let count = range.extra.wrapping_add(2);
                let weight = world.weight.div(F32::from_u32(count));
                for k in (0..count).rev() {
                    let out = match answer_notes(self.config, world.state, k) {
                        Some((state, later)) => self.out(
                            World {
                                state,
                                weight,
                                won: round_won(later.as_slice()),
                            },
                            notes,
                            later.as_slice(),
                        ),
                        None => self.out(World { weight, ..world }, notes, &[]),
                    };
                    outs.push(out);
                }
            }
            Request::Draw { .. } | Request::Choose(_) | Request::Finished | Request::Stuck => outs.push(self.out(world, notes, &[])),
        }
    }

    /// `play`: every world after move `index`.
    fn play(&self, worlds: &[World], index: u32) -> Vec<Out> {
        let mut outs = Vec::with_capacity(worlds.len());
        for world in worlds {
            match answer_notes(self.config, world.state, index) {
                Some((state, notes)) => self.settle(
                    World {
                        state,
                        weight: world.weight,
                        won: round_won(notes.as_slice()),
                    },
                    notes.as_slice(),
                    &mut outs,
                ),
                None => self.settle(*world, &[], &mut outs),
            }
        }
        outs
    }

    /// `outcomes`: the observations after move `index`, from normalized beliefs.
    fn outcomes(&self, public: &[World], private: &[World], index: u32) -> Vec<Branch> {
        let private_outs = self.play(private, index);
        let mut branches = Vec::new();
        for public_group in group(self.play(public, index), false) {
            let public_worlds = worlds_of(&public_group.outs, public_group.mass);
            let matching = private_outs.iter().filter(|out| out.public == public_group.key).cloned();
            let private_groups = group(matching, true);
            if private_groups.is_empty() {
                branches.push(Branch {
                    public: public_worlds,
                    private: Vec::new(),
                    public_p: public_group.mass,
                    private_p: F32::ZERO,
                });
            } else {
                let mut public_p = public_group.mass;
                for private_group in private_groups {
                    branches.push(Branch {
                        public: public_worlds.clone(),
                        private: worlds_of(&private_group.outs, private_group.mass),
                        public_p,
                        private_p: private_group.mass,
                    });
                    public_p = F32::ZERO;
                }
            }
        }
        branches
    }

    fn leaf(&self, public: &[World], private: &[World], reach: Reach) -> Searched {
        let value = static_value(public, self.me);
        Searched::Value(Value {
            public: value,
            private: static_private(private, self.me, value),
            reach,
        })
    }

    /// `node.expected`: with no private worlds the private value is the public one.
    fn expected(sums: Sums, private: &[World]) -> Searched {
        let value = sums.public.millionths();
        Searched::Value(Value {
            public: value,
            private: if private.is_empty() { value } else { sums.private.millionths() },
            reach: Reach::Reloads,
        })
    }

    /// `node.reload`: a deal leaf's value depends on its beliefs alone, so the memo keeps it whatever the depth.
    fn reload_leaf(&mut self, public: &[World], private: &[World]) -> Searched {
        let count = match self.reload {
            Reload::Static => return self.leaf(public, private, Reach::Reloads),
            Reload::Sampled { count } => count,
        };
        let deal = |search: &Self| sampled(search.config, public, private, search.me, count);
        match self.memo {
            Memo::Off => Self::expected(deal(self), private),
            Memo::Charged | Memo::Free => {
                let key = Key::new(Kind::Deal, public, private);
                if let Some(Stored::Deal(sums)) = self.tally.find(&key) {
                    self.tally.deal_hit();
                    return Self::expected(sums, private);
                }
                let sums = deal(self);
                self.tally.keep(key, Stored::Deal(sums));
                Self::expected(sums, private)
            }
        }
    }

    /// `node.choose`: an entry serves when its value holds at this depth and,
    /// unless reuse is free, the nodes its search spent still fit the budget.
    fn choose(&mut self, mine: bool, depth: u32, public: &[World], private: &[World], choices: Vec<Choice>) -> Task {
        let keep = match self.memo {
            Memo::Off => None,
            Memo::Charged | Memo::Free => {
                let key = Key::new(Kind::Decision, public, private);
                if let Some(Stored::Decision(entry)) = self.tally.find(&key) {
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
                    key,
                    start: self.tally.nodes,
                })
            }
        };
        Task::Decide {
            mine,
            keep,
            depth,
            choices,
        }
    }

    /// `node.task`: a choice with depth left is a decision; a won round, a
    /// reload or no depth left is evaluated. A move that won the round is a
    /// leaf even when the next round already began and waits on a choice.
    fn node_task(&mut self, depth: u32, public: &[World], private: &[World]) -> Task {
        let Some(first) = public.first() else {
            return Task::Known(Searched::Value(Value {
                public: 0,
                private: 0,
                reach: Reach::Settled,
            }));
        };
        if first.won.is_some() {
            return Task::Known(self.leaf(public, private, Reach::Settled));
        }
        match (request(self.config, &first.state), depth.checked_sub(1)) {
            (Request::Choose(menu), Some(child)) => self.choose(menu.seat() == self.me, child, public, private, choices(&menu)),
            (Request::Draw { .. }, _) => Task::Known(self.reload_leaf(public, private)),
            (Request::Choose(_), None) | (Request::Finished | Request::Stuck, _) => Task::Known(self.leaf(public, private, Reach::Cut)),
        }
    }

    fn node(&mut self, fuel: u64, depth: u32, public: &[World], private: &[World]) -> Searched {
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
            } => self.decide(fuel, mine, keep, depth, (public, private), &choices),
        }
    }

    fn decide(
        &mut self,
        fuel: u64,
        mine: bool,
        keep: Option<Keep>,
        depth: u32,
        beliefs: (&[World], &[World]),
        choices: &[Choice],
    ) -> Searched {
        let (public, private) = beliefs;
        let Some(fuel) = fuel.checked_sub(1) else {
            return Searched::Spent;
        };
        let result = decide(mine, self.moves(fuel, depth, public, private, choices));
        if let (Some(Keep { key, start }), Searched::Value(value)) = (keep, &result) {
            let entry = Entry {
                public: value.public,
                private: value.private,
                reach: value.reach,
                depth,
                cost: self.tally.nodes.saturating_sub(start),
            };
            self.tally.keep(key, Stored::Decision(entry));
        }
        result
    }

    /// The moves of a decision in menu order. A move costs one node per world
    /// it is played in; a move the budget cannot pay for spends the iteration.
    fn moves(&mut self, fuel: u64, depth: u32, public: &[World], private: &[World], choices: &[Choice]) -> Searched {
        let mut fuel = fuel;
        let mut scored = Vec::with_capacity(choices.len());
        for choice in choices {
            let Some(after) = fuel.checked_sub(1) else {
                return Searched::Spent;
            };
            let result = self.option(after, depth, public, private, choice.index);
            let (Some(next), Searched::Value(value)) = (after.checked_sub(1), result) else {
                return Searched::Spent;
            };
            scored.push(Scored { choice: *choice, value });
            fuel = next;
        }
        if fuel == 0 { Searched::Spent } else { Searched::Scores(scored) }
    }

    fn option(&mut self, fuel: u64, depth: u32, public: &[World], private: &[World], index: u32) -> Searched {
        let worlds = u64::try_from(public.len().saturating_add(private.len())).unwrap_or(u64::MAX);
        let spent = self.tally.nodes.saturating_add(worlds);
        if spent > self.budget {
            return Searched::Spent;
        }
        self.tally.nodes = spent;
        let branches = self.outcomes(public, private, index);
        self.branches(fuel, depth, &branches)
    }

    /// The branch sums: probability times value under each belief, and the branches' reach.
    fn branches(&mut self, fuel: u64, depth: u32, branches: &[Branch]) -> Searched {
        let mut fuel = fuel;
        let mut public = F32::ZERO;
        let mut private = F32::ZERO;
        let mut reach = Reach::Settled;
        for branch in branches {
            let Some(after) = fuel.checked_sub(1) else {
                return Searched::Spent;
            };
            let result = self.node(after, depth, &branch.public, &branch.private);
            let (Some(next), Searched::Value(value)) = (after.checked_sub(1), result) else {
                return Searched::Spent;
            };
            public = public.add(branch.public_p.mul(F32::from_u32(value.public)));
            private = private.add(branch.private_p.mul(F32::from_u32(value.private)));
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
}

fn invalid(reason: &'static str, nodes: u64) -> Analysis {
    Analysis::Invalid { reason, nodes }
}

fn analysed(lines: Vec<Line>, tally: &Tally, depth: u32, limited: bool) -> Analysis {
    let Some((first, rest)) = lines.split_first() else {
        return invalid("no legal move", tally.nodes);
    };
    let best = rest
        .iter()
        .fold(first, |best, line| if line.score > best.score { line } else { best });
    let (index, score) = (best.index, best.score);
    Analysis::Analysed(Analysed {
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
        Analysis::Analysed(done) => Analysis::Analysed(Analysed {
            nodes: tally.nodes,
            limited: true,
            cached: tally.cached,
            ..done
        }),
        Analysis::Invalid { reason, .. } => invalid(reason, tally.nodes),
    }
}

fn lines_of(scored: &[Scored]) -> Vec<Line> {
    scored
        .iter()
        .map(|s| Line {
            index: s.choice.index,
            r#move: s.choice.r#move,
            score: s.value.private,
            reach: s.value.reach,
        })
        .collect()
}

/// Every move scores the static value of the belief, with no move played.
fn lines_static(choices: &[Choice], score: u32) -> Vec<Line> {
    choices
        .iter()
        .map(|choice| Line {
            index: choice.index,
            r#move: choice.r#move,
            score,
            reach: Reach::Cut,
        })
        .collect()
}

/// `root` with `deepen`: iterative deepening, the tally running on across
/// depths. Only a finished iteration replaces the completed analysis.
fn root(search: &mut Search<'_>, depth: u32, public: &[World], private: &[World], choices: &[Choice]) -> Analysis {
    let static_lines = lines_static(choices, static_value(private, search.me));
    if depth == 0 {
        return analysed(static_lines, &Tally::default(), 0, false);
    }
    let fuel = search.budget.saturating_mul(8).saturating_add(64);
    let mut completed = analysed(static_lines, &Tally::default(), 0, true);
    let mut attempt = search.moves(fuel, 0, public, private, choices);
    let mut current = 1u32;
    let mut steps = depth.saturating_sub(1);
    loop {
        let scored = match attempt {
            Searched::Scores(scored) => scored,
            Searched::Value(_) | Searched::Spent => return limited(completed, &search.tally),
        };
        let done = analysed(lines_of(&scored), &search.tally, current, false);
        let Some(rest) = steps.checked_sub(1) else {
            return done;
        };
        steps = rest;
        completed = done;
        attempt = search.moves(fuel, current, public, private, choices);
        current = current.saturating_add(1);
    }
}

/// `root.belief`: the analysis of a built belief.
#[must_use]
pub fn analyse_belief(config: &Config, belief: &Belief, depth: u32, budget: u64, reload: Reload, memo: Memo) -> Analysis {
    let Some(first) = belief.public.first() else {
        return invalid("public log has no consistent shell/deck belief", 0);
    };
    let menu = match request(config, &first.state) {
        Request::Choose(menu) => menu,
        Request::Draw { .. } | Request::Finished | Request::Stuck => return invalid("the position is not a choice", 0),
    };
    if menu.seat() != belief.me {
        return invalid("it is not this player's turn", 0);
    }
    let mut search = Search {
        config,
        me: belief.me,
        budget,
        reload,
        memo,
        tally: Tally::default(),
    };
    root(&mut search, depth, &belief.public, &belief.private, &choices(&menu))
}

/// `analyse`: the position's analysis to `depth` decisions within `budget` nodes.
#[must_use]
pub fn analyse(position: &Position, depth: u32, budget: u64, reload: Reload, memo: Memo) -> Analysis {
    match reload {
        Reload::Static => {}
        Reload::Sampled { count: 0 } => return invalid("the sampled leaf needs at least one deal", 0),
        Reload::Sampled { .. } => {
            if position.config.table() != Table::TwoSeats {
                return invalid("a leaf that deals the reload takes two seats only", 0);
            }
        }
    }
    match build(position) {
        Ok(belief) => analyse_belief(&position.config, &belief, depth, budget, reload, memo),
        Err(reason) => invalid(reason, 0),
    }
}

#[cfg(test)]
mod tests {
    use buckshot_rules::{
        AmountRule, Config, Deck, Event, HealthRule, ItemRule, LoadRule, Move, Request, RoundRules, RuleError, SeatRecord, ShellRule,
        State, Table, initial, request, step_event,
    };

    use super::analyse_belief;
    use crate::num::F32;
    use crate::types::{Analysis, Belief, Memo, Reach, Reload, World};

    /// Two seats at 2 health, a one-shell live load and no items.
    fn config() -> Result<Config, RuleError> {
        let load = LoadRule {
            shells: ShellRule::AllLive { live: 1 },
            items: AmountRule::Fixed(0),
        };
        let off = ItemRule {
            enabled: false,
            per_player: 0,
            on_table: 0,
        };
        let round = RoundRules {
            health: HealthRule::Fixed(2),
            loads: [load; 4],
            items: [off; 9],
        };
        Config::new(Table::TwoSeats, &[round, round, round])
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
            decks: state.world.decks.set(config.table(), Deck::of_ids(config.table(), [0])),
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
            weight: F32::ONE,
            won: None,
        };
        let belief = Belief {
            public: vec![world],
            private: vec![world],
            me,
            round: 0,
        };
        let Analysis::Analysed(done) = analyse_belief(&config, &belief, 4, 20_000, Reload::Static, Memo::Off) else {
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

    /// P1.1: shooting the opponent wins the round and begins the next one in the
    /// same step; the search must score the won round, not the next round's start.
    #[test]
    fn a_won_round_is_settled_when_the_next_round_begins_at_once() {
        let expected = (true, Some((1_000_000, Reach::Settled)), Some((0, Reach::Settled)));
        assert_eq!(shots(), Ok(expected), "(next round at a choice, opponent shot, own shot)");
    }
}
