import Base
import ./domain.bend as D
import ./web.bend as W
import ./analysis.bend as N
import ./player/types.bend as A
import ./simple/state.bend as T

# THROWAWAY PROTOTYPE: a native entry for the minimax evaluator. Reads one
# analysis input per line (numbers only, see web/scripts/native-eval.ts) and
# prints one result line per input. The evaluator is analysis.bend's `analyse`,
# unchanged; this file only decodes and prints.



def tok(r: List<&2, Nat>) -> Nat & List<&2, Nat>:
  match r:
    case Nil{}:
      (0n, Nil{})
    case Con{h, t}:
      (h, t)

def dec.nat(r: List<&2, Nat>) -> Nat & List<&2, Nat>:
  tok(r)

def dec.u32.of(p: Nat & List<&2, Nat>) -> U32 & List<&2, Nat>:
  (t, r1) = p
  (U32.from_nat(t), r1)

def dec.u32(r: List<&2, Nat>) -> U32 & List<&2, Nat>:
  dec.u32.of(tok(r))

def dec.bool.of(p: Nat & List<&2, Nat>) -> Bool & List<&2, Nat>:
  (t, r1) = p
  (Nat.is_gt(t, 0n), r1)

def dec.bool(r: List<&2, Nat>) -> Bool & List<&2, Nat>:
  dec.bool.of(tok(r))

