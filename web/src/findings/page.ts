import { configsOf, familiesOf, isTopTier, shadeCss } from "./configs.ts";
import type { Config } from "./configs.ts";
import type { FindingsData } from "./data.ts";
import { costFigure, priceRatio, thinkingFigure, topTierRange } from "./scatter.ts";
import { selfShotFigure } from "./selfshoot.ts";
import { count, esc, pct, tokens, usd } from "./svg.ts";
import { fullTable, headToHeadTable, topGroupTable } from "./tables.ts";
import { varianceFigure } from "./variance.ts";

// The findings post as one HTML string, filled into findings.html at build time. Every number the data files hold
// comes from them; the rest (reasoning summaries, token ratios on close calls) is quoted from the analyses.

const REPO = "https://github.com/sakompella/buckshot";

const tree = (path: string): string => `${REPO}/tree/main/${path}`;

const figure = (id: string, number: number, body: string, caption: string): string =>
  `<figure class="wide" id="${id}">${body}<figcaption><b>Figure ${number}.</b> ${caption}</figcaption></figure>`;

const find = (configs: ReadonlyArray<Config>, model: string, effort: string): Config | undefined => configs.find((each) => each.model.startsWith(model) && each.effort === effort);

/** One shell at `x`: dark blue for a blank, red with a pale stripe for a live one, on a brass base. */
const shell = (x: number, live: boolean): string =>
  `<rect class="${live ? "live" : "blank"}" x="${x}" y="2" width="34" height="62" rx="5"/>${live ? `<rect class="stripe" x="${x}" y="24" width="34" height="7"/>` : ""}<rect class="brass" x="${x}" y="64" width="34" height="14" rx="2"/>`;

/** The three shells and the two answers to them: what the strong models and the depth-7 search each do. */
const shellCard = (data: FindingsData): string => {
  const { headline } = data.findings;

  return `<div class="game wide" role="figure" aria-label="Two blank shells and one live, in an unknown order. Strong models shoot themselves on ${pct(headline.strongModelRate, 0)} of such shots; the depth-7 search shoots the opponent on ${pct(1 - headline.strongSearchRate, 0)}.">
<div class="shells" aria-hidden="true"><svg viewBox="0 0 150 96" width="150" height="96">${shell(2, false)}${shell(58, false)}${shell(114, true)}<g class="shell-tag"><text x="19" y="94">blank</text><text x="75" y="94">blank</text><text x="131" y="94">live</text></g></svg><p>Two blanks, one live, order unknown. Your shot.</p></div>
<div class="choice model"><p class="who">Strong models</p><p class="act">Shoot self</p><p class="rate">${pct(headline.strongModelRate, 0)}</p></div>
<div class="choice search"><p class="who">Depth-7 search</p><p class="act">Shoot opponent</p><p class="rate">${pct(1 - headline.strongSearchRate, 0)}</p></div>
<p class="game-note">Share of plain shots taken below 50% live, on the same positions.</p>
</div>`;
};

/** Two short notes from the reasoning, under Figure 2. */
const reasoningNotes = `<div class="notes wide">
<div class="card"><h3>Close calls get more thinking</h3><p>Claude 5.5 at max spends 9 to 15 times as many thinking tokens on close calls as on clear ones.</p></div>
<div class="card"><h3>Weak models lose count</h3><p>Haiku 4.5, Haiku 5.5 and Luna 6 make most of the simple counting errors, such as firing a shell they could have counted as live.</p></div>
<p class="notes-foot">Thinking tokens are as each company reports them. Both return summaries of the reasoning, not the reasoning itself.</p>
</div>`;

const STAGES: ReadonlyArray<readonly [string, string, string, string]> = [
  ["sim/bend-mp", "Rules in Bend", "The one source of truth for the game.", "proved laws, planted-bug runs"],
  ["sim/rust", "Rust search", "Looks 7 moves ahead. It plays, and it scores every model move.", "matches Bend on a golden set"],
  ["web/src/arena", "Arena", "Seeded deals in both seat orders, with cost and time per call.", "every match replays"],
  ["tools/arena/analysis", "Scoring", "Takes the luck of the deal out, then fits skill scores.", "seed bootstrap, independent recount"],
];

