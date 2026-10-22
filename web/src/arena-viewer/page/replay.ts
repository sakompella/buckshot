import { Effect, Option } from "effect";
import { AsyncData, Mount } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import type { Call, MatchDetail, Step } from "../api.ts";
import { linScale } from "./charts.ts";
import { itemIconOf } from "./items.ts";
import { colorOf, fmtCount, fmtSec, fmtPct, fmtTime, fmtUsd, keyOf, labelOf, type MatchRow, sumOf, unique } from "./data.ts";
import { type MatchData, Message, type Replay, type Viewport } from "./model.ts";

type H = HtmlBuilder<Message>;

// The replay: health through the match, the state at the chosen move, and every model move with its reasoning.

/** The model moves a replay steps through: forced moves are left out. */
export const stepsOf = (detail: MatchDetail): ReadonlyArray<Step> => detail.decisions.filter(({ byWhom }) => byWhom !== "forced");

/** The shell a move fired, if it was a shot. */
export const shotOf = (step: Step): "live" | "blank" | null => {
  const shot = / shot [^:]*: (live|blank)/.exec(step.outcome.join(" "));

  if (shot === null) return null;

  return shot[1] === "live" ? "live" : "blank";
};

export const seatColor = (detail: MatchDetail, player: string): string => {
  const seat = detail.seats.find((candidate) => candidate.player === player);

  return seat === undefined ? "#999" : colorOf(seat.model, seat.effort);
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

/** The replay's left column, as styles.css lays out .modal and .mbody: full width on a phone, else half the modal. */
const chartWidth = ({ width }: Viewport): number => (width < 640 ? width - 24 : Math.floor((Math.min(1320, 0.96 * width) - 2 * 22 - 2 - 22) / 2));

const healthView = (h: H, detail: MatchDetail, steps: ReadonlyArray<Step>, at: number, width: number): Html => {
  const height = width < 500 ? 130 : 170;
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

  // One click target per move, so a click anywhere on the chart picks the nearest move.
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
          h.line([h.X1(String(x.at(at))), h.X2(String(x.at(at))), h.Y1(String(top)), h.Y2(String(height - bottom)), h.Stroke("#ececec"), h.StrokeOpacity("0.8")], []),
          ...targets,
        ],
      ),
    ],
  );
};

const stateView = (h: H, detail: MatchDetail, steps: ReadonlyArray<Step>, step: Step): Html => {
  const most = Math.max(1, ...steps.filter(({ round }) => round === step.round).flatMap(({ players }) => players.map(({ health }) => health)));

  return h.div(
    [h.Class("state")],
    [
      ...detail.seats.map((seat) => {
        const seen = step.players.find(({ player }) => player === seat.player);
        const health = seen?.health ?? 0;
        const color = colorOf(seat.model, seat.effort);

        return h.div(
          [h.Class(step.player === seat.player ? "on" : ""), h.Style({ "border-color": color })],
          [
            h.b([h.Style({ color })], [seat.player]),
            " ",
            h.span([h.Class("k")], [labelOf(keyOf(seat))]),
            h.div([h.Class("hp")], Array.from({ length: most }, (_bolt, index) => h.i(index < health ? [h.Class("full"), h.Style({ background: color })] : [], []))),
            h.div([h.Class("items")], (seen?.items ?? []).map((item) => h.span([h.Class("tag")], [itemIconOf(h, item), item]))),
          ],
        );
      }),
      h.div(
        [h.Class("shells")],
        [
          h.span([h.Class("k")], [`shells ${step.player}'s view`]),
          h.div([], [...Array.from({ length: step.live }, () => h.i([h.Class("live")], [])), ...Array.from({ length: step.blank }, () => h.i([], []))]),
          h.span([h.Class("k")], [`${step.live} live · ${step.blank} blank${step.known === null ? "" : ` · chamber ${step.known}`}`]),
        ],
      ),
    ],
  );
};

