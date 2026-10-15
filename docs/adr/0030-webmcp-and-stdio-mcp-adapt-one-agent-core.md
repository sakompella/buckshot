# WebMCP and stdio MCP adapt one agent core

The three tools `get_game`, `play_move` and `new_match` are defined once in `web/src/agent/`, with no DOM, page or MCP SDK in it. Two front ends adapt them. WebMCP registers them with the page's model context, so an agent plays the table a person is looking at, and carries calls into the app through Foldkit ports. It needs a Chrome flag. A stdio MCP server (`bun run mcp`) holds one headless table per process and plays the Story and DoN seats itself, for Claude Code or Codex with no browser. One core keeps schemas, privacy and refusal text identical in both. Separate server processes do not share a match.

## Consequences

The arena (ADR-0005) uses neither front end. It binds its own seat tools in one process.
