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
        let inherit (nixpkgs.lib.getAttrFromPath [ "packages" pkgs.stdenv.hostPlatform.system ] self) bend bendtt; in {
          default = pkgs.mkShell {
            packages = [ bend pkgs.bun pkgs.python3 pkgs.uv ];
            BENDTT = "${bendtt}/bin/bendtt";
          };
        });
    };
}
