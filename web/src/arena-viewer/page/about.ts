import type { Html, HtmlBuilder } from "foldkit/html";

import { isOnline } from "../../site/online.ts";
import type { Runs } from "../aggregates.ts";
import { isPromptedOff } from "./data.ts";
import { type Derived, MOVE_ELO } from "./derived.ts";
import { forestView } from "./forest.ts";
import { INTERVAL_PERCENT } from "./ratings.ts";
import { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// The page's reader-facing text: the results summary at the top, the game explained after the first chart,
// the method under About and the footer. Numbers come from the aggregates; the rules come from the shared instructions.

const DAY = new Intl.DateTimeFormat("en-US", { timeZone: "UTC", month: "short", day: "numeric", year: "numeric" });

/** "Oct 15 – Nov 9, 2026", or the one day when both ends are the same. */
const runDates = (runs: Runs): string => (runs.from === runs.to ? DAY.format(new Date(runs.from)) : `${DAY.format(new Date(runs.from))} – ${DAY.format(new Date(runs.to))}`);

/** The ranked configs' headline rating with intervals, and the search engines as reference lines. */
export const summaryView = (h: H, derived: Derived): Html =>
  h.div(
    [],
    [
      h.h2([], ["Results at a glance"]),
      h.p([h.Class("sub")], [
        `${derived.ratingName} of every ranked config, best first`,
        ...(derived.runs === undefined ? [] : [`, from matches played ${runDates(derived.runs)}`]),
        `. Every match of every tournament counts, and the depth-7 search engine sits at 0. The dot is a config's rating and the line is its ${INTERVAL_PERCENT} interval. When two lines overlap, the data cannot tell those configs apart. The dashed lines are the search engines, fixed players that About explains. The leaderboard groups the configs into tiers.`,
      ]),
      forestView(h, derived),
    ],
  );

/** The game, the experiment and one worked turn, before the charts. */
export const howView = (h: H): Html =>
  h.div(
    [],
    [
      h.h2([], ["How the game works"]),
      h.p([h.Class("sub")], [
        "Two players share a shotgun loaded with a hidden mix of live and blank shells. Each load announces how many of each it holds, but never their order. On your turn you may use items, then you must shoot: yourself or the other player. A live shell does one damage; a blank does none. Shooting the other player always passes the turn. Shooting yourself with a blank keeps the turn, and that is the only way to get another move. Each player starts a round with 3 or 4 health. A round ends when one player is left alive, and that player takes the round's prize. A match is three rounds, and whoever has the most cash at the end wins it.",
      ]),
      h.p([h.Class("sub")], [
        "Nobody is told the shell order. Players learn it from the counts announced at each load, the shells already fired, and their own items: the magnifying glass shows the chambered shell, and the burner phone shows a later one. The other items change the gun or the players: the handsaw doubles the next shot's damage, beer ejects the chambered shell, the inverter flips it between live and blank, cigarettes heal one health, the jammer makes the opponent skip a turn, and adrenaline steals an opponent's item and uses it.",
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["An example turn. "]),
        "The gun holds two live shells and one blank, and your magnifying glass showed that the chambered shell is the blank. Shooting yourself costs nothing: the blank keeps your turn, and the next shell is then sure to be live, so you can fire it at your opponent. Shooting the opponent instead passes the turn and hands over the gun. The How they play section counts moves like that as certain mistakes.",
      ]),
      h.p([h.Class("sub")], [
        "Each player here is a language model, apart from the search engines. On its turn a model receives its view as JSON: both players' health and items, the shotgun, the log entries it has not been sent yet, and its numbered legal moves. It answers with one move number. Each log entry is sent only once, so the model must remember the earlier ones. It sees the public log and its own secrets, never the true shell order or the other player's secrets. A config is one model at one effort setting. The effort (none to max) is how much thinking the provider allows per move, and more effort costs more. The chips at the top turn models and efforts off and on.",
      ]),
    ],
  );

