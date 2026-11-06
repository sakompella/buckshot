//! The Buckshot minimax player (`sim/bend-mp/player/`), mirrored from Bend.
//!
//! Bend is the source of truth. Each module follows one player file, with
//! the same F32 operations in the same order, so an analysis here matches
//! Bend's bit for bit. The player instantiates the simple machine
//! (`buckshot-rules`).

mod belief;
mod deal;
mod evaluation;
mod machine;
mod memo;
mod num;
mod position;
mod search;
mod types;

pub use belief::build;
pub use position::{Board, Briefcase, Counter, GunView, Heard, Mode, ParseError, Position, RoundView, SeatView, Stage, parse};
pub use search::{analyse, analyse_belief};
pub use types::{Analysed, Analysis, Belief, Cached, Level, Limits, Line, Memo, Reach, Reload, World};
