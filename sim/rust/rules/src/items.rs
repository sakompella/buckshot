//! `sm/items.bend`: item pools, distribution needs, and the use, jam and
//! steal options. Every function that reads sm's records (`S.State`) takes
//! the config and the simple state, since the config is not in the state.

use arrayvec::ArrayVec;

use crate::branch::B;
use crate::domain::{AmountRule, Config, Direction, Gun, Item, ItemRule, Items, Ring, Seat, Seats, Shell, Slot, Slots};
use crate::state::{Grabs, Jam, Players, State};
use crate::{push_bounded, rules};

/// sm/state.bend `IdleOption::UseAt` (`uses` only makes these).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct UseAt {
    pub slot: Slot,
    pub item: Item,
}

pub(crate) type Uses = ArrayVec<UseAt, 8>;

/// sm/state.bend `StealOption::Pick`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Pick {
    pub owner: Seat,
    pub slot: Slot,
    pub item: Item,
}

/// At most three owners with eight slots each.
pub(crate) type Picks = ArrayVec<Pick, 24>;

/// sm/state.bend `GrabOption`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum GrabOption {
    TakeItem,
    PutAt { slot: Slot },
}

pub(crate) type GrabOptions = ArrayVec<GrabOption, 9>;

/// `value.or` over `ring.get`: a seat missing from a ring reads as `fallback`.
fn read<T: Copy>(ring: &Ring<T>, seat: Seat, fallback: T) -> T {
    ring.get(seat).unwrap_or(fallback)
}

/// `keep`: whether the element is kept in the result list.
fn keep(kept: bool) -> bool {
    if kept {
        branch!(B::SmItemsKeepTrue);
    } else {
        branch!(B::SmItemsKeepFalse);
    }
    kept
}

/// `is_none`.
fn is_none(found: Option<Item>) -> bool {
    if found.is_none() {
        branch!(B::SmItemsIsNoneNone);
        true
    } else {
        branch!(B::SmItemsIsNoneSome);
        false
    }
}

/// `has_items`.
fn has_items(items: Items) -> bool {
    if items.split_first().is_none() {
        branch!(B::SmItemsHasItemsNil);
        false
    } else {
        branch!(B::SmItemsHasItemsCons);
        true
    }
}

/// `has_seats`.
fn has_seats(seats: Seats) -> bool {
    if seats.first().is_none() {
        branch!(B::SmItemsHasSeatsNil);
        false
    } else {
        branch!(B::SmItemsHasSeatsCons);
        true
    }
}

/// `slots.items`: the eight contents in slot order.
fn slots_items(slots: Slots) -> impl Iterator<Item = Option<Item>> {
    branch!(B::SmItemsSlotsItemsSlots);
    Slot::ORDER.into_iter().map(move |slot| slots.get(slot))
}

/// `occupied`.
fn occupied(slots: Slots) -> u32 {
    let mut count = 0u32;
    for found in slots_items(slots) {
        if found.is_none() {
            branch!(B::SmItemsOccupiedNoneCons);
        } else {
            branch!(B::SmItemsOccupiedSomeCons);
            count = count.saturating_add(1);
        }
    }
    branch!(B::SmItemsOccupiedNil);
    count
}

/// `bool.nat`.
fn bool_nat(b: bool) -> u32 {
    if b {
        branch!(B::SmItemsBoolNatTrue);
        1
    } else {
        branch!(B::SmItemsBoolNatFalse);
        0
    }
}

/// `copies.one`.
fn copies_one(found: Option<Item>, item: Item) -> u32 {
    match found {
        None => {
            branch!(B::SmItemsCopiesOneNone);
            0
        }
        Some(actual) => {
            branch!(B::SmItemsCopiesOneSome);
            bool_nat(actual.rank() == item.rank())
        }
    }
}

/// `copies`.
fn copies(slots: Slots, item: Item) -> u32 {
    let mut total = 0u32;
    for found in slots_items(slots) {
        branch!(B::SmItemsCopiesCons);
        total = total.saturating_add(copies_one(found, item));
    }
    branch!(B::SmItemsCopiesNil);
    total
}

/// `seat.health`.
pub(crate) fn seat_health(players: &Players, seat: Seat) -> u32 {
    players.get(seat).map_or(100, |record| record.health)
}

/// `seat.slots`.
pub(crate) fn seat_slots(players: &Players, seat: Seat) -> Slots {
    players.get(seat).map_or(Slots::EMPTY, |record| record.slots)
}

