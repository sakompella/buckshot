//! `simple/main.bend`: the machine's answers. Deals, rounds, distribution,
//! turns, shots and item effects.
//!
//! Each Bend def `f(state, ..) -> State` is a function on [`Run`], which
//! holds the state and the notes the answer has made so far.

use crate::branch::B;
use crate::domain::{
    AmountRule, Config, Direction, GameEvent, Gun, HealthRule, Item, Items, Load, Note, PHONE_CAP, Ring, Seat, Seats, Secret,
    Shell, Slot, Slots, prize,
};
use crate::items::{self, GrabOption};
use crate::rules::{self, JamResult};
use crate::state::{Batch, Deck, Decks, Grabs, Jam, Phase, SeatRecord, State, World};
use crate::{Answer, IdleOption, Notes, Stepped};

pub(crate) struct Run<'a> {
    pub config: &'a Config,
    pub state: State,
    pub notes: Notes,
}

impl Run<'_> {
    fn emit(&mut self, event: GameEvent) {
        self.notes.push(Note::Shown(event));
    }

    fn tell(&mut self, seat: Seat, secret: Secret) {
        self.notes.push(Note::Told { seat, secret });
    }

    fn set_phase(&mut self, phase: Phase) {
        self.state.phase = phase;
    }

    fn world(&mut self) -> &mut World {
        &mut self.state.world
    }

    fn deck(&self) -> Deck {
        self.state.world.decks.get(self.config.table())
    }

    fn set_deck(&mut self, deck: Deck) {
        let table = self.config.table();
        self.state.world.decks = self.state.world.decks.set(table, deck);
    }

    fn players_update(&mut self, seat: Seat, f: impl FnOnce(SeatRecord) -> SeatRecord) {
        let players = self.state.players;
        let record = players.get(seat).unwrap_or(SeatRecord::FRESH);
        self.state.players = players.set(seat, f(record));
    }

    fn into_stepped(self) -> Stepped {
        Stepped { state: self.state, notes: self.notes }
    }
}

/// `initial`.
fn initial(config: &Config) -> State {
    let table = config.table();
    State {
        world: World {
            before_round: true,
            round_index: 0,
            load_index: 0,
            first_sequence: false,
            round_health: 0,
            first_turn: Seat::Seat0,
            turn: None,
            direction: Direction::Clockwise,
            first_death: None,
            checking_first_death: false,
            item_amount: 0,
            sawed: false,
            gun: Gun::EMPTY,
            shown: Load { live: 0, blank: 0 },
            decks: Decks::full(),
        },
        players: Ring::fill(table, SeatRecord::FRESH),
        grabs: Grabs {
            distributing: false,
            grabbing: Ring::fill(table, false),
            holding: Ring::fill(table, None),
            granted: Ring::fill(table, 0),
            intake: Ring::fill(table, false),
        },
        phase: Phase::NeedFirst,
    }
}

/// `start`: the match from its first request point.
#[must_use]
pub fn start(config: &Config) -> Stepped {
    let mut run = Run { config, state: initial(config), notes: Notes::default() };
    first_begin(&mut run);
    run.into_stepped()
}

