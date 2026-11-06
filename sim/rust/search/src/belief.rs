//! The searcher's belief from its position (`player/belief.bend`): every
//! shell order and remaining deck consistent with the log, as weighted worlds.

use buckshot_rules::{
    Config, Deck, FirstDeathCheck, GameEvent, Gun, Jam, Load, LoadRule, Phase, Players, SeatRecord, Secret, Shell, Slots, State, Table,
    World as Records, initial, load_actual, load_next, predecessor, world_load_rule,
};

use crate::num::F32;
use crate::position::{Board, Counter, GunView, Heard, Mode, Position, RoundView, SeatView, Stage};
use crate::types::{Belief, World};

const fn invert(shell: Shell) -> Shell {
    match shell {
        Shell::Live => Shell::Blank,
        Shell::Blank => Shell::Live,
    }
}

fn prepend(shell: Shell, orders: Vec<Gun>) -> Vec<Gun> {
    orders.into_iter().map(|order| order.push_front(shell)).collect()
}

/// `orders`: every order of `live` live and `blank` blank shells, live first.
/// `fuel` is the shells still to place.
fn orders(fuel: u32, live: u32, blank: u32) -> Vec<Gun> {
    match (fuel.checked_sub(1), live.checked_sub(1), blank.checked_sub(1)) {
        (None, None, None) => vec![Gun::EMPTY],
        (Some(fuel), None, Some(blank)) => prepend(Shell::Blank, orders(fuel, 0, blank)),
        (Some(fuel), Some(live), None) => prepend(Shell::Live, orders(fuel, live, 0)),
        (Some(less), Some(fewer_live), Some(fewer_blank)) => {
            let mut all = prepend(Shell::Live, orders(less, fewer_live, blank));
            all.extend(prepend(Shell::Blank, orders(less, live, fewer_blank)));
            all
        }
        (None, _, _) | (Some(_), None, None) => Vec::new(),
    }
}

fn orders_load(load: Load) -> Vec<Gun> {
    orders(load.live.wrapping_add(load.blank), load.live, load.blank)
}

/// `filter.clue`: whether the order's shell at `position` is `shell`.
pub fn clue_holds(order: Gun, position: u32, shell: Shell) -> bool {
    order.nth(position) == Some(shell)
}

fn orders_clue(orders: Vec<Gun>, position: u32, shell: Shell) -> Vec<Gun> {
    orders.into_iter().filter(|order| clue_holds(*order, position, shell)).collect()
}

fn orders_pop(orders: Vec<Gun>, shell: Shell) -> Vec<Gun> {
    orders
        .into_iter()
        .filter_map(|order| order.split_first().and_then(|(first, tail)| (first == shell).then_some(tail)))
        .collect()
}

fn orders_invert(orders: Vec<Gun>) -> Vec<Gun> {
    orders
        .into_iter()
        .filter_map(|order| order.split_first().map(|(first, tail)| tail.push_front(invert(first))))
        .collect()
}

fn orders_event(event: GameEvent, current: Vec<Gun>) -> Vec<Gun> {
    match event {
        GameEvent::Loaded { load } => orders_load(load),
        GameEvent::Fired { shell, .. } | GameEvent::Ejected { shell, .. } => orders_pop(current, shell),
        GameEvent::Inverted { .. } => orders_invert(current),
        GameEvent::RoundBegan { .. }
        | GameEvent::GrabbingBegan { .. }
        | GameEvent::Granted { .. }
        | GameEvent::Placed { .. }
        | GameEvent::GrabbingEnded { .. }
        | GameEvent::DistributionDone
        | GameEvent::TurnSkipped { .. }
        | GameEvent::JamLifted { .. }
        | GameEvent::TurnGiven { .. }
        | GameEvent::PickedUp { .. }
        | GameEvent::Died { .. }
        | GameEvent::Used { .. }
        | GameEvent::Healed { .. }
        | GameEvent::JamApplied { .. }
        | GameEvent::DirectionFlipped { .. }
        | GameEvent::RoundWon { .. }
        | GameEvent::MatchConcluded => current,
    }
}

fn orders_secret(secret: Secret, current: Vec<Gun>) -> Vec<Gun> {
    match secret {
        Secret::Glimpse { shell } => orders_clue(current, 0, shell),
        Secret::Clue { position, shell } => orders_clue(current, predecessor(position), shell),
        Secret::NoClue | Secret::EmptyBriefcase => current,
    }
}

/// `orders.log`, from no orders; with `private` the searcher's secrets count.
fn orders_log(log: &[Heard], private: bool) -> Vec<Gun> {
    log.iter().fold(Vec::new(), |current, heard| match *heard {
        Heard::Witnessed(event) => orders_event(event, current),
        Heard::Learned(secret) if private => orders_secret(secret, current),
        Heard::Learned(_) => current,
    })
}

