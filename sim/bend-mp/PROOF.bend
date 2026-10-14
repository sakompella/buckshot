import Base
import ./LAWS.bend as Laws
import ./core-proof.bend as Core
import ./step-proof.bend as Step
import ./item-step-proof.bend as ItemStep
import ./grab-proof.bend as GrabProof
import ./load-proof.bend as LoadProof
import ./turn-proof.bend as TurnProof
import ./use-proof.bend as UseProof
import ./aim-proof.bend as AimProof
import ./pick-proof.bend as PickProof
import ./round-proof.bend as RoundProof
import ./load-step-proof.bend as LoadStepProof
import ./items-proof.bend as ItemsProof
import ./accept-proof.bend as AcceptProof

def Laws.legal_accepted(state, valid, n, choice, selected):
  AcceptProof.accept(state, valid, n, choice)(selected)

def Laws.state_roundtrip(world, seats, phase, notes):
  Core.law.state_roundtrip(world, seats, phase, notes)

def Laws.turn_traversal(world, seats, current):
  Core.law.turn_traversal(world, seats, current)

def Laws.privacy(state, gun, decks, seat, same_length):
  Core.law.privacy(state, gun, decks, seat, same_length)

def Laws.jam_skip_once(world, seats, seat, notes):
  Core.law.jam_skip_once(world, seats, seat, notes)
