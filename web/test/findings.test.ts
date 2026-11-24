import { expect, test } from "bun:test";

import { configsOf, isTopTier } from "../src/findings/configs.ts";
import { costFigure, tierTable, topTierRange } from "../src/findings/cost.ts";
import { decodeFindingsData } from "../src/findings/data.ts";
import type { FindingsData } from "../src/findings/data.ts";
import { defaultSlots, forestFigure, headToHeadFigure } from "../src/findings/forest.ts";
import { ogCard } from "../src/findings/og.ts";
import { articleHtml } from "../src/findings/page.ts";
import { selfShotFigure } from "../src/findings/selfshoot.ts";
import { configTable } from "../src/findings/tables.ts";
import { varianceFigure } from "../src/findings/variance.ts";
import { FINDINGS_JSON, SUMMARY_JSON } from "./fixtures.ts";

const decode = (findingsJson = JSON.stringify(FINDINGS_JSON)): FindingsData => decodeFindingsData(JSON.stringify(SUMMARY_JSON), findingsJson);

const DATA = decode();

const CONFIGS = configsOf(DATA.summary);

const unescape = (text: string): string => text.replaceAll("&quot;", '"').replaceAll("&#39;", "'").replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&amp;", "&");

/** The tip of every mark in some HTML, in order. */
const tipsOf = (html: string): ReadonlyArray<string> => [...html.matchAll(/data-tip="([^"]*)"/g)].map(([, tip = ""]) => unescape(tip));

const drawingsOf = (html: string): ReadonlyArray<string> => html.split(/(?=<svg )/).filter((part) => part.startsWith("<svg "));

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
  for (const figure of [selfShotFigure(DATA.findings), costFigure(CONFIGS), varianceFigure(DATA.findings), headToHeadFigure(CONFIGS)]) {
    expect(drawingsOf(figure).map((drawing) => /class="(fig-\w+)"/.exec(drawing)?.[1])).toEqual(["fig-wide", "fig-narrow"]);
  }
});

test("the self-shot figure marks every curve point, the search on the strong states and every effort row, in each layout", () => {
  const strong = FINDINGS_JSON.curve.filter(({ group }) => group === "strong").length;

  for (const drawing of drawingsOf(selfShotFigure(DATA.findings))) { expect(tipsOf(drawing)).toHaveLength(FINDINGS_JSON.curve.length + strong + FINDINGS_JSON.sonnetEffort.length); }
});

test("the forest opens on tiers 1 and 2 and the fixed players outside them, and its fold holds one row per rated config", () => {
  expect(defaultSlots(CONFIGS).map((slot) => slot?.short ?? null)).toEqual(["Terra 6.1 max", "Sonnet 5.5 max", "Opus 5.5 max", "Depth-7 search", "Sol 6.1 max", null, "Story AI"]);

  const [shown = "", fold = ""] = forestFigure(CONFIGS).split("<details");

  for (const drawing of drawingsOf(fold)) { expect(tipsOf(drawing)).toHaveLength(CONFIGS.length); }

  for (const drawing of drawingsOf(shown)) { expect(tipsOf(drawing).filter((tip) => tip.includes("Tier 1 "))).toHaveLength(CONFIGS.filter(isTopTier).length); }
});

test("the head-to-head inset holds the model configs with a record against the depth-7 search", () => {
  expect(tipsOf(drawingsOf(headToHeadFigure(CONFIGS))[0] ?? "")).toEqual(["Opus 5.5 \u00b7 max vs the depth-7 search \u00b7 won 46 of 84 rounds, 54.8% [47.6, 61.9] \u00b7 14 seeds, both seat orders"]);
});

test("the cost figure places every model config, joins a family's efforts and brackets the top tier's prices", () => {
  const [wide = ""] = drawingsOf(costFigure(CONFIGS));
  const models = CONFIGS.filter(({ isFixed }) => !isFixed);

  expect(tipsOf(wide)).toHaveLength(models.length);
  expect([...wide.matchAll(/<polyline class="traj (\w+)" data-family="([^"]+)"/g)].map(([, family, id]) => [family, id])).toEqual([["claude", "sonnet-5-5"]]);
  expect(topTierRange(CONFIGS)?.map(({ short }) => short)).toEqual(["Terra 6.1 max", "Sonnet 5.5 max"]);
  expect(wide).toContain("38x the price, same tier");
});

test("the tier table and the appendix hold one row per config they cover", () => {
  expect(tierTable(CONFIGS).match(/<tr><th scope="row">/g)).toHaveLength(CONFIGS.filter((config) => isTopTier(config) && !config.isFixed).length);
  expect(configTable(CONFIGS).match(/<tr><th scope="row">/g)).toHaveLength(SUMMARY_JSON.configs.length);
});

test("the variance figure gives each bar's segments and the seeds each measure needs", () => {
  const [wide = ""] = drawingsOf(varianceFigure(DATA.findings));

  expect(tipsOf(wide)).toEqual([
    "Round wins \u00b7 the config explains 6.6% of the variance",
    "Round wins \u00b7 the seed explains 0.4% of the variance",
    "Round wins \u00b7 config by seed explains 0.8% of the variance",
    "Round wins \u00b7 the residual explains 92.2% of the variance",
    "Move regret \u00b7 the config explains 43.9% of the variance",
    "Move regret \u00b7 the seed explains 0.7% of the variance",
    "Move regret \u00b7 config by seed explains 2.0% of the variance",
    "Move regret \u00b7 the residual explains 53.4% of the variance",
  ]);
  expect(wide).toContain("65 for round wins, 6 for move regret");
});

test("the article holds every section, figure and the appendix, with no long dash", () => {
  const html = articleHtml(DATA);

  expect([...html.matchAll(/<p class="eyebrow">([^<]+)<\/p>/g)].map(([, eyebrow]) => eyebrow)).toEqual(["01 / Behavior", "02 / Ratings", "03 / Cost &amp; compute", "04 / Variance", "05 / Engineering", "06 / Limits"]);
  expect([...html.matchAll(/<b>Figure (\d)\.<\/b>/g)].map(([, number]) => number)).toEqual(["1", "2", "3", "4", "5"]);
  expect(html).toContain('<details class="appendix">');
  expect(html).not.toMatch(/[\u2014]|ADR/);
});

test("the share card states the strong models' and the search's rates", () => {
  const card = ogCard(DATA.findings);

  expect(card).toContain(">80%</tspan>");
  expect(card).toContain(">17%</tspan>");
});
