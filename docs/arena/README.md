# Running the arena

The arena plays language models against each other at the Buckshot table through the agent tools. Its code is in `web/src/arena/` and `web/scripts/arena*.ts`; the decisions are ADR-0035 to ADR-0041, ADR-0043, ADR-0044, ADR-0046 and ADR-0048 in `docs/adr/`. This page is the runbook. The results are in [results.md](results.md).

## Endpoints
- An endpoint is an Anthropic Messages or OpenAI Responses API: a provider's own API, or a local proxy that serves several providers behind one key.
- `web/.env` (not committed) holds the API keys the configs name as `keyEnv`. Bun loads it for the runner, and each match gets only its own `PLAYER_*` variables.

## A tournament
- **Config:** a tournament is a JSON config, as in `web/tournaments/example.json`. It names the endpoints, the entrants (model and effort, or a bot) and the pairings.
  - Seeds are either the config seed plus the block, or a list per pairing.
  - `cohort` (optional) names the group the analysis compares the tournament's matches in, such as `"tournament 8"`; the leaderboard titles it by that name. The importer stores it on each match (`matches.cohort`) and stops on a tournament without one; tournaments before it was added get theirs from `LEGACY_COHORTS` in `web/src/analysis/import.ts`. All phases of one run share one cohort. The wrap-up command (below) stamps it into the run dirs if a config lacked it.
  - An engine entrant, `{"engine": {"depth": 6, "budget": 20000}}`, is the Rust search at that strength (`web/src/arena/engine.ts`): a fixed yardstick that sits at seat `Engine/<depth>/<budget>`. With `"reload": "sampled"` (seat `Engine/<depth>/<budget>/sampled`) a line that reaches a reload is valued over sampled deals instead of statically; that engine is much stronger (about 70% against DoN at depth 6, against about 54% with static reload) and takes about 0.2 s a move. It decides from the player's own log and the public board, as the regret scorer does, values every move unpruned (static reload unless sampled) and plays the first best one, in about 20 ms a move. It needs cargo, or `$BUCKSHOT_SEARCH` naming a buckshot-search built with `f64,seats-2`, so it plays two-seat pairings only: the config refuses an engine in a wider one. Its root moves must be Bend's menu: if they differ, or the search fails, the match stops and the position, the menu and the search output are written to `engine-fault-turn-<turn>-<player>.json` in the match directory. A pairing needs at least one model or engine; a config whose entrants are only engines and bots makes no model calls.
  - A model entrant may set `instructionsAddendum`: text appended to the shared instructions for that entrant's agent only (ADR-0048). Give such an entrant its own name; the manifest records the text.
  - Use 10 seeds, each played in both seat orders: 20 matches per pairing.
  - The `3000, 3010–3018` list is balanced by first shooter.
- **Run:**

      cd web && nice -n 10 bun scripts/arena-tournament.ts <config>.json --dir <dir> --parallel 5

  - The first run writes `<dir>/tournament.json`. A later run needs the same config, or one that only grows it.
  - Rerun the same command to resume: finished matches never run again, and an interrupted match resumes from its journal.
  - Don't run two runners on one directory.
  - `--dry-run` prints the schedule.
- **Flags:**
  - `--limit N`: plays at most N matches, the first unfinished in schedule order. The runner exits 1 while matches remain.
  - `--first N`: plays only the first N matches of the schedule, and exits 0 once they are finished.
  - `--cap <model>=N`, `--last <model>`, `--skip <entrant>`, `--forget-cooldown <model>`.
  - `--prefer-account <id>`, repeated in order of preference: a new match pins to these accounts first when accounts are equally loaded. With `--parallel 1 --limit 1`, rerun with a fresh order before each match, such as the account whose window resets first.
  - `--code <commit>=<web dir>`: see code versions below.
- **Where the data goes:** keep tournament directories under `_work/arena/`, which is gitignored. They hold raw harness data: journals, per-call logs with reasoning text, and costs. None of it is committed.

