//! `simple/point.bend`: the request at a point and a seat's Idle menu.

use arrayvec::ArrayVec;

use crate::branch::B;
use crate::domain::{Config, Item, Items, Label, Range, Seat, Seats, Slot, Table};
use crate::items::{self, PICKS_CAPACITY, Picks, Uses};
use crate::rules;
use crate::state::{Phase, Players, State};
use crate::{IdleOption, MENU_CAPACITY, Menu, Request};

type Options = ArrayVec<IdleOption, MENU_CAPACITY>;

// Shots at up to four seats, a use per slot, jams and steal-jams at up to
// three targets, and the steals.
const _: () = assert!(
    4 + 8 + 3 + PICKS_CAPACITY + 3 * 3 <= MENU_CAPACITY,
    "a menu can outgrow MENU_CAPACITY"
);

/// [`MENU_CAPACITY`] bounds every menu, so `push` (which panics on a full
/// list rather than drop the move) never fails.
fn add(options: &mut Options, option: IdleOption) {
    options.push(option);
}

/// `item.chained`: items whose use is part of a longer move.
fn item_chained(item: Item) -> bool {
    match item {
        Item::Jammer => {
            branch!(B::SimplePointItemChainedJammer);
            true
        }
        Item::Adrenaline => {
            branch!(B::SimplePointItemChainedAdrenaline);
            true
        }
        Item::Saw | Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            branch!(B::SimplePointItemChainedAny);
            false
        }
    }
}

/// `use.first`: the first slot holding `item`.
fn use_first(uses: &Uses, item: Item) -> Option<Slot> {
    for at in uses {
        branch!(B::SimplePointUseFirstUseAtCons);
        if at.item == item {
            branch!(B::SimplePointUseFirstPickTrue);
            return Some(at.slot);
        }
        branch!(B::SimplePointUseFirstPickFalse);
    }
    branch!(B::SimplePointUseFirstNil);
    None
}

/// `use.options`: one use per distinct item, at its first slot, in slot order.
fn use_options(options: &mut Options, uses: &Uses) {
    let mut seen = Items::EMPTY;
    for at in uses {
        branch!(B::SimplePointUseOptionsUseAtCons);
        items::keep(!(item_chained(at.item) | seen.contains(at.item)), || {
            add(
                options,
                IdleOption::UseSlot {
                    slot: at.slot,
                    item: at.item,
                },
            );
        });
        seen = seen.with(at.item);
    }
    branch!(B::SimplePointUseOptionsNil);
}

/// `jam.options` with `jam.targets`.
fn jam_options(options: &mut Options, jammer: Option<Slot>, targets: Seats) {
    match jammer {
        None => {
            branch!(B::SimplePointJamOptionsNone);
        }
        Some(slot) => {
            branch!(B::SimplePointJamOptionsSome);
            for target in targets.iter() {
                branch!(B::SimplePointJamTargetsJamAtCons);
                add(options, IdleOption::JamWith { slot, target });
            }
            branch!(B::SimplePointJamTargetsNil);
        }
    }
}

/// `steal.options`.
fn steal_options(options: &mut Options, adrenaline: Option<Slot>, picks: &Picks) {
    match adrenaline {
        None => {
            branch!(B::SimplePointStealOptionsNone);
        }
        Some(slot) => {
            branch!(B::SimplePointStealOptionsSome);
            steal_picks(options, slot, picks);
        }
    }
}

/// `steal.picks`: one steal per owner and distinct item that opens no pick
/// (sm never offers adrenaline; a jammer is `StealJam`), at the owner's first
/// slot holding it, by owner then slot.
fn steal_picks(options: &mut Options, adrenaline: Slot, picks: &Picks) {
    let mut seen = SeatItems::default();
    for pick in picks {
        branch!(B::SimplePointStealPicksPickCons);
        items::keep(!(item_chained(pick.item) | seen.contains(pick.owner, pick.item)), || {
            add(
                options,
                IdleOption::StealWith {
                    adrenaline,
                    owner: pick.owner,
                    slot: pick.slot,
                    item: pick.item,
                },
            );
        });
        seen.insert(pick.owner, pick.item);
    }
    branch!(B::SimplePointStealPicksNil);
}