/// `seat.jammed`.
fn seat_jammed(players: &Players, seat: Seat) -> bool {
    players.get(seat).map_or(Jam::Free, |record| record.jam).jammed()
}

/// `seat.grabbing`.
fn seat_grabbing(grabs: &Grabs, seat: Seat) -> bool {
    read(&grabs.grabbing, seat, false)
}

/// `seat.holding`.
pub(crate) fn seat_holding(grabs: &Grabs, seat: Seat) -> Option<Item> {
    read(&grabs.holding, seat, None)
}

/// `seat.granted`.
fn seat_granted(grabs: &Grabs, seat: Seat) -> u32 {
    read(&grabs.granted, seat, 0)
}

/// `seat.intake`.
fn seat_intake(grabs: &Grabs, seat: Seat) -> bool {
    read(&grabs.intake, seat, false)
}

/// `grabs.open`.
fn grabs_open(grabs: Grabs, seat: Seat) -> Grabs {
    branch!(B::SmItemsGrabsOpenGrabs);
    Grabs {
        distributing: grabs.distributing,
        grabbing: grabs.grabbing.set(seat, true),
        holding: grabs.holding.set(seat, None),
        granted: grabs.granted.set(seat, 0),
        intake: grabs.intake.set(seat, true),
    }
}

/// `grabs.open_all`.
pub(crate) fn grabs_open_all(seats: Seats, grabs: Grabs) -> Grabs {
    let mut grabs = grabs;
    for seat in seats.iter() {
        branch!(B::SmItemsGrabsOpenAllCons);
        grabs = grabs_open(grabs, seat);
    }
    branch!(B::SmItemsGrabsOpenAllNil);
    grabs
}

/// `grabs.stop_intake`.
pub(crate) fn grabs_stop_intake(grabs: Grabs, seat: Seat) -> Grabs {
    branch!(B::SmItemsGrabsStopIntakeGrabs);
    Grabs {
        intake: grabs.intake.set(seat, false),
        ..grabs
    }
}

/// `grabs.give`.
pub(crate) fn grabs_give(grabs: Grabs, seat: Seat, item: Item) -> Grabs {
    branch!(B::SmItemsGrabsGiveGrabs);
    Grabs {
        holding: grabs.holding.set(seat, Some(item)),
        granted: grabs.granted.set(seat, seat_granted(&grabs, seat).saturating_add(1)),
        intake: grabs.intake.set(seat, false),
        ..grabs
    }
}

/// `grabs.close`.
pub(crate) fn grabs_close(grabs: Grabs, seat: Seat) -> Grabs {
    branch!(B::SmItemsGrabsCloseGrabs);
    Grabs {
        grabbing: grabs.grabbing.set(seat, false),
        ..grabs
    }
}

/// `grabs.placed`: a placed item leaves the hand; intake reopens only while still grabbing.
pub(crate) fn grabs_placed(grabs: Grabs, seat: Seat) -> Grabs {
    branch!(B::SmItemsGrabsPlacedGrabs);
    Grabs {
        holding: grabs.holding.set(seat, None),
        intake: grabs.intake.set(seat, seat_grabbing(&grabs, seat)),
        ..grabs
    }
}

/// `owned`: copies in the slots plus the held item.
fn owned(players: &Players, grabs: &Grabs, seat: Seat, item: Item) -> u32 {
    copies(seat_slots(players, seat), item).saturating_add(copies_one(seat_holding(grabs, seat), item))
}

/// `owned.table`.
fn owned_table(seats: Seats, players: &Players, grabs: &Grabs, item: Item) -> u32 {
    let mut total = 0u32;
    for seat in seats.iter() {
        branch!(B::SmItemsOwnedTableCons);
        total = total.saturating_add(owned(players, grabs, seat, item));
    }
    branch!(B::SmItemsOwnedTableNil);
    total
}

/// `stock.open`.
fn stock_open(rule: ItemRule, dealt: bool, own: u32, total: u32) -> bool {
    branch!(B::SmItemsStockOpenItemRule);
    rule.enabled && dealt && own < rule.per_player && total < rule.on_table
}

