import { Data, Redacted, Result, Schema } from "effect";

import { AgentId } from "./agent.ts";
import type { PriceTable } from "./cost.ts";
import { THINKING_LEVELS } from "./endpoints.ts";
import { DELIVERIES } from "./match.ts";

// A tournament: a config, the schedule it expands to, and what the runner needs
// to start one match as a child process. Everything here is pure. Reading and
// writing the tournament directory is in tournament-dir.ts, and the statistics
// are in tournament-stats.ts.

export const BOTS = ["DoN", "Story"] as const;

const EntrantName = Schema.String.check(Schema.isPattern(/^[a-z0-9][a-z0-9.-]*$/));

const TournamentEndpoint = Schema.Struct({ api: Schema.Literals(["anthropic", "openai-responses"]), url: Schema.NonEmptyString, keyEnv: Schema.NonEmptyString });

const ModelEntrant = Schema.Struct({ endpoint: Schema.NonEmptyString, model: Schema.NonEmptyString, catalogModel: Schema.optional(Schema.NonEmptyString), effort: Schema.Literals(THINKING_LEVELS) });

const BotEntrant = Schema.Struct({ bot: Schema.Literals(BOTS) });

export const TournamentConfig = Schema.Struct({
  name: Schema.NonEmptyString,
  seed: Schema.Int,
  delivery: Schema.Literals(DELIVERIES),
  endpoints: Schema.Record(Schema.String, TournamentEndpoint),
  entrants: Schema.Record(EntrantName, Schema.Union([ModelEntrant, BotEntrant])),
  pairings: Schema.Union([Schema.Array(Schema.Array(EntrantName)), Schema.Struct({ allOf: Schema.Array(EntrantName), size: Schema.Literals([2, 3, 4]) })]),
  blocksPerPairing: Schema.Int.check(Schema.isGreaterThanOrEqualTo(1)),
});

export type TournamentConfig = typeof TournamentConfig.Type;

type Entrant = TournamentConfig["entrants"][string];

type ModelEntrant = typeof ModelEntrant.Type;

export class TournamentError extends Data.TaggedError("TournamentError")<{ readonly message: string }> {}

const fail = (message: string) => Result.fail(new TournamentError({ message }));

/** An entrant name, as the pairings and the match directories use it. */
export type EntrantName = typeof EntrantName.Type;

const isModel = (entrant: Entrant): entrant is ModelEntrant => "model" in entrant;

/** The entrant of that name, if it is a model. */
export const modelEntrant = (config: TournamentConfig, name: string): ModelEntrant | undefined => {
  const entrant = config.entrants[name];

  return entrant !== undefined && isModel(entrant) ? entrant : undefined;
};

/** The entrants of a pairing, in pairing order. Its model entrants get agent letters A to D in that order. */
export type Pairing = ReadonlyArray<EntrantName>;

const combinations = <A>(items: ReadonlyArray<A>, size: number): ReadonlyArray<ReadonlyArray<A>> =>
  size === 0 ? [[]] : items.flatMap((item, index) => combinations(items.slice(index + 1), size - 1).map((rest) => [item, ...rest]));

const permutations = <A>(items: ReadonlyArray<A>): ReadonlyArray<ReadonlyArray<A>> =>
  items.length <= 1 ? [items] : items.flatMap((item, index) => permutations([...items.slice(0, index), ...items.slice(index + 1)]).map((rest) => [item, ...rest]));

const hasModel = (config: TournamentConfig, pairing: Pairing): boolean => pairing.some((name) => modelEntrant(config, name) !== undefined);

const duplicateIn = (names: ReadonlyArray<string>): string | undefined => names.find((name, index) => names.indexOf(name) !== index);

const unknownIn = (config: TournamentConfig, names: ReadonlyArray<string>): string | undefined => names.find((name) => config.entrants[name] === undefined);

const explicitPairings = (config: TournamentConfig, listed: ReadonlyArray<Pairing>): Result.Result<ReadonlyArray<Pairing>, TournamentError> =>
  Result.gen(function* () {
    for (const [index, pairing] of listed.entries()) {
      const label = `pairing ${index + 1} (${pairing.join(", ")})`;
      const stranger = unknownIn(config, pairing);
      const twice = duplicateIn(pairing);

      if (stranger !== undefined) return yield* fail(`${label} names the unknown entrant "${stranger}"`);

      if (twice !== undefined) return yield* fail(`${label} lists the entrant "${twice}" twice`);

      if (pairing.length < 2 || pairing.length > 4) return yield* fail(`${label} has ${pairing.length} entrants; a pairing has 2 to 4`);

      if (!hasModel(config, pairing)) return yield* fail(`${label} has only bots; a pairing needs at least one model entrant`);
    }

    return listed;
  });

