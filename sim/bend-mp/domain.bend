import Base

# Shared domain of the Buckshot Roulette multiplayer rules library (2 to 4 seats).
# The reference (ref/), the machine (sm/), the laws, the AIs, the driver and the
# web UI all speak these types. Neither model's state is here: only what crosses
# the boundary between a model and its callers.
#
# D-numbers (D11, D45, ...) cite the source decision record, which cites the
# decompiled Godot code line by line. It is kept locally, not committed, at
# _work/bend-faithful/source-decisions.md.
#
# Phase-specific option types (idle moves, target lists, grab or place needs)
# are not here. Only sm/ consumes them: it renders them to the public Move menus
# and reads its own typed lists back on answer. ref/ parses the public Move into
# a host packet (D32) and needs no typed options. Keeping them inside sm/ means a
# new machine state never widens a match in the AIs, the driver or the UI.
#
# Base is imported unqualified, so constructor names here avoid Base's (Zero,
# Succ, Some, None, Done, Fail, Ready, Wait, Key, Move, Look, Close, Emit, Halt,
# ...). Importing modules see these as D.Name. In a JS build rooted elsewhere
# the tags are path-qualified ("domain.Seat1"); rooted here they are bare.

# Seats
# =====

# A seat is a fixed socket identity. Two players sit at sockets 1 and 3, three
# at 0..2, four at 0..3 (D45). Seat assignment is driver configuration.
type Seat is Data:
  Seat0{}
  Seat1{}
  Seat2{}
  Seat3{}

type Table is Data:
  TwoSeats{}
  ThreeSeats{}
  FourSeats{}

# One value per configured seat, in ascending socket order. The constructor is
# the table, so a ring can neither miss a seated socket nor hold an empty one.
type Ring<a, -A: Kind(a)> is Kind(a):
  Duo{s1: A, s3: A}
  Trio{s0: A, s1: A, s2: A}
  Quad{s0: A, s1: A, s2: A, s3: A}

def seat.eq(a: Seat, b: Seat) -> Bool:
  match a b:
    case Seat0{} Seat0{}:
      True{}
    case Seat1{} Seat1{}:
      True{}
    case Seat2{} Seat2{}:
      True{}
    case Seat3{} Seat3{}:
      True{}
    case _ _:
      False{}

def table.seats(table: Table) -> List<&2, Seat>:
  match table:
    case TwoSeats{}:
      [Seat1{}, Seat3{}]
    case ThreeSeats{}:
      [Seat0{}, Seat1{}, Seat2{}]
    case FourSeats{}:
      [Seat0{}, Seat1{}, Seat2{}, Seat3{}]

# Connected player count: the count Godot's per-count tables are keyed on.
def table.count(table: Table) -> Nat:
  match table:
    case TwoSeats{}:
      2n
    case ThreeSeats{}:
      3n
    case FourSeats{}:
      4n

def ring.fill(-A: Data, table: Table, +x: A) -> Ring<&2, A>:
  match table:
    case TwoSeats{}:
      Duo{x, x}
    case ThreeSeats{}:
      Trio{x, x, x}
    case FourSeats{}:
      Quad{x, x, x, x}

def ring.table(-A: Data, ring: Ring<&2, A>) -> Table:
  match ring:
    case Duo{a, b}:
      TwoSeats{}
    case Trio{a, b, c}:
      ThreeSeats{}
    case Quad{a, b, c, d}:
      FourSeats{}

# None exactly when the seat is not at this table.
def ring.get(-A: Data, ring: Ring<&2, A>, seat: Seat) -> Maybe<&2, A>:
  match ring seat:
    case Duo{a, b} Seat1{}:
      Some{a}
    case Duo{a, b} Seat3{}:
      Some{b}
    case Trio{a, b, c} Seat0{}:
      Some{a}
    case Trio{a, b, c} Seat1{}:
      Some{b}
    case Trio{a, b, c} Seat2{}:
      Some{c}
    case Quad{a, b, c, d} Seat0{}:
      Some{a}
    case Quad{a, b, c, d} Seat1{}:
      Some{b}
    case Quad{a, b, c, d} Seat2{}:
      Some{c}
    case Quad{a, b, c, d} Seat3{}:
      Some{d}
    case _ _:
      None{}