/// One answer: `answer.draw` for a Draw token, `answer.choice` for a Choice
/// token. A token at the other kind of point blocks, as in Bend.
#[must_use]
pub fn step(config: &Config, state: State, answer: Answer) -> Stepped {
    let mut run = Run { config, state, notes: Notes::default() };
    let r = &mut run;
    match (state.phase, answer) {
        (Phase::NeedFirst, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedFirst);
            let seat = config.table().seats().iter().nth(usize::try_from(value.get()).unwrap_or(usize::MAX)).unwrap_or(Seat::Seat0);
            first_chosen(r, seat);
        }
        (Phase::NeedHealth, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedHealth);
            health_chosen(r, value.get());
        }
        (Phase::NeedAmount, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedAmount);
            amount_chosen(r, value.get());
        }
        (Phase::NeedBatch, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedBatch);
            batch(r, value.get());
        }
        (Phase::NeedSwap { load, shells, i }, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedSwap);
            shuffle(r, load, shells.swap(i, value.get()), rules::predecessor(i));
        }
        (Phase::NeedTurnAmount { from, passing, winner }, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedTurnAmount);
            r.world().item_amount = value.get();
            turn_winner(r, from, passing, winner);
        }
        (Phase::NeedItem { seat, first, second, rest }, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedItem);
            let found = match value.get() {
                0 => Some(first),
                1 => Some(second),
                n => rest.nth(n.saturating_sub(2)),
            };
            grab_chosen(r, seat, found);
            grab_distribute(r, seat);
        }
        (Phase::NeedPhone { seat, owner, slot }, Answer::Draw(value)) => {
            branch!(B::SimpleMainAnswerDrawNeedPhone);
            item_clue(r, seat, owner, slot, value.get());
        }
        (Phase::Idle { .. } | Phase::Ended | Phase::Blocked { .. } | Phase::Stalled, Answer::Draw(_)) => {
            branch!(B::SimpleMainAnswerDrawAny);
            r.set_phase(Phase::Blocked { holder: None });
        }
        (Phase::Idle { seat }, Answer::Choice(legal)) => {
            branch!(B::SimpleMainAnswerChoiceIdle);
            pickup_selected(r, seat, Some(legal.option()));
        }
        (
            Phase::NeedFirst
            | Phase::NeedHealth
            | Phase::NeedAmount
            | Phase::NeedBatch
            | Phase::NeedSwap { .. }
            | Phase::Ended
            | Phase::Blocked { .. }
            | Phase::Stalled
            | Phase::NeedTurnAmount { .. }
            | Phase::NeedItem { .. }
            | Phase::NeedPhone { .. },
            Answer::Choice(_),
        ) => {
            branch!(B::SimpleMainAnswerChoiceAny);
            r.set_phase(Phase::Blocked { holder: None });
        }
    }
    run.into_stepped()
}

// Turns
// =====

fn pickup(r: &mut Run<'_>, seat: Seat) {
    r.emit(GameEvent::PickedUp { seat });
}

/// `give_turn`.
fn give_turn(r: &mut Run<'_>, seat: Seat) {
    r.set_phase(Phase::Idle { seat });
    r.emit(GameEvent::TurnGiven { seat });
}

/// `grant.step`: skips jammed seats, at most `rank` times.
fn grant_step(r: &mut Run<'_>, rank: u32, seat: Seat, result: JamResult) {
    let mut rank = rank;
    let mut seat = seat;
    let mut result = result;
    loop {
        match result {
            JamResult::Act { players } => {
                branch!(B::SimpleMainGrantStepAct);
                r.state.players = players;
                give_turn(r, seat);
                return;
            }
            JamResult::Lift { players } => {
                branch!(B::SimpleMainGrantStepLift);
                r.state.players = players;
                r.emit(GameEvent::JamLifted { seat });
                give_turn(r, seat);
                return;
            }
            JamResult::Skip { players } => match rank.checked_sub(1) {
                None => {
                    branch!(B::SimpleMainGrantStepZeroSkip);
                    r.state.players = players;
                    r.set_phase(Phase::Blocked { holder: None });
                    return;
                }
                Some(rest) => {
                    branch!(B::SimpleMainGrantStepSuccSkip);
                    let next = rules::next_turn(&players, r.state.world.direction, seat);
                    r.state.players = players;
                    r.world().turn = Some(next);
                    r.emit(GameEvent::TurnSkipped { seat });
                    rank = rest;
                    seat = next;
                    result = rules::jam(r.state.players, next);
                }
            },
        }
    }
}

/// `grant`.
fn grant(r: &mut Run<'_>, seat: Seat) {
    let rank = rules::jam_rank(&r.state.players);
    r.world().turn = Some(seat);
    let result = rules::jam(r.state.players, seat);
    grant_step(r, rank, seat, result);
}

// Loading
// =======

/// `shuffle`.
fn shuffle(r: &mut Run<'_>, load: Load, shells: Gun, i: u32) {
    match i {
        0 => {
            branch!(B::SimpleMainShuffleZero);
            let world = r.world();
            world.gun = shells;
            world.shown = load;
            let first = world.first_turn;
            r.emit(GameEvent::Loaded { load });
            grant(r, first);
        }
        1.. => {
            branch!(B::SimpleMainShuffleSucc);
            r.set_phase(Phase::NeedSwap { load, shells, i });
        }
    }
}

/// `batch` and `batch.found`.
fn batch(r: &mut Run<'_>, index: u32) {
    match r.deck().nth(index) {
        None => {
            branch!(B::SimpleMainBatchFoundNone);
            r.set_phase(Phase::Blocked { holder: None });
        }
        Some(Batch { load: sampled, .. }) => {
            branch!(B::SimpleMainBatchFoundSomeBatch);
            let load = rules::load_actual(rules::world_load_rule(r.config, &r.state.world), sampled);
            let shells = Gun::of_load(load);
            let deck = r.deck().remove(index);
            r.set_deck(deck);
            shuffle(r, load, shells, rules::predecessor(shells.len()));
        }
    }
}

