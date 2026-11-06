//! `sm/items.bend`: item pools, distribution needs, and the use, jam and
//! steal options. Every function that reads sm's records (`S.State`) takes
//! the config and the simple state, since the config is not in the state.

use arrayvec::ArrayVec;

use crate::domain::{AmountRule, Config, Direction, Gun, Item, ItemRule, Items, Ring, Seat, Seats, Shell, Slot, Slots};
use crate::rules;
use crate::state::{Grabs, Jam, Players, State};

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
const fn keep(kept: bool) -> bool {
    if kept {
        bend_arm!("sm/items:keep:True{}");
    } else {
        bend_arm!("sm/items:keep:False{}");
    }
    kept
}

/// `is_none`.
const fn is_none(found: Option<Item>) -> bool {
    match found {
        None => {
            bend_arm!("sm/items:is_none:None{}");
            true
        }
        Some(_) => {
            bend_arm!("sm/items:is_none:Some{item}");
            false
        }
    }
}

/// `has_items`.
fn has_items(items: Items) -> bool {
    match items.split_first() {
        None => {
            bend_arm!("sm/items:has_items:Nil{}");
            false
        }
        Some(_) => {
            bend_arm!("sm/items:has_items:x <> rest");
            true
        }
    }
}

/// `has_seats`.
fn has_seats(seats: Seats) -> bool {
    match seats.first() {
        None => {
            bend_arm!("sm/items:has_seats:Nil{}");
            false
        }
        Some(_) => {
            bend_arm!("sm/items:has_seats:x <> rest");
            true
        }
    }
}

/// `slots.items`: the eight contents in slot order.
fn slots_items(slots: Slots) -> impl Iterator<Item = Option<Item>> {
    bend_arm!("sm/items:slots.items:D.Slots{a, b, c, d, e, f, g, h}");
    Slot::ORDER.into_iter().map(move |slot| slots.get(slot))
}

/// `occupied`.
#[allow(clippy::single_match, clippy::collapsible_match, reason = "one arm per Bend case, even when it only names the branch")]
fn occupied(slots: Slots) -> u32 {
    let mut count = 0u32;
    for found in slots_items(slots) {
        match found {
            None => {
                bend_arm!("sm/items:occupied:None{} <> rest");
            }
            Some(_) => {
                bend_arm!("sm/items:occupied:Some{item} <> rest");
                count = count.saturating_add(1);
            }
        }
    }
    bend_arm!("sm/items:occupied:Nil{}");
    count
}

/// `bool.nat`.
const fn bool_nat(b: bool) -> u32 {
    if b {
        bend_arm!("sm/items:bool.nat:True{}");
        1
    } else {
        bend_arm!("sm/items:bool.nat:False{}");
        0
    }
}

/// `copies.one`.
const fn copies_one(found: Option<Item>, item: Item) -> u32 {
    match found {
        None => {
            bend_arm!("sm/items:copies.one:None{}");
            0
        }
        Some(actual) => {
            bend_arm!("sm/items:copies.one:Some{actual}");
            bool_nat(actual.rank() == item.rank())
        }
    }
}

/// `copies`.
fn copies(slots: Slots, item: Item) -> u32 {
    let mut total = 0u32;
    for found in slots_items(slots) {
        bend_arm!("sm/items:copies:x <> rest");
        total = total.saturating_add(copies_one(found, item));
    }
    bend_arm!("sm/items:copies:Nil{}");
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
    bend_arm!("sm/items:grabs.open:S.Grabs{distributing, grabbing, holding, granted, intake}");
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
        bend_arm!("sm/items:grabs.open_all:seat <> rest");
        grabs = grabs_open(grabs, seat);
    }
    bend_arm!("sm/items:grabs.open_all:Nil{}");
    grabs
}

/// `grabs.stop_intake`.
pub(crate) fn grabs_stop_intake(grabs: Grabs, seat: Seat) -> Grabs {
    bend_arm!("sm/items:grabs.stop_intake:S.Grabs{distributing, grabbing, holding, granted, intake}");
    Grabs { intake: grabs.intake.set(seat, false), ..grabs }
}

