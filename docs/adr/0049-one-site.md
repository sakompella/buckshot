# One site

> Amended 2026-11-10 by ADR-0053: the Play page is gone and `/` moves to `/arena`.
> Amended 2026-11-11 by ADR-0055: the Replay page is gone; the site is the Arena page only.

The game and the arena analysis viewer are one Foldkit app (`web/src/site/`) with three pages, each at a real URL:

- **Play** at `/`: the game, run entirely in the browser as before (ADR-0027).
- **Arena** at `/arena`: the analysis viewer's sections. The filter (`offModels`, `offEfforts`) and the open leaderboard row (`row`) are query parameters.
The URL is the source of truth for what the arena shows. Each change to it rewrites the URL, so a link shares it and a reload restores it. Old links to the viewer's sections (`/#scatter`) move to `/arena#scatter`.

The shell holds the game's Model always and the arena's only once Arena is first opened, so Play never asks for the arena's data. The game's Ports (WebMCP, ADR-0030) stay on the one runtime. Each page brings its own global stylesheet, and only the shown page's is in the document, because the two set the same root variables and elements.

`web/scripts/arena-viewer.ts` serves the Vite build (`web/dist`) with the viewer's read-only `/api/*` beside it, and answers every other path with the page, which routes itself. The same `dist` on a static host still plays; Arena then says it needs the arena data. `bun run dev` proxies `/api` to a viewer on its default port.

This replaces the viewer's separate Bun-bundled page, and amends ADR-0027: the build is still plain files and the game still needs no server, but two of the site's pages read a server's API when one is there.

## Considered Options

- **Two apps with links between them:** the simplest change, but the game and the viewer would keep two bundlers and two looks, and the planned single deploy (one Worker serving the build and the API) would still serve two sites.
- **Hash routes (`/#/replay/…`):** they work on any static host without a fallback, but the viewer already uses the hash for its section anchors, and the two would fight over it.
- **A Vite multi-page build (`index.html` and `arena.html`):** each page loads on its own, but moving between them reloads the page and loses the game in progress.

## Consequences

- One bundle holds both pages. Code-splitting the arena behind a dynamic import is possible later and is not needed yet.
- The viewer serves the build from disk, so `bun run build` must run before the viewer starts, and again after a change to the page. The server needs no restart for a new build.
