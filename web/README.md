# Buckshot table (web UI)

A web game for the Bend multiplayer rules library in `sim/bend-mp/`, built
on Foldkit 0.167 and Effect 4 and run with bun and Vite. It builds `web.bend` to
JavaScript and plays 2- to 4-seat matches in the browser, on a dark top-down
table: you play by clicking the shotgun, a seat, an item slot or the briefcase. Any seat can be a
human, a Story AI, a DoN AI or an agent (see below). The UI has no rules of its own. Legality,
observation and privacy all come from the machine. See
[`sim/bend-mp/README.md`](../sim/bend-mp/README.md) for the rules library.

## Run

    bun install
    bun run dev        # builds generated/rules.mjs from sim/bend-mp/web.bend, then serves http://localhost:5173/

`bun run rules` needs Bend 2.0.36: `$BEND`, else `bend` on PATH, else the
pinned Nix store path in `scripts/build-rules.ts`. `nix develop` at the repo
root provides it.

Checks:

    bun run typecheck  # tsc --noEmit, strict
    bun run lint       # oxlint with every anti-slop rule and the Effect group, --deny-warnings
    bun run test       # plays full Story and DoN matches through bend.ts at 2, 3 and 4 seats; checks stale answers are rejected
    bun scripts/play.ts [url] [outdir]   # headless Chrome: one human-vs-bot match by clicking the table, one 4-bot autoplay match
    bun scripts/shots.ts [url] [outdir] [WxH ...]   # headless Chrome: a screenshot of each stage of a match, at 1440x900 and 390x844 by default

## Playing

The setup screen picks the number of players, each seat's controller, items
and the seed. In a match the banner says whose view it is and the phase
(Your turn, Grab items, Watch, Match over). Each of the viewer's legal moves is
a dashed outline on the thing it acts on:

| Move | Click |
|---|---|
| Grab | your open briefcase |
| Place | an empty slot on your side |
| Pick up | the shotgun |
| Shoot, Jam | a seat's counter |
| Use an item | the item on your side |
| Steal (adrenaline) | the item on another seat's side |

`src/board.ts` maps each move to its target. Moves that would share a target
get plain buttons instead; the tests check that every legal move of many bot
matches has its own target. The bots move on their own from the start of a
match. The Menu in the corner pauses or steps them, sets their speed, switches
whose view the table shows (hotseat), lists the controllers and WebMCP status,
and has the event log. Animations are CSS, keyed by the event's place in the
log so each plays once, and `prefers-reduced-motion` turns movement off.

The shotgun in the middle is also drawn in three.js (`src/gun-model.ts`): a
small accent, loaded after the page in its own chunk, and not loaded at all
under `prefers-reduced-motion`. Without it the SVG shotgun shows.

Fonts are self-hosted from `@fontsource`: League Gothic (banners) and VT323
(everything else), both under the SIL Open Font License 1.1. Every drawing is
original CSS or SVG.

## Playing with an agent (WebMCP)

A seat set to Agent waits for tool calls, as a Human seat waits for clicks. Any
number of seats can be Agents, so agents can play each other. Autoplay keeps
moving the Story and DoN seats and waits at any Agent's turn. The page
registers tools only when the browser has `document.modelContext`. Otherwise
the controls say WebMCP is not available.

Enable it in Chrome 149 or later (tested on 155):

- Open `chrome://flags/#enable-webmcp-testing`, set it to Enabled and relaunch, or
- launch with `--enable-features=WebMCPTesting`.

`get_game` and `play_move` name the seat they are for, as the number in its
name (`Seat 0` to `Seat 3`; a 2-seat table uses seats 1 and 3). A call for a
seat that is not an Agent at this table is refused. A seat's view never
includes another seat's notes or the shell order.

- `get_game(seat)`: the seat's view as JSON. It has the table and round, each
  seat's public health (null while jammed), cash, items and status, the last
  load shown, the seat's private notes, recent events, `isYourTurn`, `turn`, and
  `moves`, a numbered list of the legal moves with the same labels as the buttons.
- `play_move(seat, index, turn?)`: plays move `index` for the seat. It refuses a
  call when it is not that seat's turn, an index outside the list, or a `turn`
  that no longer matches. It returns the seat's new `get_game` JSON. The bots
  move on their own afterwards, so poll `get_game` until `isYourTurn` is true.
- `new_match(players, items, seed?, controllers?)`: starts a match with
  autoplay on. `controllers` lists one controller per seat in seat order, for
  example `["Agent", "Agent", "DoN"]`; each is `Agent`, `DoN`, `Story` or
  `Human`. Without it the first seat is the Agent and DoN plays the others. It
  returns each seat's number and controller.

`turn` counts every request point of the match, so any seat's move advances it.
While several seats grab items from the briefcase at once, each Agent seat has
its own moves and may answer in any order, but a move from another seat between
an agent's `get_game` and its `play_move` makes that `turn` stale. The agent
then calls `get_game` again. When several bots can move, the lowest seat goes
first, as in `sim/bend-mp/driver.bend`.

A refusal comes back as `{"error": "..."}` text, because Chrome shows the agent
only a generic message when a tool throws.

Tools reach the game through Foldkit ports, not by touching the Model. The app
runs with `Runtime.embed`, which returns the port handles. A tool sends
`{id, call}` on the inbound port `agentCalled`. A subscription turns it into
`Message.AgentCalled`, `update` answers it (moves go through the same
`ClickedMove` the buttons send), and a `ReplyToAgent` Command emits `{id, reply}`
on the outbound port `agentReplied`.

    bun scripts/agent.ts [url] [outdir]   # headless Chrome with the flag, tools only: a 2-seat match (one Agent vs DoN) and a 3-seat match (two Agents and DoN), items on

Chrome 155 has no `navigator.modelContextTesting`. The script calls the tools
through `document.modelContext.getTools()` and `executeTool()` from the spec.

## Layout

- `src/bend.ts`: the only file that writes Bend tags. It decodes every Bend
  value with a Schema, turns lists and Nats into arrays and numbers, and
  tickets every request point (match number + generation) so a stale answer is
  rejected before Bend's `answer` runs.
- `src/driver.ts`: runs a match between controllers. Story and DoN seats decide
  through the Bend entry points that `sim/bend-mp/driver.bend` uses, each with
  its own coin stream. A human seat picks from the legal moves the
  machine offers. Game draws come from a seeded RNG (`src/rng.ts`).
- `src/titles.ts`: end-of-match titles from the public event log. Titles are a UI
  feature. The rules library does not compute them.
- `src/agent.ts`: an Agent seat's view, move checks and the port schemas.
  `src/webmcp.ts` registers the tools. `src/text.ts` has the labels shared by the
  buttons and the agent.
- `src/model.ts`: Foldkit Model and Messages. `src/main.ts`: update, init,
  agent calls and the autoplay subscription, which pauses after each step for
  as long as its animation needs (scaled by the speed setting).
- `src/view.ts`: setup screen, banner, menu, round-over and results.
  `src/board-view.ts` draws the table; `src/icons.ts` has the SVG drawings.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
