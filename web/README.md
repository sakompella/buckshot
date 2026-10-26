# Buckshot table (web UI)

A web game for the Bend multiplayer rules library in `sim/bend-mp/`, built
on Foldkit 0.167 and Effect 4 and run with bun and Vite. It builds `web.bend` to
JavaScript and plays 2- to 4-player matches in the browser, on a dark top-down
table drawn in DOM, CSS and SVG: you play by clicking the shotgun, a player's
defibrillator, an item or the briefcase. Any player can be a human, a Story
AI, a DoN AI or an agent (see below). The UI has no rules of its own. Legality,
observation and privacy all come from the machine. See
[`sim/bend-mp/README.md`](../sim/bend-mp/README.md) for the rules library.

## Run

    bun install
    bun run dev        # builds generated/rules.mjs from sim/bend-mp/web.bend, then serves http://localhost:5173/

`bun run rules` needs Bend 2.0.36: `$BEND`, else `bend` on PATH, else the
pinned Nix store path in `scripts/build-rules.ts`. `nix develop` at the repo
root provides it.

Checks:

    bun run typecheck  # tsrs --noEmit, strict (tsrs is the Rust port of tsc)
    bun run lint       # oxlint with every anti-slop rule and the Effect group, --deny-warnings
    bun run test       # plays full Story and DoN matches through bend.ts at 2, 3 and 4 players; checks stale answers are rejected; checks the agent tool contract: privacy, read-only get_game, stale, repeated and rematch turns, new_match refused mid-match, the moves list matching the machine's legal chains, and each Agent's events adding up to the whole log, the end included
    bun scripts/play.ts [url] [outdir]   # headless Chrome (BROWSER=firefox for Playwright Firefox): one human-vs-bot match by clicking the table, one 4-bot autoplay match
    bun scripts/shots.ts [url] [outdir] [WxH ...]   # a screenshot of each stage of a match, at 1440x900 and 390x844 by default; MOTION=reduce for reduced motion, BROWSER=firefox for Playwright Firefox

## Playing

The setup screen picks the number of players, each player's controller, items
and the seed. In a match the banner says whose view it is and the phase
(Your turn, Grab items, Watch, Round over, Match over). Everything else is on
the table: health is the bolts on each defibrillator, a new load is its shells
set out in a live group and a blank group, a shot is the gun turning, its
flash and recoil and the bolts going dark, and a private result (glass, phone)
shows big in the middle for a moment, only to the player who learned it. Each
of the viewer's legal moves is played by clicking the thing it acts on, which
lifts under the pointer; the moves are buttons, so Tab and Enter play them too:

| Move | Click |
|---|---|
| Grab | your open briefcase |
| Place | an empty slot on your side (shown only while placing) |
| Pick up | the shotgun |
| Shoot, Jam | a player's defibrillator (your own to shoot yourself) |
| Use an item | the item on your side |
| Steal (adrenaline) | the item on another player's side |

`src/board.ts` maps each move to its target. Moves that would share a target
get plain buttons instead; the tests check that every legal move of many bot
matches has its own target. The bots move on their own from the start of a
match. The Menu in the corner pauses or steps them, sets their speed, switches
whose view the table shows (hotseat), lists the controllers and WebMCP status,
and has the event log. Animations are CSS, keyed by the event's place in the
log so each plays once and is gone when the next step starts, and
`prefers-reduced-motion` turns movement off.

The Speed setting (Slow, Normal, Fast) scales every pause: Normal holds a load
reveal 2.6 s, a shot 2.2 s and a round over 4.4 s, and Fast is about an eighth
of that. ADR-0029 records why the table is 2D; a three.js version of the whole
scene is kept unmerged on branch `web/game-3d` as a reference.

Fonts are self-hosted from `@fontsource`: League Gothic (banners) and VT323
(everything else), both under the SIL Open Font License 1.1. Every drawing is
original CSS or SVG (ADR-0028).

## Playing with an agent (WebMCP)

A player set to Agent waits for tool calls, as a Human player waits for clicks. Any
number of players can be Agents, so agents can play each other. Autoplay keeps
moving the Story and DoN players and waits at any Agent's turn. The page
registers tools only when the browser has `document.modelContext`. Otherwise
the controls say WebMCP is not available.

Enable it in Chrome 149 or later (tested on 155):

- Open `chrome://flags/#enable-webmcp-testing`, set it to Enabled and relaunch, or
- launch with `--enable-features=WebMCPTesting`.

