import Base
import ./domain.bend as D
import ./abstract.bend as A
import ./sm/main.bend as M
import ./sm/state.bend as S
import ./sm/items.bend as I
import ./sm/rules.bend as G
import ./simple/main.bend as N
import ./simple/state.bend as T
import ./simple/point.bend as P
import ./simple-abstract.bend as SA
import ./simple-step-proof.bend as C
import ./simple-walk-proof.bend as Wk

# The simple machine's grab policy (simple/main.bend) is the schedule
# simple-abstract.bend states over sm's menus.

def cell(+needs: D.Ring<&2, List<&2, S.GrabOption>>, seat: D.Seat) -> List<&2, S.GrabOption>:
  G.value.or(List<&2, S.GrabOption>, D.ring.get(List<&2, S.GrabOption>, needs, seat), Nil{})

def render(next: N.Distribution) -> Maybe<&2, SA.Step>:
  match next:
    case N.Taking{seat}:
      Some{SA.ChoiceStep{seat, D.Grab{}}}
    case N.Placing{seat, slot}:
      Some{SA.ChoiceStep{seat, D.Place{slot}}}
    case _:
      None{}

def order.eq(table: D.Table, after: D.Seat) -> {N.seats.after(D.table.seats(table), after, Nil{}) == SA.order(table, after) : List<&2, D.Seat>}:
  match table after:
    case D.TwoSeats{} D.Seat0{}:
      {==}
    case D.TwoSeats{} D.Seat1{}:
      {==}
    case D.TwoSeats{} D.Seat2{}:
      {==}
    case D.TwoSeats{} D.Seat3{}:
      {==}
    case D.ThreeSeats{} D.Seat0{}:
      {==}
    case D.ThreeSeats{} D.Seat1{}:
      {==}
    case D.ThreeSeats{} D.Seat2{}:
      {==}
    case D.ThreeSeats{} D.Seat3{}:
      {==}
    case D.FourSeats{} D.Seat0{}:
      {==}
    case D.FourSeats{} D.Seat1{}:
      {==}
    case D.FourSeats{} D.Seat2{}:
      {==}
    case D.FourSeats{} D.Seat3{}:
      {==}

