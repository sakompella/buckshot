import { expect, test } from "bun:test";

import { configsOf, familiesOf, isTopTier } from "../src/findings/configs.ts";
import { decodeFindingsData } from "../src/findings/data.ts";
import type { FindingsData } from "../src/findings/data.ts";
import { ogCard } from "../src/findings/og.ts";
import { articleHtml } from "../src/findings/page.ts";
import { costFigure, thinkingFigure, topTierRange } from "../src/findings/scatter.ts";
import { selfShotFigure } from "../src/findings/selfshoot.ts";
import { fullTable, headToHeadTable, topGroupTable } from "../src/findings/tables.ts";
import { varianceFigure } from "../src/findings/variance.ts";
import { FINDINGS_JSON, SUMMARY_JSON } from "./fixtures.ts";

const decode = (findingsJson = JSON.stringify(FINDINGS_JSON)): FindingsData => decodeFindingsData(JSON.stringify(SUMMARY_JSON), findingsJson);

const DATA = decode();

const CONFIGS = configsOf(DATA.summary);

const MODELS = CONFIGS.filter(({ isFixed }) => !isFixed);

const unescape = (text: string): string => text.replaceAll("&quot;", '"').replaceAll("&#39;", "'").replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&amp;", "&");

/** The tip of every mark in some HTML, in order. */
const tipsOf = (html: string): ReadonlyArray<string> => [...html.matchAll(/data-tip="([^"]*)"/g)].map(([, tip = ""]) => unescape(tip));

