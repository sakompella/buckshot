# Arena players share one process with seat-bound tools

The arena runs a match and every model player in one process. Each player is a pi-durable conversation whose two tools, `get_game` and `play_move`, take no player argument. They read the player from a seat document written when the conversation was created. So no call can reach another seat, and a model has no shell, files or network to look elsewhere.

## Considered Options

- One MCP endpoint per seat with a secret URL (built and proven, commit `6e5d3fb`): it needs a transport and tokens, it races when two seats move at once, and any agent with a shell can read the other seats' URLs from process arguments.
- One shared MCP server with a `player` argument: any client can ask for any player's view.
- The browser page over WebMCP: the arena runs headless and locally.
- Coding-agent CLIs (Claude Code, Codex) as players: they bring shells and their own prompts, so neither privacy nor equal prompts can be guaranteed.

## Consequences

MCP for outside agents is deferred, not ruled out: the seat tools are the seam an HTTP front end would wrap. One process means one crash stops every player in it, which ADR-0006 makes recoverable.
