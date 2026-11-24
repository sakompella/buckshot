import { effortLabel } from "../arena-viewer/page/data.ts";
import type { Config } from "./configs.ts";
import { modelName } from "./configs.ts";
import { esc, rating, ratingInterval, usd } from "./svg.ts";

// The appendix: every config in one static table, best first, and the terms the page uses.

const cell = (value: string): string => `<td>${esc(value)}</td>`;

/** One row per config: name, effort, tier, Round Elo with its interval, scored matches, cost, seconds and points lost per move. */
export const configTable = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.map((config) =>
    [
      `<tr><th scope="row">${esc(config.isFixed ? config.label : modelName(config.model))}</th>`,
      cell(config.isFixed ? "" : effortLabel(config.model, config.effort)),
      cell(config.tier === null ? "" : String(config.tier)),
      cell(rating(config.rating)),
      cell(ratingInterval(config.lo, config.hi)),
      cell(config.scored.toLocaleString("en-US")),
      cell(config.isFixed ? "$0" : usd(config.cost)),
      cell(config.secondsPerMove === null ? "" : config.secondsPerMove.toFixed(1)),
      cell(config.meanLost === null ? "" : config.meanLost.toFixed(2)),
      "</tr>",
    ].join(""));

  const heads = ["Config", "Effort", "Tier", "Round Elo", "90% interval", "Matches", "$ / match", "s / move", "Points lost / move"].map((head) => `<th scope="col">${head}</th>`).join("");

  return `<div class="table-scroll tall"><table class="data all-configs"><thead><tr>${heads}</tr></thead><tbody>${rows.join("")}</tbody></table></div>`;
};

const TERMS: ReadonlyArray<readonly [string, string]> = [
  ["Points", "Percentage points of round-win chance, as the depth-7 search estimates it. A move that loses 4 points takes a 60% round to 56%."],
  ["Clean shot", "A shot with the chambered shell unknown to the shooter, the gun not sawn off and the opponent not jammed. Both targets are legal and nothing else changes the answer."],
  ["Config", "One model at one effort setting. Astra off* plays at low effort with one added line asking it to answer at once, since its API has no reasoning-off setting."],
  ["Round Elo", "A Bradley-Terry rating fitted over every scored round, measured from the depth-7 search at 0. It is not a match Elo."],
  ["Luck adjustment", "An AIVAT-style correction that subtracts the part of each round's result the deal explains, fitted out of fold by seed."],
  ["Tier", "Configs sorted by rating. A new tier starts at the first config whose gap to the tier's top excludes 0."],
  ["Regret", "Points a move gave up against the best move the depth-7 search found."],
  ["Seed", "A fixed deal sequence. Each pairing plays a seed in both seat orders."],
];

export const glossary = (): string => `<dl class="terms">${TERMS.map(([term, text]) => `<dt>${esc(term)}</dt><dd>${esc(text)}</dd>`).join("")}</dl>`;
