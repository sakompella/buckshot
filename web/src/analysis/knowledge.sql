DROP TABLE IF EXISTS matches; DROP TABLE IF EXISTS players; DROP TABLE IF EXISTS decisions; DROP TABLE IF EXISTS clues;
DROP TABLE IF EXISTS items; DROP TABLE IF EXISTS deaths; DROP TABLE IF EXISTS problems;
CREATE TABLE matches (match_id TEXT PRIMARY KEY, name TEXT, tournament TEXT, kind TEXT, status TEXT, disposition TEXT, code_hash TEXT, instructions_hash TEXT, seed INTEGER, seed_block_id TEXT, pairing INTEGER);
CREATE TABLE players (match_id TEXT, player TEXT, position INTEGER, entrant TEXT, model TEXT, effort TEXT, PRIMARY KEY (match_id, player));
CREATE TABLE decisions (
  match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, label TEXT, choice TEXT, legal_json TEXT,
  round INTEGER, remaining INTEGER, shown_live INTEGER, shown_blank INTEGER, sawed INTEGER,
  public_orders INTEGER, public_live_min INTEGER, public_live_max INTEGER, public_live_json TEXT, public_known TEXT,
  private_orders INTEGER, private_live_min INTEGER, private_live_max INTEGER, private_live_json TEXT, private_known TEXT,
  chamber TEXT, source TEXT, clue_ordinal INTEGER, clue_via_adrenaline INTEGER, moves_since_clue INTEGER, own_moves_since_clue INTEGER,
  shot TEXT, item TEXT, item_stolen INTEGER, legal_items_json TEXT, own_items_json TEXT, opponent_items_json TEXT, health_json TEXT,
  exact_key TEXT, belief_key TEXT, PRIMARY KEY (match_id, ordinal));
CREATE TABLE clues (match_id TEXT, learned INTEGER, ordinal INTEGER, player TEXT, kind TEXT, position INTEGER, shell TEXT, via_adrenaline INTEGER, PRIMARY KEY (match_id, learned));
CREATE TABLE items (match_id TEXT, player TEXT, item TEXT, slot INTEGER, round INTEGER, placed_ordinal INTEGER, end TEXT, ended_ordinal INTEGER, by_player TEXT, moves_held INTEGER, own_decisions_held INTEGER);
CREATE TABLE deaths (match_id TEXT, player TEXT, ordinal INTEGER, round INTEGER, items_held INTEGER);
CREATE TABLE problems (match_id TEXT, ordinal INTEGER, message TEXT);
