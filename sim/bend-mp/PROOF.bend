import Base
import ./LAWS.bend as Laws
import ./core-proof.bend as Core
import ./step-proof.bend as Step
import ./item-step-proof.bend as ItemStep
import ./grab-proof.bend as GrabProof

def Laws.core_roundtrip(seats):
  Core.law.core_roundtrip(seats)

def Laws.pickup_matches(world, seats, seat, notes, n, present, accepted):
  Core.law.pickup_matches(world, seats, seat, notes, n, present, accepted)

def Laws.pickup_point_matches(world, seats, seat, notes, n, present, accepted):
  Core.law.pickup_point_matches(world, seats, seat, notes, n, present, accepted)

def Laws.legal_play_exact(world, seats, seat, aiming, notes):
  Core.law.legal_play_exact(world, seats, seat, aiming, notes)

def Laws.observe_matches(world, seats, phase, notes, seat):
  Core.law.observe_matches(world, seats, phase, notes, seat)

def Laws.legal_exact(world, seats, phase, notes):
  Core.law.legal_exact(world, seats, phase, notes)

def Laws.legal_accepted(world, seats, seat, aiming, notes, n, choice, present, selected, current, permission):
  Core.law.legal_accepted(world, seats, seat, aiming, notes, n, choice, present, selected, current, permission)

def Laws.state_roundtrip(world, seats, phase, notes):
  Core.law.state_roundtrip(world, seats, phase, notes)

def Laws.turn_traversal(world, seats, current):
  Core.law.turn_traversal(world, seats, current)

def Laws.start_result_matches(config, supported):
  Core.law.start_result_matches(config, supported)

def Laws.privacy(state, gun, decks, seat, same_length):
  Core.law.privacy(state, gun, decks, seat, same_length)

def Laws.jam_skip_once(world, seats, seat, notes):
  Core.law.jam_skip_once(world, seats, seat, notes)

def Laws.start_matches(config, supported):
  Core.law.start_matches(config, supported)
