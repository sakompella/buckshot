import { Result } from "effect";

import { type PriceTable, type Total, totalsBy } from "./cost.ts";
import { callsOf, finishedNames, readMatch, type TournamentFile } from "./tournament-dir.ts";
import {
  fitRatings,
  headToHead,
  intervalsOf,
  type Interval,
  type Interventions,
  interventionsByEntrant,
  type PlayedMatch,
  type PositionShare,
  resamples,
  type Share,
  sharesByEntrant,
  sharesByPosition,
} from "./tournament-stats.ts";
import { botEntrant, type Tournament } from "./tournament.ts";

// The tournament's report: the stats of its finished matches that agree with
// the schedule, as plain data. scripts/arena-stats.ts prints it.

export const RESAMPLES = 1000;

export const NOTES = [
  "Ratings are per configuration (model, endpoint and effort), not per model.",
  'An effort level is not equal compute across providers: "medium" means something different to each.',
  "Matches with interventions are scored, and flagged.",
];

export interface EntrantRow extends Share {
  readonly entrant: string;
  readonly shareInterval: Interval | undefined;
  readonly rating: number;
  readonly ratingInterval: Interval | undefined;
}

export interface Report {
  readonly name: string;
  /** The entrant rated 0, or undefined when the mean of all entrants is. */
  readonly anchor: string | undefined;
  readonly matches: { readonly scheduled: number; readonly finished: number; readonly scored: number };
  /** Finished matches left out of the stats because their manifest disagrees with the schedule. */
  readonly excluded: ReadonlyArray<{ readonly match: string; readonly problems: ReadonlyArray<string> }>;
  readonly entrants: ReadonlyArray<EntrantRow>;
  readonly seatTerms: ReadonlyArray<{ readonly size: number; readonly position: number; readonly rating: number }>;
  readonly byPosition: ReadonlyArray<PositionShare>;
  readonly pairings: ReadonlyArray<{ readonly entrants: ReadonlyArray<string>; readonly matches: number; readonly shares: ReadonlyArray<{ readonly entrant: string; readonly share: number }> }>;
  readonly interventions: ReadonlyArray<Interventions>;
  /** The scored matches in which a model needed a reminder or an intervention. */
  readonly flagged: ReadonlyArray<{ readonly match: string; readonly entrant: string; readonly reminders: number; readonly interventions: number }>;
  readonly cost: ReadonlyArray<{ readonly entrant: string } & Total>;
  readonly notes: ReadonlyArray<string>;
}

const FREE: Total = { calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 0, unpriced: 0 };

export const reportOf = (dir: string, file: TournamentFile, tournament: Tournament, prices: PriceTable, resampleCount: number = RESAMPLES): Report => {
  const { config } = tournament;
  const finished = finishedNames(dir, file.schedule);
  const read = file.schedule.flatMap((match) => (finished.has(match.name) ? [{ match, result: readMatch(dir, tournament, match) }] : []));
  const played: ReadonlyArray<PlayedMatch> = read.flatMap(({ result }) => Result.match(result, { onFailure: () => [], onSuccess: (match) => [match] }));
  const shares = sharesByEntrant(played);
  const anchor = [...shares.keys()].find((name) => botEntrant(config, name) === "DoN");

  const ratings = fitRatings(played, anchor);
  const replicates = resamples(played, resampleCount, config.seed);
  const shareIntervals = intervalsOf(replicates.map((replicate) => new Map([...sharesByEntrant(replicate)].map(([entrant, { share }]) => [entrant, share]))));
  const ratingIntervals = intervalsOf(replicates.map((replicate) => fitRatings(replicate, anchor).entrants));
  const costs = totalsBy(prices, file.schedule.flatMap((match) => callsOf(dir, match)));
  const interventions = interventionsByEntrant(played);

  return {
    name: config.name,
    anchor,
    matches: { scheduled: file.schedule.length, finished: finished.size, scored: played.length },
    excluded: read.flatMap(({ match, result }) => Result.match(result, { onFailure: (problems) => [{ match: match.name, problems }], onSuccess: () => [] })),
    entrants: [...shares].map(([entrant, share]) => ({ entrant, ...share, shareInterval: shareIntervals.get(entrant), rating: ratings.entrants.get(entrant) ?? 0, ratingInterval: ratingIntervals.get(entrant) })).toSorted((left, right) => right.rating - left.rating),
    seatTerms: ratings.seats,
    byPosition: sharesByPosition(played),
    pairings: headToHead(played).map(({ matches, entrants }) => ({ entrants: entrants.map(({ entrant }) => entrant), matches, shares: entrants })),
    interventions: interventions.toSorted((left, right) => left.entrant.localeCompare(right.entrant)),
    flagged: played.flatMap((match) => match.players.filter((player) => player.interventions + player.reminders > 0).map((player) => ({ match: match.name, entrant: player.entrant, reminders: player.reminders, interventions: player.interventions }))),
    cost: [...shares.keys()].toSorted().map((entrant) => ({ entrant, ...(costs.get(entrant) ?? FREE) })),
    notes: NOTES,
  };
};