# A seat not at this table leaves the ring unchanged.
def ring.set(-A: Data, ring: Ring<&2, A>, seat: Seat, x: A) -> Ring<&2, A>:
  match ring seat:
    case Duo{a, b} Seat1{}:
      Duo{x, b}
    case Duo{a, b} Seat3{}:
      Duo{a, x}
    case Trio{a, b, c} Seat0{}:
      Trio{x, b, c}
    case Trio{a, b, c} Seat1{}:
      Trio{a, x, c}
    case Trio{a, b, c} Seat2{}:
      Trio{a, b, x}
    case Quad{a, b, c, d} Seat0{}:
      Quad{x, b, c, d}
    case Quad{a, b, c, d} Seat1{}:
      Quad{a, x, c, d}
    case Quad{a, b, c, d} Seat2{}:
      Quad{a, b, x, d}
    case Quad{a, b, c, d} Seat3{}:
      Quad{a, b, c, x}
    case ring _:
      ring

# A value tagged with its seat.
type At<a, -A: Kind(a)> is Kind(a):
  At{seat: Seat, value: A}

def ring.entries(-A: Data, ring: Ring<&2, A>) -> List<&2, At<&2, A>>:
  match ring:
    case Duo{a, b}:
      [At{Seat1{}, a}, At{Seat3{}, b}]
    case Trio{a, b, c}:
      [At{Seat0{}, a}, At{Seat1{}, b}, At{Seat2{}, c}]
    case Quad{a, b, c, d}:
      [At{Seat0{}, a}, At{Seat1{}, b}, At{Seat2{}, c}, At{Seat3{}, d}]

# Shells and items
# ================

type Shell is Data:
  Live{}
  Blank{}

# A shell composition, live count first (D21 tuples are (live, blank)).
type Load is Data:
  Load{live: Nat, blank: Nat}

# Expired medicine (Godot ID 7) is absent: the unmodified customization never
# enables it, so no distribution can grant it (D22).
type Item is Data:
  Saw{}
  Glass{}
  Jammer{}
  Cigarettes{}
  Beer{}
  Phone{}
  Inverter{}
  Adrenaline{}
  Remote{}

# Godot resource-array order 1,2,3,4,5,6,(7),9,8,10. Item-choice draws index
# the eligible subsequence of this list, so its order is part of the tape (D11).
def item.order() -> List<&2, Item>:
  [Saw{}, Glass{}, Jammer{}, Cigarettes{}, Beer{}, Phone{}, Inverter{}, Adrenaline{}, Remote{}]

def item.godot_id(item: Item) -> Nat:
  match item:
    case Saw{}:
      1n
    case Glass{}:
      2n
    case Jammer{}:
      3n
    case Cigarettes{}:
      4n
    case Beer{}:
      5n
    case Phone{}:
      6n
    case Inverter{}:
      9n
    case Adrenaline{}:
      8n
    case Remote{}:
      10n

# At exactly two connected seats the remote is removed from every pool (D22).
def item.dealt_at(table: Table, item: Item) -> Bool:
  match table item:
    case TwoSeats{} Remote{}:
      False{}
    case _ _:
      True{}

# A seat's inventory has eight grid slots (D22).
type Slot is Data:
  Slot0{}
  Slot1{}
  Slot2{}
  Slot3{}
  Slot4{}
  Slot5{}
  Slot6{}
  Slot7{}

type Slots is Data:
  Slots{s0: Maybe<&2, Item>, s1: Maybe<&2, Item>, s2: Maybe<&2, Item>, s3: Maybe<&2, Item>, s4: Maybe<&2, Item>, s5: Maybe<&2, Item>, s6: Maybe<&2, Item>, s7: Maybe<&2, Item>}

def slots.empty() -> Slots:
  Slots{None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}}

def slots.get(slots: Slots, slot: Slot) -> Maybe<&2, Item>:
  match slots slot:
    case Slots{a, b, c, d, e, f, g, h} Slot0{}:
      a
    case Slots{a, b, c, d, e, f, g, h} Slot1{}:
      b
    case Slots{a, b, c, d, e, f, g, h} Slot2{}:
      c
    case Slots{a, b, c, d, e, f, g, h} Slot3{}:
      d
    case Slots{a, b, c, d, e, f, g, h} Slot4{}:
      e
    case Slots{a, b, c, d, e, f, g, h} Slot5{}:
      f
    case Slots{a, b, c, d, e, f, g, h} Slot6{}:
      g
    case Slots{a, b, c, d, e, f, g, h} Slot7{}:
      h

