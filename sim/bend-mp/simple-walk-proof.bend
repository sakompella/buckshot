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

# Lemmas about lists, the domain's equality tests and the flat choice index,
# for walking simple answers on sm.

def append_nil(-A: Data, +xs: List<&2, A>) -> {List.append(&2, A, xs, Nil{}) == xs : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +rest:
      Equal.cong(List<&2, A>, List<&2, A>, ys => x <> ys, List.append(&2, A, rest, Nil{}), rest, append_nil(A, rest))

def append_assoc(-A: Data, +xs: List<&2, A>, +ys: List<&2, A>, +zs: List<&2, A>) -> {List.append(&2, A, List.append(&2, A, xs, ys), zs) == List.append(&2, A, xs, List.append(&2, A, ys, zs)) : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +rest:
      Equal.cong(List<&2, A>, List<&2, A>, vs => x <> vs, List.append(&2, A, List.append(&2, A, rest, ys), zs), List.append(&2, A, rest, List.append(&2, A, ys, zs)), append_assoc(A, rest, ys, zs))

def append_length(-A: Data, +xs: List<&2, A>, +ys: List<&2, A>) -> {List.length(&2, A, List.append(&2, A, xs, ys)) == Nat.add(List.length(&2, A, xs), List.length(&2, A, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case +x <> +rest:
      Equal.cong(Nat, Nat, n => 1n+n, List.length(&2, A, List.append(&2, A, rest, ys)), Nat.add(List.length(&2, A, rest), List.length(&2, A, ys)), append_length(A, rest, ys))

def add_zero(+n: Nat) -> {Nat.add(n, 0n) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+(+k):
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(k, 0n), k, add_zero(k))

def list.join(+a: T.Log, +b: T.Log) -> {T.log.list(C.log.join(a, b)) == List.append(&2, D.Note, T.log.list(a), T.log.list(b)) : List<&2, D.Note>}:
  match b:
    case T.Empty{}:
      Equal.sym(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(a), Nil{}), T.log.list(a), append_nil(D.Note, T.log.list(a)))
    case T.Snoc{+earlier, +note}:
      +e1 : {List.append(&2, D.Note, T.log.list(C.log.join(a, earlier)), [note]) == List.append(&2, D.Note, List.append(&2, D.Note, T.log.list(a), T.log.list(earlier)), [note]) : List<&2, D.Note>} = Equal.cong(List<&2, D.Note>, List<&2, D.Note>, xs => List.append(&2, D.Note, xs, [note]), T.log.list(C.log.join(a, earlier)), List.append(&2, D.Note, T.log.list(a), T.log.list(earlier)), list.join(a, earlier))
      Equal.trans(List<&2, D.Note>, List.append(&2, D.Note, T.log.list(C.log.join(a, earlier)), [note]), List.append(&2, D.Note, List.append(&2, D.Note, T.log.list(a), T.log.list(earlier)), [note]), List.append(&2, D.Note, T.log.list(a), List.append(&2, D.Note, T.log.list(earlier), [note])), e1, append_assoc(D.Note, T.log.list(a), T.log.list(earlier), [note]))

def nat_eq.refl(+n: Nat) -> {Nat.is_eq(n, n) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+k:
      nat_eq.refl(k)

def absurd(-X: Type, impossible: Empty) -> X:
  match impossible:

def bool.disc(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

def bool.clash(e: {False{} == True{} : Bool}) -> Empty:
  %e : bool.disc(_)
  Unit{}

def nat_eq.sound(+m: Nat, +n: Nat, e: {Nat.is_eq(m, n) == True{} : Bool}) -> {m == n : Nat}:
  match m n:
    case 0n 0n:
      {==}
    case 0n 1n+k:
      absurd({0n == 1n+k : Nat}, bool.clash(e))
    case 1n+k 0n:
      absurd({1n+k == 0n : Nat}, bool.clash(e))
    case 1n+(+j) 1n+(+k):
      Equal.cong(Nat, Nat, x => 1n+x, j, k, nat_eq.sound(j, k, e))

def seat.code(seat: D.Seat) -> Nat:
  match seat:
    case D.Seat0{}:
      0n
    case D.Seat1{}:
      1n
    case D.Seat2{}:
      2n
    case D.Seat3{}:
      3n

def seat.eq.sound(+a: D.Seat, +b: D.Seat, e: {D.seat.eq(a, b) == True{} : Bool}) -> {a == b : D.Seat}:
  match a b:
    case D.Seat0{} D.Seat0{}:
      {==}
    case D.Seat1{} D.Seat1{}:
      {==}
    case D.Seat2{} D.Seat2{}:
      {==}
    case D.Seat3{} D.Seat3{}:
      {==}
    case D.Seat0{} D.Seat1{}:
      absurd({D.Seat0{} == D.Seat1{} : D.Seat}, bool.clash(e))
    case D.Seat0{} D.Seat2{}:
      absurd({D.Seat0{} == D.Seat2{} : D.Seat}, bool.clash(e))
    case D.Seat0{} D.Seat3{}:
      absurd({D.Seat0{} == D.Seat3{} : D.Seat}, bool.clash(e))
    case D.Seat1{} D.Seat0{}:
      absurd({D.Seat1{} == D.Seat0{} : D.Seat}, bool.clash(e))
    case D.Seat1{} D.Seat2{}:
      absurd({D.Seat1{} == D.Seat2{} : D.Seat}, bool.clash(e))
    case D.Seat1{} D.Seat3{}:
      absurd({D.Seat1{} == D.Seat3{} : D.Seat}, bool.clash(e))
    case D.Seat2{} D.Seat0{}:
      absurd({D.Seat2{} == D.Seat0{} : D.Seat}, bool.clash(e))
    case D.Seat2{} D.Seat1{}:
      absurd({D.Seat2{} == D.Seat1{} : D.Seat}, bool.clash(e))
    case D.Seat2{} D.Seat3{}:
      absurd({D.Seat2{} == D.Seat3{} : D.Seat}, bool.clash(e))
    case D.Seat3{} D.Seat0{}:
      absurd({D.Seat3{} == D.Seat0{} : D.Seat}, bool.clash(e))
    case D.Seat3{} D.Seat1{}:
      absurd({D.Seat3{} == D.Seat1{} : D.Seat}, bool.clash(e))
    case D.Seat3{} D.Seat2{}:
      absurd({D.Seat3{} == D.Seat2{} : D.Seat}, bool.clash(e))

def seat.eq.refl(+a: D.Seat) -> {D.seat.eq(a, a) == True{} : Bool}:
  match a:
    case D.Seat0{}:
      {==}
    case D.Seat1{}:
      {==}
    case D.Seat2{}:
      {==}
    case D.Seat3{}:
      {==}

def slot.decode(n: Nat) -> D.Slot:
  match n:
    case 0n:
      D.Slot0{}
    case 1n:
      D.Slot1{}
    case 2n:
      D.Slot2{}
    case 3n:
      D.Slot3{}
    case 4n:
      D.Slot4{}
    case 5n:
      D.Slot5{}
    case 6n:
      D.Slot6{}
    case _:
      D.Slot7{}

def slot.decode.code(+s: D.Slot) -> {slot.decode(D.slot.code(s)) == s : D.Slot}:
  match s:
    case D.Slot0{}:
      {==}
    case D.Slot1{}:
      {==}
    case D.Slot2{}:
      {==}
    case D.Slot3{}:
      {==}
    case D.Slot4{}:
      {==}
    case D.Slot5{}:
      {==}
    case D.Slot6{}:
      {==}
    case D.Slot7{}:
      {==}

def slot.eq.sound(+a: D.Slot, +b: D.Slot, e: {D.slot.eq(a, b) == True{} : Bool}) -> {a == b : D.Slot}:
  +codes : {slot.decode(D.slot.code(a)) == slot.decode(D.slot.code(b)) : D.Slot} = Equal.cong(Nat, D.Slot, slot.decode, D.slot.code(a), D.slot.code(b), nat_eq.sound(D.slot.code(a), D.slot.code(b), e))
  Equal.trans(D.Slot, a, slot.decode(D.slot.code(b)), b, Equal.trans(D.Slot, a, slot.decode(D.slot.code(a)), slot.decode(D.slot.code(b)), Equal.sym(D.Slot, slot.decode(D.slot.code(a)), a, slot.decode.code(a)), codes), slot.decode.code(b))

def slot.eq.refl(+a: D.Slot) -> {D.slot.eq(a, a) == True{} : Bool}:
  nat_eq.refl(D.slot.code(a))

def item.decode(n: Nat) -> D.Item:
  match n:
    case 1n:
      D.Saw{}
    case 2n:
      D.Glass{}
    case 3n:
      D.Jammer{}
    case 4n:
      D.Cigarettes{}
    case 5n:
      D.Beer{}
    case 6n:
      D.Phone{}
    case 9n:
      D.Inverter{}
    case 8n:
      D.Adrenaline{}
    case _:
      D.Remote{}

def item.decode.code(+i: D.Item) -> {item.decode(D.item.godot_id(i)) == i : D.Item}:
  match i:
    case D.Saw{}:
      {==}
    case D.Glass{}:
      {==}
    case D.Jammer{}:
      {==}
    case D.Cigarettes{}:
      {==}
    case D.Beer{}:
      {==}
    case D.Phone{}:
      {==}
    case D.Inverter{}:
      {==}
    case D.Adrenaline{}:
      {==}
    case D.Remote{}:
      {==}

def item.eq.sound(+a: D.Item, +b: D.Item, e: {D.item.eq(a, b) == True{} : Bool}) -> {a == b : D.Item}:
  +codes : {item.decode(D.item.godot_id(a)) == item.decode(D.item.godot_id(b)) : D.Item} = Equal.cong(Nat, D.Item, item.decode, D.item.godot_id(a), D.item.godot_id(b), nat_eq.sound(D.item.godot_id(a), D.item.godot_id(b), e))
  Equal.trans(D.Item, a, item.decode(D.item.godot_id(b)), b, Equal.trans(D.Item, a, item.decode(D.item.godot_id(a)), item.decode(D.item.godot_id(b)), Equal.sym(D.Item, item.decode(D.item.godot_id(a)), a, item.decode.code(a)), codes), item.decode.code(b))

def item.eq.refl(+a: D.Item) -> {D.item.eq(a, a) == True{} : Bool}:
  nat_eq.refl(D.item.godot_id(a))

# The flat choice index. A prompt's answer to its menu's k-th move picks that
# move of that seat.

def menu.at(j: Nat, ms: List<&2, D.Move>, +m: D.Move) -> D.Move:
  match j ms:
    case 0n _:
      m
    case 1n+k Nil{}:
      m
    case 1n+k +x <> r:
      menu.at(k, r, x)

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+(+k):
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(k, 1n+b), 1n+Nat.add(k, b), add_succ(k, b))

def choices.len(ms: List<&2, D.Move>, +s: D.Seat, +i: Nat) -> {List.length(&2, D.Choice, D.choices.of(ms, s, i)) == List.length(&2, D.Move, ms) : Nat}:
  match ms:
    case Nil{}:
      {==}
    case m <> rest:
      Equal.cong(Nat, Nat, x => 1n+x, List.length(&2, D.Choice, D.choices.of(rest, s, 1n+i)), List.length(&2, D.Move, rest), choices.len(rest, s, 1n+i))

def block(ms: List<&2, D.Move>, j: Nat, +rest: List<&2, D.Choice>, +m: D.Move, +s: D.Seat, +i: Nat) -> {D.choices.nth(List.append(&2, D.Choice, D.choices.of(m <> ms, s, i), rest), D.clamp(j, List.length(&2, D.Move, ms))) == Some{D.Choice{s, Nat.add(D.clamp(j, List.length(&2, D.Move, ms)), i), menu.at(D.clamp(j, List.length(&2, D.Move, ms)), ms, m)}} : Maybe<&2, D.Choice>}:
  match ms j rest:
    case Nil{} 0n Nil{}:
      {==}
    case Nil{} 0n c <> cs:
      {==}
    case Nil{} 1n+k Nil{}:
      {==}
    case Nil{} 1n+k c <> cs:
      {==}
    case x <> r 0n _:
      {==}
    case +x <> +r 1n+(+k) _:
      +c : Nat = D.clamp(k, List.length(&2, D.Move, r))
      %add_succ(c, i) : {D.choices.nth(List.append(&2, D.Choice, D.choices.of(x <> r, s, 1n+i), rest), c) == Some{D.Choice{s, _, menu.at(c, r, x)}} : Maybe<&2, D.Choice>}
      block(r, k, rest, x, s, 1n+i)

def skip(+pre: List<&2, D.Choice>, +r: D.Choice, +rs: List<&2, D.Choice>, +j: Nat) -> {D.choices.nth(List.append(&2, D.Choice, pre, r <> rs), Nat.add(List.length(&2, D.Choice, pre), j)) == D.choices.nth(r <> rs, j) : Maybe<&2, D.Choice>}:
  match pre:
    case Nil{}:
      {==}
    case c <> Nil{}:
      {==}
    case c <> (+c2) <> (+cs):
      skip(c2 <> cs, r, rs, j)

def Hit(+all: List<&2, D.Choice>, +s: D.Seat, +k: Nat, found: Maybe<&2, D.Prompt>) -> Type:
  match found:
    case None{}:
      Unit
    case Some{D.Prompt{_, first, D.NonEmpty{m, ms}}}:
      {D.choices.nth(all, Nat.add(first, D.clamp(k, List.length(&2, D.Move, ms)))) == Some{D.Choice{s, Nat.add(D.clamp(k, List.length(&2, D.Move, ms)), 0n), menu.at(D.clamp(k, List.length(&2, D.Move, ms)), ms, m)}} : Maybe<&2, D.Choice>}

def hit.pick(+pre: List<&2, D.Choice>, +s2: D.Seat, +m: D.Move, +ms: List<&2, D.Move>, +rest: List<&2, D.At<&2, List<&2, D.Move>>>, +s: D.Seat, +k: Nat, same: Bool, +eq: {D.seat.eq(s2, s) == same : Bool}, ih: Hit(List.append(&2, D.Choice, List.append(&2, D.Choice, pre, D.choices.of(m <> ms, s2, 0n)), D.choices.flatten(rest)), s, k, D.prompt.find(D.prompts.go(rest, List.length(&2, D.Choice, List.append(&2, D.Choice, pre, D.choices.of(m <> ms, s2, 0n)))), s))) -> Hit(List.append(&2, D.Choice, pre, D.choices.flatten(D.At{s2, m <> ms} <> rest)), s, k, D.prompt.pick(same, D.Prompt{s2, List.length(&2, D.Choice, pre), D.NonEmpty{m, ms}}, D.prompt.find(D.prompts.go(rest, Nat.add(List.length(&2, D.Choice, pre), D.nonempty.length(D.Move, D.NonEmpty{m, ms}))), s))):
  match same:
    case True{}:
      +c : Nat = D.clamp(k, List.length(&2, D.Move, ms))
      +flat : List<&2, D.Choice> = D.choices.flatten(rest)
      +picked : {D.choices.nth(List.append(&2, D.Choice, D.choices.of(m <> ms, s2, 0n), flat), c) == Some{D.Choice{s2, Nat.add(c, 0n), menu.at(c, ms, m)}} : Maybe<&2, D.Choice>} = block(ms, k, flat, m, s2, 0n)
      +skipped : {D.choices.nth(List.append(&2, D.Choice, pre, List.append(&2, D.Choice, D.choices.of(m <> ms, s2, 0n), flat)), Nat.add(List.length(&2, D.Choice, pre), c)) == Some{D.Choice{s2, Nat.add(c, 0n), menu.at(c, ms, m)}} : Maybe<&2, D.Choice>} = Equal.trans(Maybe<&2, D.Choice>, D.choices.nth(List.append(&2, D.Choice, pre, List.append(&2, D.Choice, D.choices.of(m <> ms, s2, 0n), flat)), Nat.add(List.length(&2, D.Choice, pre), c)), D.choices.nth(List.append(&2, D.Choice, D.choices.of(m <> ms, s2, 0n), flat), c), Some{D.Choice{s2, Nat.add(c, 0n), menu.at(c, ms, m)}}, skip(pre, D.Choice{s2, 0n, m}, List.append(&2, D.Choice, D.choices.of(ms, s2, 1n), flat), c), picked)
      %seat.eq.sound(s2, s, eq) : {D.choices.nth(List.append(&2, D.Choice, pre, List.append(&2, D.Choice, D.choices.of(m <> ms, s2, 0n), flat)), Nat.add(List.length(&2, D.Choice, pre), c)) == Some{D.Choice{_, Nat.add(c, 0n), menu.at(c, ms, m)}} : Maybe<&2, D.Choice>}
      skipped
    case False{}:
      +block : List<&2, D.Choice> = D.choices.of(m <> ms, s2, 0n)
      +flat : List<&2, D.Choice> = D.choices.flatten(rest)
      +lengths : {List.length(&2, D.Choice, List.append(&2, D.Choice, pre, block)) == Nat.add(List.length(&2, D.Choice, pre), List.length(&2, D.Move, m <> ms)) : Nat} = Equal.trans(Nat, List.length(&2, D.Choice, List.append(&2, D.Choice, pre, block)), Nat.add(List.length(&2, D.Choice, pre), List.length(&2, D.Choice, block)), Nat.add(List.length(&2, D.Choice, pre), List.length(&2, D.Move, m <> ms)), append_length(D.Choice, pre, block), Equal.cong(Nat, Nat, x => Nat.add(List.length(&2, D.Choice, pre), x), List.length(&2, D.Choice, block), List.length(&2, D.Move, m <> ms), choices.len(m <> ms, s2, 0n)))
      %append_assoc(D.Choice, pre, block, flat) : Hit(_, s, k, D.prompt.find(D.prompts.go(rest, Nat.add(List.length(&2, D.Choice, pre), D.nonempty.length(D.Move, D.NonEmpty{m, ms}))), s))
      %lengths : Hit(List.append(&2, D.Choice, List.append(&2, D.Choice, pre, block), flat), s, k, D.prompt.find(D.prompts.go(rest, _), s))
      ih

def hit(entries: List<&2, D.At<&2, List<&2, D.Move>>>, +pre: List<&2, D.Choice>, +s: D.Seat, +k: Nat) -> Hit(List.append(&2, D.Choice, pre, D.choices.flatten(entries)), s, k, D.prompt.find(D.prompts.go(entries, List.length(&2, D.Choice, pre)), s)):
  match entries:
    case Nil{}:
      Unit{}
    case D.At{s2, Nil{}} <> rest:
      hit(rest, pre, s, k)
    case D.At{+s2, +m <> +ms} <> +rest:
      hit.pick(pre, s2, m, ms, rest, s, k, D.seat.eq(s2, s), {==}, hit(rest, List.append(&2, D.Choice, pre, D.choices.of(m <> ms, s2, 0n)), s, k))

# Finding a seat's prompt in a menu ring.

def advance(menu: List<&2, D.Move>, +first: Nat) -> Nat:
  match menu:
    case Nil{}:
      first
    case m <> ms:
      Nat.add(first, 1n+List.length(&2, D.Move, ms))

def find.after(+s: D.Seat, +s0: D.Seat, c0: List<&2, D.Move>, +rest: List<&2, D.At<&2, List<&2, D.Move>>>, +first: Nat, ne: {D.seat.eq(s0, s) == False{} : Bool}) -> {D.prompt.find(D.prompts.go(D.At{s0, c0} <> rest, first), s) == D.prompt.find(D.prompts.go(rest, advance(c0, first)), s) : Maybe<&2, D.Prompt>}:
  match c0:
    case Nil{}:
      {==}
    case m <> ms:
      %Equal.sym(Bool, D.seat.eq(s0, s), False{}, ne) : {D.prompt.pick(_, D.Prompt{s0, first, D.NonEmpty{m, ms}}, D.prompt.find(D.prompts.go(rest, Nat.add(first, 1n+List.length(&2, D.Move, ms))), s)) == D.prompt.find(D.prompts.go(rest, Nat.add(first, 1n+List.length(&2, D.Move, ms))), s) : Maybe<&2, D.Prompt>}
      {==}

def find.here(+s: D.Seat, +m: D.Move, +ms: List<&2, D.Move>, +rest: List<&2, D.At<&2, List<&2, D.Move>>>, +first: Nat) -> {D.prompt.find(D.prompts.go(D.At{s, m <> ms} <> rest, first), s) == Some{D.Prompt{s, first, D.NonEmpty{m, ms}}} : Maybe<&2, D.Prompt>}:
  %Equal.sym(Bool, D.seat.eq(s, s), True{}, seat.eq.refl(s)) : {D.prompt.pick(_, D.Prompt{s, first, D.NonEmpty{m, ms}}, D.prompt.find(D.prompts.go(rest, Nat.add(first, 1n+List.length(&2, D.Move, ms))), s)) == Some{D.Prompt{s, first, D.NonEmpty{m, ms}}} : Maybe<&2, D.Prompt>}
  {==}

def maybe.disc(-A: Data, x: Maybe<&2, A>) -> Type:
  match x:
    case None{}:
      Unit
    case Some{_}:
      Empty

def maybe.clash(-A: Data, +x: A, e: {None{} == Some{x} : Maybe<&2, A>}) -> Empty:
  %e : maybe.disc(A, _)
  Unit{}

def some.value(-A: Data, x: Maybe<&2, A>, +fallback: A) -> A:
  match x:
    case Some{v}:
      v
    case None{}:
      fallback

def some.inj(-A: Data, +x: A, +y: A, e: {Some{x} == Some{y} : Maybe<&2, A>}) -> {x == y : A}:
  Equal.cong(Maybe<&2, A>, A, v => some.value(A, v, x), Some{x}, Some{y}, e)

def Found(+ring: D.Ring<&2, List<&2, D.Move>>, +s: D.Seat, +m: D.Move, +ms: List<&2, D.Move>) -> Data:
  Sigma<&2, &2, Nat, first => {D.prompt.find(D.prompts.go(D.ring.entries(List<&2, D.Move>, ring), 0n), s) == Some{D.Prompt{s, first, D.NonEmpty{m, ms}}} : Maybe<&2, D.Prompt>}>
def prompt.cell(ring: D.Ring<&2, List<&2, D.Move>>, s: D.Seat, +m: D.Move, +ms: List<&2, D.Move>, get: {D.ring.get(List<&2, D.Move>, ring, s) == Some{m <> ms} : Maybe<&2, List<&2, D.Move>>}) -> Found(ring, s, m, ms):
  match ring s:
    case D.Duo{+a, +b} D.Seat0{}:
      absurd(Found(D.Duo{a, b}, D.Seat0{}, m, ms), maybe.clash(List<&2, D.Move>, m <> ms, get))
    case D.Duo{+a, +b} D.Seat1{}:
      +cell : {a == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, a, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, a, m <> ms, cell) : Found(D.Duo{_, b}, D.Seat1{}, m, ms)
      (0n, find.here(D.Seat1{}, m, ms, [D.At{D.Seat3{}, b}], 0n))
    case D.Duo{+a, +b} D.Seat2{}:
      absurd(Found(D.Duo{a, b}, D.Seat2{}, m, ms), maybe.clash(List<&2, D.Move>, m <> ms, get))
    case D.Duo{+a, +b} D.Seat3{}:
      +cell : {b == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, b, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, b, m <> ms, cell) : Found(D.Duo{a, _}, D.Seat3{}, m, ms)
      (advance(a, 0n), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat1{}, a}, D.At{D.Seat3{}, m <> ms}], 0n), D.Seat3{}), D.prompt.find(D.prompts.go([D.At{D.Seat3{}, m <> ms}], advance(a, 0n)), D.Seat3{}), Some{D.Prompt{D.Seat3{}, advance(a, 0n), D.NonEmpty{m, ms}}}, find.after(D.Seat3{}, D.Seat1{}, a, [D.At{D.Seat3{}, m <> ms}], 0n, {==}), find.here(D.Seat3{}, m, ms, [], advance(a, 0n))))
    case D.Trio{+a, +b, +c} D.Seat0{}:
      +cell : {a == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, a, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, a, m <> ms, cell) : Found(D.Trio{_, b, c}, D.Seat0{}, m, ms)
      (0n, find.here(D.Seat0{}, m, ms, [D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}], 0n))
    case D.Trio{+a, +b, +c} D.Seat1{}:
      +cell : {b == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, b, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, b, m <> ms, cell) : Found(D.Trio{a, _, c}, D.Seat1{}, m, ms)
      (advance(a, 0n), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat0{}, a}, D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}], 0n), D.Seat1{}), D.prompt.find(D.prompts.go([D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}], advance(a, 0n)), D.Seat1{}), Some{D.Prompt{D.Seat1{}, advance(a, 0n), D.NonEmpty{m, ms}}}, find.after(D.Seat1{}, D.Seat0{}, a, [D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}], 0n, {==}), find.here(D.Seat1{}, m, ms, [D.At{D.Seat2{}, c}], advance(a, 0n))))
    case D.Trio{+a, +b, +c} D.Seat2{}:
      +cell : {c == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, c, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, c, m <> ms, cell) : Found(D.Trio{a, b, _}, D.Seat2{}, m, ms)
      (advance(b, advance(a, 0n)), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat0{}, a}, D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}], 0n), D.Seat2{}), D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}], advance(a, 0n)), D.Seat2{}), Some{D.Prompt{D.Seat2{}, advance(b, advance(a, 0n)), D.NonEmpty{m, ms}}}, find.after(D.Seat2{}, D.Seat0{}, a, [D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}], 0n, {==}), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}], advance(a, 0n)), D.Seat2{}), D.prompt.find(D.prompts.go([D.At{D.Seat2{}, m <> ms}], advance(b, advance(a, 0n))), D.Seat2{}), Some{D.Prompt{D.Seat2{}, advance(b, advance(a, 0n)), D.NonEmpty{m, ms}}}, find.after(D.Seat2{}, D.Seat1{}, b, [D.At{D.Seat2{}, m <> ms}], advance(a, 0n), {==}), find.here(D.Seat2{}, m, ms, [], advance(b, advance(a, 0n))))))
    case D.Trio{+a, +b, +c} D.Seat3{}:
      absurd(Found(D.Trio{a, b, c}, D.Seat3{}, m, ms), maybe.clash(List<&2, D.Move>, m <> ms, get))
    case D.Quad{+a, +b, +c, +d} D.Seat0{}:
      +cell : {a == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, a, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, a, m <> ms, cell) : Found(D.Quad{_, b, c, d}, D.Seat0{}, m, ms)
      (0n, find.here(D.Seat0{}, m, ms, [D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, d}], 0n))
    case D.Quad{+a, +b, +c, +d} D.Seat1{}:
      +cell : {b == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, b, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, b, m <> ms, cell) : Found(D.Quad{a, _, c, d}, D.Seat1{}, m, ms)
      (advance(a, 0n), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat0{}, a}, D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, d}], 0n), D.Seat1{}), D.prompt.find(D.prompts.go([D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, d}], advance(a, 0n)), D.Seat1{}), Some{D.Prompt{D.Seat1{}, advance(a, 0n), D.NonEmpty{m, ms}}}, find.after(D.Seat1{}, D.Seat0{}, a, [D.At{D.Seat1{}, m <> ms}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, d}], 0n, {==}), find.here(D.Seat1{}, m, ms, [D.At{D.Seat2{}, c}, D.At{D.Seat3{}, d}], advance(a, 0n))))
    case D.Quad{+a, +b, +c, +d} D.Seat2{}:
      +cell : {c == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, c, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, c, m <> ms, cell) : Found(D.Quad{a, b, _, d}, D.Seat2{}, m, ms)
      (advance(b, advance(a, 0n)), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat0{}, a}, D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], 0n), D.Seat2{}), D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], advance(a, 0n)), D.Seat2{}), Some{D.Prompt{D.Seat2{}, advance(b, advance(a, 0n)), D.NonEmpty{m, ms}}}, find.after(D.Seat2{}, D.Seat0{}, a, [D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], 0n, {==}), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], advance(a, 0n)), D.Seat2{}), D.prompt.find(D.prompts.go([D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], advance(b, advance(a, 0n))), D.Seat2{}), Some{D.Prompt{D.Seat2{}, advance(b, advance(a, 0n)), D.NonEmpty{m, ms}}}, find.after(D.Seat2{}, D.Seat1{}, b, [D.At{D.Seat2{}, m <> ms}, D.At{D.Seat3{}, d}], advance(a, 0n), {==}), find.here(D.Seat2{}, m, ms, [D.At{D.Seat3{}, d}], advance(b, advance(a, 0n))))))
    case D.Quad{+a, +b, +c, +d} D.Seat3{}:
      +cell : {d == m <> ms : List<&2, D.Move>} = some.inj(List<&2, D.Move>, d, m <> ms, get)
      %Equal.sym(List<&2, D.Move>, d, m <> ms, cell) : Found(D.Quad{a, b, c, _}, D.Seat3{}, m, ms)
      (advance(c, advance(b, advance(a, 0n))), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat0{}, a}, D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], 0n), D.Seat3{}), D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], advance(a, 0n)), D.Seat3{}), Some{D.Prompt{D.Seat3{}, advance(c, advance(b, advance(a, 0n))), D.NonEmpty{m, ms}}}, find.after(D.Seat3{}, D.Seat0{}, a, [D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], 0n, {==}), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat1{}, b}, D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], advance(a, 0n)), D.Seat3{}), D.prompt.find(D.prompts.go([D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], advance(b, advance(a, 0n))), D.Seat3{}), Some{D.Prompt{D.Seat3{}, advance(c, advance(b, advance(a, 0n))), D.NonEmpty{m, ms}}}, find.after(D.Seat3{}, D.Seat1{}, b, [D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], advance(a, 0n), {==}), Equal.trans(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go([D.At{D.Seat2{}, c}, D.At{D.Seat3{}, m <> ms}], advance(b, advance(a, 0n))), D.Seat3{}), D.prompt.find(D.prompts.go([D.At{D.Seat3{}, m <> ms}], advance(c, advance(b, advance(a, 0n)))), D.Seat3{}), Some{D.Prompt{D.Seat3{}, advance(c, advance(b, advance(a, 0n))), D.NonEmpty{m, ms}}}, find.after(D.Seat3{}, D.Seat2{}, c, [D.At{D.Seat3{}, m <> ms}], advance(b, advance(a, 0n)), {==}), find.here(D.Seat3{}, m, ms, [], advance(c, advance(b, advance(a, 0n))))))))

