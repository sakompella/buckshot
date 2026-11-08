{
  description = "Buckshot Roulette research: simulators and tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    rust-overlay = { url = "github:oxalica/rust-overlay"; inputs.nixpkgs.follows = "nixpkgs"; };
    pyproject-nix = { url = "github:pyproject-nix/pyproject.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    uv2nix = { url = "github:pyproject-nix/uv2nix"; inputs.pyproject-nix.follows = "pyproject-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix"; inputs.uv2nix.follows = "uv2nix"; inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, crane, rust-overlay, pyproject-nix, uv2nix, pyproject-build-systems, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; }));

      perSystem = pkgs:
        let
          inherit (pkgs) lib;
          bend = pkgs.callPackage ./nix/bend.nix { };
          bendtt = pkgs.callPackage ./nix/bendtt.nix { inherit bend; };

          # Rust: one toolchain for rustup users and crane, from sim/rust/rust-toolchain.toml.
          toolchain = pkgs.rust-bin.fromRustupToolchainFile ./sim/rust/rust-toolchain.toml;
          craneLib = (crane.mkLib pkgs).overrideToolchain (_: toolchain);
          # The workspace plus the Bend sources `cargo branch-map check` reads (sim/rust/../bend-mp).
          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (craneLib.fileset.commonCargoSources ./sim/rust)
              ./sim/rust/rules/branch-map.toml
              ./sim/rust/clippy.toml
              ./sim/rust/rustfmt.toml
              ./sim/rust/.cargo
              (lib.fileset.fileFilter (f: f.hasExt "bend") ./sim/bend-mp)
            ];
          };
          features = "--no-default-features --features f64,seats-2-4";
          common = {
            inherit src;
            pname = "buckshot-sim";
            version = "0.0.0";
            strictDeps = true;
            cargoLock = ./sim/rust/Cargo.lock;
            cargoToml = ./sim/rust/Cargo.toml;
            postUnpack = "cd $sourceRoot/sim/rust && sourceRoot=.";
            cargoExtraArgs = "--locked ${features}";
            CI = "true"; # deterministic Hegel properties, no .hegel/
          };
          cargoArtifacts = craneLib.buildDepsOnly (common // { doCheck = false; });
          rust = craneLib.buildPackage (common // { inherit cargoArtifacts; doCheck = false; });

          # Python: dev/ (pyproject + uv.lock) as a uv2nix virtualenv.
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./dev; };
          python = pkgs.python3;
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
            (lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
            ]);
          devEnv = pythonSet.mkVirtualEnv "buckshot-dev-env" workspace.deps.default;
        in {
          packages = { inherit bend bendtt rust devEnv; default = rust; };
          checks = {
            inherit rust;
            rust-fmt = craneLib.cargoFmt common;
            rust-clippy = craneLib.cargoClippy (common // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--workspace --all-targets -- -D warnings";
            });
            rust-test = craneLib.cargoTest (common // {
              inherit cargoArtifacts;
              cargoTestExtraArgs = "--workspace";
            });
            py-test = pkgs.runCommand "py-test" { nativeBuildInputs = [ devEnv ]; } ''
              cp -r ${./tools} tools && chmod -R u+w tools
              cd tools/arena && python -m unittest discover -p 'test_*.py'
              cd analysis && python -m unittest discover -p 'test_*.py'
              touch $out
            '';
          };
          apps.dev = { type = "app"; program = "${devEnv}/bin/dev"; };
          devShells.default = pkgs.mkShell ({
            packages = [ bend toolchain pkgs.bun pkgs.nodejs_22 devEnv pkgs.uv pkgs.cargo-mutants ];
            BEND = "${bend}/bin/bend";
            BENDTT = "${bendtt}/bin/bendtt";
            UV_NO_SYNC = "1";
            UV_PYTHON_DOWNLOADS = "never";
            shellHook = ''
              if [ "$(git config --get core.hooksPath 2>/dev/null)" != .githooks ] && git rev-parse --git-dir >/dev/null 2>&1; then
                git config core.hooksPath .githooks
              fi
            '';
          } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          });
        };
      outputsFor = forEachSystem perSystem;
    in {
      packages = nixpkgs.lib.mapAttrs (_: o: o.packages) outputsFor;
      checks = nixpkgs.lib.mapAttrs (_: o: o.checks) outputsFor;
      apps = nixpkgs.lib.mapAttrs (_: o: o.apps) outputsFor;
      devShells = nixpkgs.lib.mapAttrs (_: o: { inherit (o.devShells) default; }) outputsFor;
    };
}
