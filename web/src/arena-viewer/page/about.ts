import type { Html, HtmlBuilder } from "foldkit/html";

import { isOnline } from "../../site/online.ts";
import type { Runs } from "../aggregates.ts";
import { colorOf, fmtRating, isClaude } from "./data.ts";
import type { Derived, ModelStats } from "./derived.ts";
import { inRankOrder } from "./leaderboard.ts";
import { Message } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// The page's reader-facing text: the results summary at the top, the game explained before the charts,
// and the method under About. Numbers come from the aggregates; the rules come from the shared instructions.

const DAY = new Intl.DateTimeFormat("en-US", { timeZone: "UTC", month: "short", day: "numeric", year: "numeric" });

/** "Oct 15 – Nov 9, 2026", or the one day when both ends are the same. */
const runDates = (runs: Runs): string => (runs.from === runs.to ? DAY.format(new Date(runs.from)) : `${DAY.format(new Date(runs.from))} – ${DAY.format(new Date(runs.to))}`);

/** How many configs the results summary lists. */
const SUMMARY_ROWS = 3;

/** A config's rating as the summary needs it. */
export interface Leader {
  readonly label: string;
  readonly rating: number;
  readonly interval: { readonly lo: number; readonly hi: number } | null;
}

const leaderOf = ({ label }: ModelStats, elo: Rating | undefined): Leader => ({ label, rating: elo?.rating ?? 0, interval: elo?.interval ?? null });

/** The note when the top two's intervals overlap: the order between them is not settled. */
export const tooCloseNote = (first: Leader | undefined, second: Leader | undefined): string | null => {
  if (first === undefined || second === undefined || first.interval === null || second.interval === null) return null;

  return first.interval.lo <= second.interval.hi && second.interval.lo <= first.interval.hi ? `Too close to call at the top: the intervals of ${first.label} and ${second.label} overlap, so the order between them is not settled.` : null;
};

const leaderLine = (h: H, m: ModelStats, rank: number | undefined, elo: Rating | undefined): Html =>
  h.li(
    [],
    [
      h.span([h.Class("rk")], [rank === undefined ? "" : String(rank)]),
      h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: colorOf(m.model) })], []),
      h.span([h.Class("lp")], [m.label]),
      h.b([], [fmtRating(elo?.rating ?? 0)]),
      ...(elo?.interval === undefined || elo?.interval === null ? [] : [h.span([h.Class("pm")], [` [${Math.round(elo.interval.lo)}, ${Math.round(elo.interval.hi)}]`])]),
    ],
  );

/** The first few leaderboard rows, with the too-close-to-call note when the leaders' intervals overlap. */
export const summaryView = (h: H, derived: Derived): Html => {
  const ranked = inRankOrder(derived.pooled, derived.ranks, derived.ratings).filter(({ key }) => derived.ranks.has(key));
  const leaders = ranked.slice(0, SUMMARY_ROWS);
  const [first, second] = leaders;
  const note = tooCloseNote(first === undefined ? undefined : leaderOf(first, derived.ratings.get(first.key)), second === undefined ? undefined : leaderOf(second, derived.ratings.get(second.key)));

  return h.div(
    [],
    [
      h.h2([], ["Results at a glance"]),
      h.p([h.Class("sub")], [
        `The leading configs by Round Elo`,
        ...(derived.runs === undefined ? [] : [` from matches played ${runDates(derived.runs)}`]),
        ". Round Elo pools every match of every tournament; the bracket is its 95% interval. The full leaderboard is under Tables.",
      ]),
      leaders.length === 0 ? h.p([h.Class("k")], ["No scored matches for this filter."]) : h.ol([h.Class("toplist")], leaders.map((m) => leaderLine(h, m, derived.ranks.get(m.key), derived.ratings.get(m.key)))),
      ...(note === null ? [] : [h.p([h.Class("sub")], [h.b([], [note])])]),
    ],
  );
};

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
        "Each player here is a language model. On its turn it receives its view as JSON — both players' health and items, the shotgun, the log of every event so far, and its numbered legal moves — and answers with one move number. It sees the public log plus its own secrets, never the true shell order or the other player's secrets. A config is one model at one effort setting; the effort (none to max) is how much thinking the provider allows per move, and more of it costs more. The chips at the top switch models and efforts off and on.",
      ]),
    ],
  );

/** Run dates, conditions, the ratings, and what the comparison cannot settle. */
export const aboutView = (h: H, derived: Derived): Html => {
  const hasLuck = derived.everyPooled.some(({ luckRating }) => luckRating !== null);

  return h.div(
    [],
    [
      h.h2([], ["About this experiment"]),
      ...(derived.runs === undefined ? [] : [h.p([h.Class("sub")], [`The matches here were played ${runDates(derived.runs)} (UTC).`])]),
      h.p([h.Class("sub")], [
        "Every match is two players with items. Each pairing plays whole seed blocks — the same seed in both seat orders — so neither side gains from sitting first. All tournaments are pooled, and every model plays under the same shared instructions with the same tools.",
        ...(isOnline ? [] : [" The Matches section lists every match."]),
      ]),
      h.p([h.Class("sub")], [
        h.b([], ["Round Elo. "]),
        "One Bradley-Terry rating fitted over every scored match, counting each round as one game; the average player sits at 0. The bracket beside a rating is a 95% bootstrap over seed blocks, so it carries the luck a whole seed shares.",
      ]),
      ...(hasLuck
        ? [
            h.p([h.Class("sub")], [
              h.b([], ["Luck-adjusted Elo. "]),
              "The same fit with each round's luck — the shots, loads and first seat — corrected out (AIVAT), estimating the same strengths with less noise.",
            ]),
          ]
        : []),
      h.p([h.Class("sub")], [
        h.b([], ["What to keep in mind. "]),
        "Overlapping intervals mean the order between two configs is not settled; the results summary says so at the top. Provisional configs (fewer than 20 scored matches) have no rank. Regret and accuracy are measured against a fixed-depth minimax player, not against perfect play. Costs are the providers' list prices, not what anyone was billed.",
      ]),
    ],
  );
};