/** Run dates, conditions, the ratings, and what the comparison cannot settle. */
export const aboutView = (h: H, derived: Derived): Html => {
  const hasLuck = derived.everyPooled.some(({ luckRating }) => luckRating !== null);
  const promptedOff = derived.everyPooled.filter(isPromptedOff).map(({ label }) => label);
  const { blocks, unpaired } = derived.seedBlocks;

  return h.div(
    [],
    [
      h.h2([], ["About this experiment"]),
      ...(derived.runs === undefined ? [] : [h.p([h.Class("sub")], [`The matches here were played ${runDates(derived.runs)} (UTC).`])]),
      h.p([h.Class("sub")], [
        `Every match has two players and uses items. A seed fixes the deals. A seed block is one seed that a pairing plays in both seat orders, so neither side gains from sitting first. ${unpaired.toLocaleString()} of the ${blocks.toLocaleString()} seed blocks hold only one scored match, so their seat order is not balanced. All tournaments are pooled. Every model plays under the same shared instructions with the same tools`,
        ...(promptedOff.length === 0
          ? ["."]
          : [`, except ${promptedOff.join(", ")}: its API has no reasoning-off setting, so it plays at low effort with one added line telling it to answer at once, without planning or checking ("immediate-recall mode").`]),
        " The models were called through subscription accounts behind a proxy, not with first-party API keys.",
        ...(isOnline ? [] : [" The Matches section lists every match."]),
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["Search engines. "]),
        "The configs named Search engine are not language models. They are the arena's own minimax search program, which looks ahead through the possible moves, assumes the opponent also plays its best, and plays the move that scores best. Depth is how many decisions ahead it looks. With sampled reloads, it values a new load by trying a sample of the possible deals. Search engines cost nothing, so the charts draw them as reference lines.",
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["Round Elo. "]),
        `A Bradley-Terry rating: one fit over every scored match, where each round counts as one game. The gap between two ratings says how often one config beats the other in a round. The depth-7 search engine (Engine/7/2000000/sampled) is fixed at 0, so adding a config does not move the others. The bracket beside a rating is its ${INTERVAL_PERCENT} bootstrap interval: the fit is redone many times on seed blocks drawn at random, with repeats, and about one in ten true values falls outside the bracket. Because whole seed blocks are drawn, the bracket includes the luck that all matches on one seed share. Each bracket is measured against the mean of all configs, so it leaves out the engine's own noise; the leaderboard gives that noise once.`,
      ]),
      ...(hasLuck
        ? [
            h.p([h.Class("sub")], [
              h.b([], ["Luck-adjusted Elo. "]),
              "The same fit, with each round's luck taken out: the shots, loads, first seat, item deals and the shells that items show. The correction method is AIVAT. It estimates the same strengths with less noise. This is the headline rating, and it ranks the leaderboard and the results summary.",
            ]),
          ]
        : []),
      ...(derived.everyPooled.some(({ moveRating }) => moveRating !== null)
        ? [
            h.p([h.Class("sub")], [
              h.b([], [`${MOVE_ELO}. `]),
              "A second column. It never sets the ranking. Across the language-model configs, the headline rating falls close to a straight line when set against points lost per move, as the move scorer counts them. Each config's rating is combined with the rating its points lost predict, and each of the two is weighted by how precise it is. So a config with few matches leans on its moves, and a config with many matches leans on its results. This trusts the move scorer: a config whose strength the scorer cannot see is pulled toward the line.",
            ]),
          ]
        : []),
      h.p([h.Class("sub")], [
        h.b([], ["What to keep in mind. "]),
        `Configs are grouped in tiers. Going down the ranking, a new tier starts at the first config that is clearly below the top config of the current tier: the ${INTERVAL_PERCENT} bootstrap interval of the gap between the two does not include 0. Within a tier the order is not settled. Provisional configs (fewer than 20 scored matches) have no tier. Points lost and accuracy are measured against a minimax player, not against perfect play; certain mistakes do not need such a player. Costs are the providers' list prices applied to the usage, not what anyone was billed.`,
      ]),
    ],
  );
};

/** The data date, a link to the method, and whose game this is. */
export const footerView = (h: H, derived: Derived): Html =>
  h.footer(
    [h.Class("foot")],
    [
      h.p([], [
        ...(derived.runs === undefined ? [] : [`Matches through ${DAY.format(new Date(derived.runs.to))}. `]),
        h.a([h.Href("#about"), h.OnClick(Message.ClickedJump({ target: "about" }), { defaultAction: "Prevent" })], ["Methods"]),
        ".",
      ]),
      h.p([], ["An unofficial project, not affiliated with the game's developer. Buckshot Roulette is a game by Mike Klubnika."]),
    ],
  );
