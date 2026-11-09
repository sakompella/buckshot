# Bend and Lean pins

`nix/bend.nix` pins Bend 2.0.40 by version and hash, because the proofs and the JavaScript build of the rules depend on that exact checker. Bend's own flake cannot pin a release. Bend 2.0.40 asks for Lean 4.34.0 and would build its proof kernel itself. Instead `nix/bendtt.nix` builds the kernel with nixpkgs' Lean (4.34.1 when this was set up), and the dev shell sets `BENDTT` to it, and `BEND` to the pinned compiler. Setting it skips Bend's version check. `check.sh` runs the proofs with `--verdict` through that kernel.

## Consequences

We trust a kernel built with a different Lean patch version than Bend names. Upgrading Bend means rechecking every proof, and rereading the JavaScript host contract: Bend 2.0.37 to 2.0.40 hand a `Nat` to JS as a plain number (checked to lie in 0..2^53) rather than a BigInt, key an imported export as `module:name` (`domain:table.seats`), and tag constructors with their bare names (`Adrenaline`, not `domain.Adrenaline`). Two types may now share a constructor name (for example `Jammed` in `domain` and `sm/state`), so the JS side tells them apart by where a value sits, never by its tag alone. The web build uses the same pinned Bend through the dev shell.