// The open move's detail is new each time the move changes, so mounting it is when to bring it into view.
const ScrollStepIntoView = Mount.define("ScrollStepIntoView", {
  messages: [Message.CompletedStepScroll],
  execute: ({ element }) =>
    Effect.sync(() => {
      element.closest(".step")?.scrollIntoView({ block: "nearest" });

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

const stepDetailView = (h: H, step: Step): Html =>
  h.keyed("div")(
    `detail-${step.id}`,
    [h.Class("sd"), h.OnMount(ScrollStepIntoView())],
    [...(step.outcome.length > 0 ? [h.div([h.Class("k")], [step.outcome.join(" ")])] : []), ...step.calls.map((call) => callView(h, call))],
  );

const stepView = (h: H, detail: MatchDetail, step: Step, index: number, at: number): Html =>
  h.keyed("div")(
    step.id,
    [h.Class(`step ${index === at ? "on" : ""}`), h.OnClick(Message.SelectedStep({ index }))],
    [
      h.div(
        [h.Class("h")],
        [
          h.span([h.Class("k")], [`R${step.round}`]),
          h.b([h.Style({ color: seatColor(detail, step.player) })], [step.player]),
          h.span([], [step.label]),
          step.byWhom === "agent" ? h.empty : h.span([h.Class("tag")], [step.byWhom]),
          h.span([h.Class("k right")], [step.outcome.find((line) => / shot /.test(line))?.replace(/^.*?: /, "") ?? ""]),
        ],
      ),
      index === at ? stepDetailView(h, step) : h.empty,
    ],
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

  return h.div(
    [h.Class("seedrow")],
    groups.map(({ fixed, chips }) =>
      h.div(
        [h.Class("chips")],
        [
          h.span([h.Class("k")], [`seed ${detail.match.seed} vs ${labelOf(keyOf(fixed))}:`]),
          ...chips.map(({ match, other }) => {
            const share = other.winShare ?? 0;
            const color = colorOf(other.model, other.effort);
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
        ],
      ),
    ),
  );
};

const detailView = (h: H, replay: Replay, detail: MatchDetail, allMatches: ReadonlyArray<MatchRow>, viewport: Viewport): ReadonlyArray<Html> => {
  const steps = stepsOf(detail);
  const at = replayIndex(replay, steps);
  const step = steps[at];
  const cost = sumOf(detail.decisions.flatMap(({ calls }) => calls.map((call) => call.cost ?? 0)));

  return [
    h.div(
      [h.Class("mhead")],
      [
        h.h2(
          [],
          detail.seats.map((seat, index) => h.span([], [index > 0 ? " vs " : h.empty, h.span([h.Style({ color: colorOf(seat.model, seat.effort) })], [labelOf(keyOf(seat))])])),
        ),
        h.span(
          [h.Class("k")],
          [`${detail.match.tournament} · seed ${detail.match.seed} · ${fmtTime(detail.match.startedAt)} · ${steps.length} moves · ${fmtUsd(cost)} · `, h.b([h.Class("res")], [resultOf(detail)])],
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
            healthView(h, detail, steps, at, chartWidth(viewport)),
            h.div(
              [h.Class("rounds")],
              detail.story.rounds.map((round, index) =>
                h.span([], [`R${index + 1} `, h.b([h.Style({ color: seatColor(detail, round.winner) })], [round.winner]), ` +$${round.prize.toLocaleString()}`]),
              ),
            ),
            step === undefined ? h.empty : stateView(h, detail, steps, step),
            h.div(
              [h.Class("stepper")],
              [
                h.button([h.Type("button"), h.Disabled(at === 0), h.OnClick(Message.SteppedReplay({ delta: -1 }))], ["‹ Prev"]),
                h.span([h.Class("k")], [`move ${at + 1} of ${steps.length}`]),
                h.button([h.Type("button"), h.Disabled(at >= steps.length - 1), h.OnClick(Message.SteppedReplay({ delta: 1 }))], ["Next ›"]),
              ],
            ),
          ],
        ),
        h.div(
          [h.Class("mright")],
          steps.map((each, index) => stepView(h, detail, each, index, at)),
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
      h.div([h.Class("modal")], [h.button([h.Type("button"), h.Class("x"), h.AriaLabel("Close"), h.OnClick(Message.ClosedReplay())], ["✕"]), ...body]),
    ],
  );
};