/** The article body: masthead, the game, four figures, how it is built, limits and the full table. */
export const articleHtml = (data: FindingsData): string => {
  const { findings, summary } = data;
  const { headline, sonnetEffort, gStudy } = findings;
  const configs = configsOf(summary);
  const models = configs.filter(({ isFixed }) => !isFixed);
  const topModels = configs.filter((config) => isTopTier(config) && !config.isFixed);
  const [cheapest, dearest] = topTierRange(configs) ?? [];
  const astraHigh = find(configs, "gpt-6-astra", "high");
  const sonnetMax = find(configs, "claude-sonnet-5-5", "max");
  const sonnetOff = sonnetEffort.find(({ effort }) => effort === "off");
  const sonnetMaxShots = sonnetEffort.find(({ effort }) => effort === "max");
  const matches = count(summary.configs.reduce((total, { scored }) => total + scored, 0) / 2);
  const families = familiesOf(configs).length;
  const headToHead = models.filter(({ vsEngine }) => vsEngine !== null);
  const astraZero = astraHigh?.reasonedShare === null || astraHigh?.reasonedShare === undefined ? "" : pct(1 - astraHigh.reasonedShare, 0);

  return `<style>${shadeCss()}</style>
<header class="masthead wide">
<h1>Buckshot Arena</h1>
<p class="sub">How ${models.length} AI model settings play a game of hidden shells and risk</p>
<p class="by">Aditya Kompella \u00b7 November 2026</p>
<ul class="pills"><li><a href="${REPO}">Code</a></li><li><a href="/data/summary.json">Data</a></li><li><a href="#table">Full table</a></li></ul>
</header>

<h2 id="game">The game in a minute</h2>
<p>Two players share a shotgun loaded with live and blank shells. Both know how many of each went in, but not the order. On your turn you shoot the opponent or yourself, and a blank fired at yourself keeps your turn.</p>
<p>${models.length} settings of ${families} AI models played more than 5,000 matches (${matches} including baseline games) against each other and against a search that looks 7 moves ahead. That depth-7 search also scored every move.</p>
${shellCard(data)}

<h2 id="self-shots">Below 50% live, strong models shoot themselves</h2>
<p>Shooting yourself looks free, since a blank keeps your turn. With one live shell in three, though, shooting the opponent puts the live shell on them 2 times in 3, and shooting yourself hands you the next shell at 50/50.</p>
<p>Take the plain shots, where the shooter does not know the shell, the gun is not sawn off and the opponent is not jammed. Below 50% live, the strongest models shot themselves on ${pct(headline.strongModelRate, 0)} of ${count(headline.strongN)} such shots. On the same positions the depth-7 search did so on ${pct(headline.strongSearchRate, 0)}. The habit stops at 50% live, so the models read the odds and then apply a rule. More thinking breaks it. Sonnet 5.5 shot itself ${sonnetOff === undefined ? "" : pct(sonnetOff.modelRate, 0)} of the time with thinking off and ${sonnetMaxShots === undefined ? "" : pct(sonnetMaxShots.modelRate, 0)} at max.</p>
<p>Shooting is also where much of the loss is. ${pct(headline.missedItemLossShare)} of all the win chance the models gave up came from taking a shot when an item scored higher.</p>
${figure("fig-self-shots", 1, selfShotFigure(findings), `Share of plain shots aimed at self. Strong models are Astra 6, Sol 6.1, Sonnet 5.5, Opus 5.5 and Terra 6.1 and 5.6, with ${count(headline.strongN)} shots below 50% live. Bars are 90% ranges.`)}

<h2 id="thinking">${astraHigh?.short ?? "Astra 6 high"} reaches the top group on almost no thinking</h2>
<p>Each mark is one model setting, and a line joins one model\u2019s settings from least to most effort. The skill score is a rating from rounds won with the luck of the deal taken out, where 0 is the depth-7 search. The top group holds ${topModels.length} settings and the search. Their 90% ranges overlap, so they can\u2019t be put in order.</p>
<p>Within a model, more effort mostly buys more skill. Across models the amount differs a lot. ${astraHigh?.short ?? ""} reports about ${tokens(astraHigh?.tokensPerMove ?? 0)} thinking tokens a move, and none at all on ${astraZero} of its moves. ${sonnetMax?.short ?? ""} reports about ${tokens(sonnetMax?.tokensPerMove ?? 0)}.</p>
${figure("fig-thinking", 2, thinkingFigure(configs), "Skill score against thinking tokens per move, log scale. Vertical bars are 90% ranges on the top group. The two companies may count thinking tokens differently.")}
${reasoningNotes}

<h2 id="cost">Same top group, ${priceRatio(configs)}x the price</h2>
<p>At list prices a match cost ${usd(cheapest?.cost ?? 0)} with ${cheapest?.short ?? ""} and ${usd(dearest?.cost ?? 0)} with ${dearest?.short ?? ""}. Both are in the top group. The dashed step marks the best skill score available at each price.</p>
${figure("fig-cost", 3, costFigure(configs), "Skill score against cost per match at list price, log scale.")}
<p>${headToHead.length === 2 ? "Two" : String(headToHead.length)} top settings also played the depth-7 search directly, with no judge. Neither record separates from an even split.</p>
<div class="wide tables">${topGroupTable(configs)}${headToHeadTable(configs)}</div>

<h2 id="variance">Why the outcome ranges are wide</h2>
<p>Most of a round\u2019s result is the deal. The model setting explains ${pct(gStudy.rounds.config)} of the spread in round wins and ${pct(gStudy.regret.config)} of the spread in move scores. Ranking settings reliably takes ${Math.ceil(gStudy.seedsG90.rounds)} seeds with round wins and ${Math.ceil(gStudy.seedsG90.regret)} with move scores, about ${Math.round(gStudy.ratioAll)}x fewer, or ${gStudy.ratioTop14.toFixed(1)}x fewer among the top 14. That is why Figure 1 is tight and the skill scores are wide. Every range on this page is a 90% range, and more seeds would narrow them.</p>
${figure("fig-variance", 4, varianceFigure(findings), `Share of variance by source, over ${gStudy.configs} settings and ${gStudy.seeds} seeds. The rest is mostly the luck of the deal.`)}

<h2 id="built">How it\u2019s built</h2>
<ol class="pipeline wide">${STAGES.map(([path, stage, role, check]) => `<li><a href="${tree(path)}"><b>${esc(stage)}</b><span>${esc(role)}</span><small>${esc(check)}</small></a></li>`).join("")}</ol>

<h2 id="limits">Limits</h2>
<ul class="limits">
<li>The depth-7 search is both an opponent and the judge of every move.</li>
<li>The reasoning counts come from 41 summaries read by model readers, not checked by hand.</li>
<li>This is one game.</li>
</ul>

<details class="full wide" id="table">
<summary>Full table \u00b7 all ${configs.length} settings</summary>
${fullTable(configs)}
<p class="data-note">Group 1 is the top group. Skill scores have 0 at the depth-7 search. The numbers are in <a href="/data/summary.json">summary.json</a> and <a href="/data/findings.json">findings.json</a>, generated ${esc(findings.generated)}.</p>
</details>`;
};
