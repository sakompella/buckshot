# Distribution goes one grab per seat in turn, from the seat after the first shooter

In the game every client grabs from the briefcase at once, and the host serves each request as it arrives. Table caps count every seat's items. At default settings that means one jammer on the table, and two remotes at three or four seats. So whoever grabs first can take a capped item from everyone else. The machine and the reference offer every grabbing seat's move at once and leave the order to the caller. Our callers used to pick the lowest socket first: `driver.bend`, the web's `aiPrompt` and the arena's `onTurn`. That seat took all its items before the next seat began, which gave it first claim on capped items in every simulated distribution.

We chose one grab per seat in turn, in socket order, starting from the seat after the first shooter (`world.first_turn`). The simple machine distributes this way on its own. `driver.bend` serves grab prompts the same way, and the web bots and arena agents use its chooser through `web.bend`'s `prompt.next`. It is the closest fixed order to people grabbing at once at the same pace. Starting after the first shooter means the seat that shoots first also picks last in each pass, and first claim moves around the table as play moves. The strong machine can produce this order, so the simple machine still refines it.

## Considered options

- Each seat takes all its items, lowest socket first. This was the old driver. Rejected, because it is a bias of our driver and not a game rule.
- One grab per seat in turn from the lowest socket. Rejected, because seat 0 still picks first in every pass.
- One grab per seat in turn, rotating the start by one seat each distribution. Rejected, because it needs a counter that only the simple machine would keep.

## Consequences

- Win rates and seat statistics simulated before this change carry a seat-0 distribution bias.
- Some bias remains. Within a pass, the seat after the first shooter picks first. It follows play rather than a fixed seat, but it is not uniform.
- Other grab schedules are real game behaviour, and the simple machine cannot represent them. Examples are another seat grabbing while one seat still holds an item, or one seat grabbing twice in a row while another could grab.