def menu_of.eq(needs: D.Ring<&2, List<&2, S.GrabOption>>, seat: D.Seat) -> {SA.menu.of(I.grab.menus(needs), seat) == I.grab.moves(cell(needs, seat)) : List<&2, D.Move>}:
  match needs seat:
    case D.Duo{a, b} D.Seat0{}:
      {==}
    case D.Duo{a, b} D.Seat1{}:
      {==}
    case D.Duo{a, b} D.Seat2{}:
      {==}
    case D.Duo{a, b} D.Seat3{}:
      {==}
    case D.Trio{a, b, c} D.Seat0{}:
      {==}
    case D.Trio{a, b, c} D.Seat1{}:
      {==}
    case D.Trio{a, b, c} D.Seat2{}:
      {==}
    case D.Trio{a, b, c} D.Seat3{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat0{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat1{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat2{}:
      {==}
    case D.Quad{a, b, c, d} D.Seat3{}:
      {==}

def takes.eq(options: List<&2, S.GrabOption>) -> {SA.menu.takes(I.grab.moves(options)) == N.grab.takes(options) : Bool}:
  match options:
    case Nil{}:
      {==}
    case S.TakeItem{} <> Nil{}:
      {==}
    case S.TakeItem{} <> S.TakeItem{} <> os:
      {==}
    case S.TakeItem{} <> S.PutAt{slot} <> os:
      {==}
    case S.PutAt{slot} <> os:
      {==}

def pick.agree(take: Bool, +seat: D.Seat, +rest_s: Maybe<&2, SA.Step>, +rest_n: N.Distribution, ih: {rest_s == render(rest_n) : Maybe<&2, SA.Step>}) -> {Bool.pick(Maybe<&2, SA.Step>, take, Some{SA.ChoiceStep{seat, D.Grab{}}}, rest_s) == render(Bool.pick(N.Distribution, take, N.Taking{seat}, rest_n)) : Maybe<&2, SA.Step>}:
  match take:
    case True{}:
      {==}
    case False{}:
      ih

def taker.agree(seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>) -> {SA.taker(seats, I.grab.menus(needs)) == render(N.grab.taker(seats, needs)) : Maybe<&2, SA.Step>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> +rest:
      +moves : {SA.menu.takes(SA.menu.of(I.grab.menus(needs), seat)) == N.grab.takes(cell(needs, seat)) : Bool} = Equal.trans(Bool, SA.menu.takes(SA.menu.of(I.grab.menus(needs), seat)), SA.menu.takes(I.grab.moves(cell(needs, seat))), N.grab.takes(cell(needs, seat)), Equal.cong(List<&2, D.Move>, Bool, SA.menu.takes, SA.menu.of(I.grab.menus(needs), seat), I.grab.moves(cell(needs, seat)), menu_of.eq(needs, seat)), takes.eq(cell(needs, seat)))
      %Equal.sym(Bool, SA.menu.takes(SA.menu.of(I.grab.menus(needs), seat)), N.grab.takes(cell(needs, seat)), moves) : {Bool.pick(Maybe<&2, SA.Step>, _, Some{SA.ChoiceStep{seat, D.Grab{}}}, SA.taker(rest, I.grab.menus(needs))) == render(N.grab.taker(seat <> rest, needs)) : Maybe<&2, SA.Step>}
      pick.agree(N.grab.takes(cell(needs, seat)), seat, SA.taker(rest, I.grab.menus(needs)), N.grab.taker(rest, needs), taker.agree(rest, needs))

def own.agree(own: List<&2, S.GrabOption>, +after: D.Seat, +seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>) -> {SA.decide.own(I.grab.moves(own), after, seats, I.grab.menus(needs)) == render(N.grab.act.own(own, seats, needs, after)) : Maybe<&2, SA.Step>}:
  match own:
    case Nil{}:
      taker.agree(seats, needs)
    case S.TakeItem{} <> rest:
      taker.agree(seats, needs)
    case S.PutAt{slot} <> rest:
      {==}

def decide.agree(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +table: D.Table, +after: D.Seat) -> {SA.decide(I.grab.menus(needs), table, after) == render(N.grab.act.own(cell(needs, after), N.seats.after(D.table.seats(table), after, Nil{}), needs, after)) : Maybe<&2, SA.Step>}:
  %Equal.sym(List<&2, D.Move>, SA.menu.of(I.grab.menus(needs), after), I.grab.moves(cell(needs, after)), menu_of.eq(needs, after)) : {SA.decide.own(_, after, SA.order(table, after), I.grab.menus(needs)) == render(N.grab.act.own(cell(needs, after), N.seats.after(D.table.seats(table), after, Nil{}), needs, after)) : Maybe<&2, SA.Step>}
  %order.eq(table, after) : {SA.decide.own(I.grab.moves(cell(needs, after)), after, _, I.grab.menus(needs)) == render(N.grab.act.own(cell(needs, after), N.seats.after(D.table.seats(table), after, Nil{}), needs, after)) : Maybe<&2, SA.Step>}
  own.agree(cell(needs, after), after, N.seats.after(D.table.seats(table), after, Nil{}), needs)

# What the policy's move says about the menus.
def ActView(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +after: D.Seat, +own: List<&2, S.GrabOption>, next: N.Distribution) -> Type:
  match next:
    case N.Taking{seat}:
      {cell(needs, seat) == [S.TakeItem{}] : List<&2, S.GrabOption>}
    case N.Placing{seat, slot}:
      Sigma<&2, &2, {seat == after : D.Seat}, _ => Sigma<&2, &2, List<&2, S.GrabOption>, rest => {own == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}>>
    case N.NoTaker{}:
      Unit
    case _:
      Empty

def options.disc(options: List<&2, S.GrabOption>) -> Type:
  match options:
    case S.TakeItem{} <> Nil{}:
      Unit
    case _:
      Empty

def takes.sound(+options: List<&2, S.GrabOption>, e: {N.grab.takes(options) == True{} : Bool}) -> {options == [S.TakeItem{}] : List<&2, S.GrabOption>}:
  match options:
    case Nil{}:
      Wk.absurd({Nil{} == [S.TakeItem{}] : List<&2, S.GrabOption>}, Wk.bool.clash(e))
    case S.TakeItem{} <> Nil{}:
      {==}
    case S.TakeItem{} <> o <> os:
      Wk.absurd({S.TakeItem{} <> o <> os == [S.TakeItem{}] : List<&2, S.GrabOption>}, Wk.bool.clash(e))
    case S.PutAt{slot} <> os:
      Wk.absurd({S.PutAt{slot} <> os == [S.TakeItem{}] : List<&2, S.GrabOption>}, Wk.bool.clash(e))

def pick.view(+needs: D.Ring<&2, List<&2, S.GrabOption>>, +after: D.Seat, +own: List<&2, S.GrabOption>, +seat: D.Seat, +rest: N.Distribution, take: Bool, eb: {N.grab.takes(cell(needs, seat)) == take : Bool}, ih: ActView(needs, after, own, rest)) -> ActView(needs, after, own, Bool.pick(N.Distribution, take, N.Taking{seat}, rest)):
  match take:
    case True{}:
      takes.sound(cell(needs, seat), eb)
    case False{}:
      ih

def taker.view(seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +after: D.Seat, +own: List<&2, S.GrabOption>) -> ActView(needs, after, own, N.grab.taker(seats, needs)):
  match seats:
    case Nil{}:
      Unit{}
    case +seat <> +rest:
      pick.view(needs, after, own, seat, N.grab.taker(rest, needs), N.grab.takes(cell(needs, seat)), {==}, taker.view(rest, needs, after, own))

def act.view(own: List<&2, S.GrabOption>, +seats: List<&2, D.Seat>, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +after: D.Seat) -> ActView(needs, after, own, N.grab.act.own(own, seats, needs, after)):
  match own:
    case Nil{}:
      taker.view(seats, needs, after, Nil{})
    case S.TakeItem{} <> rest:
      taker.view(seats, needs, after, S.TakeItem{} <> rest)
    case S.PutAt{+slot} <> +rest:
      ({==}, (rest, {==}))

# The distribution loop against sm's walk of the schedule.

def NS(+x: S.State) -> S.State:
  S.state.set_notes(x, Nil{})

def Fin.of(+u: T.State, +y: S.State, walked: Maybe<&2, D.Stepped<&2, S.State>>) -> Data:
  match walked:
    case None{}:
      Empty
    case Some{D.Stepped{z, d}}:
      Sigma<&2, &2, {NS(z) == NS(SA.embed(u)) : S.State}, _ => {T.state.notes(u) == List.append(&2, D.Note, S.state.notes(y), d) : List<&2, D.Note>}>

def Claim(+fuel: Nat, +u: T.State, +y: S.State, +after: D.Seat) -> Data:
  Fin.of(u, y, SA.walk.go(SA.sched.go(fuel, SA.sched.decide(y, after), y), y))

def loop.loading(fuel: Nat, +t: T.State) -> {N.grab.loop(fuel, t, N.Loading{}) == N.load.begin(t) : T.State}:
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      {==}

def loop.drawing(fuel: Nat, +t: T.State) -> {N.grab.loop(fuel, t, N.Drawing{}) == t : T.State}:
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      {==}

def loop.notaker(fuel: Nat, +t: T.State) -> {N.grab.loop(fuel, t, N.NoTaker{}) == T.state.set_phase(t, T.Stalled{}) : T.State}:
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      {==}

def sched.none(fuel: Nat, +x: S.State) -> {SA.sched.go(fuel, None{}, x) == Nil{} : List<&2, SA.Step>}:
  match fuel:
    case 0n:
      {==}
    case 1n+f:
      {==}

def calm.none(+u: T.State, +after: D.Seat, calm: A.Holds(C.calm(T.state.phase(u)))) -> {SA.sched.decide(SA.embed(u), after) == None{} : Maybe<&2, SA.Step>}:
  match u:
    case T.State{w, p, ph, l, g}:
      match ph:
        case T.Stalled{}:
          Wk.absurd({SA.sched.decide(SA.embed(T.State{w, p, T.Stalled{}, l, g}), after) == None{} : Maybe<&2, SA.Step>}, Wk.bool.clash(calm))
        case T.NeedFirst{}:
          {==}
        case T.NeedHealth{}:
          {==}
        case T.NeedAmount{}:
          {==}
        case T.NeedBatch{}:
          {==}
        case T.NeedSwap{a, b, c}:
          {==}
        case T.Idle{s}:
          {==}
        case T.Ended{}:
          {==}
        case T.Blocked{h}:
          {==}
        case T.NeedTurnAmount{a, b, c}:
          {==}
        case T.NeedItem{a, b, c, d}:
          {==}
        case T.NeedPhone{a, b, c}:
          {==}

def claim.direct(+fuel: Nat, +u: T.State, +y: S.State, +after: D.Seat, direct: C.Direct(u, y)) -> Claim(fuel, u, y, after):
  match direct:
    case Tuple{+eq, +calm}:
      %Equal.sym(S.State, y, SA.embed(u), eq) : Claim(fuel, u, _, after)
      %Equal.sym(Maybe<&2, SA.Step>, SA.sched.decide(SA.embed(u), after), None{}, calm.none(u, after, calm)) : Fin.of(u, SA.embed(u), SA.walk.go(SA.sched.go(fuel, _, SA.embed(u)), SA.embed(u)))
      %Equal.sym(List<&2, SA.Step>, SA.sched.go(fuel, None{}, SA.embed(u)), Nil{}, sched.none(fuel, SA.embed(u))) : Fin.of(u, SA.embed(u), SA.walk.go(_, SA.embed(u)))
      ({==}, Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.state.notes(u), Nil{}), T.state.notes(u), Wk.append_nil(D.Note, T.state.notes(u))))

def resolve.disc(r: D.Resolved) -> Type:
  match r:
    case D.Chose{_}:
      Empty
    case _:
      Unit

def resolve.clash(+r: D.Resolved, +choice: D.Choice, e: {r == D.Chose{choice} : D.Resolved}, unchosen: resolve.disc(r)) -> Empty:
  %e : resolve.disc(_)
  unchosen

def choose.answer(+st: S.State, +n: Nat, req: D.Request, +choice: D.Choice, eres: {D.resolve(req, n) == D.Chose{choice} : D.Resolved}) -> {M.answer.request(st, n, req) == S.state.stepped(M.answer.choice(S.state.set_notes(st, Nil{}), choice)) : D.Stepped<&2, S.State>}:
  match req:
    case D.Finished{}:
      Wk.absurd({M.answer.request(st, n, D.Finished{}) == S.state.stepped(M.answer.choice(S.state.set_notes(st, Nil{}), choice)) : D.Stepped<&2, S.State>}, resolve.clash(D.Unanswerable{}, choice, eres, Unit{}))
    case D.Stuck{}:
      Wk.absurd({M.answer.request(st, n, D.Stuck{}) == S.state.stepped(M.answer.choice(S.state.set_notes(st, Nil{}), choice)) : D.Stepped<&2, S.State>}, resolve.clash(D.Unanswerable{}, choice, eres, Unit{}))
    case D.Draw{label, range}:
      Wk.absurd({M.answer.request(st, n, D.Draw{label, range}) == S.state.stepped(M.answer.choice(S.state.set_notes(st, Nil{}), choice)) : D.Stepped<&2, S.State>}, resolve.clash(D.Drawn{D.draw.value(range, n)}, choice, eres, Unit{}))
    case D.Choose{+menus}:
      %Equal.sym(D.Resolved, D.resolve(D.Choose{menus}, n), D.Chose{choice}, eres) : {S.state.stepped(M.answer.resolved(S.state.set_notes(st, Nil{}), _)) == S.state.stepped(M.answer.choice(S.state.set_notes(st, Nil{}), choice)) : D.Stepped<&2, S.State>}
      {==}

def nil.disc(xs: List<&2, S.GrabOption>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case _:
      Empty

def nil.clash(+x: S.GrabOption, +xs: List<&2, S.GrabOption>, e: {Nil{} == x <> xs : List<&2, S.GrabOption>}) -> Empty:
  %e : nil.disc(_)
  Unit{}

def menus.get(needs: D.Ring<&2, List<&2, S.GrabOption>>, seat: D.Seat, +x: S.GrabOption, +xs: List<&2, S.GrabOption>, e: {cell(needs, seat) == x <> xs : List<&2, S.GrabOption>}) -> {D.ring.get(List<&2, D.Move>, I.grab.menus(needs), seat) == Some{I.grab.moves(x <> xs)} : Maybe<&2, List<&2, D.Move>>}:
  match needs seat:
    case D.Duo{+a, +b} D.Seat0{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, I.grab.menus(D.Duo{a, b}), D.Seat0{}) == Some{I.grab.moves(x <> xs)} : Maybe<&2, List<&2, D.Move>>}, nil.clash(x, xs, e))
    case D.Duo{+a, +b} D.Seat1{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, a, x <> xs, e)
    case D.Duo{+a, +b} D.Seat2{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, I.grab.menus(D.Duo{a, b}), D.Seat2{}) == Some{I.grab.moves(x <> xs)} : Maybe<&2, List<&2, D.Move>>}, nil.clash(x, xs, e))
    case D.Duo{+a, +b} D.Seat3{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, b, x <> xs, e)
    case D.Trio{+a, +b, +c} D.Seat0{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, a, x <> xs, e)
    case D.Trio{+a, +b, +c} D.Seat1{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, b, x <> xs, e)
    case D.Trio{+a, +b, +c} D.Seat2{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, c, x <> xs, e)
    case D.Trio{+a, +b, +c} D.Seat3{}:
      Wk.absurd({D.ring.get(List<&2, D.Move>, I.grab.menus(D.Trio{a, b, c}), D.Seat3{}) == Some{I.grab.moves(x <> xs)} : Maybe<&2, List<&2, D.Move>>}, nil.clash(x, xs, e))
    case D.Quad{+a, +b, +c, +d} D.Seat0{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, a, x <> xs, e)
    case D.Quad{+a, +b, +c, +d} D.Seat1{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, b, x <> xs, e)
    case D.Quad{+a, +b, +c, +d} D.Seat2{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, c, x <> xs, e)
    case D.Quad{+a, +b, +c, +d} D.Seat3{}:
      Equal.cong(List<&2, S.GrabOption>, Maybe<&2, List<&2, D.Move>>, c => Some{I.grab.moves(c)}, d, x <> xs, e)

