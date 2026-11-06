// Move and game accuracy as lichess computes them (lila AccuracyPercent.scala, Advice.scala, scalalib Maths.scala), on our
// scale: a "win percent" is a score in points of the round win chance (0-100), and a move's drop is its regret.
// Adaptations are listed in docs/arena/analysis/accuracy.md.

/** A move that gave up at least this many points of the round win chance is an inaccuracy, a mistake or a blunder. Lichess's 0.1, 0.2 and 0.3 are on its winning chances, [-1, 1], so they are 5, 10 and 15 win percents. */
export const INACCURACY_POINTS = 5;
export const MISTAKE_POINTS = 10;
export const BLUNDER_POINTS = 15;

/** A decision whose moves all score within this many points has no real choice and is left out of every move statistic. */
export const NO_CHOICE_POINTS = 1;

const clamp = (value: number, low: number, high: number): number => Math.min(high, Math.max(low, value));

const mean = (values: ReadonlyArray<number>): number => values.reduce((sum, value) => sum + value, 0) / values.length;

const populationDeviation = (values: ReadonlyArray<number>): number => {
  const center = mean(values);

  return Math.sqrt(values.reduce((sum, value) => sum + (value - center) ** 2, 0) / values.length);
};

/** Lichess's AccuracyPercent.fromWinPercents, with its one-point uncertainty bonus for an imperfect analysis (ours is a depth-limited search). */
export const moveAccuracy = (before: number, after: number): number =>
  after >= before ? 100 : clamp(103.1668100711649 * Math.exp(-0.04354415386753951 * (before - after)) - 3.166924740191411 + 1, 0, 100);

export interface ScoredMove {
  /** The best move's score: the win chance the player stood at before the move. */
  readonly before: number;
  /** The chosen move's score. */
  readonly after: number;
}

/**
 * Lichess's gameAccuracy for one player: the mean of a volatility-weighted mean and a harmonic mean of the move
 * accuracies. Each move's weight is the standard deviation of the win chances in a sliding window around it, kept
 * within 0.5 to 12. The series is the player's own moves in order: each best score, then the last chosen score.
 */
export const gameAccuracy = (moves: ReadonlyArray<ScoredMove>): number | null => {
  const { length } = moves;

  if (length === 0) return null;

  const positions = [...moves.map(({ before }) => before), moves[length - 1]?.after ?? 0];
  const size = positions.length;
  const windowSize = clamp(Math.floor((size - 1) / 10), 2, 8);
  const first = positions.slice(0, windowSize);
  const windows = [...Array.from({ length: Math.max(0, Math.min(windowSize, size) - 2) }, () => first), ...Array.from({ length: Math.max(1, size - windowSize + 1) }, (_window, at) => positions.slice(at, at + windowSize))];
  const weights = windows.map((window) => clamp(populationDeviation(window), 0.5, 12));
  const accuracies = moves.map(({ before, after }) => moveAccuracy(before, after));
  const weighted = accuracies.reduce((sum, accuracy, at) => sum + accuracy * (weights[at] ?? 0), 0) / weights.slice(0, length).reduce((sum, weight) => sum + weight, 0);
  const harmonic = length / accuracies.reduce((sum, accuracy) => sum + 1 / Math.max(1, accuracy), 0);

  return (weighted + harmonic) / 2;
};

export type Judgement = "best" | "fine" | "inaccuracy" | "mistake" | "blunder";

export const judgementOf = (points: number): Judgement =>
  points >= BLUNDER_POINTS ? "blunder" : points >= MISTAKE_POINTS ? "mistake" : points >= INACCURACY_POINTS ? "inaccuracy" : points > 0 ? "fine" : "best";
