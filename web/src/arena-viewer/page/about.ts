import type { Html, HtmlBuilder } from "foldkit/html";

import { isOnline } from "../../site/online.ts";
import type { Runs } from "../aggregates.ts";
import { isPromptedOff } from "./data.ts";
import type { Derived } from "./derived.ts";
import { forestView } from "./forest.ts";
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
        `. It pools every match of every tournament, with the depth-2 search engine at 0; the bar is its 95% interval, so configs whose bars overlap are not separated by the data. The dashed lines are the search engines, fixed players that About explains. The leaderboard groups the configs into tiers.`,
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
        "Two players share a shotgun loaded with a hidden mix of live and blank shells. Each load announces how many of each it holds, never their order. On your turn you may use items, then you must shoot: yourself or the other player. A live shell does one damage; a blank does none. Shooting the other player always passes the turn. Shooting yourself on a blank keeps it — the one way to buy another move. Each player starts a round with 3 or 4 health; a round ends when one player is left alive, who takes the round's prize. A match is three rounds, and the most cash at the end wins it.",
      ]),
      h.p([h.Class("sub")], [
        "Nobody is told the shell order. Players learn it from the counts announced at each load, the shells already fired, and their own items: the magnifying glass shows the chambered shell, the burner phone a later one. The other items change the gun or the players: the handsaw doubles the next shot's damage, beer ejects the chambered shell, the inverter flips it between live and blank, cigarettes heal one health, the jammer makes the opponent skip a turn, and adrenaline steals and uses an opponent's item.",
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["A worked turn. "]),
        "The gun holds two live shells and one blank, and your magnifying glass showed the chambered shell is blank. Shooting yourself is free: the blank keeps your turn, and the next shell is a proven live one for your opponent. Shooting the opponent instead passes the turn and hands the gun over. The How they play section counts moves like that as certain mistakes.",
      ]),
      h.p([h.Class("sub")], [
        "Each player here is a language model, apart from the two search engines. On its turn it receives its view as JSON — both players' health and items, the shotgun, the log entries it has not been sent yet, and its numbered legal moves — and answers with one move number. Each log entry reaches it once, so it must remember the earlier ones. It sees the public log plus its own secrets, never the true shell order or the other player's secrets. A config is one model at one effort setting; the effort (none to max) is how much thinking the provider allows per move, and more of it costs more. The chips at the top switch models and efforts off and on.",
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
        `Every match is two players with items. A seed fixes the deals, and a seed block is one seed a pairing plays in both seat orders, so neither side gains from sitting first. ${unpaired.toLocaleString()} of the ${blocks.toLocaleString()} seed blocks hold only one scored match, so their seat order is not balanced. All tournaments are pooled. Every model plays under the same shared instructions with the same tools`,
        ...(promptedOff.length === 0
          ? ["."]
          : [`, except ${promptedOff.join(", ")}: its API has no reasoning-off setting, so it plays at low effort with one added line telling it to answer at once, without planning or checking ("immediate-recall mode").`]),
        " The models were reached through subscription accounts via a proxy, not first-party API keys.",
        ...(isOnline ? [] : [" The Matches section lists every match."]),
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["Search engines. "]),
        "The configs named Search engine are the arena's own minimax search, not language models. Depth is how many decisions ahead it looks; with sampled reloads it values a new load by sampling the possible deals. They cost nothing, so the charts draw them as reference lines.",
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["Round Elo. "]),
        "One Bradley-Terry rating fitted over every scored match, counting each round as one game. The depth-2 search engine (Engine/2/20000) is fixed at 0, so a new config does not move the others. The bracket beside a rating is a 95% bootstrap over seed blocks, so it carries the luck a whole seed shares.",
      ]),
      ...(hasLuck
        ? [
            h.p([h.Class("sub")], [
              h.b([], ["Luck-adjusted Elo. "]),
              "The same fit with each round's luck — the shots, loads and first seat — corrected out (AIVAT), estimating the same strengths with less noise. It is the headline rating: it ranks the leaderboard and the results summary.",
            ]),
          ]
        : []),
      h.p([h.Class("sub")], [
        h.b([], ["What to keep in mind. "]),
        "Configs are grouped in tiers. Down the ranking, a new tier starts at the first config clearly below the top of the current one: the 95% bootstrap interval of the gap between the two excludes 0. Within a tier the order is not settled. Provisional configs (fewer than 20 scored matches) have no tier. Points lost and accuracy are measured against a minimax player, not against perfect play; certain mistakes need no such player. Costs are the providers' list prices applied to the usage, not what anyone was billed.",
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