/// A set of (seat, item) pairs: bit `16 * seat + rank` per pair.
#[derive(Clone, Copy, Default)]
struct SeatItems(u64);

impl SeatItems {
    fn bit(seat: Seat, item: Item) -> u64 {
        1u64.checked_shl(u32::from(u8::from(seat)).wrapping_mul(16).wrapping_add(item.rank()))
            .unwrap_or(0)
    }

    fn contains(self, seat: Seat, item: Item) -> bool {
        self.0 & Self::bit(seat, item) != 0
    }

    fn insert(&mut self, seat: Seat, item: Item) {
        self.0 |= Self::bit(seat, item);
    }
}

/// `steal_jam.options`.
fn steal_jam_options(options: &mut Options, adrenaline: Option<Slot>, picks: &Picks, targets: Seats) {
    match adrenaline {
        None => {
            branch!(B::SimplePointStealJamOptionsNone);
        }
        Some(slot) => {
            branch!(B::SimplePointStealJamOptionsSome);
            steal_jam_picks(options, slot, picks, targets);
        }
    }
}

/// `steal_jam.picks`: each owner's first jammer, stolen and used on each
/// target, by owner then target.
fn steal_jam_picks(options: &mut Options, adrenaline: Slot, picks: &Picks, targets: Seats) {
    let mut seen = Seats::EMPTY;
    for pick in picks {
        branch!(B::SimplePointStealJamPicksPickCons);
        let jammer = pick.item == Item::Jammer;
        if jammer & !seen.contains(pick.owner) {
            branch!(B::SimplePointStealJamHereTrue);
            for target in targets.iter() {
                branch!(B::SimplePointStealJamTargetsJamAtCons);
                add(
                    options,
                    IdleOption::StealJamWith {
                        adrenaline,
                        owner: pick.owner,
                        slot: pick.slot,
                        target,
                    },
                );
            }
            branch!(B::SimplePointStealJamTargetsNil);
        } else {
            branch!(B::SimplePointStealJamHereFalse);
        }
        items::keep(jammer, || seen.insert(pick.owner));
    }
    branch!(B::SimplePointStealJamPicksNil);
}

