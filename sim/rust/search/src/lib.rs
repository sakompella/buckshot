//! The Buckshot minimax player (`sim/bend-mp/player/`), mirrored from Bend.
//!
//! Bend is the source of truth. Each module follows one player file, with
//! the same F32 operations in the same order, so an analysis here matches
//! Bend's bit for bit. The player instantiates the simple machine
//! (`buckshot-rules`).
//!
//! A [`Searcher`] analyses an [`InfoSet`], the mover's view. [`Compat`] is
//! Bend's search; [`BoundedV1`] is a new, versioned mode whose rows are not
//! Bend's. Parallel work runs only on a `rayon::ThreadPool` the caller
//! passes: [`analyse_batch`] spreads decisions over it and a sampled leaf its
//! deals. A decision's root moves always run one after another, since they
//! share the fuel, the node budget and the memo.

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
pub use position::{Board, Briefcase, Counter, GunView, Heard, Mode, ParseError, Position, RoundView, SeatView, Stage, parse};
pub use search::{KeyStats, analyse_belief};
pub use searcher::{BoundedV1, Compat, InfoSet, Searcher, analyse_batch};
pub use types::{Analysed, Analysis, Belief, Cached, Level, Limits, Line, Memo, Reach, Reload, World};