const fn seat_of(view: SeatView) -> SeatRecord {
    match view.counter {
        Counter::Unjammed { health } => SeatRecord {
            health,
            jam: Jam::Free,
            cash: view.cash,
            slots: view.slots,
        },
        Counter::Jammed => SeatRecord {
            health: 0,
            jam: Jam::Jammed,
            cash: view.cash,
            slots: view.slots,
        },
    }
}

fn update(players: Players, seat: buckshot_rules::Seat, change: impl FnOnce(SeatRecord) -> SeatRecord) -> Players {
    match players.get(seat) {
        Some(record) => players.set(seat, change(record)),
        None => players,
    }
}

/// `players.event`: only counters are replayed.
fn players_event(event: GameEvent, players: Players) -> Players {
    match event {
        GameEvent::RoundBegan { health, .. } => players.entries().fold(players, |all, (seat, record)| {
            all.set(
                seat,
                SeatRecord {
                    health,
                    jam: Jam::Free,
                    cash: record.cash,
                    slots: Slots::EMPTY,
                },
            )
        }),
        GameEvent::Fired { target, health, .. } => update(players, target, |record| SeatRecord { health, ..record }),
        GameEvent::Healed { seat, health } => update(players, seat, |record| SeatRecord { health, ..record }),
        GameEvent::JamApplied { target, .. } => update(players, target, |record| SeatRecord {
            jam: Jam::Jammed,
            ..record
        }),
        GameEvent::TurnSkipped { seat } => update(players, seat, |record| SeatRecord {
            jam: Jam::JammedSkipped,
            ..record
        }),
        GameEvent::JamLifted { seat } => update(players, seat, |record| SeatRecord { jam: Jam::Free, ..record }),
        GameEvent::GrabbingBegan { .. }
        | GameEvent::Granted { .. }
        | GameEvent::Placed { .. }
        | GameEvent::GrabbingEnded { .. }
        | GameEvent::DistributionDone
        | GameEvent::Loaded { .. }
        | GameEvent::TurnGiven { .. }
        | GameEvent::PickedUp { .. }
        | GameEvent::Died { .. }
        | GameEvent::Used { .. }
        | GameEvent::Ejected { .. }
        | GameEvent::Inverted { .. }
        | GameEvent::DirectionFlipped { .. }
        | GameEvent::RoundWon { .. }
        | GameEvent::MatchConcluded => players,
    }
}

/// `world.event`: the round and load counters the log moves.
fn world_event(event: GameEvent, world: Records) -> Records {
    match event {
        GameEvent::RoundBegan { round, health, first } => Records {
            round_index: round,
            round_health: health,
            first_turn: first,
            load_index: 0,
            first_sequence: true,
            checking_first_death: FirstDeathCheck::On,
            ..world
        },
        GameEvent::Loaded { load } => Records {
            shown: load,
            load_index: load_next(world.first_sequence, world.load_index),
            first_sequence: false,
            ..world
        },
        GameEvent::GrabbingBegan { .. }
        | GameEvent::Granted { .. }
        | GameEvent::Placed { .. }
        | GameEvent::GrabbingEnded { .. }
        | GameEvent::DistributionDone
        | GameEvent::TurnSkipped { .. }
        | GameEvent::JamLifted { .. }
        | GameEvent::TurnGiven { .. }
        | GameEvent::PickedUp { .. }
        | GameEvent::Fired { .. }
        | GameEvent::Died { .. }
        | GameEvent::Used { .. }
        | GameEvent::Healed { .. }
        | GameEvent::Ejected { .. }
        | GameEvent::Inverted { .. }
        | GameEvent::JamApplied { .. }
        | GameEvent::DirectionFlipped { .. }
        | GameEvent::RoundWon { .. }
        | GameEvent::MatchConcluded => world,
    }
}

/// A remaining deck as a set of batch ids (bit `id` set) and its weight.
#[derive(Clone, Copy, Debug, PartialEq)]
struct DeckMass {
    mask: u32,
    weight: F32,
}

fn bit(index: u32) -> u32 {
    1u32.checked_shl(index).unwrap_or(0)
}

/// `deck.full`: one bit per batch of the table's deck.
fn deck_full(table: Table) -> u32 {
    bit(crate::num::len_u32(table.deck().len())).wrapping_sub(1)
}

/// `deck.batches` of the full deck: the batches in `mask`.
fn deck_of(table: Table, mask: u32) -> Deck {
    Deck::of_ids(
        table,
        Deck::full(table).iter().map(|batch| batch.id).filter(|id| mask & bit(*id) != 0),
    )
}

fn deck_insert(decks: &mut Vec<DeckMass>, mask: u32, weight: F32) {
    match decks.iter_mut().find(|deck| deck.mask == mask) {
        Some(found) => found.weight = found.weight.add(weight),
        None => decks.push(DeckMass { mask, weight }),
    }
}