def dec.seat.c0(r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  (D.Seat0{}, r)

def dec.seat.c1(r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  (D.Seat1{}, r)

def dec.seat.c2(r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  (D.Seat2{}, r)

def dec.seat.c3(r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  (D.Seat3{}, r)

def dec.seat.k3(t: Nat, r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  dec.seat.c3(r)

def dec.seat.k2(t: Nat, r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  match t:
    case 0n:
      dec.seat.c2(r)
    case 1n+p:
      dec.seat.k3(p, r)

def dec.seat.k1(t: Nat, r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  match t:
    case 0n:
      dec.seat.c1(r)
    case 1n+p:
      dec.seat.k2(p, r)

def dec.seat.k0(t: Nat, r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  match t:
    case 0n:
      dec.seat.c0(r)
    case 1n+p:
      dec.seat.k1(p, r)

def dec.seat.pick(p: Nat & List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  (t, r1) = p
  dec.seat.k0(t, r1)

def dec.seat(r: List<&2, Nat>) -> D.Seat & List<&2, Nat>:
  dec.seat.pick(tok(r))

def dec.event.c0.s3(v0: Nat, v1: Nat, p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v2, r3) = p
  (D.RoundBegan{v0, v1, v2}, r3)

def dec.event.c0.s2(v0: Nat, p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  dec.event.c0.s3(v0, v1, dec.seat(r2))

def dec.event.c0.s1(p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c0.s2(v0, dec.nat(r1))

def dec.event.c0(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c0.s1(dec.nat(r))

def dec.event.c1.s1(p: List<&2, D.Seat> & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.GrabbingBegan{v0}, r1)

def dec.list_seat.add(acc: List<&2, D.Seat>, p: D.Seat & List<&2, Nat>) -> List<&2, D.Seat> & List<&2, Nat>:
  (x, r1) = p
  (Con{x, acc}, r1)

def dec.list_seat.step(st: List<&2, D.Seat> & List<&2, Nat>) -> List<&2, D.Seat> & List<&2, Nat>:
  (acc, r) = st
  dec.list_seat.add(acc, dec.seat(r))

def dec.list_seat.go(n: Nat, st: List<&2, D.Seat> & List<&2, Nat>) -> List<&2, D.Seat> & List<&2, Nat>:
  match n:
    case 0n:
      st
    case 1n+p:
      dec.list_seat.go(p, dec.list_seat.step(st))

def dec.list_seat.n(p: Nat & List<&2, Nat>) -> List<&2, D.Seat> & List<&2, Nat>:
  (n, r1) = p
  dec.list_seat.go(n, (Nil{}, r1))

def dec.list_seat(r: List<&2, Nat>) -> List<&2, D.Seat> & List<&2, Nat>:
  dec.list_seat.n(tok(r))

def dec.event.c1(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c1.s1(dec.list_seat(r))

def dec.item.c0(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Saw{}, r)

def dec.item.c1(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Glass{}, r)

def dec.item.c2(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Jammer{}, r)

def dec.item.c3(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Cigarettes{}, r)

def dec.item.c4(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Beer{}, r)

def dec.item.c5(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Phone{}, r)

def dec.item.c6(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Inverter{}, r)

def dec.item.c7(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Adrenaline{}, r)

def dec.item.c8(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (D.Remote{}, r)

def dec.item.k8(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  dec.item.c8(r)

def dec.item.k7(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c7(r)
    case 1n+p:
      dec.item.k8(p, r)

def dec.item.k6(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c6(r)
    case 1n+p:
      dec.item.k7(p, r)

def dec.item.k5(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c5(r)
    case 1n+p:
      dec.item.k6(p, r)

def dec.item.k4(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c4(r)
    case 1n+p:
      dec.item.k5(p, r)

def dec.item.k3(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c3(r)
    case 1n+p:
      dec.item.k4(p, r)

def dec.item.k2(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c2(r)
    case 1n+p:
      dec.item.k3(p, r)

def dec.item.k1(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c1(r)
    case 1n+p:
      dec.item.k2(p, r)

def dec.item.k0(t: Nat, r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  match t:
    case 0n:
      dec.item.c0(r)
    case 1n+p:
      dec.item.k1(p, r)

def dec.item.pick(p: Nat & List<&2, Nat>) -> D.Item & List<&2, Nat>:
  (t, r1) = p
  dec.item.k0(t, r1)

def dec.item(r: List<&2, Nat>) -> D.Item & List<&2, Nat>:
  dec.item.pick(tok(r))

def dec.event.c2.s2(v0: D.Seat, p: D.Item & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  (D.Granted{v0, v1}, r2)

def dec.event.c2.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c2.s2(v0, dec.item(r1))

def dec.event.c2(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c2.s1(dec.seat(r))

def dec.slot.c0(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot0{}, r)

def dec.slot.c1(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot1{}, r)

def dec.slot.c2(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot2{}, r)

def dec.slot.c3(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot3{}, r)

def dec.slot.c4(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot4{}, r)

def dec.slot.c5(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot5{}, r)

def dec.slot.c6(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot6{}, r)

def dec.slot.c7(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (D.Slot7{}, r)

def dec.slot.k7(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  dec.slot.c7(r)

def dec.slot.k6(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c6(r)
    case 1n+p:
      dec.slot.k7(p, r)

def dec.slot.k5(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c5(r)
    case 1n+p:
      dec.slot.k6(p, r)

def dec.slot.k4(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c4(r)
    case 1n+p:
      dec.slot.k5(p, r)

def dec.slot.k3(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c3(r)
    case 1n+p:
      dec.slot.k4(p, r)

def dec.slot.k2(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c2(r)
    case 1n+p:
      dec.slot.k3(p, r)

def dec.slot.k1(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c1(r)
    case 1n+p:
      dec.slot.k2(p, r)

def dec.slot.k0(t: Nat, r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  match t:
    case 0n:
      dec.slot.c0(r)
    case 1n+p:
      dec.slot.k1(p, r)

def dec.slot.pick(p: Nat & List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  (t, r1) = p
  dec.slot.k0(t, r1)

def dec.slot(r: List<&2, Nat>) -> D.Slot & List<&2, Nat>:
  dec.slot.pick(tok(r))

def dec.event.c3.s3(v0: D.Seat, v1: D.Slot, p: D.Item & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v2, r3) = p
  (D.Placed{v0, v1, v2}, r3)

def dec.event.c3.s2(v0: D.Seat, p: D.Slot & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  dec.event.c3.s3(v0, v1, dec.item(r2))

def dec.event.c3.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c3.s2(v0, dec.slot(r1))

def dec.event.c3(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c3.s1(dec.seat(r))

def dec.event.c4.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.GrabbingEnded{v0}, r1)

def dec.event.c4(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c4.s1(dec.seat(r))

def dec.event.c5(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (D.DistributionDone{}, r)

def dec.load.c0.s2(v0: Nat, p: Nat & List<&2, Nat>) -> D.Load & List<&2, Nat>:
  (v1, r2) = p
  (D.Load{v0, v1}, r2)

def dec.load.c0.s1(p: Nat & List<&2, Nat>) -> D.Load & List<&2, Nat>:
  (v0, r1) = p
  dec.load.c0.s2(v0, dec.nat(r1))

def dec.load.c0(r: List<&2, Nat>) -> D.Load & List<&2, Nat>:
  dec.load.c0.s1(dec.nat(r))

def dec.load(r: List<&2, Nat>) -> D.Load & List<&2, Nat>:
  dec.load.c0(r)

def dec.event.c6.s1(p: D.Load & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.Loaded{v0}, r1)

def dec.event.c6(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c6.s1(dec.load(r))

def dec.event.c7.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.TurnSkipped{v0}, r1)

def dec.event.c7(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c7.s1(dec.seat(r))

def dec.event.c8.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.JamLifted{v0}, r1)

def dec.event.c8(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c8.s1(dec.seat(r))

def dec.event.c9.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.TurnGiven{v0}, r1)

def dec.event.c9(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c9.s1(dec.seat(r))

def dec.event.c10.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.PickedUp{v0}, r1)

def dec.event.c10(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c10.s1(dec.seat(r))

def dec.shell.c0(r: List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  (D.Live{}, r)

def dec.shell.c1(r: List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  (D.Blank{}, r)

def dec.shell.k1(t: Nat, r: List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  dec.shell.c1(r)

def dec.shell.k0(t: Nat, r: List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  match t:
    case 0n:
      dec.shell.c0(r)
    case 1n+p:
      dec.shell.k1(p, r)

def dec.shell.pick(p: Nat & List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  (t, r1) = p
  dec.shell.k0(t, r1)

def dec.shell(r: List<&2, Nat>) -> D.Shell & List<&2, Nat>:
  dec.shell.pick(tok(r))

def dec.damage.c0(r: List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  (D.Single{}, r)

def dec.damage.c1(r: List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  (D.Double{}, r)

def dec.damage.k1(t: Nat, r: List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  dec.damage.c1(r)

def dec.damage.k0(t: Nat, r: List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  match t:
    case 0n:
      dec.damage.c0(r)
    case 1n+p:
      dec.damage.k1(p, r)

def dec.damage.pick(p: Nat & List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  (t, r1) = p
  dec.damage.k0(t, r1)

def dec.damage(r: List<&2, Nat>) -> D.Damage & List<&2, Nat>:
  dec.damage.pick(tok(r))

def dec.event.c11.s6(v0: D.Seat, v1: D.Seat, v2: D.Shell, v3: D.Damage, v4: Nat, p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v5, r6) = p
  (D.Fired{v0, v1, v2, v3, v4, v5}, r6)

def dec.event.c11.s5(v0: D.Seat, v1: D.Seat, v2: D.Shell, v3: D.Damage, p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v4, r5) = p
  dec.event.c11.s6(v0, v1, v2, v3, v4, dec.nat(r5))

def dec.event.c11.s4(v0: D.Seat, v1: D.Seat, v2: D.Shell, p: D.Damage & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v3, r4) = p
  dec.event.c11.s5(v0, v1, v2, v3, dec.nat(r4))

def dec.event.c11.s3(v0: D.Seat, v1: D.Seat, p: D.Shell & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v2, r3) = p
  dec.event.c11.s4(v0, v1, v2, dec.damage(r3))

def dec.event.c11.s2(v0: D.Seat, p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  dec.event.c11.s3(v0, v1, dec.shell(r2))

def dec.event.c11.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c11.s2(v0, dec.seat(r1))

def dec.event.c11(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c11.s1(dec.seat(r))

def dec.event.c12.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.Died{v0}, r1)

def dec.event.c12(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c12.s1(dec.seat(r))

def dec.event.c13.s4(v0: D.Seat, v1: D.Seat, v2: D.Slot, p: D.Item & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v3, r4) = p
  (D.Used{v0, v1, v2, v3}, r4)

def dec.event.c13.s3(v0: D.Seat, v1: D.Seat, p: D.Slot & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v2, r3) = p
  dec.event.c13.s4(v0, v1, v2, dec.item(r3))

def dec.event.c13.s2(v0: D.Seat, p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  dec.event.c13.s3(v0, v1, dec.slot(r2))

def dec.event.c13.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c13.s2(v0, dec.seat(r1))

def dec.event.c13(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c13.s1(dec.seat(r))

def dec.event.c14.s2(v0: D.Seat, p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  (D.Healed{v0, v1}, r2)

def dec.event.c14.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c14.s2(v0, dec.nat(r1))

def dec.event.c14(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c14.s1(dec.seat(r))

def dec.event.c15.s2(v0: D.Seat, p: D.Shell & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  (D.Ejected{v0, v1}, r2)

def dec.event.c15.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c15.s2(v0, dec.shell(r1))

def dec.event.c15(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c15.s1(dec.seat(r))

def dec.event.c16.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.Inverted{v0}, r1)

def dec.event.c16(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c16.s1(dec.seat(r))

def dec.event.c17.s2(v0: D.Seat, p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  (D.JamApplied{v0, v1}, r2)

def dec.event.c17.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c17.s2(v0, dec.seat(r1))

def dec.event.c17(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c17.s1(dec.seat(r))

def dec.direction.c0(r: List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  (D.Clockwise{}, r)

def dec.direction.c1(r: List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  (D.CounterClockwise{}, r)

def dec.direction.k1(t: Nat, r: List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  dec.direction.c1(r)

def dec.direction.k0(t: Nat, r: List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  match t:
    case 0n:
      dec.direction.c0(r)
    case 1n+p:
      dec.direction.k1(p, r)

def dec.direction.pick(p: Nat & List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  (t, r1) = p
  dec.direction.k0(t, r1)

def dec.direction(r: List<&2, Nat>) -> D.Direction & List<&2, Nat>:
  dec.direction.pick(tok(r))

def dec.event.c18.s1(p: D.Direction & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  (D.DirectionFlipped{v0}, r1)

def dec.event.c18(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c18.s1(dec.direction(r))

def dec.event.c19.s2(v0: D.Seat, p: U32 & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v1, r2) = p
  (D.RoundWon{v0, v1}, r2)

def dec.event.c19.s1(p: D.Seat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (v0, r1) = p
  dec.event.c19.s2(v0, dec.u32(r1))

def dec.event.c19(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c19.s1(dec.seat(r))

def dec.event.c20(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (D.MatchConcluded{}, r)

def dec.event.k20(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.c20(r)

def dec.event.k19(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c19(r)
    case 1n+p:
      dec.event.k20(p, r)

def dec.event.k18(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c18(r)
    case 1n+p:
      dec.event.k19(p, r)

def dec.event.k17(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c17(r)
    case 1n+p:
      dec.event.k18(p, r)

def dec.event.k16(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c16(r)
    case 1n+p:
      dec.event.k17(p, r)

def dec.event.k15(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c15(r)
    case 1n+p:
      dec.event.k16(p, r)

def dec.event.k14(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c14(r)
    case 1n+p:
      dec.event.k15(p, r)

def dec.event.k13(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c13(r)
    case 1n+p:
      dec.event.k14(p, r)

def dec.event.k12(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c12(r)
    case 1n+p:
      dec.event.k13(p, r)

def dec.event.k11(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c11(r)
    case 1n+p:
      dec.event.k12(p, r)

def dec.event.k10(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c10(r)
    case 1n+p:
      dec.event.k11(p, r)

def dec.event.k9(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c9(r)
    case 1n+p:
      dec.event.k10(p, r)

def dec.event.k8(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c8(r)
    case 1n+p:
      dec.event.k9(p, r)

def dec.event.k7(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c7(r)
    case 1n+p:
      dec.event.k8(p, r)

def dec.event.k6(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c6(r)
    case 1n+p:
      dec.event.k7(p, r)

def dec.event.k5(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c5(r)
    case 1n+p:
      dec.event.k6(p, r)

def dec.event.k4(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c4(r)
    case 1n+p:
      dec.event.k5(p, r)

def dec.event.k3(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c3(r)
    case 1n+p:
      dec.event.k4(p, r)

def dec.event.k2(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c2(r)
    case 1n+p:
      dec.event.k3(p, r)

def dec.event.k1(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c1(r)
    case 1n+p:
      dec.event.k2(p, r)

def dec.event.k0(t: Nat, r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  match t:
    case 0n:
      dec.event.c0(r)
    case 1n+p:
      dec.event.k1(p, r)

def dec.event.pick(p: Nat & List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  (t, r1) = p
  dec.event.k0(t, r1)

def dec.event(r: List<&2, Nat>) -> D.GameEvent & List<&2, Nat>:
  dec.event.pick(tok(r))

def dec.heard.c0.s1(p: D.GameEvent & List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  (v0, r1) = p
  (D.Witnessed{v0}, r1)

def dec.heard.c0(r: List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  dec.heard.c0.s1(dec.event(r))

def dec.secret.c0.s1(p: D.Shell & List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (v0, r1) = p
  (D.Glimpse{v0}, r1)

def dec.secret.c0(r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  dec.secret.c0.s1(dec.shell(r))

def dec.secret.c1.s2(v0: Nat, p: D.Shell & List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (v1, r2) = p
  (D.Clue{v0, v1}, r2)

def dec.secret.c1.s1(p: Nat & List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (v0, r1) = p
  dec.secret.c1.s2(v0, dec.shell(r1))

def dec.secret.c1(r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  dec.secret.c1.s1(dec.nat(r))

def dec.secret.c2(r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (D.NoClue{}, r)

def dec.secret.c3(r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (D.EmptyBriefcase{}, r)

def dec.secret.k3(t: Nat, r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  dec.secret.c3(r)

def dec.secret.k2(t: Nat, r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  match t:
    case 0n:
      dec.secret.c2(r)
    case 1n+p:
      dec.secret.k3(p, r)

def dec.secret.k1(t: Nat, r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  match t:
    case 0n:
      dec.secret.c1(r)
    case 1n+p:
      dec.secret.k2(p, r)

def dec.secret.k0(t: Nat, r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  match t:
    case 0n:
      dec.secret.c0(r)
    case 1n+p:
      dec.secret.k1(p, r)

def dec.secret.pick(p: Nat & List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  (t, r1) = p
  dec.secret.k0(t, r1)

def dec.secret(r: List<&2, Nat>) -> D.Secret & List<&2, Nat>:
  dec.secret.pick(tok(r))

def dec.heard.c1.s1(p: D.Secret & List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  (v0, r1) = p
  (D.Learned{v0}, r1)

def dec.heard.c1(r: List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  dec.heard.c1.s1(dec.secret(r))

def dec.heard.k1(t: Nat, r: List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  dec.heard.c1(r)

def dec.heard.k0(t: Nat, r: List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  match t:
    case 0n:
      dec.heard.c0(r)
    case 1n+p:
      dec.heard.k1(p, r)

def dec.heard.pick(p: Nat & List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  (t, r1) = p
  dec.heard.k0(t, r1)

def dec.heard(r: List<&2, Nat>) -> D.Heard & List<&2, Nat>:
  dec.heard.pick(tok(r))

def dec.mode.c0(r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  (D.Idle{}, r)

def dec.mode.c1(r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  (D.Aiming{}, r)

def dec.mode.c2(r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  (D.Jamming{}, r)

def dec.mode.c3(r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  (D.Stealing{}, r)

def dec.mode.k3(t: Nat, r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  dec.mode.c3(r)

def dec.mode.k2(t: Nat, r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  match t:
    case 0n:
      dec.mode.c2(r)
    case 1n+p:
      dec.mode.k3(p, r)

def dec.mode.k1(t: Nat, r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  match t:
    case 0n:
      dec.mode.c1(r)
    case 1n+p:
      dec.mode.k2(p, r)

def dec.mode.k0(t: Nat, r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  match t:
    case 0n:
      dec.mode.c0(r)
    case 1n+p:
      dec.mode.k1(p, r)

def dec.mode.pick(p: Nat & List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  (t, r1) = p
  dec.mode.k0(t, r1)

def dec.mode(r: List<&2, Nat>) -> D.Mode & List<&2, Nat>:
  dec.mode.pick(tok(r))

def dec.maybe_item.c0(r: List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  (None{}, r)

def dec.maybe_item.c1.s1(p: D.Item & List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  (v0, r1) = p
  (Some{v0}, r1)

def dec.maybe_item.c1(r: List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  dec.maybe_item.c1.s1(dec.item(r))

def dec.maybe_item.k1(t: Nat, r: List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  dec.maybe_item.c1(r)

def dec.maybe_item.k0(t: Nat, r: List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  match t:
    case 0n:
      dec.maybe_item.c0(r)
    case 1n+p:
      dec.maybe_item.k1(p, r)

def dec.maybe_item.pick(p: Nat & List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  (t, r1) = p
  dec.maybe_item.k0(t, r1)

def dec.maybe_item(r: List<&2, Nat>) -> Maybe<&2, D.Item> & List<&2, Nat>:
  dec.maybe_item.pick(tok(r))

def dec.counter.c0.s1(p: Nat & List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  (v0, r1) = p
  (D.Unjammed{v0}, r1)

def dec.counter.c0(r: List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  dec.counter.c0.s1(dec.nat(r))

def dec.counter.c1(r: List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  (D.Jammed{}, r)

def dec.counter.k1(t: Nat, r: List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  dec.counter.c1(r)

def dec.counter.k0(t: Nat, r: List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  match t:
    case 0n:
      dec.counter.c0(r)
    case 1n+p:
      dec.counter.k1(p, r)

def dec.counter.pick(p: Nat & List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  (t, r1) = p
  dec.counter.k0(t, r1)

def dec.counter(r: List<&2, Nat>) -> D.Counter & List<&2, Nat>:
  dec.counter.pick(tok(r))

def dec.briefcase.c0(r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  (D.NotGrabbing{}, r)

def dec.briefcase.c1(r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  (D.Grabbing{}, r)

def dec.briefcase.c2.s1(p: D.Item & List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  (v0, r1) = p
  (D.Holding{v0}, r1)

def dec.briefcase.c2(r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  dec.briefcase.c2.s1(dec.item(r))

def dec.briefcase.k2(t: Nat, r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  dec.briefcase.c2(r)

def dec.briefcase.k1(t: Nat, r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  match t:
    case 0n:
      dec.briefcase.c1(r)
    case 1n+p:
      dec.briefcase.k2(p, r)

def dec.briefcase.k0(t: Nat, r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  match t:
    case 0n:
      dec.briefcase.c0(r)
    case 1n+p:
      dec.briefcase.k1(p, r)

def dec.briefcase.pick(p: Nat & List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  (t, r1) = p
  dec.briefcase.k0(t, r1)

def dec.briefcase(r: List<&2, Nat>) -> D.Briefcase & List<&2, Nat>:
  dec.briefcase.pick(tok(r))

def dec.slots.c0.s8(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, v2: Maybe<&2, D.Item>, v3: Maybe<&2, D.Item>, v4: Maybe<&2, D.Item>, v5: Maybe<&2, D.Item>, v6: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v7, r8) = p
  (D.Slots{v0, v1, v2, v3, v4, v5, v6, v7}, r8)

def dec.slots.c0.s7(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, v2: Maybe<&2, D.Item>, v3: Maybe<&2, D.Item>, v4: Maybe<&2, D.Item>, v5: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v6, r7) = p
  dec.slots.c0.s8(v0, v1, v2, v3, v4, v5, v6, dec.maybe_item(r7))

def dec.slots.c0.s6(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, v2: Maybe<&2, D.Item>, v3: Maybe<&2, D.Item>, v4: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v5, r6) = p
  dec.slots.c0.s7(v0, v1, v2, v3, v4, v5, dec.maybe_item(r6))

def dec.slots.c0.s5(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, v2: Maybe<&2, D.Item>, v3: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v4, r5) = p
  dec.slots.c0.s6(v0, v1, v2, v3, v4, dec.maybe_item(r5))

def dec.slots.c0.s4(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, v2: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v3, r4) = p
  dec.slots.c0.s5(v0, v1, v2, v3, dec.maybe_item(r4))

def dec.slots.c0.s3(v0: Maybe<&2, D.Item>, v1: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v2, r3) = p
  dec.slots.c0.s4(v0, v1, v2, dec.maybe_item(r3))

def dec.slots.c0.s2(v0: Maybe<&2, D.Item>, p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v1, r2) = p
  dec.slots.c0.s3(v0, v1, dec.maybe_item(r2))

def dec.slots.c0.s1(p: Maybe<&2, D.Item> & List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  (v0, r1) = p
  dec.slots.c0.s2(v0, dec.maybe_item(r1))

def dec.slots.c0(r: List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  dec.slots.c0.s1(dec.maybe_item(r))

def dec.slots(r: List<&2, Nat>) -> D.Slots & List<&2, Nat>:
  dec.slots.c0(r)

def dec.seatview.c0.s4(v0: D.Counter, v1: D.Slots, v2: U32, p: D.Briefcase & List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  (v3, r4) = p
  (D.SeatView{v0, v1, v2, v3}, r4)

def dec.seatview.c0.s3(v0: D.Counter, v1: D.Slots, p: U32 & List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  (v2, r3) = p
  dec.seatview.c0.s4(v0, v1, v2, dec.briefcase(r3))

def dec.seatview.c0.s2(v0: D.Counter, p: D.Slots & List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  (v1, r2) = p
  dec.seatview.c0.s3(v0, v1, dec.u32(r2))

def dec.seatview.c0.s1(p: D.Counter & List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  (v0, r1) = p
  dec.seatview.c0.s2(v0, dec.slots(r1))

def dec.seatview.c0(r: List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  dec.seatview.c0.s1(dec.counter(r))

def dec.seatview(r: List<&2, Nat>) -> D.SeatView & List<&2, Nat>:
  dec.seatview.c0(r)

def dec.ring.c0.s2(v0: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v1, r2) = p
  (D.Duo{v0, v1}, r2)

def dec.ring.c0.s1(p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v0, r1) = p
  dec.ring.c0.s2(v0, dec.seatview(r1))

def dec.ring.c0(r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  dec.ring.c0.s1(dec.seatview(r))

def dec.ring.c1.s3(v0: D.SeatView, v1: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v2, r3) = p
  (D.Trio{v0, v1, v2}, r3)

def dec.ring.c1.s2(v0: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v1, r2) = p
  dec.ring.c1.s3(v0, v1, dec.seatview(r2))

def dec.ring.c1.s1(p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v0, r1) = p
  dec.ring.c1.s2(v0, dec.seatview(r1))

def dec.ring.c1(r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  dec.ring.c1.s1(dec.seatview(r))

def dec.ring.c2.s4(v0: D.SeatView, v1: D.SeatView, v2: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v3, r4) = p
  (D.Quad{v0, v1, v2, v3}, r4)

def dec.ring.c2.s3(v0: D.SeatView, v1: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v2, r3) = p
  dec.ring.c2.s4(v0, v1, v2, dec.seatview(r3))

def dec.ring.c2.s2(v0: D.SeatView, p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v1, r2) = p
  dec.ring.c2.s3(v0, v1, dec.seatview(r2))

def dec.ring.c2.s1(p: D.SeatView & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (v0, r1) = p
  dec.ring.c2.s2(v0, dec.seatview(r1))

def dec.ring.c2(r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  dec.ring.c2.s1(dec.seatview(r))

def dec.ring.k2(t: Nat, r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  dec.ring.c2(r)

def dec.ring.k1(t: Nat, r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  match t:
    case 0n:
      dec.ring.c1(r)
    case 1n+p:
      dec.ring.k2(p, r)

def dec.ring.k0(t: Nat, r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  match t:
    case 0n:
      dec.ring.c0(r)
    case 1n+p:
      dec.ring.k1(p, r)

def dec.ring.pick(p: Nat & List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  (t, r1) = p
  dec.ring.k0(t, r1)

def dec.ring(r: List<&2, Nat>) -> D.Ring<&2, D.SeatView> & List<&2, Nat>:
  dec.ring.pick(tok(r))

def dec.gun.c0.s3(v0: D.Load, v1: Nat, p: Bool & List<&2, Nat>) -> D.GunView & List<&2, Nat>:
  (v2, r3) = p
  (D.GunView{v0, v1, v2}, r3)

def dec.gun.c0.s2(v0: D.Load, p: Nat & List<&2, Nat>) -> D.GunView & List<&2, Nat>:
  (v1, r2) = p
  dec.gun.c0.s3(v0, v1, dec.bool(r2))

def dec.gun.c0.s1(p: D.Load & List<&2, Nat>) -> D.GunView & List<&2, Nat>:
  (v0, r1) = p
  dec.gun.c0.s2(v0, dec.nat(r1))

def dec.gun.c0(r: List<&2, Nat>) -> D.GunView & List<&2, Nat>:
  dec.gun.c0.s1(dec.load(r))

def dec.gun(r: List<&2, Nat>) -> D.GunView & List<&2, Nat>:
  dec.gun.c0(r)

def dec.roundview.c0.s3(v0: Nat, v1: Nat, p: Nat & List<&2, Nat>) -> D.RoundView & List<&2, Nat>:
  (v2, r3) = p
  (D.RoundView{v0, v1, v2}, r3)

def dec.roundview.c0.s2(v0: Nat, p: Nat & List<&2, Nat>) -> D.RoundView & List<&2, Nat>:
  (v1, r2) = p
  dec.roundview.c0.s3(v0, v1, dec.nat(r2))

def dec.roundview.c0.s1(p: Nat & List<&2, Nat>) -> D.RoundView & List<&2, Nat>:
  (v0, r1) = p
  dec.roundview.c0.s2(v0, dec.nat(r1))

def dec.roundview.c0(r: List<&2, Nat>) -> D.RoundView & List<&2, Nat>:
  dec.roundview.c0.s1(dec.nat(r))

def dec.roundview(r: List<&2, Nat>) -> D.RoundView & List<&2, Nat>:
  dec.roundview.c0(r)

def dec.stage.c0(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (D.Setup{}, r)

def dec.stage.c1(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (D.Distributing{}, r)

def dec.stage.c2(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (D.Loading{}, r)

def dec.stage.c3.s2(v0: D.Seat, p: D.Mode & List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (v1, r2) = p
  (D.Playing{v0, v1}, r2)

def dec.stage.c3.s1(p: D.Seat & List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (v0, r1) = p
  dec.stage.c3.s2(v0, dec.mode(r1))

def dec.stage.c3(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  dec.stage.c3.s1(dec.seat(r))

def dec.stage.c4(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (D.MatchOver{}, r)

def dec.stage.k4(t: Nat, r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  dec.stage.c4(r)

def dec.stage.k3(t: Nat, r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  match t:
    case 0n:
      dec.stage.c3(r)
    case 1n+p:
      dec.stage.k4(p, r)

def dec.stage.k2(t: Nat, r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  match t:
    case 0n:
      dec.stage.c2(r)
    case 1n+p:
      dec.stage.k3(p, r)

def dec.stage.k1(t: Nat, r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  match t:
    case 0n:
      dec.stage.c1(r)
    case 1n+p:
      dec.stage.k2(p, r)

def dec.stage.k0(t: Nat, r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  match t:
    case 0n:
      dec.stage.c0(r)
    case 1n+p:
      dec.stage.k1(p, r)

def dec.stage.pick(p: Nat & List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  (t, r1) = p
  dec.stage.k0(t, r1)

def dec.stage(r: List<&2, Nat>) -> D.Stage & List<&2, Nat>:
  dec.stage.pick(tok(r))

def dec.board.c0.s5(v0: D.RoundView, v1: D.Ring<&2, D.SeatView>, v2: D.GunView, v3: D.Direction, p: D.Stage & List<&2, Nat>) -> D.Board & List<&2, Nat>:
  (v4, r5) = p
  (D.Board{v0, v1, v2, v3, v4}, r5)

def dec.board.c0.s4(v0: D.RoundView, v1: D.Ring<&2, D.SeatView>, v2: D.GunView, p: D.Direction & List<&2, Nat>) -> D.Board & List<&2, Nat>:
  (v3, r4) = p
  dec.board.c0.s5(v0, v1, v2, v3, dec.stage(r4))

def dec.board.c0.s3(v0: D.RoundView, v1: D.Ring<&2, D.SeatView>, p: D.GunView & List<&2, Nat>) -> D.Board & List<&2, Nat>:
  (v2, r3) = p
  dec.board.c0.s4(v0, v1, v2, dec.direction(r3))

def dec.board.c0.s2(v0: D.RoundView, p: D.Ring<&2, D.SeatView> & List<&2, Nat>) -> D.Board & List<&2, Nat>:
  (v1, r2) = p
  dec.board.c0.s3(v0, v1, dec.gun(r2))

def dec.board.c0.s1(p: D.RoundView & List<&2, Nat>) -> D.Board & List<&2, Nat>:
  (v0, r1) = p
  dec.board.c0.s2(v0, dec.ring(r1))

def dec.board.c0(r: List<&2, Nat>) -> D.Board & List<&2, Nat>:
  dec.board.c0.s1(dec.roundview(r))

def dec.board(r: List<&2, Nat>) -> D.Board & List<&2, Nat>:
  dec.board.c0(r)

def enc.seat(x: D.Seat) -> Nat:
  match x:
    case D.Seat0{}:
      0n
    case D.Seat1{}:
      1n
    case D.Seat2{}:
      2n
    case D.Seat3{}:
      3n

def enc.item(x: D.Item) -> Nat:
  match x:
    case D.Saw{}:
      0n
    case D.Glass{}:
      1n
    case D.Jammer{}:
      2n
    case D.Cigarettes{}:
      3n
    case D.Beer{}:
      4n
    case D.Phone{}:
      5n
    case D.Inverter{}:
      6n
    case D.Adrenaline{}:
      7n
    case D.Remote{}:
      8n

def table.of.c(t: Nat) -> D.Table:
  match t:
    case 0n:
      D.ThreeSeats{}
    case 1n+p:
      D.FourSeats{}

def table.of.b(t: Nat) -> D.Table:
  match t:
    case 0n:
      D.TwoSeats{}
    case 1n+p:
      table.of.c(p)

def table.of.a(t: Nat) -> D.Table:
  match t:
    case 0n:
      D.FourSeats{}
    case 1n+p:
      table.of.b(p)

def table.of(t: Nat) -> D.Table:
  match t:
    case 0n:
      D.FourSeats{}
    case 1n+p:
      table.of.a(p)

def position.log(config: D.Config, me: D.Seat, board: D.Board, p: List<&2, D.Heard> & List<&2, Nat>) -> A.Position:
  (log, r5) = p
  A.Position{config, board, log, me}

def dec.log.add(acc: List<&2, D.Heard>, p: D.Heard & List<&2, Nat>) -> List<&2, D.Heard> & List<&2, Nat>:
  (x, r1) = p
  (Con{x, acc}, r1)

def dec.log.step(st: List<&2, D.Heard> & List<&2, Nat>) -> List<&2, D.Heard> & List<&2, Nat>:
  (acc, r) = st
  dec.log.add(acc, dec.heard(r))

def dec.log.go(n: Nat, st: List<&2, D.Heard> & List<&2, Nat>) -> List<&2, D.Heard> & List<&2, Nat>:
  match n:
    case 0n:
      st
    case 1n+p:
      dec.log.go(p, dec.log.step(st))

def dec.log.n(p: Nat & List<&2, Nat>) -> List<&2, D.Heard> & List<&2, Nat>:
  (n, r1) = p
  dec.log.go(n, (Nil{}, r1))

def dec.log(r: List<&2, Nat>) -> List<&2, D.Heard> & List<&2, Nat>:
  dec.log.n(tok(r))

def position.board(config: D.Config, me: D.Seat, p: D.Board & List<&2, Nat>) -> A.Position:
  (board, r4) = p
  position.log(config, me, board, dec.log(r4))

def position.me(config: D.Config, p: D.Seat & List<&2, Nat>) -> A.Position:
  (me, r3) = p
  position.board(config, me, dec.board(r3))

def position.items(table: D.Table, p: Bool & List<&2, Nat>) -> A.Position:
  (items, r2) = p
  position.me(W.config(table, items), dec.seat(r2))

def position.t(p: Nat & List<&2, Nat>) -> A.Position:
  (t, r1) = p
  position.items(table.of(t), dec.bool(r1))

def position.of(r: List<&2, Nat>) -> A.Position:
  position.t(tok(r))

def nat.read.of(m: Maybe<&2, Nat>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{n}:
      n

def nat.read(s: String) -> Nat:
  nat.read.of(Nat.read(s))

def nat.reads(xs: List<&2, String>) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{nat.read(h), nat.reads(t)}

def numbers(+text: String) -> List<&2, Nat>:
  nat.reads(String.split(text, Chr{32}))

def show.move(m: T.Move) -> String:
  match m:
    case T.Shoot{target}:
      Nat.show(0n) ++ "." ++ Nat.show(enc.seat(target))
    case T.Use{item}:
      Nat.show(1n) ++ "." ++ Nat.show(enc.item(item))
    case T.Jam{target}:
      Nat.show(2n) ++ "." ++ Nat.show(enc.seat(target))
    case T.Steal{owner, item}:
      Nat.show(3n) ++ "." ++ Nat.show(enc.seat(owner)) ++ "." ++ Nat.show(enc.item(item))
    case T.StealJam{owner, target}:
      Nat.show(4n) ++ "." ++ Nat.show(enc.seat(owner)) ++ "." ++ Nat.show(enc.seat(target))

def show.reach(r: A.Reach) -> String:
  match r:
    case A.Settled{}:
      "0"
    case A.Reloads{}:
      "1"
    case A.Cut{}:
      "2"

def show.line(l: A.Line) -> String:
  match l:
    case A.Line{_, move, score, _, reach}:
      show.move(move) ++ ":" ++ Nat.show(U32.to_nat(score)) ++ ":" ++ show.reach(reach)

def show.lines(ls: List<&2, A.Line>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{show.line(h), show.lines(t)}

def show.bool(b: Bool) -> String:
  match b:
    case True{}:
      "1"
    case False{}:
      "0"

def show.analysis(a: A.Analysis) -> String:
  match a:
    case A.Analysed{lines, best, score, nodes, depth, limited, cached}:
      match cached:
        case A.Cached{entries, hits, deals, deal_hits}:
          "A " ++ String.join([Nat.show(best), Nat.show(nodes), Nat.show(depth), show.bool(limited), Nat.show(entries), Nat.show(hits), Nat.show(deals), Nat.show(deal_hits)], " ") ++ " | " ++ String.join(show.lines(lines), " ")
    case A.Invalid{reason, nodes}:
      "I " ++ reason ++ " " ++ Nat.show(nodes)

def reload.of.expected(k: Nat, samples: Nat) -> A.Reload:
  match k:
    case 0n:
      A.ExpectedDeal{}
    case 1n+p:
      A.Sampled{samples}

def reload.of(k: Nat, samples: Nat) -> A.Reload:
  match k:
    case 0n:
      A.Static{}
    case 1n+p:
      reload.of.expected(p, samples)

def memo.of.charged(k: Nat) -> A.Memo:
  match k:
    case 0n:
      A.Charged{}
    case 1n+p:
      A.Free{}

def memo.of(k: Nat) -> A.Memo:
  match k:
    case 0n:
      A.Off{}
    case 1n+p:
      memo.of.charged(p)

def solve(line: String, depth: Nat, budget: Nat, reload: Nat, samples: Nat, memo: Nat) -> String:
  show.analysis(N.analyse(position.of(numbers(line)), depth, budget, reload.of(reload, samples), memo.of(memo)))

def each(lines: List<&2, String>, +depth: Nat, +budget: Nat, +reload: Nat, +samples: Nat, +memo: Nat) -> IO(Unit):
  match lines:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{h, t}:
      do IO<Unit>:
        IO.print(solve(h, depth, budget, reload, samples, memo))
        each(t, depth, budget, reload, samples, memo)

def finish(got: File & Result<&1, &1, U32 & String, String>, d: String, b: String, rl: String, sm: String, mm: String) -> IO(Unit):
  (file, text) = got
  do IO<Unit>:
    content : String <- IO.pass(String, text)
    File.close(file)
    each(String.lines(content), nat.read(d), nat.read(b), nat.read(rl), nat.read(sm), nat.read(mm))

def run(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{path, Con{d, Con{b, Con{rl, Con{sm, Con{mm, Nil{}}}}}}}}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(path, "r"))
        got : File & Result<&1, &1, U32 & String, String> <- File.read(file, 268435456)
        finish(got, d, b, rl, sm, mm)
    case _:
      IO.die(Unit, 2, "usage: native-eval <inputs> depth budget reload samples memo")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