## Code versions
Every match records the git commit of the checkout it played from, `gitCommit()` in `web/src/arena/match.ts`, and refuses to start or resume while the checkout has uncommitted changes to tracked files, so the commit alone identifies the code that played it. A started match resumes only under the commit it started on. A tournament can therefore mix versions: new matches start under the current checkout, and `--code <commit>=<web dir of a checkout of that commit>` resumes older ones. Without a matching checkout they wait.

The commit is the version id: no hand-assigned labels, and no second hash to keep in sync. Because a match refuses to play over a dirty tree, the arena tests that start matches (`bun run test`) also need a clean checkout.

## Usage limits
- **Usage-limit 429s:** a match stopped by one doesn't count as failed. It waits for the reset, and other matches fill its slot.
- **Unpinned agents:** the cooldown is per model.
- **Account pins:** when the endpoint is a proxy over several accounts, an endpoint may list `accounts`, the proxy's ids for them.
  - Each new match pins each agent of that endpoint to one account by sending its id in the header that `ARENA_ACCOUNT_HEADER` names (set it in `web/.env`; an account id without it is an error), and records it in provenance as `account_id`.
  - It picks an account that isn't cooling, with the fewest running matches; ties go to config order.
  - When an account is full, the proxy answers 429, and only that (model, account) pair cools. The match pauses until the reset, and new matches start on another account.
  - Resumed matches always keep their pin. Matches started without a pin stay unpinned.
  - An existing tournament may add `accounts` to an endpoint that had none.
- **Account ids:** they may contain account emails, so they stay out of committed configs. Add them to the run's own copy of the config.
- **Checking a run:** `tools/arena/check_matches.py` finds fallback moves, failed audit flags and unexpected endpoints in a tournament directory.

## Results
- **Stats:**

      bun scripts/arena-stats.ts <dir> [--among a,b,...]

  It prints Bradley-Terry ratings per configuration (model + endpoint + effort), with bootstrap CIs clustered by seed, plus head to head and seat effects.
- **Matched seeds:**

      python3 tools/arena/seed_pairs.py <dir> <entrant> <opponent> [--baseline <dir> <entrant> <opponent>]

  It gives the win share over complete seed pairs and compares the same seeds against another tournament.
