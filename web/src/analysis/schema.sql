PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS tournaments (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, source_dir TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL, git_commit TEXT NOT NULL, status TEXT NOT NULL,
  config_json TEXT NOT NULL, source_record TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS entrants (
  id TEXT PRIMARY KEY, tournament_id TEXT NOT NULL REFERENCES tournaments(id), name TEXT NOT NULL,
  model TEXT, provider TEXT, endpoint_category TEXT, effort TEXT, config_json TEXT NOT NULL,
  UNIQUE(tournament_id, name)
);
CREATE TABLE IF NOT EXISTS matches (
  id TEXT PRIMARY KEY, tournament_id TEXT NOT NULL REFERENCES tournaments(id), name TEXT NOT NULL,
  pairing INTEGER NOT NULL, block INTEGER NOT NULL, seed INTEGER NOT NULL, seed_block_id TEXT NOT NULL,
  status TEXT NOT NULL, disposition TEXT, status_reason TEXT, started_at TEXT, ended_at TEXT,
  code_hash TEXT, rules_hash TEXT, instructions_hash TEXT, source_dir TEXT NOT NULL,
  schedule_json TEXT NOT NULL, manifest_json TEXT, source_record TEXT,
  fingerprint TEXT NOT NULL, replay_status TEXT NOT NULL,
  UNIQUE(tournament_id, name)
);
CREATE TABLE IF NOT EXISTS match_seats (
  match_id TEXT NOT NULL REFERENCES matches(id), position INTEGER NOT NULL,
  entrant_id TEXT NOT NULL REFERENCES entrants(id), player TEXT NOT NULL, label TEXT NOT NULL,
  cash REAL, win_share REAL, provenance_json TEXT,
  PRIMARY KEY(match_id, position)
);
CREATE TABLE IF NOT EXISTS source_files (
  path TEXT PRIMARY KEY, tournament_id TEXT NOT NULL REFERENCES tournaments(id), match_id TEXT REFERENCES matches(id),
  sha256 TEXT NOT NULL, bytes INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS source_records (
  id TEXT PRIMARY KEY, path TEXT NOT NULL, line INTEGER NOT NULL, raw TEXT NOT NULL,
  current INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS records_path ON source_records(path, current, line);
CREATE TABLE IF NOT EXISTS decisions (
  id TEXT PRIMARY KEY, match_id TEXT NOT NULL REFERENCES matches(id), ordinal INTEGER NOT NULL,
  journal_seq INTEGER, turn INTEGER NOT NULL, player TEXT NOT NULL, position INTEGER NOT NULL,
  selected_move INTEGER NOT NULL, label TEXT NOT NULL, by_whom TEXT NOT NULL,
  visible_json TEXT, legal_json TEXT, delivered_json TEXT NOT NULL,
  view_provenance TEXT, source_record TEXT NOT NULL REFERENCES source_records(id),
  UNIQUE(match_id, ordinal)
);
CREATE TABLE IF NOT EXISTS calls (
  id TEXT PRIMARY KEY, match_id TEXT NOT NULL REFERENCES matches(id), decision_id TEXT REFERENCES decisions(id),
  ordinal INTEGER NOT NULL, player TEXT NOT NULL, position INTEGER NOT NULL,
  model TEXT NOT NULL, provider TEXT NOT NULL, api TEXT NOT NULL, t TEXT NOT NULL,
  status TEXT NOT NULL, error TEXT, stop_reason TEXT NOT NULL, latency_ms REAL,
  input_tokens REAL, output_tokens REAL, cache_read_tokens REAL, cache_write_tokens REAL,
  cache_write_1h_tokens REAL, reasoning_tokens REAL, cost_usd REAL,
  reasoning_text TEXT NOT NULL, reasoning_provenance TEXT NOT NULL, response_text TEXT NOT NULL,
  tool_calls_json TEXT NOT NULL, usage_json TEXT NOT NULL, source_record TEXT NOT NULL REFERENCES source_records(id),
  link_method TEXT, UNIQUE(match_id, ordinal)
);
CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS entrants_model_effort ON entrants(model, effort);
CREATE INDEX IF NOT EXISTS matches_seed ON matches(tournament_id, seed, pairing, block);
CREATE INDEX IF NOT EXISTS matches_code ON matches(code_hash, status);
CREATE INDEX IF NOT EXISTS seats_entrant ON match_seats(entrant_id, match_id);
CREATE INDEX IF NOT EXISTS decisions_turn ON decisions(match_id, turn, player);
CREATE INDEX IF NOT EXISTS calls_decision ON calls(decision_id);
CREATE INDEX IF NOT EXISTS calls_model ON calls(model, match_id);
CREATE VIEW IF NOT EXISTS match_totals AS
SELECT m.id AS match_id, COUNT(c.id) AS model_calls, SUM(c.cost_usd) AS known_cost_usd,
  SUM(CASE WHEN c.id IS NOT NULL AND c.cost_usd IS NULL THEN 1 ELSE 0 END) AS unpriced_calls,
  SUM(c.input_tokens) AS input_tokens, SUM(c.output_tokens) AS output_tokens,
  SUM(c.cache_read_tokens) AS cache_read_tokens, SUM(c.cache_write_tokens) AS cache_write_tokens,
  SUM(c.reasoning_tokens) AS reasoning_tokens
FROM matches m LEFT JOIN calls c ON c.match_id = m.id GROUP BY m.id;
