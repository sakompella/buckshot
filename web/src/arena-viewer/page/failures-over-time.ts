import type { Html, HtmlBuilder } from "foldkit/html";

import type { Message } from "./model.ts";
import { anchorId, linScale, markTip } from "./charts.ts";
import { baseName, baseOrder, colorOf, fmtTime, groupBy, type SeatFull } from "./data.ts";

type H = HtmlBuilder<Message>;

// When calls failed: one lane per model, a bar per hour of the calls' own log times. Provider incidents show as the same
// hours failing in every lane of a family.

const HOUR_MS = 3.6e6;

/** A bar is drawn only for an hour with this many replies, so a quiet hour's one failure is not a spike. */
const MIN_CALLS = 20;

export interface HourBucket {
  /** Hours since the epoch, in UTC. */
  readonly hour: number;
  readonly calls: number;
  readonly failed: number;
}

/** Each model's replies and failed replies by the hour each was logged, hours in order. */
export const failuresByHour = (seats: ReadonlyArray<Pick<SeatFull, "model" | "callHours">>, keep: ReadonlyArray<boolean>): ReadonlyMap<string, ReadonlyArray<HourBucket>> => {
  const kept = seats.filter((_, index) => keep[index] === true);

  return new Map(
    [...groupBy(kept, ({ model }) => model)].map(([model, modelSeats]) => {
      const byHour = new Map<number, { calls: number; failed: number }>();

      for (const [hour, calls, failed] of modelSeats.flatMap(({ callHours }) => callHours)) {
        const bucket = byHour.get(hour) ?? { calls: 0, failed: 0 };

        bucket.calls += calls;
        bucket.failed += failed;
        byHour.set(hour, bucket);
      }

      return [model, [...byHour].map(([hour, { calls, failed }]) => ({ hour, calls, failed })).toSorted((left, right) => left.hour - right.hour)];
    }),
  );
};

const failedShare = ({ calls, failed }: HourBucket): number => (calls >= MIN_CALLS ? failed / calls : Number.NaN);

const PACIFIC_DAY = new Intl.DateTimeFormat("en-US", { timeZone: "America/Los_Angeles", month: "short", day: "numeric", hour: "numeric", hourCycle: "h23" });

/** The hours in [first, last] that start a Pacific day, with the day's name. */
const dayStarts = (first: number, last: number): ReadonlyArray<{ readonly hour: number; readonly name: string }> =>
  Array.from({ length: last - first + 1 }, (_, index) => first + index).flatMap((hour) => {
    const parts = PACIFIC_DAY.formatToParts(new Date(hour * HOUR_MS));
    const part = (type: string) => parts.find((piece) => piece.type === type)?.value ?? "";

    return Number(part("hour")) === 0 ? [{ hour, name: `${part("month")} ${part("day")}` }] : [];
  });

const LANE_HEIGHT = 30;

const LANE_GAP = 6;

const AXIS_HEIGHT = 22;

/**
 * Lanes for the kept models, in the models' order. The time axis and the bars' height span every seat whatever the
 * filter, so a filter only adds or removes lanes.
 */
export const failuresOverTimeView = (h: H, every: ReadonlyMap<string, ReadonlyArray<HourBucket>>, kept: ReadonlyMap<string, ReadonlyArray<HourBucket>>, width: number): Html => {
  const hours = [...every.values()].flat().map(({ hour }) => hour);
  const first = Math.min(...hours);
  const last = Math.max(...hours);
  const peak = Math.max(0.01, ...[...every.values()].flatMap((buckets) => buckets.map(failedShare).filter((share) => !Number.isNaN(share))));
  const top = Math.ceil(peak * 20) / 20;
  const lanes = [...kept].toSorted(([left], [right]) => baseOrder(left) - baseOrder(right));
  const labelWidth = Math.min(width * 0.3, 8 + 6.6 * Math.max(...[...every.keys()].map((model) => baseName(model).length)));
  const x = linScale(first, last + 1, labelWidth + 8, width - 6, []);
  const barWidth = Math.max(1, x.at(first + 1) - x.at(first) - 0.5);
  const days = dayStarts(first, last).filter((_, index) => width >= 600 || index % 2 === 0);
  const height = lanes.length * (LANE_HEIGHT + LANE_GAP) + AXIS_HEIGHT;

  return h.figure(
    [h.Class("lanes")],
    [
      h.h3([], ["Failed calls by hour"]),
      h.p([h.Class("sub")], [`Share of replies that failed, by the hour each was logged. Every lane tops out at ${Math.round(top * 100)}%.`]),
      lanes.length === 0
        ? h.div([h.Class("empty")], ["No configs for this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...days.map(({ hour, name }) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(x.at(hour))), h.X2(String(x.at(hour))), h.Y1("0"), h.Y2(String(height - AXIS_HEIGHT))], []),
                    h.text([h.X(String(x.at(hour) + 3)), h.Y(String(height - 6))], [name]),
                  ],
                ),
              ),
              ...lanes.flatMap(([model, buckets], lane) => {
                const base = lane * (LANE_HEIGHT + LANE_GAP) + LANE_HEIGHT;

                return [
                  h.text([h.X(String(labelWidth)), h.Y(String(base - 6)), h.TextAnchor("end"), h.Style({ fill: colorOf(model) })], [baseName(model)]),
                  h.line([h.Class("grid"), h.X1(String(x.at(first))), h.X2(String(width - 6)), h.Y1(String(base)), h.Y2(String(base))], []),
                  ...buckets.flatMap((bucket) => {
                    const share = failedShare(bucket);

                    return Number.isNaN(share)
                      ? []
                      : [
                          h.rect(
                            [
                              ...markTip(h, anchorId("hour", model, bucket.hour), `${baseName(model)}, ${fmtTime(new Date(bucket.hour * HOUR_MS).toISOString())}: ${bucket.failed} of ${bucket.calls} replies failed (${(share * 100).toFixed(1)}%)`, false),
                              h.X(String(x.at(bucket.hour))),
                              h.Y(String(base - Math.max(1, (share / top) * LANE_HEIGHT))),
                              h.Width(String(barWidth)),
                              h.Height(String(Math.max(1, (share / top) * LANE_HEIGHT))),
                              h.Fill(colorOf(model)),
                            ],
                            [],
                          ),
                        ];
                  }),
                ];
              }),
            ],
          ),
    ],
  );
};
