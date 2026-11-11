# The online site: aggregates on Cloudflare

The site (ADR-0049) also runs on Cloudflare at a public domain as an assets-only Worker, built with `vite build --mode online` through the `cf` CLI (`web/cloudflare.config.ts`; no Wrangler). The online build serves aggregate data only: per-config and per-config-pair statistics (ratings and intervals, item usage, odds tallies, certain-mistake rates, seat balance, run health). It carries no match, decision, replay or raw text, no match ids or seeds. The Replay page, the match list, Comebacks and Upsets, replay links and the per-move charts exist only in the local site, which keeps everything.

`web/scripts/arena-export.ts` writes the aggregates from the analysis database and the derived databases into `web/online/data/` (gitignored), after a privacy check that fails the export on any email, account id, match id, seed or free text. `wrap_tournament.py` runs it after the derived databases are swapped in. Deploying is manual (`bun run deploy:online` from `web/`), or through a preview version that is checked before it takes the domain (`bun run deploy:preview`, `deploy:promote`, and `wrap_tournament.py --deploy`, off by default; `docs/arena/README.md`).

## Considered Options

- **Per-match files for Replay:** about 73 MB gzipped with model reasoning and responses; online they would be raw text, so they stay local.
- **KV, R2 or D1:** the aggregates are small and change only at a deploy, and static asset requests are free and unlimited, so a binding and a Worker would add code for no gain.
- **Cloudflare Tunnel to the local viewer:** the site would go down with the local server, and the data would not be aggregate-only by construction.
- **Cloudflare Access:** not for now; the site is public.

## Consequences

- The shared sections read the same aggregate files locally (`/api/agg/<name>`) and online (`/data/<name>.json`); only local-only sections load per-seat data.
- `cf` needs Node 22.23 or later (the dev shell has it) and is run with Node, not Bun.
