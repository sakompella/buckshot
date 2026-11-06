// The `regret` table of a derived database and the columns that depend on how a decision was scored. Shared by
// scripts/arena-regret.ts (the JS player) and scripts/arena-regret-native.ts (the native one), so their rows have one shape.

import { type Regret } from "./regret.ts";

export const CREATE_REGRET = `CREATE TABLE IF NOT EXISTS regret (
    match_id TEXT, ordinal INTEGER, player TEXT, label TEXT,
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT NOT NULL, samples INTEGER NOT NULL CHECK ((reload = 'sampled') = (samples > 0)),
    status TEXT, reason TEXT, values_json TEXT, best TEXT, best_score INTEGER, chosen_score INTEGER, regret INTEGER, exact INTEGER,
    depth INTEGER, limited INTEGER, nodes INTEGER, ms REAL,
    PRIMARY KEY (match_id, ordinal, evaluator, max_depth, budget, reload, samples))`;

/** The columns that depend on how the decision was scored. Only a searched decision has a regret; a fallback or invalid one has none, never 0. */
export const scored = (regret: Regret) => {
  switch (regret.status) {
    case "searched":
      return { values_json: JSON.stringify(regret.values), best: regret.best.label, best_score: regret.best.score, chosen_score: regret.chosen.score, regret: regret.regret, exact: regret.exact ? 1 : 0, depth: regret.depth, limited: regret.limited ? 1 : 0 };
    case "fallback":
      return { values_json: JSON.stringify(regret.values), depth: 0, limited: regret.limited ? 1 : 0 };
    case "invalid":
      return { reason: regret.reason };
  }
};