def ns.shift(+a: T.Log, +u: T.State) -> {NS(SA.embed(C.shift(a, u))) == NS(SA.embed(u)) : S.State}:
  match u:
    case T.State{w, p, ph, l, g}:
      {==}

# One sm step from y (its notes the simple log l) to y1, then the rest.
def notes.shift(+a: T.Log, +u: T.State) -> {T.state.notes(C.shift(a, u)) == List.append(&2, D.Note, T.log.list(a), T.state.notes(u)) : List<&2, D.Note>}:
  match u:
    case T.State{w, p, ph, l, g}:
      Wk.list.join(a, l)

def fin.step(+l: T.Log, +u: T.State, +yw: S.World, +yp: S.Players, +yq: S.Phase, +yg: S.Grabs, +y1: S.State, walked: Maybe<&2, D.Stepped<&2, S.State>>, ih: Fin.of(u, y1, walked)) -> Fin.of(C.shift(l, u), S.State{yw, yp, yq, T.log.list(l), yg}, SA.walk.merge(D.Stepped{y1, S.state.notes(y1)}, walked)):
  match walked:
    case None{}:
      Wk.absurd(Fin.of(C.shift(l, u), S.State{yw, yp, yq, T.log.list(l), yg}, None{}), ih)
    case Some{D.Stepped{+z, +d}}:
      match ih:
        case Tuple{+ns, +nt}:
          +e1 : {NS(z) == NS(SA.embed(C.shift(l, u))) : S.State} = Equal.trans(S.State, NS(z), NS(SA.embed(u)), NS(SA.embed(C.shift(l, u))), ns, Equal.sym(S.State, NS(SA.embed(C.shift(l, u))), NS(SA.embed(u)), ns.shift(l, u)))
          +e2 : {T.state.notes(C.shift(l, u)) == List.append(&2, D.Note, T.log.list(l), T.state.notes(u)) : List<&2, D.Note>} = notes.shift(l, u)
          +e3 : {List.append(&2, D.Note, T.log.list(l), T.state.notes(u)) == List.append(&2, D.Note, T.log.list(l), List.append(&2, D.Note, S.state.notes(y1), d)) : List<&2, D.Note>} = Equal.cong(List<&2, D.Note>, List<&2, D.Note>, xs => List.append(&2, D.Note, T.log.list(l), xs), T.state.notes(u), List.append(&2, D.Note, S.state.notes(y1), d), nt)
          (e1, Equal.trans(List<&2, D.Note>, T.state.notes(C.shift(l, u)), List.append(&2, D.Note, T.log.list(l), T.state.notes(u)), List.append(&2, D.Note, T.log.list(l), List.append(&2, D.Note, S.state.notes(y1), d)), e2, e3))