/// `load.ready`.
fn load_ready(r: &mut Run<'_>, deck: Deck) {
    match deck.len() {
        0 => {
            branch!(B::SimpleMainLoadReadyNil);
            r.set_phase(Phase::Blocked { holder: None });
        }
        1 => {
            branch!(B::SimpleMainLoadReadyConsNil);
            batch(r, 0);
        }
        2.. => {
            branch!(B::SimpleMainLoadReadyConsCons);
            r.set_phase(Phase::NeedBatch);
        }
    }
}

/// `load.refill`.
fn load_refill(r: &mut Run<'_>, deck: Deck) {
    if deck.is_empty() {
        branch!(B::SimpleMainLoadRefillNil);
        r.world().decks = Decks::full();
        load_ready(r, r.deck());
    } else {
        branch!(B::SimpleMainLoadRefillAny);
        load_ready(r, deck);
    }
}

/// `load.begin`.
fn load_begin(r: &mut Run<'_>) {
    let world = r.world();
    world.load_index = rules::load_next(world.first_sequence, world.load_index);
    world.first_sequence = false;
    load_refill(r, r.deck());
}

// Item distribution
// =================

/// What the next distribution pass does (`Distribution`).
#[derive(Clone, Copy)]
enum Distribution {
    Taking { seat: Seat },
    Placing { seat: Seat, slot: Slot },
    Drawing,
    Loading,
    NoTaker,
}

/// `grab.check`.
fn grab_check(r: &mut Run<'_>) {
    let done = r.state.grabs.distributing && items::finished(r.config, &r.state);
    if done {
        branch!(B::SimpleMainGrabCheckDoneTrue);
        r.state.grabs.distributing = false;
        r.emit(GameEvent::DistributionDone);
    } else {
        branch!(B::SimpleMainGrabCheckDoneFalse);
    }
}

/// `grab.end_all`.
fn grab_end_all(r: &mut Run<'_>, seats: Seats) {
    for seat in seats.iter() {
        branch!(B::SimpleMainGrabEndAllCons);
        r.state.grabs = items::grabs_close(r.state.grabs, seat);
        r.emit(GameEvent::GrabbingEnded { seat });
    }
    branch!(B::SimpleMainGrabEndAllNil);
}

/// `grab.put`.
fn grab_put(r: &mut Run<'_>, seat: Seat, slot: Slot) {
    match items::seat_holding(&r.state.grabs, seat) {
        None => {
            branch!(B::SimpleMainGrabPutHeldNone);
            r.set_phase(Phase::Blocked { holder: None });
        }
        Some(item) => {
            branch!(B::SimpleMainGrabPutHeldSome);
            r.players_update(seat, |record| SeatRecord { slots: record.slots.put(slot, Some(item)), ..record });
            r.state.grabs = items::grabs_placed(r.state.grabs, seat);
            r.emit(GameEvent::Placed { seat, slot, item });
        }
    }
}

/// `grab.place`: a last placement ends the seat, checks completion, ends
/// the noneligible empty-handed grabbers, and checks completion again.
fn grab_place(r: &mut Run<'_>, seat: Seat, slot: Slot) {
    if items::placing_last(r.config, &r.state, seat) {
        branch!(B::SimpleMainGrabPlaceLastTrue);
        r.state.grabs = items::grabs_close(r.state.grabs, seat);
        r.emit(GameEvent::GrabbingEnded { seat });
        grab_check(r);
        let stalled = items::stalled_seats(r.config, &r.state, seat);
        grab_end_all(r, stalled);
        grab_check(r);
    } else {
        branch!(B::SimpleMainGrabPlaceLastFalse);
    }
    grab_put(r, seat, slot);
}

/// `grab.give`.
fn grab_give(r: &mut Run<'_>, seat: Seat, item: Item) {
    r.state.grabs = items::grabs_give(r.state.grabs, seat, item);
    r.emit(GameEvent::Granted { seat, item });
}

