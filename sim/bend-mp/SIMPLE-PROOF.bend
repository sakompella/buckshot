import Base
import ./SIMPLE-LAWS.bend as Laws
import ./simple-idle-proof.bend as Idle
import ./simple-misc-proof.bend as Misc
import ./simple-valid-proof.bend as Valid
import ./simple-run-proof.bend as Run
import ./simple-complete-proof.bend as Complete

def Laws.simple_start(config):
  Misc.start.eq(config)

def Laws.simple_refines(state, n):
  Idle.refines(state, n)

def Laws.simple_roundtrip(state):
  Misc.roundtrip(state)

def Laws.simple_valid(state, valid, n):
  Valid.simple.valid(state, valid, n)

def Laws.simple_reachable_valid(fuel, config, tape):
  Valid.reachable.valid(fuel, config, tape)

def Laws.simple_run_refines(fuel, state, tape):
  Run.run.refines(fuel)(state, tape)

def Laws.simple_observe(state, seat):
  Misc.observe.eq(state, seat)

def Laws.simple_privacy(state, gun, decks, seat, same_length):
  Misc.privacy.eq(state, gun, decks, seat, same_length)

def Laws.simple_complete(state, steps, gesture, first):
  Complete.complete(state, steps, gesture, first)
