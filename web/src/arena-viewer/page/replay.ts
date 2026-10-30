import { Effect, Option } from "effect";
import { AsyncData, Mount } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import type { Call, MatchDetail, MoveRegret, Step } from "../api.ts";
import { linScale, pressable } from "./charts.ts";
import { baseName, colorOf, fmtCount, fmtPoints, fmtSec, fmtPct, fmtTime, fmtUsd, keyOf, labelOf, type MatchRow, sumOf, unique } from "./data.ts";
import { type MatchData, Message, type Replay, type Viewport } from "./model.ts";
import { tableView } from "./table.ts";

type H = HtmlBuilder<Message>;

export const stepsOf = (detail: MatchDetail): ReadonlyArray<Step> => detail.decisions.filter(({ byWhom }) => byWhom !== "forced");

export const shotOf = (step: Step): "live" | "blank" | null => {
  const shot = / shot [^:]*: (live|blank)/.exec(step.outcome.join(" "));

  if (shot === null) return null;

  return shot[1] === "live" ? "live" : "blank";
};

export const seatColor = (detail: MatchDetail, player: string): string => {
  const seat = detail.seats.find((candidate) => candidate.player === player);

  return seat === undefined ? "#999" : colorOf(seat.model);
};

/** A compact strip of one match: a tick per model move, tall for a live shot, short for a blank, a dot for anything else. */
export const moveStripView = (h: H, detail: MatchDetail, width: number, height = 26): Html => {
  const steps = stepsOf(detail);
  const x = (index: number) => 2 + (index / Math.max(1, steps.length - 1)) * (width - 4);

  return h.div(
    [],
    [
      h.svg(
        [h.Width(`${width}`), h.Height(`${height}`)],
        [
          ...steps.flatMap((step, index) =>
            index > 0 && step.round !== steps[index - 1]?.round ? [h.line([h.X1(`${x(index - 0.5)}`), h.X2(`${x(index - 0.5)}`), h.Y1("0"), h.Y2(`${height}`), h.Stroke("#333")], [])] : [],
          ),
          ...steps.map((step, index) => {
            const shot = shotOf(step);
            const color = seatColor(detail, step.player);

            if (shot === null) return h.circle([h.Cx(`${x(index)}`), h.Cy(`${height - 4}`), h.R("1.3"), h.Fill(color), h.Opacity("0.6")], []);

            const tall = shot === "live" ? height - 4 : (height - 4) / 2.6;

            return h.rect([h.X(`${x(index) - 1}`), h.Y(`${height - 2 - tall}`), h.Width("2"), h.Height(`${tall}`), h.Fill(color)], []);
          }),
        ],
      ),
    ],
  );
};

/** Regret in points from which a move stands out as a blunder, in its tag and on the health chart. */
const BIG_REGRET = 5;

/** Regret in points below which the move list leaves a move untagged, so the tags mark the few real mistakes. */
const MINOR_REGRET = 2;

const TURNING_POINTS = 3;

export const turningPoints = (steps: ReadonlyArray<{ readonly regret: { readonly points: number } | null }>, count = TURNING_POINTS): ReadonlyArray<number> =>
  steps
    .flatMap((step, index) => (step.regret !== null && step.regret.points >= BIG_REGRET ? [{ index, points: step.regret.points }] : []))
    .toSorted((a, b) => b.points - a.points || a.index - b.index)
    .slice(0, count)
    .map(({ index }) => index);

/** The move a replay shows: the one chosen, else the first model move at or after the focus. */
export const replayIndex = (replay: Replay, steps: ReadonlyArray<Step>): number =>
  Option.getOrElse(replay.maybeAt, () =>
    Math.max(
      0,
      Option.match(replay.maybeFocus, { onNone: () => 0, onSome: (focus) => steps.findIndex(({ ordinal }) => ordinal >= focus) }),
    ),
  );

const resultOf = (detail: MatchDetail): string => {
  const winner = detail.seats.find(({ winShare }) => (winShare ?? 0) >= 1);

  if (detail.match.status !== "completed") return "unscored";

  return winner === undefined ? "split" : `${labelOf(keyOf(winner))} wins`;
};

