# Buckshot table (web UI)

A plain web UI for the Bend multiplayer rules library in `sim/bend-mp/`, built
on Foldkit 0.167 and Effect 4 and run with bun and Vite. It builds `web.bend` to
JavaScript and plays 2- to 4-seat matches in the browser. Any seat can be a
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
    bun scripts/play.ts [url] [outdir]   # headless Chrome: one human-vs-bot match by clicking, one 4-bot autoplay match

## Playing with an agent (WebMCP)

A seat set to Agent waits for tool calls, as a Human seat waits for clicks. At
most one seat is the Agent. Setting a second one takes the role and returns the
old seat to Human. Autoplay keeps moving the Story and DoN seats and waits at
the Agent's turn. The page registers tools only when the browser has
`document.modelContext`. Otherwise the controls say WebMCP is not available.

Enable it in Chrome 149 or later (tested on 155):

- Open `chrome://flags/#enable-webmcp-testing`, set it to Enabled and relaunch, or
- launch with `--enable-features=WebMCPTesting`.

Tools, all for the Agent seat only (its view never includes another seat's
notes or the shell order):

- `get_game`: the seat's view as JSON. It has the table and round, each seat's
  public health (null while jammed), cash, items and status, the last load shown,
  the agent's private notes, recent events, `isYourTurn`, `turn`, and `moves`, a
  numbered list of the legal moves with the same labels as the buttons.
- `play_move(index, turn?)`: plays move `index`. It refuses a call when it is not
  the agent's turn, an index outside the list, or a `turn` that no longer matches.
  It returns the new `get_game` JSON. The bots move on their own afterwards, so
  poll `get_game` until `isYourTurn` is true.
- `new_match(players, items, seed?)`: starts a match with the agent in the first
  seat and DoN in the others, with autoplay on.

A refusal comes back as `{"error": "..."}` text, because Chrome shows the agent
only a generic message when a tool throws.

Tools reach the game through Foldkit ports, not by touching the Model. The app
runs with `Runtime.embed`, which returns the port handles. A tool sends
`{id, call}` on the inbound port `agentCalled`. A subscription turns it into
`Message.AgentCalled`, `update` answers it (moves go through the same
`ClickedMove` the buttons send), and a `ReplyToAgent` Command emits `{id, reply}`
on the outbound port `agentReplied`.

    bun scripts/agent.ts [url] [outdir]   # headless Chrome with the flag: plays a 2-seat match with items through the tools only

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
- `src/agent.ts`: the agent's view of its seat, move checks and the port schemas.
  `src/webmcp.ts` registers the tools. `src/text.ts` has the labels shared by the
  buttons and the agent.
- `src/main.ts`: Foldkit Model, Messages, update, view, autoplay subscription.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
