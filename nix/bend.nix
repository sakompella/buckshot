# Bend from its GitHub release archive, pinned by version and hash.
# Bend's own flake can't pin a release: each vX tag still carries the previous
# release's flake.nix, which is bumped in the commit after the tag.
# The wrapper mirrors upstream: Apple's clang on macOS, nixpkgs clang on Linux.
{ lib, stdenv, fetchurl, makeWrapper, autoPatchelfHook, clang }:

let
  version = "2.0.36";
  archives = {
    aarch64-darwin = { target = "darwin-arm64"; sha256 = "2876687ceb0aba836abc98b3f62c8fc9fb612d124ae2af6814d5ec937760878d"; };
    x86_64-darwin = { target = "darwin-x64"; sha256 = "925bb306c60260e1cdde56c2b8e4ba0e1eb4cbc88a76372cc0bb389a172dccdf"; };
    aarch64-linux = { target = "linux-arm64"; sha256 = "a14a311e39bad45f9669d4eab39d156b578c945f13a2b7bae20d9c23567a4664"; };
    x86_64-linux = { target = "linux-x64"; sha256 = "02089dc0eed0fd5fd6d73c74cc9cffcb2c6638dd3b02ae83f7b8cc57fbe381ba"; };
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