/// `pool`: the items `seat` may still be granted, in item order. Held items
/// count against both caps.
pub(crate) fn pool(config: &Config, state: &State, seat: Seat) -> Items {
    let table = config.table();
    let rules = rules::world_rules_ref(config, &state.world);
    // `pool.go` over `item.order()`.
    branch!(B::SmItemsRoundItemsRoundRules);
    let mut pool = Items::EMPTY;
    for item in Item::ORDER {
        branch!(B::SmItemsPoolGoCons);
        let open = stock_open(
            rules.item(item),
            item.dealt_at(table),
            owned(&state.players, &state.grabs, seat, item),
            owned_table(table.seats(), &state.players, &state.grabs, item),
        );
        if keep(open) {
            pool = pool.with(item);
        }
    }
    branch!(B::SmItemsPoolGoNil);
    pool
}

/// `begin.can`: a new round ignores health and full slots.
fn begin_can(new_round: bool, hp: u32, slots: Slots) -> bool {
    let living = rules::alive(hp);
    let room = occupied(slots) < 8;
    new_round || (living && room)
}

/// `begin.go`.
fn begin_go(seats: Seats, config: &Config, state: &State, new_round: bool) -> Seats {
    let mut kept = Seats::EMPTY;
    for seat in seats.iter() {
        branch!(B::SmItemsBeginGoCons);
        let can = begin_can(new_round, seat_health(&state.players, seat), seat_slots(&state.players, seat));
        let stocked = has_items(pool(config, state, seat));
        if keep(can && stocked) {
            kept.push(seat);
        }
    }
    branch!(B::SmItemsBeginGoNil);
    kept
}

/// `begin.seats`: who begins grabbing. The caller passes the stored amount,
/// whose zero selects no one.
pub(crate) fn begin_seats(config: &Config, state: &State, new_round: bool, amount: u32) -> Seats {
    if amount == 0 {
        branch!(B::SmItemsBeginSeatsZero);
        Seats::EMPTY
    } else {
        branch!(B::SmItemsBeginSeatsAny);
        begin_go(config.table().seats(), config, state, new_round)
    }
}

/// `puts.here`.
fn puts_here(found: Option<Item>, slot: Slot, out: &mut GrabOptions) {
    if found.is_none() {
        branch!(B::SmItemsPutsHereNone);
        push_bounded(out, GrabOption::PutAt { slot });
    } else {
        branch!(B::SmItemsPutsHereSome);
    }
}

/// `puts`: a put at every empty slot.
fn puts(inventory: Slots, out: &mut GrabOptions) {
    for slot in Slot::ORDER {
        branch!(B::SmItemsPutsCons);
        puts_here(inventory.get(slot), slot, out);
    }
    branch!(B::SmItemsPutsNil);
}

/// `grab.intake`.
fn grab_intake(open: bool, out: &mut GrabOptions) {
    if open {
        branch!(B::SmItemsGrabIntakeTrue);
        push_bounded(out, GrabOption::TakeItem);
    } else {
        branch!(B::SmItemsGrabIntakeFalse);
    }
}

/// `grab.offer`.
fn grab_offer(grabbing: bool, holding: Option<Item>, open: bool, slots: Slots) -> GrabOptions {
    let mut out = GrabOptions::new();
    match (grabbing, holding) {
        (true, Some(_)) => {
            branch!(B::SmItemsGrabOfferTrueSome);
            puts(slots, &mut out);
        }
        (true, None) => {
            branch!(B::SmItemsGrabOfferTrueNone);
            grab_intake(open, &mut out);
        }
        (false, None | Some(_)) => {
            branch!(B::SmItemsGrabOfferFalse);
        }
    }
    out
}

/// One seat's entry of `grab.needs.go` (empty for a seat not at the table).
/// The traversal's `Nil{}` arm has no counterpart here: the caller visits the
/// seats.
pub(crate) fn grab_needs(config: &Config, state: &State, seat: Seat) -> GrabOptions {
    if !config.table().has(seat) {
        return GrabOptions::new();
    }
    branch!(B::SmItemsGrabNeedsGoCons);
    let grabs = &state.grabs;
    let open = seat_intake(grabs, seat) && grabs.distributing;
    grab_offer(
        seat_grabbing(grabs, seat),
        seat_holding(grabs, seat),
        open,
        seat_slots(&state.players, seat),
    )
}

/// `placing.last`: the placing seat still holds its item here.
pub(crate) fn placing_last(config: &Config, state: &State, seat: Seat) -> bool {
    let grabs = &state.grabs;
    let empty_pool = !has_items(pool(config, state, seat));
    let last_slot = occupied(seat_slots(&state.players, seat)).saturating_add(1) == 8;
    let enough = seat_granted(grabs, seat) >= state.world.item_amount;
    empty_pool || last_slot || enough
}

