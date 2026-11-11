# Buckshot web: arena, agent tools and site

The TypeScript side of the project, built on Foldkit 0.167 and Effect 4 and run
with bun and Vite. It builds the Bend rules in `sim/bend-mp/web.bend` to
JavaScript and drives them through `src/bend.ts` and `src/driver.ts`, with no
rules of its own: legality, observation and privacy all come from the machine.
On top of that sit the agent tools (`src/agent/`, served by an MCP server), the
arena that plays models against each other (`src/arena/`, `docs/arena/`), and
the site that shows the arena's results. See
[`sim/bend-mp/README.md`](../sim/bend-mp/README.md) for the rules library.

## Run

    bun install
    bun run dev        # builds generated/rules.mjs from sim/bend-mp/web.bend, then serves the site at http://localhost:5173/

`bun run rules` needs the pinned Bend (2.0.40): `$BEND`, else `bend` on PATH.
`nix develop` at the repo root provides both.

Checks:

    bun run typecheck  # tsrs --noEmit, strict (tsrs is the Rust port of tsc)
    bun run lint       # oxlint with every anti-slop rule and the Effect group, --deny-warnings
    bun run test       # plays full Story and DoN matches through bend.ts at 2, 3 and 4 players; checks stale answers are rejected; checks the agent tool contract: privacy, read-only get_game, stale, repeated and rematch turns, new_match refused mid-match, the moves list matching the machine's legal chains, and each Agent's events adding up to the whole log, the end included

The page uses the system font stack and no web fonts. Every drawing is
original CSS or SVG (ADR-0028).
## Playing with an agent (MCP server)

`bun run mcp` is a stdio MCP server with three tools, `get_game`, `play_move` and
`new_match` (`src/agent/`), for an MCP client such as Claude Code or Codex. It builds the rules,
then holds one table in the process and plays the DoN and Story players there, so
by the time a tool replies the bots have moved and an Agent player has the turn
(or the match is over). It refuses Human players, since nothing can click them.

One server process can serve several Agent players: name each player in `get_game`
and `play_move`, from one agent or from several sub-agents that share the
client's connection. Separate processes do not share a match. Two clients that
each launch the server get two separate tables, and no other process can see them.

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

### Tools

Players are named by letter in table order: a 2-player table has Player A and
Player B. `get_game` and `play_move` name the player they are for by its letter
(`player`: `"A"` to `"D"`). A call for a letter the table does not have, or for a
player that is not an Agent, is refused. Replies
never show the machine's seat ids. A player's view never includes another
player's secrets or the shell order.

- `get_game(player)`: the player's view as JSON, with only what that player can see. It is read-only: until some player moves, every call returns the same view.
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
- `new_match(players, items, seed?, controllers?)`: starts a match. It is refused
  while a match is in progress (some player still has a move): "A match is in
  progress; finish it first."
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

#### Moves

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

#### Turns

`turn` is a number the session advances with every accepted move, by any player,
and every new match, across matches. It never repeats in one MCP server process, so a `play_move` repeated after it was played, one from an earlier view,
or one from a finished match after a rematch with the same seed is refused as stale
instead of played. Nothing else is kept per agent: a view is built from the match log
alone.

While several players grab items from the briefcase at once, each Agent player has
its own moves and may answer in any order, but a move from another player between
an agent's `get_game` and its `play_move` makes that turn stale. The agent
then calls `get_game` again for the current moves and turn. When several bots can
move, the first player in table order goes first, as in `sim/bend-mp/driver.bend`.

A refusal comes back as `{"error": "..."}` text, and the result is marked `isError`.

## Arena analysis viewer

The site is one app (`src/site/`) with one page, at its own URL:

| Page | URL |
|-|-|
| Arena | `/arena?offModels=…&offEfforts=…&row=…` |

It reads the arena viewer's API (the online build reads its aggregate files).

The arena's filter and its open leaderboard row live in the
URL, so a link shares them and a reload keeps them. The root `/` moves to `/arena`,
and old links to the arena's sections (`/#scatter`) to `/arena#scatter`. A build of the site with no arena
server (`vite preview`, a static host) says the page needs the arena data.

`bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>] [--luck <luck db>]` serves the built site
(`web/dist`: run `bun run build` first) and its API over the arena
analysis database (`scripts/arena-import.ts` builds it; see
`docs/arena/database.md`) at http://127.0.0.1:8790/ by default, with no auth.
With `--luck` (the file `tools/arena/analysis/aivat.py --out` writes) the leaderboard also shows the luck-adjusted Round
Elo (`docs/arena/analysis/matchups.md#luck-adjusted-round-elo`). `bun run dev` proxies `/api` to a viewer on that port, so the arena pages work in
development while one runs.

The Arena page is one long page in five groups, in this order (`Group` and `Section` in `src/arena-viewer/page/model.ts` are the list):

- Standings: the hero numbers, the Round Elo of every config, the cost, moves, output tokens or mean regret vs rating
  scatter, and the breakdown heatmaps;
- How they play: each config's certain mistakes over their opportunities (`docs/arena/analysis/certain-mistakes.md`),
  how often each config shoots itself by the odds it counts, and item fates (used, stolen or left unused);
- Matches: a few interesting matches and the newest ones, listed only (there is no replay, ADR-0055). The online
  site has no matches group, because it reads aggregates only;
- Tables: the leaderboard by cohort and the accuracy table;
- About: how the game works and how the experiment was run.

Each section has its own anchor (`#scatter`, `#matches`, ...), and a link to a section the page no longer has lands at
its `MOVED_TARGETS` entry. The jump menu at the top links to the groups. Its Tour button starts a guided tour: each
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
