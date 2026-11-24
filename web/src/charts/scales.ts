/** A linear or log mapping from data to pixels, with the ticks to draw. */
export interface Scale {
  readonly at: (value: number) => number;
  readonly ticks: ReadonlyArray<number>;
}

export const linScale = (d0: number, d1: number, r0: number, r1: number, ticks: ReadonlyArray<number>): Scale => ({
  at: (value) => r0 + ((value - d0) / (d1 - d0 || 1)) * (r1 - r0),
  ticks,
});

/** Ticks at 1, 2 and 5 times each power of ten in the domain. */
export const logScale = (d0: number, d1: number, r0: number, r1: number): Scale => {
  const l0 = Math.log10(d0);
  const l1 = Math.log10(d1);
  const ticks: Array<number> = [];

  for (let exponent = Math.floor(l0); exponent <= Math.ceil(l1); exponent++) {
    for (const step of [1, 2, 5]) {
      const value = Number((step * 10 ** exponent).toPrecision(3));

      if (value >= d0 * 0.999 && value <= d1 * 1.001) { ticks.push(value); }
    }
  }

  return { at: (value) => r0 + ((Math.log10(Math.max(value, d0)) - l0) / (l1 - l0 || 1)) * (r1 - r0), ticks };
};