/// `finish.ended`.
fn finish_ended(grabs: &Grabs) -> bool {
    let mut ended = true;
    for (_, grabbing) in grabs.grabbing.entries() {
        branch!(B::SmItemsFinishEndedAtCons);
        ended = !grabbing && ended;
    }
    branch!(B::SmItemsFinishEndedNil);
    ended
}

/// `finish.empty`.
fn finish_empty(seats: Seats, config: &Config, state: &State) -> bool {
    let mut empty = true;
    for seat in seats.iter() {
        branch!(B::SmItemsFinishEmptyCons);
        let stocked = has_items(pool(config, state, seat));
        empty = !stocked && empty;
    }
    branch!(B::SmItemsFinishEmptyNil);
    empty
}

/// `finished`: Godot's completion predicate, unchanged. Every seat stopped
/// grabbing, or every seat's pool is empty.
pub(crate) fn finished(config: &Config, state: &State) -> bool {
    let ended = finish_ended(&state.grabs);
    let empty = finish_empty(config.table().seats(), config, state);
    ended || empty
}

/// `stalled`.
fn stalled(seats: Seats, config: &Config, state: &State, placing: Seat) -> Seats {
    let mut out = Seats::EMPTY;
    for seat in seats.iter() {
        branch!(B::SmItemsStalledCons);
        let grabs = &state.grabs;
        let grabbing = seat_grabbing(grabs, seat);
        let empty_handed = is_none(seat_holding(grabs, seat));
        let other = seat != placing;
        let dry = !has_items(pool(config, state, seat));
        if keep(grabbing && empty_handed && other && dry) {
            out.push(seat);
        }
    }
    branch!(B::SmItemsStalledNil);
    out
}

/// `stalled.seats`: empty-handed grabbers with an empty pool, other than the
/// placing seat. Holders never qualify.
pub(crate) fn stalled_seats(config: &Config, state: &State, placing: Seat) -> Seats {
    stalled(config.table().seats(), config, state, placing)
}

/// `holders` over the holding ring.
pub(crate) fn holders(grabs: &Grabs) -> bool {
    for (_, holding) in grabs.holding.entries() {
        if holding.is_none() {
            branch!(B::SmItemsHoldersAtNoneCons);
        } else {
            branch!(B::SmItemsHoldersAtSomeCons);
            return true;
        }
    }
    branch!(B::SmItemsHoldersNil);
    false
}

/// `amount.live`: the end-of-turn amount draw is live while distributing, or
/// when an exhausted, winnerless gun would start a distribution.
pub(crate) fn amount_live(rule: AmountRule, distributing: bool, reload: bool) -> bool {
    match rule {
        AmountRule::Random => {
            branch!(B::SmItemsAmountLiveRandomAmount);
            distributing || reload
        }
        AmountRule::Fixed(_) => {
            branch!(B::SmItemsAmountLiveFixedAmount);
            false
        }
    }
}

/// `winnerless`.
fn winnerless(winner: Option<Seat>) -> bool {
    if winner.is_none() {
        branch!(B::SmItemsWinnerlessNone);
        true
    } else {
        branch!(B::SmItemsWinnerlessSome);
        false
    }
}

/// `gun.empty`.
fn gun_empty(gun: Gun) -> bool {
    if gun.split_first().is_none() {
        branch!(B::SmItemsGunEmptyNil);
        true
    } else {
        branch!(B::SmItemsGunEmptyCons);
        false
    }
}

/// `reload.wanted`.
pub(crate) fn reload_wanted(config: &Config, state: &State, winner: Option<Seat>) -> bool {
    let empty = gun_empty(state.world.gun);
    let winnerless = winnerless(winner);
    let begins = has_seats(begin_seats(config, state, false, 1));
    empty && winnerless && begins
}

/// `jam.options`.
fn jam_options(players: &Players, by: Seat) -> Seats {
    let mut out = Seats::EMPTY;
    for (seat, record) in players.entries() {
        branch!(B::SmItemsJamOptionsAtCons);
        let other = seat != by;
        let living = rules::alive(record.health);
        let free = !seat_jammed(players, seat);
        if keep(other && living && free) {
            out.push(seat);
        }
    }
    branch!(B::SmItemsJamOptionsNil);
    out
}

