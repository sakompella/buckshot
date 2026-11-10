# Tournament database

The analysis database is `_work/arena/analysis/buckshot.sqlite` by default. It is Git-ignored. Original tournament directories remain the source of truth. It isn't published openly: the arena viewer shares it behind a password, with a copy that has every email and account id redacted as its download (`web/README.md`). The importer never writes to a tournament directory.

## Import and rebuild

From `web/`, after installing the locked dependencies and building the rules with `nix develop --command bun run --cwd web rules` from the repository root:

```sh
bun scripts/arena-import.ts --db /absolute/path/to/buckshot.sqlite \
  --skips /absolute/path/to/skips.json \
  /absolute/path/to/tournament-1 /absolute/path/to/tournament-2 /absolute/path/to/tournament-3
```

`--skips` is optional. It takes a JSON object of the form `{absoluteTournamentPath: {matchName: reason}}`: each absolute tournament path maps to its exact scheduled match names, and each match name maps to the reason it is not scored. The reason is stored in `matches.status_reason`, so every skip keeps its own. This is an explicit disposition, not a guess based on missing files. Keep this local file beside the database. A skipped match that has logs, finished or not, is stored as `partial` and keeps its moves and costs, but it is never scored. Tournament 1 has 120 skipped matches (38 started and partial, 82 never started) and tournament 3 has 5 unfinished matches past its 40-match cap.

Run the same command after more matches finish. Unchanged matches are not replayed. A match is unchanged only if its files, schedule entry, skip reason, source directory and the result of checking its manifest against the tournament's configuration are all the same, so changing a tournament's configuration or importing a copy from a new directory refreshes the affected matches. Changed matches refresh in a transaction per tournament. Stable IDs derive from the tournament's creation date and name, the scheduled match name, and the observation's position. Copies of the same tournament should not be imported as separate tournaments. Importing the same tournament from a new directory moves it: its rows point at the new paths, and the observations at the old paths stay as history but are no longer current. The database retains previous raw observations when files change. Analytical tables describe the latest imported snapshot, not every historical snapshot.

For a clean rebuild, import into a **new database path**, check it, then replace the old database while no reader is using it. Do not delete the old database first. The same inputs and price table produce the same analytical rows. The command does not delete tournaments omitted from an incremental import.

Live files are read once per match. A snapshot can straddle an append or manifest update. Unterminated JSONL tails are retained but not counted until a newline arrives. Refresh after the writer settles. Import failures roll back that tournament and leave earlier imported tournaments intact.

## Tables

