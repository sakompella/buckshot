import Base
import ./domain.bend as D

def seated(table: D.Table, seat: D.Seat) -> Data:
  match table seat:
    case D.TwoSeats{} D.Seat1{}:
      Unit
    case D.TwoSeats{} D.Seat3{}:
      Unit
    case D.ThreeSeats{} D.Seat0{}:
      Unit
    case D.ThreeSeats{} D.Seat1{}:
      Unit
    case D.ThreeSeats{} D.Seat2{}:
      Unit
    case D.FourSeats{} _:
      Unit
    case _ _:
      Empty

law pickup_resolves:
  for +table: D.Table
  for +seat: D.Seat
  for n: Nat
  for +present: seated(table, seat)
  {D.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}]), n) == Some{D.Choice{seat, 0n, D.PickUp{}}} : Maybe<&2, D.Choice>}

def single_choice(+seat: D.Seat, n: Nat) -> {D.choices.nth([D.Choice{seat, 0n, D.PickUp{}}], n) == Some{D.Choice{seat, 0n, D.PickUp{}}} : Maybe<&2, D.Choice>}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      {==}

def pickup_resolves(table, seat, n, present):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      match present:
    case D.TwoSeats{} D.Seat1{}:
      single_choice(D.Seat1{}, n)
    case D.TwoSeats{} D.Seat2{}:
      match present:
    case D.TwoSeats{} D.Seat3{}:
      single_choice(D.Seat3{}, n)
    case D.ThreeSeats{} D.Seat0{}:
      single_choice(D.Seat0{}, n)
    case D.ThreeSeats{} D.Seat1{}:
      single_choice(D.Seat1{}, n)
    case D.ThreeSeats{} D.Seat2{}:
      single_choice(D.Seat2{}, n)
    case D.ThreeSeats{} D.Seat3{}:
      match present:
    case D.FourSeats{} D.Seat0{}:
      single_choice(D.Seat0{}, n)
    case D.FourSeats{} D.Seat1{}:
      single_choice(D.Seat1{}, n)
    case D.FourSeats{} D.Seat2{}:
      single_choice(D.Seat2{}, n)
    case D.FourSeats{} D.Seat3{}:
      single_choice(D.Seat3{}, n)


def pickup_request(+table: D.Table, +seat: D.Seat) -> D.Request:
  D.request.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}]))

law pickup_request_choose:
  for +table: D.Table
  for +seat: D.Seat
  for +present: seated(table, seat)
  {pickup_request(table, seat) == D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])} : D.Request}

def pickup_request_choose(table, seat, present):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      match present:
    case D.TwoSeats{} D.Seat1{}:
      {==}
    case D.TwoSeats{} D.Seat2{}:
      match present:
    case D.TwoSeats{} D.Seat3{}:
      {==}
    case D.ThreeSeats{} D.Seat0{}:
      {==}
    case D.ThreeSeats{} D.Seat1{}:
      {==}
    case D.ThreeSeats{} D.Seat2{}:
      {==}
    case D.ThreeSeats{} D.Seat3{}:
      match present:
    case D.FourSeats{} D.Seat0{}:
      {==}
    case D.FourSeats{} D.Seat1{}:
      {==}
    case D.FourSeats{} D.Seat2{}:
      {==}
    case D.FourSeats{} D.Seat3{}:
      {==}

def pickup_choose_resolved(+table: D.Table, +seat: D.Seat, +n: Nat, present: seated(table, seat)) -> {D.resolve(D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, n) == D.Chose{D.Choice{seat, 0n, D.PickUp{}}} : D.Resolved}:
  Equal.cong(Maybe<&2, D.Choice>, D.Resolved, picked => D.resolve.choice(picked), D.choose(D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}]), n), Some{D.Choice{seat, 0n, D.PickUp{}}}, pickup_resolves(table, seat, n, present))

