import { Result } from "effect";

import { type PriceTable, type Total, totalsBy } from "./cost.ts";
import { callsOf, faultsOf, finishedNames, readMatch, type TournamentFile } from "./tournament-dir.ts";
import {
  type CodeVersion,
  codeVersions,
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
  sharesByVersion,
  type StarterRate,
  starterRates,
  type VersionShare,
} from "./tournament-stats.ts";
import { botEntrant, type Tournament } from "./tournament.ts";

// The tournament's report: the stats of its finished matches that agree with
// the schedule, as plain data. scripts/arena-stats.ts prints it.

export const RESAMPLES = 1000;

/** Below this many seeds the clustered intervals are rough. */
export const FEW_SEEDS = 20;

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

export interface SeatTerm {
  readonly size: number;
  readonly position: number;
  readonly rating: number;
  readonly interval: Interval | undefined;
}

export interface StarterRow extends StarterRate {
  readonly interval: Interval | undefined;
}

export interface VersionRow extends VersionShare {
  readonly interval: Interval | undefined;
}

export interface Report {
  readonly name: string;
  /** The entrant rated 0, or undefined when the mean of all entrants is. */
  readonly anchor: string | undefined;
  readonly matches: { readonly scheduled: number; readonly finished: number; readonly scored: number };
  /** Finished matches left out of the stats because their manifest disagrees with the schedule. */
  readonly excluded: ReadonlyArray<{ readonly match: string; readonly problems: ReadonlyArray<string> }>;
  /** The distinct seeds of the scored matches: the units the intervals resample. */
  readonly seeds: number;
  /** The code versions the scored matches were played under, with their entrants. */
  readonly versions: ReadonlyArray<CodeVersion>;
  /** The win share per version of each entrant that played under more than one. */
  readonly versionShares: ReadonlyArray<VersionRow>;
  readonly entrants: ReadonlyArray<EntrantRow>;
  /** The seat advantage of each position after the first, on the Elo scale. */
  readonly seatTerms: ReadonlyArray<SeatTerm>;
  /** By table size, how often the player who started round 1 won the match. */
  readonly starters: ReadonlyArray<StarterRow>;
  readonly byPosition: ReadonlyArray<PositionShare>;
  readonly pairings: ReadonlyArray<{ readonly entrants: ReadonlyArray<string>; readonly matches: number; readonly shares: ReadonlyArray<{ readonly entrant: string; readonly share: number }> }>;
  readonly interventions: ReadonlyArray<Interventions>;
  /** The scored matches in which a model needed a reminder or an intervention. */
  readonly flagged: ReadonlyArray<{ readonly match: string; readonly entrant: string; readonly reminders: number; readonly interventions: number }>;
  /** Over every scheduled match, finished or not, as cost is: the calls made and the provider faults hit. */
  readonly cost: ReadonlyArray<{ readonly entrant: string; readonly faults: number } & Total>;
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

  const byVersion = sharesByVersion(played);
  const ratings = fitRatings(played, anchor);
  const replicates = resamples(played, resampleCount, config.seed);
  const shareIntervals = intervalsOf(replicates.map((replicate) => new Map([...sharesByEntrant(replicate)].map(([entrant, { share }]) => [entrant, share]))));
  const fits = replicates.map((replicate) => fitRatings(replicate, anchor));
  const ratingIntervals = intervalsOf(fits.map((fit) => fit.entrants));
  const seatIntervals = intervalsOf(fits.map((fit) => new Map(fit.seats.map(({ size, position, rating }) => [`${size}:${position}`, rating]))));
  const versionIntervals = intervalsOf(replicates.map((replicate) => new Map(sharesByVersion(replicate).map(({ entrant, code, share }) => [JSON.stringify([entrant, code]), share]))));
  const starterIntervals = intervalsOf(replicates.map((replicate) => new Map(starterRates(replicate).map(({ size, rate }) => [String(size), rate]))));
  const costs = totalsBy(prices, file.schedule.flatMap((match) => callsOf(dir, match)));
  const faults = file.schedule.flatMap((match) => faultsOf(dir, match));
  const interventions = interventionsByEntrant(played);

  return {
    name: config.name,
    anchor,
    matches: { scheduled: file.schedule.length, finished: finished.size, scored: played.length },
    excluded: read.flatMap(({ match, result }) => Result.match(result, { onFailure: (problems) => [{ match: match.name, problems }], onSuccess: () => [] })),
    seeds: new Set(played.map((match) => match.seed)).size,
    versions: codeVersions(played),
    versionShares: byVersion
      .filter(({ entrant }) => byVersion.filter((row) => row.entrant === entrant).length > 1)
      .map((row) => ({ ...row, interval: versionIntervals.get(JSON.stringify([row.entrant, row.code])) })),
    entrants: [...shares].map(([entrant, share]) => ({ entrant, ...share, shareInterval: shareIntervals.get(entrant), rating: ratings.entrants.get(entrant) ?? 0, ratingInterval: ratingIntervals.get(entrant) })).toSorted((left, right) => right.rating - left.rating),
    seatTerms: ratings.seats.map((seat) => ({ ...seat, interval: seatIntervals.get(`${seat.size}:${seat.position}`) })),
    starters: starterRates(played).map((row) => ({ ...row, interval: starterIntervals.get(String(row.size)) })),
    byPosition: sharesByPosition(played),
    pairings: headToHead(played).map(({ matches, entrants }) => ({ entrants: entrants.map(({ entrant }) => entrant), matches, shares: entrants })),
    interventions: interventions.toSorted((left, right) => left.entrant.localeCompare(right.entrant)),
    flagged: played.flatMap((match) => match.players.filter((player) => player.interventions + player.reminders > 0).map((player) => ({ match: match.name, entrant: player.entrant, reminders: player.reminders, interventions: player.interventions }))),
    cost: [...new Set([...shares.keys(), ...costs.keys()])].toSorted().map((entrant) => ({ entrant, faults: faults.filter((name) => name === entrant).length, ...(costs.get(entrant) ?? FREE) })),
    notes: NOTES,
  };
};
