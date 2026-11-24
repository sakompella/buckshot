import { effortLabel } from "../arena-viewer/page/data.ts";
import { familyId, isTopTier, modelName } from "./configs.ts";
import type { Config } from "./configs.ts";
import { esc, pct, pctInterval, rating, ratingInterval, tokens, usd } from "./svg.ts";

// The page's tables: the top group under Figure 3, the direct record against the depth-7 search, and every setting at
// the bottom of the page.

const cell = (value: string): string => `<td>${esc(value)}</td>`;

const heads = (names: ReadonlyArray<string>): string => `<thead><tr>${names.map((name) => `<th scope="col">${esc(name)}</th>`).join("")}</tr></thead>`;

const nameCell = (config: Config, text: string): string => `<th scope="row"${config.isFixed ? "" : ` data-family="${familyId(config.family)}"`}><i class="sw" aria-hidden="true"></i>${esc(text)}</th>`;

/** The top group's model settings side by side: price, speed, thinking tokens and skill score. */
export const topGroupTable = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.flatMap((config) =>
    !isTopTier(config) || config.isFixed
      ? []
      : [
        [
          `<tr>${nameCell(config, config.short)}`,
          cell(usd(config.cost)),
          cell(config.secondsPerMove === null ? "" : config.secondsPerMove.toFixed(1)),
          cell(config.tokensPerMove === null ? "" : tokens(config.tokensPerMove)),
          `<td><b>${rating(config.rating)}</b> <span class="range">${ratingInterval(config.lo, config.hi)}</span></td></tr>`,
        ].join(""),
      ]);

  return `<div class="table-scroll"><table class="data"><caption>Top group</caption>${heads(["Setting", "$ / match", "s / move", "Thinking tok / move", "Skill score [90% range]"])}<tbody>${rows.join("")}</tbody></table></div>`;
};

/** The model settings that played the depth-7 search directly: rounds won with no judge. */
export const headToHeadTable = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.flatMap((config) => {
    const record = config.vsEngine;

    return config.isFixed || record === null || record.rate === null || record.lo === null || record.hi === null
      ? []
      : [`<tr>${nameCell(config, config.short)}${cell(`${record.k} / ${record.n}`)}<td><b>${pct(record.rate)}</b> <span class="range">${pctInterval(record.lo, record.hi)}</span></td></tr>`];
  });

  return `<div class="table-scroll"><table class="data"><caption>Head to head against the depth-7 search, no judge</caption>${heads(["Setting", "Rounds won", "Share [90% range]"])}<tbody>${rows.join("")}</tbody></table></div>`;
};

/** One row per setting, best first: model, effort, group, skill score and range, matches, cost, speed, thinking and points lost per move. */
export const fullTable = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.map((config) =>
    [
      `<tr>${nameCell(config, config.isFixed ? config.label : modelName(config.model))}`,
      cell(config.isFixed ? "" : effortLabel(config.model, config.effort)),
      cell(config.tier === null ? "" : String(config.tier)),
      `<td><b>${rating(config.rating)}</b></td>`,
      `<td class="range">${ratingInterval(config.lo, config.hi)}</td>`,
      cell(config.scored.toLocaleString("en-US")),
      cell(config.isFixed ? "$0" : usd(config.cost)),
      cell(config.secondsPerMove === null ? "" : config.secondsPerMove.toFixed(1)),
      cell(config.tokensPerMove === null ? "" : tokens(config.tokensPerMove)),
      cell(config.meanLost === null ? "" : config.meanLost.toFixed(2)),
      "</tr>",
    ].join(""));

  return `<div class="table-scroll tall"><table class="data full">${heads(["Setting", "Effort", "Group", "Skill score", "90% range", "Matches", "$ / match", "s / move", "Thinking tok / move", "Points lost / move"])}<tbody>${rows.join("")}</tbody></table></div>`;
};