const shortNamesOf = (detail: MatchDetail): ReadonlyMap<string, string> => {
  const bases = detail.seats.map(({ model }) => baseName(model));

  return new Map(detail.seats.map((seat, index) => [seat.player, bases.indexOf(bases[index] ?? "") === bases.lastIndexOf(bases[index] ?? "") ? (bases[index] ?? seat.player) : labelOf(keyOf(seat))]));
};

/** The health chart's width, as styles.css lays out .modal and .mbody: one full-screen column up to a tablet, else half the modal. */
const chartWidth = ({ width }: Viewport): number => {
  if (width < 640) return width - 24;

  return width <= 1024 ? width - 2 * 16 : Math.floor((Math.min(1320, 0.96 * width) - 2 * 22 - 2 - 22) / 2);
};

const healthView = (h: H, detail: MatchDetail, steps: ReadonlyArray<Step>, at: number, width: number): Html => {
  const height = width < 500 ? 110 : 140;
  const [left, right, top, bottom] = [26, 18, 10, 22];
  const most = Math.max(1, ...steps.flatMap(({ players }) => players.map(({ health }) => health)));
  const x = linScale(0, Math.max(1, steps.length - 1), left, width - right, []);
  const y = linScale(0, most, height - bottom, top, Array.from({ length: most + 1 }, (_tick, index) => index));
  const isRoundStart = (index: number) => index > 0 && steps[index]?.round !== steps[index - 1]?.round;

  const lines = detail.seats.map(({ player }, index) => {
    const ys = steps.map((step) => y.at(step.players.find((seen) => seen.player === player)?.health ?? 0) + (index > 0 ? 1.5 : -1.5));
    const color = seatColor(detail, player);

    return h.g(
      [],
      [
        h.path(
          [
            h.D(ys.map((value, step) => (step > 0 ? `H${x.at(step)}V${value}` : `M${x.at(step)},${value}`)).join("")),
            h.Fill("none"),
            h.Stroke(color),
            h.StrokeWidth("2"),
            ...(index > 0 ? [h.StrokeDasharray("5 3")] : []),
          ],
          [],
        ),
        h.text([h.X(String(width - right + 3)), h.Y(String((ys.at(-1) ?? 0) + (index > 0 ? 11 : -3))), h.Class("small"), h.Style({ fill: color })], [player]),
      ],
    );
  });

  const turning = turningPoints(steps);

  const blunders = steps.flatMap((step, index) => {
    if (step.regret === null || step.regret.points < BIG_REGRET) return [];

    const color = seatColor(detail, step.player);
    const seat = detail.seats.findIndex(({ player }) => player === step.player);
    const mine = step.players.find(({ player }) => player === step.player)?.health ?? 0;
    const radius = 4 + Math.min(step.regret.points, 50) / 10;

    return [
      h.circle(
        [h.Cx(String(x.at(index))), h.Cy(String(y.at(mine) + (seat > 0 ? 1.5 : -1.5))), h.R(String(radius)), h.Stroke(color), h.StrokeWidth("1.5"), h.Fill(turning.includes(index) ? color : "#000"), h.FillOpacity(turning.includes(index) ? "0.85" : "0.6")],
        [h.title([], [`${step.player}: ${step.label} · gave up ${fmtPoints(step.regret.points)} points`])],
      ),
    ];
  });

  const targets = steps.map((_step, index) => {
    const from = index === 0 ? 0 : x.at(index - 0.5);
    const to = index === steps.length - 1 ? width : x.at(index + 0.5);

    return h.rect([h.X(String(from)), h.Y("0"), h.Width(String(to - from)), h.Height(String(height)), h.Fill("transparent"), h.OnClick(Message.SelectedStep({ index }))], []);
  });

  return h.div(
    [h.Class("chart")],
    [
      h.svg(
        [h.Width(String(width)), h.Height(String(height)), h.Style({ cursor: "pointer" })],
        [
          ...y.ticks.map((tick) =>
            h.g(
              [],
              [
                h.line([h.Class("grid"), h.X1(String(left)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick)))], []),
                h.text([h.X(String(left - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [`${tick}`]),
              ],
            ),
          ),
          ...steps.flatMap((_step, index) =>
            isRoundStart(index)
              ? [h.line([h.X1(String(x.at(index - 0.5))), h.X2(String(x.at(index - 0.5))), h.Y1(String(top)), h.Y2(String(height - bottom)), h.Stroke("#333"), h.StrokeDasharray("2 3")], [])]
              : [],
          ),
          ...unique(steps.map(({ round }) => round)).map((round) =>
            h.text([h.X(String(x.at(steps.findIndex((step) => step.round === round)) + 3)), h.Y(String(height - 6)), h.Class("small")], [`R${round}`]),
          ),
          ...lines,
          ...blunders,
          h.line([h.X1(String(x.at(at))), h.X2(String(x.at(at))), h.Y1(String(top)), h.Y2(String(height - bottom)), h.Stroke("#ececec"), h.StrokeOpacity("0.8")], []),
          ...targets,
        ],
      ),
    ],
  );
};

const turningPointsView = (h: H, detail: MatchDetail, names: ReadonlyMap<string, string>, steps: ReadonlyArray<Step>, at: number): Html => {
  const turning = turningPoints(steps);

  if (turning.length === 0) return h.empty;

  return h.div(
    [h.Class("turning")],
    [
      h.span([h.Class("k")], ["Turning points"]),
      h.div(
        [h.Class("chips")],
        turning.flatMap((index) => {
          const step = steps[index];

          return step?.regret === undefined || step.regret === null
            ? []
            : [
                h.button(
                  [
                    h.Type("button"),
                    h.Class(`chip ${index === at ? "on" : ""}`),
                    h.Style({ color: seatColor(detail, step.player), "border-color": index === at ? seatColor(detail, step.player) : "" }),
                    h.OnClick(Message.SelectedStep({ index })),
                  ],
                  [`R${step.round} ${names.get(step.player) ?? step.player} · ${step.label} · −${fmtPoints(step.regret.points)}`],
                ),
              ];
        }),
      ),
    ],
  );
};

const nameView = (h: H, detail: MatchDetail, names: ReadonlyMap<string, string>, player: string): Html =>
  h.b([h.Class("who"), h.Style({ color: seatColor(detail, player) })], [names.get(player) ?? player]);

/** The table just before the chosen move, as its mover saw it; what the move did is the selected view's. */
const boardView = (h: H, detail: MatchDetail, steps: ReadonlyArray<Step>, step: Step, names: ReadonlyMap<string, string>): Html => {
  const most = Math.max(1, ...steps.filter(({ round }) => round === step.round).flatMap(({ players }) => players.map(({ health }) => health)));

  return tableView(h, {
    seats: detail.seats.map((seat) => {
      const seen = step.players.find(({ player }) => player === seat.player);

      return { letter: seat.player, name: names.get(seat.player) ?? seat.player, color: colorOf(seat.model), health: seen?.health ?? 0, items: seen?.items ?? [], isActing: seat.player === step.player };
    }),
    maxHealth: most,
    live: step.live,
    blank: step.blank,
    known: step.known,
    viewer: names.get(step.player) ?? step.player,
    action: h.div([h.Class("action")], [nameView(h, detail, names, step.player), " chose ", h.span([], [step.label])]),
  });
};

const scrollListToRow = (list: Element, row: Element): void => {
  const [rowBox, listBox] = [row.getBoundingClientRect(), list.getBoundingClientRect()];
  const header = list.querySelector(".roundh")?.getBoundingClientRect().height ?? 0;

  if (rowBox.top < listBox.top + header) list.scrollTop -= listBox.top + header - rowBox.top;
  else if (rowBox.bottom > listBox.bottom) list.scrollTop += rowBox.bottom - listBox.bottom;
};

const ScrollStepIntoView = Mount.define("ScrollStepIntoView", {
  messages: [Message.CompletedStepScroll],
  execute: ({ element }) =>
    Effect.sync(() => {
      const list = element.closest(".moves");
      const chosen = element.closest(".step");

      if (list !== null && chosen !== null) scrollListToRow(list, chosen);

      return Message.CompletedStepScroll();
    }),
});

const callView = (h: H, call: Call): Html => {
  const reasoning = call.reasoning === "" ? (call.rt ? h.div([h.Class("k")], ["reasoning hidden by the provider"]) : h.empty) : h.pre([], [call.reasoning]);
  const tokens = call.rt ? ` (${fmtCount(call.rt)} reasoning)` : "";

  return h.div(
    [],
    [
      h.div([h.Class("k")], [`${call.status}${call.error === null ? "" : ` · ${call.error}`} · ${fmtSec(call.latency)} · ${fmtCount(call.outp)} out${tokens} · ${fmtUsd(call.cost)}`]),
      reasoning,
      call.response === "" ? h.empty : h.pre([h.Class("reply")], [call.response]),
    ],
  );
};

const PHONE_WIDTH = 640;

const verdictOf = (regret: MoveRegret): string => {
  if (regret.points === 0) return `Best at depth ${regret.depth}`;

  return regret.exact ? `Proven worse · gave up ${fmtPoints(regret.points)} points` : `Gave up ${fmtPoints(regret.points)} points (estimate)`;
};

const candidatesView = (h: H, step: Step, regret: MoveRegret, who: string, isOpen: boolean): Html =>
  h.details(
    [h.Class("fold cands"), ...(isOpen ? [h.Open(true)] : [])],
    [
      h.summary([], [verdictOf(regret)]),
      h.div([h.Class("k")], [`${who}'s estimated round win chance · depth ${regret.depth}${regret.limited ? " · budget stopped" : ""}`]),
      h.ol(
        [],
        regret.values
          .toSorted((left, right) => right.score - left.score)
          .map(({ label, score }) => {
            const isChosen = label === regret.chosen;
            const isBest = score === regret.bestScore;

            return h.li(
              [h.Class(`cand ${isChosen ? "chosen" : ""} ${isBest ? "best" : ""}`)],
              [
                h.span([h.Class("label")], [label]),
                isBest ? h.span([h.Class("tag")], ["best"]) : h.empty,
                isChosen ? h.span([h.Class("tag")], ["chosen"]) : h.empty,
                h.span([h.Class("pct")], [`${fmtPoints(score)}%`]),
              ],
            );
          }),
      ),
      step.live + step.blank <= regret.depth ? h.div([h.Class("k")], ["A reload is within reach. With the static leaf, gaps at 1–3 shells left read about 0.6 points high on average."]) : h.empty,
    ],
  );

const selectedView = (h: H, detail: MatchDetail, step: Step, names: ReadonlyMap<string, string>, viewport: Viewport): Html => {
  const { regret } = step;
  const shot = shotOf(step);
  const latency = sumOf(step.calls.map(({ latency }) => latency ?? 0));
  const cost = sumOf(step.calls.map((call) => call.cost ?? 0));

  return h.div(
    [h.Class("sel")],
    [
      h.div(
        [h.Class("selh")],
        [
          nameView(h, detail, names, step.player),
          h.span([], [step.label]),
          step.byWhom === "agent" ? h.empty : h.span([h.Class("tag")], [step.byWhom]),
          shot === null ? h.empty : h.span([h.Class(`shot ${shot}`)], [shot]),
          regret === null || regret.points < MINOR_REGRET ? h.empty : h.span([h.Class(`tag regret ${regret.points >= BIG_REGRET ? "big" : ""}`)], [`−${fmtPoints(regret.points)}`]),
        ],
      ),
      step.outcome.length > 0 ? h.div([h.Class("outcome")], [h.span([h.Class("k")], ["Outcome: "]), step.outcome.join(" ")]) : h.empty,
      regret === null
        ? h.div([h.Class("k")], ["Not searched by the evaluator."])
        : candidatesView(h, step, regret, names.get(step.player) ?? step.player, viewport.width >= PHONE_WIDTH),
      step.calls.length === 0
        ? h.empty
        : h.details(
            [h.Class("fold")],
            [h.summary([], [`Model reasoning · ${step.calls.length === 1 ? "1 call" : `${step.calls.length} calls`} · ${fmtSec(latency)} · ${fmtUsd(cost)}`]), ...step.calls.map((call) => callView(h, call))],
          ),
    ],
  );
};

/** A model move's regret in the list, only from MINOR_REGRET up; a proven exact one is marked apart. */
const regretTag = (h: H, regret: MoveRegret | null): Html =>
  regret === null || regret.points < MINOR_REGRET
    ? h.empty
    : h.span(
        [h.Class(`tag regret ${regret.exact ? "exact" : ""} ${regret.points >= BIG_REGRET ? "big" : ""}`), h.Title(`gave up ${fmtPoints(regret.points)} points · ${regret.exact ? "proven exact" : "not proven exact"}`)],
        [`−${fmtPoints(regret.points)}`],
      );

const stepView = (h: H, detail: MatchDetail, names: ReadonlyMap<string, string>, step: Step, index: number, at: number): Html => {
  const isOn = index === at;
  const shot = shotOf(step);

  return h.keyed("div")(
    step.id,
    [h.Class(`step ${isOn ? "on" : ""}`), ...(isOn ? [h.AriaCurrent("step")] : []), ...pressable(h, Message.SelectedStep({ index }))],
    [
      h.span([h.Class("n")], [isOn ? h.keyed("span")(`${step.id}-on`, [h.OnMount(ScrollStepIntoView())], []) : h.empty, `${index + 1}`]),
      nameView(h, detail, names, step.player),
      h.span([h.Class("label"), h.Title(step.label)], [step.label, step.byWhom === "agent" ? h.empty : h.span([h.Class("tag")], [step.byWhom])]),
      shot === null ? h.empty : h.span([h.Class(`shot ${shot}`)], [shot]),
      regretTag(h, step.regret),
    ],
  );
};

const movesView = (h: H, detail: MatchDetail, names: ReadonlyMap<string, string>, steps: ReadonlyArray<Step>, at: number): Html =>
  h.div(
    [h.Class("moves"), h.AriaLabel("Moves")],
    unique(steps.map(({ round }) => round)).flatMap((round) => {
      const result = detail.story.rounds[round - 1];

      return [
        h.div(
          [h.Class("roundh")],
          [
            h.span([], [`Round ${round}`]),
            result === undefined ? h.empty : h.span([h.Class("k")], [nameView(h, detail, names, result.winner), ` won +$${result.prize.toLocaleString()}`]),
          ],
        ),
        ...steps.flatMap((step, index) => (step.round === round ? [stepView(h, detail, names, step, index, at)] : [])),
      ];
    }),
  );

/** The other matches on this seed and code hash where one of this match's configs held the same table position. */
const sameSeedView = (h: H, detail: MatchDetail, allMatches: ReadonlyArray<MatchRow>): Html => {
  const self = allMatches.find(({ matchId }) => matchId === detail.match.id);

  if (self === undefined || self.seats.length !== 2) return h.empty;

  const code = self.seats[0]?.codeHash;

  const groups = self.seats.flatMap((fixed) => {
    const chips = allMatches.flatMap((match) => {
      const other = match.seats.find(({ position }) => position !== fixed.position);

      const isSibling =
        match.matchId !== self.matchId &&
        match.seed === self.seed &&
        match.seats.length === 2 &&
        match.seats[0]?.codeHash === code &&
        match.seats.some((seat) => seat.position === fixed.position && keyOf(seat) === keyOf(fixed));

      return isSibling && other !== undefined ? [{ match, other }] : [];
    });

    return chips.length === 0 ? [] : [{ fixed, chips }];
  });

  if (groups.length === 0) return h.empty;

  const count = sumOf(groups.map(({ chips }) => chips.length));

  return h.details(
    [h.Class("fold seeds")],
    [
      h.summary([], [`Same seed · ${count === 1 ? "1 other match" : `${count} other matches`}`]),
      h.div(
        [h.Class("seedrow")],
        groups.map(({ fixed, chips }) =>
          h.div(
            [h.Class("seedgroup")],
            [
              h.span([h.Class("k")], [`vs ${labelOf(keyOf(fixed))}:`]),
              h.div(
                [h.Class("chips")],
                chips.map(({ match, other }) => {
                  const share = other.winShare ?? 0;
                  const color = colorOf(other.model);
                  const isScored = match.status === "completed";
                  const mark = !isScored ? "·" : share >= 1 ? "W" : share > 0 ? "½" : "L";

                  return h.button(
                    [
                      h.Type("button"),
                      h.Class("chip on"),
                      h.Title(isScored ? `${fmtPct(share)} win share` : "unscored"),
                      h.Style(share >= 1 ? { color, "border-color": color } : { color }),
                      h.OnClick(Message.ClickedMatch({ id: match.matchId, maybeFocus: Option.none() })),
                    ],
                    [`${labelOf(keyOf(other))} ${mark}`],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ],
  );
};

const detailView = (h: H, replay: Replay, detail: MatchDetail, allMatches: ReadonlyArray<MatchRow>, viewport: Viewport): ReadonlyArray<Html> => {
  const steps = stepsOf(detail);
  const at = replayIndex(replay, steps);
  const step = steps[at];
  const names = shortNamesOf(detail);
  const cost = sumOf(detail.decisions.flatMap(({ calls }) => calls.map((call) => call.cost ?? 0)));

  return [
    h.div(
      [h.Class("mhead"), h.DataAttribute("match", detail.match.id)],
      [
        h.h2(
          [],
          detail.seats.map((seat, index) =>
            h.span([], [index > 0 ? " vs " : h.empty, h.span([h.Style({ color: colorOf(seat.model) })], [labelOf(keyOf(seat))]), h.span([h.Class("letter")], [seat.player])]),
          ),
        ),
        h.span(
          [h.Class("k")],
          [`seed ${detail.match.seed} · ${fmtTime(detail.match.startedAt)} · ${steps.length} moves · ${fmtUsd(cost)} · `, h.b([h.Class("res")], [resultOf(detail)])],
        ),
      ],
    ),
    sameSeedView(h, detail, allMatches),
    h.div(
      [h.Class("mbody")],
      [
        h.div(
          [h.Class("mleft")],
          [
            h.div(
              [h.Class("stepper")],
              [
                h.button([h.Type("button"), h.AriaLabel("Previous move"), h.Disabled(at === 0), h.OnClick(Message.SteppedReplay({ delta: -1 }))], ["‹ Prev"]),
                h.span([h.Class("k")], [step === undefined ? "" : `move ${at + 1} of ${steps.length} · round ${step.round}`]),
                h.button([h.Type("button"), h.AriaLabel("Next move"), h.Disabled(at >= steps.length - 1), h.OnClick(Message.SteppedReplay({ delta: 1 }))], ["Next ›"]),
              ],
            ),
            ...(step === undefined ? [] : [boardView(h, detail, steps, step, names), selectedView(h, detail, step, names, viewport)]),
          ],
        ),
        h.div(
          [h.Class("mright")],
          [
            h.div(
              [h.Class("timeline")],
              [
                healthView(h, detail, steps, at, chartWidth(viewport)),
                turningPointsView(h, detail, names, steps, at),
                h.div(
                  [h.Class("rounds")],
                  detail.story.rounds.map((round, index) => h.span([], [`R${index + 1} `, nameView(h, detail, names, round.winner), ` +$${round.prize.toLocaleString()}`])),
                ),
              ],
            ),
            h.div([h.Class("k legend")], [`−N: points of round win chance the move gave up, marked from ${fmtPoints(MINOR_REGRET)}; outlined when proven exact.`]),
            movesView(h, detail, names, steps, at),
          ],
        ),
      ],
    ),
  ];
};

/** The replay modal over the page. A click outside the modal, the ✕, Escape or the back gesture closes it. */
export const replayView = (h: H, replay: Replay, data: MatchData | undefined, allMatches: ReadonlyArray<MatchRow>, viewport: Viewport): Html => {
  const body =
    data === undefined
      ? [h.p([h.Class("k")], ["Loading match…"])]
      : AsyncData.matchData(data, {
          onEmpty: () => [h.p([h.Class("k")], ["Loading match…"])],
          onFailure: () => [h.p([], ["Could not load the match."])],
          onData: (detail) => detailView(h, replay, detail, allMatches, viewport),
        });

  return h.div(
    [h.Class("overlay")],
    [
      h.div([h.Class("backdrop"), h.OnClick(Message.ClosedReplay())], []),
      h.div([h.Class("modal"), h.Role("dialog"), h.AriaModal(true), h.AriaLabel("Match replay")], [h.button([h.Type("button"), h.Class("x"), h.AriaLabel("Close"), h.OnClick(Message.ClosedReplay())], ["✕"]), ...body]),
    ],
  );
};
