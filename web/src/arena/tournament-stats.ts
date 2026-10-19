// The statistics of a tournament, as pure functions of its scored matches.
// Confidence intervals bootstrap over seeds: a seed fixes the deal of round 1,
// so the matches played at one seed, in any pairing, are not independent.

/** One player of a scored match. `share` is its part of the win: 1, or 1/k when k players tied on cash. */
export interface Player {
  readonly entrant: string;
  readonly share: number;
  readonly moves: number;
  readonly reminders: number;
  readonly interventions: number;
}

/** A finished match that agrees with its schedule. `players` is in table order, so a player's position is its index plus 1. */
export interface PlayedMatch {
  readonly name: string;
  readonly pairing: number;
  readonly seed: number;
  /** The code the match was played under, from its manifest. */
  readonly code: string;
  /** The position, from 1, that starts round 1. The seed decides it. */
  readonly starter: number;
  readonly players: ReadonlyArray<Player>;
}

export interface Interval {
  readonly low: number;
  readonly high: number;
}

/** The players with the most cash win, and share the win equally. */
export const winShares = (cash: ReadonlyArray<number>): ReadonlyArray<number> => {
  const best = Math.max(...cash);
  const winners = cash.filter((amount) => amount === best).length;

  return cash.map((amount) => (amount === best ? 1 / winners : 0));
};

const sum = (values: ReadonlyArray<number>): number => values.reduce((total, value) => total + value, 0);

const mean = (values: ReadonlyArray<number>): number => sum(values) / values.length;

const groupBy = <A, K>(items: ReadonlyArray<A>, key: (item: A) => K): ReadonlyMap<K, ReadonlyArray<A>> => {
  const groups = new Map<K, Array<A>>();

  for (const item of items) {
    const group = groups.get(key(item));

    if (group === undefined) groups.set(key(item), [item]);
    else group.push(item);
  }

  return groups;
};

/** Every (entrant, player) pair of the matches. */
const seatsOf = (matches: ReadonlyArray<PlayedMatch>) => matches.flatMap((match) => match.players.map((player, index) => ({ match, player, position: index + 1, size: match.players.length })));

export interface Share {
  readonly matches: number;
  readonly wins: number;
  readonly share: number;
  /** The share an entrant of equal strength would have: the mean of 1/n over its matches. */
  readonly expected: number;
}

const shareOf = (seats: ReadonlyArray<{ readonly player: Player; readonly size: number }>): Share => ({
  matches: seats.length,
  wins: sum(seats.map(({ player }) => player.share)),
  share: mean(seats.map(({ player }) => player.share)),
  expected: mean(seats.map(({ size }) => 1 / size)),
});

export const sharesByEntrant = (matches: ReadonlyArray<PlayedMatch>): ReadonlyMap<string, Share> =>
  new Map([...groupBy(seatsOf(matches), ({ player }) => player.entrant)].map(([entrant, seats]) => [entrant, shareOf(seats)]));

export interface PositionShare extends Share {
  readonly entrant: string;
  readonly size: number;
  readonly position: number;
}

export const sharesByPosition = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<PositionShare> =>
  [...groupBy(seatsOf(matches), ({ player, size, position }) => JSON.stringify([player.entrant, size, position])).values()]
    .flatMap((seats) => (seats[0] === undefined ? [] : [{ entrant: seats[0].player.entrant, size: seats[0].size, position: seats[0].position, ...shareOf(seats) }]))
    .toSorted((left, right) => left.entrant.localeCompare(right.entrant) || left.size - right.size || left.position - right.position);

export interface CodeVersion {
  readonly code: string;
  readonly matches: number;
  readonly entrants: ReadonlyArray<string>;
}

export const codeVersions = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<CodeVersion> =>
  [...groupBy(matches, (match) => match.code)]
    .map(([code, played]) => ({ code, matches: played.length, entrants: [...new Set(played.flatMap((match) => match.players.map((player) => player.entrant)))].toSorted() }))
    .toSorted((left, right) => left.code.localeCompare(right.code));

export interface VersionShare extends Share {
  readonly entrant: string;
  readonly code: string;
}

export const sharesByVersion = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<VersionShare> =>
  [...groupBy(seatsOf(matches), ({ match, player }) => JSON.stringify([player.entrant, match.code])).values()]
    .flatMap((seats) => (seats[0] === undefined ? [] : [{ entrant: seats[0].player.entrant, code: seats[0].match.code, ...shareOf(seats) }]))
    .toSorted((left, right) => left.entrant.localeCompare(right.entrant) || left.code.localeCompare(right.code));