def legal.at(+ring: D.Ring<&2, List<&2, D.Move>>, +s: D.Seat, +move: D.Move, +prompt: D.Prompt, +index: Maybe<&2, Nat>, +k: Nat, at: {D.prompt.find(D.prompts.go(D.ring.entries(List<&2, D.Move>, ring), 0n), s) == Some{prompt} : Maybe<&2, D.Prompt>}, found: {D.prompt.index(prompt, move) == Some{k} : Maybe<&2, Nat>}) -> {SA.walk.legal(D.Choose{ring}, SA.ChoiceStep{s, move}) == Some{D.prompt.answer(prompt, k)} : Maybe<&2, Nat>}:
  %Equal.sym(Maybe<&2, D.Prompt>, D.prompt.find(D.prompts.go(D.ring.entries(List<&2, D.Move>, ring), 0n), s), Some{prompt}, at) : {SA.walk.prompt(_, move) == Some{D.prompt.answer(prompt, k)} : Maybe<&2, Nat>}
  %Equal.sym(Maybe<&2, Nat>, D.prompt.index(prompt, move), Some{k}, found) : {SA.walk.index(prompt, _) == Some{D.prompt.answer(prompt, k)} : Maybe<&2, Nat>}
  {==}

def any.found(entries: List<&2, D.At<&2, List<&2, D.Move>>>, +first: Nat, +s: D.Seat, +prompt: D.Prompt, e: {D.prompt.find(D.prompts.go(entries, first), s) == Some{prompt} : Maybe<&2, D.Prompt>}) -> {D.menus.any(entries) == True{} : Bool}:
  match entries:
    case Nil{}:
      absurd({D.menus.any(Nil{}) == True{} : Bool}, maybe.clash(D.Prompt, prompt, e))
    case D.At{s0, Nil{}} <> rest:
      any.found(rest, first, s, prompt, e)
    case D.At{s0, m <> ms} <> rest:
      {==}