/** Every combination of `size`, without the ones of bots only. */
const allOfPairings = (config: TournamentConfig, allOf: ReadonlyArray<EntrantName>, size: number): Result.Result<ReadonlyArray<Pairing>, TournamentError> => {
  const stranger = unknownIn(config, allOf);
  const twice = duplicateIn(allOf);

  if (stranger !== undefined) return fail(`allOf names the unknown entrant "${stranger}"`);

  if (twice !== undefined) return fail(`allOf lists the entrant "${twice}" twice`);

  if (allOf.length < size) return fail(`allOf has ${allOf.length} entrants, fewer than its size ${size}`);

  return Result.succeed(combinations(allOf, size).filter((pairing) => hasModel(config, pairing)));
};

const pairingsOf = (config: TournamentConfig): Result.Result<ReadonlyArray<Pairing>, TournamentError> =>
  "allOf" in config.pairings ? allOfPairings(config, config.pairings.allOf, config.pairings.size) : explicitPairings(config, config.pairings);

/** The config, once every entrant, endpoint and pairing in it is known to exist. */
export interface Tournament {
  readonly config: TournamentConfig;
  readonly pairings: ReadonlyArray<Pairing>;
}

/** A config whose every entrant, endpoint and pairing exists. */
export const resolveConfig = (config: TournamentConfig): Result.Result<Tournament, TournamentError> =>
  Result.gen(function* () {
    for (const [name, entrant] of Object.entries(config.entrants)) {
      if (isModel(entrant) && config.endpoints[entrant.endpoint] === undefined) return yield* fail(`entrant "${name}" uses the unknown endpoint "${entrant.endpoint}"`);
    }

    const pairings = yield* pairingsOf(config);
    const repeated = duplicateIn(pairings.map((pairing) => pairing.join(",")));

    if (repeated !== undefined) return yield* fail(`the pairing (${repeated}) is listed twice`);

    return { config, pairings };
  });

/** Decodes a config from its JSON text. A mistyped key is an error, and so is a name that points at nothing. */
export const parseConfig = (text: string): Result.Result<Tournament, TournamentError> =>
  Result.flatMap(
    Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(TournamentConfig))(text, { onExcessProperty: "error" }), (error) => new TournamentError({ message: `the config is not valid: ${error.message}` })),
    resolveConfig,
  );

/** Every model entrant's `model` must have a price, since that is the id the calls are logged and priced under. */
export const checkPrices = ({ config }: Tournament, prices: PriceTable): Result.Result<void, TournamentError> => {
  const unpriced = Object.keys(config.entrants).find((name) => {
    const entrant = modelEntrant(config, name);

    return entrant !== undefined && prices.models[entrant.model] === undefined;
  });

  return unpriced === undefined ? Result.void : fail(`the model of entrant "${unpriced}" has no entry in prices.json; add a price for it first`);
};

/** The seats a match can have: an agent letter or a bot. */
const Seat = Schema.Union([AgentId, Schema.Literals(BOTS)]);

export const ScheduledMatch = Schema.Struct({
  name: Schema.String,
  pairing: Schema.Int,
  block: Schema.Int,
  seed: Schema.Int,
  /** In table order: the agent's letter, or the bot's name. */
  seats: Schema.Array(Seat),
  /** The entrant at each seat, in the same order. */
  entrants: Schema.Array(EntrantName),
});

export type ScheduledMatch = typeof ScheduledMatch.Type;

type Seat = typeof Seat.Type;

/** A seed block is one seed and every permutation of the pairing's seats. */
const blockOf = ({ config }: Tournament, pairing: Pairing, pairingIndex: number, block: number): ReadonlyArray<ScheduledMatch> => {
  const letters = AgentId.literals.values();

  const seated = pairing.flatMap((name): ReadonlyArray<readonly [Seat, EntrantName]> => {
    const entrant = config.entrants[name];

    if (entrant === undefined) return [];

    if (isModel(entrant)) {
      const letter = letters.next().value;

      return letter === undefined ? [] : [[letter, name]];
    }

    return [[entrant.bot, name]];
  });

  return permutations(seated).map((table, index) => ({
    name: [...pairing, `b${block}`, `p${index}`].join("_"),
    pairing: pairingIndex,
    block,
    seed: config.seed + block,
    seats: table.map(([seat]) => seat),
    entrants: table.map(([, name]) => name),
  }));
};