/// `grabs.give`.
pub(crate) fn grabs_give(grabs: Grabs, seat: Seat, item: Item) -> Grabs {
    bend_arm!("sm/items:grabs.give:S.Grabs{distributing, grabbing, holding, granted, intake}");
    Grabs {
        holding: grabs.holding.set(seat, Some(item)),
        granted: grabs.granted.set(seat, seat_granted(&grabs, seat).saturating_add(1)),
        intake: grabs.intake.set(seat, false),
        ..grabs
    }
}

/// `grabs.close`.
pub(crate) fn grabs_close(grabs: Grabs, seat: Seat) -> Grabs {
    bend_arm!("sm/items:grabs.close:S.Grabs{distributing, grabbing, holding, granted, intake}");
    Grabs { grabbing: grabs.grabbing.set(seat, false), ..grabs }
}

/// `grabs.placed`: a placed item leaves the hand; intake reopens only while still grabbing.
pub(crate) fn grabs_placed(grabs: Grabs, seat: Seat) -> Grabs {
    bend_arm!("sm/items:grabs.placed:S.Grabs{distributing, grabbing, holding, granted, intake}");
    Grabs { holding: grabs.holding.set(seat, None), intake: grabs.intake.set(seat, seat_grabbing(&grabs, seat)), ..grabs }
}

/// `owned`: copies in the slots plus the held item.
fn owned(players: &Players, grabs: &Grabs, seat: Seat, item: Item) -> u32 {
    copies(seat_slots(players, seat), item).saturating_add(copies_one(seat_holding(grabs, seat), item))
}

/// `owned.table`.
fn owned_table(seats: Seats, players: &Players, grabs: &Grabs, item: Item) -> u32 {
    let mut total = 0u32;
    for seat in seats.iter() {
        bend_arm!("sm/items:owned.table:seat <> rest");
        total = total.saturating_add(owned(players, grabs, seat, item));
    }
    bend_arm!("sm/items:owned.table:Nil{}");
    total
}

/// `stock.open`.
const fn stock_open(rule: ItemRule, dealt: bool, own: u32, total: u32) -> bool {
    bend_arm!("sm/items:stock.open:D.ItemRule{enabled, per_player, on_table}");
    rule.enabled && dealt && own < rule.per_player && total < rule.on_table
}