/// `jam.for`: the living, unjammed seats other than `by`.
pub(crate) fn jam_for(_config: &Config, state: &State, by: Seat) -> Seats {
    jam_options(&state.players, by)
}

/// `jam.any`.
fn jam_any(options: Seats) -> bool {
    if options.first().is_none() {
        branch!(B::SmItemsJamAnyNil);
        false
    } else {
        branch!(B::SmItemsJamAnyCons);
        true
    }
}

/// `steal.fits`: adrenaline never, a saw only while the barrel is whole, a
/// jammer only if the thief has a target, everything else always.
fn steal_fits(item: Item, sawed: bool, targets: bool) -> bool {
    match item {
        Item::Adrenaline => {
            branch!(B::SmItemsStealFitsAdrenaline);
            false
        }
        Item::Saw => {
            branch!(B::SmItemsStealFitsSaw);
            !sawed
        }
        Item::Jammer => {
            branch!(B::SmItemsStealFitsJammer);
            targets
        }
        Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            branch!(B::SmItemsStealFitsAny);
            true
        }
    }
}

/// `steal.here`.
fn steal_here(found: Option<Item>, owner: Seat, slot: Slot, sawed: bool, targets: bool, out: &mut Picks) {
    if let Some(item) = found {
        branch!(B::SmItemsStealHereSome);
        if keep(steal_fits(item, sawed, targets)) {
            push_bounded(out, Pick { owner, slot, item });
        }
    } else {
        branch!(B::SmItemsStealHereNone);
    }
}

/// `steal.slots`.
fn steal_slots(inventory: Slots, owner: Seat, sawed: bool, targets: bool) -> Picks {
    let mut out = Picks::new();
    for slot in Slot::ORDER {
        branch!(B::SmItemsStealSlotsCons);
        steal_here(inventory.get(slot), owner, slot, sawed, targets, &mut out);
    }
    branch!(B::SmItemsStealSlotsNil);
    out
}

/// `steal.owner`: `slots` is `steal.slots` of this owner, built either way.
fn steal_owner(own: bool, slots: &Picks, out: &mut Picks) {
    if own {
        branch!(B::SmItemsStealOwnerTrue);
    } else {
        branch!(B::SmItemsStealOwnerFalse);
        for pick in slots {
            push_bounded(out, *pick);
        }
    }
}

/// `steal.owners`.
fn steal_owners(players: &Players, thief: Seat, sawed: bool, targets: bool) -> Picks {
    let mut out = Picks::new();
    for (owner, record) in players.entries() {
        branch!(B::SmItemsStealOwnersAtCons);
        let slots = steal_slots(record.slots, owner, sawed, targets);
        steal_owner(owner == thief, &slots, &mut out);
    }
    branch!(B::SmItemsStealOwnersNil);
    out
}

/// `steal.for`: every other seat's occupied slot that fits, dead owners included.
pub(crate) fn steal_for(config: &Config, state: &State, thief: Seat) -> Picks {
    let targets = jam_any(jam_for(config, state, thief));
    steal_owners(&state.players, thief, state.world.sawed, targets)
}

/// `steal.any`.
fn steal_any(options: &Picks) -> bool {
    if options.is_empty() {
        branch!(B::SmItemsStealAnyNil);
        false
    } else {
        branch!(B::SmItemsStealAnyCons);
        true
    }
}

/// `use.fits`.
fn use_fits(item: Item, sawed: bool, targets: bool, steals: bool) -> bool {
    match item {
        Item::Adrenaline => {
            branch!(B::SmItemsUseFitsAdrenaline);
            steals
        }
        Item::Saw => {
            branch!(B::SmItemsUseFitsSaw);
            !sawed
        }
        Item::Jammer => {
            branch!(B::SmItemsUseFitsJammer);
            targets
        }
        Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            branch!(B::SmItemsUseFitsAny);
            true
        }
    }
}

/// `use.here`.
fn use_here(found: Option<Item>, slot: Slot, sawed: bool, targets: bool, steals: bool, out: &mut Uses) {
    if let Some(item) = found {
        branch!(B::SmItemsUseHereSome);
        if keep(use_fits(item, sawed, targets, steals)) {
            push_bounded(out, UseAt { slot, item });
        }
    } else {
        branch!(B::SmItemsUseHereNone);
    }
}

