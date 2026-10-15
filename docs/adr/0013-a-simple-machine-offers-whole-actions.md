---
status: accepted
---

# A simple machine offers whole actions

`sim/bend-mp/simple/` is a third model whose only choices are whole actions: Shoot a player, Use an item, Jam a player, Steal an item from a player, and Steal a jammer to jam a player. An agent loop can call it directly, with no chaining. It starts from the strong machine and cuts what exists only because the real game's interface goes one step at a time: picking up the gun, choosing whom to jam or what to steal as a separate mode, choosing a slot, and taking turns at the briefcase. Distribution makes no choices (ADR-0033), and moves name items rather than slots (ADR-0034). A request offers moves to one seat, never to several at once.

The strong machine stays the authority. `simple-abstract.bend` embeds each simple state in a strong-machine state, lists the strong-machine steps of each simple answer, and plays them on the strong machine, refusing any step it does not offer. A fuzz test checks on whole states that every answer is such a chain and lands on the embedded next state with the same notes. It also checks that boards, draws, privacy and the distribution order agree, and that the menu is exactly the deduped strong-machine chains that use first slots. Universal laws in the style of ADR-0014 are in progress. They do not block using the machine.

The simple machine shares the strong machine's records and pure rules, not its step. It may import `sm/state.bend` (World, Players, Seat, Jam, Grabs and Decks), `sm/rules.bend` (turn order, jam steps, shot damage, load and round rules, the winner) and `sm/items.bend` (pools and caps, who begins grabbing, `grab.needs` for who may take or place, `placing.last`, `finished`, `stalled.seats`, usable items, jam targets and steal options). `check.sh` enforces this. A change to those rules changes both machines together.

## Consequences

- Some strong-machine behaviour cannot be represented: other grab schedules (ADR-0033), and later-slot choices (ADR-0034).
- Whether `web/src/agent/moves.ts` switches from its chain search to the simple machine is still open.