/// `pool`: the items `seat` may still be granted, in item order. Held items
/// count against both caps.
pub(crate) fn pool(config: &Config, state: &State, seat: Seat) -> Items {
    let table = config.table();
    let rules = rules::world_rules(config, &state.world);
    // `pool.go` over `item.order()`.
    bend_arm!("sm/items:round.items:D.RoundRules{_, _, items}");
    let mut pool = Items::EMPTY;
    for item in Item::ORDER {
        bend_arm!("sm/items:pool.go:+item <> rest");
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
    bend_arm!("sm/items:pool.go:Nil{}");
    pool
}

/// `alive` (sm/rules.bend).
const fn alive(hp: u32) -> bool {
    match hp {
        0 => {
            bend_arm!("sm/rules:alive:0n");
            false
        }
        1.. => {
            bend_arm!("sm/rules:alive:1n+rest");
            true
        }
    }
}

/// `begin.can`: a new round ignores health and full slots.
fn begin_can(new_round: bool, hp: u32, slots: Slots) -> bool {
    let living = alive(hp);
    let room = occupied(slots) < 8;
    new_round || (living && room)
}

/// `begin.go`.
fn begin_go(seats: Seats, config: &Config, state: &State, new_round: bool) -> Seats {
    let mut kept = Seats::EMPTY;
    for seat in seats.iter() {
        bend_arm!("sm/items:begin.go:+seat <> rest");
        let can = begin_can(new_round, seat_health(&state.players, seat), seat_slots(&state.players, seat));
        let stocked = has_items(pool(config, state, seat));
        if keep(can && stocked) {
            kept.push(seat);
        }
    }
    bend_arm!("sm/items:begin.go:Nil{}");
    kept
}

/// `begin.seats`: who begins grabbing. The caller passes the stored amount,
/// whose zero selects no one.
pub(crate) fn begin_seats(config: &Config, state: &State, new_round: bool, amount: u32) -> Seats {
    match amount {
        0 => {
            bend_arm!("sm/items:begin.seats:0n");
            Seats::EMPTY
        }
        1.. => {
            bend_arm!("sm/items:begin.seats:_");
            begin_go(config.table().seats(), config, state, new_round)
        }
    }
}

/// `puts.here`.
#[allow(clippy::single_match, clippy::collapsible_match, reason = "one arm per Bend case, even when it only names the branch")]
fn puts_here(found: Option<Item>, slot: Slot, out: &mut GrabOptions) {
    match found {
        None => {
            bend_arm!("sm/items:puts.here:None{}");
            let _ = out.try_push(GrabOption::PutAt { slot });
        }
        Some(_) => {
            bend_arm!("sm/items:puts.here:Some{item}");
        }
    }
}

/// `puts`: a put at every empty slot.
fn puts(inventory: Slots, out: &mut GrabOptions) {
    for slot in Slot::ORDER {
        bend_arm!("sm/items:puts:+slot <> rest");
        puts_here(inventory.get(slot), slot, out);
    }
    bend_arm!("sm/items:puts:Nil{}");
}

/// `grab.intake`.
fn grab_intake(open: bool, out: &mut GrabOptions) {
    if open {
        bend_arm!("sm/items:grab.intake:True{}");
        let _ = out.try_push(GrabOption::TakeItem);
    } else {
        bend_arm!("sm/items:grab.intake:False{}");
    }
}

/// `grab.offer`.
fn grab_offer(grabbing: bool, holding: Option<Item>, open: bool, slots: Slots) -> GrabOptions {
    let mut out = GrabOptions::new();
    match (grabbing, holding) {
        (true, Some(_)) => {
            bend_arm!("sm/items:grab.offer:True{} Some{item}");
            puts(slots, &mut out);
        }
        (true, None) => {
            bend_arm!("sm/items:grab.offer:True{} None{}");
            grab_intake(open, &mut out);
        }
        (false, None | Some(_)) => {
            bend_arm!("sm/items:grab.offer:False{} _");
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
    bend_arm!("sm/items:grab.needs.go:+seat <> rest");
    let grabs = &state.grabs;
    let open = seat_intake(grabs, seat) && grabs.distributing;
    grab_offer(seat_grabbing(grabs, seat), seat_holding(grabs, seat), open, seat_slots(&state.players, seat))
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
        bend_arm!("sm/items:finish.ended:D.At{seat, grabbing} <> rest");
        ended = !grabbing && ended;
    }
    bend_arm!("sm/items:finish.ended:Nil{}");
    ended
}

/// `finish.empty`.
fn finish_empty(seats: Seats, config: &Config, state: &State) -> bool {
    let mut empty = true;
    for seat in seats.iter() {
        bend_arm!("sm/items:finish.empty:seat <> rest");
        let stocked = has_items(pool(config, state, seat));
        empty = !stocked && empty;
    }
    bend_arm!("sm/items:finish.empty:Nil{}");
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
        bend_arm!("sm/items:stalled:+seat <> rest");
        let grabs = &state.grabs;
        let grabbing = seat_grabbing(grabs, seat);
        let empty_handed = is_none(seat_holding(grabs, seat));
        let other = seat != placing;
        let dry = !has_items(pool(config, state, seat));
        if keep(grabbing && empty_handed && other && dry) {
            out.push(seat);
        }
    }
    bend_arm!("sm/items:stalled:Nil{}");
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
        match holding {
            None => {
                bend_arm!("sm/items:holders:D.At{seat, None{}} <> rest");
            }
            Some(_) => {
                bend_arm!("sm/items:holders:D.At{seat, Some{item}} <> rest");
                return true;
            }
        }
    }
    bend_arm!("sm/items:holders:Nil{}");
    false
}

/// `amount.live`: the end-of-turn amount draw is live while distributing, or
/// when an exhausted, winnerless gun would start a distribution.
pub(crate) const fn amount_live(rule: AmountRule, distributing: bool, reload: bool) -> bool {
    match rule {
        AmountRule::Random => {
            bend_arm!("sm/items:amount.live:D.RandomAmount{}");
            distributing || reload
        }
        AmountRule::Fixed(_) => {
            bend_arm!("sm/items:amount.live:D.FixedAmount{amount}");
            false
        }
    }
}