/// `deck.load`: each deck's batches that would show `shown`, each splitting its deck's weight evenly.
fn deck_load(decks: &[DeckMass], table: Table, rule: LoadRule, shown: Load) -> Vec<DeckMass> {
    let mut found = Vec::new();
    for deck in decks {
        let mask = if deck.mask == 0 { deck_full(table) } else { deck.mask };
        let batches: Vec<_> = deck_of(table, mask).iter().collect();
        let weight = deck.weight.div(F32::from_len(batches.len()));
        for batch in batches {
            if load_actual(rule, batch.load) == shown {
                deck_insert(&mut found, mask ^ bit(batch.id), weight);
            }
        }
    }
    found
}

fn deck_normalize(decks: Vec<DeckMass>) -> Vec<DeckMass> {
    let total = F32::sum_right(decks.iter().map(|deck| deck.weight));
    decks
        .into_iter()
        .map(|deck| DeckMass {
            mask: deck.mask,
            weight: deck.weight.div(total),
        })
        .collect()
}

fn deck_log(config: &Config, log: &[Heard]) -> Vec<DeckMass> {
    let table = config.table();
    let mut world = initial(config).world;
    let mut decks = vec![DeckMass {
        mask: deck_full(table),
        weight: F32::ONE,
    }];
    for heard in log {
        if let Heard::Witnessed(event) = *heard {
            let next = world_event(event, world);
            if let GameEvent::Loaded { load } = event {
                decks = deck_normalize(deck_load(&decks, table, world_load_rule(config, &next), load));
            }
            world = next;
        }
    }
    decks
}

/// `state.of` at an Idle board: the initial state with the log's counters
/// replayed and the board's visible records restored.
fn state_of(config: &Config, board: &Board, log: &[Heard], seat: buckshot_rules::Seat) -> State {
    let base = initial(config);
    let replayed = log.iter().fold(base.world, |world, heard| match *heard {
        Heard::Witnessed(event) => world_event(event, world),
        Heard::Learned(_) => world,
    });
    let RoundView { index, health, .. } = board.round;
    let GunView { shown, sawed, .. } = board.gun;
    let world = Records {
        round_index: index,
        round_health: health,
        shown,
        direction: board.direction,
        sawed,
        turn: Some(seat),
        ..replayed
    };
    let views = board.views;
    let of_views = views
        .entries()
        .fold(Players::fill(views.table(), SeatRecord::FRESH), |players, (at, view)| {
            players.set(at, seat_of(view))
        });
    let counted = log.iter().fold(of_views, |players, heard| match *heard {
        Heard::Witnessed(event) => players_event(event, players),
        Heard::Learned(_) => players,
    });
    let players = views.entries().fold(counted, |players, (at, view)| {
        update(players, at, |record| SeatRecord {
            slots: view.slots,
            cash: view.cash,
            ..record
        })
    });
    State {
        world,
        players,
        grabs: base.grabs,
        phase: Phase::Idle { seat },
    }
}

/// `worlds.decks`: one world per deck and shell order, at the deck's weight.
fn worlds(config: &Config, decks: &[DeckMass], orders: &[Gun], state: State) -> Vec<World> {
    let table = config.table();
    let mut all = Vec::with_capacity(decks.len().saturating_mul(orders.len()));
    for deck in decks {
        let records = Records {
            decks: state.world.decks.set(table, deck_of(table, deck.mask)),
            ..state.world
        };
        for gun in orders {
            all.push(World {
                state: State {
                    world: Records { gun: *gun, ..records },
                    ..state
                },
                weight: deck.weight,
                won: None,
            });
        }
    }
    all
}

fn normalize(worlds: Vec<World>) -> Vec<World> {
    let total = F32::sum_right(worlds.iter().map(|world| world.weight));
    worlds
        .into_iter()
        .map(|world| World {
            weight: world.weight.div(total),
            ..world
        })
        .collect()
}

/// `build`: the belief at an Idle board with at most ten shells shown, or why there is none.
///
/// # Errors
///
/// The reason Bend's `Rejected` gives.
pub fn build(position: &Position) -> Result<Belief, &'static str> {
    let Position { config, board, log, me } = position;
    let seat = match board.stage {
        Stage::Playing { seat, mode: Mode::Idle } if board.gun.shown.live.saturating_add(board.gun.shown.blank) <= 10 => seat,
        Stage::Playing { .. } | Stage::Setup | Stage::Distributing | Stage::Loading | Stage::MatchOver => {
            return Err("requires an Idle board and a shown load of at most ten shells");
        }
    };
    let state = state_of(config, board, log, seat);
    let decks = deck_log(config, log);
    let public = worlds(config, &decks, &orders_log(log, false), state);
    let private = worlds(config, &decks, &orders_log(log, true), state);
    if public.is_empty() {
        return Err("public log has no consistent shell/deck belief");
    }
    if private.is_empty() {
        return Err("private log has no consistent shell/deck belief");
    }
    Ok(Belief {
        public: normalize(public),
        private: normalize(private),
        me: *me,
        round: state.world.round_index,
    })
}
