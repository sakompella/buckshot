import Base
import ./model.bend as Model
import ./LAWS.bend as Laws

def add_zero_right(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero_right(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_succ_right(a: Nat, +b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ap:
      %add_succ_right(ap, b) : {1n+1n+Nat.add(ap, b) == 1n+_ : Nat}
      {==}

def Laws.zero_damage_preserves_hp(hp):
  match hp:
    case 0n:
      {==}
    case 1n+p:
      {==}

def Laws.damage_equal_to_hp_is_fatal(hp):
  match hp:
    case 0n:
      {==}
    case 1n+p:
      Laws.damage_equal_to_hp_is_fatal(p)

def Laws.damage_accounts_for_lost_hp(hp, damage):
  match hp damage:
    case 0n _:
      {==}
    case 1n+p 0n:
      %add_zero_right(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}
    case 1n+p 1n+d:
      %add_succ_right(Model.damage_hp(p, d), Nat.min(p, d)) : {_ == 1n+p : Nat}
      %Laws.damage_accounts_for_lost_hp(p, d) : {1n+Nat.add(Model.damage_hp(p, d), Nat.min(p, d)) == 1n+_ : Nat}
      {==}
