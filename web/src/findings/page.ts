import { configsOf, isTopTier } from "./configs.ts";
import type { Config } from "./configs.ts";
import { costFigure, tierTable, topTierRange } from "./cost.ts";
import type { CurvePoint, FindingsData } from "./data.ts";
import { isBelowEven } from "./data.ts";
import { forestFigure, headToHeadFigure } from "./forest.ts";
import { selfShotFigure } from "./selfshoot.ts";
import { esc, pct, pctInterval, points, pointsInterval, rating, ratingInterval, usd } from "./svg.ts";
import { configTable, glossary } from "./tables.ts";
import { varianceFigure } from "./variance.ts";

// The findings post: prose, figures and tables as one HTML string, filled into findings.html at build time. Every number
// the data files hold comes from them; the rest (reasoning traces, judge calibration) is quoted from the analyses.

const REPO = "https://github.com/sakompella/buckshot";

const tree = (path: string): string => `${REPO}/tree/main/${path}`;

const MONTHS = new Intl.DateTimeFormat("en-US", { month: "long", day: "numeric", timeZone: "UTC" });

const day = (iso: string): string => MONTHS.format(new Date(`${iso}T00:00:00Z`));

const eyebrow = (index: number, name: string): string => `<p class="eyebrow">${String(index).padStart(2, "0")} / ${esc(name)}</p>`;

const figure = (id: string, number: number, title: string, body: string, caption: string): string =>
  `<figure class="wide" id="${id}"><p class="fig-title">${esc(title)}</p>${body}<figcaption><b>Figure ${number}.</b> ${caption}</figcaption></figure>`;

const pointAt = (curve: ReadonlyArray<CurvePoint>, label: string): CurvePoint | undefined => curve.find((point) => point.group === "strong" && point.pLabel === label);

const rateAt = (curve: ReadonlyArray<CurvePoint>, label: string): string => {
  const point = pointAt(curve, label);

  return point === undefined ? "" : pct(point.modelRate, 0);
};

const range = (values: ReadonlyArray<number>): string => `${Math.round(Math.min(...values) * 100)} and ${pct(Math.max(...values), 0)}`;

const config = (configs: ReadonlyArray<Config>, model: string, effort: string): Config | undefined => configs.find((each) => each.model.startsWith(model) && each.effort === effort);

const record = (each: Config | undefined): string => {
  const games = each?.vsEngine;

  return games === undefined || games === null || games.rate === null || games.lo === null || games.hi === null
    ? ""
    : `${games.k} of ${games.n} rounds, ${pct(games.rate)} ${pctInterval(games.lo, games.hi)}`;
};

const list = (names: ReadonlyArray<string>): string => (names.length < 2 ? names.join("") : `${names.slice(0, -1).join(", ")} and ${names.at(-1) ?? ""}`);

/** The 3-shell card at the top: what a strong model and the search each do with two blanks and one live shell. */
const hook = (data: FindingsData): string => {
  const { headline } = data.findings;

  return `<div class="hook wide" role="figure" aria-label="Three shells, two blank and one live. Strong models shoot themselves on ${pct(headline.strongModelRate, 0)} of such shots; the depth-7 search shoots the opponent on ${pct(1 - headline.strongSearchRate, 0)}.">
<div class="shells" aria-hidden="true"><span class="shell blank">Blank</span><span class="shell blank">Blank</span><span class="shell live">Live</span></div>
<p class="hook-q">Two blanks and one live shell, in an unknown order. Your shot.</p>
<div class="choices">
<div class="choice model"><p class="who">Strong models</p><p class="act">Shoot self</p><p class="why">on ${pct(headline.strongModelRate, 0)} of shots below even odds</p><p class="cost">about \u22124 points each</p></div>
<div class="versus" aria-hidden="true">vs</div>
<div class="choice search"><p class="who">Depth-7 search</p><p class="act">Shoot opponent</p><p class="why">on ${pct(1 - headline.strongSearchRate, 0)} of the same shots</p><p class="cost">the live shell lands on them 2 times in 3</p></div>
</div>
</div>`;
};

