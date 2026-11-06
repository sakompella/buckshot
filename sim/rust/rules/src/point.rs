//! `simple/point.bend`: the request at a point and a seat's Idle menu.

use arrayvec::ArrayVec;

use crate::domain::{Config, Item, Items, Label, Range, Seat, Seats, Slot, Table};
use crate::items::{self, Picks, Uses};
use crate::rules;
use crate::state::{Phase, State};
use crate::{IdleOption, MENU_CAPACITY, Menu, Request};

type Options = ArrayVec<IdleOption, MENU_CAPACITY>;

fn add(options: &mut Options, option: IdleOption) {
    // The capacity bounds every menu (see MENU_CAPACITY), so nothing is dropped.
    let _ = options.try_push(option);
}

/// `item.chained`: items whose use is part of a longer move.
fn item_chained(item: Item) -> bool {
    match item {
        Item::Jammer => {
            bend_arm!("simple/point:item.chained:D.Jammer{}");
            true
        }
        Item::Adrenaline => {
            bend_arm!("simple/point:item.chained:D.Adrenaline{}");
            true
        }
        Item::Saw | Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            bend_arm!("simple/point:item.chained:_");
            false
        }
    }
}

/// `use.first`: the first slot holding `item`.
fn use_first(uses: &Uses, item: Item) -> Option<Slot> {
    uses.iter().find(|at| at.item == item).map(|at| at.slot)
}

/// `use.options`: one use per distinct item, at its first slot, in slot order.
fn use_options(options: &mut Options, uses: &Uses) {
    let mut seen = Items::EMPTY;
    for at in uses {
        if item_chained(at.item) | seen.contains(at.item) {
            bend_arm!("sm/items:keep:False{}");
        } else {
            bend_arm!("sm/items:keep:True{}");
            add(options, IdleOption::UseSlot { slot: at.slot, item: at.item });
        }
        seen = seen.with(at.item);
    }
}

/// `jam.options` with `jam.targets`.
fn jam_options(options: &mut Options, jammer: Option<Slot>, targets: Seats) {
    match jammer {
        None => {
            bend_arm!("simple/point:jam.options:None{}");
        }
        Some(slot) => {
            bend_arm!("simple/point:jam.options:Some{slot}");
            for target in targets.iter() {
                add(options, IdleOption::JamWith { slot, target });
            }
        }
    }
}

/// `steal.options` with `steal.picks`: one steal per owner and distinct item
/// that opens no pick (sm never offers adrenaline; a jammer is StealJam), at
/// the owner's first slot holding it, by owner then slot.
fn steal_options(options: &mut Options, adrenaline: Option<Slot>, picks: &Picks) {
    let Some(adrenaline) = adrenaline else {
        bend_arm!("simple/point:steal.options:None{}");
        return;
    };
    bend_arm!("simple/point:steal.options:Some{slot}");
    let mut seen: ArrayVec<(Seat, Item), 24> = ArrayVec::new();
    for pick in picks {
        if item_chained(pick.item) | seen.contains(&(pick.owner, pick.item)) {
            bend_arm!("sm/items:keep:False{}");
        } else {
            bend_arm!("sm/items:keep:True{}");
            add(options, IdleOption::StealWith { adrenaline, owner: pick.owner, slot: pick.slot, item: pick.item });
        }
        let _ = seen.try_push((pick.owner, pick.item));
    }
}

/// `steal_jam.options` with `steal_jam.picks`: each owner's first jammer,
/// stolen and used on each target, by owner then target.
fn steal_jam_options(options: &mut Options, adrenaline: Option<Slot>, picks: &Picks, targets: Seats) {
    let Some(adrenaline) = adrenaline else {
        bend_arm!("simple/point:steal_jam.options:None{}");
        return;
    };
    bend_arm!("simple/point:steal_jam.options:Some{slot}");
    let mut seen = Seats::EMPTY;
    for pick in picks {
        let jammer = pick.item == Item::Jammer;
        if jammer & !seen.contains(pick.owner) {
            bend_arm!("simple/point:steal_jam.here:True{}");
            for target in targets.iter() {
                add(options, IdleOption::StealJamWith { adrenaline, owner: pick.owner, slot: pick.slot, target });
            }
        } else {
            bend_arm!("simple/point:steal_jam.here:False{}");
        }
        if jammer && !seen.contains(pick.owner) {
            seen.push(pick.owner);
        }
    }
}

