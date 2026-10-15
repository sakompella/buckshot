# Trust comes from universal laws checked by the kernel

The machine is trusted because `LAWS.bend` states laws over every config, state and answer, and `PROOF.bend` proves them. The Bend compiler and the Lean-built proof kernel check the proofs, through `bend PROOF.bend --verdict`, which must print `ALL PROOFS CHECK`. `check.sh` fails on any `@unsafe` or unfinished hole, requires every named law to be present, and plants bugs in a copy of the machine that each proof or fuzz run must reject. Some proofs are case splits over every table shape and seat, too big to write by hand. `tools/proof_cases.py` writes their bodies. The claims stay hand-written, `check.sh` regenerates the bodies and fails on any difference, and the script itself is not trusted because the kernel checks every body it writes.

## Considered Options

- Tests and fuzzing alone: they sample, and a proof covers all inputs. The laws are also fuzzed on random games, as extra evidence and not as a replacement.

## Consequences

What a reader must still trust is the law statements, the mapping from machine state to reference state, the reference against the real game (ADR-0021), the text search for `@unsafe`, and the checkers. The full gate takes several minutes.
