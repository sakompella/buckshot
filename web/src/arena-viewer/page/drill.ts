import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import type { ConfigItems } from "../aggregates.ts";
import { fmtCount, fmtPct, keyOf, MIN_BLOCKS_FOR_INTERVAL } from "./data.ts";
import type { ModelStats } from "./derived.ts";
import { itemBarsView } from "./fates.ts";
import type { Lazy, Message } from "./model.ts";

type H = HtmlBuilder<Message>;

const GAP_NAMES = ["behind 2+", "behind 1", "level", "ahead 1", "ahead 2+"];

const MIN_MOVES = 30;

const lineView = (h: H, label: string, content: ReadonlyArray<Html | string>): Html => h.div([h.Class("dline")], [h.span([h.Class("dl")], [label]), ...content]);

const gapLineView = (h: H, tokensByGap: ConfigItems["tokensByGap"]): Html =>
  lineView(
    h,
    "Output tokens per move by health gap",
    tokensByGap.map(({ moves, tokens }, index) =>
      h.span([h.Class("dv"), ...(moves < MIN_MOVES ? [] : [h.Title(`${moves.toLocaleString()} moves`)])], [h.span([h.Class("k")], [`${GAP_NAMES[index] ?? ""} `]), moves < MIN_MOVES ? "–" : fmtCount(tokens)]),
    ),
  );

const consistencyLineView = (h: H, consistency: Lazy["consistency"], key: string, hasInterval: boolean): Html =>
  AsyncData.matchData(consistency, {
    onEmpty: () => h.empty,
    onFailure: (error) => lineView(h, "Same position, same move", [h.span([h.Class("dv")], [`Could not load the consistency: ${error}`])]),
    onData: (rows) => {
      if (rows.length === 0) return h.empty;

      const row = rows.find((candidate) => keyOf(candidate) === key);

      return lineView(
        h,
        "Same position, same move",
        row === undefined
          ? ["–"]
          : [h.span([h.Class("dv")], [fmtPct(row.agree), " ", h.span([h.Class("pm")], [`${hasInterval ? `[${fmtPct(row.lo)}, ${fmtPct(row.hi)}] ` : ""}over ${row.positions.toLocaleString()} positions`])])],
      );
    },
  });

/** A config's drill-down: its consistency, output tokens and items, each once its file has loaded. */
export const drillView = (h: H, m: ModelStats, lazy: Lazy): Html =>
  h.div(
    [h.Class("drillin")],
    [
      consistencyLineView(h, lazy.consistency, m.key, m.win.blocks >= MIN_BLOCKS_FOR_INTERVAL),
      ...AsyncData.matchData(lazy.items, {
        onEmpty: () => [],
        onFailure: (error) => [h.p([h.Class("k")], [`Could not load the items: ${error}`])],
        onData: (items) => {
          const own = items.find(({ config }) => config === m.key);

          return [...(own === undefined ? [] : [gapLineView(h, own.tokensByGap)]), h.div([h.Class("dhead")], ["Items"]), itemBarsView(h, own, m.color, m.key)];
        },
      }),
    ],
  );