def pickup_choose_resolved_backwards(+table: D.Table, +seat: D.Seat, +n: Nat, present: seated(table, seat)) -> {D.Chose{D.Choice{seat, 0n, D.PickUp{}}} == D.resolve(D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, n) : D.Resolved}:
  %pickup_choose_resolved(table, seat, n, present) : {_ == D.resolve(D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, n) : D.Resolved}
  {==}


law pickup_resolved:
  for +table: D.Table
  for +seat: D.Seat
  for +n: Nat
  for +present: seated(table, seat)
  {D.resolve(pickup_request(table, seat), n) == D.Chose{D.Choice{seat, 0n, D.PickUp{}}} : D.Resolved}

def pickup_resolved(table, seat, n, present):
  Equal.trans(D.Resolved, D.resolve(pickup_request(table, seat), n), D.resolve(D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, n), D.Chose{D.Choice{seat, 0n, D.PickUp{}}}, Equal.cong(D.Request, D.Resolved, request => D.resolve(request, n), pickup_request(table, seat), D.Choose{D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, [D.PickUp{}])}, pickup_request_choose(table, seat, present)), pickup_choose_resolved(table, seat, n, present))

def pickup_resolved_backwards(+table: D.Table, +seat: D.Seat, +n: Nat, present: seated(table, seat)) -> {D.Chose{D.Choice{seat, 0n, D.PickUp{}}} == D.resolve(pickup_request(table, seat), n) : D.Resolved}:
  %pickup_resolved(table, seat, n, present) : {_ == D.resolve(pickup_request(table, seat), n) : D.Resolved}
  {==}

def seat_self_backwards(+seat: D.Seat) -> {True{} == D.seat.eq(seat, seat) : Bool}:
  match seat:
    case D.Seat0{}:
      {==}
    case D.Seat1{}:
      {==}
    case D.Seat2{}:
      {==}
    case D.Seat3{}:
      {==}


def append_nil_choices(+xs: List<&2, D.Choice>) -> {List.append(&2, D.Choice, xs, Nil{}) == xs : List<&2, D.Choice>}:
  match xs:
    case Nil{}:
      {==}
    case +choice <> +rest:
      Equal.cong(List<&2, D.Choice>, List<&2, D.Choice>, tail => choice <> tail, List.append(&2, D.Choice, rest, Nil{}), rest, append_nil_choices(rest))

law one_menu_choices:
  for +table: D.Table
  for +seat: D.Seat
  for +moves: List<&2, D.Move>
  for present: seated(table, seat)
  {D.choices.flatten(D.ring.entries(List<&2, D.Move>, D.ring.set(List<&2, D.Move>, D.ring.fill(List<&2, D.Move>, table, Nil{}), seat, moves))) == D.choices.of(moves, seat, 0n) : List<&2, D.Choice>}

def one_menu_choices(table, seat, moves, present):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      match present:
    case D.TwoSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.TwoSeats{} D.Seat2{}:
      match present:
    case D.TwoSeats{} D.Seat3{}:
      append_nil_choices(D.choices.of(moves, D.Seat3{}, 0n))
    case D.ThreeSeats{} D.Seat0{}:
      append_nil_choices(D.choices.of(moves, D.Seat0{}, 0n))
    case D.ThreeSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.ThreeSeats{} D.Seat2{}:
      append_nil_choices(D.choices.of(moves, D.Seat2{}, 0n))
    case D.ThreeSeats{} D.Seat3{}:
      match present:
    case D.FourSeats{} D.Seat0{}:
      append_nil_choices(D.choices.of(moves, D.Seat0{}, 0n))
    case D.FourSeats{} D.Seat1{}:
      append_nil_choices(D.choices.of(moves, D.Seat1{}, 0n))
    case D.FourSeats{} D.Seat2{}:
      append_nil_choices(D.choices.of(moves, D.Seat2{}, 0n))
    case D.FourSeats{} D.Seat3{}:
      append_nil_choices(D.choices.of(moves, D.Seat3{}, 0n))