| Table | Contents |
|---|---|
| `tournaments` | Source directory, original configuration, creation date, Git commit and derived completion status. Its ID is also the default rating-pool boundary. |
| `entrants` | Tournament-local name, configured model, API family in `provider`, endpoint category, effort and complete entrant configuration. Actual per-call provider IDs are in `calls`. |
| `matches` | Schedule, pairing, block, seed, seed-block ID, cohort (the tournament config's `cohort`), original manifest, code and instructions hashes, timestamps, status, explicit disposition and replay result. |
| `match_seats` | Position from 1 in table order, player letter, entrant, label, final cash, fractional win share and provenance. The label names who played the seat, as the match's manifest records it (`labels`): a model config as `<model>-<effort>`, a bot or a human by its controller, an engine by its seat. For matches from before labels were recorded the importer derives it from the entrant. The label is the config's one key: the import stops when a model seat's label is not its entrant's `<model>-<effort>`, or when two configs (model, effort, effort label, addendum) play under one label. |
| `decisions` | Accepted moves in chronological order, including forced and fallback moves. Turn, journal sequence, player, selected move, label, reconstructed own-player view and legal alternatives. |
| `calls` | Each physical model reply, including failed replies, provider, usage, list-price cost, latency, exact saved reasoning text, response text and tool arguments. |
| `source_files` | Latest file hashes and byte lengths for imported JSON/JSONL files. |
| `source_records` | Exact raw JSON records and JSONL lines, source path and 1-based line, and whether the observation belongs to the latest snapshot. Prior versions remain available. A live match's last line without its newline is read on a later import. |
| `metadata` | Schema version, exact price table with its SHA-256, and the importer files with their SHA-256. |
| `match_totals` | View over calls. Known cost, unpriced-call count and token totals, including partial matches and failures. |

IDs are SHA-256 strings. Indexes cover model and effort, tournament/seed/pairing/block, code, entrant, match/turn/player and decision-call joins. A seed-block ID includes tournament, pairing, block and seed. Keep this relationship when resampling results. Do not treat seat swaps as independent seeds.

`matches.status` is `completed`, `partial`, `unstarted` or `skipped`. `completed` is the scored set: the manifest says finished and the match is not skipped, its standings cover every scheduled player exactly once, the log has its end event, and the replay reaches a finished match whose cash equals the standings. Where two sources disagree the import stops: a manifest that does not decode or disagrees with the tournament config or the schedule, standings that miss a player, a finished manifest without an end event, a JSONL line that does not decode, two different moves logged under one sequence, a replay that refuses a logged move or does not reach the manifest's end and cash, manifest call or token totals that differ from `calls.jsonl`, an unscheduled match directory, or a source file imported before that is gone. The error names the match directory, what disagrees and both values; the tournament's transaction rolls back. A running match (no finished manifest yet) stays `partial`. An explicitly skipped match that already has logs stays `partial`, with `disposition = 'skipped'`, even if it finished. A skipped match with no logs is `skipped`. A failed call does not make a match a loss. Its status is `failed`; it and any later calls remain separate observations. Raw fault, reminder and resumed events remain in `source_records`. Retries internal to an SDK request that did not emit a call line are not invented.

Missing values are SQL NULL. Zero usage remains zero. `reasoning_tokens` is NULL when the provider did not report it. A match with no calls has NULL cost and token totals. Check `unpriced_calls` before treating known cost as full cost. Costs use the existing `arena/cost.ts` and its tier rules. They are estimates at list prices, not subscription charges.

## Views, reasoning and source evidence

`decisions.visible_json` comes from `agentGame` immediately before each accepted move, using the existing viewer replay and generated Bend rules. `legal_json` is that player's legal move list. These are reconstructed views, not captured original prompts. `delivered_json` retains the actual deliveries for that player's turn. Other events and deliveries can be inspected in the raw records.

No hidden shell order or another player's secrets are copied into a decision view. No spectator frame is stored as agent-visible information. Repeated journal sequences (the same move logged twice) count once in the decision projection but every raw line remains. Call lines are not deduplicated by text, timestamp or usage: identical replies can represent separate paid attempts.

Calls link to the accepted move at the turn they were made on. `link_method` says where that turn came from: `logged turn` (the call line records it, as logged since `turn` was added to `calls.jsonl`) or `events turn` (older logs: the turn of the same player's next turn, move, fallback or fault line in `events.jsonl`, which the arena writes when an ask ends). The two must agree where both exist, and a call and its move must be the same player; otherwise the import fails with a dump. A call with no accepted move at its turn has a NULL decision and `link_method = 'unlinked'`: a failed call is never given a later turn's move. Several replies, reminders and failed attempts, across pauses and resumes, can link to one decision.

`reasoning_text` preserves `calls.jsonl`'s `thinking` string exactly. It is provider-returned text, often a reasoning summary, not a complete chain-of-thought trace. The original logger concatenated blocks without separators; the importer does not repair that. Encrypted signatures are not decrypted. Full conversation prompts and durable retry history remain in `session.sqlite`, referenced through `matches.source_dir`; the importer does not open the journal or its WAL. `arena.log` remains there too.

Original manifests provide a combined gameplay `code_hash`, not an independently recorded rules hash. Replay uses the current generated rules, and a divergence stops the import. A replayed match records in `validated_with` the hash of the code that validated it: `import.ts`, every local module it imports (the replay, the agent view, `bend.ts`, the generated Bend rules and the files that play a match) and `schema.sql`, listed with their SHA-256 in the `importer_files` metadata row (`web/src/analysis/importer-hash.ts`). The viewer, `arena-knowledge.ts`, `rust-search-inputs.ts`, the export and the Python analysis scripts refuse a database with a validated match whose hash is not this checkout's; re-import it after a rules or replay change. The fingerprint includes the hash, so the re-import replays every match. Keep code versions separate when comparing requests. Rating subsets, such as medium-only cross-model games and within-model effort sweeps, must be selected explicitly by entrants/pairings; the importer does not pool them into one rating.

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
```

## Validation

Every import replays every started match against the generated rules and records any failure in `issues`; after a rebuild, `PRAGMA integrity_check` returns `ok`, the foreign key check is clean and `issues` is empty. Matches cut from a schedule (never started, or past a match cap) reach the importer through a `--skips` file that maps each tournament directory to `{match name: reason}`. They are stored with `disposition = 'skipped'`, as `partial` when they started, and are not scored.

Account ids may contain emails, so provenance stays in the database and out of committed files.