def LoopHyp(fuel: Nat) -> Type:
  @+w:S.World -> @+p:S.Players -> @+ph:T.Phase -> @+l:T.Log -> @+g:S.Grabs -> @+q:S.Phase -> @+after:D.Seat -> Claim(fuel, N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), M.grab.continue(S.State{w, p, q, T.log.list(l), g}), after)

def embedq(+q: S.Phase, t: T.State) -> S.State:
  match t:
    case T.State{w, p, _, l, g}:
      S.State{w, p, q, T.log.list(l), g}

# The loop after a grab move that took the simple log from l to l then d,
# against sm's step to its continue and the rest of the schedule.
def next.continue(+fuel: Nat, ih: LoopHyp(fuel), +l: T.Log, +t: T.State, +yw: S.World, +yp: S.Players, +yq: S.Phase, +yg: S.Grabs, +q: S.Phase, +seat: D.Seat) -> Fin.of(N.grab.loop(fuel, C.shift(l, t), N.grab.continue(T.state.records(C.shift(l, t)), seat)), S.State{yw, yp, yq, T.log.list(l), yg}, SA.walk.merge(S.state.stepped(M.grab.continue(embedq(q, t))), SA.walk.go(SA.sched.go(fuel, SA.sched.decide(M.grab.continue(embedq(q, t)), seat), M.grab.continue(embedq(q, t))), M.grab.continue(embedq(q, t))))):
  match t:
    case T.State{+w, +p, +ph, +d, +g}:
      +next : N.Distribution = N.grab.continue(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat)
      +u : T.State = N.grab.loop(fuel, T.State{w, p, ph, d, g}, next)
      +y1 : S.State = M.grab.continue(S.State{w, p, q, T.log.list(d), g})
      %Equal.sym(T.State, N.grab.loop(fuel, T.State{w, p, ph, C.log.join(l, d), g}, next), C.shift(l, u), C.loop.frame(fuel)(l, w, p, ph, d, g, next)) : Fin.of(_, S.State{yw, yp, yq, T.log.list(l), yg}, SA.walk.merge(S.state.stepped(y1), SA.walk.go(SA.sched.go(fuel, SA.sched.decide(y1, seat), y1), y1)))
      fin.step(l, u, yw, yp, yq, yg, y1, SA.walk.go(SA.sched.go(fuel, SA.sched.decide(y1, seat), y1), y1), ih(w, p, ph, d, g, q, seat))

def ll.pool(+fuel: Nat, ih: LoopHyp(fuel), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +yq: S.Phase, +yg: S.Grabs, +seat: D.Seat, pool: List<&2, D.Item>) -> Fin.of(N.grab.loop(fuel, N.grab.pool(T.State{w, p, ph, l, g}, seat, pool), N.grab.next(T.state.records(N.grab.pool(T.State{w, p, ph, l, g}, seat, pool)), pool, seat)), S.State{w, p, yq, T.log.list(l), yg}, SA.walk.merge(S.state.stepped(M.grab.pool(S.State{w, p, yq, Nil{}, g}, seat, pool)), SA.walk.go(SA.sched.go(fuel, SA.sched.decide(M.stepped.state(S.state.stepped(M.grab.pool(S.State{w, p, yq, Nil{}, g}, seat, pool))), seat), M.stepped.state(S.state.stepped(M.grab.pool(S.State{w, p, yq, Nil{}, g}, seat, pool)))), M.stepped.state(S.state.stepped(M.grab.pool(S.State{w, p, yq, Nil{}, g}, seat, pool)))))):
  match pool:
    case Nil{}:
      next.continue(fuel, ih, l, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Told{seat, D.EmptyBriefcase{}}}, g}, w, p, yq, yg, yq, seat)
    case +item <> Nil{}:
      next.continue(fuel, ih, l, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.Granted{seat, item}}}, I.grabs.give(g, seat, item)}, w, p, yq, yg, yq, seat)
    case +first <> +second <> +rest:
      %Equal.sym(T.State, N.grab.loop(fuel, T.State{w, p, T.NeedItem{seat, first, second, rest}, l, g}, N.Drawing{}), T.State{w, p, T.NeedItem{seat, first, second, rest}, l, g}, loop.drawing(fuel, T.State{w, p, T.NeedItem{seat, first, second, rest}, l, g})) : Fin.of(_, S.State{w, p, yq, T.log.list(l), yg}, SA.walk.merge(D.Stepped{S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g}, Nil{}}, SA.walk.go(SA.sched.go(fuel, SA.sched.decide(S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g}, seat), S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g}), S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g})))
      %Equal.sym(List<&2, SA.Step>, SA.sched.go(fuel, None{}, S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g}), Nil{}, sched.none(fuel, S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g})) : Fin.of(T.State{w, p, T.NeedItem{seat, first, second, rest}, l, g}, S.State{w, p, yq, T.log.list(l), yg}, SA.walk.merge(D.Stepped{S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g}, Nil{}}, SA.walk.go(_, S.State{w, p, S.NeedItem{seat, first, second, rest}, Nil{}, g})))
      ({==}, Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(l), Nil{}), T.log.list(l), Wk.append_nil(D.Note, T.log.list(l))))

def take.selected(+w: S.World, +p: S.Players, +g: S.Grabs, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +seat: D.Seat, view: {cell(needs, seat) == [S.TakeItem{}] : List<&2, S.GrabOption>}) -> {M.answer.choice(S.State{w, p, S.Grab{needs}, Nil{}, g}, D.Choice{seat, 0n, D.Grab{}}) == M.grab.take(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat) : S.State}:
  %Equal.sym(List<&2, S.GrabOption>, cell(needs, seat), [S.TakeItem{}], view) : {M.grab.selected(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat, I.grab.nth(_, 0n)) == M.grab.take(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat) : S.State}
  {==}