/// `grab.chosen`.
fn grab_chosen(r: &mut Run<'_>, seat: Seat, found: Option<Item>) {
    match found {
        Some(item) => {
            branch!(B::SimpleMainGrabChosenSome);
            grab_give(r, seat, item);
        }
        None => {
            branch!(B::SimpleMainGrabChosenNone);
            r.tell(seat, Secret::EmptyBriefcase);
        }
    }
}

/// `grab.pool`.
fn grab_pool(r: &mut Run<'_>, seat: Seat, pool: Items) {
    match pool.split_first() {
        None => {
            branch!(B::SimpleMainGrabPoolNil);
            grab_chosen(r, seat, None);
        }
        Some((first, rest)) => match rest.split_first() {
            None => {
                branch!(B::SimpleMainGrabPoolConsNil);
                grab_give(r, seat, first);
            }
            Some((second, rest)) => {
                branch!(B::SimpleMainGrabPoolConsCons);
                r.set_phase(Phase::NeedItem { seat, first, second, rest });
            }
        },
    }
}

/// `grab.takes`.
fn grab_takes(options: &[GrabOption]) -> bool {
    match options {
        [GrabOption::TakeItem] => {
            branch!(B::SimpleMainGrabTakesTakeItemConsNil);
            true
        }
        [] | [GrabOption::PutAt { .. }, ..] | [GrabOption::TakeItem, _, ..] => {
            branch!(B::SimpleMainGrabTakesAny);
            false
        }
    }
}

/// `seats.after`: the seats after `after` in socket order, cycling, `after` last.
fn seats_after(seats: Seats, after: Seat) -> Seats {
    let Some(at) = seats.iter().position(|seat| seat == after) else {
        return seats;
    };
    let mut cycled = Seats::EMPTY;
    for seat in seats.iter().skip(at.saturating_add(1)).chain(seats.iter().take(at.saturating_add(1))) {
        cycled.push(seat);
    }
    cycled
}

/// `grab.act` with `grab.act.own` and `grab.taker`.
fn grab_act(config: &Config, state: &State, after: Seat) -> Distribution {
    let own = items::grab_needs(config, state, after);
    if let Some(GrabOption::PutAt { slot }) = own.first() {
        branch!(B::SimpleMainGrabActOwnPutAtCons);
        return Distribution::Placing { seat: after, slot: *slot };
    }
    branch!(B::SimpleMainGrabActOwnAny);
    for seat in seats_after(config.table().seats(), after).iter() {
        branch!(B::SimpleMainGrabTakerCons);
        if grab_takes(&items::grab_needs(config, state, seat)) {
            return Distribution::Taking { seat };
        }
    }
    branch!(B::SimpleMainGrabTakerNil);
    Distribution::NoTaker
}

/// `grab.continue`: loading once the distribution is done and no item is
/// held, else the next grab move.
fn grab_continue(config: &Config, state: &State, after: Seat) -> Distribution {
    match (state.grabs.distributing, items::holders(&state.grabs)) {
        (false, false) => {
            branch!(B::SimpleMainGrabContinueReadyFalseFalse);
            Distribution::Loading
        }
        (true, _) | (false, true) => {
            branch!(B::SimpleMainGrabContinueReadyAny);
            grab_act(config, state, after)
        }
    }
}

/// `grab.next`: a take from a pool of two or more waits for the item draw.
fn grab_next(config: &Config, state: &State, pool: Items, after: Seat) -> Distribution {
    if pool.len() >= 2 {
        branch!(B::SimpleMainGrabNextConsCons);
        Distribution::Drawing
    } else {
        branch!(B::SimpleMainGrabNextAny);
        grab_continue(config, state, after)
    }
}

/// `grab.fuel`: never spent (each seat takes at most 9 times and places at most 8).
const fn grab_fuel(config: &Config) -> u32 {
    match config.table() {
        crate::Table::TwoSeats => 34,
        crate::Table::ThreeSeats => 51,
        crate::Table::FourSeats => 68,
    }
}