# Match configuration
# ===================

# A positive count: Pos{minus_one} is 1 + minus_one. Used where zero would be an
# engine failure rather than a rule (zero starting health, an empty load).
type Pos is Data:
  Pos{minus_one: Nat}

def pos.nat(p: Pos) -> Nat:
  match p:
    case Pos{n}:
      1n+n

type HealthRule is Data:
  RandomHealth{}
  FixedHealth{health: Pos}

# A fixed load always has at least one shell (D23: the UI offers totals 1..10).
type ShellRule is Data:
  RandomShells{}
  FixedShells{live: Nat, blank: Pos}
  AllLive{live: Pos}

type AmountRule is Data:
  RandomAmount{}
  FixedAmount{amount: Nat}

type LoadRule is Data:
  LoadRule{shells: ShellRule, items: AmountRule}

# One rule per per-load index 0..3; the index cycles 0,1,2,3,0.. (D14).
type LoadRules is Data:
  LoadRules{l0: LoadRule, l1: LoadRule, l2: LoadRule, l3: LoadRule}

type ItemRule is Data:
  ItemRule{enabled: Bool, per_player: Nat, on_table: Nat}

# Fields in item.order().
type ItemRules is Data:
  ItemRules{saw: ItemRule, glass: ItemRule, jammer: ItemRule, cigarettes: ItemRule, beer: ItemRule, phone: ItemRule, inverter: ItemRule, adrenaline: ItemRule, remote: ItemRule}

type RoundRules is Data:
  RoundRules{health: HealthRule, loads: LoadRules, items: ItemRules}

# The UI offers one to three rounds (D23); the type has no other lengths.
type Plan is Data:
  OneRound{r0: RoundRules}
  TwoRounds{r0: RoundRules, r1: RoundRules}
  ThreeRounds{r0: RoundRules, r1: RoundRules, r2: RoundRules}

type Config is Data:
  Config{table: Table, plan: Plan}

def rules.item(rules: ItemRules, item: Item) -> ItemRule:
  match rules item:
    case ItemRules{a, b, c, d, e, f, g, h, i} Saw{}:
      a
    case ItemRules{a, b, c, d, e, f, g, h, i} Glass{}:
      b
    case ItemRules{a, b, c, d, e, f, g, h, i} Jammer{}:
      c
    case ItemRules{a, b, c, d, e, f, g, h, i} Cigarettes{}:
      d
    case ItemRules{a, b, c, d, e, f, g, h, i} Beer{}:
      e
    case ItemRules{a, b, c, d, e, f, g, h, i} Phone{}:
      f
    case ItemRules{a, b, c, d, e, f, g, h, i} Inverter{}:
      g
    case ItemRules{a, b, c, d, e, f, g, h, i} Adrenaline{}:
      h
    case ItemRules{a, b, c, d, e, f, g, h, i} Remote{}:
      i

# Rounds in the plan; the final round index is this minus one (D25).
def plan.length(plan: Plan) -> Nat:
  match plan:
    case OneRound{a}:
      1n
    case TwoRounds{a, b}:
      2n
    case ThreeRounds{a, b, c}:
      3n

def plan.round(plan: Plan, index: Nat) -> Maybe<&2, RoundRules>:
  match plan index:
    case OneRound{a} 0n:
      Some{a}
    case TwoRounds{a, b} 0n:
      Some{a}
    case TwoRounds{a, b} 1n:
      Some{b}
    case ThreeRounds{a, b, c} 0n:
      Some{a}
    case ThreeRounds{a, b, c} 1n:
      Some{b}
    case ThreeRounds{a, b, c} 2n:
      Some{c}
    case _ _:
      None{}

# MP_MatchCustomization defaults (D22, D23).
def config.default_items() -> ItemRules:
  ItemRules{ItemRule{True{}, 2n, 32n}, ItemRule{True{}, 2n, 32n}, ItemRule{True{}, 1n, 1n}, ItemRule{True{}, 1n, 32n}, ItemRule{True{}, 8n, 32n}, ItemRule{True{}, 8n, 32n}, ItemRule{True{}, 4n, 32n}, ItemRule{True{}, 4n, 32n}, ItemRule{True{}, 1n, 2n}}