/// `winnerless`.
const fn winnerless(winner: Option<Seat>) -> bool {
    match winner {
        None => {
            bend_arm!("sm/items:winnerless:None{}");
            true
        }
        Some(_) => {
            bend_arm!("sm/items:winnerless:Some{seat}");
            false
        }
    }
}

/// `gun.empty`.
const fn gun_empty(gun: Gun) -> bool {
    match gun.split_first() {
        None => {
            bend_arm!("sm/items:gun.empty:Nil{}");
            true
        }
        Some(_) => {
            bend_arm!("sm/items:gun.empty:shell <> rest");
            false
        }
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
        bend_arm!("sm/items:jam.options:D.At{+seat, hp} <> rest");
        let other = seat != by;
        let living = alive(record.health);
        let free = !seat_jammed(players, seat);
        if keep(other && living && free) {
            out.push(seat);
        }
    }
    bend_arm!("sm/items:jam.options:Nil{}");
    out
}

/// `jam.for`: the living, unjammed seats other than `by`.
pub(crate) fn jam_for(_config: &Config, state: &State, by: Seat) -> Seats {
    jam_options(&state.players, by)
}

/// `jam.any`.
fn jam_any(options: Seats) -> bool {
    match options.first() {
        None => {
            bend_arm!("sm/items:jam.any:Nil{}");
            false
        }
        Some(_) => {
            bend_arm!("sm/items:jam.any:option <> rest");
            true
        }
    }
}

/// `steal.fits`: adrenaline never, a saw only while the barrel is whole, a
/// jammer only if the thief has a target, everything else always.
const fn steal_fits(item: Item, sawed: bool, targets: bool) -> bool {
    match item {
        Item::Adrenaline => {
            bend_arm!("sm/items:steal.fits:D.Adrenaline{}");
            false
        }
        Item::Saw => {
            bend_arm!("sm/items:steal.fits:D.Saw{}");
            !sawed
        }
        Item::Jammer => {
            bend_arm!("sm/items:steal.fits:D.Jammer{}");
            targets
        }
        Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            bend_arm!("sm/items:steal.fits:_");
            true
        }
    }
}

/// `steal.here`.
#[allow(clippy::single_match, clippy::collapsible_match, reason = "one arm per Bend case, even when it only names the branch")]
fn steal_here(found: Option<Item>, owner: Seat, slot: Slot, sawed: bool, targets: bool, out: &mut Picks) {
    match found {
        None => {
            bend_arm!("sm/items:steal.here:None{}");
        }
        Some(item) => {
            bend_arm!("sm/items:steal.here:Some{+item}");
            if keep(steal_fits(item, sawed, targets)) {
                let _ = out.try_push(Pick { owner, slot, item });
            }
        }
    }
}

/// `steal.slots`.
fn steal_slots(inventory: Slots, owner: Seat, sawed: bool, targets: bool) -> Picks {
    let mut out = Picks::new();
    for slot in Slot::ORDER {
        bend_arm!("sm/items:steal.slots:+slot <> rest");
        steal_here(inventory.get(slot), owner, slot, sawed, targets, &mut out);
    }
    bend_arm!("sm/items:steal.slots:Nil{}");
    out
}

/// `steal.owner`: `slots` is `steal.slots` of this owner, built either way.
fn steal_owner(own: bool, slots: &Picks, out: &mut Picks) {
    if own {
        bend_arm!("sm/items:steal.owner:True{}");
    } else {
        bend_arm!("sm/items:steal.owner:False{}");
        for pick in slots {
            let _ = out.try_push(*pick);
        }
    }
}

/// `steal.owners`.
fn steal_owners(players: &Players, thief: Seat, sawed: bool, targets: bool) -> Picks {
    let mut out = Picks::new();
    for (owner, record) in players.entries() {
        bend_arm!("sm/items:steal.owners:D.At{+owner, inventory} <> rest");
        let slots = steal_slots(record.slots, owner, sawed, targets);
        steal_owner(owner == thief, &slots, &mut out);
    }
    bend_arm!("sm/items:steal.owners:Nil{}");
    out
}

