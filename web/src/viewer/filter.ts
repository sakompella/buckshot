import { modelFamily } from "../arena/model-names.ts";

// What the run list and the leaderboard are narrowed to, kept in the query
// string beside the sort. Each field is empty for "any".

export const FILTER_FIELDS = ["family", "model", "effort", "vs", "vsEffort"] as const;

const FIRST_FIELDS = ["family", "model", "effort"] as const;

const SECOND_FIELDS = ["vs", "vsEffort"] as const;

export type Filter = Readonly<Record<(typeof FILTER_FIELDS)[number], string>>;

export const NO_FILTER: Filter = { family: "", model: "", effort: "", vs: "", vsEffort: "" };

export const filterFromQuery = (query: URLSearchParams): Filter => ({
  family: query.get("family") ?? "",
  model: query.get("model") ?? "",
  effort: query.get("effort") ?? "",
  vs: query.get("vs") ?? "",
  vsEffort: query.get("vsEffort") ?? "",
});

export const writeFilter = (query: URLSearchParams, filter: Filter): void => {
  for (const field of FILTER_FIELDS) {
    if (filter[field] === "") query.delete(field);
    else query.set(field, filter[field]);
  }
};

/** A model played at an effort; either is unknown for an agent that has made no call and has no effort in its manifest. */
export interface Played {
  readonly model?: string | undefined;
  readonly effort?: string | undefined;
}

type Wants = (played: Played) => boolean;

/** The agent the filter looks for: the family, model and effort given, all of one agent. */
const first = (filter: Filter): Wants => ({ model, effort }) =>
  (filter.family === "" || (model !== undefined && modelFamily(model) === filter.family)) && (filter.model === "" || model === filter.model) && (filter.effort === "" || effort === filter.effort);

/** The agent it plays against: the model and effort given. */
const second = (filter: Filter): Wants => ({ model, effort }) => (filter.vs === "" || model === filter.vs) && (filter.vsEffort === "" || effort === filter.vsEffort);

/** One row of the leaderboard: the agent the filter looks for. */
export const rowMatches = (filter: Filter, played: Played): boolean => first(filter)(played);

/** Each wanted agent is played by one of its own, so a head to head needs two agents, even of one model. */
const playedEach = (agents: ReadonlyArray<Played>, wanted: ReadonlyArray<Wants>): boolean => {
  const [next, ...rest] = wanted;

  return next === undefined || agents.some((agent, index) => next(agent) && playedEach(agents.toSpliced(index, 1), rest));
};

/** A run with the agent the filter looks for and, when it names one, another that plays against it. */
export const runMatches = (filter: Filter, agents: ReadonlyArray<Played>): boolean =>
  playedEach(agents, [...(FIRST_FIELDS.some((field) => filter[field] !== "") ? [first(filter)] : []), ...(SECOND_FIELDS.some((field) => filter[field] !== "") ? [second(filter)] : [])]);