def ll.take.go(+f: Nat, ih: LoopHyp(f), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, view: {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == [S.TakeItem{}] : List<&2, S.GrabOption>}, walked: Wk.Walked(I.grab.menus(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})), seat, D.Grab{}, D.Grab{}, Nil{}, 0n)) -> Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Taking{seat}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(1n+f, Some{SA.ChoiceStep{seat, D.Grab{}}}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  match walked:
    case Tuple{+n, Tuple{+legal, +res}}:
      %Equal.sym(Maybe<&2, Nat>, SA.walk.legal(M.request(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), SA.ChoiceStep{seat, D.Grab{}}), Some{n}, legal) : Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Taking{seat}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.answer(_, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, next => SA.walk.go(SA.sched.go(f, SA.sched.decide(SA.sched.index(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _), seat), SA.sched.index(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _)), next)))
      +answered : {M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n) == S.state.stepped(M.grab.take(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat)) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n), S.state.stepped(M.answer.choice(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, D.Choice{seat, 0n, D.Grab{}})), S.state.stepped(M.grab.take(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat)), choose.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n, M.request(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), D.Choice{seat, 0n, D.Grab{}}, res), Equal.cong(S.State, D.Stepped<&2, S.State>, x => S.state.stepped(x), M.answer.choice(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, D.Choice{seat, 0n, D.Grab{}}), M.grab.take(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat), take.selected(w, p, g, I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat, view)))
      %Equal.sym(D.Stepped<&2, S.State>, M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n), S.state.stepped(M.grab.take(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat)), answered) : Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Taking{seat}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.merge(_, SA.walk.go(SA.sched.go(f, SA.sched.decide(M.stepped.state(_), seat), M.stepped.state(_)), M.stepped.state(_))))
      +opened : S.Grabs = I.grabs.stop_intake(g, seat)
      ll.pool(f, ih, w, p, ph, l, opened, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, g, seat, I.pool(S.State{w, p, S.Blocked{None{}}, Nil{}, opened}, seat))

def ll.take(+f: Nat, ih: LoopHyp(f), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +view: {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == [S.TakeItem{}] : List<&2, S.GrabOption>}) -> Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Taking{seat}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(1n+f, Some{SA.ChoiceStep{seat, D.Grab{}}}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  ll.take.go(f, ih, w, p, ph, l, g, seat, view, Wk.choose.walk(I.grab.menus(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})), seat, D.Grab{}, D.Grab{}, Nil{}, 0n, menus.get(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat, S.TakeItem{}, Nil{}, view), {==}))

# The placement step: sm's place, which ends in grab.continue, is the
# simple place followed by sm's continue.

def finish_empty.indep(seats: List<&2, D.Seat>, +w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>) -> {I.finish.empty(seats, S.State{w, p, q1, n1, g}) == I.finish.empty(seats, S.State{w, p, q2, n2, g}) : Bool}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> rest:
      Equal.cong(Bool, Bool, b => Bool.and(Bool.not(I.stocked(S.State{w, p, q1, n1, g}, seat)), b), I.finish.empty(rest, S.State{w, p, q1, n1, g}), I.finish.empty(rest, S.State{w, p, q2, n2, g}), finish_empty.indep(rest, w, p, g, q1, n1, q2, n2))

def finished.indep(+w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>) -> {I.finished(S.State{w, p, q1, n1, g}) == I.finished(S.State{w, p, q2, n2, g}) : Bool}:
  Equal.cong(Bool, Bool, b => Bool.or(I.finish.ended(D.ring.entries(Bool, S.grabs.grabbing(g))), b), I.finish.empty(D.table.seats(S.world.table(w)), S.State{w, p, q1, n1, g}), I.finish.empty(D.table.seats(S.world.table(w)), S.State{w, p, q2, n2, g}), finish_empty.indep(D.table.seats(S.world.table(w)), w, p, g, q1, n1, q2, n2))

def stalled.indep(seats: List<&2, D.Seat>, +w: S.World, +p: S.Players, +g: S.Grabs, +q1: S.Phase, +n1: List<&2, D.Note>, +q2: S.Phase, +n2: List<&2, D.Note>, +placing: D.Seat) -> {I.stalled(seats, S.State{w, p, q1, n1, g}, placing) == I.stalled(seats, S.State{w, p, q2, n2, g}, placing) : List<&2, D.Seat>}:
  match seats:
    case Nil{}:
      {==}
    case +seat <> rest:
      Equal.cong(List<&2, D.Seat>, List<&2, D.Seat>, xs => I.keep(D.Seat, Bool.and(I.seat.grabbing(g, seat), Bool.and(I.is_none(I.seat.holding(g, seat)), Bool.and(Bool.not(D.seat.eq(seat, placing)), Bool.not(I.stocked(S.State{w, p, q1, n1, g}, seat))))), seat, xs), I.stalled(rest, S.State{w, p, q1, n1, g}, placing), I.stalled(rest, S.State{w, p, q2, n2, g}, placing), stalled.indep(rest, w, p, g, q1, n1, q2, n2, placing))

def stalled.any(+q: S.Phase, +t: T.State, +placing: D.Seat) -> {I.stalled.seats(embedq(q, t), placing) == I.stalled.seats(T.state.records(t), placing) : List<&2, D.Seat>}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      stalled.indep(D.table.seats(S.world.table(w)), w, p, g, q, T.log.list(l), S.Blocked{None{}}, Nil{}, placing)

def check_done.step(+q: S.Phase, +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, done: Bool) -> {M.grab.check.done(S.State{w, p, q, T.log.list(l), g}, done) == embedq(q, N.grab.check.done(T.State{w, p, ph, l, g}, done)) : S.State}:
  match done:
    case True{}:
      {==}
    case False{}:
      {==}

