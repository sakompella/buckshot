//! The pluggable search (ADR-0052): a [`Searcher`] analyses the mover's
//! information set within [`Limits`]. [`Compat`] is Bend's search, bit for
//! bit; [`BoundedV1`] is the box search of a new, versioned mode.

use buckshot_rules::Table;
use rayon::ThreadPool;
use rayon::iter::{IntoParallelRefIterator, ParallelIterator};

use crate::belief::build;
use crate::position::{ParseError, Position, parse};
use crate::search::{KeyStats, Mode, run};
use crate::types::{Analysis, Limits, Memo, Reload};

/// What the mover knows: the config, the board as the mover sees it, the
/// mover's log and seat. Built only from that view (the position's number
/// line), never from the true state, so a searcher cannot see hidden shells.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InfoSet {
    position: Position,
}

impl InfoSet {
    /// The information set of a position's number line.
    ///
    /// # Errors
    ///
    /// The line's [`ParseError`].
    pub fn parse(line: &str) -> Result<Self, ParseError> {
        parse(line).map(|position| Self { position })
    }

    #[must_use]
    pub const fn position(&self) -> &Position {
        &self.position
    }
}

/// A search over an information set.
pub trait Searcher: Sync {
    /// The analysis of `info` to `limits.depth` decisions within `limits.budget` nodes.
    fn analyse(&self, info: &InfoSet, limits: Limits) -> Analysis;
}

/// Bend's search (`player/search.bend`), every row bit-identical to Bend's.
/// A pool runs the deals of a sampled leaf in parallel and leaves the rows as they are.
#[derive(Clone, Copy, Debug)]
pub struct Compat<'a> {
    pub reload: Reload,
    pub memo: Memo,
    pub pool: Option<&'a ThreadPool>,
}

/// `bounded-v1`: the box search, unpruned. A line's score is its private
/// value's low end and `upper` its high end; with nothing pruned they agree
/// and equal compat's values at a budget compat finishes within. Only nodes
/// count against the budget; there is no fuel, and a memo hit is free.
#[derive(Clone, Copy, Debug)]
pub struct BoundedV1<'a> {
    pub reload: Reload,
    pub pool: Option<&'a ThreadPool>,
}

/// `analyse.table`: the reload leaf's own refusals, then the belief.
fn analyse_in(
    info: &InfoSet,
    limits: Limits,
    leaves: (Reload, Memo),
    pool: Option<&ThreadPool>,
    mode: Mode,
) -> (Analysis, Option<KeyStats>) {
    let position = &info.position;
    match leaves.0 {
        Reload::Static => {}
        Reload::Sampled { count: 0 } => return (refused("the sampled leaf needs at least one deal"), None),
        Reload::Sampled { .. } => {
            if position.config.table() != Table::TwoSeats {
                return (refused("a leaf that deals the reload takes two seats only"), None);
            }
        }
    }
    match build(position) {
        Ok(belief) => run(&position.config, &belief, limits, leaves, pool, mode),
        Err(reason) => (refused(reason), None),
    }
}

const fn refused(reason: &'static str) -> Analysis {
    Analysis::Invalid { reason, nodes: 0 }
}

impl Searcher for Compat<'_> {
    fn analyse(&self, info: &InfoSet, limits: Limits) -> Analysis {
        analyse_in(info, limits, (self.reload, self.memo), self.pool, Mode::Compat).0
    }
}

impl BoundedV1<'_> {
    /// [`Searcher::analyse`] with the decision keys its deepest iteration visited.
    #[must_use]
    pub fn analyse_with_stats(&self, info: &InfoSet, limits: Limits) -> (Analysis, Option<KeyStats>) {
        analyse_in(info, limits, (self.reload, Memo::Charged), self.pool, Mode::Bounded { stats: true })
    }
}

impl Searcher for BoundedV1<'_> {
    fn analyse(&self, info: &InfoSet, limits: Limits) -> Analysis {
        analyse_in(
            info,
            limits,
            (self.reload, Memo::Charged),
            self.pool,
            Mode::Bounded { stats: false },
        )
        .0
    }
}

/// `f` of every information set on `pool`, in input order. Each is searched
/// alone, with its own memo and tally, so each result is the one a single
/// thread gives.
pub fn analyse_batch<T: Send>(infos: &[InfoSet], pool: &ThreadPool, f: impl Fn(&InfoSet) -> T + Sync + Send) -> Vec<T> {
    pool.install(|| infos.par_iter().map(f).collect())
}
