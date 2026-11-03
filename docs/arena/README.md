# Running the arena

The arena plays language models against each other at the Buckshot table through the agent tools. Its code is in `web/src/arena/` and `web/scripts/arena*.ts`; the decisions are ADR-0035 to ADR-0042 and ADR-0044 to ADR-0046 and ADR-0048 in `docs/adr/`. This page is the runbook. The results so far are in [results.md](results.md).

## Endpoints
- Models are reached through CLIProxyAPI (CPA), hosted on hp-server at `https://hub.dog-minnow.ts.net`.
  - Anthropic Messages is at the root and OpenAI Responses at `/v1`.
  - The management API is `/v0/management/...` and `/v8/management/config/...`; its password is the container's `MANAGEMENT_PASSWORD`.
  - The old local container on `127.0.0.1:8318` is retired. Matches that recorded that URL resume only through a forwarder that serves it, because an endpoint change stops a resume.
- DeepSeek is the one model reached through 9router (`http://localhost:20128/v1`). Its free tier has been refusing requests (429 FreeUsageLimitError). OpenCode Zen is never used.
- `web/.env` (not committed) holds `CPA_KEY` and `NINEROUTER_KEY`. Bun loads it for the runner, and each match gets only its own `PLAYER_*` variables.

## A tournament
- **Config:** a tournament is a JSON config, as in `web/tournaments/`. It names the endpoints, the entrants (model and effort, or a bot) and the pairings.
  - Seeds are either the config seed plus the block, or a list per pairing.
  - `cohort` (optional) names the group the analysis compares the tournament's matches in, such as `"tournament 8"`; the leaderboard titles it by that name. Tournaments before it was added get theirs from `cohort_of` in `tools/arena/analysis/load.py`. All phases of one run share one cohort. The wrap-up command (below) stamps it into the run dirs if a config lacked it.
  - A model entrant may set `instructionsAddendum`: text appended to the shared instructions for that entrant's agent only (ADR-0048). Give such an entrant its own name, as in `astra-recall.json`, and the manifest records the text.
  - Use 10 seeds, each played in both seat orders: 20 matches per pairing.
  - The `3000, 3010–3018` list is balanced by first shooter.
- **Run:**

      cd web && nice -n 10 bun scripts/arena-tournament.ts tournaments/<config>.json --dir <dir> --parallel 5

  - The first run writes `<dir>/tournament.json`. A later run needs the same config, or one that only grows it.
  - Rerun the same command to resume: finished matches never run again, and an interrupted match resumes from its journal.
  - Don't run two runners on one directory.
  - `--dry-run` prints the schedule.
- **Flags:**
  - `--limit N`: plays at most N matches, the first unfinished in schedule order. The runner exits 1 while matches remain.
  - `--cap <model>=N`, `--last <model>`, `--skip <entrant>`, `--forget-cooldown <model>`.
  - `--prefer-account <id>`, repeated in order of preference: a new match pins to these accounts first when accounts are equally loaded. With `--parallel 1 --limit 1`, rerun with a fresh order before each match, such as the account whose window resets first.
  - `--code <code_sha>=<web dir>`: see code versions below.
- **Where the data goes:** keep tournament directories under `_work/arena/`, which is gitignored. They hold raw harness data: journals, per-call logs with reasoning text, and costs. None of it is committed.

## Code versions
Every match records a code hash, `codeSha()` in `web/src/arena/match.ts`, a hash of the files that play a match. A started match resumes only under the code it started on. A tournament can therefore mix versions: new matches start under the current checkout, and `--code <sha>=<web dir of a checkout of that version>` resumes older ones. Without a matching checkout they wait.

Use the hash, not a hand-assigned version id. It changes exactly when gameplay code changes, so two different versions can't share a label.

## Usage limits
- **Usage-limit 429s:** a match stopped by one doesn't count as failed. It waits for the reset, and other matches fill its slot.
- **Unpinned agents:** the cooldown is per model. CPA picks the account, and its session affinity (24 h) keeps an agent's conversation on one account until that account fails.
- **Account pins (ADR-0042):** an endpoint may list CPA `accounts`, the `id` of each entry in `GET /v0/management/auth-files`.
  - Each new match pins each agent of that endpoint to one account, with the `X-CPA-Auth-ID` header, and records it in provenance as `cpa_auth_id`.
  - It picks an account that isn't cooling, with the fewest running matches; ties go to config order.
  - When an account is full, CPA answers 429, and only that (model, account) pair cools. The match pauses until the reset, and new matches start on another account.
  - Resumed matches always keep their pin. Matches started without a pin stay unpinned.
  - An existing tournament may add `accounts` to an endpoint that had none.
- **Account ids:** they contain account emails, so they stay out of committed configs. Add them to the run's own copy of the config.

## Quota-limited runs
The Claude subscription is shared with other work, so long runs go through `tools/arena/run-quota-limited.sh` under launchd. It stops for good, with no resume after resets, when:
- the least-used Claude account reaches the Claude line (default: 0.78 to start, 0.80 while playing);
- the runner fails;
- `tools/arena/check_matches.py` finds a fallback move, a failed audit flag or an unexpected endpoint;
- the first `CAP` matches are finished.

