{
  description = "Buckshot Roulette research: simulators and tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay, pyproject-nix, uv2nix, pyproject-build-systems, git-hooks, ... }:
    let
      inherit (nixpkgs) lib;
      # x86_64-darwin is gone: nixpkgs 26.11 dropped it.
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      pkgsFor = lib.genAttrs systems (system: import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      });
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});

      # The pre-commit hooks are plain commands in sim/rust/pre-commit-config.json,
      # which `bash sim/rust/install-hooks.sh` installs for plain pre-commit or prek.
      # The dev shell installs nothing and changes no git config. `nix flake check`
      # runs the hooks on the whole tree, with the crates vendored from Cargo.lock.
      hookConfig = (builtins.head (lib.importJSON ./sim/rust/pre-commit-config.json).repos).hooks;
      hooks = lib.genAttrs (builtins.filter (system: git-hooks.lib ? ${system}) systems) (system:
        let pkgs = pkgsFor.${system}; in
        git-hooks.lib.${system}.run {
          src = ./.;
          settings.rust.check.cargoDeps = pkgs.rustPlatform.importCargoLock { lockFile = ./sim/rust/Cargo.lock; };
          hooks = lib.listToAttrs (map (hook: lib.nameValuePair hook.id (removeAttrs hook [ "id" ] // {
            enable = true;
            # Clippy and rustfmt come from the same toolchain file.
            extraPackages = [ (pkgs.rust-bin.fromRustupToolchainFile ./sim/rust/rust-toolchain.toml) ];
          })) hookConfig);
        });

      # Python: dev/ (pyproject.toml + uv.lock) as a uv2nix virtualenv,
      # providing the `dev` app and everything the dev/ tests need.
      devEnv = pkgs:
        let
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./dev; };
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages { python = pkgs.python3; }).overrideScope
            (lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
            ]);
        in pythonSet.mkVirtualEnv "buckshot-dev-env" workspace.deps.default;
    in {
      packages = forEachSystem (pkgs: rec {
        bend = pkgs.callPackage ./nix/bend.nix { };
        bendtt = pkgs.callPackage ./nix/bendtt.nix { inherit bend; };
      });

      # cargoRoot: Cargo.lock is the workspace's, not at the repository root.
      # arena-python: ruff, ruff format and ty over tools/arena and dev, then the tools/arena, tools/arena/analysis and dev/tests
      # unit tests, in the dev/ env (some call Bend and node). Its source is only what those read, so a docs change does not rerun it.
      checks = forEachSystem (pkgs:
        let system = pkgs.stdenv.hostPlatform.system; in
        lib.optionalAttrs (hooks ? ${system}) { pre-commit-check = hooks.${system}.overrideAttrs { cargoRoot = "sim/rust"; }; }
        // {
          arena-python = pkgs.runCommand "arena-python-tests" {
            nativeBuildInputs = [ (devEnv pkgs) self.packages.${system}.bend pkgs.nodejs_22 pkgs.ruff pkgs.ty ];
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [ ./tools ./dev ./web ./sim ];
            };
          } ''
            cp -r $src src && chmod -R u+w src && cd src
            export HOME=$TMPDIR
            ruff check --config dev/pyproject.toml tools/arena dev
            ruff format --config dev/pyproject.toml --check tools/arena dev
            ty check --project dev --python ${devEnv pkgs} tools/arena dev
            (cd tools/arena && python -m unittest discover -s . -p 'test_*.py')
            (cd tools/arena/analysis && python -m unittest discover -s .)
            (cd dev && BUCKSHOT_HEAVY_MEM_BUDGET=8G python -m unittest discover -s tests -t .)
            touch $out
          '';
        });

      apps = forEachSystem (pkgs: {
        # `nix run .#dev -- ...`: the dev/ package's commands in the uv2nix virtualenv.
        dev = { type = "app"; program = "${devEnv pkgs}/bin/dev"; };
      });

      devShells = forEachSystem (pkgs:
        let
          inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) bend bendtt;
          # The single Rust pin: rustup reads sim/rust/rust-toolchain.toml outside Nix,
          # and the flake builds the exact same toolchain from the same file.
          toolchain = pkgs.rust-bin.fromRustupToolchainFile ./sim/rust/rust-toolchain.toml;
        in {
          default = pkgs.mkShell ({
            packages = [ bend pkgs.bun pkgs.nodejs_22 (devEnv pkgs) pkgs.uv
              toolchain pkgs.rust-analyzer pkgs.cargo-mutants pkgs.pre-commit ];
            BEND = "${bend}/bin/bend";
            BENDTT = "${bendtt}/bin/bendtt";
            # The dev env already has everything in dev/uv.lock.
            UV_NO_SYNC = "1";
            UV_PYTHON_DOWNLOADS = "never";
          } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          });
        });
    };
}