export interface StarterRate {
  readonly size: number;
  readonly matches: number;
  /** How many matches each position started, from position 1. */
  readonly started: ReadonlyArray<number>;
  readonly wins: number;
  /** The share of matches won by the player who started round 1. */
  readonly rate: number;
}

export const starterRates = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<StarterRate> =>
  [...groupBy(matches, (match) => match.players.length)]
    .map(([size, played]) => {
      const wins = sum(played.map((match) => match.players[match.starter - 1]?.share ?? 0));

      return {
        size,
        matches: played.length,
        started: Array.from({ length: size }, (_, index) => played.filter((match) => match.starter === index + 1).length),
        wins,
        rate: wins / played.length,
      };
    })
    .toSorted((left, right) => left.size - right.size);

export interface HeadToHead {
  readonly pairing: number;
  readonly matches: number;
  readonly entrants: ReadonlyArray<{ readonly entrant: string; readonly share: number }>;
}

/** For each pairing, each entrant's win share against the others of that pairing. */
export const headToHead = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<HeadToHead> =>
  [...groupBy(matches, (match) => match.pairing)].map(([pairing, played]) => ({
    pairing,
    matches: played.length,
    entrants: [...sharesByEntrant(played)].map(([entrant, { share }]) => ({ entrant, share })).toSorted((left, right) => left.entrant.localeCompare(right.entrant)),
  }));

export interface Interventions {
  readonly entrant: string;
  readonly matches: number;
  /** Moves the model chose itself. */
  readonly moves: number;
  readonly interventions: number;
  /** interventions / (moves + interventions); undefined for an entrant that never moves, such as a bot. */
  readonly rate: number | undefined;
  readonly reminders: number;
  readonly matchesWithAny: number;
}

export const interventionsByEntrant = (matches: ReadonlyArray<PlayedMatch>): ReadonlyArray<Interventions> =>
  [...groupBy(seatsOf(matches), ({ player }) => player.entrant)].map(([entrant, seats]) => {
    const moves = sum(seats.map(({ player }) => player.moves));
    const interventions = sum(seats.map(({ player }) => player.interventions));

    return {
      entrant,
      matches: seats.length,
      moves,
      interventions,
      rate: moves + interventions === 0 ? undefined : interventions / (moves + interventions),
      reminders: sum(seats.map(({ player }) => player.reminders)),
      matchesWithAny: seats.filter(({ player }) => player.interventions > 0).length,
    };
  });

// Ratings

export const ELO_PER_NAT = 400 / Math.LN10;

export interface Ratings {
  /** Elo scale, with the anchor at 0. */
  readonly entrants: ReadonlyMap<string, number>;
  /** The seat advantage at each position after the first, by table size, on the Elo scale. */
  readonly seats: ReadonlyArray<{ readonly size: number; readonly position: number; readonly rating: number }>;
}

/** Solves a x = b for a positive definite a, by Gauss-Jordan elimination, which needs no pivoting there. */
const solve = (a: ReadonlyArray<ReadonlyArray<number>>, b: ReadonlyArray<number>): ReadonlyArray<number> => {
  const rows = a.map((row, index) => [...row, b[index] ?? 0]);

  for (const [pivot, lead] of rows.entries()) {
    for (const [index, row] of rows.entries()) {
      const factor = index === pivot ? 0 : (row[pivot] ?? 0) / (lead[pivot] ?? 1);

      rows[index] = row.map((value, column) => value - factor * (lead[column] ?? 0));
    }
  }

  return rows.map((row, index) => (row[rows.length] ?? 0) / (row[index] ?? 1));
};

/**
 * The most probable ratings under a winner-choice model: in a match, player i wins with probability
 * exp(theta_i + s[n][position_i]) / the sum of that over the table, where n is the table size and the
 * first position has no seat term. Gaussian priors of standard deviation 1 on every theta and seat term
 * give the fit a single answer. A tied win counts by its share. Newton steps find the peak.
 */
