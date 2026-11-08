//! `sm/items.bend`: item pools, distribution needs, and the use, jam and
//! steal options. Every function that reads sm's records (`S.State`) takes
//! the config and the simple state, since the config is not in the state.

use arrayvec::ArrayVec;

use crate::branch::B;
use crate::domain::{AmountRule, Config, Direction, Gun, Item, ItemRule, Items, Ring, Seat, Seats, Shell, Slot, Slots, Table};
use crate::rules;
use crate::state::{Grabs, Jam, Players, State};

/// sm/state.bend `IdleOption::UseAt` (`uses` only makes these).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct UseAt {
    pub slot: Slot,
    pub item: Item,
}

/// At most one use per slot. Every list type here is sized for its most
/// entries, so `push` (which panics rather than drop an entry) never fails.
pub(crate) type Uses = ArrayVec<UseAt, 8>;

/// sm/state.bend `StealOption::Pick`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Pick {
    pub owner: Seat,
    pub slot: Slot,
    pub item: Item,
}

/// At most three owners (every seat but the thief) with eight slots each.
pub(crate) type Picks = ArrayVec<Pick, PICKS_CAPACITY>;
pub(crate) const PICKS_CAPACITY: usize = 24;

/// sm/state.bend `GrabOption`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum GrabOption {
    TakeItem,
    PutAt { slot: Slot },
}

/// A put per slot and one take.
pub(crate) type GrabOptions = ArrayVec<GrabOption, 9>;

/// `value.or` over `ring.get`: a seat missing from a ring reads as `fallback`.
fn read<T: Copy>(ring: &Ring<T>, seat: Seat, fallback: T) -> T {
    ring.get(seat).unwrap_or(fallback)
}

/// `keep`: runs `on_keep` when the element is kept in the result list.
pub(crate) fn keep(kept: bool, on_keep: impl FnOnce()) {
    if kept {
        branch!(B::SmItemsKeepTrue);
        on_keep();
    } else {
        branch!(B::SmItemsKeepFalse);
    }
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
    Slot::ORDER.into_iter().map(move |slot| slots.get(slot))
}

