//! The simple machine as the player drives it (`simple/main.bend`'s `answer`
//! and `request`), with the round winner its notes announce.

use buckshot_rules::{Answer, Config, GameEvent, Note, Notes, Range, Request, Seat, State, request, step};

/// A state and the first round winner in the notes of the answer that reached it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Stepped {
    pub state: State,
    pub won: Option<Seat>,
}

/// `exact`'s note: the first `RoundWon`.
pub fn round_won(notes: &[Note]) -> Option<Seat> {
    notes.iter().find_map(|note| match *note {
        Note::Shown(GameEvent::RoundWon { seat, .. }) => Some(seat),
        Note::Shown(_) | Note::Told { .. } => None,
    })
}

/// `M.answer(state, n)`: a draw takes the n-th value of its range, a choice
/// the n-th move (the last past the end); at an end the state stands, with
/// no notes.
pub fn answer_notes(config: &Config, state: State, n: u32) -> Option<(State, Notes)> {
    let token = match request(config, &state) {
        Request::Draw { range, .. } => Answer::Draw(range.value(n)),
        Request::Choose(menu) => Answer::Choice(menu.clamped(n)?),
        Request::Finished | Request::Stuck => return None,
    };
    let stepped = step(config, state, token);
    Some((stepped.state, stepped.notes))
}

/// [`answer_notes`] keeping only the winner; a state that stands keeps its notes.
pub fn answer(config: &Config, at: Stepped, n: u32) -> Stepped {
    match answer_notes(config, at.state, n) {
        Some((state, notes)) => Stepped {
            state,
            won: round_won(notes.as_slice()),
        },
        None => at,
    }
}

/// The range of the state's draw, if it is at one.
pub fn draw_range(config: &Config, state: &State) -> Option<Range> {
    match request(config, state) {
        Request::Draw { range, .. } => Some(range),
        Request::Choose(_) | Request::Finished | Request::Stuck => None,
    }
}