def config.default_round() -> RoundRules:
  +load : LoadRule = LoadRule{RandomShells{}, RandomAmount{}}
  RoundRules{RandomHealth{}, LoadRules{load, load, load, load}, config.default_items()}

def config.default(table: Table) -> Config:
  +round : RoundRules = config.default_round()
  Config{table, ThreeRounds{round, round, round}}

# Non-empty lists
# ===============

type NonEmpty<a, -A: Kind(a)> is Kind(a):
  NonEmpty{head: A, tail: List<a, A>}

def nonempty.list(-A: Data, xs: NonEmpty<&2, A>) -> List<&2, A>:
  match xs:
    case NonEmpty{x, rest}:
      x <> rest

def nonempty.length(-A: Data, xs: NonEmpty<&2, A>) -> Nat:
  match xs:
    case NonEmpty{x, rest}:
      1n+List.length(&2, A, rest)

# Per-player-count constants
# ==========================

# A random draw a model must request: the inclusive range lo..lo+extra+1. It
# always holds at least two values. A draw whose range has one value cannot
# affect play, so it is never a request: the model uses that value directly
# (D11, Phase 1 amendment; Godot's randi_range(a, a) reads no RNG word either).
type Range is Data:
  Range{lo: Nat, extra: Nat}

# The request range for lo..lo+width, or None when that range has one value
# and the caller uses lo with no request.
def range.of(lo: Nat, width: Nat) -> Maybe<&2, Range>:
  match width:
    case 0n:
      None{}
    case 1n+extra:
      Some{Range{lo, extra}}

# Ordered sequence-batch resources (D21). Draws index this order.
def table.deck(table: Table) -> List<&2, Load>:
  match table:
    case TwoSeats{}:
      [Load{1n, 2n}, Load{2n, 1n}, Load{2n, 2n}, Load{3n, 2n}, Load{1n, 1n}, Load{2n, 3n}, Load{3n, 3n}, Load{3n, 1n}, Load{4n, 2n}]
    case ThreeSeats{}:
      [Load{2n, 3n}, Load{3n, 2n}, Load{3n, 3n}, Load{4n, 3n}, Load{2n, 2n}, Load{3n, 4n}, Load{4n, 4n}, Load{4n, 2n}, Load{3n, 1n}, Load{1n, 1n}]
    case FourSeats{}:
      [Load{3n, 4n}, Load{3n, 2n}, Load{3n, 3n}, Load{4n, 3n}, Load{2n, 2n}, Load{3n, 4n}, Load{4n, 4n}, Load{4n, 2n}, Load{3n, 1n}, Load{2n, 1n}]

# Random starting health: 2 seats 3..4, 3 seats 4..5, 4 seats 3..5 (D23).
def table.health_range(table: Table) -> Range:
  match table:
    case TwoSeats{}:
      Range{3n, 0n}
    case ThreeSeats{}:
      Range{4n, 0n}
    case FourSeats{}:
      Range{3n, 1n}

# Random items per distribution: 2 seats 2..4, 3 seats 3..5, 4 seats 3..4 (D23).
def table.amount_range(table: Table) -> Range:
  match table:
    case TwoSeats{}:
      Range{2n, 1n}
    case ThreeSeats{}:
      Range{3n, 1n}
    case FourSeats{}:
      Range{3n, 0n}

# Round prize by round index, not by plan length (D25).
def prize(round: Nat) -> U32:
  match round:
    case 0n:
      70000
    case 1n:
      75000
    case 2n:
      80000
    case _:
      0

# The phone announces at most the seventh shell (D28).
def phone.cap() -> Nat:
  7n

# Moves
# =====

# A move an unmodified client can make (D37), one constructor per canonical
# packet kind (D32, D50). Item identity is the nominated slot's actual item.
# A Move value alone is not evidence of legality: legal moves exist only as
# entries of a Choose request, and callers answer with an index.
type Move is Data:
  PickUp{}
  Shoot{target: Seat}
  UseItem{slot: Slot, item: Item}
  Grab{}
  Place{slot: Slot}
  JamTarget{target: Seat}
  Steal{owner: Seat, slot: Slot, item: Item}