/** The article body: header, TL;DR, five findings sections, limits and the appendix. */
export const articleHtml = (data: FindingsData): string => {
  const { findings, summary } = data;
  const { headline, curve, sonnetEffort, gStudy } = findings;
  const configs = configsOf(summary);
  const models = configs.filter(({ isFixed }) => !isFixed);
  const topTier = configs.filter(isTopTier);
  const topModels = topTier.filter(({ isFixed }) => !isFixed);
  const topFixed = topTier.filter(({ isFixed }) => isFixed);
  const [cheapest, dearest] = topTierRange(configs) ?? [];
  const priceRatio = cheapest === undefined || dearest === undefined ? 0 : Math.round(dearest.cost / cheapest.cost);
  const fastest = topModels.toSorted((left, right) => (left.secondsPerMove ?? Infinity) - (right.secondsPerMove ?? Infinity))[0];
  const slowest = topModels.toSorted((left, right) => (right.secondsPerMove ?? 0) - (left.secondsPerMove ?? 0))[0];
  const terraMax = config(configs, "gpt-6.1-terra", "max");
  const opusMax = config(configs, "claude-opus-5-5", "max");
  const solMax = config(configs, "gpt-6.1-sol", "max");
  const strongBelow = curve.filter((point) => point.group === "strong" && isBelowEven(point));
  const strongAbove = curve.filter((point) => point.group === "strong" && !isBelowEven(point) && point.pLive > 0.5);
  const sonnetOff = sonnetEffort.find(({ effort }) => effort === "off");
  const sonnetMax = sonnetEffort.find(({ effort }) => effort === "max");
  const runs = summary.runs === undefined ? "" : ` between ${day(summary.runs.from)} and ${day(summary.runs.to)}, 2026`;
  const fixedCount = configs.length - models.length;
  const lunaShots = curve.filter((point) => point.group === "luna" && isBelowEven(point)).reduce((total, { n }) => total + n, 0);
  const haikuShots = curve.filter((point) => point.group === "haiku" && isBelowEven(point)).reduce((total, { n }) => total + n, 0);
  const fastestZeroShare = fastest?.reasonedShare === null || fastest?.reasonedShare === undefined ? "" : pct(1 - fastest.reasonedShare, 0);

  return `<header class="masthead">
<h1>Two blanks, one live</h1>
<p class="dek">I had ${models.length} model configs play more than 5,000 matches of a two-player shotgun game, scored every move against a depth-7 search, and found one habit the best models share and the search does not.</p>
<p class="byline">Aditya Kompella \u00b7 November 2026 \u00b7 <a href="${REPO}">Code</a> \u00b7 <a href="/data/summary.json">Data</a></p>
</header>

<p>Three shells go into the shotgun. Two are blank and one is live, in an order nobody knows. It is your turn. In Buckshot Roulette you may aim at your opponent or at yourself, and a blank fired at yourself keeps your turn.</p>
<p>The strongest language models I tested take that deal. They write things like \u201ctwo of the three are blank, I keep the turn\u201d and point the gun at themselves. A depth-7 search, looking at the same positions, mostly shoots the opponent.</p>

${hook(data)}

<aside class="tldr" aria-label="Summary">
<p class="tldr-head">TL;DR</p>
<ul>
<li>Below 50% live, strong models shoot themselves on ${pct(headline.strongModelRate, 0)} of plain shots. The depth-7 search prefers that on ${pct(headline.strongSearchRate, 0)}.</li>
<li>The top tier holds ${topModels.length} model configs and the depth-6 and depth-7 searches, with no detectable gap between them. Head to head, ${terraMax?.short ?? ""} and ${opusMax?.short ?? ""} win 53 to 55% of rounds against the search, with intervals that include 50%.</li>
<li>Inside that tier, cost per match spans ${priceRatio}x, from ${usd(cheapest?.cost ?? 0)} to ${usd(dearest?.cost ?? 0)}.</li>
<li>Scoring moves needs about ${Math.round(gStudy.ratioAll)}x fewer seeds than counting wins. That is why the behavior findings are sharp and the leaderboard is wide.</li>
</ul>
</aside>

<h2 id="setup">The game and the players</h2>
<p>Buckshot Roulette is a two-player game around one shotgun. Each load mixes live and blank shells, and both players know how many of each went in. You shoot yourself or your opponent. A live shell costs a life, and a blank fired at yourself lets you go again. Items change the odds. A magnifying glass shows the chambered shell, a handsaw doubles the damage, beer ejects a shell, an inverter flips one, a jammer skips the opponent\u2019s turn, and a few more.</p>
<p>${models.length} model configs played. A config is one model at one effort setting. The Claude side was Haiku 4.5 and 5.5, Sonnet 5.5 and Opus 5.5. The GPT side was Luna 6, Terra 5.6 and 6.1, Sol 6.1 and Astra 6. Each played at every effort level its API offers. ${fixedCount} fixed players joined them, a search engine at three depths and two fixed rule-based computer players. Every match used seeded deals in both seat orders, and the matches ran${runs}.</p>
<p>I scored every model move with a depth-7 search. A point is one percentage point of round-win chance by its estimate. A move that loses 4 points turns a 60% round into a 56% round.</p>

${eyebrow(1, "Behavior")}
<h2 id="behavior">Below even odds, they shoot themselves</h2>
<p>Take the clean shots, where the shooter does not know the chambered shell, the gun is not sawn off and the opponent is not jammed. When fewer than half the remaining shells are live, the models aimed at themselves on ${pct(headline.modelRate)} of ${headline.cleanShotsN.toLocaleString("en-US")} shots. On the same states the search preferred that on ${pct(headline.searchRate)}. The gap is ${points(headline.gap)} points ${pointsInterval(headline.gapLo, headline.gapHi)}.</p>
<p>It is a threshold rule. The strong families shot themselves on ${rateAt(curve, "1/4")} of shots at 1/4 live, ${rateAt(curve, "1/3")} at 1/3, ${rateAt(curve, "2/5")} at 2/5 and ${rateAt(curve, "1/2")} at 1/2. Above 1/2 they almost never did, at most ${pct(Math.max(...strongAbove.map(({ modelRate }) => modelRate)), 0)}. The search sat between ${range(strongBelow.map(({ searchRate }) => searchRate))} at every value below 1/2. For the strong families the gap is ${points(headline.strongGap, 0)} points ${pointsInterval(headline.strongGapLo, headline.strongGapHi, 0)}.</p>
${figure("fig-selfshot", 1, "Below 50% live, strong models aim at themselves. The search mostly doesn\u2019t.", selfShotFigure(findings), `Share of clean shots aimed at self, by the chance the chambered shell is live. Clean shots have an unknown chamber, an unsawn gun and an opponent who is not jammed. Strong models are Astra 6, Sol 6.1, Sonnet 5.5, Opus 5.5 and Terra 6.1 and 5.6 (${headline.strongN.toLocaleString("en-US")} shots below 1/2). Haiku covers ${haikuShots.toLocaleString("en-US")} and Luna 6 ${lunaShots.toLocaleString("en-US")}, for ${headline.cleanShotsN.toLocaleString("en-US")} in all. The search line is the depth-7 search on the strong models\u2019 states. Bars are 90% intervals from 2,000 bootstrap draws over seeds.`)}
<p>This is not small models gambling more. Haiku 5.5 tracks the search. Haiku 4.5 runs higher at 1/4. Luna 6 sits about 20 points above the search everywhere, on both sides of 1/2, which reads as noise rather than this rule.</p>
<p>The search is right for a simple reason. With one live shell in three and no items, shooting the opponent lands the live shell on them 2 times in 3. On a blank they face a 50/50 shell next. Shooting yourself gives that 50/50 to you, and the live shell reaches the opponent only 1 time in 3. The turn you keep comes with a deadlier gun.</p>
<p>The models read the odds correctly. In a sample of reasoning traces, the stated chance of a live shell matched the true value 24 times out of 24. What they did with it was apply \u201ca blank keeps my turn\u201d, which 19 of 27 self-shooting traces cite. Each such shot gives up about 4 points by the search\u2019s count, and the rule barely reacts to stakes. Strong models still shot themselves 68% of the time when the search rated that more than 5 points worse.</p>
<p>Long reasoning breaks the habit. Across Sonnet and Opus decisions, the self-shot rate falls from 95% when the reasoning is under 500 characters to 10% above 5,000. Sonnet 5.5 shot itself on ${sonnetOff === undefined ? "" : pct(sonnetOff.modelRate, 0)} of these shots with reasoning off and ${sonnetMax === undefined ? "" : pct(sonnetMax.modelRate, 0)} at max effort, where the search sat at ${sonnetMax === undefined ? "" : pct(sonnetMax.searchRate, 0)}.</p>
<p>Shooting is also where much of the loss is. ${pct(headline.missedItemLossShare)} ${pctInterval(headline.missedItemLossLo, headline.missedItemLossHi)} of all the round-win chance the search says models gave up came from taking a shot when an item, a steal or a jam scored higher.</p>

${eyebrow(2, "Ratings")}
<h2 id="ratings">The top is a tie, and the search is in it</h2>
<p>I rate configs with a luck-adjusted Round Elo, anchored at the depth-7 search as 0. A new tier starts at the first config whose gap to the tier\u2019s top excludes 0. Tier 1 holds ${list(topModels.map(({ short }) => short))}, along with the ${list(topFixed.map(({ label }) => label.toLowerCase()))}.${solMax !== undefined && solMax.tier !== 1 ? ` ${solMax.short} just misses it at ${rating(solMax.rating)} ${ratingInterval(solMax.lo, solMax.hi)}.` : ""}</p>
${figure("fig-ratings", 2, `${topModels.length === 5 ? "Five" : String(topModels.length)} model configs and the search share the top tier.`, `${forestFigure(configs)}${headToHeadFigure(configs)}`, "Luck-adjusted Round Elo from a Bradley-Terry fit over every scored round, with 90% intervals from refitting seed-block resamples. Round Elo is not match Elo. The inset counts rounds against the depth-7 search directly, with no judge.")}
<p>The direct record needs no judge. ${terraMax?.short ?? ""} won ${record(terraMax)} against the depth-7 search. ${opusMax?.short ?? ""} won ${record(opusMax)}. Neither shows parity or superiority. More seeds would settle it.</p>
<p>Effort helps, by about half of what the raw numbers suggest. Within recurring positions, each step up in effort gave up ${Math.abs(headline.fixedPosEffortSlope).toFixed(2)} fewer points per move, ${pct(headline.fixedPosEffortShareOfRaw, 0)} of the association across all turns.</p>

${eyebrow(3, "Cost & compute")}
<h2 id="cost">Same tier, ${priceRatio}x the price</h2>
<p>${cheapest?.short ?? ""} cost ${usd(cheapest?.cost ?? 0)} per scored match. ${dearest?.short ?? ""} cost ${usd(dearest?.cost ?? 0)}. They sit in the same tier. ${fastest === undefined || slowest === undefined ? "" : `${fastest.short} took ${fastest.secondsPerMove?.toFixed(1) ?? ""} s per move and billed reasoning tokens on few moves. ${slowest.short} took ${slowest.secondsPerMove?.toFixed(0) ?? ""} s.`}</p>
${figure("fig-cost", 3, `Same tier, ${priceRatio}x the price.`, `${costFigure(configs)}${tierTable(configs)}`, `Cost per scored match at list price, log scale, against luck-adjusted Round Elo. Circles are Claude configs and squares GPT. Thin lines join each model\u2019s efforts, weakest to strongest. The dashed step is the best rating available at each price. Reasoning tokens are averaged over all moves, including those that billed none${fastest === undefined || fastestZeroShare === "" ? "" : `. ${fastest.short} billed none on ${fastestZeroShare} of its moves`}.`)}
<p>Claude 5.5 at max effort spends its tokens where they matter. It used 9 to 15 times as many reasoning tokens on close calls as on clear ones. That is the same long reasoning that breaks the self-shot habit.</p>

${eyebrow(4, "Variance")}
<h2 id="variance">Wins are mostly luck; moves are not</h2>
<p>A variance study over ${gStudy.configs} configs and ${gStudy.seeds} seeds splits each result into config, seed, config by seed and the rest. The config explains ${pct(gStudy.rounds.config)} of the variance in round-win share and ${pct(gStudy.regret.config)} of the variance in mean move regret.</p>
${figure("fig-variance", 4, "Move quality separates configs that round wins cannot.", varianceFigure(findings), `Shares of variance from a restricted-likelihood fit with config, seed and config-by-seed effects. The residual is what neither explains, mostly the luck of the deal. Repeatability G is the share of a config\u2019s mean that would replicate on new seeds, two seat orders per seed.`)}
<p>To reach a repeatability of 0.9, move regret needs ${Math.ceil(gStudy.seedsG90.regret)} seeds and round wins need ${Math.ceil(gStudy.seedsG90.rounds)}. Among the 14 strongest configs the advantage drops to ${gStudy.ratioTop14.toFixed(1)}x. This is a design lesson more than a caveat. Scoring every move is why Figure 1 is tight and Figure 2 is wide.</p>

${eyebrow(5, "Engineering")}
<h2 id="engineering">How it\u2019s built</h2>
<p>Each stage has its own check, and each feeds the next.</p>
<figure class="wide" id="fig-pipeline"><p class="fig-title">Four stages, each with the check it passes.</p>
<ol class="pipeline">
<li><a href="${tree("sim/bend-mp")}"><span class="stage">Rules in Bend</span><span class="role">The source of truth for the game</span><span class="check">Laws proved and checked by a Lean-built kernel, planted-bug runs</span></a></li>
<li><a href="${tree("sim/rust")}"><span class="stage">Rust search</span><span class="role">Depth-7 minimax with sampled reloads</span><span class="check">Parity with Bend, mutation tests, a bit-exact golden set</span></a></li>
<li><a href="${tree("web/src/arena")}"><span class="stage">Arena</span><span class="role">Seeded deals, both seat orders, cost and latency per call</span><span class="check">Replayable matches, privacy-scanned export</span></a></li>
<li><a href="${tree("tools/arena/analysis")}"><span class="stage">Scoring</span><span class="role">Luck correction, Round Elo, move regret</span><span class="check">Seed-block bootstrap, out-of-fold fits, an independent recount</span></a></li>
</ol>
<figcaption><b>Figure 5.</b> The pipeline from rules to ratings. Each card links to its code.</figcaption></figure>
<p>The rules live in Bend, and nothing else re-implements them. The TypeScript arena calls Bend exports, and the Rust search is tested against Bend until they agree on every position in the golden set. When they disagree, Bend wins.</p>
<p>The arena runs matches from fixed seeds in both seat orders and logs every model call with its cost and latency. Only per-config numbers leave the machine, after a privacy scan.</p>
<p>Scoring corrects each round for the luck of the deal, fits Round Elo with a seed-block bootstrap and scores every move against the depth-7 search. An independent model recomputed the headline numbers from the database. Claims it could not confirm are not on this page.</p>

${eyebrow(6, "Limits")}
<h2 id="limits">What this does not show</h2>
<ul class="limits">
<li>The judge is a depth-7 search, not a solver. In top-against-top model games its round-win estimates ran 2.4 points above the outcomes, with a 90% interval of 1.0 to 3.9.</li>
<li>The reasoning-trace counts come from 41 decisions read by two model readers with one rubric. Nobody checked them by hand.</li>
<li>Reasoning length is a correlation. It also tracks how hard a position looks.</li>
<li>Claude and GPT saw different positions, so their item preferences are not a family comparison.</li>
<li>Provider models can change without notice. A 32-day drift test found no change.</li>
<li>This is one game.</li>
</ul>

<details class="appendix">
<summary>Appendix. All ${configs.length} configs, terms and raw data</summary>
<h3>All configs</h3>
${configTable(configs)}
<h3>Terms</h3>
${glossary()}
<h3>Data</h3>
<p>The per-config numbers are in <a href="/data/summary.json">/data/summary.json</a> and the self-shot, effort and variance numbers in <a href="/data/findings.json">/data/findings.json</a>, generated ${esc(findings.generated)}.</p>
</details>`;
};
