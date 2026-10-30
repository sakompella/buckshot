// Point-label placement after RuneBench's scatter-labels.js. A label prefers to sit centred above its dot (as on
// DeepSWE), then below, sliding sideways under pressure, then on the right and left flanks and wider rings.
// Coordinate descent lets each label re-pick its cheapest spot, then a joint pass untangles pairs whose leader lines cross.

export interface LabelPoint {
  readonly x: number;
  readonly y: number;
  readonly w: number;
  readonly h: number;
}

export type Align = "start" | "middle" | "end";

export interface Placed {
  readonly idx: number;
  readonly left: number;
  readonly y: number;
  readonly w: number;
  readonly h: number;
  readonly anchorX: number;
  readonly align: Align;
  readonly dotX: number;
  readonly dotY: number;
}

export interface Box {
  readonly left: number;
  readonly right: number;
  readonly top: number;
  readonly bottom: number;
}

export interface Segment {
  readonly x1: number;
  readonly y1: number;
  readonly x2: number;
  readonly y2: number;
}

interface Candidate {
  readonly left: number;
  readonly y: number;
  readonly anchorX: number;
  readonly align: Align;
  readonly gap: number;
  readonly side: number;
}

const ALIGN_SHARE: Readonly<Record<Align, number>> = { start: 0, middle: 0.5, end: 1 };

const PAD = 2;

const DOT_R = 7;

const GAP = 4;

let context: CanvasRenderingContext2D | null = null;

export const measureText = (text: string, font: string): number => {
  context ??= document.createElement("canvas").getContext("2d");

  if (context === null) return text.length * 6.5;

  context.font = font;

  return context.measureText(text).width;
};

const boxOf = (at: { readonly left: number; readonly y: number }, w: number, h: number): Box => ({ left: at.left - PAD, right: at.left + w + PAD, top: at.y - h / 2 - PAD, bottom: at.y + h / 2 + PAD });

const overlap = (a: Box, b: Box): number => {
  const width = Math.min(a.right, b.right) - Math.max(a.left, b.left);
  const height = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);

  return width > 0 && height > 0 ? width * height : 0;
};

const orient = (ax: number, ay: number, bx: number, by: number, cx: number, cy: number) => Math.sign((bx - ax) * (cy - ay) - (by - ay) * (cx - ax));

const segmentsCross = (s: Segment, t: Segment): boolean => {
  if (Math.max(s.x1, s.x2) < Math.min(t.x1, t.x2) || Math.max(t.x1, t.x2) < Math.min(s.x1, s.x2) || Math.max(s.y1, s.y2) < Math.min(t.y1, t.y2) || Math.max(t.y1, t.y2) < Math.min(s.y1, s.y2)) return false;

  const o1 = orient(s.x1, s.y1, s.x2, s.y2, t.x1, t.y1);
  const o2 = orient(s.x1, s.y1, s.x2, s.y2, t.x2, t.y2);
  const o3 = orient(t.x1, t.y1, t.x2, t.y2, s.x1, s.y1);
  const o4 = orient(t.x1, t.y1, t.x2, t.y2, s.x2, s.y2);

  return o1 !== o2 && o3 !== o4 && o1 !== 0 && o2 !== 0;
};

const segmentHitsBox = (s: Segment, box: Box): boolean => {
  if (Math.max(s.x1, s.x2) <= box.left || Math.min(s.x1, s.x2) >= box.right || Math.max(s.y1, s.y2) <= box.top || Math.min(s.y1, s.y2) >= box.bottom) return false;

  const isInside = (x: number, y: number) => x > box.left && x < box.right && y > box.top && y < box.bottom;

  if (isInside(s.x1, s.y1) || isInside(s.x2, s.y2)) return true;

  const edges: ReadonlyArray<Segment> = [
    { x1: box.left, y1: box.top, x2: box.right, y2: box.top },
    { x1: box.right, y1: box.top, x2: box.right, y2: box.bottom },
    { x1: box.right, y1: box.bottom, x2: box.left, y2: box.bottom },
    { x1: box.left, y1: box.bottom, x2: box.left, y2: box.top },
  ];

  return edges.some((edge) => segmentsCross(s, edge));
};

const segmentOf = (dotX: number, dotY: number, at: { readonly left: number; readonly y: number }, w: number, h: number): Segment => ({
  x1: dotX,
  y1: dotY,
  x2: Math.max(at.left, Math.min(dotX, at.left + w)),
  y2: Math.max(at.y - h / 2, Math.min(dotY, at.y + h / 2)),
});

