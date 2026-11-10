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

`bun run rules` needs the pinned Bend (2.0.40): `$BEND`, else `bend` on PATH.
`nix develop` at the repo root provides both.

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
of that. ADR-0029 records why the table is 2D.

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

## Arena analysis viewer

The site is one app (`src/site/`) with three pages, each at its own URL:

| Page | URL | Needs |
|-|-|-|
| Play | `/` | nothing: the game runs in the browser |
| Arena | `/arena?offModels=…&offEfforts=…&row=…` | the arena viewer's API |
| Replay | `/replay/<match id>?at=<move ordinal>` | the arena viewer's API |

The arena's filter, its open leaderboard row and a replay's move live in the
URL, so a link shares them and a reload keeps them. Opening a replay adds a
history entry, so Back closes it. Old links to the arena's sections
(`/#scatter`) move to `/arena#scatter`. A build of the site with no arena
server (`vite preview`, a static host) still plays; Arena and Replay then say
they need the arena data.

`bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>] [--luck <luck db>]` serves the built site
(`web/dist`: run `bun run build` first) and its API over the arena
analysis database (`scripts/arena-import.ts` builds it; see
`docs/arena/database.md`) at http://127.0.0.1:8790/ by default, with no auth.
With `--luck` (the file `tools/arena/analysis/aivat.py --out` writes) the leaderboard also shows the luck-adjusted Round
Elo (`docs/arena/analysis/matchups.md#luck-adjusted-round-elo`). `bun run dev` proxies `/api` to a viewer on that port, so the arena pages work in
development while one runs.

The Arena page is one long page in six groups, in this order:

- the hero numbers;
- Results: the cost, moves, output tokens or mean regret vs rating scatter, each model's rating across its efforts,
  how often the higher-rated player wins at each rating gap (rated by fits that held the match's seed block out,
  against the Bradley-Terry curve);
- Watch a match: a few interesting matches and, with `--regret`, the costliest blunders, each marked exact or
  estimated;
- Decisions: with `--certain-mistakes` (the file `tools/arena/analysis/certain_mistakes.py --opportunities` writes), each
  config's certain mistakes over their opportunities (`docs/arena/analysis/certain-mistakes.md`), each count opening its
  matches at the move, which the replay marks; how often each config shoots itself by the odds it counts (one panel per model, a line per effort);
  with `--regret`, each model's mean regret per move by shells left in the gun and each config's blunder rate (the
  share of its searched moves that gave up 10 or more points); item fates (used, stolen by the opponent or left
  unused, per config and per item); with `--knowledge` (the database `scripts/arena-knowledge.ts` builds) each
  config's chance of repeating its move in a repeated position, in the chosen cohort, with the seed-block interval
  `docs/arena/analysis/beliefs-and-items.md` uses; and how often the player with higher estimated regret still won;
- Rounds: the table position and round-1 starter charts, results after round 1 (round 2 after a round-1 win, with
  each config's round 2 and 1-1 round 3 folded below), output tokens per move by health gap and dead rubbers
  (round 3 at 1-1 against after 2-0);
- Reliability: service failures (failed calls, the time they cost, and each model's failed replies by the hour each
  call was logged) apart from model failures (turns ended without a move), one bar per config, then where the money
  went (each config's share of the list-price usage);
- Details: the leaderboard by cohort, the newest matches, each seed's results per config from table position 1
  and 2 and, last, the breakdown heatmaps.

Seats and reliability fold their full tables under the charts. The jump menu at the top links to the six groups
(`#results`, `#watch`, `#decisions`, `#rounds`, `#reliability`, `#details`); every section keeps its own anchor
(`#scatter`, `#seats`, `#matches`, ...), so older links still land. Its Tour button starts a guided tour: each
step scrolls to a section or control, highlights it and shows a short card, with Back, Next and Close, the arrow
keys and Escape (`page/tour.ts` holds the steps). The filter bar
under it applies to the whole page; on a wide screen both stay at the top, and
the jump menu marks the group in view. On a phone or tablet the filters fold
into one line that says what they keep, and a tap opens them; on a phone the
scatter's choices are menus, so the chart starts on the first screen, and charts
too narrow to name their lines at the ends key them below.

Chart marks mean the same everywhere: a solid dot is a config's value, a ring the same config in a second situation,
a coloured dash an effort, and a grey dashed line a reference. The important marks share one tip: the mouse shows
it, and a click, a tap or Enter pins it, with the sample behind the mark. A scatter tap picks the nearest point
within a fingertip, and a seed cell answers a tap anywhere in it. Other titled marks show their title in a bar at
the bottom when tapped. 