/// `occupied`.
fn occupied(slots: Slots) -> u32 {
    let mut count = 0u32;
    let mut found = slots_items(slots);
    loop {
        match found.next() {
            None => {
                branch!(B::SmItemsOccupiedNil);
                return count;
            }
            Some(None) => {
                branch!(B::SmItemsOccupiedNoneCons);
            }
            Some(Some(_)) => {
                branch!(B::SmItemsOccupiedSomeCons);
                count = count.saturating_add(1);
            }
        }
    }
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

/// `slots.copies`.
fn slots_copies(slots: Slots, item: Item) -> u32 {
    slots_items(slots).fold(0u32, |total, found| total.saturating_add(copies_one(found, item)))
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
    Grabs {
        intake: grabs.intake.set(seat, false),
        ..grabs
    }
}

/// `grabs.give`.
pub(crate) fn grabs_give(grabs: Grabs, seat: Seat, item: Item) -> Grabs {
    Grabs {
        holding: grabs.holding.set(seat, Some(item)),
        granted: grabs.granted.set(seat, seat_granted(&grabs, seat).saturating_add(1)),
        intake: grabs.intake.set(seat, false),
        ..grabs
    }
}

/// `grabs.close`.
pub(crate) fn grabs_close(grabs: Grabs, seat: Seat) -> Grabs {
    Grabs {
        grabbing: grabs.grabbing.set(seat, false),
        ..grabs
    }
}

/// `grabs.placed`: a placed item leaves the hand; intake reopens only while still grabbing.
pub(crate) fn grabs_placed(grabs: Grabs, seat: Seat) -> Grabs {
    Grabs {
        holding: grabs.holding.set(seat, None),
        intake: grabs.intake.set(seat, seat_grabbing(&grabs, seat)),
        ..grabs
    }
}

/// `seat.copies`: `slots.copies` of the seat's slots, 0 for a seat not at the table.
fn seat_copies(players: &Players, seat: Seat, item: Item) -> u32 {
    match (players.table(), seat) {
        (Table::TwoSeats, Seat::Seat1) => {
            branch!(B::SmItemsSeatCopiesDuoSeatSeat1);
        }
        (Table::TwoSeats, Seat::Seat3) => {
            branch!(B::SmItemsSeatCopiesDuoSeatSeat3);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::ThreeSeats, Seat::Seat0) => {
            branch!(B::SmItemsSeatCopiesTrioSeatSeat0);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::ThreeSeats, Seat::Seat1) => {
            branch!(B::SmItemsSeatCopiesTrioSeatSeat1);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::ThreeSeats, Seat::Seat2) => {
            branch!(B::SmItemsSeatCopiesTrioSeatSeat2);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::FourSeats, Seat::Seat0) => {
            branch!(B::SmItemsSeatCopiesQuadSeatSeat0);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::FourSeats, Seat::Seat1) => {
            branch!(B::SmItemsSeatCopiesQuadSeatSeat1);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::FourSeats, Seat::Seat2) => {
            branch!(B::SmItemsSeatCopiesQuadSeatSeat2);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::FourSeats, Seat::Seat3) => {
            branch!(B::SmItemsSeatCopiesQuadSeatSeat3);
        }
        #[cfg(feature = "seats-2-4")]
        (Table::TwoSeats, Seat::Seat0 | Seat::Seat2) | (Table::ThreeSeats, Seat::Seat3) => {
            branch!(B::SmItemsSeatCopiesAny);
            return 0;
        }
        #[cfg(not(feature = "seats-2-4"))]
        (Table::TwoSeats, Seat::Seat0 | Seat::Seat2) => {
            branch!(B::SmItemsSeatCopiesAny);
            return 0;
        }
    }
    slots_copies(seat_slots(players, seat), item)
}

/// `owned`: copies in the slots plus the held item.
fn owned(players: &Players, grabs: &Grabs, seat: Seat, item: Item) -> u32 {
    seat_copies(players, seat, item).saturating_add(copies_one(seat_holding(grabs, seat), item))
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

/// `stock.total`: the table's count, read only while the seat's own count
/// is under its cap.
fn stock_total(own_open: bool, total: impl FnOnce() -> u32, on_table: u32) -> bool {
    if own_open {
        branch!(B::SmItemsStockTotalTrue);
        total() < on_table
    } else {
        branch!(B::SmItemsStockTotalFalse);
        false
    }
}

/// `stock.counted`: whether `seat` may still be granted `item`; the counts are
/// read only for an enabled, dealt item.
fn stock_counted(rule: ItemRule, dealt: bool, state: &State, seat: Seat, item: Item, seats: Seats) -> bool {
    if rule.enabled && dealt {
        branch!(B::SmItemsStockCountedItemRuleTrueTrue);
        let own = owned(&state.players, &state.grabs, seat, item);
        stock_total(
            own < rule.per_player,
            || owned_table(seats, &state.players, &state.grabs, item),
            rule.on_table,
        )
    } else {
        branch!(B::SmItemsStockCountedAny);
        false
    }
}

/// `pool`: the items `seat` may still be granted, in item order. Held items
/// count against both caps.
pub(crate) fn pool(config: &Config, state: &State, seat: Seat) -> Items {
    let table = config.table();
    let rules = rules::world_rules_ref(config, &state.world);
    // `pool.go` over `item.order()`.
    let mut pool = Items::EMPTY;
    for item in Item::ORDER {
        branch!(B::SmItemsPoolGoCons);
        let open = stock_counted(rules.item(item), item.dealt_at(table), state, seat, item, table.seats());
        keep(open, || pool = pool.with(item));
    }
    branch!(B::SmItemsPoolGoNil);
    pool
}

/// `stocked` with `pool.any`: whether `seat`'s pool has an item, stopping at
/// the first.
fn stocked(config: &Config, state: &State, seat: Seat) -> bool {
    let table = config.table();
    let rules = rules::world_rules_ref(config, &state.world);
    let mut items = Item::ORDER.into_iter();
    let mut found = false;
    loop {
        match (items.next(), found) {
            (_, true) => {
                branch!(B::SmItemsPoolAnyTrue);
                return true;
            }
            (None, false) => {
                branch!(B::SmItemsPoolAnyNilFalse);
                return false;
            }
            (Some(item), false) => {
                branch!(B::SmItemsPoolAnyConsFalse);
                found = stock_counted(rules.item(item), item.dealt_at(table), state, seat, item, table.seats());
            }
        }
    }
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
        let stocked = stocked(config, state, seat);
        keep(can && stocked, || kept.push(seat));
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
        out.push(GrabOption::PutAt { slot });
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
        out.push(GrabOption::TakeItem);
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

/// The options of every seat (`grab.needs`); a seat not at the table has none.
#[derive(Default)]
pub(crate) struct Needs([GrabOptions; 4]);

impl Needs {
    pub(crate) fn of(&self, seat: Seat) -> &[GrabOption] {
        self.0.get(seat.index()).map_or(&[], ArrayVec::as_slice)
    }

    fn set(&mut self, seat: Seat, options: GrabOptions) {
        if let Some(cell) = self.0.get_mut(seat.index()) {
            *cell = options;
        }
    }
}

/// `grab.needs` with `grab.needs.go`.
pub(crate) fn grab_needs(config: &Config, state: &State) -> Needs {
    let mut needs = Needs::default();
    let grabs = &state.grabs;
    for seat in config.table().seats().iter() {
        branch!(B::SmItemsGrabNeedsGoCons);
        let open = seat_intake(grabs, seat) && grabs.distributing;
        let offer = grab_offer(
            seat_grabbing(grabs, seat),
            seat_holding(grabs, seat),
            open,
            seat_slots(&state.players, seat),
        );
        needs.set(seat, offer);
    }
    branch!(B::SmItemsGrabNeedsGoNil);
    needs
}

/// `placing.last`: the placing seat still holds its item here.
pub(crate) fn placing_last(config: &Config, state: &State, seat: Seat) -> bool {
    let grabs = &state.grabs;
    let empty_pool = !stocked(config, state, seat);
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
        let stocked = stocked(config, state, seat);
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
        let dry = !stocked(config, state, seat);
        keep(grabbing && empty_handed && other && dry, || out.push(seat));
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
    let mut entries = grabs.holding.entries();
    loop {
        match entries.next() {
            None => {
                branch!(B::SmItemsHoldersNil);
                return false;
            }
            Some((_, None)) => {
                branch!(B::SmItemsHoldersAtNoneCons);
            }
            Some((_, Some(_))) => {
                branch!(B::SmItemsHoldersAtSomeCons);
                return true;
            }
        }
    }
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

/// `reload.ready`: a loaded gun answers alone.
fn reload_ready(gun: Gun, config: &Config, state: &State, winner: Option<Seat>) -> bool {
    if gun.split_first().is_none() {
        branch!(B::SmItemsReloadReadyNil);
        let winnerless = winnerless(winner);
        let begins = has_seats(begin_seats(config, state, false, 1));
        winnerless && begins
    } else {
        branch!(B::SmItemsReloadReadyCons);
        false
    }
}

/// `reload.wanted`.
pub(crate) fn reload_wanted(config: &Config, state: &State, winner: Option<Seat>) -> bool {
    reload_ready(state.world.gun, config, state, winner)
}

/// `jam.options`.
fn jam_options(players: &Players, by: Seat) -> Seats {
    let mut out = Seats::EMPTY;
    for (seat, record) in players.entries() {
        branch!(B::SmItemsJamOptionsAtCons);
        let other = seat != by;
        let living = rules::alive(record.health);
        let free = !seat_jammed(players, seat);
        keep(other && living && free, || out.push(seat));
    }
    branch!(B::SmItemsJamOptionsNil);
    out
}

/// `jam.of`: the living, unjammed seats other than `by`.
pub(crate) fn jam_of(players: &Players, by: Seat) -> Seats {
    jam_options(players, by)
}

/// `jam.any`.
pub(crate) fn jam_any(options: Seats) -> bool {
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
        keep(steal_fits(item, sawed, targets), || out.push(Pick { owner, slot, item }));
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

/// `steal.owner`.
fn steal_owner(own: bool, owner: Seat, inventory: Slots, sawed: bool, targets: bool, out: &mut Picks) {
    if own {
        branch!(B::SmItemsStealOwnerTrue);
    } else {
        branch!(B::SmItemsStealOwnerFalse);
        let slots = steal_slots(inventory, owner, sawed, targets);
        for pick in slots {
            out.push(pick);
        }
    }
}

/// `steal.owners`.
fn steal_owners(players: &Players, thief: Seat, sawed: bool, targets: bool) -> Picks {
    let mut out = Picks::new();
    for (owner, record) in players.entries() {
        branch!(B::SmItemsStealOwnersAtCons);
        steal_owner(owner == thief, owner, record.slots, sawed, targets, &mut out);
    }
    branch!(B::SmItemsStealOwnersNil);
    out
}

/// `steal.with`: every other seat's occupied slot that fits, dead owners
/// included, given whether the thief has a jam target.
pub(crate) fn steal_with(players: &Players, thief: Seat, sawed: bool, targets: bool) -> Picks {
    steal_owners(players, thief, sawed, targets)
}

/// `steal.any`.
pub(crate) fn steal_any(options: &Picks) -> bool {
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
        keep(use_fits(item, sawed, targets, steals), || out.push(UseAt { slot, item }));
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

/// `uses.with`: ordinary item use, with the adrenaline rule of M4, given
/// whether the seat has jam targets and steals.
pub(crate) fn uses_with(players: &Players, seat: Seat, sawed: bool, targets: bool, steals: bool) -> Uses {
    use_slots(seat_slots(players, seat), sawed, targets, steals)
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
