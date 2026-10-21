# Bend and Lean pins

`nix/bend.nix` pins Bend 2.0.36 by version and hash, because the proofs and the JavaScript build of the rules depend on that exact checker. Bend's own flake cannot pin a release. Bend 2.0.36 asks for Lean 4.34.0 and would build its proof kernel itself. Instead `nix/bendtt.nix` builds the kernel with nixpkgs' Lean (4.34.1 when this was set up), and the dev shell sets `BENDTT` to it. Setting it skips Bend's version check. `check.sh` runs the proofs with `--verdict` through that kernel.

## Consequences

We trust a kernel built with a different Lean patch version than Bend names. Upgrading Bend means rechecking every proof. The web build uses the same pinned Bend through the dev shell.
