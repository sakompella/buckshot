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
            packages = [ bend pkgs.bun pkgs.nodejs_22 (pkgs.python3.withPackages (ps: [ ps.hypothesis ps.numpy ])) pkgs.uv ];
            BEND = "${bend}/bin/bend";
            BENDTT = "${bendtt}/bin/bendtt";
          } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          });
        });
    };
}
