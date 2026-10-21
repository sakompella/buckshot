# Simple item moves

The simple machine keeps each seat's eight indexed slots, so boards, `Placed` and `Used` stay the same as the strong machine's. Its moves name items, not slots, matching what an agent says: "Use beer", "Steal beer from Player B". A move acts on the first slot that holds the item. That includes the first adrenaline for a steal and the first jammer for a jam. A drawn item goes into the first free slot at once, with no place step. No rule reads a slot index. Pools and capacity count items (`copies`, `occupied < 8`), and slots only order menus and appear in events.

## Considered options

- Keep slot choices in moves. Rejected, because agents already dedupe moves that differ only in a slot and keep the first one.
- Make the inventory a multiset. Rejected by the user, so the board and events keep their shape and the mapping to the strong machine stays an embedding.

## Consequences

- The simple machine cannot represent two strong-machine behaviours. One is placing in a later free slot. The other is using or stealing a later copy of an item that also sits in an earlier slot. Both change only which slots are filled.