/// `options`: every legal move of `seat`, in menu order (shots, uses, jams,
/// steals, steal-jams).
pub(crate) fn options(config: &Config, state: &State, seat: Seat) -> Options {
    let uses = items::uses(config, state, seat);
    let targets = items::jam_for(config, state, seat);
    let picks = items::steal_for(config, state, seat);
    let adrenaline = use_first(&uses, Item::Adrenaline);
    let mut options = Options::new();
    for target in rules::aim_targets(&state.players).iter() {
        add(&mut options, IdleOption::ShootAt { target });
    }
    use_options(&mut options, &uses);
    jam_options(&mut options, use_first(&uses, Item::Jammer), targets);
    steal_options(&mut options, adrenaline, &picks);
    steal_jam_options(&mut options, adrenaline, &picks, targets);
    options
}

/// `first.range`.
fn first_range(table: Table) -> Range {
    match table {
        Table::TwoSeats => {
            bend_arm!("simple/point:first.range:D.TwoSeats{}");
            Range { lo: 0, extra: 0 }
        }
        Table::ThreeSeats => {
            bend_arm!("simple/point:first.range:D.ThreeSeats{}");
            Range { lo: 0, extra: 1 }
        }
        Table::FourSeats => {
            bend_arm!("simple/point:first.range:D.FourSeats{}");
            Range { lo: 0, extra: 2 }
        }
    }
}

/// `request` with `phase.request`.
#[must_use]
pub fn request(config: &Config, state: &State) -> Request {
    let table = config.table();
    let draw = |label, range| Request::Draw { label, range };
    match state.phase {
        Phase::NeedFirst => {
            bend_arm!("simple/point:phase.request:T.NeedFirst{}");
            draw(Label::FirstSeat, first_range(table))
        }
        Phase::NeedHealth => {
            bend_arm!("simple/point:phase.request:T.NeedHealth{}");
            draw(Label::StartingHealth, table.health_range())
        }
        Phase::NeedAmount => {
            bend_arm!("simple/point:phase.request:T.NeedAmount{}");
            draw(Label::ItemAmount, table.amount_range())
        }
        Phase::NeedBatch => {
            bend_arm!("simple/point:phase.request:T.NeedBatch{}");
            match state.world.decks.get(table).len().checked_sub(2) {
                Some(extra) => {
                    bend_arm!("simple/point:batch.request:1n+1n+extra");
                    draw(Label::SequenceBatch, Range { lo: 0, extra })
                }
                None => {
                    bend_arm!("simple/point:batch.request:_");
                    Request::Stuck
                }
            }
        }
        Phase::NeedSwap { i, .. } => match i.checked_sub(1) {
            Some(extra) => {
                bend_arm!("simple/point:phase.request:T.NeedSwap{_, _, 1n+extra}");
                draw(Label::ShuffleSwap, Range { lo: 0, extra })
            }
            None => {
                bend_arm!("simple/point:phase.request:T.NeedSwap{_, _, 0n}");
                Request::Stuck
            }
        },
        Phase::Idle { seat } => {
            bend_arm!("simple/point:phase.request:T.Idle{+seat}");
            if table.has(seat) {
                bend_arm!("simple/point:idle.request:True{}");
                let options = options(config, state, seat);
                if options.is_empty() {
                    bend_arm!("simple/point:choose:Nil{}");
                    Request::Stuck
                } else {
                    bend_arm!("simple/point:choose:move <> rest");
                    Request::Choose(Menu::new(seat, options))
                }
            } else {
                bend_arm!("simple/point:idle.request:False{}");
                Request::Stuck
            }
        }
        Phase::Ended => {
            bend_arm!("simple/point:phase.request:T.Ended{}");
            Request::Finished
        }
        Phase::Blocked { .. } => {
            bend_arm!("simple/point:phase.request:T.Blocked{_}");
            Request::Stuck
        }
        Phase::Stalled => {
            bend_arm!("simple/point:phase.request:T.Stalled{}");
            Request::Stuck
        }
        Phase::NeedTurnAmount { .. } => {
            bend_arm!("simple/point:phase.request:T.NeedTurnAmount{_, _, _}");
            draw(Label::ItemAmount, table.amount_range())
        }
        Phase::NeedItem { rest, .. } => {
            bend_arm!("simple/point:phase.request:T.NeedItem{_, _, _, rest}");
            draw(Label::ItemChoice, Range { lo: 0, extra: rest.len() })
        }
        Phase::NeedPhone { .. } => {
            bend_arm!("simple/point:phase.request:T.NeedPhone{_, _, _}");
            match state.world.gun.len().checked_sub(4) {
                Some(extra) => {
                    bend_arm!("simple/point:phone.request:1n+1n+1n+1n+extra");
                    draw(Label::PhoneIndex, Range { lo: 2, extra })
                }
                None => {
                    bend_arm!("simple/point:phone.request:_");
                    Request::Stuck
                }
            }
        }
    }
}

impl Menu {
    pub(crate) const fn new(seat: Seat, options: Options) -> Self {
        Self { seat, options }
    }
}