const drawingsOf = (html: string): ReadonlyArray<string> => html.split(/(?=<svg class="fig-)/).filter((part) => part.startsWith("<svg "));

const rowsOf = (html: string): number => html.match(/<tr><th scope="row"/g)?.length ?? 0;

test("findings.json decodes, and a curve that leaves out headline shots or a variance split that does not sum to 1 does not", () => {
  expect(DATA.findings.curve).toHaveLength(FINDINGS_JSON.curve.length);
  expect(() => decode(JSON.stringify({ ...FINDINGS_JSON, headline: { ...FINDINGS_JSON.headline, cleanShotsN: 3891 } }))).toThrow(/below even odds/);
  expect(() => decode(JSON.stringify({ ...FINDINGS_JSON, gStudy: { ...FINDINGS_JSON.gStudy, rounds: { ...FINDINGS_JSON.gStudy.rounds, residual: 0.5 } } }))).toThrow(/sum to 1/);
  expect(() => decode(JSON.stringify({ ...FINDINGS_JSON, curve: FINDINGS_JSON.curve.map((point) => ({ ...point, group: "opus" })) }))).toThrow();
});

test("every mark's tooltip is also its accessible name", () => {
  const html = articleHtml(DATA);
  const marks = [...html.matchAll(/<g class="mark"[^>]*>/g)].map(([tag]) => tag);

  expect(marks.length).toBeGreaterThan(0);

  for (const tag of marks) { expect(/aria-label="([^"]*)"/.exec(tag)?.[1]).toBe(/data-tip="([^"]*)"/.exec(tag)?.[1]); }
});

test("every figure draws a wide and a narrow layout", () => {
  for (const figure of [selfShotFigure(DATA.findings), thinkingFigure(CONFIGS), costFigure(CONFIGS), varianceFigure(DATA.findings)]) {
    expect(drawingsOf(figure).map((drawing) => /class="(fig-\w+)"/.exec(drawing)?.[1])).toEqual(["fig-wide", "fig-narrow"]);
  }
});

test("the self-shot figure marks every curve point, the search on the strong states and every effort, in each layout", () => {
  const strong = FINDINGS_JSON.curve.filter(({ group }) => group === "strong").length;

  for (const drawing of drawingsOf(selfShotFigure(DATA.findings))) { expect(tipsOf(drawing)).toHaveLength(FINDINGS_JSON.curve.length + strong + FINDINGS_JSON.sonnetEffort.length); }
});

test("every model the data holds has a shade, in the legend above each scatter", () => {
  expect(familiesOf(CONFIGS)).toEqual(["Opus 5.5", "Sonnet 5.5", "Terra 6.1", "Sol 6.1"]);
  expect([...thinkingFigure(CONFIGS).matchAll(/<li data-family="([^"]+)"/g)].map(([, id]) => id)).toEqual(["opus-5-5", "sonnet-5-5", "terra-6-1", "sol-6-1"]);
});

test("the thinking scatter places the settings with a thinking count, with the search and the game's AI as reference lines", () => {
  const [wide = ""] = drawingsOf(thinkingFigure(CONFIGS));
  const counted = MODELS.filter(({ tokensPerMove }) => tokensPerMove !== null);

  expect(counted.length).toBeLessThan(MODELS.length);
  expect(tipsOf(wide)).toHaveLength(counted.length);
  expect(wide.match(/<polyline class="join"/g)).toBeNull();
  expect([...wide.matchAll(/class="ref-label halo" text-anchor="\w+">([^<]+)</g)].map(([, text]) => text)).toEqual(["Depth-7 search (0)", "Story AI"]);
  expect(wide.match(/class="whisker"/g)).toHaveLength(counted.filter(isTopTier).length);
});

test("the cost scatter places every priced setting, joins a model's efforts and brackets the top group's prices", () => {
  const [wide = ""] = drawingsOf(costFigure(CONFIGS));

  expect(tipsOf(wide)).toHaveLength(MODELS.length);
  expect([...wide.matchAll(/<polyline class="join" data-family="([^"]+)"/g)].map(([, id]) => id)).toEqual(["sonnet-5-5"]);
  expect(topTierRange(CONFIGS)?.map(({ short }) => short)).toEqual(["Terra 6.1 max", "Sonnet 5.5 max"]);
  expect(wide).toContain("38x the price, same top group");
  expect(wide).toContain('class="frontier"');
});

test("the tables hold one row per setting they cover", () => {
  expect(rowsOf(topGroupTable(CONFIGS))).toBe(MODELS.filter(isTopTier).length);
  expect(rowsOf(headToHeadTable(CONFIGS))).toBe(1);
  expect(headToHeadTable(CONFIGS)).toContain("46 / 84");
  expect(rowsOf(fullTable(CONFIGS))).toBe(SUMMARY_JSON.configs.length);
});

test("the variance figure gives each bar's segments and the seeds each measure needs", () => {
  const [wide = ""] = drawingsOf(varianceFigure(DATA.findings));

  expect(tipsOf(wide)).toEqual([
    "Round wins \u00b7 the setting explains 6.6% of the variance",
    "Round wins \u00b7 the seed explains 0.4% of the variance",
    "Round wins \u00b7 setting by seed explains 0.8% of the variance",
    "Round wins \u00b7 the rest explains 92.2% of the variance",
    "Move scores \u00b7 the setting explains 43.9% of the variance",
    "Move scores \u00b7 the seed explains 0.7% of the variance",
    "Move scores \u00b7 setting by seed explains 2.0% of the variance",
    "Move scores \u00b7 the rest explains 53.4% of the variance",
  ]);
  expect(wide).toContain("65 for round wins, 6 for move scores");
});

test("the article leads with the game, holds four figures and ends on the full table, with no long dash", () => {
  const html = articleHtml(DATA);

  expect([...html.matchAll(/<h2 id="([^"]+)"/g)].map(([, id]) => id)).toEqual(["game", "self-shots", "thinking", "cost", "variance", "built", "limits"]);
  expect([...html.matchAll(/<b>Figure (\d)\.<\/b>/g)].map(([, number]) => number)).toEqual(["1", "2", "3", "4"]);
  expect(html.indexOf('class="game')).toBeLessThan(html.indexOf("<figure"));
  expect(html.trimEnd().endsWith("</details>")).toBe(true);
  expect(html).not.toMatch(/[\u2014]|ADR/);
});

test("the share card holds one title and the strong models' and the search's rates", () => {
  const card = ogCard(DATA.findings);

  expect([...card.matchAll(/<text[^>]*>([^<]+)<\/text>/g)].map(([, text]) => text)).toEqual(["Two blanks, one live", "50% live", "80%", "17%"]);
});
