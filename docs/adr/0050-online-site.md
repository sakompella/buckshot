# The online site: aggregates on Cloudflare

The site (ADR-0049) also runs on Cloudflare at buckshot.akompella.dev as an assets-only Worker, built with `vite build --mode online` through the `cf` CLI (`web/cloudflare.config.ts`; no Wrangler). The online build serves aggregate data only: per-config and per-config-pair statistics (ratings and intervals, item usage, odds tallies, certain-mistake rates, seat balance, run health). It carries no match, decision, replay or raw text, no match ids or seeds. The Replay page, the match list, Comebacks and Upsets, replay links and the per-move charts exist only in the hp site, which keeps everything.

`web/scripts/arena-export.ts` writes the aggregates from the redacted public database and the derived databases into `web/online/data/` (gitignored), after a privacy check that fails the export on any email, account id, match id, seed or free text. `wrap_tournament.py` runs it after the public copy is made. Deploying is manual: `bun run deploy:online` from `web/`.

## Considered Options

- **Per-match files for Replay:** about 73 MB gzipped with model reasoning and responses; online they would be raw text, so they stay on hp.
- **KV, R2 or D1:** the aggregates are small and change only at a deploy, and static asset requests are free and unlimited, so a binding and a Worker would add code for no gain.
- **Cloudflare Tunnel to the hp viewer:** the site would go down with hp, and the data would not be aggregate-only by construction.
- **Cloudflare Access:** not for now; the site is public.

## Consequences

- The shared sections read the same aggregate files locally (`/api/agg/<name>`) and online (`/data/<name>.json`); only hp-only sections load per-seat data.
- `cf` needs Node 22.23 or later (the dev shell has it) and is run with Node, not Bun.
