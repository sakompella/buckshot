import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/state.bend as S
import ./item-step-proof.bend as ISP
import ./load-proof.bend as LP
import ./use-proof.bend as U
import ./aim-proof.bend as AP
import ./pick-proof.bend as PK
import ./round-proof.bend as RP
import ./load-step-proof.bend as LS

# step_matches for every config: A.Simulation at every A.Valid
# state, by the phase. The win premises of the turn proofs are discharged by
# round-proof.bend.

def step.swap(+w: S.World, +p: S.Players, +ld: D.Load, +sh: List<&2, D.Shell>, +i: Nat, +notes: A.Notes(), +g: S.Grabs, +n: Nat, +valid: A.Valid(S.State{w, p, S.NeedSwap{ld, sh, i}, notes, g})) -> A.Simulation(S.State{w, p, S.NeedSwap{ld, sh, i}, notes, g}, n):
  match i:
    case 0n:
      %A.valid.normal(S.State{w, p, S.NeedSwap{ld, sh, 0n}, notes, g}, valid) : A.Simulation(_, n)
      ISP.simulation.items(S.State{w, p, S.Blocked{None{}}, notes, g}, n, {==}, ISP.valid.normalized(S.State{w, p, S.NeedSwap{ld, sh, 0n}, notes, g}, valid))
    case 1n+e:
      ISP.simulation.items(S.State{w, p, S.NeedSwap{ld, sh, 1n+e}, notes, g}, n, LS.swap.answer(w, p, ld, sh, e, notes, g, n, A.valid.shape(S.State{w, p, S.NeedSwap{ld, sh, 1n+e}, notes, g}, valid)), LS.valid.swap.answer(w, p, ld, sh, e, notes, g, n, valid))


def step.items(+s: S.State, +n: Nat, +valid: A.Valid(s)) -> A.Simulation(s, n):
  match s:
    case S.State{+w, +p, +ph, +notes, +g}:
      match ph:
        case S.NeedFirst{}:
          RP.step.first(w, p, notes, g, n, valid)
        case S.NeedHealth{}:
          RP.step.health(w, p, notes, g, n, valid)
        case S.NeedAmount{}:
          RP.step.amount(w, p, notes, g, n, valid)
        case S.NeedBatch{}:
          LS.step.batch(w, p, notes, g, n, valid)
        case S.NeedSwap{+ld, +sh, +i}:
          step.swap(w, p, ld, sh, i, notes, g, n, valid)
        case S.Idle{+seat, +options}:
          U.step.idle(w, p, seat, options, notes, g, n, valid, RP.win.closure(), RP.win.valid())
        case S.Aim{+seat}:
          AP.step.aim(w, p, seat, notes, g, n, valid, RP.win.closure(), RP.win.valid())
        case S.Ended{}:
          ISP.simulation.items(S.State{w, p, S.Ended{}, notes, g}, n, {==}, valid)
        case S.Blocked{+holder}:
          ISP.simulation.items(S.State{w, p, S.Blocked{holder}, notes, g}, n, {==}, valid)
        case S.NeedTurnAmount{+from, +passing, +winner}:
          PK.step.turn.amount(w, p, from, passing, winner, notes, g, n, valid, RP.win.closure(), RP.win.valid())
        case S.Grab{+needs}:
          LP.step.grab(w, p, needs, notes, g, n, valid)
        case S.NeedItem{+seat, +first, +second, +rest}:
          LP.step.item(w, p, seat, first, second, rest, notes, g, n, valid)
        case S.NeedPhone{+seat, +owner, +slot}:
          PK.step.phone(w, p, seat, owner, slot, notes, g, n, valid, RP.win.closure(), RP.win.valid())
        case S.JamPick{+seat, +targets}:
          PK.step.jam(w, p, seat, targets, notes, g, n, valid)
        case S.StealPick{+seat, +picks}:
          PK.step.steal(w, p, seat, picks, notes, g, n, valid, RP.win.closure(), RP.win.valid())