/// `use.slots`.
fn use_slots(inventory: Slots, sawed: bool, targets: bool, steals: bool) -> Uses {
    let mut out = Uses::new();
    for slot in Slot::ORDER {
        branch!(B::SmItemsUseSlotsCons);
        use_here(inventory.get(slot), slot, sawed, targets, steals, &mut out);
    }
    branch!(B::SmItemsUseSlotsNil);
    out
}

/// `uses`: ordinary item use, with the adrenaline rule of M4.
pub(crate) fn uses(config: &Config, state: &State, seat: Seat) -> Uses {
    let targets = jam_any(jam_for(config, state, seat));
    let steals = steal_any(&steal_for(config, state, seat));
    use_slots(seat_slots(&state.players, seat), state.world.sawed, targets, steals)
}

/// `ends_turn`.
pub(crate) fn ends_turn(item: Item, length: u32) -> bool {
    match item {
        Item::Beer => {
            branch!(B::SmItemsEndsTurnBeer);
            length == 1
        }
        Item::Saw | Item::Glass | Item::Jammer | Item::Cigarettes | Item::Phone | Item::Inverter | Item::Adrenaline | Item::Remote => {
            branch!(B::SmItemsEndsTurnAny);
            false
        }
    }
}

/// `invert`.
pub(crate) fn invert(shell: Shell) -> Shell {
    match shell {
        Shell::Live => {
            branch!(B::SmItemsInvertLive);
            Shell::Blank
        }
        Shell::Blank => {
            branch!(B::SmItemsInvertBlank);
            Shell::Live
        }
    }
}