def item.eq(a: Item, b: Item) -> Bool:
  Nat.is_eq(item.godot_id(a), item.godot_id(b))

def slot.code(slot: Slot) -> Nat:
  match slot:
    case Slot0{}:
      0n
    case Slot1{}:
      1n
    case Slot2{}:
      2n
    case Slot3{}:
      3n
    case Slot4{}:
      4n
    case Slot5{}:
      5n
    case Slot6{}:
      6n
    case Slot7{}:
      7n

def slot.eq(a: Slot, b: Slot) -> Bool:
  Nat.is_eq(slot.code(a), slot.code(b))

def move.eq(a: Move, b: Move) -> Bool:
  match a b:
    case PickUp{} PickUp{}:
      True{}
    case Shoot{s} Shoot{t}:
      seat.eq(s, t)
    case UseItem{s, i} UseItem{t, j}:
      Bool.and(slot.eq(s, t), item.eq(i, j))
    case Grab{} Grab{}:
      True{}
    case Place{s} Place{t}:
      slot.eq(s, t)
    case JamTarget{s} JamTarget{t}:
      seat.eq(s, t)
    case Steal{o, s, i} Steal{p, t, j}:
      Bool.and(seat.eq(o, p), Bool.and(slot.eq(s, t), item.eq(i, j)))
    case _ _:
      False{}

