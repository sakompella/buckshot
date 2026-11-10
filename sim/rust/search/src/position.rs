//! A position as the web encodes it for the native player (the number line of
//! `native.bend`'s `position.of`): fields in constructor order, a constructor
//! as its tag, a list as its count and then its items last first. A tag past
//! the last constructor reads as the last one, and a missing or unreadable
//! number reads as 0, as Bend's decoder does.
//!
//! Bend's decoder trusts its input, so this one refuses what the rules and the
//! search cannot hold: a list whose count is more than the numbers left, a
//! `GrabbingBegan` with more seats than the table, and a `Loaded` of more than
//! ten shells. Those are a [`ParseError`], never a panic or a silent cut.

use buckshot_rules::{
    AmountRule, Config, Damage, Direction, EnumMap, GameEvent, HealthRule, Item, ItemRule, Load, LoadRule, Ring, RoundRules, RuleError,
    Seat, Seats, Secret, Shell, ShellRule, Slot, Slots, Table,
};

/// The most shells a load holds; the search takes no board with a longer one shown.
pub(crate) const MAX_SHELLS: u32 = 10;

/// One log entry as one seat heard it (domain.bend `Heard`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Heard {
    Witnessed(GameEvent),
    Learned(Secret),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RoundView {
    pub index: u32,
    pub rounds: u32,
    pub health: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Counter {
    Unjammed { health: u32 },
    Jammed,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Briefcase {
    NotGrabbing,
    Grabbing,
    Holding(Item),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SeatView {
    pub counter: Counter,
    pub slots: Slots,
    pub cash: u32,
    pub briefcase: Briefcase,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct GunView {
    pub shown: Load,
    pub remaining: u32,
    pub sawed: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Idle,
    Aiming,
    Jamming,
    Stealing,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Stage {
    Setup,
    Distributing,
    Loading,
    Playing { seat: Seat, mode: Mode },
    MatchOver,
}

/// What every seat sees of the table (domain.bend `Board`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Board {
    pub round: RoundView,
    pub views: Ring<SeatView>,
    pub gun: GunView,
    pub direction: Direction,
    pub stage: Stage,
}

/// The searcher's view of a match: the config, the board, its log and its seat.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Position {
    pub config: Config,
    pub board: Board,
    pub log: Vec<Heard>,
    pub me: Seat,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ParseError {
    #[error("the board has {views:?} seat views at a {table:?} table")]
    Ring { table: Table, views: Table },
    #[error("a table with more than two seats, which the seats-2 build lacks")]
    Wide,
    #[error("a list of {count} items with {left} numbers left")]
    List { count: u64, left: usize },
    #[error("{count} seats grabbing at a {table:?} table")]
    Grabbing { table: Table, count: usize },
    #[error("a load of {live} live and {blank} blank shells, over {}", MAX_SHELLS)]
    Loaded { live: u32, blank: u32 },
    #[error(transparent)]
    Config(#[from] RuleError),
}

/// A number token; a missing or unreadable one reads as 0.
fn number(token: Option<&&str>) -> u64 {
    token.and_then(|token| token.parse().ok()).unwrap_or(0)
}

struct Tokens<'a> {
    rest: core::slice::Iter<'a, &'a str>,
    table: Table,
}

impl Tokens<'_> {
    fn raw(&mut self) -> u64 {
        number(self.rest.next())
    }

    /// `dec.nat`, cut to a U32.
    fn nat(&mut self) -> u32 {
        u32::try_from(self.raw() & 0xFFFF_FFFF).unwrap_or(0)
    }

    /// A constructor tag, past `last` read as `last`.
    fn tag(&mut self, last: u8) -> u8 {
        u8::try_from(self.raw().min(u64::from(last))).unwrap_or(last)
    }

    fn bool(&mut self) -> bool {
        self.raw() > 0
    }

    fn seat(&mut self) -> Seat {
        Seat::try_from(self.tag(3)).unwrap_or(Seat::Seat3)
    }

    fn item(&mut self) -> Item {
        Item::try_from(self.tag(8)).unwrap_or(Item::Remote)
    }

    fn slot(&mut self) -> Slot {
        Slot::try_from(self.tag(7)).unwrap_or(Slot::Slot7)
    }

    fn shell(&mut self) -> Shell {
        if self.tag(1) == 0 { Shell::Live } else { Shell::Blank }
    }

    fn damage(&mut self) -> Damage {
        if self.tag(1) == 0 { Damage::Single } else { Damage::Double }
    }

    fn direction(&mut self) -> Direction {
        if self.tag(1) == 0 {
            Direction::Clockwise
        } else {
            Direction::CounterClockwise
        }
    }

    fn load(&mut self) -> Load {
        let live = self.nat();
        let blank = self.nat();
        Load { live, blank }
    }

    /// A list: the count, then the items as read reversed. Each item takes at
    /// least one number, so a count over the numbers left is refused.
    fn list<T>(&mut self, mut read: impl FnMut(&mut Self) -> Result<T, ParseError>) -> Result<Vec<T>, ParseError> {
        let count = self.raw();
        let left = self.rest.len();
        let len = usize::try_from(count)
            .ok()
            .filter(|len| *len <= left)
            .ok_or(ParseError::List { count, left })?;
        let mut items = (0..len).map(|_| read(self)).collect::<Result<Vec<T>, _>>()?;
        items.reverse();
        Ok(items)
    }

    fn event(&mut self) -> Result<GameEvent, ParseError> {
        Ok(match self.tag(20) {
            0 => {
                let round = self.nat();
                let health = self.nat();
                let first = self.seat();
                GameEvent::RoundBegan { round, health, first }
            }
            1 => {
                let listed = self.list(|tokens| Ok(tokens.seat()))?;
                let table = self.table;
                if listed.len() > table.seats().len() {
                    return Err(ParseError::Grabbing {
                        table,
                        count: listed.len(),
                    });
                }
                let mut seats = Seats::EMPTY;
                for seat in listed {
                    seats.push(seat);
                }
                GameEvent::GrabbingBegan { seats }
            }
            2 => {
                let seat = self.seat();
                let item = self.item();
                GameEvent::Granted { seat, item }
            }
            3 => {
                let seat = self.seat();
                let slot = self.slot();
                let item = self.item();
                GameEvent::Placed { seat, slot, item }
            }
            4 => GameEvent::GrabbingEnded { seat: self.seat() },
            5 => GameEvent::DistributionDone,
            6 => {
                let load = self.load();
                if load.live.saturating_add(load.blank) > MAX_SHELLS {
                    return Err(ParseError::Loaded {
                        live: load.live,
                        blank: load.blank,
                    });
                }
                GameEvent::Loaded { load }
            }
            7 => GameEvent::TurnSkipped { seat: self.seat() },
            8 => GameEvent::JamLifted { seat: self.seat() },
            9 => GameEvent::TurnGiven { seat: self.seat() },
            10 => GameEvent::PickedUp { seat: self.seat() },
            11 => {
                let shooter = self.seat();
                let target = self.seat();
                let shell = self.shell();
                let captured = self.damage();
                let applied = self.nat();
                let health = self.nat();
                GameEvent::Fired {
                    shooter,
                    target,
                    shell,
                    captured,
                    applied,
                    health,
                }
            }
            12 => GameEvent::Died { seat: self.seat() },
            13 => {
                let seat = self.seat();
                let owner = self.seat();
                let slot = self.slot();
                let item = self.item();
                GameEvent::Used { seat, owner, slot, item }
            }
            14 => {
                let seat = self.seat();
                let health = self.nat();
                GameEvent::Healed { seat, health }
            }
            15 => {
                let seat = self.seat();
                let shell = self.shell();
                GameEvent::Ejected { seat, shell }
            }
            16 => GameEvent::Inverted { seat: self.seat() },
            17 => {
                let by = self.seat();
                let target = self.seat();
                GameEvent::JamApplied { by, target }
            }
            18 => GameEvent::DirectionFlipped {
                direction: self.direction(),
            },
            19 => {
                let seat = self.seat();
                let prize = self.nat();
                GameEvent::RoundWon { seat, prize }
            }
            _ => GameEvent::MatchConcluded,
        })
    }

    fn secret(&mut self) -> Secret {
        match self.tag(3) {
            0 => Secret::Glimpse { shell: self.shell() },
            1 => {
                let position = self.nat();
                let shell = self.shell();
                Secret::Clue { position, shell }
            }
            2 => Secret::NoClue,
            _ => Secret::EmptyBriefcase,
        }
    }

    fn heard(&mut self) -> Result<Heard, ParseError> {
        Ok(if self.tag(1) == 0 {
            Heard::Witnessed(self.event()?)
        } else {
            Heard::Learned(self.secret())
        })
    }

    fn slots(&mut self) -> Slots {
        Slot::ORDER.iter().fold(Slots::EMPTY, |slots, slot| {
            let item = if self.tag(1) == 0 { None } else { Some(self.item()) };
            slots.put(*slot, item)
        })
    }

    fn seat_view(&mut self) -> SeatView {
        let counter = if self.tag(1) == 0 {
            Counter::Unjammed { health: self.nat() }
        } else {
            Counter::Jammed
        };
        let slots = self.slots();
        let cash = self.nat();
        let briefcase = match self.tag(2) {
            0 => Briefcase::NotGrabbing,
            1 => Briefcase::Grabbing,
            _ => Briefcase::Holding(self.item()),
        };
        SeatView {
            counter,
            slots,
            cash,
            briefcase,
        }
    }

    /// `dec.ring`: a `Duo`, `Trio` or `Quad`, as the ring of that table.
    fn ring(&mut self) -> Result<Ring<SeatView>, ParseError> {
        let seats = u64::from(self.tag(2)).saturating_add(2);
        let table = Table::of_seats(seats).ok_or(ParseError::Wide)?;
        let views: Vec<SeatView> = table.seats().iter().map(|_| self.seat_view()).collect();
        let first = views.first().copied().unwrap_or(SeatView {
            counter: Counter::Jammed,
            slots: Slots::EMPTY,
            cash: 0,
            briefcase: Briefcase::NotGrabbing,
        });
        Ok(table
            .seats()
            .iter()
            .zip(views)
            .fold(Ring::fill(table, first), |ring, (seat, view)| ring.set(seat, view)))
    }

    fn stage(&mut self) -> Stage {
        match self.tag(4) {
            0 => Stage::Setup,
            1 => Stage::Distributing,
            2 => Stage::Loading,
            3 => {
                let seat = self.seat();
                let mode = match self.tag(3) {
                    0 => Mode::Idle,
                    1 => Mode::Aiming,
                    2 => Mode::Jamming,
                    _ => Mode::Stealing,
                };
                Stage::Playing { seat, mode }
            }
            _ => Stage::MatchOver,
        }
    }

    fn board(&mut self) -> Result<Board, ParseError> {
        let index = self.nat();
        let rounds = self.nat();
        let health = self.nat();
        let views = self.ring()?;
        let shown = self.load();
        let remaining = self.nat();
        let sawed = self.bool();
        let direction = self.direction();
        let stage = self.stage();
        Ok(Board {
            round: RoundView { index, rounds, health },
            views,
            gun: GunView { shown, remaining, sawed },
            direction,
            stage,
        })
    }
}

/// `table.of`: 2, 3 and 4 seats; anything else reads as four.
fn table_of(tag: u64) -> Result<Table, ParseError> {
    let seats = if matches!(tag, 2 | 3) { tag } else { 4 };
    Table::of_seats(seats).ok_or(ParseError::Wide)
}

/// `web.bend` `round.of`: the default round, or with items off random health
/// and loads and every item disabled.
const fn round_of(items: bool) -> RoundRules {
    if items {
        RoundRules::default_round()
    } else {
        let load = LoadRule {
            shells: ShellRule::Random,
            items: AmountRule::Random,
        };
        RoundRules {
            health: HealthRule::Random,
            loads: [load; 4],
            items: EnumMap::from_array([ItemRule::OFF; 9]),
        }
    }
}

/// `position.of` over a line of numbers separated by single spaces.
///
/// # Errors
///
/// [`ParseError::Ring`] when the board's seat views are not the table's ring,
/// and [`ParseError::Wide`] for a table the build lacks. [`ParseError::List`]
/// for a list count over the numbers left, [`ParseError::Grabbing`] for more
/// grabbing seats than the table has and [`ParseError::Loaded`] for a load of
/// more than ten shells.
pub fn parse(line: &str) -> Result<Position, ParseError> {
    let numbers: Vec<&str> = line.split(' ').collect();
    let mut rest = numbers.iter();
    let table = table_of(number(rest.next()))?;
    let mut tokens = Tokens { rest, table };
    let round = round_of(tokens.bool());
    let config = Config::new(table, &[round, round, round])?;
    let me = tokens.seat();
    let board = tokens.board()?;
    let log = tokens.list(Tokens::heard)?;
    let views = board.views.table();
    if views != table {
        return Err(ParseError::Ring { table, views });
    }
    Ok(Position { config, board, log, me })
}

#[cfg(test)]
mod tests {
    use buckshot_rules::{GameEvent, Load, Table};

    use super::{Heard, ParseError, parse};

    /// A two-seat board at an Idle turn of seat 1, up to where the log's count goes.
    const BOARD: &str = "2 1 1 0 3 3 0 0 3 0 0 0 0 0 0 0 0 0 0 0 3 0 0 0 0 0 0 0 0 0 0 1 1 2 0 0 3 1 0";

    fn with_log(log: &str) -> Result<super::Position, ParseError> {
        parse(&format!("{BOARD} {log}"))
    }

    #[test]
    fn a_grabbing_list_longer_than_the_table_is_refused() {
        assert_eq!(
            with_log("1 0 1 5 1 3 1 3 1"),
            Err(ParseError::Grabbing {
                table: Table::TwoSeats,
                count: 5
            })
        );
        assert!(with_log("1 0 1 2 1 3").is_ok(), "two seats fit a two-seat table");
    }

    #[test]
    fn a_list_count_over_the_numbers_left_is_refused() {
        assert_eq!(
            with_log("4294967295 0 1 1 1"),
            Err(ParseError::List {
                count: 4_294_967_295,
                left: 4
            })
        );
        assert_eq!(with_log("18446744073709551615"), Err(ParseError::List { count: u64::MAX, left: 0 }));
        assert_eq!(with_log("3 0 0"), Err(ParseError::List { count: 3, left: 2 }));
    }

    #[test]
    fn a_load_of_more_than_ten_shells_is_refused() {
        assert_eq!(with_log("1 0 6 6 5"), Err(ParseError::Loaded { live: 6, blank: 5 }));
        let position = with_log("1 0 6 6 4").expect("ten shells fit");
        assert_eq!(
            position.log,
            [Heard::Witnessed(GameEvent::Loaded {
                load: Load { live: 6, blank: 4 }
            })]
        );
    }
}