def check.step(+q: S.Phase, +t: T.State) -> {M.grab.check(embedq(q, t)) == embedq(q, N.grab.check(t)) : S.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      %finished.indep(w, p, g, S.Blocked{None{}}, Nil{}, q, T.log.list(l)) : {M.grab.check.done(S.State{w, p, q, T.log.list(l), g}, Bool.and(S.grabs.distributing(g), _)) == embedq(q, N.grab.check(T.State{w, p, ph, l, g})) : S.State}
      check_done.step(q, w, p, ph, l, g, Bool.and(S.grabs.distributing(g), I.finished(S.State{w, p, S.Blocked{None{}}, Nil{}, g})))

def end_all.step(seats: List<&2, D.Seat>, +q: S.Phase, +t: T.State) -> {M.grab.end_all(seats, embedq(q, t)) == embedq(q, N.grab.end_all(seats, t)) : S.State}:
  match seats t:
    case Nil{} T.State{w, p, ph, l, g}:
      {==}
    case +seat <> rest T.State{+w, +p, +ph, +l, +g}:
      end_all.step(rest, q, T.State{w, p, ph, T.Snoc{l, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})

def put.step(+q: S.Phase, +t: T.State, +seat: D.Seat, +slot: D.Slot, +item: D.Item, held: {I.seat.holding(T.state.grabs(t), seat) == Some{item} : Maybe<&2, D.Item>}) -> {M.grab.put(embedq(q, t), seat, slot) == M.grab.continue(embedq(q, N.grab.put(t, seat, slot))) : S.State}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      %Equal.sym(Maybe<&2, D.Item>, I.seat.holding(g, seat), Some{item}, held) : {M.grab.put.held(S.State{w, p, q, T.log.list(l), g}, seat, slot, _) == M.grab.continue(embedq(q, N.grab.put.held(T.State{w, p, ph, l, g}, seat, slot, _))) : S.State}
      {==}

def holding_done(+g: S.Grabs, +s: D.Seat, done: Bool) -> {I.seat.holding(S.grabs.set_distributing(g, done), s) == I.seat.holding(g, s) : Maybe<&2, D.Item>}:
  match g:
    case S.Grabs{d, gr, h, gt, i}:
      {==}

def holding_check.done(+w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +s: D.Seat, done: Bool) -> {I.seat.holding(T.state.grabs(N.grab.check.done(T.State{w, p, ph, l, g}, done)), s) == I.seat.holding(g, s) : Maybe<&2, D.Item>}:
  match done:
    case True{}:
      holding_done(g, s, False{})
    case False{}:
      {==}

def holding.check(+t: T.State, +s: D.Seat) -> {I.seat.holding(T.state.grabs(N.grab.check(t)), s) == I.seat.holding(T.state.grabs(t), s) : Maybe<&2, D.Item>}:
  match t:
    case T.State{+w, +p, +ph, +l, +g}:
      holding_check.done(w, p, ph, l, g, s, Bool.and(S.grabs.distributing(g), I.finished(S.State{w, p, S.Blocked{None{}}, Nil{}, g})))

def holding_close(+g: S.Grabs, +seat: D.Seat, +s: D.Seat) -> {I.seat.holding(I.grabs.close(g, seat), s) == I.seat.holding(g, s) : Maybe<&2, D.Item>}:
  match g:
    case S.Grabs{d, gr, h, gt, i}:
      {==}

def holding.end_all(seats: List<&2, D.Seat>, +t: T.State, +s: D.Seat) -> {I.seat.holding(T.state.grabs(N.grab.end_all(seats, t)), s) == I.seat.holding(T.state.grabs(t), s) : Maybe<&2, D.Item>}:
  match seats t:
    case Nil{} T.State{w, p, ph, l, g}:
      {==}
    case +seat <> rest T.State{+w, +p, +ph, +l, +g}:
      Equal.trans(Maybe<&2, D.Item>, I.seat.holding(T.state.grabs(N.grab.end_all(rest, T.State{w, p, ph, T.Snoc{l, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), s), I.seat.holding(I.grabs.close(g, seat), s), I.seat.holding(g, s), holding.end_all(rest, T.State{w, p, ph, T.Snoc{l, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}, s), holding_close(g, seat, s))

def place_last.step(+q: S.Phase, +w: S.World, +p: S.Players, +ph: T.Phase, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +item: D.Item, held: {I.seat.holding(g, seat) == Some{item} : Maybe<&2, D.Item>}, last: Bool) -> {M.grab.place.last(S.State{w, p, q, Nil{}, g}, seat, slot, last) == M.grab.continue(embedq(q, N.grab.place.last(T.State{w, p, ph, T.Empty{}, g}, seat, slot, last))) : S.State}:
  match last:
    case False{}:
      put.step(q, T.State{w, p, ph, T.Empty{}, g}, seat, slot, item, held)
    case True{}:
      Equal.trans(S.State, M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(embedq(q, N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.continue(embedq(q, N.grab.put(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))), seat, slot))), Equal.trans(S.State, M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(M.grab.check(embedq(q, N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(embedq(q, N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), Equal.trans(S.State, M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(M.grab.check(embedq(q, N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), Equal.trans(S.State, M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), Equal.cong(S.State, S.State, x => M.grab.put(M.grab.check(M.grab.end_all(I.stalled.seats(x, seat), x)), seat, slot), M.grab.check(embedq(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), check.step(q, T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), Equal.cong(List<&2, D.Seat>, S.State, xs => M.grab.put(M.grab.check(M.grab.end_all(xs, embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat, slot), I.stalled.seats(embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), stalled.any(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}), seat))), Equal.cong(S.State, S.State, x => M.grab.put(M.grab.check(x), seat, slot), M.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), embedq(q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))), embedq(q, N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))), end_all.step(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), q, N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), Equal.cong(S.State, S.State, x => M.grab.put(x, seat, slot), M.grab.check(embedq(q, N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), embedq(q, N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), check.step(q, N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))))), put.step(q, N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))), seat, slot, item, Equal.trans(Maybe<&2, D.Item>, I.seat.holding(T.state.grabs(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat), I.seat.holding(g, seat), Some{item}, Equal.trans(Maybe<&2, D.Item>, I.seat.holding(T.state.grabs(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat), I.seat.holding(T.state.grabs(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}), seat), I.seat.holding(g, seat), Equal.trans(Maybe<&2, D.Item>, I.seat.holding(T.state.grabs(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat), I.seat.holding(T.state.grabs(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), I.seat.holding(T.state.grabs(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}), seat), Equal.trans(Maybe<&2, D.Item>, I.seat.holding(T.state.grabs(N.grab.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})))), seat), I.seat.holding(T.state.grabs(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}))), seat), I.seat.holding(T.state.grabs(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), holding.check(N.grab.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), holding.end_all(I.stalled.seats(T.state.records(N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)})), seat), N.grab.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}), seat)), holding.check(T.State{w, p, ph, T.Snoc{T.Empty{}, D.Shown{D.GrabbingEnded{seat}}}, I.grabs.close(g, seat)}, seat)), holding_close(g, seat, seat)), held)))

def place.step(+q: S.Phase, +w: S.World, +p: S.Players, +ph: T.Phase, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +item: D.Item, held: {I.seat.holding(g, seat) == Some{item} : Maybe<&2, D.Item>}) -> {M.grab.place(S.State{w, p, q, Nil{}, g}, seat, slot) == M.grab.continue(embedq(q, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))) : S.State}:
  place_last.step(q, w, p, ph, g, seat, slot, item, held, I.placing.last(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, seat))

def puts.disc(xs: List<&2, S.GrabOption>) -> Type:
  match xs:
    case S.PutAt{_} <> _:
      Empty
    case _:
      Unit

def puts.clash(+xs: List<&2, S.GrabOption>, +slot: D.Slot, +rest: List<&2, S.GrabOption>, e: {xs == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}, other: puts.disc(xs)) -> Empty:
  %e : puts.disc(_)
  other

def Held(+g: S.Grabs, +seat: D.Seat) -> Data:
  Sigma<&2, &2, D.Item, item => {I.seat.holding(g, seat) == Some{item} : Maybe<&2, D.Item>}>

def offer.held(grabbing: Bool, holding: Maybe<&2, D.Item>, open: Bool, +slots: D.Slots, +slot: D.Slot, +rest: List<&2, S.GrabOption>, e: {I.grab.offer(grabbing, holding, open, slots) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}) -> Sigma<&2, &2, D.Item, item => {holding == Some{item} : Maybe<&2, D.Item>}>:
  match grabbing holding open:
    case True{} Some{+item} _:
      (item, {==})
    case True{} None{} True{}:
      Wk.absurd(Sigma<&2, &2, D.Item, item => {None{} == Some{item} : Maybe<&2, D.Item>}>, puts.clash([S.TakeItem{}], slot, rest, e, Unit{}))
    case True{} None{} False{}:
      Wk.absurd(Sigma<&2, &2, D.Item, item => {None{} == Some{item} : Maybe<&2, D.Item>}>, puts.clash(Nil{}, slot, rest, e, Unit{}))
    case False{} h _:
      Wk.absurd(Sigma<&2, &2, D.Item, item => {h == Some{item} : Maybe<&2, D.Item>}>, puts.clash(Nil{}, slot, rest, e, Unit{}))