/// `flip`.
pub(crate) fn flip(direction: Direction) -> Direction {
    match direction {
        Direction::Clockwise => {
            branch!(B::SmItemsFlipClockwise);
            Direction::CounterClockwise
        }
        Direction::CounterClockwise => {
            branch!(B::SmItemsFlipCounterClockwise);
            Direction::Clockwise
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Load, RoundRules, Table};
    use crate::state::{Decks, FirstDeathCheck, Phase, SeatRecord, World};

    const S0: Seat = Seat::Seat0;
    const S1: Seat = Seat::Seat1;
    const S2: Seat = Seat::Seat2;
    const S3: Seat = Seat::Seat3;

    fn config(table: Table) -> Result<Config, crate::RuleError> {
        Config::new(table, &[RoundRules::default_round()])
    }

    fn state(table: Table) -> State {
        let record = SeatRecord {
            health: 3,
            jam: Jam::Free,
            cash: 0,
            slots: Slots::EMPTY,
        };
        State {
            world: World {
                before_round: false,
                round_index: 0,
                load_index: 0,
                first_sequence: false,
                round_health: 3,
                first_turn: S0,
                turn: Some(S0),
                direction: Direction::Clockwise,
                first_death: None,
                checking_first_death: FirstDeathCheck::Off,
                item_amount: 2,
                sawed: false,
                gun: Gun::EMPTY,
                shown: Load { live: 0, blank: 0 },
                decks: Decks::full(),
            },
            players: Ring::fill(table, record),
            grabs: Grabs {
                distributing: true,
                grabbing: Ring::fill(table, false),
                holding: Ring::fill(table, None),
                granted: Ring::fill(table, 0),
                intake: Ring::fill(table, false),
            },
            phase: Phase::Idle { seat: S0 },
        }
    }

    fn edit(state: &mut State, seat: Seat, f: impl FnOnce(&mut SeatRecord)) {
        let mut record = state.players.get(seat).unwrap_or(SeatRecord::FRESH);
        f(&mut record);
        state.players = state.players.set(seat, record);
    }

    fn stock(slots: &[(Slot, Item)]) -> Slots {
        slots.iter().fold(Slots::EMPTY, |acc, (slot, item)| acc.put(*slot, Some(*item)))
    }

    #[test]
    fn jam_for_skips_self_dead_and_jammed_seats() {
        let config = config(Table::FourSeats).expect("a valid config");
        let mut s = state(Table::FourSeats);
        edit(&mut s, S2, |r| r.jam = Jam::JammedSkipped);
        edit(&mut s, S3, |r| r.health = 0);
        assert_eq!(jam_for(&config, &s, S0).iter().collect::<Vec<_>>(), [S1]);
        edit(&mut s, S2, |r| r.jam = Jam::Free);
        assert_eq!(jam_for(&config, &s, S1).iter().collect::<Vec<_>>(), [S0, S2]);
    }

    #[test]
    fn steal_for_filters_by_item_and_walks_owners_then_slots() {
        let config = config(Table::ThreeSeats).expect("a valid config");
        let mut s = state(Table::ThreeSeats);
        edit(&mut s, S0, |r| r.slots = stock(&[(Slot::Slot0, Item::Glass)]));
        edit(&mut s, S1, |r| {
            r.slots = stock(&[(Slot::Slot0, Item::Saw), (Slot::Slot1, Item::Adrenaline), (Slot::Slot2, Item::Beer)]);
        });
        edit(&mut s, S2, |r| {
            r.slots = stock(&[(Slot::Slot4, Item::Jammer), (Slot::Slot5, Item::Phone)]);
        });
        let pick = |owner, slot, item| Pick { owner, slot, item };
        assert_eq!(
            steal_for(&config, &s, S0).as_slice(),
            [
                pick(S1, Slot::Slot0, Item::Saw),
                pick(S1, Slot::Slot2, Item::Beer),
                pick(S2, Slot::Slot4, Item::Jammer),
                pick(S2, Slot::Slot5, Item::Phone),
            ]
        );
        // A sawed barrel hides saws. With the other seats dead or jammed the thief has no
        // jam target, which hides jammers; dead owners' items are still candidates.
        s.world.sawed = true;
        edit(&mut s, S1, |r| r.jam = Jam::Jammed);
        edit(&mut s, S2, |r| r.health = 0);
        assert_eq!(
            steal_for(&config, &s, S0).as_slice(),
            [pick(S1, Slot::Slot2, Item::Beer), pick(S2, Slot::Slot5, Item::Phone)]
        );
    }

    #[test]
    fn grab_needs_follow_grabbing_holding_intake_and_distributing() {
        let config = config(Table::ThreeSeats).expect("a valid config");
        let mut s = state(Table::ThreeSeats);
        assert!(grab_needs(&config, &s, S0).is_empty());
        s.grabs.grabbing = s.grabs.grabbing.set(S0, true);
        assert!(grab_needs(&config, &s, S0).is_empty());
        s.grabs.intake = s.grabs.intake.set(S0, true);
        assert_eq!(grab_needs(&config, &s, S0).as_slice(), [GrabOption::TakeItem]);
        s.grabs.distributing = false;
        assert!(grab_needs(&config, &s, S0).is_empty());
        s.grabs.distributing = true;
        s.grabs.holding = s.grabs.holding.set(S0, Some(Item::Beer));
        edit(&mut s, S0, |r| {
            r.slots = stock(&[(Slot::Slot0, Item::Glass), (Slot::Slot3, Item::Saw)]);
        });
        let puts: Vec<_> = [Slot::Slot1, Slot::Slot2, Slot::Slot4, Slot::Slot5, Slot::Slot6, Slot::Slot7]
            .into_iter()
            .map(|slot| GrabOption::PutAt { slot })
            .collect();
        assert_eq!(grab_needs(&config, &s, S0).as_slice(), puts);
        assert!(grab_needs(&config, &s, S3).is_empty());
    }

    #[test]
    fn uses_hide_saw_jammer_and_adrenaline_without_their_preconditions() {
        let config = config(Table::ThreeSeats).expect("a valid config");
        let mut s = state(Table::ThreeSeats);
        edit(&mut s, S0, |r| {
            r.slots = stock(&[
                (Slot::Slot0, Item::Adrenaline),
                (Slot::Slot1, Item::Saw),
                (Slot::Slot2, Item::Jammer),
                (Slot::Slot3, Item::Beer),
            ]);
        });
        edit(&mut s, S1, |r| r.slots = stock(&[(Slot::Slot0, Item::Beer)]));
        s.world.sawed = true;
        let at = |slot, item| UseAt { slot, item };
        assert_eq!(
            uses(&config, &s, S0).as_slice(),
            [
                at(Slot::Slot0, Item::Adrenaline),
                at(Slot::Slot2, Item::Jammer),
                at(Slot::Slot3, Item::Beer)
            ]
        );
        // No jam target and nothing to steal: adrenaline and jammer drop out.
        edit(&mut s, S1, |r| r.health = 0);
        edit(&mut s, S2, |r| r.health = 0);
        edit(&mut s, S1, |r| r.slots = Slots::EMPTY);
        s.world.sawed = false;
        assert_eq!(
            uses(&config, &s, S0).as_slice(),
            [at(Slot::Slot1, Item::Saw), at(Slot::Slot3, Item::Beer)]
        );
    }
}
