import { Result } from "effect";

import { DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { readTournamentFile, tournamentOf } from "../src/arena/tournament-dir.ts";
import { type Report, reportOf } from "../src/arena/tournament-report.ts";
import type { Interval } from "../src/arena/tournament-stats.ts";

// Reports a tournament directory: wins and win share per entrant, overall, by
// position and head to head, interventions, ratings and cost. Intervals are 95%
// bootstraps over seed blocks, drawn with a seed, so a rerun prints the same
// numbers. Finished matches whose manifest disagrees with the schedule are
// listed and left out. Prices come from src/arena/prices.json.
// Usage: bun scripts/arena-stats.ts <tournament dir> [--json]

const dir = process.argv.slice(2).find((arg) => !arg.startsWith("--"));

if (dir === undefined) {
  console.error("Usage: bun scripts/arena-stats.ts <tournament dir> [--json]");
  process.exit(1);
}

const file = Result.match(readTournamentFile(dir), { onFailure: (error) => { console.error(error.message);

 return process.exit(1); }, onSuccess: (value) => value });

const tournament = Result.match(tournamentOf(file), { onFailure: (error) => { console.error(error.message);

 return process.exit(1); }, onSuccess: (value) => value });

const report = reportOf(dir, file, tournament, loadPrices(DEFAULT_PRICES));

const percent = (share: number): string => `${(share * 100).toFixed(1)}%`;

const between = (interval: Interval | undefined, show: (value: number) => string): string => (interval === undefined ? "-" : `${show(interval.low)} to ${show(interval.high)}`);

const elo = (rating: number): string => String(Math.round(rating));

const money = (dollars: number): string => `$${dollars.toFixed(4)}`;

/** Columns aligned: the first to the left, the rest to the right. */
const table = (header: ReadonlyArray<string>, rows: ReadonlyArray<ReadonlyArray<string>>): string => {
  const widths = header.map((title, column) => Math.max(title.length, ...rows.map((row) => (row[column] ?? "").length)));
  const line = (row: ReadonlyArray<string>) => row.map((cell, column) => (column === 0 ? cell.padEnd(widths[column] ?? 0) : cell.padStart(widths[column] ?? 0))).join("  ");

  return [line(header), ...rows.map(line)].map((text) => `  ${text}`).join("\n");
};

const text = (stats: Report): string => {
  const { matches } = stats;

  const sections = [
    `Tournament ${stats.name}: ${matches.finished} of ${matches.scheduled} matches finished, ${matches.scored} scored, ${matches.finished - matches.scored} left out.`,
    ...(stats.excluded.length === 0 ? [] : [`Left out, because the manifest disagrees with the schedule:\n${stats.excluded.map(({ match, problems }) => `  ${match}: ${problems.join("; ")}`).join("\n")}`]),
    `Win share and rating, best rating first. Expected is the share at equal strength. Ratings are on the Elo scale with ${stats.anchor ?? "the mean of all entrants"} at 0.\n${table(
      ["entrant", "matches", "wins", "share", "expected", "95% CI", "rating", "95% CI"],
      stats.entrants.map((row) => [row.entrant, String(row.matches), row.wins.toFixed(1), percent(row.share), percent(row.expected), between(row.shareInterval, percent), elo(row.rating), between(row.ratingInterval, elo)]),
    )}`,
    `Seat advantage over the first position, on the Elo scale.\n${table(["table", "position", "rating"], stats.seatTerms.map((seat) => [`${seat.size} players`, String(seat.position), elo(seat.rating)]))}`,
    `Win share by position.\n${table(["entrant", "table", "position", "matches", "share"], stats.byPosition.map((row) => [row.entrant, `${row.size} players`, String(row.position), String(row.matches), percent(row.share)]))}`,
    `Head to head, by pairing.\n${stats.pairings.map((pairing) => `  ${pairing.entrants.join(" vs ")}: ${pairing.matches} matches, ${pairing.shares.map(({ entrant, share }) => `${entrant} ${percent(share)}`).join(", ")}`).join("\n")}`,
    `Interventions. The rate is interventions over the entrant's own moves plus interventions.\n${table(
      ["entrant", "matches", "moves", "interventions", "rate", "reminders", "matches with any"],
      stats.interventions.map((row) => [row.entrant, String(row.matches), String(row.moves), String(row.interventions), row.rate === undefined ? "-" : percent(row.rate), String(row.reminders), String(row.matchesWithAny)]),
    )}`,
    ...(stats.flagged.length === 0 ? [] : [`Matches with a reminder or an intervention, scored all the same:\n${stats.flagged.map((row) => `  ${row.match}: ${row.entrant}, ${row.reminders} reminders, ${row.interventions} interventions`).join("\n")}`]),
    `Usage and cost over every match played or started, at src/arena/prices.json prices. Faults are provider errors that paused a match; they are never losses.\n${table(
      ["entrant", "calls", "faults", "input", "output", "reasoning", "cache read", "cache write", "cost"],
      stats.cost.map((row) => [row.entrant, String(row.calls), String(row.faults), String(row.input), String(row.output), String(row.reasoning), String(row.cacheRead), String(row.cacheWrite), row.unpriced > 0 ? `${money(row.dollars)} (${row.unpriced} unpriced)` : money(row.dollars)]),
    )}\n  total ${money(stats.cost.reduce((total, row) => total + row.dollars, 0))}`,
    stats.notes.map((note) => `Note: ${note}`).join("\n"),
  ];

  return sections.join("\n\n");
};

console.log(process.argv.includes("--json") ? JSON.stringify(report, null, 2) : text(report));
