# The web app is a static page with no server

`bun run rules` compiles `sim/bend-mp/web.bend` to JavaScript, and the page runs the machine, the AIs and the driver in the browser. There is no game server, no accounts and no network play, and the output of `vite build` is plain files. One browser tab holds the whole match, hidden shell order included, so privacy comes from what views and tools carry (ADR-0021), not from keeping state away from the page. The stdio MCP server (ADR-0029) is a separate process with its own table.

## Considered Options

- An authoritative game server with remote players: it would need the machine hosted and trusted, and networking is outside the model (ADR-0018).
