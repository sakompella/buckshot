# Tournament database

The internal analytical database is `_work/arena/analysis/buckshot.sqlite` in the main checkout. It is Git-ignored. Original tournament directories remain the source of truth. It isn't published openly: the arena viewer shares it behind a password, with a copy that has every email and account id redacted as its download (`web/README.md`). The importer never writes to a tournament directory.

## Import and rebuild

From `web/`, after installing the locked dependencies and building the rules with `nix develop --command bun run --cwd web rules` from the repository root:

```sh
bun scripts/arena-import.ts --db /absolute/path/to/buckshot.sqlite \
  --skips /absolute/path/to/skips.json \
  /absolute/path/to/tournament-1 /absolute/path/to/tournament-2 /absolute/path/to/tournament-3
```

`--skips` is optional. It takes a JSON object of the form `{absoluteTournamentPath: {matchName: reason}}`: each absolute tournament path maps to its exact scheduled match names, and each match name maps to the reason it is not scored. The reason is stored in `matches.status_reason`, so every skip keeps its own. This is an explicit disposition, not a guess based on missing files. Keep this local file beside the database and record its evidence in the validation report. A skipped match that has logs, finished or not, is stored as `partial` and keeps its moves and costs, but it is never scored. Two committed lists feed the file: tournament 1's 120 skipped matches (38 started and partial, 82 never started) and tournament 3's 5 unfinished matches past its 40-match cap.

Run the same command after more matches finish. Unchanged matches are not replayed. A match is unchanged only if its files, schedule entry, skip reason, source directory and the result of checking its manifest against the tournament's configuration are all the same, so changing a tournament's configuration or importing a copy from a new directory refreshes the affected matches. Changed matches refresh in a transaction per tournament. Stable IDs derive from the tournament's creation date and name, the scheduled match name, and the observation's position. Copies of the same tournament should not be imported as separate tournaments. Importing the same tournament from a new directory moves it: its rows point at the new paths, and the observations at the old paths stay as history but are no longer current. The database retains previous raw observations when files change. Analytical tables describe the latest imported snapshot, not every historical snapshot.

For a clean rebuild, import into a **new database path**, check it, then replace the old database while no reader is using it. Do not delete the old database first. The same inputs and price table produce the same analytical rows. The command does not delete tournaments omitted from an incremental import.

Live files are read once per match. A snapshot can straddle an append or manifest update. Unterminated JSONL tails are retained but not counted until a newline arrives. Refresh after the writer settles. Import failures roll back that tournament and leave earlier imported tournaments intact.

## Tables

| Table | Contents |
|---|---|
| `tournaments` | Source directory, original configuration, creation date, Git commit and derived completion status. Its ID is also the default rating-pool boundary. |
| `entrants` | Tournament-local name, configured model, API family in `provider`, endpoint category, effort and complete entrant configuration. Actual per-call provider IDs are in `calls`. |
| `matches` | Schedule, pairing, block, seed, seed-block ID, original manifest, code and instructions hashes, timestamps, status, explicit disposition and replay result. |
| `match_seats` | Position from 1 in table order, player letter, entrant, final cash, fractional win share and provenance. |
| `decisions` | Accepted moves in chronological order, including forced and fallback moves. Turn, journal sequence, player, selected move, label, reconstructed own-player view and legal alternatives. |
| `calls` | Each physical model reply, including failed replies, provider, usage, list-price cost, latency, exact saved reasoning text, response text and tool arguments. |
| `source_files` | Latest file hashes and byte lengths for imported JSON/JSONL files. |
| `source_records` | Exact raw JSON records and JSONL lines, source path and 1-based line, parse problems and whether the observation belongs to the latest snapshot. Prior versions remain available. |
| `issues` | Import discrepancies, malformed records, repeated or conflicting moves and replay failures. |
| `metadata` | Schema version and exact price table with its SHA-256. |
| `match_totals` | View over calls. Known cost, unpriced-call count and token totals, including partial matches and failures. |

IDs are SHA-256 strings. Indexes cover model and effort, tournament/seed/pairing/block, code, entrant, match/turn/player and decision-call joins. A seed-block ID includes tournament, pairing, block and seed. Keep this relationship when resampling results. Do not treat seat swaps as independent seeds.

`matches.status` is `completed`, `partial`, `unstarted` or `skipped`. `completed` is the scored set: the manifest says finished and the match is not skipped, its standings cover every scheduled player exactly once, the log has its end event, and the replay reaches a finished match whose cash equals the standings. A finished match that fails any of these stays `partial`, has no win share and gets an issue. An explicitly skipped match that already has logs stays `partial`, with `disposition = 'skipped'`, even if it finished. A skipped match with no logs is `skipped`. A failed call does not make a match a loss. Its status is `failed`; it and any later calls remain separate observations. Raw fault, reminder and resumed events remain in `source_records`. Retries internal to an SDK request that did not emit a call line are not invented.

