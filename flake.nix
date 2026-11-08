{
  description = "Buckshot Roulette research: simulators and tooling";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.git-hooks = {
    url = "github:cachix/git-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, git-hooks, ... }:
    let
      inherit (nixpkgs) lib;
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forEachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # The pre-commit hooks are plain commands in sim/rust/pre-commit-config.json,
      # which plain pre-commit or prek also installs. `nix flake check` runs them
      # on the whole tree, with the crates vendored from Cargo.lock.
      hookConfig = (builtins.head (lib.importJSON ./sim/rust/pre-commit-config.json).repos).hooks;
      hooks = lib.genAttrs (builtins.filter (system: git-hooks.lib ? ${system}) systems) (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        git-hooks.lib.${system}.run {
          src = ./.;
          settings.rust.check.cargoDeps = pkgs.rustPlatform.importCargoLock { lockFile = ./sim/rust/Cargo.lock; };
          hooks = lib.listToAttrs (map (hook: lib.nameValuePair hook.id (removeAttrs hook [ "id" ] // {
            enable = true;
            extraPackages = [ pkgs.cargo pkgs.rustc pkgs.clippy pkgs.rustfmt ];
          })) hookConfig);
        });
    in {
      packages = forEachSystem (pkgs: rec {
        bend = pkgs.callPackage ./nix/bend.nix { };
        bendtt = pkgs.callPackage ./nix/bendtt.nix { inherit bend; };
      });

      # cargoRoot: Cargo.lock is the workspace's, not at the repository root.
      checks = lib.mapAttrs (_: run: { pre-commit-check = run.overrideAttrs { cargoRoot = "sim/rust"; }; }) hooks;

      devShells = forEachSystem (pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          inherit (self.packages.${system}) bend bendtt;
        in {
          default = pkgs.mkShell ({
            packages = [ bend pkgs.bun pkgs.nodejs_22 (pkgs.python3.withPackages (ps: [ ps.hypothesis ps.numpy ])) pkgs.uv
              pkgs.cargo pkgs.rustc pkgs.clippy pkgs.rustfmt pkgs.rust-analyzer pkgs.cargo-mutants ];
            BEND = "${bend}/bin/bend";
            BENDTT = "${bendtt}/bin/bendtt";
            # git-hooks.nix installs into the repository of the working directory,
            # so only in a Buckshot checkout, never a caller's other repository.
            # Worktrees share one hooks directory. git-hooks.nix names it by a
            # path relative to the checkout, which a linked worktree cannot
            # resolve, so it is renamed absolute; and a worktree whose shell has
            # not linked its .pre-commit-config.yaml skips the hooks.
            shellHook = lib.optionalString (hooks ? ${system}) ''
              top=$(git rev-parse --show-toplevel 2>/dev/null || true)
              if [ -n "$top" ] && [ -f "$top/sim/rust/pre-commit-config.json" ] \
                && grep -q 'Buckshot Roulette research' "$top/flake.nix" 2>/dev/null; then
                ${hooks.${system}.shellHook}
                hooks=$(git rev-parse --path-format=absolute --git-common-dir)/hooks
                if ! grep -q skip-on-missing-config "$hooks/pre-commit" 2>/dev/null; then
                  git config --local --unset-all core.hooksPath || true
                  pre-commit install --allow-missing-config -c .pre-commit-config.yaml >/dev/null
                fi
                [ "$(git config --get core.hooksPath)" = "$hooks" ] || git config --local core.hooksPath "$hooks"
                unset hooks
              fi
              unset top
            '';
          } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          });
        });
    };
}
