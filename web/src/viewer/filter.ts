import { modelFamily } from "../arena/model-names.ts";

// What the run list and the leaderboard are narrowed to, kept in the query
// string beside the sort. Each field is empty for "any".

export const FILTER_FIELDS = ["model", "vs", "family", "effort"] as const;

export type Filter = Readonly<Record<(typeof FILTER_FIELDS)[number], string>>;

export const NO_FILTER: Filter = { model: "", vs: "", family: "", effort: "" };

export const filterFromQuery = (query: URLSearchParams): Filter => ({
  model: query.get("model") ?? "",
  vs: query.get("vs") ?? "",
  family: query.get("family") ?? "",
  effort: query.get("effort") ?? "",
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

const hasFamilyAndEffort = (filter: Filter, { model, effort }: Played): boolean =>
  (filter.family === "" || (model !== undefined && modelFamily(model) === filter.family)) && (filter.effort === "" || effort === filter.effort);

/** One row of the leaderboard: its family, effort and model, when it is the one the model filter names. */
export const rowMatches = (filter: Filter, played: Played): boolean => hasFamilyAndEffort(filter, played) && (filter.model === "" || played.model === filter.model);

/** Each wanted model is played by an agent of its own, so a head to head needs two agents, even of one model. */
const playedEach = (agents: ReadonlyArray<Played>, wanted: ReadonlyArray<string>): boolean => {
  const [model, ...rest] = wanted;

  return model === undefined || agents.some((agent, index) => agent.model === model && playedEach(agents.toSpliced(index, 1), rest));
};

/**
 * A run whose agents are the filter's: its family and effort narrow the agents that count, the model and vs
 * must each be played by one of them, and with neither some agent must be left.
 */
export const runMatches = (filter: Filter, agents: ReadonlyArray<Played>): boolean => {
  const counted = agents.filter((agent) => hasFamilyAndEffort(filter, agent));
  const wanted = [filter.model, filter.vs].filter((model) => model !== "");

  if (wanted.length > 0) return playedEach(counted, wanted);

  return filter.family === "" && filter.effort === "" ? true : counted.length > 0;
};