Missing values are SQL NULL. Zero usage remains zero. `reasoning_tokens` is NULL when the provider did not report it. A match with no calls has NULL cost and token totals. Check `unpriced_calls` before treating known cost as full cost. Costs use the existing `arena/cost.ts` and its tier rules. They are estimates at list prices, not subscription charges.

## Views, reasoning and source evidence

`decisions.visible_json` comes from `agentGame` immediately before each accepted move, using the existing viewer replay and generated Bend rules. `legal_json` is that player's legal move list. These are reconstructed views, not captured original prompts. `delivered_json` retains the actual deliveries for that player's turn. Other events and deliveries can be inspected in the raw records.

No hidden shell order or another player's secrets are copied into a decision view. No spectator frame is stored as agent-visible information. If replay fails, subsequent reconstructed views stay NULL and `issues` explains why. Repeated journal sequences count once in the decision projection but every raw line remains. Conflicting repeats stop view reconstruction and are reported. Call lines are not deduplicated by text, timestamp or usage: identical replies can represent separate paid attempts.

Calls link to the next chosen move by the same player in timestamp order, matching the viewer's attribution. `link_method` labels this heuristic. It is not an exact provider call-ID join. A call without a subsequent accepted move has a NULL decision link. Several replies, reminders and failed attempts can link to one decision.

`reasoning_text` preserves `calls.jsonl`'s `thinking` string exactly. It is provider-returned text, often a reasoning summary, not a complete chain-of-thought trace. The original logger concatenated blocks without separators; the importer does not repair that. Encrypted signatures are not decrypted. Full conversation prompts and durable retry history remain in `session.sqlite`, referenced through `matches.source_dir`; the importer does not open the journal or its WAL. `arena.log` remains there too.

Original manifests provide a combined gameplay `code_hash`, not an independently recorded rules hash. `rules_hash` therefore remains NULL. Do not substitute the current rules hash for historical evidence. Replay uses the current generated rules and reports any divergence. Keep code versions separate when comparing requests. Rating subsets, such as medium-only cross-model games and within-model effort sweeps, must be selected explicitly by entrants/pairings; the importer does not pool them into one rating.

## Queries

Completed-match win shares within each tournament:

```sql
SELECT t.name AS tournament, e.name, e.model, e.effort,
       COUNT(*) AS matches, AVG(s.win_share) AS win_share
FROM match_seats s
JOIN entrants e ON e.id = s.entrant_id
JOIN matches m ON m.id = s.match_id
JOIN tournaments t ON t.id = m.tournament_id
WHERE m.status = 'completed'
GROUP BY t.id, e.id
ORDER BY t.name, win_share DESC;
```

Two-player head-to-head results, preserving position:

```sql
SELECT m.tournament_id, a.entrant_id, b.entrant_id, a.position,
       COUNT(*) AS matches, AVG(a.win_share) AS win_share
FROM matches m
JOIN match_seats a ON a.match_id = m.id
JOIN match_seats b ON b.match_id = m.id AND b.position != a.position
WHERE m.status = 'completed'
  AND (SELECT COUNT(*) FROM match_seats s WHERE s.match_id = m.id) = 2
GROUP BY m.tournament_id, a.entrant_id, b.entrant_id, a.position;
```

Cost and reported reasoning tokens by model and configured effort, including partial work:

```sql
SELECT m.tournament_id, c.model, e.effort, COUNT(*) AS calls,
       SUM(c.cost_usd) AS known_cost_usd,
       SUM(c.cost_usd IS NULL) AS unpriced_calls,
       SUM(c.reasoning_tokens) AS reported_reasoning_tokens,
       SUM(c.reasoning_tokens IS NULL) AS missing_reasoning_counts
FROM calls c JOIN matches m ON m.id = c.match_id
JOIN match_seats s ON s.match_id = c.match_id AND s.position = c.position
JOIN entrants e ON e.id = s.entrant_id
GROUP BY m.tournament_id, c.model, e.effort;
```

Decision sequence with available reasoning and source references:

```sql
SELECT d.ordinal, d.player, d.label, d.legal_json, d.visible_json,
       c.reasoning_text, c.link_method, r.path, r.line
FROM decisions d
LEFT JOIN calls c ON c.decision_id = d.id
JOIN source_records r ON r.id = d.source_record
WHERE d.match_id = :match_id ORDER BY d.ordinal, c.ordinal;

SELECT m.name, i.message FROM issues i
LEFT JOIN matches m ON m.id = i.match_id ORDER BY m.name, i.message;
```

