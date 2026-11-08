//! The Buckshot minimax player (`sim/bend-mp/player/`), mirrored from Bend.
//!
//! Bend is the source of truth. Each module follows one player file, with
//! the same F32 operations in the same order, so an analysis here matches
//! Bend's bit for bit in the `f32` build. The `f64` build runs the same
//! operations in f64 and has no compat evaluator. The player instantiates the simple machine
//! (`buckshot-rules`).
//!
//! A [`Searcher`] analyses an [`InfoSet`], the mover's view. [`Compat`] is
//! Bend's search; [`BoundedV1`] is a new, versioned mode whose rows are not
//! Bend's. Parallel work runs only on a `rayon::ThreadPool` the caller
//! passes: [`analyse_batch`] spreads decisions over it and a sampled leaf its
//! deals. A decision's root moves always run one after another, since they
//! share the fuel, the node budget and the memo.

#[cfg(not(any(feature = "f32", feature = "f64")))]
compile_error!(
    "buckshot-search needs an arithmetic feature: `f64` (the default) or `f32` (Bend-exact, with compat: --no-default-features --features f32,seats-2-4)"
);
#[cfg(all(feature = "f32", feature = "f64"))]
compile_error!(
    "buckshot-search's `f32` and `f64` features exclude each other; for the f32 build use --no-default-features --features f32,seats-2-4"
);

mod belief;
mod deal;
mod evaluation;
mod machine;
mod memo;
mod num;
mod position;
mod search;
mod searcher;
mod types;

pub use belief::build;
pub use num::ARITHMETIC;
pub use position::{Board, Briefcase, Counter, GunView, Heard, Mode, ParseError, Position, RoundView, SeatView, Stage, parse};
pub use search::KeyStats;
#[cfg(feature = "f32")]
pub use search::analyse_belief;
#[cfg(feature = "f32")]
pub use searcher::Compat;
pub use searcher::{BoundedV1, InfoSet, Searcher, analyse_batch};
pub use types::{Analysed, Analysis, Belief, Cached, Level, Limits, Line, Memo, Reach, Reload, World};