const RINGS: ReadonlyArray<readonly [number, number, number, ReadonlyArray<number>]> = [
  [14, 8, 10, [0, -10, 10, -20, 20, -30, 30, -40, 40]],
  [30, 12, 14, [0, -14, 14, -28, 28, -42, 42]],
  [48, 16, 18, [0, -16, 16, -32, 32, -48, 48]],
];

const candidatesOf = (point: LabelPoint): ReadonlyArray<Candidate> => {
  const { w, h } = point;

  const at = (dx: number, dy: number, align: Align, side: number): Candidate => {
    const anchorX = point.x + dx;
    const left = anchorX - w * ALIGN_SHARE[align];
    const y = point.y + dy;
    const gap = Math.hypot(point.x - Math.max(left, Math.min(point.x, left + w)), point.y - Math.max(y - h / 2, Math.min(point.y, y + h / 2)));

    return { left, y, align, anchorX, gap, side };
  };

  const flank = DOT_R + GAP;
  const vertical = DOT_R + 1 + h / 2;

  return [
    at(0, -vertical, "middle", 0),
    at(0, vertical, "middle", 1),
    ...[-w / 4, w / 4, -w / 2, w / 2].flatMap((dx) => [at(dx, -vertical, "middle", 2), at(dx, vertical, "middle", 3)]),
    ...[7, 14, 21].flatMap((dy) => [at(0, -vertical - dy, "middle", 2), at(0, vertical + dy, "middle", 3)]),
    ...[0, -7, 7, -14, 14, -21, 21, -28, 28, -36, 36].flatMap((dy) => [at(flank, dy, "start", 4), at(-flank, dy, "end", 5)]),
    ...RINGS.flatMap(([dx, sideRight, sideLeft, heights]) => heights.flatMap((dy) => [at(flank + dx, dy, "start", sideRight), at(-flank - dx, dy, "end", sideLeft)])),
  ];
};

interface Label {
  readonly idx: number;
  readonly w: number;
  readonly h: number;
  readonly dotX: number;
  readonly dotY: number;
  readonly candidates: ReadonlyArray<Candidate>;
  current: Candidate;
}