/// `grab.loop`.
fn grab_loop(r: &mut Run<'_>, fuel: u32, next: Distribution) {
    let mut fuel = fuel;
    let mut next = next;
    loop {
        match (fuel.checked_sub(1), next) {
            (_, Distribution::Drawing) => {
                branch!(B::SimpleMainGrabLoopDrawing);
                return;
            }
            (_, Distribution::Loading) => {
                branch!(B::SimpleMainGrabLoopLoading);
                load_begin(r);
                return;
            }
            (_, Distribution::NoTaker) => {
                branch!(B::SimpleMainGrabLoopNoTaker);
                r.set_phase(Phase::Stalled);
                return;
            }
            (None, Distribution::Taking { .. }) => {
                branch!(B::SimpleMainGrabLoopZeroTaking);
                r.set_phase(Phase::Stalled);
                return;
            }
            (None, Distribution::Placing { .. }) => {
                branch!(B::SimpleMainGrabLoopZeroPlacing);
                r.set_phase(Phase::Stalled);
                return;
            }
            (Some(rest), Distribution::Taking { seat }) => {
                branch!(B::SimpleMainGrabLoopSuccTaking);
                r.state.grabs = items::grabs_stop_intake(r.state.grabs, seat);
                let pool = items::pool(r.config, &r.state, seat);
                grab_pool(r, seat, pool);
                fuel = rest;
                next = grab_next(r.config, &r.state, pool, seat);
            }
            (Some(rest), Distribution::Placing { seat, slot }) => {
                branch!(B::SimpleMainGrabLoopSuccPlacing);
                grab_place(r, seat, slot);
                fuel = rest;
                next = grab_continue(r.config, &r.state, seat);
            }
        }
    }
}

/// `grab.distribute`.
fn grab_distribute(r: &mut Run<'_>, after: Seat) {
    let next = grab_continue(r.config, &r.state, after);
    grab_loop(r, grab_fuel(r.config), next);
}

/// `distribute.begin`.
fn distribute_begin(r: &mut Run<'_>, seats: Seats) {
    if seats.is_empty() {
        branch!(B::SimpleMainDistributeBeginNil);
        load_begin(r);
    } else {
        branch!(B::SimpleMainDistributeBeginCons);
        let mut grabs = items::grabs_open_all(seats, r.state.grabs);
        grabs.distributing = true;
        r.state.grabs = grabs;
        r.emit(GameEvent::GrabbingBegan { seats });
        grab_distribute(r, r.state.world.first_turn);
    }
}

// Rounds
// ======

/// `round.reset`.
fn round_reset(r: &mut Run<'_>) {
    let world = r.state.world;
    let health = world.round_health;
    let table = r.config.table();
    let mut players = r.state.players;
    for (seat, record) in r.state.players.entries() {
        players = players.set(seat, SeatRecord { health, jam: Jam::Free, cash: record.cash, slots: Slots::EMPTY });
    }
    let _ = table;
    r.state.players = players;
    let w = r.world();
    w.checking_first_death = true;
    w.direction = Direction::Clockwise;
    r.emit(GameEvent::RoundBegan { round: world.round_index, health, first: world.first_turn });
    let seats = items::begin_seats(r.config, &r.state, true, world.item_amount);
    distribute_begin(r, seats);
}

/// `amount.chosen`.
fn amount_chosen(r: &mut Run<'_>, value: u32) {
    r.world().item_amount = value;
    round_reset(r);
}

/// `amount.begin` with `amount.rule`.
fn amount_begin(r: &mut Run<'_>) {
    match rules::load_amount(rules::world_load_rule(r.config, &r.state.world)) {
        AmountRule::Random => {
            branch!(B::SimpleMainAmountRuleRandomAmount);
            r.set_phase(Phase::NeedAmount);
        }
        AmountRule::Fixed(amount) => {
            branch!(B::SimpleMainAmountRuleFixedAmount);
            amount_chosen(r, amount);
        }
    }
}

/// `health.chosen`.
fn health_chosen(r: &mut Run<'_>, value: u32) {
    r.world().round_health = value;
    amount_begin(r);
}

/// `health.begin` with `health.rule`.
fn health_begin(r: &mut Run<'_>) {
    match rules::round_health(&rules::world_rules(r.config, &r.state.world)) {
        HealthRule::Random => {
            branch!(B::SimpleMainHealthRuleRandomHealth);
            r.set_phase(Phase::NeedHealth);
        }
        HealthRule::Fixed(health) => {
            branch!(B::SimpleMainHealthRuleFixedHealth);
            health_chosen(r, health);
        }
    }
}

/// `first.chosen`.
fn first_chosen(r: &mut Run<'_>, seat: Seat) {
    let world = r.world();
    world.round_index = rules::round_next(world.before_round, world.round_index);
    world.before_round = false;
    world.first_turn = seat;
    world.first_sequence = true;
    health_begin(r);
}

