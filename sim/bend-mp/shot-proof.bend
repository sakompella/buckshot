import Base
import ./abstract.bend as A
import ./domain.bend as D
import ./sm/rules.bend as Q

def subtract_matches(+left: Nat, +right: Nat) -> {Q.subtract(left, right) == A.ref_subtract(left, right) : Nat}:
  match left right:
    case 0n 0n:
      {==}
    case 0n 1n+right:
      {==}
    case 1n+left 0n:
      {==}
    case 1n+left 1n+right:
      subtract_matches(left, right)

def subtract_zero(hp: Nat) -> {Q.subtract(hp, 0n) == hp : Nat}:
  match hp:
    case 0n:
      {==}
    case 1n+hp:
      {==}

def health_matches(shell: D.Shell, hp: Nat, damage: D.Damage) -> {Q.shot.health(shell, hp, damage) == A.ref_shot_health(shell, hp, damage) : Nat}:
  match shell hp damage:
    case D.Blank{} _ _:
      {==}
    case D.Live{} 0n D.Single{}:
      {==}
    case D.Live{} 0n D.Double{}:
      {==}
    case D.Live{} 1n+hp D.Single{}:
      subtract_zero(hp)
    case D.Live{} 1n+0n D.Double{}:
      {==}
    case D.Live{} 1n+1n+hp D.Double{}:
      subtract_zero(hp)

def passes_matches(shell: D.Shell, same: Bool) -> {Q.shot.passes(shell, same) == A.ref_shot_passes(shell, same) : Bool}:
  match shell same:
    case D.Live{} False{}:
      {==}
    case D.Live{} True{}:
      {==}
    case D.Blank{} False{}:
      {==}
    case D.Blank{} True{}:
      {==}