export const placeLabels = (points: ReadonlyArray<LabelPoint>, area: Box): ReadonlyArray<Placed> => {
  const MARGIN = 4;
  const dots = points.map((point): Box => ({ left: point.x - DOT_R - MARGIN, right: point.x + DOT_R + MARGIN, top: point.y - DOT_R - MARGIN, bottom: point.y + DOT_R + MARGIN }));
  const isInArea = (box: Box) => box.left >= area.left && box.right <= area.right && box.top >= area.top && box.bottom <= area.bottom;

  const labels = points.map((point, idx): Label => {
    const all = candidatesOf(point);
    const usable = all.filter((candidate) => isInArea(boxOf(candidate, point.w, point.h)));
    const candidates = usable.length > 0 ? usable : all.slice(0, 1);
    const [first = all[0]] = candidates;

    if (first === undefined) throw new Error("a label always has a first candidate");

    return { idx, w: point.w, h: point.h, dotX: point.x, dotY: point.y, candidates, current: first };
  });

  const boxes = labels.map((label) => boxOf(label.current, label.w, label.h));
  const segments = labels.map((label) => segmentOf(label.dotX, label.dotY, label.current, label.w, label.h));

  const refresh = (label: Label) => {
    boxes[label.idx] = boxOf(label.current, label.w, label.h);
    segments[label.idx] = segmentOf(label.dotX, label.dotY, label.current, label.w, label.h);
  };

  const between = (box: Box, segment: Segment, otherBox: Box, otherSegment: Segment): number =>
    overlap(box, otherBox) * 4 + (segmentsCross(segment, otherSegment) ? 150 : 0) + (segmentHitsBox(segment, otherBox) ? 60 : 0) + (segmentHitsBox(otherSegment, box) ? 60 : 0);

  const costAt = (label: Label, candidate: Candidate, apart?: Label): number => {
    const box = boxOf(candidate, label.w, label.h);
    const segment = segmentOf(label.dotX, label.dotY, candidate, label.w, label.h);
    let cost = candidate.gap * 2.2 + candidate.side;

    labels.forEach((other) => {
      const otherBox = boxes[other.idx];
      const otherSegment = segments[other.idx];

      if (other === label || other === apart || otherBox === undefined || otherSegment === undefined) return;

      cost += between(box, segment, otherBox, otherSegment);
    });

    dots.forEach((dot, index) => {
      if (index !== label.idx) cost += overlap(box, dot) * 6;
    });

    return cost;
  };

  const cheapest = (label: Label): Candidate => {
    let best = label.current;
    let bestCost = Infinity;

    for (const candidate of label.candidates) {
      const cost = costAt(label, candidate);

      if (cost < bestCost) {
        bestCost = cost;
        best = candidate;
      }
    }

    return best;
  };

  for (let sweep = 0; sweep < 8; sweep++) {
    let hasMoved = false;

    for (const label of labels) {
      const best = cheapest(label);

      if (best !== label.current) {
        label.current = best;
        refresh(label);
        hasMoved = true;
      }
    }

    if (!hasMoved) break;
  }

  const cheaperPair = (a: Label, b: Label): readonly [Candidate, Candidate] | null => {
    let best: readonly [Candidate, Candidate] | null = null;
    let bestCost = costAt(a, a.current) + costAt(b, b.current);

    const placesOf = (label: Label, other: Label) =>
      label.candidates.map((candidate) => ({ candidate, alone: costAt(label, candidate, other), box: boxOf(candidate, label.w, label.h), segment: segmentOf(label.dotX, label.dotY, candidate, label.w, label.h) }));

    const placesB = placesOf(b, a);

    for (const placeA of placesOf(a, b)) {
      for (const placeB of placesB) {
        const cost = placeA.alone + placeB.alone + 2 * between(placeA.box, placeA.segment, placeB.box, placeB.segment);

        if (cost < bestCost - 1e-6) {
          bestCost = cost;
          best = [placeA.candidate, placeB.candidate];
        }
      }
    }

    return best;
  };

  for (let pass = 0; pass < 3; pass++) {
    let hasUntangled = false;

    for (const [index, a] of labels.entries()) {
      for (const b of labels.slice(index + 1)) {
        const segmentA = segments[a.idx];
        const segmentB = segments[b.idx];

        if (segmentA === undefined || segmentB === undefined || !segmentsCross(segmentA, segmentB)) continue;

        const pair = cheaperPair(a, b);

        if (pair === null) continue;

        [a.current, b.current] = pair;
        refresh(a);
        refresh(b);
        hasUntangled = true;
      }
    }

    if (!hasUntangled) break;
  }

  return labels.map((label) => ({ idx: label.idx, left: label.current.left, y: label.current.y, w: label.w, h: label.h, anchorX: label.current.anchorX, align: label.current.align, dotX: label.dotX, dotY: label.dotY }));
};

/** The leader from the dot's edge to the nearest point of the label box, or null when the label hugs its dot. */
export const leader = (label: Placed): Segment | null => {
  const nearX = Math.max(label.left, Math.min(label.dotX, label.left + label.w));
  const nearY = Math.max(label.y - label.h / 2, Math.min(label.dotY, label.y + label.h / 2));

  if (Math.hypot(nearX - label.dotX, nearY - label.dotY) <= DOT_R + 4) return null;

  const angle = Math.atan2(nearY - label.dotY, nearX - label.dotX);

  return { x1: label.dotX + Math.cos(angle) * DOT_R, y1: label.dotY + Math.sin(angle) * DOT_R, x2: nearX - Math.cos(angle), y2: nearY - Math.sin(angle) };
};

/** Drops labels, lowest priority first, until none overlaps another label or a dot: for charts too narrow to label every point. */
export const uncrowded = (placed: ReadonlyArray<Placed>, priority: ReadonlyArray<number>): ReadonlyArray<Placed> => {
  const dots = placed.map((label): Box => ({ left: label.dotX - 5, right: label.dotX + 5, top: label.dotY - 5, bottom: label.dotY + 5 }));
  const kept: Array<{ readonly label: Placed; readonly box: Box }> = [];

  for (const idx of priority) {
    const label = placed.find((candidate) => candidate.idx === idx);

    if (label === undefined) continue;

    const box = boxOf(label, label.w, label.h);
    const isCrowded = kept.some((other) => overlap(box, other.box) > 0) || dots.some((dot, index) => placed[index]?.idx !== idx && overlap(box, dot) > 0);

    if (!isCrowded) kept.push({ label, box });
  }

  return kept.map(({ label }) => label);
};