/// `first.begin` with `first.override`.
fn first_begin(r: &mut Run<'_>) {
    match r.state.world.first_death {
        None => {
            branch!(B::SimpleMainFirstOverrideNone);
            r.set_phase(Phase::NeedFirst);
        }
        Some(seat) => {
            branch!(B::SimpleMainFirstOverrideSome);
            first_chosen(r, seat);
        }
    }
}

/// `win` with `win.final`.
fn win(r: &mut Run<'_>, seat: Seat) {
    let round = r.state.world.round_index;
    let prize = prize(round);
    // Bend's U32.add wraps.
    r.players_update(seat, |record| SeatRecord { cash: record.cash.wrapping_add(prize), ..record });
    r.emit(GameEvent::RoundWon { seat, prize });
    if round.saturating_add(1) == r.config.plan_length() {
        branch!(B::SimpleMainWinFinalTrue);
        r.set_phase(Phase::Ended);
        r.emit(GameEvent::MatchConcluded);
    } else {
        branch!(B::SimpleMainWinFinalFalse);
        first_begin(r);
    }
}

/// `reload.begin`.
fn reload_begin(r: &mut Run<'_>) {
    let seats = items::begin_seats(r.config, &r.state, false, r.state.world.item_amount);
    distribute_begin(r, seats);
}

/// `turn.winner` with `turn.recipient` and `turn.continue`.
fn turn_winner(r: &mut Run<'_>, shooter: Seat, passing: bool, winner: Option<Seat>) {
    match winner {
        Some(seat) => {
            branch!(B::SimpleMainTurnWinnerSome);
            win(r, seat);
        }
        None => {
            branch!(B::SimpleMainTurnWinnerNone);
            let next = rules::next_turn(&r.state.players, r.state.world.direction, shooter);
            let recipient = if passing {
                branch!(B::SimpleMainTurnRecipientTrue);
                next
            } else {
                branch!(B::SimpleMainTurnRecipientFalse);
                shooter
            };
            r.world().first_turn = recipient;
            if r.state.world.gun.is_empty() {
                branch!(B::SimpleMainTurnContinueNil);
                reload_begin(r);
            } else {
                branch!(B::SimpleMainTurnContinueCons);
                grant(r, recipient);
            }
        }
    }
}

/// `turn.packet` with `turn.live` and `turn.amount`: the winner is the
/// shot's winner check, or None after beer ejects the last shell.
fn turn_packet(r: &mut Run<'_>, shooter: Seat, passing: bool, winner: Option<Seat>) {
    let rule = rules::load_amount(rules::world_load_rule(r.config, &r.state.world));
    let live = items::amount_live(rule, r.state.grabs.distributing, items::reload_wanted(r.config, &r.state, winner));
    if live {
        branch!(B::SimpleMainTurnLiveTrue);
        r.set_phase(Phase::NeedTurnAmount { from: shooter, passing, winner });
        return;
    }
    branch!(B::SimpleMainTurnLiveFalse);
    match rule {
        AmountRule::Random => {
            branch!(B::SimpleMainTurnAmountRandomAmount);
        }
        AmountRule::Fixed(amount) => {
            branch!(B::SimpleMainTurnAmountFixedAmount);
            r.world().item_amount = amount;
        }
    }
    turn_winner(r, shooter, passing, winner);
}

/// `turn.end`.
fn turn_end(r: &mut Run<'_>, shooter: Seat, passing: bool) {
    let winner = rules::winner(&r.state.players);
    turn_packet(r, shooter, passing, winner);
}

/// `death` with `death.remember`.
fn death(r: &mut Run<'_>, target: Seat, shell: Shell, health: u32) {
    match (shell, health) {
        (Shell::Live, 0) => {
            branch!(B::SimpleMainDeathLiveZero);
            if r.state.world.checking_first_death {
                branch!(B::SimpleMainDeathRememberTrue);
                let world = r.world();
                world.first_death = Some(target);
                world.checking_first_death = false;
            } else {
                branch!(B::SimpleMainDeathRememberFalse);
            }
            r.emit(GameEvent::Died { seat: target });
        }
        (Shell::Live, 1..) | (Shell::Blank, _) => {
            branch!(B::SimpleMainDeathAny);
        }
    }
}