# A seat offered a place holds an item.
def put.held.at(table: D.Table, seat: D.Seat, +p: S.Players, +g: S.Grabs, +slot: D.Slot, +rest: List<&2, S.GrabOption>, e: {cell(I.grab.needs.go(D.table.seats(table), p, g, D.ring.fill(List<&2, S.GrabOption>, table, Nil{})), seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}) -> Held(g, seat):
  match table seat:
    case D.TwoSeats{} D.Seat0{}:
      Wk.absurd(Held(g, D.Seat0{}), puts.clash(Nil{}, slot, rest, e, Unit{}))
    case D.TwoSeats{} D.Seat1{}:
      offer.held(I.seat.grabbing(g, D.Seat1{}), I.seat.holding(g, D.Seat1{}), Bool.and(I.seat.intake(g, D.Seat1{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat1{}), slot, rest, e)
    case D.TwoSeats{} D.Seat2{}:
      Wk.absurd(Held(g, D.Seat2{}), puts.clash(Nil{}, slot, rest, e, Unit{}))
    case D.TwoSeats{} D.Seat3{}:
      offer.held(I.seat.grabbing(g, D.Seat3{}), I.seat.holding(g, D.Seat3{}), Bool.and(I.seat.intake(g, D.Seat3{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat3{}), slot, rest, e)
    case D.ThreeSeats{} D.Seat0{}:
      offer.held(I.seat.grabbing(g, D.Seat0{}), I.seat.holding(g, D.Seat0{}), Bool.and(I.seat.intake(g, D.Seat0{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat0{}), slot, rest, e)
    case D.ThreeSeats{} D.Seat1{}:
      offer.held(I.seat.grabbing(g, D.Seat1{}), I.seat.holding(g, D.Seat1{}), Bool.and(I.seat.intake(g, D.Seat1{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat1{}), slot, rest, e)
    case D.ThreeSeats{} D.Seat2{}:
      offer.held(I.seat.grabbing(g, D.Seat2{}), I.seat.holding(g, D.Seat2{}), Bool.and(I.seat.intake(g, D.Seat2{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat2{}), slot, rest, e)
    case D.ThreeSeats{} D.Seat3{}:
      Wk.absurd(Held(g, D.Seat3{}), puts.clash(Nil{}, slot, rest, e, Unit{}))
    case D.FourSeats{} D.Seat0{}:
      offer.held(I.seat.grabbing(g, D.Seat0{}), I.seat.holding(g, D.Seat0{}), Bool.and(I.seat.intake(g, D.Seat0{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat0{}), slot, rest, e)
    case D.FourSeats{} D.Seat1{}:
      offer.held(I.seat.grabbing(g, D.Seat1{}), I.seat.holding(g, D.Seat1{}), Bool.and(I.seat.intake(g, D.Seat1{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat1{}), slot, rest, e)
    case D.FourSeats{} D.Seat2{}:
      offer.held(I.seat.grabbing(g, D.Seat2{}), I.seat.holding(g, D.Seat2{}), Bool.and(I.seat.intake(g, D.Seat2{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat2{}), slot, rest, e)
    case D.FourSeats{} D.Seat3{}:
      offer.held(I.seat.grabbing(g, D.Seat3{}), I.seat.holding(g, D.Seat3{}), Bool.and(I.seat.intake(g, D.Seat3{}), S.grabs.distributing(g)), I.seat.slots(p, D.Seat3{}), slot, rest, e)

def put.held(+w: S.World, +p: S.Players, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +rest: List<&2, S.GrabOption>, e: {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}) -> Held(g, seat):
  put.held.at(S.world.table(w), seat, p, g, slot, rest, e)

def place.found(+slot: D.Slot, +ms: List<&2, D.Move>) -> {D.menu.find(D.Place{slot} <> ms, D.Place{slot}) == Some{0n} : Maybe<&2, Nat>}:
  %Equal.sym(Bool, D.slot.eq(slot, slot), True{}, Wk.slot.eq.refl(slot)) : {D.menu.find.here(_, D.menu.find(ms, D.Place{slot})) == Some{0n} : Maybe<&2, Nat>}
  {==}

def place.selected(+w: S.World, +p: S.Players, +g: S.Grabs, +needs: D.Ring<&2, List<&2, S.GrabOption>>, +seat: D.Seat, +slot: D.Slot, +rest: List<&2, S.GrabOption>, view: {cell(needs, seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}) -> {M.answer.choice(S.State{w, p, S.Grab{needs}, Nil{}, g}, D.Choice{seat, 0n, D.Place{slot}}) == M.grab.place(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat, slot) : S.State}:
  %Equal.sym(List<&2, S.GrabOption>, cell(needs, seat), S.PutAt{slot} <> rest, view) : {M.grab.selected(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat, I.grab.nth(_, 0n)) == M.grab.place(S.State{w, p, S.Grab{needs}, Nil{}, g}, seat, slot) : S.State}
  {==}

def ll.place.go(+f: Nat, ih: LoopHyp(f), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +rest: List<&2, S.GrabOption>, view: {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}, held: Held(g, seat), walked: Wk.Walked(I.grab.menus(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})), seat, D.Place{slot}, D.Place{slot}, I.grab.moves(rest), 0n)) -> Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Placing{seat, slot}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(1n+f, Some{SA.ChoiceStep{seat, D.Place{slot}}}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  match held walked:
    case Tuple{+item, +hi} Tuple{+n, Tuple{+legal, +res}}:
      %Equal.sym(Maybe<&2, Nat>, SA.walk.legal(M.request(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), SA.ChoiceStep{seat, D.Place{slot}}), Some{n}, legal) : Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Placing{seat, slot}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.answer(_, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, next => SA.walk.go(SA.sched.go(f, SA.sched.decide(SA.sched.index(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _), seat), SA.sched.index(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, _)), next)))
      +placed : {M.grab.place(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat, slot) == M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))) : S.State} = place.step(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, w, p, ph, g, seat, slot, item, hi)
      +answered : {M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n) == S.state.stepped(M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)))) : D.Stepped<&2, S.State>} = Equal.trans(D.Stepped<&2, S.State>, M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n), S.state.stepped(M.answer.choice(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, D.Choice{seat, 0n, D.Place{slot}})), S.state.stepped(M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)))), choose.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n, M.request(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), D.Choice{seat, 0n, D.Place{slot}}, res), Equal.cong(S.State, D.Stepped<&2, S.State>, x => S.state.stepped(x), M.answer.choice(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, D.Choice{seat, 0n, D.Place{slot}}), M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))), Equal.trans(S.State, M.answer.choice(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, D.Choice{seat, 0n, D.Place{slot}}), M.grab.place(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, Nil{}, g}, seat, slot), M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))), place.selected(w, p, g, I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat, slot, rest, view), placed)))
      %Equal.sym(D.Stepped<&2, S.State>, M.answer(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, n), S.state.stepped(M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)))), answered) : Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Placing{seat, slot}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.merge(_, SA.walk.go(SA.sched.go(f, SA.sched.decide(M.stepped.state(_), seat), M.stepped.state(_)), M.stepped.state(_))))
      %Equal.sym(T.State, N.grab.place(T.State{w, p, ph, l, g}, seat, slot), C.shift(l, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)), C.place.frame(l, T.State{w, p, ph, T.Empty{}, g}, seat, slot)) : Fin.of(N.grab.loop(f, _, N.grab.continue(T.state.records(_), seat)), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.merge(S.state.stepped(M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)))), SA.walk.go(SA.sched.go(f, SA.sched.decide(M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))), seat), M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot)))), M.grab.continue(embedq(S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot))))))
      next.continue(f, ih, l, N.grab.place(T.State{w, p, ph, T.Empty{}, g}, seat, slot), w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, g, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, seat)

