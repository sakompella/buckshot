//! The simple machine as the player drives it (`simple/main.bend`'s `answer`
//! and `request`), with the round winner its notes announce.

use buckshot_rules::{Answer, Config, GameEvent, Note, Notes, Request, Seat, State, request, step_into};

/// `exact`'s note: the first `RoundWon`.
pub fn round_won(notes: &[Note]) -> Option<Seat> {
    notes.iter().find_map(|note| match *note {
        Note::Shown(GameEvent::RoundWon { seat, .. }) => Some(seat),
        Note::Shown(_) | Note::Told { .. } => None,
    })
}

/// The answer `M.answer(state, n)` gives at `request`: a draw takes the n-th
/// value of its range, a choice the n-th move (the last past the end); an end
/// takes none.
pub fn token(request: &Request, n: u32) -> Option<Answer> {
    match request {
        Request::Draw { range, .. } => Some(Answer::Draw(range.value(n))),
        Request::Choose(menu) => menu.clamped(n).map(Answer::Choice),
        Request::Finished | Request::Stuck => None,
    }
}

/// `M.answer(state, n)` with its notes written into `notes`; `None` where
/// the state stands, with no notes.
pub fn answer_into(config: &Config, state: &State, n: u32, notes: &mut Notes) -> Option<State> {
    let answer = token(&request(config, state), n)?;
    Some(step_into(config, *state, answer, notes))
}