Players are named by letter in table order: a 2-player table has Player A and
Player B. `get_game` and `play_move` name the player they are for by its letter
(`player`: `"A"` to `"D"`). A call for a letter the table does not have, or for a
player that is not an Agent, is refused. Replies
never show the machine's seat ids. A player's view never includes another
player's secrets or the shell order.

- `get_game(player)`: the player's view as JSON, with only what that player's screen
  shows. It is read-only: until some player moves, every call returns the same view.
  While it is not the player's turn it is just `{"you": "B", "status": "waiting"}`.
  On the player's turn it has `status: "your turn"`, `turn`, `players` (health, which
  is left out while a player is jammed, item names, and, while players grab from the
  briefcase, `holding`, the item a player drew and has not placed yet; no slots or cash),
  `gun` (`sawed` when it is), `events` and `moves`. `events` are what happened since
  the player's previous turn ended: its last move first, then everything after it,
  with the secrets this player heard (the magnifying glass, the phone) just after the
  event that told them. The first view covers the match from its start. So the views a
  player moves from, then its final view, add up to the whole log with no gaps or
  repeats, and no other player's secrets appear. `moves` lists whole actions, each as `{ move, label }`;
  `move` is the number `play_move` takes, from 0. Fields with nothing to show are left
  out, with no nulls. When the match is over the view is `status: "over"`, the events
  since the player's last turn ended (the final shot, the last round's prize, "The
  match is over."), and `standings`, the cash of each player; cash appears nowhere else.
- `play_move(player, move, turn)`: plays move number `move` for the player, with the
  `turn` of the view the move was chosen from. It refuses a call when it is not that
  player's turn, a number outside the list, or any turn but the current one. A refused
  call plays nothing. It returns the player's view as `get_game` does. The bots move on
  their own afterwards, so poll `get_game` until `status` is `"your turn"`.
- `new_match(players, items, seed?, controllers?)`: starts a match with
  autoplay on. It is refused while a match is in progress (some player still has a
  move): "A match is in progress; finish it first." The page's Restart match button
  still starts a new match at any time; that is a person's choice, not a tool.
  `controllers` lists one controller per player in player order, for
  example `["Agent", "Agent", "DoN"]`; each is `Agent`, `DoN`, `Story` or
  `Human`. Without it Player A is the Agent and DoN plays the others. `seed` is a
  string holding an integer from -9007199254740991 to 9007199254740991; anything
  else is refused. It returns each player's letter and controller, and the seed,
  which replays the match when passed back.

A your-turn view in a 3-player match with items, as the MCP check prints it:

    {"you":"A","status":"your turn","turn":7,
     "players":[{"player":"A","health":4,"items":["burner phone","adrenaline","magnifying glass"]},
                {"player":"B","health":4,"items":["magnifying glass","magnifying glass","inverter"]},
                {"player":"C","health":4,"items":["remote","jammer","magnifying glass"]}],
     "events":["Player A drew an item.","Player A finished grabbing.","Player A placed magnifying glass in slot 3.",
               "Player B drew an item.","Player B finished grabbing.","Distribution is over.",
               "Player B placed inverter in slot 3.","The shotgun is loaded: 4 live, 3 blank.","Player A's turn."],
     "moves":[{"move":0,"label":"Shoot yourself"},
              {"move":1,"label":"Shoot Player B"},
              {"move":2,"label":"Shoot Player C"},
              {"move":3,"label":"Use burner phone"},
              {"move":4,"label":"Steal magnifying glass from Player B"},
              {"move":5,"label":"Steal inverter from Player B"},
              {"move":6,"label":"Steal remote from Player C"},
              {"move":7,"label":"Steal jammer from Player C and jam Player B"},
              {"move":8,"label":"Steal jammer from Player C and jam Player C"},
              {"move":9,"label":"Steal magnifying glass from Player C"},
              {"move":10,"label":"Use magnifying glass"}]}

### Moves

The machine asks for one step at a time: pick up the shotgun, then shoot; use a
jammer, then pick whom to jam. An agent move is a whole action, made by chaining the
machine's own legal moves. `src/agent/moves.ts` finds the chains by playing each
step on a copy of the match with the driver and following the player's next menu
while the machine leaves the player partway through an action (aiming, choosing a
jam target or an item to steal, or holding a drawn item). No rule is written in
TypeScript.

- `Shoot Player B`, `Shoot yourself`: pick up and fire, listed only when picking up is legal.
- `Use beer`, `Use magnifying glass`, ...; a jammer is `Jam Player C`; adrenaline is
  `Steal beer from Player B` (and a stolen jammer adds its target, `Steal jammer from
  Player C and jam Player B`).
- `Grab an item`: grab, then place the drawn item in the first free slot.