/** Block by block, so a tournament stopped half way has balanced pairings. */
export const scheduleOf = (tournament: Tournament): ReadonlyArray<ScheduledMatch> =>
  Array.from({ length: tournament.config.blocksPerPairing }, (_, block) => tournament.pairings.flatMap((pairing, index) => blockOf(tournament, pairing, index, block))).flat();

export type Env = Readonly<Record<string, string | undefined>>;

/** Which bot the entrant of that name is, if it is one. */
export const botEntrant = (config: TournamentConfig, name: string): (typeof BOTS)[number] | undefined => {
  const entrant = config.entrants[name];

  return entrant !== undefined && "bot" in entrant ? entrant.bot : undefined;
};

/** The endpoint a model entrant plays through. */
const endpointOf = (config: TournamentConfig, name: string) => config.endpoints[modelEntrant(config, name)?.endpoint ?? ""];

/** Each key variable the model entrants of the schedule use, read from the environment. A missing one is named, never shown. */
export const resolveKeys = (config: TournamentConfig, schedule: ReadonlyArray<ScheduledMatch>, env: Env): Result.Result<ReadonlyMap<string, Redacted.Redacted<string>>, TournamentError> => {
  const variables = [...new Set(schedule.flatMap((match) => match.entrants.flatMap((name) => endpointOf(config, name)?.keyEnv ?? [])))];

  const missing = variables.filter((variable) => (env[variable] ?? "") === "");

  if (missing.length > 0) return fail(`set ${missing.join(", ")} in the environment or in web/.env: ${missing.length > 1 ? "they hold" : "it holds"} the key of an endpoint this tournament uses`);

  return Result.succeed(new Map(variables.map((variable) => [variable, Redacted.make(env[variable] ?? "")] as const)));
};

/** The command of a match, from the web/ directory. The settings are flags and the keys are in the environment, so no key shows in a process list. */
export const childCommand = (matchDir: string, config: TournamentConfig, match: ScheduledMatch): ReadonlyArray<string> => [
  "nice", "-n", "10", "bun", "--no-env-file", "scripts/arena.ts",
  "--dir", matchDir,
  "--seed", String(match.seed),
  "--seats", match.seats.join(","),
  "--rotation", "0",
  "--delivery", config.delivery,
];

/** The runner's environment, without any PLAYER_* variable, plus the PLAYER_<letter>_* variables of this match's model entrants. */
export const childEnv = (base: Env, config: TournamentConfig, match: ScheduledMatch, keys: ReadonlyMap<string, Redacted.Redacted<string>>): Env => {
  const inherited = Object.entries(base).filter(([name]) => !name.startsWith("PLAYER_"));

  const seats = match.seats.flatMap((seat, index) => {
    const entrant = modelEntrant(config, match.entrants[index] ?? "");
    const endpoint = endpointOf(config, match.entrants[index] ?? "");
    const key = keys.get(endpoint?.keyEnv ?? "");

    if (entrant === undefined || endpoint === undefined || key === undefined) return [];

    const prefix = `PLAYER_${seat}_`;
    const api = endpoint.api === "anthropic" ? "ANT" : "OAI";

    return [
      [`${prefix}${api}_URL`, endpoint.url],
      [`${prefix}${api}_KEY`, Redacted.value(key)],
      [`${prefix}MODEL`, entrant.model],
      ...(entrant.catalogModel === undefined ? [] : [[`${prefix}CATALOG_MODEL`, entrant.catalogModel]]),
      [`${prefix}EFFORT`, entrant.effort],
    ] as const;
  });

  return Object.fromEntries([...inherited, ...seats]);
};

/** The scheduled matches whose names are not finished. */
export const unfinished = (schedule: ReadonlyArray<ScheduledMatch>, finished: ReadonlySet<string>): ReadonlyArray<ScheduledMatch> => schedule.filter((match) => !finished.has(match.name));

/** Runs the items, at most `parallel` at a time, in order. Once `stop` aborts, no new item starts and the running ones finish. */
