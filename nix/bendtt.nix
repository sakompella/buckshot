# Bend's proof kernel, built from the bend package's bendtt.lean.
# Bend 2.0.39 asks for Lean 4.34.0 and builds this itself when $BENDTT is unset.
# Setting $BENDTT skips that version check, so nixpkgs' lean4 is used as is.
{ stdenv, bend, lean4 }:

stdenv.mkDerivation {
  pname = "bendtt";
  inherit (bend) version;
  dontUnpack = true;
  nativeBuildInputs = [ lean4 ];
  buildPhase = ''
    cp ${bend}/libexec/bend/bend2/bendtt.lean .
    lean -c bendtt.c bendtt.lean
    leanc -O3 -DNDEBUG bendtt.c -o bendtt
  '';
  installPhase = ''
    install -Dm755 bendtt $out/bin/bendtt
  '';
  meta.mainProgram = "bendtt";
}