/// `steal.for`: every other seat's occupied slot that fits, dead owners included.
pub(crate) fn steal_for(config: &Config, state: &State, thief: Seat) -> Picks {
    let targets = jam_any(jam_for(config, state, thief));
    steal_owners(&state.players, thief, state.world.sawed, targets)
}

/// `steal.any`.
fn steal_any(options: &Picks) -> bool {
    match options.first() {
        None => {
            bend_arm!("sm/items:steal.any:Nil{}");
            false
        }
        Some(_) => {
            bend_arm!("sm/items:steal.any:option <> rest");
            true
        }
    }
}

/// `use.fits`.
const fn use_fits(item: Item, sawed: bool, targets: bool, steals: bool) -> bool {
    match item {
        Item::Adrenaline => {
            bend_arm!("sm/items:use.fits:D.Adrenaline{}");
            steals
        }
        Item::Saw => {
            bend_arm!("sm/items:use.fits:D.Saw{}");
            !sawed
        }
        Item::Jammer => {
            bend_arm!("sm/items:use.fits:D.Jammer{}");
            targets
        }
        Item::Glass | Item::Cigarettes | Item::Beer | Item::Phone | Item::Inverter | Item::Remote => {
            bend_arm!("sm/items:use.fits:_");
            true
        }
    }
}

/// `use.here`.
#[allow(clippy::single_match, clippy::collapsible_match, reason = "one arm per Bend case, even when it only names the branch")]
fn use_here(found: Option<Item>, slot: Slot, sawed: bool, targets: bool, steals: bool, out: &mut Uses) {
    match found {
        None => {
            bend_arm!("sm/items:use.here:None{}");
        }
        Some(item) => {
            bend_arm!("sm/items:use.here:Some{+item}");
            if keep(use_fits(item, sawed, targets, steals)) {
                let _ = out.try_push(UseAt { slot, item });
            }
        }
    }
}

/// `use.slots`.
fn use_slots(inventory: Slots, sawed: bool, targets: bool, steals: bool) -> Uses {
    let mut out = Uses::new();
    for slot in Slot::ORDER {
        bend_arm!("sm/items:use.slots:+slot <> rest");
        use_here(inventory.get(slot), slot, sawed, targets, steals, &mut out);
    }
    bend_arm!("sm/items:use.slots:Nil{}");
    out
}

/// `uses`: ordinary item use, with the adrenaline rule of M4.
pub(crate) fn uses(config: &Config, state: &State, seat: Seat) -> Uses {
    let targets = jam_any(jam_for(config, state, seat));
    let steals = steal_any(&steal_for(config, state, seat));
    use_slots(seat_slots(&state.players, seat), state.world.sawed, targets, steals)
}

/// `ends_turn`.
pub(crate) const fn ends_turn(item: Item, length: u32) -> bool {
    match item {
        Item::Beer => {
            bend_arm!("sm/items:ends_turn:D.Beer{}");
            length == 1
        }
        Item::Saw
        | Item::Glass
        | Item::Jammer
        | Item::Cigarettes
        | Item::Phone
        | Item::Inverter
        | Item::Adrenaline
        | Item::Remote => {
            bend_arm!("sm/items:ends_turn:_");
            false
        }
    }
}

/// `invert`.
pub(crate) const fn invert(shell: Shell) -> Shell {
    match shell {
        Shell::Live => {
            bend_arm!("sm/items:invert:D.Live{}");
            Shell::Blank
        }
        Shell::Blank => {
            bend_arm!("sm/items:invert:D.Blank{}");
            Shell::Live
        }
    }
}