def hit.at(+entries: List<&2, D.At<&2, List<&2, D.Move>>>, +s: D.Seat, +k: Nat, +prompt: D.Prompt, e: {D.prompt.find(D.prompts.go(entries, 0n), s) == Some{prompt} : Maybe<&2, D.Prompt>}) -> Hit(D.choices.flatten(entries), s, k, Some{prompt}):
  %e : Hit(D.choices.flatten(entries), s, k, _)
  hit(entries, Nil{}, s, k)

# A choice step at a Choose request whose seat's menu holds the move: the
# step's tape answer, and the choice it resolves to.
def Walked(+ring: D.Ring<&2, List<&2, D.Move>>, +s: D.Seat, +move: D.Move, +m: D.Move, +ms: List<&2, D.Move>, +k: Nat) -> Data:
  Sigma<&2, &2, Nat, n => Sigma<&2, &2, {SA.walk.legal(D.request.choose(ring), SA.ChoiceStep{s, move}) == Some{n} : Maybe<&2, Nat>}, _ => {D.resolve(D.request.choose(ring), n) == D.Chose{D.Choice{s, Nat.add(D.clamp(k, List.length(&2, D.Move, ms)), 0n), menu.at(D.clamp(k, List.length(&2, D.Move, ms)), ms, m)}} : D.Resolved}>>

