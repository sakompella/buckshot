//! A position as the web encodes it for the native player (the number line of
//! `native.bend`'s `position.of`): fields in constructor order, a constructor
//! as its tag, a list as its count and then its items last first. A tag past
//! the last constructor reads as the last one, and a missing or unreadable
//! number reads as 0, as Bend's decoder does.

use buckshot_rules::{
    AmountRule, Config, Damage, Direction, GameEvent, HealthRule, Item, ItemRule, Load, LoadRule, Ring, RoundRules, RuleError, Seat, Seats,
    Secret, Shell, ShellRule, Slot, Slots, Table,
};

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
    #[error(transparent)]
    Config(#[from] RuleError),
}

struct Tokens<'a> {
    rest: core::str::Split<'a, char>,
}

impl Tokens<'_> {
    fn raw(&mut self) -> u64 {
        self.rest.next().and_then(|token| token.parse().ok()).unwrap_or(0)
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

    /// A list: the count, then the items as read reversed.
    fn list<T>(&mut self, mut read: impl FnMut(&mut Self) -> T) -> Vec<T> {
        let count = self.raw();
        let mut items: Vec<T> = (0..count).map(|_| read(self)).collect();
        items.reverse();
        items
    }

    fn event(&mut self) -> GameEvent {
        match self.tag(20) {
            0 => {
                let round = self.nat();
                let health = self.nat();
                let first = self.seat();
                GameEvent::RoundBegan { round, health, first }
            }
            1 => {
                let mut seats = Seats::EMPTY;
                for seat in self.list(Self::seat) {
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
            6 => GameEvent::Loaded { load: self.load() },
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
        }
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

    fn heard(&mut self) -> Heard {
        if self.tag(1) == 0 {
            Heard::Witnessed(self.event())
        } else {
            Heard::Learned(self.secret())
        }
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
    fn ring(&mut self) -> Ring<SeatView> {
        let table = match self.tag(2) {
            0 => Table::TwoSeats,
            1 => Table::ThreeSeats,
            _ => Table::FourSeats,
        };
        let views: Vec<SeatView> = table.seats().iter().map(|_| self.seat_view()).collect();
        let first = views.first().copied().unwrap_or(SeatView {
            counter: Counter::Jammed,
            slots: Slots::EMPTY,
            cash: 0,
            briefcase: Briefcase::NotGrabbing,
        });
        table
            .seats()
            .iter()
            .zip(views)
            .fold(Ring::fill(table, first), |ring, (seat, view)| ring.set(seat, view))
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

    fn board(&mut self) -> Board {
        let index = self.nat();
        let rounds = self.nat();
        let health = self.nat();
        let views = self.ring();
        let shown = self.load();
        let remaining = self.nat();
        let sawed = self.bool();
        let direction = self.direction();
        let stage = self.stage();
        Board {
            round: RoundView { index, rounds, health },
            views,
            gun: GunView { shown, remaining, sawed },
            direction,
            stage,
        }
    }
}

/// `table.of`: 2, 3 and 4 seats; anything else reads as four.
const fn table_of(tag: u64) -> Table {
    match tag {
        2 => Table::TwoSeats,
        3 => Table::ThreeSeats,
        _ => Table::FourSeats,
    }
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
        let off = ItemRule {
            enabled: false,
            per_player: 0,
            on_table: 0,
        };
        RoundRules {
            health: HealthRule::Random,
            loads: [load; 4],
            items: [off; 9],
        }
    }
}

/// `position.of` over a line of numbers separated by single spaces.
///
/// # Errors
///
/// [`ParseError::Ring`] when the board's seat views are not the table's ring.
pub fn parse(line: &str) -> Result<Position, ParseError> {
    let mut tokens = Tokens { rest: line.split(' ') };
    let table = table_of(tokens.raw());
    let round = round_of(tokens.bool());
    let config = Config::new(table, &[round, round, round])?;
    let me = tokens.seat();
    let board = tokens.board();
    let log = tokens.list(Tokens::heard);
    let views = board.views.table();
    if views != table {
        return Err(ParseError::Ring { table, views });
    }
    Ok(Position { config, board, log, me })
}
