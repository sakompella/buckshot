# Bend from its GitHub release archive, pinned by version and hash.
# Bend's own flake can't pin a release: each vX tag still carries the previous
# release's flake.nix, which is bumped in the commit after the tag.
# The wrapper mirrors upstream: Apple's clang on macOS, nixpkgs clang on Linux.
{ lib, stdenv, fetchurl, makeWrapper, autoPatchelfHook, clang }:

let
  version = "2.0.39";
  archives = {
    aarch64-darwin = { target = "darwin-arm64"; sha256 = "d4aaef68de545727429ce83b9e88ff3273bf068df599e3542e446755b5f3d83a"; };
    x86_64-darwin = { target = "darwin-x64"; sha256 = "a512cfd1d29ec24c640126a6a640e597b4ea1abe0aefbda7cc57efd85ab56e22"; };
    aarch64-linux = { target = "linux-arm64"; sha256 = "71b43e1bb9313dd14ac2b0553b854e41c39d65ecaa47040796ebff4a46f54a97"; };
    x86_64-linux = { target = "linux-x64"; sha256 = "6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab"; };
  };
  system = stdenv.hostPlatform.system;
  archive = archives.${system} or (throw "bend ${version} has no release archive for ${system}");
in
stdenv.mkDerivation {
  pname = "bend";
  inherit version;
  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-${archive.target}.tar.gz";
    inherit (archive) sha256;
  };
  nativeBuildInputs = [ makeWrapper ] ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p $out/libexec/bend $out/bin
    cp -r . $out/libexec/bend
    makeWrapper $out/libexec/bend/bin/bend $out/bin/bend \
      ${if stdenv.hostPlatform.isLinux
        then ''--prefix PATH : "${lib.makeBinPath [ clang ]}"''
        else "--set-default CC /usr/bin/clang"}
  '';
  meta = {
    description = "Bend: C speed, CUDA parallelism, Lean proofs, Python syntax";
    homepage = "https://github.com/bendlang/bend";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = builtins.attrNames archives;
  };
}
