# Bend from its GitHub release archive, pinned by version and hash.
# Bend's own flake can't pin a release: each vX tag still carries the previous
# release's flake.nix, which is bumped in the commit after the tag.
# The wrapper mirrors upstream: Apple's clang on macOS, nixpkgs clang on Linux.
{ lib, stdenv, fetchurl, makeWrapper, autoPatchelfHook, clang }:

let
  version = "2.0.40";
  archives = {
    aarch64-darwin = { target = "darwin-arm64"; sha256 = "b2be003b041eb6cfc65326be18f79eb2e0bae2189be79a18c507e661b4b6900b"; };
    x86_64-darwin = { target = "darwin-x64"; sha256 = "9229c8bdd0a93f63fa45cc5af5e9e56389ebb620d655920915daf966c6ca561c"; };
    aarch64-linux = { target = "linux-arm64"; sha256 = "2f42a6fa34ecdaa71ae105e5fa734f9a07e129d333e45448ab6d2ff03a837570"; };
    x86_64-linux = { target = "linux-x64"; sha256 = "c9ff8d67bd903fb6ad9a26b43d8a62c01021de82a44d55ce4a3dcd4732113d6b"; };
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