def menu.find.here(hit: Bool, rest: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match hit rest:
    case True{} _:
      Some{0n}
    case False{} None{}:
      None{}
    case False{} Some{k}:
      Some{1n+k}

# Where a wanted move sits in a menu, if it is legal now.
def menu.find(moves: List<&2, Move>, +wanted: Move) -> Maybe<&2, Nat>:
  match moves:
    case Nil{}:
      None{}
    case m <> rest:
      menu.find.here(move.eq(m, wanted), menu.find(rest, wanted))

# Requests and answers
# ====================

# The semantic draw sites, in Godot call order (D11).
type Label is Data:
  FirstSeat{}
  StartingHealth{}
  ItemAmount{}
  ItemChoice{}
  SequenceBatch{}
  ShuffleSwap{}
  PhoneIndex{}

# What a model needs before it can continue. Every request is answered by one
# Nat from the same tape.
#   Draw: a labelled random range of at least two values. A shuffle of n
#     shells is one ShuffleSwap request per Fisher-Yates step, j in 0..i for
#     i = n-1 down to 1 (range Range{0, i-1}), swapping positions i and j in
#     Godot 4.1 order. Any answer sequence is a permutation.
#   Choose: each configured seat's legal moves, in the canonical order the
#     producing model must use (ascending socket, then the order the moves are
#     listed by D37's table: pickup, uses by slot, shots by socket, grab,
#     places by slot, jam targets by socket, steals by owner then slot). A seat
#     with no move has Nil. Several seats can be non-empty while grabbing.
#     Build it with request.choose, never directly.
#   Finished: the match concluded (D47). No answer is read.
#   Stuck: no seat has a legal move and no rule can continue (D53), or the
#     reference ran out of dispatcher fuel. Laws require the machine never to
#     reach it in normal play; a driver reports it as an invariant failure.
type Request is Data:
  Draw{label: Label, range: Range}
  Choose{menus: Ring<&2, List<&2, Move>>}
  Finished{}
  Stuck{}

# A normalized Choose answer: the seat, the move's index in that seat's menu,
# and the move. Models act on (seat, index) against their own typed menus.
type Choice is Data:
  Choice{seat: Seat, index: Nat, move: Move}

type Resolved is Data:
  Drawn{value: Nat}
  Chose{choice: Choice}
  Unanswerable{}

# min(n, top) by structural recursion, so proofs need no division lemma.
# Every Nat therefore names an in-range answer.
def clamp(n: Nat, top: Nat) -> Nat:
  match n top:
    case 0n _:
      0n
    case 1n+p 0n:
      0n
    case 1n+p 1n+t:
      1n+clamp(p, t)

def draw.value(range: Range, n: Nat) -> Nat:
  match range:
    case Range{lo, extra}:
      Nat.add(lo, clamp(n, 1n+extra))

def choices.of(moves: List<&2, Move>, +seat: Seat, +index: Nat) -> List<&2, Choice>:
  match moves:
    case Nil{}:
      Nil{}
    case m <> rest:
      Choice{seat, index, m} <> choices.of(rest, seat, 1n+index)

def choices.flatten(entries: List<&2, At<&2, List<&2, Move>>>) -> List<&2, Choice>:
  match entries:
    case Nil{}:
      Nil{}
    case At{seat, moves} <> rest:
      List.append(&2, Choice, choices.of(moves, seat, 0n), choices.flatten(rest))

def choices.nth(xs: List<&2, Choice>, n: Nat) -> Maybe<&2, Choice>:
  match xs n:
    case Nil{} _:
      None{}
    case c <> Nil{} _:
      Some{c}
    case c <> rest 0n:
      Some{c}
    case c <> rest 1n+p:
      choices.nth(rest, p)

# The flat answer index runs over all seats' menus in ring order. Past the end
# it clamps to the last move. None only when every menu is empty.
def choose(menus: Ring<&2, List<&2, Move>>, n: Nat) -> Maybe<&2, Choice>:
  choices.nth(choices.flatten(ring.entries(List<&2, Move>, menus)), n)

def resolve.choice(picked: Maybe<&2, Choice>) -> Resolved:
  match picked:
    case None{}:
      Unanswerable{}
    case Some{c}:
      Chose{c}

# The one answer normalization both models apply.
def resolve(request: Request, n: Nat) -> Resolved:
  match request:
    case Draw{label, range}:
      Drawn{draw.value(range, n)}
    case Choose{menus}:
      resolve.choice(choose(menus, n))
    case Finished{}:
      Unanswerable{}
    case Stuck{}:
      Unanswerable{}

def menus.any(entries: List<&2, At<&2, List<&2, Move>>>) -> Bool:
  match entries:
    case Nil{}:
      False{}
    case At{s, Nil{}} <> rest:
      menus.any(rest)
    case At{s, m <> ms} <> rest:
      True{}

def request.choose.any(any: Bool, menus: Ring<&2, List<&2, Move>>) -> Request:
  match any:
    case True{}:
      Choose{menus}
    case False{}:
      Stuck{}

# Smart constructor: a Choose request always offers at least one move.
def request.choose(+menus: Ring<&2, List<&2, Move>>) -> Request:
  request.choose.any(menus.any(ring.entries(List<&2, Move>, menus)), menus)

# Prompts
# =======

# One active seat's part of a Choose request. It exists only for a seat with
# at least one legal move. `first` is the flat answer index of the menu's head
# in the request it was built from. A controller (AI or human) answers with an
# index into its own menu; prompt.answer lifts it to the tape answer.
type Prompt is Data:
  Prompt{seat: Seat, first: Nat, menu: NonEmpty<&2, Move>}

def prompts.go(entries: List<&2, At<&2, List<&2, Move>>>, +first: Nat) -> List<&2, Prompt>:
  match entries:
    case Nil{}:
      Nil{}
    case At{seat, Nil{}} <> rest:
      prompts.go(rest, first)
    case At{seat, m <> ms} <> rest:
      +menu : NonEmpty<&2, Move> = NonEmpty{m, ms}
      Prompt{seat, first, menu} <> prompts.go(rest, Nat.add(first, nonempty.length(Move, menu)))

# Every active seat's prompt, in ascending socket order. Seats with no move
# get none. Nil for a Draw, Finished or Stuck request.
def prompts(request: Request) -> List<&2, Prompt>:
  match request:
    case Choose{menus}:
      prompts.go(ring.entries(List<&2, Move>, menus), 0n)
    case _:
      Nil{}

def prompt.pick(mine: Bool, prompt: Prompt, rest: Maybe<&2, Prompt>) -> Maybe<&2, Prompt>:
  match mine:
    case True{}:
      Some{prompt}
    case False{}:
      rest

def prompt.find(found: List<&2, Prompt>, +seat: Seat) -> Maybe<&2, Prompt>:
  match found:
    case Nil{}:
      None{}
    case Prompt{+s, first, menu} <> rest:
      prompt.pick(seat.eq(s, seat), Prompt{s, first, menu}, prompt.find(rest, seat))

# The seat's prompt, or None when the seat has no legal move now. A driver asks
# a controller to decide only when this is Some.
def prompt.of(request: Request, +seat: Seat) -> Maybe<&2, Prompt>:
  prompt.find(prompts(request), seat)

# The tape answer for the prompt's k-th move, k clamped to its last move. The
# result stays inside this prompt's own block of the flat index, so it can
# never select another seat's move: resolve on the request the prompt came from
# returns Choice{prompt.seat, clamp(k, length - 1), that move}.
def prompt.answer(prompt: Prompt, k: Nat) -> Nat:
  match prompt:
    case Prompt{seat, first, NonEmpty{m, ms}}:
      Nat.add(first, clamp(k, List.length(&2, Move, ms)))

# Where a wanted move sits in the prompt's menu, if it is legal now. This is
# how a controller states intent ("shoot seat 2") and still answers with an
# index.
def prompt.index(prompt: Prompt, +wanted: Move) -> Maybe<&2, Nat>:
  match prompt:
    case Prompt{seat, first, menu}:
      menu.find(nonempty.list(Move, menu), wanted)

# Observation
# ===========

# A seat's health counter and jam state as every client shows them, in one
# value. Jammer_Enable sets is_jammed and hides the counter; only Jammer_Disable
# clears is_jammed and shows it again; Jammer_Check flickers it and ends hidden
# (MP_Jammer.gd:53-77, D27). Round start unjams every seat through
# Jammer_Disable (MP_RoundManager.gd:231). So at every request point the
# counter is hidden exactly while the seat is jammed. D26 requires display
# visibility and the health value to be separate because request points occur
# while it is hidden: here the visibility is the constructor and the value
# exists only while visible. A jammed seat's logical health stays public only
# through earlier events (Fired, Healed, RoundBegan), as D27 states. The
# jammer_checked bit is model-private and has no public field.
type Counter is Data:
  Unjammed{health: Nat}
  Jammed{}

# The one way both models build a seat's counter.
def counter.of(jammed: Bool, health: Nat) -> Counter:
  match jammed:
    case True{}:
      Jammed{}
    case False{}:
      Unjammed{health}

# A seat's part in item distribution (D37 grabbing rows).
type Briefcase is Data:
  NotGrabbing{}
  Grabbing{}
  Holding{item: Item}

type SeatView is Data:
  SeatView{counter: Counter, slots: Slots, cash: U32, briefcase: Briefcase}

type Direction is Data:
  Clockwise{}
  CounterClockwise{}

# Remaining live/blank counts are not public: an inverter changes the split
# without revealing it (D29). Only the count and the last shown load are.
type GunView is Data:
  GunView{shown: Load, remaining: Nat, sawed: Bool}

type RoundView is Data:
  RoundView{index: Nat, rounds: Nat, health: Nat}

type Mode is Data:
  Idle{}
  Aiming{}
  Jamming{}
  Stealing{}

type Stage is Data:
  Setup{}
  Distributing{}
  Loading{}
  Playing{seat: Seat, mode: Mode}
  MatchOver{}

# The public table: what every unmodified client shows (D26, D27, D29).
# Shell order, the remaining deck, the item amount and every private result
# are absent by type. Nothing here is per-seat private.
type Board is Data:
  Board{round: RoundView, seats: Ring<&2, SeatView>, gun: GunView, direction: Direction, stage: Stage}

# What a model exposes at a request point. Both models compute it from their
# own state; observation agreement and legal-moves-exact are one equality of
# Points. A Point is controller data: a Draw's range can reveal deck size or
# remaining length, so privacy laws are stated on observe and hear, never on
# a whole Point.
type Point is Data:
  Point{request: Request, board: Board}

# A seat's observation: the public board only. Private knowledge reaches a
# seat as Heard secrets; its legal moves reach it as a Prompt.
type Obs is Data:
  Obs{me: Seat, board: Board}

def observe(point: Point, seat: Seat) -> Obs:
  match point:
    case Point{request, board}:
      Obs{seat, board}

# Events
# ======

# Damage a shot captured at host acceptance from the saw bool (D15). A blank
# captures it too and applies none.
type Damage is Data:
  Single{}
  Double{}

def damage.amount(damage: Damage) -> Nat:
  match damage:
    case Single{}:
      1n
    case Double{}:
      2n

# Public events, in rule-effect order (D51). Rich enough for the web UI to
# compute end-of-match titles itself (D19, D48): Fired carries the captured
# damage the source's badge counter reads and the applied damage after the
# clamp to zero, so both are auditable; self-live shots are Fired with
# shooter == target; deaths come from Died, cigarettes and items used from
# Used (a steal has owner != seat), cash from RoundWon.
type GameEvent is Data:
  RoundBegan{round: Nat, health: Nat, first: Seat}
  GrabbingBegan{seats: List<&2, Seat>}
  Granted{seat: Seat, item: Item}
  Placed{seat: Seat, slot: Slot, item: Item}
  GrabbingEnded{seat: Seat}
  DistributionDone{}
  Loaded{load: Load}
  TurnSkipped{seat: Seat}
  JamLifted{seat: Seat}
  TurnGiven{seat: Seat}
  PickedUp{seat: Seat}
  Fired{shooter: Seat, target: Seat, shell: Shell, captured: Damage, applied: Nat, health: Nat}
  Died{seat: Seat}
  Used{seat: Seat, owner: Seat, slot: Slot, item: Item}
  Healed{seat: Seat, health: Nat}
  Ejected{seat: Seat, shell: Shell}
  Inverted{seat: Seat}
  JamApplied{by: Seat, target: Seat}
  DirectionFlipped{direction: Direction}
  RoundWon{seat: Seat, prize: U32}
  MatchConcluded{}

# Results shown only to one seat (D28, D37 empty-pool grab).
type Secret is Data:
  Glimpse{shell: Shell}
  Clue{position: Nat, shell: Shell}
  NoClue{}
  EmptyBriefcase{}

# A model's output for one answer.
type Note is Data:
  Shown{event: GameEvent}
  Told{seat: Seat, secret: Secret}

# What one seat receives. It has no seat field, so another seat's secret has
# nowhere to go.
type Heard is Data:
  Witnessed{event: GameEvent}
  Learned{secret: Secret}

def hear.told(mine: Bool, secret: Secret, rest: List<&2, Heard>) -> List<&2, Heard>:
  match mine:
    case True{}:
      Learned{secret} <> rest
    case False{}:
      rest

def hear.put(+me: Seat, note: Note, rest: List<&2, Heard>) -> List<&2, Heard>:
  match note:
    case Shown{event}:
      Witnessed{event} <> rest
    case Told{seat, secret}:
      hear.told(seat.eq(seat, me), secret, rest)

# The only way a seat's controller sees notes: every public event and the
# secrets addressed to that seat, in order.
def hear(notes: List<&2, Note>, +me: Seat) -> List<&2, Heard>:
  match notes:
    case Nil{}:
      Nil{}
    case note <> rest:
      hear.put(me, note, hear(rest, me))

def public_events.put(note: Note, rest: List<&2, GameEvent>) -> List<&2, GameEvent>:
  match note:
    case Shown{event}:
      event <> rest
    case Told{seat, secret}:
      rest

# What a spectator reads: every public event, no secret.
def public_events(notes: List<&2, Note>) -> List<&2, GameEvent>:
  match notes:
    case Nil{}:
      Nil{}
    case note <> rest:
      public_events.put(note, public_events(rest))

# Model boundary
# ==============

# Both models (ref/ and sm/) export the same four functions over their own
# private State type S. Nothing else of a model is public.
#   start(config: Config) -> Stepped<S>     setup up to the first request point
#   point(state: S) -> Point                 the request and the public board
#   answer(state: S, n: Nat) -> Stepped<S>   resolve(point.request, n), apply it,
#                                            run silently to the next request point
#   run(fuel: Nat, state: S, tape: List<&2, Nat>) -> Ran<S>
#                                            one fuel per tape answer; stops at
#                                            Finished, Stuck, an empty tape or fuel 0
# answer on a Finished or Stuck point returns the state unchanged with no notes.
type Stepped<a, -S: Kind(a)> is Kind(a):
  Stepped{state: S, notes: List<&2, Note>}

type Ran<a, -S: Kind(a)> is Kind(a):
  Ran{state: S, notes: List<&2, Note>, tape: List<&2, Nat>}

# What a controller returns for a Prompt: an index into that prompt's menu
# (any Nat; prompt.answer clamps it) and its next memory. M is private to each
# AI. Controllers are asked only through a Prompt, never with a bare seat.
type Decision<a, -M: Kind(a)> is Kind(a):
  Decision{pick: Nat, memory: M}