/// `shoot` with `shoot.gun` and `shoot.loaded`.
fn shoot(r: &mut Run<'_>, shooter: Seat, target: Seat) {
    let Some((shell, rest)) = r.state.world.gun.split_first() else {
        branch!(B::SimpleMainShootGunNil);
        r.set_phase(Phase::Blocked { holder: Some(shooter) });
        return;
    };
    branch!(B::SimpleMainShootGunCons);
    let damage = rules::captured(r.state.world.sawed);
    let before = r.state.players.get(target).map_or(100, |record| record.health);
    let health = rules::shot_health(shell, before, damage);
    r.players_update(target, |record| SeatRecord { health, ..record });
    let world = r.world();
    world.gun = rest;
    world.sawed = false;
    r.emit(GameEvent::Fired { shooter, target, shell, captured: damage, applied: rules::subtract(before, health), health });
    death(r, target, shell, health);
    turn_end(r, shooter, rules::shot_passes(shell, shooter == target));
}

// Items
// =====

/// `item.resume`.
fn item_resume(r: &mut Run<'_>, seat: Seat) {
    r.set_phase(Phase::Idle { seat });
}

/// `item.end`.
fn item_end(r: &mut Run<'_>, seat: Seat, ending: bool) {
    if ending {
        branch!(B::SimpleMainItemEndTrue);
        turn_packet(r, seat, true, None);
    } else {
        branch!(B::SimpleMainItemEndFalse);
        item_resume(r, seat);
    }
}

/// `item.shell` with `item.chamber`: the items that act on the chambered shell.
fn item_shell(r: &mut Run<'_>, seat: Seat, item: Item, ending: bool) {
    let Some((shell, rest)) = r.state.world.gun.split_first() else {
        branch!(B::SimpleMainItemShellNil);
        r.set_phase(Phase::Blocked { holder: None });
        return;
    };
    branch!(B::SimpleMainItemShellCons);
    match item {
        Item::Glass => {
            branch!(B::SimpleMainItemChamberGlass);
            r.tell(seat, Secret::Glimpse { shell });
        }
        Item::Beer => {
            branch!(B::SimpleMainItemChamberBeer);
            r.world().gun = rest;
            r.emit(GameEvent::Ejected { seat, shell });
        }
        Item::Inverter => {
            branch!(B::SimpleMainItemChamberInverter);
            r.world().gun = rest.push_front(items::invert(shell));
            r.emit(GameEvent::Inverted { seat });
        }
        Item::Saw | Item::Jammer | Item::Cigarettes | Item::Phone | Item::Adrenaline | Item::Remote => {
            branch!(B::SimpleMainItemChamberAny);
            r.set_phase(Phase::Blocked { holder: None });
            return;
        }
    }
    item_end(r, seat, ending);
}

/// `item.effect`, with `item.heal` and `item.tell`.
fn item_effect(r: &mut Run<'_>, seat: Seat, item: Item, ending: bool, phone: Option<Secret>) {
    match item {
        Item::Saw => {
            branch!(B::SimpleMainItemEffectSaw);
            r.world().sawed = true;
            item_resume(r, seat);
        }
        Item::Jammer => {
            branch!(B::SimpleMainItemEffectJammer);
        }
        Item::Cigarettes => {
            branch!(B::SimpleMainItemEffectCigarettes);
            let hp = items::seat_health(&r.state.players, seat);
            if hp < r.state.world.round_health {
                branch!(B::SimpleMainItemHealTrue);
                let hp = hp.saturating_add(1);
                r.players_update(seat, |record| SeatRecord { health: hp, ..record });
                r.emit(GameEvent::Healed { seat, health: hp });
            } else {
                branch!(B::SimpleMainItemHealFalse);
            }
            item_resume(r, seat);
        }
        Item::Phone => {
            branch!(B::SimpleMainItemEffectPhone);
            match phone {
                None => {
                    branch!(B::SimpleMainItemTellNone);
                    r.set_phase(Phase::Blocked { holder: None });
                }
                Some(secret) => {
                    branch!(B::SimpleMainItemTellSome);
                    r.tell(seat, secret);
                    item_resume(r, seat);
                }
            }
        }
        Item::Adrenaline => {
            branch!(B::SimpleMainItemEffectAdrenaline);
        }
        Item::Remote => {
            branch!(B::SimpleMainItemEffectRemote);
            let direction = items::flip(r.state.world.direction);
            r.world().direction = direction;
            r.emit(GameEvent::DirectionFlipped { direction });
            item_resume(r, seat);
        }
        Item::Glass => {
            branch!(B::SimpleMainItemEffectGlass);
            item_shell(r, seat, Item::Glass, ending);
        }
        Item::Beer => {
            branch!(B::SimpleMainItemEffectBeer);
            item_shell(r, seat, Item::Beer, ending);
        }
        Item::Inverter => {
            branch!(B::SimpleMainItemEffectInverter);
            item_shell(r, seat, Item::Inverter, ending);
        }
    }
}