def choose.walk.go(+ring: D.Ring<&2, List<&2, D.Move>>, +s: D.Seat, +move: D.Move, +m: D.Move, +ms: List<&2, D.Move>, +k: Nat, found: {D.menu.find(m <> ms, move) == Some{k} : Maybe<&2, Nat>}, cell: Found(ring, s, m, ms)) -> Walked(ring, s, move, m, ms, k):
  match cell:
    case Tuple{+first, +at}:
      +entries : List<&2, D.At<&2, List<&2, D.Move>>> = D.ring.entries(List<&2, D.Move>, ring)
      +prompt : D.Prompt = D.Prompt{s, first, D.NonEmpty{m, ms}}
      +any : {D.menus.any(entries) == True{} : Bool} = any.found(entries, 0n, s, prompt, at)
      +n : Nat = Nat.add(first, D.clamp(k, List.length(&2, D.Move, ms)))
      %Equal.sym(Bool, D.menus.any(entries), True{}, any) : Sigma<&2, &2, Nat, n => Sigma<&2, &2, {SA.walk.legal(D.request.choose.any(_, ring), SA.ChoiceStep{s, move}) == Some{n} : Maybe<&2, Nat>}, _ => {D.resolve(D.request.choose.any(_, ring), n) == D.Chose{D.Choice{s, Nat.add(D.clamp(k, List.length(&2, D.Move, ms)), 0n), menu.at(D.clamp(k, List.length(&2, D.Move, ms)), ms, m)}} : D.Resolved}>>
      +legal : {SA.walk.legal(D.Choose{ring}, SA.ChoiceStep{s, move}) == Some{n} : Maybe<&2, Nat>} = legal.at(ring, s, move, prompt, D.menu.find(m <> ms, move), k, at, found)
      (n, (legal, Equal.cong(Maybe<&2, D.Choice>, D.Resolved, D.resolve.choice, D.choices.nth(D.choices.flatten(entries), n), Some{D.Choice{s, Nat.add(D.clamp(k, List.length(&2, D.Move, ms)), 0n), menu.at(D.clamp(k, List.length(&2, D.Move, ms)), ms, m)}}, hit.at(entries, s, k, prompt, at))))

def choose.walk(+ring: D.Ring<&2, List<&2, D.Move>>, +s: D.Seat, +move: D.Move, +m: D.Move, +ms: List<&2, D.Move>, +k: Nat, get: {D.ring.get(List<&2, D.Move>, ring, s) == Some{m <> ms} : Maybe<&2, List<&2, D.Move>>}, found: {D.menu.find(m <> ms, move) == Some{k} : Maybe<&2, Nat>}) -> Walked(ring, s, move, m, ms, k):
  choose.walk.go(ring, s, move, m, ms, k, found, prompt.cell(ring, s, m, ms, get))