/// `options`: every legal move of `seat`, in menu order (shots, uses, jams,
/// steals, steal-jams). Reads only the players and `sawed`; [`MenuInputs`]
/// relies on that.
pub(crate) fn options(state: &State, seat: Seat) -> Options {
    let players = &state.players;
    let sawed = state.world.sawed;
    let targets = items::jam_of(players, seat);
    let jams = items::jam_any(targets);
    let picks = items::steal_with(players, seat, sawed, jams);
    let uses = items::uses_with(players, seat, sawed, jams, items::steal_any(&picks));
    let adrenaline = use_first(&uses, Item::Adrenaline);
    let mut options = Options::new();
    for target in rules::aim_targets(&state.players).iter() {
        branch!(B::SimplePointShotsTargetCons);
        add(&mut options, IdleOption::ShootAt { target });
    }
    branch!(B::SimplePointShotsNil);
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
            branch!(B::SimplePointFirstRangeTwoSeats);
            Range { lo: 0, extra: 0 }
        }
        #[cfg(feature = "seats-2-4")]
        Table::ThreeSeats => {
            branch!(B::SimplePointFirstRangeThreeSeats);
            Range { lo: 0, extra: 1 }
        }
        #[cfg(feature = "seats-2-4")]
        Table::FourSeats => {
            branch!(B::SimplePointFirstRangeFourSeats);
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
            branch!(B::SimplePointPhaseRequestNeedFirst);
            draw(Label::FirstSeat, first_range(table))
        }
        Phase::NeedHealth => {
            branch!(B::SimplePointPhaseRequestNeedHealth);
            draw(Label::StartingHealth, table.health_range())
        }
        Phase::NeedAmount => {
            branch!(B::SimplePointPhaseRequestNeedAmount);
            draw(Label::ItemAmount, table.amount_range())
        }
        Phase::NeedBatch => {
            branch!(B::SimplePointPhaseRequestNeedBatch);
            if let Some(extra) = state.world.decks.get(table).len().checked_sub(2) {
                branch!(B::SimplePointBatchRequestSuccSucc);
                draw(Label::SequenceBatch, Range { lo: 0, extra })
            } else {
                branch!(B::SimplePointBatchRequestAny);
                Request::Stuck
            }
        }
        Phase::NeedSwap { i: 0, .. } => {
            branch!(B::SimplePointPhaseRequestNeedSwapZero);
            Request::Stuck
        }
        Phase::NeedSwap { i, .. } => {
            branch!(B::SimplePointPhaseRequestNeedSwapSucc);
            draw(
                Label::ShuffleSwap,
                Range {
                    lo: 0,
                    extra: i.saturating_sub(1),
                },
            )
        }
        Phase::Idle { seat } => {
            branch!(B::SimplePointPhaseRequestIdle);
            if table.has(seat) {
                branch!(B::SimplePointIdleRequestTrue);
                let options = options(state, seat);
                if options.is_empty() {
                    branch!(B::SimplePointChooseNil);
                    Request::Stuck
                } else {
                    branch!(B::SimplePointChooseCons);
                    Request::Choose(Menu::new(seat, options))
                }
            } else {
                branch!(B::SimplePointIdleRequestFalse);
                Request::Stuck
            }
        }
        Phase::Ended => {
            branch!(B::SimplePointPhaseRequestEnded);
            Request::Finished
        }
        Phase::Blocked { .. } => {
            branch!(B::SimplePointPhaseRequestBlocked);
            Request::Stuck
        }
        Phase::Stalled => {
            branch!(B::SimplePointPhaseRequestStalled);
            Request::Stuck
        }
        Phase::NeedTurnAmount { .. } => {
            branch!(B::SimplePointPhaseRequestNeedTurnAmount);
            draw(Label::ItemAmount, table.amount_range())
        }
        Phase::NeedItem { rest, .. } => {
            branch!(B::SimplePointPhaseRequestNeedItem);
            draw(Label::ItemChoice, Range { lo: 0, extra: rest.len() })
        }
        Phase::NeedPhone { .. } => {
            branch!(B::SimplePointPhaseRequestNeedPhone);
            if let Some(extra) = state.world.gun.len().checked_sub(4) {
                branch!(B::SimplePointPhoneRequestSuccSuccSuccSucc);
                draw(Label::PhoneIndex, Range { lo: 2, extra })
            } else {
                branch!(B::SimplePointPhoneRequestAny);
                Request::Stuck
            }
        }
    }
}

/// What an Idle point's request reads besides the config: the seat, the
/// players and whether the barrel is sawed (see [`options`]). States with
/// equal inputs have the same request.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MenuInputs {
    seat: Seat,
    sawed: bool,
    players: Players,
}

impl MenuInputs {
    /// The inputs of the state's Idle menu; `None` away from Idle.
    #[must_use]
    pub const fn of(state: &State) -> Option<Self> {
        if let Phase::Idle { seat } = state.phase {
            Some(Self {
                seat,
                sawed: state.world.sawed,
                players: state.players,
            })
        } else {
            None
        }
    }
}

/// The request's draw, if it is one, without building the menu an Idle
/// seat's request holds: at Idle the request is a menu or `Stuck`.
#[must_use]
pub fn draw_request(config: &Config, state: &State) -> Option<(Label, Range)> {
    if let Phase::Idle { .. } = state.phase {
        return None;
    }
    if let Request::Draw { label, range } = request(config, state) {
        Some((label, range))
    } else {
        None
    }
}

impl Menu {
    pub(crate) const fn new(seat: Seat, options: Options) -> Self {
        Self { seat, options }
    }
}
