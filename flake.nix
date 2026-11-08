{
  description = "Buckshot Roulette research: simulators and tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forEachSystem (pkgs: rec {
        bend = pkgs.callPackage ./nix/bend.nix { };
        bendtt = pkgs.callPackage ./nix/bendtt.nix { inherit bend; };
      });

      devShells = forEachSystem (pkgs:
        let inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) bend bendtt; in {
          default = pkgs.mkShell ({
            packages = [ bend pkgs.bun pkgs.nodejs_22 (pkgs.python3.withPackages (ps: [ ps.hypothesis ps.numpy ])) pkgs.uv
              pkgs.cargo pkgs.rustc pkgs.clippy pkgs.rustfmt pkgs.rust-analyzer pkgs.cargo-mutants ];
            BEND = "${bend}/bin/bend";
            BENDTT = "${bendtt}/bin/bendtt";
            # Committed git hooks (.githooks/pre-commit). Set only for a Buckshot checkout
            # (never the caller's other repo) and only when core.hooksPath is unset.
            # Worktrees share the config, so this is set once.
            shellHook = ''
              top=$(git rev-parse --show-toplevel 2>/dev/null)
              if [ -n "$top" ] && [ -f "$top/.githooks/pre-commit" ] && [ -d "$top/sim/bend-mp" ] \
                && grep -q 'Buckshot Roulette research' "$top/flake.nix" 2>/dev/null \
                && [ -z "$(git -C "$top" config --get core.hooksPath)" ]; then
                git -C "$top" config core.hooksPath .githooks
                echo "buckshot: set core.hooksPath to .githooks"
              fi
              unset top
            '';
          } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          });
        });
    };
}