Codex isn't checked there: use account pins, so a full Codex account pauses only its own matches.

    printf %s "$MANAGEMENT_PASSWORD" > <dir>/.mgmt && chmod 600 <dir>/.mgmt
    launchctl submit -l com.aditya.buckshot-<name> -o <dir>/runner.log -e <dir>/runner.log -- \
      /usr/bin/env TD=<dir> CONFIG=<config> WEB=<checkout>/web LABEL=com.aditya.buckshot-<name> CAP=40 \
      /bin/sh tools/arena/run-quota-limited.sh

- Delete `.mgmt` when the run ends.
- `tools/arena/quota_guard.py` prints every account's windows. CPA reports no Claude 7-day window, so that window can't be checked. A CPA restart empties CPA's Codex quota data until the next Codex reply.
- `launchctl submit` jobs don't survive a reboot.
- A T3 restart ends agent sessions and their heartbeats, but not launchd jobs.

## Results
- **Stats:**

      bun scripts/arena-stats.ts <dir> [--among a,b,...]

  It prints Bradley-Terry ratings per configuration (model + endpoint + effort), with bootstrap CIs clustered by seed, plus head to head and seat effects.
- **Matched seeds:**

      python3 tools/arena/seed_pairs.py <dir> <entrant> <opponent> [--baseline <dir> <entrant> <opponent>]

  It gives the win share over complete seed pairs and compares the same seeds against another tournament.
- **Matchups, seat and starter effects:** `python3 tools/arena/analysis/matchups.py --doc docs/arena/analysis/matchups.md` reads the analysis database and rewrites the tables of [analysis/matchups.md](analysis/matchups.md): pooled ratings with intervals, pot share and cash rating, pair effects, seat and starter effects. It takes about 70 minutes under `nice` and counts as a heavy job.
- **Leaderboard:** `python3 tools/arena/analysis/leaderboard.py --doc docs/arena/results.md` rewrites the leaderboard tables of [results.md](results.md) from the same pooled fit, in a few seconds. They match the viewer's leaderboards.
- **Regret:** `bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived.sqlite> --match <name>` scores one match's agent moves with the minimax player, about a third of a second per decision. `python3 tools/arena/analysis/regret.py --doc docs/arena/analysis/regret.md` rewrites the summary tables of [analysis/regret.md](analysis/regret.md) from the stored rows. `tools/arena/analysis/regret_depth.py` draws and summarises a depth 8 re-score of a stratified sample, for its Deeper search section.
- **Certain mistakes:** `python3 tools/arena/analysis/certain_mistakes.py --doc docs/arena/analysis/certain-mistakes.md` counts moves provably worse from the player's own information, per opportunity, in [analysis/certain-mistakes.md](analysis/certain-mistakes.md).
- **Net points:** `python3 tools/arena/analysis/net_points.py --doc docs/arena/analysis/net-points.md` sums regret per match and seat (round-win equivalents lost), sets it beside Round Elo and the round margin, and prices a deeper rescoring, in [analysis/net-points.md](analysis/net-points.md).
- **Patterns against regret:** `python3 tools/arena/analysis/patterns_regret.py --doc docs/arena/analysis/patterns.md` rewrites the table in [analysis/patterns.md](analysis/patterns.md) that sets each single-move choice pattern against regret, from the regret and knowledge databases, read only, in a few seconds.
- **Cost:**

      bun scripts/arena-cost.ts <dir>

  This is theoretical cost at `web/src/arena/prices.json` list prices. CPA plans are subscriptions, so nothing is billed.

## Wrap-up
`python3 tools/arena/wrap_tournament.py --run-dir <dir> --importer <worktree> --cohort "<name>"`, inside `nix develop` from the main checkout, imports finished tournaments and refreshes everything derived from them: the steps are in its docstring. It is rerunnable (a `wrapup/state.json` in the run dir records finished steps), stops on the first failed check, and rewrites doc tables in the working tree without committing. `--dry-run` lists the steps.

## Reasoning settings
- **Claude 5.5 models:** `adaptive` thinking with an effort and `display: "summarized"` (their default `omitted` returns no text).
  - haiku 5.5 off sends `disabled`.
  - sonnet 5.5 off sends `between_tools`.
  - opus 5.5 off sends `disabled`. The hub accepted it in a probe on 2026-10-29 (HTTP 200, no thinking block); `between_tools` is rejected with a 400.
- **claude-haiku-4-5:** thinking budgets.
- **GPT models:** `reasoning.effort` and `reasoning.summary: "detailed"`.
  - CPA rewrites effort `none` to `low` for gpt-5.6 models. The upstream accepts it; a CPA patch is in progress.
  - gpt-6 models pass `none` through.
  - gpt-6.1-sol rejects `none` upstream.
- **`minimal`** sends the same request as `low` on every model except haiku 4.5.
