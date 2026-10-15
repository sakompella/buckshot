# Buckshot table (web UI)

A plain web UI for the Bend multiplayer rules library in `sim/bend-mp/`, built
on Foldkit 0.167 and Effect 4 and run with bun and Vite. It builds `web.bend` to
JavaScript and plays 2- to 4-player matches in the browser. Any player can be a
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
    bun run test       # plays full Story and DoN matches through bend.ts at 2, 3 and 4 players; checks stale answers are rejected; checks the agent tool contract: privacy, stale turns, and each Agent's events adding up to the whole log
    bun scripts/play.ts [url] [outdir]   # headless Chrome: one human-vs-bot match by clicking, one 4-bot autoplay match

## Playing with an agent (WebMCP)

A player set to Agent waits for tool calls, as a Human player waits for clicks. Any
number of players can be Agents, so agents can play each other. Autoplay keeps
moving the Story and DoN players and waits at any Agent's turn. The page
registers tools only when the browser has `document.modelContext`. Otherwise
the controls say WebMCP is not available.

Enable it in Chrome 149 or later (tested on 155):

- Open `chrome://flags/#enable-webmcp-testing`, set it to Enabled and relaunch, or
- launch with `--enable-features=WebMCPTesting`.

Players are numbered 1 to N in table order, as in the game's "PLAYER 2". A
2-player table has Player 1 and Player 2. `get_game` and `play_move` name the
player they are for by that number (`player`: 1 to 4). A call for a number the
table does not have, or for a player that is not an Agent, is refused. Replies
never show the machine's seat ids. A player's view never includes another
player's secrets or the shell order.

- `get_game(player)`: the player's view as JSON, with only what that player's screen
  shows. While it is not the player's turn it is just `{"you": 2, "status": "waiting"}`.
  On the player's turn it has `status: "your turn"`, `turn`, `players` (health, which
  is left out while a player is jammed, and item names, with no slots or cash),
  `gun` (`heldBy`, and `sawed` when it is), `events` and `moves`. `events` are what
  happened since the player's previous reply on its turn, from the start of the
  match in the first one. They include round starts and round wins. The secrets
  this player heard (the magnifying glass, the phone) stand in the list just after
  the event that told them, and no other player's secrets appear. Events are shown
  once, so the agent remembers what it needs, as a person does. The server keeps
  one count per Agent player of the events it has shown; a waiting reply does not
  move it. `moves` is the list of the legal moves with the same labels as the
  buttons; a move's number is its position in the list, from 0. Fields with
  nothing to show are left out, with no nulls. When the match is over the view is
  `status: "over"` and `standings`, the cash of each player; cash appears nowhere
  else.
- `play_move(player, index, turn?)`: plays move `index` for the player. It refuses a
  call when it is not that player's turn, an index outside the list, or a `turn`
  that no longer matches. It returns the player's view as `get_game` does. The bots
  move on their own afterwards, so poll `get_game` until `status` is `"your turn"`.
- `new_match(players, items, seed?, controllers?)`: starts a match with
  autoplay on. `controllers` lists one controller per player in player order, for
  example `["Agent", "Agent", "DoN"]`; each is `Agent`, `DoN`, `Story` or
  `Human`. Without it Player 1 is the Agent and DoN plays the others. It
  returns each player's number and controller, and the seed.

`turn` counts every request point of the match, so any player's move advances it.
While several players grab items from the briefcase at once, each Agent player has
its own moves and may answer in any order, but a move from another player between
an agent's `get_game` and its `play_move` makes that `turn` stale. The agent
then calls `get_game` again. When several bots can move, the lowest-numbered player goes
first, as in `sim/bend-mp/driver.bend`.

A refusal comes back as `{"error": "..."}` text, because Chrome shows the agent
only a generic message when a tool throws. The MCP server sends the same text
and also marks the result `isError`.

Tools reach the game through Foldkit ports, not by touching the Model. The app
runs with `Runtime.embed`, which returns the port handles. A tool sends
`{id, call}` on the inbound port `agentCalled`. A subscription turns it into
`Message.AgentCalled`, `update` answers it (moves go through the same
`ClickedMove` the buttons send), and a `ReplyToAgent` Command emits `{id, reply}`
on the outbound port `agentReplied`.

    bun scripts/agent.ts [url] [outdir]   # headless Chrome with the flag, tools only: a 2-player match (one Agent vs DoN) and a 3-player match (two Agents and DoN), items on

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

    bun scripts/mcp-check.ts   # spawns the server with the SDK client, lists the tools, plays two Agent players against DoN to the end, and prints the reply sizes
    bunx @modelcontextprotocol/inspector --cli bun scripts/mcp.ts --method tools/list

The server uses `@modelcontextprotocol/server` 2.3.1, the v2 SDK. It also
answers clients that use the older `initialize` handshake.

## Layout

- `src/bend.ts`: the only file that writes Bend tags. It decodes every Bend
  value with a Schema, turns lists and Nats into arrays and numbers, and
  tickets every request point (match number + generation) so a stale answer is
  rejected before Bend's `answer` runs.
- `src/driver.ts`: runs a match between controllers. Story and DoN seats decide
  through the Bend entry points that `sim/bend-mp/driver.bend` uses, each with
  its own coin stream. A human seat picks from the legal moves the
  machine offers. Game draws come from a seeded RNG (`src/rng.ts`).
- `src/players.ts`: the `Roster`, the one place a table's seat ids and the
  player numbers people and agents see (Player 1 to N, in table order) convert.
  Bend and the driver keep raw seat ids; every label and tool reply goes
  through a `Roster`.
- `src/titles.ts`: end-of-match titles from the public event log. Titles are a UI
  feature. The rules library does not compute them.
- `src/agent/`: the agent tools, with no DOM, page or MCP SDK.
  `tools.ts` holds the tool names, descriptions, input schemas (Effect
  Schemas, turned into JSON Schema for both front ends) and `runTool`, which
  runs one call over a `MatchSession`. `view.ts` builds an Agent player's view
  and checks its moves. `headless.ts` is the session the MCP server runs: one
  table, with the AI players played in-process. `src/text.ts` has the labels
  shared by the buttons and the agent.
- `src/webmcp.ts`: the WebMCP front end. It registers the tools with the page's
  model context and carries calls through the ports. `src/main.ts` has the
  page's `MatchSession`, which moves through `ClickedMove`.
- `scripts/mcp.ts`: the stdio MCP front end.
- `src/main.ts`: Foldkit Model, Messages, update, view, autoplay subscription.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