Labels name no slots. No rule depends on a slot: the machine and the reference rules
count items, never read a slot index, and empty a used or stolen item's own slot.
So when a player has two copies of an item, the move uses the first copy, and a drawn
item goes in the first free slot, as the DoN AI places it. Of two chains that differ
only in a slot, the first is listed.

### Turns

`turn` is a number the session advances with every accepted move, by any player,
and every new match, across matches. It never repeats in one MCP server process or
page load, so a `play_move` repeated after it was played, one from an earlier view,
or one from a finished match after a rematch with the same seed is refused as stale
instead of played. Nothing else is kept per agent: a view is built from the match log
alone.

While several players grab items from the briefcase at once, each Agent player has
its own moves and may answer in any order, but a move from another player between
an agent's `get_game` and its `play_move` makes that turn stale. The agent
then calls `get_game` again for the current moves and turn. When several bots can
move, the first player in table order goes first, as in `sim/bend-mp/driver.bend`.

A refusal comes back as `{"error": "..."}` text, because Chrome shows the agent
only a generic message when a tool throws. The MCP server sends the same text
and also marks the result `isError`.

Tools reach the game through Foldkit ports, not by touching the Model. The app
runs with `Runtime.embed`, which returns the port handles. A tool sends
`{id, call}` on the inbound port `agentCalled`. A subscription turns it into
`Message.AgentCalled`, `update` answers it (a move's steps go through the
driver and the same result handling as the buttons' `ClickedMove`), and a `ReplyToAgent` Command emits `{id, reply}`
on the outbound port `agentReplied`.

    bun scripts/agent.ts [url] [outdir]   # headless Chrome with the flag, tools only: a 2-player match (one Agent vs DoN), a 3-player match (two Agents and DoN), and that match again with the same seed, where the previous match's last turn is refused, items on

Chrome 155 has no `navigator.modelContextTesting`. The script calls the tools
through `document.modelContext.getTools()` and `executeTool()` from the spec.

## Playing with an agent (MCP server)

`bun run mcp` is a stdio MCP server with the same three tools, for an MCP
client such as Claude Code or Codex. It needs no browser. It builds the rules,
then holds one table in the process and plays the DoN and Story players there, so
by the time a tool replies the bots have moved and an Agent player has the turn
(or the match is over). It refuses Human players, since nothing can click them.

One server process can serve several Agent players: name each player in `get_game`
and `play_move`, from one agent or from several sub-agents that share the
client's connection. Separate processes do not share a match. Two clients that
each launch the server get two separate tables, and neither the page nor
another process can see them.

Add it to Claude Code (run in this `web/` directory, so `$PWD` is its path):

    claude mcp add buckshot -- bun run --cwd "$PWD" mcp

Add it to Codex the same way:

    codex mcp add buckshot -- bun run --cwd "$PWD" mcp

or add this to `~/.codex/config.toml`, with the absolute path to `web/`:

    [mcp_servers.buckshot]
    command = "bun"
    args = ["run", "--cwd", "/absolute/path/to/buckshot/web", "mcp"]

Each launch rebuilds the rules first, which takes a few seconds. Then ask the
agent to call `new_match` and play its player. Checks:

    bun scripts/mcp-check.ts   # spawns the server with the SDK client, lists the tools, plays two Agent players against DoN to the end, checks repeated get_game and play_move calls, new_match mid-match, the final events and a turn from the previous match after a rematch, and prints the reply sizes
    bunx @modelcontextprotocol/inspector --cli bun scripts/mcp.ts --method tools/list

The server uses `@modelcontextprotocol/server` 2.3.1, the v2 SDK. It also
answers clients that use the older `initialize` handshake.

## Arena viewer

`bun run viewer` serves a read-only site for browsing arena matches at
http://127.0.0.1:4173/. It reads the run directories in `_work/arena` at the
repo root (`--dir <runs dir>` picks another, `--port <n>` another port, 0 a free
one) and binds 127.0.0.1 only, with no auth. Each run directory's
`manifest.json`, `events.jsonl` and `calls.jsonl` are all it reads; costs come
from `src/arena/prices.json` at each request. The list shows every match with its agents,
seating, status and standings, and totals per agent and per model. A match page
replays the match through the rules machine with a scrubber, and shows each
agent's log side by side: what was delivered to it, its model calls with
thinking, text, tool calls, tokens and cost, and its turns. A live match is
polled and followed. Runs from before format 1 are listed as unreadable.

    bun scripts/viewer-check.ts [outdir]   # headless Chrome over a temp runs dir it fills itself (two faux matches, a format-0 run and a live copy): the list, a finished match, and a live match appended while the page watches

The look borrows from the studio viewer in
[claude-paint](https://github.com/aliceisjustplaying/claude-paint) (MIT).

## Arena analysis viewer

`bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>]` serves charts over the arena
analysis database (`scripts/arena-import.ts` builds it; see
`docs/arena/database.md`) at http://127.0.0.1:8790/ by default, with no auth.
It is one long page: the hero numbers, the cost, moves, output tokens or mean regret
vs rating scatter, each model's rating across its efforts, a few interesting matches, the table position and round-1 starter
charts, the reliability charts (failed calls, faults and the time they cost, one bar per
config pooled over every tournament), the newest matches, the leaderboard by cohort and, last, the breakdown heatmaps. Seats and
reliability fold their full tables under the charts. A jump menu at the top links
to each section's anchor (`#scatter`, `#seats`, `#matches`, ...), and the filter bar
under it applies to the whole page; on a wide screen both stay at the top. The
scatter's and the effort chart's axes span every config in every cohort, so a filter only shows or hides
points; the reliability bars keep one scale the same way.

Wherever ratings show (the scatter's y axis, the heatmap's and the leaderboards'
rating columns), a Wins / Cash / Rounds toggle and an Elo / Rank toggle switch all of them.
Elo is one Bradley-Terry rating per config, fitted over every completed
two-player match of every tournament (`page/ratings.ts`): win shares count
fractionally, a Gaussian prior (standard deviation 3 nats) keeps it finite, the
scale has mean 0, and the 95% intervals refit 200 resamples of whole seed blocks.
Effort sweeps join the other models through their medium configs, so one scale
covers every config and no filter changes it. Cash is the same fit with pot
shares in place of win shares: a player's pot share is its cash over the match's
cash, and the leaderboards show each config's pot share, averaged over its scored
matches, beside its win share. Rounds is the same fit with each round of a match
as one game, its winner read from the public events (a match whose rounds the
events do not give in full is left out), and the leaderboards show each config's
round share, the rounds it won over the rounds it played. Its resamples still take
whole seed blocks, since a match's rounds are not independent. The cash and rounds
fits run the first time each is chosen, so the first load pays only for the win
fit. Rank is a place 1, 2, 3, ... for every config. The leaderboards rank by the
observed share (win, pot or round) within each cohort, among all of its configs
before the chip and switch filters, ties going to the higher Elo. The scatter and heatmap do the same
under one cohort. Under "All cohorts" they rank by the pooled Elo instead, since
pooling every cohort's shares would count the effort sweeps' self-play. The
interesting matches always judge underdogs by the win rating.

`--regret` names the derived database with the `regret` table
(`docs/arena/analysis/regret.md`), opened read only. Without it the viewer runs as
before and shows no regret. With it, each leaderboard row has a Regret column, the
mean percentage points of round win chance a model's moves gave up over its scored
matches (hover for the move count and the share proven exact), the scatter has a Regret axis, and each model move in
a replay has a regret tag, filled in when the move gave up 5 points or more. A move proven exact is marked "exact" and the rest are not;
the open move says its best move, both scores, search depth and whether the node
budget stopped it. The table can hold runs with other settings; the viewer reads the
run with the most searched moves, so scores never mix. Moves with no search have no tag.

A match row, an interesting match or a
flagged move opens its replay: health through the match,
each player's view at the chosen move, and every model move with its reasoning.
The arrow keys step through it, and Escape, a click outside or the back gesture
closes it. A cohort is one kind of comparison, pooled over code versions and runs: the
medium cross-model games, each model's effort sweep, and each smaller
tournament's pairing ("Opus xhigh vs Astra"). The page shows every config by
default; switching 'all configs' off keeps only configs with at least 20 scored
matches and one against another model, and hides the effort-sweep leaderboards. Items are drawn with the table's own
icons from `src/icons.ts`, except the saw, beer and jammer, which the viewer
draws after the game's own: a folding saw, a blue-label can and a flat jammer with a
green screen. It is a Foldkit app; the server loads every seat at start and works out the per-move
analysis once.

    bun scripts/arena-viewer-check.ts <url> [outdir]   # headless Chrome at desktop, phone and tablet widths: hovers, taps, jumps, the ranking toggle, fixed axes and screenshots

The shared copy runs on hp-server at http://100.108.62.24:8790/, from the main
checkout's `web/`. Its PID is in `_work/arena/viewer.pid` and its log in
`_work/arena/viewer.log`. To restart it after a merge, from the repository root:

    kill "$(cat _work/arena/viewer.pid)"
    cd web && setsid -f sh -c 'echo $$ > ../_work/arena/viewer.pid; set -a; . ../_work/arena/viewer.env; set +a; exec bun scripts/arena-viewer.ts ../_work/arena/analysis/buckshot.sqlite 100.108.62.24 8790 --regret ../_work/arena/analysis/derived/regret.sqlite > ../_work/arena/viewer.log 2>&1' < /dev/null

With `ARENA_VIEWER_PASSWORD` set (the shared copy keeps it in the gitignored `_work/arena/viewer.env`), the API asks for that password through the browser's sign-in prompt; leave the username empty. Without it the viewer is open. With `ARENA_VIEWER_DOWNLOAD` set to a database file, the nav links to it as a download behind the same password; the shared copy serves `_work/arena/analysis/buckshot.public.sqlite`, a copy with every email and account id redacted, built with `python3 tools/arena/redact_database.py <db> <out>` (rebuild it after every database swap).

## Layout

- `src/bend.ts`: the only file that writes Bend tags. It decodes every Bend
  value with a Schema, turns lists and Nats into arrays and numbers, and
  tickets every request point (match id + generation) so a stale answer is
  rejected before Bend's `answer` runs.
- `src/driver.ts`: runs a match between controllers. Story and DoN seats decide
  through the Bend entry points that `sim/bend-mp/driver.bend` uses, each with
  its own coin stream. A human seat picks from the legal moves the
  machine offers. Game draws come from a seeded RNG (`src/rng.ts`).
- `src/players.ts`: the `Roster`, the one place a table's seat ids and the
  player letters people and agents see (Player A to D, in table order by
  default, or from an explicit seat-to-letter assignment) convert.
  Bend and the driver keep raw seat ids; every label and tool reply goes
  through a `Roster`.
- `src/titles.ts`: end-of-match titles from the public event log. Titles are a UI
  feature. The rules library does not compute them.
- `src/agent/`: the agent tools, with no DOM, page or MCP SDK.
  `tools.ts` holds the tool names, descriptions, input schemas (Effect
  Schemas, turned into JSON Schema for both front ends) and `runTool`, which
  runs one call over a `MatchSession`. `view.ts` builds an Agent player's view
  from the match log and checks its moves. `moves.ts` chains the machine's
  steps into whole agent moves. `headless.ts` is the session the MCP server runs: one
  table, with the AI players played in-process. `src/text.ts` has the words
  the buttons and the agent share, and the agent move labels.
- `src/webmcp.ts`: the WebMCP front end. It registers the tools with the page's
  model context and carries calls through the ports. `src/main.ts` has the
  page's `MatchSession`, which moves through `ClickedMove`.
- `scripts/mcp.ts`: the stdio MCP front end.
- `src/model.ts`: Foldkit Model and Messages. `src/main.ts`: update, init and
  the autoplay subscription, which pauses after each step for as long as its
  animation needs (scaled by the speed setting).
- `src/view.ts`: setup screen, banner, menu, round-over, private results and
  the results. `src/board-view.ts` draws the table and its one-time effects,
  keyed by event index; `src/board.ts` maps each legal move to the thing it is
  played on; `src/icons.ts` has the SVG drawings; `src/styles.css` the look
  and the animations.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
- `src/arena/cost.ts` prices model calls from `prices.json` and totals them; `scripts/arena-cost.ts` and the viewer both use it.
- `src/viewer/runs.ts` reads run directories and their JSONL files, leaving out a last line still being written.
- `src/viewer/api.ts` holds the schemas the viewer's server encodes and its page decodes.
- `src/viewer/replay.ts` replays a run's moves through the rules machine into frames, extending a live run's replay as moves arrive.
- `src/viewer/server.ts` serves the viewer's page and its JSON API, with cursors for polling.
- `src/viewer/page/` is the viewer's page, plain TypeScript and DOM.
- `scripts/viewer.ts` starts the viewer, and `scripts/viewer-check.ts` screenshots it in headless Chrome.
- `test/faux-run.ts` plays a free faux arena match into a run directory, for the viewer's tests and its screenshot check.
- `src/arena-viewer/server.ts` serves the arena analysis viewer's page and JSON API; `analysis.ts` replays each seat's visible events to tag its moves (known shells, item use, choice patterns); `regret.ts` reads the optional regret database; `api.ts` holds the schemas both sides use.
- `src/arena-viewer/page/` is that viewer's Foldkit page: `model.ts` and `main.ts` the state and updates, one module per chart or section, hand-drawn SVG, and `replay.ts` the replay.
