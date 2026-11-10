# No game table in the release

The released site is the benchmark only: the Arena and Replay pages of ADR-0049, at the hp viewer and online (ADR-0050). The browser game table, the Play page at `/` with its WebMCP tools (ADR-0030), is gone, and `/` moves to `/arena`. Its UI code and its browser scripts are deleted, not hidden behind a flag, so the release carries no half-maintained page.

What the benchmark uses stays: the Bend bridge and driver (`web/src/bend.ts`, `web/src/driver.ts`), the domain, text and seeded RNG modules, the agent tools in `web/src/agent/` with their stdio MCP server, and the table drawing the replay uses (`web/src/board.ts`, `web/src/board-view.ts`, `web/src/table.css`).

## Consequences

- The site has one page group and one stylesheet set; the shell holds only the arena's Model.
- Bringing the table back means restoring its files from the history before this ADR (`web/src/main.ts`, `model.ts`, `view.ts`, `titles.ts`, `webmcp.ts`, `styles.css`) and its Play route.