def ll.place(+f: Nat, ih: LoopHyp(f), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +seat: D.Seat, +slot: D.Slot, +rest: List<&2, S.GrabOption>, +view: {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>}) -> Fin.of(N.grab.loop(1n+f, T.State{w, p, ph, l, g}, N.Placing{seat, slot}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(1n+f, Some{SA.ChoiceStep{seat, D.Place{slot}}}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  ll.place.go(f, ih, w, p, ph, l, g, seat, slot, rest, view, put.held(w, p, g, seat, slot, rest, view), Wk.choose.walk(I.grab.menus(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})), seat, D.Place{slot}, D.Place{slot}, I.grab.moves(rest), 0n, menus.get(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat, S.PutAt{slot}, rest, view), place.found(slot, I.grab.moves(rest))))

def Prev(fuel: Nat) -> Type:
  match fuel:
    case 0n:
      Unit
    case 1n+f:
      LoopHyp(f)

def act.go(fuel: Nat, ih: Prev(fuel), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +after: D.Seat, next: N.Distribution, view: ActView(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), after, cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), after), next)) -> Fin.of(N.grab.loop(fuel, T.State{w, p, ph, l, g}, next), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(fuel, render(next), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  match fuel next:
    case 0n N.Taking{seat}:
      ({==}, Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(l), Nil{}), T.log.list(l), Wk.append_nil(D.Note, T.log.list(l))))
    case 0n N.Placing{seat, slot}:
      ({==}, Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(l), Nil{}), T.log.list(l), Wk.append_nil(D.Note, T.log.list(l))))
    case 1n+(+f) N.Taking{+seat}:
      ll.take(f, ih, w, p, ph, l, g, seat, view)
    case 1n+(+f) N.Placing{+seat, +slot}:
      match view:
        case Tuple{+es, Tuple{+rest, +eo}}:
          +at : {cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat) == S.PutAt{slot} <> rest : List<&2, S.GrabOption>} = Equal.trans(List<&2, S.GrabOption>, cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), seat), cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), after), S.PutAt{slot} <> rest, Equal.cong(D.Seat, List<&2, S.GrabOption>, s => cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), s), seat, after, es), eo)
          ll.place(f, ih, w, p, ph, l, g, seat, slot, rest, at)
    case fuel N.NoTaker{}:
      %Equal.sym(T.State, N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.NoTaker{}), T.State{w, p, T.Stalled{}, l, g}, loop.notaker(fuel, T.State{w, p, ph, l, g})) : Fin.of(_, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(fuel, None{}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}))
      %Equal.sym(List<&2, SA.Step>, SA.sched.go(fuel, None{}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), Nil{}, sched.none(fuel, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})) : Fin.of(T.State{w, p, T.Stalled{}, l, g}, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(_, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}))
      ({==}, Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(l), Nil{}), T.log.list(l), Wk.append_nil(D.Note, T.log.list(l))))
    case fuel N.Drawing{}:
      match view:
    case fuel N.Loading{}:
      match view:

def act.claim(+fuel: Nat, ih: Prev(fuel), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +after: D.Seat) -> Fin.of(N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.grab.act(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(fuel, SA.sched.decide(S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, after), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g})):
  %Equal.sym(Maybe<&2, SA.Step>, SA.decide(I.grab.menus(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})), S.world.table(w), after), render(N.grab.act(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), decide.agree(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), S.world.table(w), after)) : Fin.of(N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.grab.act(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after)), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}, SA.walk.go(SA.sched.go(fuel, _, S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}), S.State{w, p, S.Grab{I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g})}, T.log.list(l), g}))
  act.go(fuel, ih, w, p, ph, l, g, after, N.grab.act(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after), act.view(cell(I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), after), N.seats.after(D.table.seats(S.world.table(w)), after, Nil{}), I.grab.needs(S.State{w, p, S.Blocked{None{}}, Nil{}, g}), after))

def ready.claim(+fuel: Nat, ih: Prev(fuel), +w: S.World, +p: S.Players, +ph: T.Phase, +l: T.Log, +g: S.Grabs, +q: S.Phase, +after: D.Seat, dist: Bool, hold: Bool) -> Claim(fuel, N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.grab.continue.ready(S.State{w, p, S.Blocked{None{}}, Nil{}, g}, after, dist, hold)), M.grab.continue.ready(S.State{w, p, q, T.log.list(l), g}, dist, hold), after):
  match dist hold:
    case False{} False{}:
      %Equal.sym(T.State, N.grab.loop(fuel, T.State{w, p, ph, l, g}, N.Loading{}), N.load.begin(T.State{w, p, ph, l, g}), loop.loading(fuel, T.State{w, p, ph, l, g})) : Claim(fuel, _, M.load.begin(S.State{w, p, q, T.log.list(l), g}), after)
      claim.direct(fuel, N.load.begin(T.State{w, p, ph, l, g}), M.load.begin(S.State{w, p, q, T.log.list(l), g}), after, C.direct.of(t => N.load.begin(t), x => M.load.begin(x), T.Empty{}, w, p, ph, l, g, q, C.load_begin.c(T.Empty{}, w, p, ph, l, g, q)))
    case False{} True{}:
      act.claim(fuel, ih, w, p, ph, l, g, after)
    case True{} hold:
      act.claim(fuel, ih, w, p, ph, l, g, after)

def loop.lemma(fuel: Nat) -> LoopHyp(fuel):
  match fuel:
    case 0n:
      +w => +p => +ph => +l => +g => +q => +after => ready.claim(0n, Unit{}, w, p, ph, l, g, q, after, S.grabs.distributing(g), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(g))))
    case 1n+(+f):
      +w => +p => +ph => +l => +g => +q => +after => ready.claim(1n+f, loop.lemma(f), w, p, ph, l, g, q, after, S.grabs.distributing(g), I.holders(D.ring.entries(Maybe<&2, D.Item>, S.grabs.holding(g))))
