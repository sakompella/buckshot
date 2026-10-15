import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./sm/main.bend as M
import ./simple/state.bend as T
import ./simple/main.bend as N
import ./simple/point.bend as P
import ./simple-abstract.bend as SA

# The simple machine refines sm. Every law is stated over the simple
# machine, sm and the bridge simple-abstract.bend: embed maps a simple state
# to the sm state it stands for, chain lists the sm steps of one simple
# answer and walk plays them on sm, refusing any step sm does not offer.

law simple_start:
  for +config: D.Config
  {SA.lift(N.start(config)) == Some{M.start(config)} : Maybe<&2, D.Stepped<&2, S.State>>}

# Every simple answer is a chain of legal sm moves ending at the state that
# maps the simple answer's state, with the same notes. No premise is needed.
law simple_refines:
  for +state: T.State
  for +n: Nat
  {SA.walk(SA.embed(state), SA.chain(state, n)) == SA.lift(N.answer(state, n)) : Maybe<&2, D.Stepped<&2, S.State>>}

law simple_roundtrip:
  for +state: T.State
  {SA.back(SA.embed(state)) == state : T.State}

law simple_valid:
  for +state: T.State
  for +valid: A.Valid(SA.embed(state))
  for +n: Nat
  A.Valid(SA.embed(N.stepped.state(N.answer(state, n))))

law simple_reachable_valid:
  for fuel: Nat
  for +config: D.Config
  for +tape: List<&2, Nat>
  A.Valid(SA.embed(SA.ran.state(N.run(fuel, N.stepped.state(N.start(config)), tape))))

law simple_run_refines:
  for fuel: Nat
  for +state: T.State
  for +tape: List<&2, Nat>
  {SA.replay(SA.embed(state), SA.chains(fuel, state, tape)) == SA.ran(N.run(fuel, state, tape)) : Maybe<&2, D.Stepped<&2, S.State>>}

law simple_observe:
  for +state: T.State
  for +seat: D.Seat
  {(D.Obs{seat, P.board(state)}, D.hear(T.state.notes(state), seat)) == (D.observe(M.point(SA.embed(state)), seat), D.hear(S.state.notes(SA.embed(state)), seat)) : D.Obs & List<&2, D.Heard>}

law simple_privacy:
  for +state: T.State
  for +gun: List<&2, D.Shell>
  for decks: S.Decks
  for +seat: D.Seat
  for same_length: {List.length(&2, D.Shell, S.world.gun(T.state.world(state))) == List.length(&2, D.Shell, gun) : Nat}
  {(D.Obs{seat, P.board(state)}, D.hear(T.state.notes(state), seat)) == (D.Obs{seat, P.board(N.replace_hidden(state, gun, decks))}, D.hear(T.state.notes(N.replace_hidden(state, gun, decks)), seat)) : D.Obs & List<&2, D.Heard>}
