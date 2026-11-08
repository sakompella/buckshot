//! The Bend branches the rules mirror. `ids.rs` is generated from the Bend
//! sources by `branch-map` (`cargo run -p branch-map -- write`); `branch-map
//! check` checks that each Rust match arm, `if` branch and loop opens with
//! `branch!` naming its variant, and that each variant has its Rust sites.
//!
//! `branch!` compiles to nothing unless the `trace` feature is on; only the
//! verification runs turn it on (`cargo trace-test`). Under `trace` the
//! branches taken are recorded per thread.

mod ids;

pub(crate) use ids::B;

#[cfg(feature = "trace")]
thread_local! {
    static TRACE: core::cell::RefCell<Vec<&'static str>> = const { core::cell::RefCell::new(Vec::new()) };
}

#[cfg(feature = "trace")]
pub(crate) fn record(branch: B) {
    TRACE.with(|trace| trace.borrow_mut().push(branch.label()));
}

/// The Bend branches (`module:def:pattern`) taken on this thread since the last call.
#[cfg(feature = "trace")]
#[must_use]
pub fn take_trace() -> Vec<&'static str> {
    TRACE.with(|trace| core::mem::take(&mut *trace.borrow_mut()))
}
