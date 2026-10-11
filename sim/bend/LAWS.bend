import Base
import ./model.bend as Model

law zero_damage_preserves_hp:
  for +hp: Nat
  {Model.damage_hp(hp, 0n) == hp : Nat}

law damage_equal_to_hp_is_fatal:
  for +hp: Nat
  {Model.damage_hp(hp, hp) == 0n : Nat}

law damage_accounts_for_lost_hp:
  for +hp: Nat
  for +damage: Nat
  {Nat.add(Model.damage_hp(hp, damage), Nat.min(hp, damage)) == hp : Nat}