/// `flip`.
pub(crate) const fn flip(direction: Direction) -> Direction {
    match direction {
        Direction::Clockwise => {
            bend_arm!("sm/items:flip:D.Clockwise{}");
            Direction::CounterClockwise
        }
        Direction::CounterClockwise => {
            bend_arm!("sm/items:flip:D.CounterClockwise{}");
            Direction::Clockwise
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{Load, RoundRules, Table};
    use crate::state::{Decks, Phase, SeatRecord, World};

    const S0: Seat = Seat::Seat0;
    const S1: Seat = Seat::Seat1;
    const S2: Seat = Seat::Seat2;
    const S3: Seat = Seat::Seat3;

    fn config(table: Table) -> Result<Config, crate::RuleError> {
        Config::new(table, &[RoundRules::default_round()])
    }

    fn state(table: Table) -> State {
        let record = SeatRecord { health: 3, jam: Jam::Free, cash: 0, slots: Slots::EMPTY };
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
                checking_first_death: false,
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
    fn jam_for_skips_self_dead_and_jammed_seats() -> Result<(), crate::RuleError> {
        let config = config(Table::FourSeats)?;
        let mut s = state(Table::FourSeats);
        edit(&mut s, S2, |r| r.jam = Jam::JammedSkipped);
        edit(&mut s, S3, |r| r.health = 0);
        assert_eq!(jam_for(&config, &s, S0).iter().collect::<Vec<_>>(), [S1]);
        edit(&mut s, S2, |r| r.jam = Jam::Free);
        assert_eq!(jam_for(&config, &s, S1).iter().collect::<Vec<_>>(), [S0, S2]);
        Ok(())
    }

    #[test]
    fn steal_for_filters_by_item_and_walks_owners_then_slots() -> Result<(), crate::RuleError> {
        let config = config(Table::ThreeSeats)?;
        let mut s = state(Table::ThreeSeats);
        edit(&mut s, S0, |r| r.slots = stock(&[(Slot::Slot0, Item::Glass)]));
        edit(&mut s, S1, |r| r.slots = stock(&[(Slot::Slot0, Item::Saw), (Slot::Slot1, Item::Adrenaline), (Slot::Slot2, Item::Beer)]));
        edit(&mut s, S2, |r| r.slots = stock(&[(Slot::Slot4, Item::Jammer), (Slot::Slot5, Item::Phone)]));
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
        Ok(())
    }

    #[test]
    fn grab_needs_follow_grabbing_holding_intake_and_distributing() -> Result<(), crate::RuleError> {
        let config = config(Table::ThreeSeats)?;
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
        edit(&mut s, S0, |r| r.slots = stock(&[(Slot::Slot0, Item::Glass), (Slot::Slot3, Item::Saw)]));
        let puts: Vec<_> = [Slot::Slot1, Slot::Slot2, Slot::Slot4, Slot::Slot5, Slot::Slot6, Slot::Slot7]
            .into_iter()
            .map(|slot| GrabOption::PutAt { slot })
            .collect();
        assert_eq!(grab_needs(&config, &s, S0).as_slice(), puts);
        assert!(grab_needs(&config, &s, S3).is_empty());
        Ok(())
    }

    #[test]
    fn uses_hide_saw_jammer_and_adrenaline_without_their_preconditions() -> Result<(), crate::RuleError> {
        let config = config(Table::ThreeSeats)?;
        let mut s = state(Table::ThreeSeats);
        edit(&mut s, S0, |r| {
            r.slots = stock(&[(Slot::Slot0, Item::Adrenaline), (Slot::Slot1, Item::Saw), (Slot::Slot2, Item::Jammer), (Slot::Slot3, Item::Beer)]);
        });
        edit(&mut s, S1, |r| r.slots = stock(&[(Slot::Slot0, Item::Beer)]));
        s.world.sawed = true;
        let at = |slot, item| UseAt { slot, item };
        assert_eq!(
            uses(&config, &s, S0).as_slice(),
            [at(Slot::Slot0, Item::Adrenaline), at(Slot::Slot2, Item::Jammer), at(Slot::Slot3, Item::Beer)]
        );
        // No jam target and nothing to steal: adrenaline and jammer drop out.
        edit(&mut s, S1, |r| r.health = 0);
        edit(&mut s, S2, |r| r.health = 0);
        edit(&mut s, S1, |r| r.slots = Slots::EMPTY);
        s.world.sawed = false;
        assert_eq!(uses(&config, &s, S0).as_slice(), [at(Slot::Slot1, Item::Saw), at(Slot::Slot3, Item::Beer)]);
        Ok(())
    }
}