/// `item.consume`.
fn item_consume(r: &mut Run<'_>, seat: Seat, owner: Seat, slot: Slot, item: Item, ending: bool, phone: Option<Secret>) {
    r.players_update(owner, |record| SeatRecord { slots: record.slots.put(slot, None), ..record });
    r.emit(GameEvent::Used { seat, owner, slot, item });
    item_effect(r, seat, item, ending, phone);
}

/// `item.clue` with `item.clue.found`: the phone announces the drawn index
/// plus one, capped at the seventh shell.
fn item_clue(r: &mut Run<'_>, seat: Seat, owner: Seat, slot: Slot, index: u32) {
    let position = index.saturating_add(1).min(PHONE_CAP);
    match r.state.world.gun.nth(rules::predecessor(position)) {
        None => {
            branch!(B::SimpleMainItemClueFoundNone);
            r.set_phase(Phase::Blocked { holder: Some(seat) });
        }
        Some(shell) => {
            branch!(B::SimpleMainItemClueFoundSome);
            item_consume(r, seat, owner, slot, Item::Phone, false, Some(Secret::Clue { position, shell }));
        }
    }
}

/// `item.use` with `item.route` and `item.phone`.
fn item_use(r: &mut Run<'_>, seat: Seat, owner: Seat, slot: Slot, item: Item) {
    let length = r.state.world.gun.len();
    let ending = items::ends_turn(item, length);
    match item {
        Item::Phone => {
            branch!(B::SimpleMainItemRoutePhone);
            match length {
                0..=2 => {
                    branch!(B::SimpleMainItemPhoneZeroOneTwo);
                    item_consume(r, seat, owner, slot, Item::Phone, false, Some(Secret::NoClue));
                }
                3 => {
                    branch!(B::SimpleMainItemPhoneThree);
                    item_clue(r, seat, owner, slot, 2);
                }
                4.. => {
                    branch!(B::SimpleMainItemPhoneAny);
                    r.set_phase(Phase::NeedPhone { seat, owner, slot });
                }
            }
        }
        Item::Saw | Item::Glass | Item::Jammer | Item::Cigarettes | Item::Beer | Item::Inverter | Item::Adrenaline | Item::Remote => {
            branch!(B::SimpleMainItemRouteAny);
            item_consume(r, seat, owner, slot, item, ending, None);
        }
    }
}

/// `jam.selected`.
fn jam_selected(r: &mut Run<'_>, seat: Seat, target: Seat) {
    r.players_update(target, |record| SeatRecord { jam: Jam::Jammed, ..record });
    r.emit(GameEvent::JamApplied { by: seat, target });
    item_resume(r, seat);
}

/// `pickup.selected`.
fn pickup_selected(r: &mut Run<'_>, seat: Seat, selected: Option<IdleOption>) {
    match selected {
        Some(IdleOption::ShootAt { target }) => {
            branch!(B::SimpleMainPickupSelectedSomeShootAt);
            pickup(r, seat);
            shoot(r, seat, target);
        }
        Some(IdleOption::UseSlot { slot, item }) => {
            branch!(B::SimpleMainPickupSelectedSomeUseSlot);
            item_use(r, seat, seat, slot, item);
        }
        Some(IdleOption::JamWith { slot, target }) => {
            branch!(B::SimpleMainPickupSelectedSomeJamWith);
            item_use(r, seat, seat, slot, Item::Jammer);
            jam_selected(r, seat, target);
        }
        Some(IdleOption::StealWith { adrenaline, owner, slot, item }) => {
            branch!(B::SimpleMainPickupSelectedSomeStealWith);
            item_use(r, seat, seat, adrenaline, Item::Adrenaline);
            item_use(r, seat, owner, slot, item);
        }
        Some(IdleOption::StealJamWith { adrenaline, owner, slot, target }) => {
            branch!(B::SimpleMainPickupSelectedSomeStealJamWith);
            item_use(r, seat, seat, adrenaline, Item::Adrenaline);
            item_use(r, seat, owner, slot, Item::Jammer);
            jam_selected(r, seat, target);
        }
        None => {
            branch!(B::SimpleMainPickupSelectedNone);
            r.set_phase(Phase::Blocked { holder: Some(seat) });
        }
    }
}
