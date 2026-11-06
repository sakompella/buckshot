//! Every F32 operation and numeric cast of the player, in one place, so the
//! match with Bend's F32 can be audited here. Bend compiles F32 to JavaScript
//! doubles rounded by `Math.fround` after each operation; for one `+`, `*`
//! or `/` of two F32 values that is exactly Rust's `f32` operation. There is
//! no fused multiply-add: each product is rounded before it is added.

pub use ops::F32;

#[expect(
    clippy::float_arithmetic,
    clippy::as_conversions,
    clippy::cast_precision_loss,
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    reason = "Bend F32/U32 ops and conversions, in Bend's order"
)]
mod ops {
    /// 2^32, the first value past a U32.
    const TWO_TO_32: f32 = 65_536.0 * 65_536.0;

    /// A Bend F32.
    #[derive(Clone, Copy, Debug, PartialEq, Default)]
    pub struct F32(f32);

    impl F32 {
        pub const ZERO: Self = Self(0.0);
        pub const ONE: Self = Self(1.0);
        const HALF: Self = Self(0.5);
        const MILLION: Self = Self(1_000_000.0);

        /// `U32.to_f32`: rounded to the nearest F32.
        #[must_use]
        pub const fn from_u32(x: u32) -> Self {
            Self(x as f32)
        }

        /// `F32.from_nat` of a length: the Nat cut to a U32, then rounded.
        #[must_use]
        pub const fn from_len(n: usize) -> Self {
            Self((n as u32) as f32)
        }

        /// `F32.to_u32`: the floor of a value in `[1, 2^32)`, else 0 (NaN included).
        #[must_use]
        pub fn to_u32(self) -> u32 {
            if self.0 >= 1.0 && self.0 < TWO_TO_32 { self.0 as u32 } else { 0 }
        }

        #[must_use]
        pub fn bits(self) -> u32 {
            self.0.to_bits()
        }

        #[must_use]
        pub fn add(self, other: Self) -> Self {
            Self(self.0 + other.0)
        }

        #[must_use]
        pub fn mul(self, other: Self) -> Self {
            Self(self.0 * other.0)
        }

        #[must_use]
        pub fn div(self, other: Self) -> Self {
            Self(self.0 / other.0)
        }

        /// `millionths`: `min(1000000, F32.to_u32(x + 0.5))`.
        #[must_use]
        pub fn millionths(self) -> u32 {
            self.add(Self::HALF).to_u32().min(1_000_000)
        }

        /// `state.estimate`'s ratio: `F32.to_u32(1000000.0 * (weight / total))`.
        #[must_use]
        pub fn per_million(weight: u32, total: u32) -> u32 {
            Self::MILLION.mul(Self::from_u32(weight).div(Self::from_u32(total))).to_u32()
        }

        /// A Bend right fold `f(x0, f(x1, ... f(xn, 0.0)))` with `f = add`:
        /// the sum taken from the last term to the first.
        pub fn sum_right(terms: impl DoubleEndedIterator<Item = Self>) -> Self {
            terms.rev().fold(Self::ZERO, |rest, term| term.add(rest))
        }
    }

    /// `U32.from_nat` of a count: the Nat modulo 2^32.
    #[must_use]
    pub const fn len_u32(n: usize) -> u32 {
        n as u32
    }
}

pub use ops::len_u32;
