# Tournament database

The internal analytical database is `_work/arena/analysis/buckshot.sqlite` in the main checkout. It is Git-ignored. Original tournament directories remain the source of truth. Nothing is published, and the importer never writes to a tournament directory.

## Import and rebuild

From `web/`, after installing the locked dependencies and building the rules with `nix develop --command bun run --cwd web rules` from the repository root:

```sh
bun scripts/arena-import.ts --db /absolute/path/to/buckshot.sqlite \
  --skips /absolute/path/to/skips.json \
  /absolute/path/to/tournament-1 /absolute/path/to/tournament-2 /absolute/path/to/tournament-3
```

`--skips` is optional. It takes a JSON object mapping absolute tournament paths to arrays of exact scheduled match names. This is an explicit disposition, not a guess based on missing files. Keep this local file beside the database and record its evidence in the validation report. Tournament 1's documented 123 skipped matches include 41 started partial matches and 82 never-started matches. The partial matches retain their moves and costs.

Run the same command after more matches finish. Unchanged matches are not replayed. Changed matches refresh in a transaction per tournament. Stable IDs derive from the tournament's creation date and name, the scheduled match name, and the observation's position. Copies of the same tournament should not be imported as separate tournaments. The database retains previous raw observations when files change. Analytical tables describe the latest imported snapshot, not every historical snapshot.

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

`matches.status` is `completed`, `partial`, `unstarted` or `skipped`. An explicitly skipped match that already has logs stays `partial`, with `disposition = 'skipped'`. A failed call does not make a match a loss. Its status is `failed`; it and any later calls remain separate observations. Raw fault, reminder and resumed events remain in `source_records`. Retries internal to an SDK request that did not emit a call line are not invented.

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

The local report is `_work/arena/analysis/VALIDATION.md`. It records the source snapshot, table counts, usage and costs, report comparisons and discrepancies. Tournament 1's 2,017 completed matches and $971.5335 agree with its progress report. Tournament 2 has 80 completed matches and $58.8854. Tournament 3 is live; historical reports and its 40-match cap do not describe all 60 scheduled entries. Its three partial matches and unstarted work remain distinct from scored results. Detailed database validation results are recorded after import in the local report.