Legal alternatives and own-player views support future opportunity-conditioned strategy and move-review tables. This change adds no solver, behavioral evaluation or frontend integration. A future leaderboard should generate its aggregates here rather than parse tournament directories again.

## Validation

Snapshot of 2026-11-04, the one the derived tables are built from: 2,915 `completed` matches (2,895 scored without a DeepSeek seat), 43 `partial` with logs, every one of those 2,958 replay-validated, 0 issues, in a database of 30 `tournaments` rows (tournaments 1 to 7 and 9; a row is one tournament directory or phase). Tournaments 6, 7 and 9 were added since 2026-10-30; tournament 8 is still running and isn't in it. A copy of that database is what `arena-knowledge.ts` and `arena-regret.ts` read, so later top-up imports do not shift their input. The tables below describe the earlier import of tournaments 1 to 3 and are kept as that record.

Rebuilt on 2026-10-21 into a new file, then swapped in. The import took about 10 minutes on the Mac and 30 on hp. Scoring seed 3030's finished match was an incremental re-import of a copy, about 2 minutes. On 2026-10-22 the tournament-1 leftovers (60 new terra matches and 3 resumed Astra vs haiku 4.5 matches) were added the same way, in 3.5 minutes on hp, and the old file was kept as `buckshot.pre-leftovers.sqlite`. `PRAGMA integrity_check` returned `ok`, the foreign key check was clean and `issues` is empty. The figures below are after that import.

| Tournament | Scheduled | Completed (scored) | Partial, skipped (unscored) | Skipped, never started | Unstarted | Replay validated | List-price cost, including partial work |
|---|---|---|---|---|---|---|---|
| tournament-1 (`cpa-tiers`) | 2,200 | 2,080 | 38 | 82 | 0 | 2,118 | $934.4558 |
| tournament-2 (`opus-effort`) | 80 | 80 | 0 | 0 | 0 | 80 | $58.8854 |
| tournament-3 (`astra-vs-opus-xhigh`) | 60 | 41 | 5 | 0 | 14 | 46 | $42.4880 |
| Total | 2,340 | 2,201 | 43 | 82 | 14 | 2,244 | $1,035.83 |

- Every started match (2,244) replayed and validated against the generated rules. The 96 matches with no logs have replay status `unavailable`. There are 216,291 decisions. Every call has a list price.
- Tournament 2 and tournament 1's first 2,017 scored matches match the tournament reports and the first build exactly: $971.5335 and $58.8854. The leftovers added 63 scored matches, $19.56. On 2026-10-22 Sonnet 5.5's cache-read price was corrected from $0.20 to $0.10 per million tokens (Anthropic's pricing page), and the database was rebuilt clean: only Sonnet's cost changed, $579.48 to $522.84, so tournament 1 is now $934.46 and the total $1,035.83 (earlier figures in this section are before the correction).
- Tournament 3 has 41 scored matches, Opus 22 and Astra 19, matching `results.md`. The 41st is seed 3030's first match, which finished during an uncapped run between 9:20 and 9:23 PM Pacific time; Aditya ruled that it counts. The other 5 matches past the 40-match cap never finished. They carry a skip disposition, are stored as `partial` and are unscored. The other 14 never started. The $42.4880 list-price cost includes all 46 started matches. The first build had 39 scored, 3 partial and $39.94.
- The 2026-10-21 rebuild and its checks ran on the Mac, which holds the tournament directories: `PRAGMA integrity_check` returned `ok`, `issues` is empty and all 2,184 started matches replayed. Rebuilding on another machine needs its own copy of the tournament directories.
- The `--skips` file now holds 125 skips: tournament 1's 120 and tournament 3's 5. All 125 carry `disposition = 'skipped'` and the reason from their committed list. Tournament 1's 38 started matches and tournament 3's 5 are `partial`, and tournament 1's 82 never-started matches are `skipped`. No other match has a disposition. Tournaments 1 and 2 are `completed`. Tournament 3 stays `partial`.

The skips file holds absolute local paths, so it is not committed. The two committed lists hold only match names and reasons: `web/src/analysis/tournament-1-skipped.json` (120 matches) and `web/src/analysis/tournament-3-over-cap.json` (5 matches). Build the file from both, giving each tournament its absolute path:

```sh
bun -e '
const entry = async (f) => { const l = await Bun.file(f).json(); return Object.fromEntries(l.matches.map((m) => [m, l.reason])); };
console.log(JSON.stringify({
  "/absolute/path/to/tournament-1": await entry("web/src/analysis/tournament-1-skipped.json"),
  "/absolute/path/to/tournament-3": await entry("web/src/analysis/tournament-3-over-cap.json"),
}));
' > skips.json
```

Tournament 3's account ids contain emails, so provenance stays in the database and out of committed files.