export const fitRatings = (matches: ReadonlyArray<PlayedMatch>, anchor: string | undefined): Ratings => {
  const entrants = [...new Set(matches.flatMap((match) => match.players.map((player) => player.entrant)))].toSorted();
  const seatTerms = [...new Set(seatsOf(matches).flatMap(({ size, position }) => (position === 1 ? [] : [`${size}:${position}`])))].toSorted();
  const parameters = entrants.length + seatTerms.length;

  const indices = matches.map((match) =>
    match.players.map((player, index) => [entrants.indexOf(player.entrant), ...(index === 0 ? [] : [entrants.length + seatTerms.indexOf(`${match.players.length}:${index + 1}`)])]),
  );

  /** The log posterior's gradient, and the negative of its Hessian, at x. */
  const slope = (x: ReadonlyArray<number>) => {
    const gradient = x.map((value) => -value);
    const curvature = Array.from({ length: parameters }, (_, row) => Array.from({ length: parameters }, (__, column): number => (row === column ? 1 : 0)));

    for (const [at, match] of matches.entries()) {
      const used = indices[at] ?? [];
      const utilities = used.map((own) => sum(own.map((parameter) => x[parameter] ?? 0)));
      const top = Math.max(...utilities);
      const weights = utilities.map((utility) => Math.exp(utility - top));
      const chances = weights.map((weight) => weight / sum(weights));

      for (const [player, own] of used.entries()) {
        for (const parameter of own) {
          gradient[parameter] = (gradient[parameter] ?? 0) + (match.players[player]?.share ?? 0) - (chances[player] ?? 0);

          for (const [other, theirs] of used.entries()) {
            for (const column of theirs) {
              const row = curvature[parameter];

              if (row !== undefined) row[column] = (row[column] ?? 0) + (player === other ? (chances[player] ?? 0) : 0) - (chances[player] ?? 0) * (chances[other] ?? 0);
            }
          }
        }
      }
    }

    return { gradient, curvature };
  };

  let x: ReadonlyArray<number> = Array.from({ length: parameters }, () => 0);

  for (let step = 0; step < 100; step += 1) {
    const { gradient, curvature } = slope(x);
    const move = solve(curvature, gradient);

    x = x.map((value, index) => value + (move[index] ?? 0));

    if (Math.max(...move.map(Math.abs)) < 1e-10) break;
  }

  const strengths = entrants.map((_, index) => x[index] ?? 0);
  const origin = anchor !== undefined && entrants.includes(anchor) ? (strengths[entrants.indexOf(anchor)] ?? 0) : mean(strengths);

  return {
    entrants: new Map(entrants.map((entrant, index) => [entrant, ((strengths[index] ?? 0) - origin) * ELO_PER_NAT])),
    seats: seatTerms.map((term, index) => {
      const [size = 0, position = 0] = term.split(":").map(Number);

      return { size, position, rating: (x[entrants.length + index] ?? 0) * ELO_PER_NAT };
    }),
  };
};

// Bootstrap

/** A small seeded generator, so a rerun prints the same intervals. */
const randomFrom = (seed: number): (() => number) => {
  let state = seed >>> 0;

  return () => {
    state = (state + 0x6d2b79f5) >>> 0;

    const mixed = Math.imul(state ^ (state >>> 15), state | 1);
    const stirred = mixed ^ (mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61));

    return ((stirred ^ (stirred >>> 14)) >>> 0) / 4_294_967_296;
  };
};

/** Resamples of the matches: seeds drawn with replacement, each with every match played at it, in any pairing. */
export const resamples = (matches: ReadonlyArray<PlayedMatch>, count: number, seed: number): ReadonlyArray<ReadonlyArray<PlayedMatch>> => {
  const bySeed = [...groupBy(matches, (match) => match.seed).values()];
  const random = randomFrom(seed);

  return Array.from({ length: count }, () => Array.from({ length: bySeed.length }, () => bySeed[Math.floor(random() * bySeed.length)] ?? []).flat());
};

const quantile = (sorted: ReadonlyArray<number>, level: number): number => {
  const at = level * (sorted.length - 1);
  const below = Math.floor(at);

  return (sorted[below] ?? 0) + ((sorted[Math.ceil(at)] ?? 0) - (sorted[below] ?? 0)) * (at - below);
};

/** The central 95% of each named statistic (an entrant's, for instance) over the resamples that have it. */
export const intervalsOf = (replicates: ReadonlyArray<ReadonlyMap<string, number>>): ReadonlyMap<string, Interval> =>
  new Map(
    [...groupBy(replicates.flatMap((replicate) => [...replicate]), ([name]) => name)].map(([name, values]) => {
      const sorted = values.map(([, value]) => value).toSorted((left, right) => left - right);

      return [name, { low: quantile(sorted, 0.025), high: quantile(sorted, 0.975) }] as const;
    }),
  );