- **Matchups, seat and starter effects:** `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` reads the analysis database and rewrites the tables of [analysis/matchups.md](analysis/matchups.md): pooled ratings with intervals, pot share and cash rating, pair effects, seat and starter effects. It takes about 8 minutes under `nice` and counts as a heavy job.
- **Leaderboard:** `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the leaderboard tables of [results.md](results.md) from the same pooled fit, in a few seconds. Its ratings fit matches, not rounds, so they are not the viewer's Round Elo.
- **Viewer:** the arena viewer is the site's Arena page (`/arena`, ADR-0049), served with its API by `web/scripts/arena-viewer.ts` after `bun run build`; see [web/README.md](../../web/README.md#arena-analysis-viewer). There is no replay page (ADR-0055).
- **Regret:** `python3 tools/arena/score_regret.py --db <buckshot.sqlite> --sampled-out <regret file>` scores the agent moves no row covers yet with the Rust evaluator and the sampled reload rule ([analysis/regret.md](analysis/regret.md#production-scoring)); the wrap-up runs it. A regret file holds one run; the viewer, the export and the analyses below read the production file (`PRODUCTION` in `tools/arena/analysis/regret.py`) by default. `python3 tools/arena/analysis/regret.py --doc docs/arena/analysis/regret.md` rewrites the summary tables of [analysis/regret.md](analysis/regret.md) from the stored rows. `tools/arena/analysis/regret_depth.py` draws and summarises a depth 8 re-score of a stratified sample, for its Deeper search section.
- **Luck-adjusted Round Elo:** `python3 tools/arena/analysis/aivat.py --out _work/arena/analysis/derived/luck.sqlite --doc docs/arena/analysis/matchups.md` writes the per-match luck corrections the viewer (`--luck`) and the export read, and the method's table in [analysis/matchups.md](analysis/matchups.md#luck-adjusted-round-elo); the wrap-up runs it. About a minute.
- **Certain mistakes:** `python3 tools/arena/analysis/certain_mistakes.py --doc docs/arena/analysis/certain-mistakes.md` counts moves provably worse from the player's own information, per opportunity, in [analysis/certain-mistakes.md](analysis/certain-mistakes.md).
- **Net points:** `python3 tools/arena/analysis/net_points.py --doc docs/arena/analysis/net-points.md` sums regret per match and seat (round-win equivalents lost), sets it beside Round Elo and the round margin, in [analysis/net-points.md](analysis/net-points.md).
- **Patterns against regret:** `python3 tools/arena/analysis/patterns_regret.py --doc docs/arena/analysis/patterns.md` rewrites the table in [analysis/patterns.md](analysis/patterns.md) that sets each single-move choice pattern against regret, from the regret and knowledge databases, read only, in a few seconds.
- **Cost:**

      bun scripts/arena-cost.ts <dir>

  This is theoretical cost at `web/src/arena/prices.json` list prices; a subscription plan bills nothing per call.

## Wrap-up
`python3 tools/arena/wrap_tournament.py --run-dir <dir> --importer <checkout> --cohort "<name>"`, inside `nix develop` from the main checkout, imports finished tournaments and refreshes everything derived from them: the steps are in its docstring. It is rerunnable (a `wrapup/state.json` in the run dir records finished steps), stops on the first failed check, and rewrites doc tables in the working tree without committing. `--dry-run` lists the steps.

## Deploying the online site
The wrap-up's `export` step writes the aggregates to `web/online/data`. Deploying them is off by default. `wrap_tournament.py --deploy` adds a `deploy` step after `export`: it uploads a Worker version without traffic, checks it at its preview URL (the privacy scan on the files it serves, `/` and `/arena` answering, every `/data/*.json` equal to the export), then promotes it to the live domain. A failed check stops the run and nothing is promoted.

By hand, from `web/` in `nix develop`, with the deploy settings loaded (`set -a; . <deploy env file>; set +a`):

- `bun run deploy:preview --alias <name>` uploads, checks and prints `{"versionId", "url", "problems"}`; exit 1 when a check fails. The preview URL is `https://<alias>-buckshot.<workers.dev subdomain>.workers.dev`. It is public and holds the same aggregates as the live site. An alias is lowercase letters, digits and dashes, starting with a letter; reusing one moves it to the new version.
- `bun run deploy:promote <versionId>` sends all traffic to that version.
- `bun run deploy:online` deploys to the live domain in one step, with no preview.

The deploy env file (gitignored, mode 600) holds `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` and `ONLINE_DOMAIN`, the live domain. The token needs to edit Workers scripts and the zone's Worker routes and to read account settings. `cf auth login` also works for the by-hand commands. `cf` needs Node, so run everything under `nix develop`.

## Reasoning settings
- **Claude 5.5 models:** `adaptive` thinking with an effort and `display: "summarized"` (their default `omitted` returns no text).
  - haiku 5.5 off sends `disabled`.
  - sonnet 5.5 off sends `between_tools`.
  - opus 5.5 off sends `disabled`. It is accepted (HTTP 200, no thinking block); `between_tools` is rejected with a 400.
- **claude-haiku-4-5:** thinking budgets.
- **GPT models:** `reasoning.effort` and `reasoning.summary: "detailed"`.
  - Some proxies rewrite effort `none` to `low` for gpt-5.6 models; the upstream accepts `none`.
  - gpt-6 models pass `none` through.
  - gpt-6.1-sol rejects `none` upstream.
- **`minimal`** sends the same request as `low` on every model except haiku 4.5.
