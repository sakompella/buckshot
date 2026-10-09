#!/usr/bin/env bash
set -eEuo pipefail

GODOT_VERSION=4.1.4-stable
GODOT_URL=https://github.com/godotengine/godot/releases/download/$GODOT_VERSION
HEAVY="nice -n 10"
MOD_LABEL='v1.2.0 (decompilation) - MODDED BUILD TEST'

die() { echo "error: $*" >&2; exit "${2:-2}"; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

resolve_work() {
  if [ $# -ge 1 ] && [ -n "$1" ]; then (cd "$1" 2>/dev/null && pwd) || echo "$1"; return; fi
  case "$SCRIPT_DIR" in
    */scripts) echo "$(cd "$SCRIPT_DIR/.." && pwd)/_work" ;;
    */_work/evidence/modding) echo "${SCRIPT_DIR%/evidence/modding}" ;;
    *) die "cannot infer WORK_DIR from $SCRIPT_DIR; pass it as the first argument" ;;
  esac
}

WORK=$(resolve_work "$@")
[ "$(basename "$WORK")" = "_work" ] || die "WORK_DIR must be a directory named _work, got: $WORK"
[ -d "$WORK" ] || die "WORK_DIR does not exist: $WORK"

if [ -d "$SCRIPT_DIR/mod-support" ]; then PATCH=$SCRIPT_DIR/mod-support; else PATCH=$SCRIPT_DIR/patch; fi
TOOLS=$WORK/tools/godot-4.1.4
GODOT=$TOOLS/Godot.app/Contents/MacOS/Godot
SRC="$WORK/decomp-full/v1.2 (Steam)"
PROJECT=$WORK/mod-project
OUT_DIR=$WORK/evidence/modding/out
APP=$OUT_DIR/BuckshotRouletteMod.app
SMOKE_LOG=$WORK/evidence/modding/logs/smoke-run.log

rm_under_work() {
  case "$1" in "$WORK"/?*) rm -rf "$1" ;; *) die "refusing to delete outside $WORK: $1" 1 ;; esac
}

preflight() {
  local f
  for f in "$SRC/project.godot" "$SRC/scenes/main.7z" "$SRC/scenes/menu.tscn" \
           "$PATCH/SteamStub.gd" "$PATCH/export_presets.cfg"; do
    [ -f "$f" ] || die "missing input: $f"
  done
  grep -q 'config/features=PackedStringArray("4.1"' "$SRC/project.godot" || die "source project is not pinned to Godot 4.1"
  grep -q '^GlobalSteam=' "$SRC/project.godot" || die "source project.godot has no GlobalSteam autoload to patch around"
  grep -q 'text = "v1.2.0 (decompilation)"' "$SRC/scenes/menu.tscn" || die "menu.tscn version label not found"
  local tool
  for tool in curl unzip shasum nix nice file; do command -v "$tool" >/dev/null || die "missing tool: $tool"; done
}

fetch_godot() {
  if [ ! -x "$GODOT" ]; then
    mkdir -p "$WORK/tools/dl" "$TOOLS/editor_data/export_templates/4.1.4.stable"
    cd "$WORK/tools/dl"
    local f
    for f in SHA512-SUMS.txt Godot_v${GODOT_VERSION}_macos.universal.zip Godot_v${GODOT_VERSION}_export_templates.tpz; do
      [ -f "$f" ] || $HEAVY curl -fL --retry 3 -O "$GODOT_URL/$f"
    done
    grep -E "Godot_v${GODOT_VERSION}_(macos.universal.zip|export_templates.tpz)" SHA512-SUMS.txt | shasum -a 512 -c -
    unzip -q -o Godot_v${GODOT_VERSION}_macos.universal.zip -d "$TOOLS"
    unzip -q -o -j Godot_v${GODOT_VERSION}_export_templates.tpz templates/macos.zip templates/version.txt \
      -d "$TOOLS/editor_data/export_templates/4.1.4.stable"
    touch "$TOOLS/Godot.app/Contents/MacOS/._sc_" "$TOOLS/._sc_"
  fi
  case "$("$GODOT" --version 2>/dev/null)" in 4.1.4.stable*) ;; *) die "unexpected Godot version" 1 ;; esac
}

copy_source() {
  rm_under_work "$PROJECT"
  cp -Rc "$SRC/." "$PROJECT/"
  $HEAVY nix run nixpkgs#_7zz -- x -y -o"$PROJECT/scenes" "$PROJECT/scenes/main.7z" >/dev/null
  rm "$PROJECT/scenes/main.7z"
  test -s "$PROJECT/scenes/main.tscn"
}

patch_project() {
  rm_under_work "$PROJECT/addons/godotsteam"
  rm_under_work "$PROJECT/.godot/extension_list.cfg"
  rmdir "$PROJECT/addons" 2>/dev/null || true
  mkdir -p "$PROJECT/stubs"
  cp "$PATCH/SteamStub.gd" "$PROJECT/stubs/"
  sed -i '' 's|^GlobalSteam=|Steam="*res://stubs/SteamStub.gd"\
GlobalSteam=|' "$PROJECT/project.godot"
  sed -i '' "s|text = \"v1.2.0 (decompilation)\"|text = \"$MOD_LABEL\"|" "$PROJECT/scenes/menu.tscn"
  cp "$PATCH/export_presets.cfg" "$PROJECT/"
  grep -q '^Steam="\*res://stubs/SteamStub.gd"' "$PROJECT/project.godot" || die "Steam autoload patch did not apply" 1
  grep -q "text = \"$MOD_LABEL\"" "$PROJECT/scenes/menu.tscn" || die "label patch did not apply" 1
}

export_app() {
  mkdir -p "$OUT_DIR" "$(dirname "$SMOKE_LOG")"
  rm_under_work "$APP"
  cd "$PROJECT"
  $HEAVY "$GODOT" --headless --path . --export-release macOS
  grep -q -a 'MODDED BUILD TEST' "$APP/Contents/Resources/Buckshot Roulette.pck" || die "mod string missing from .pck" 1
  file "$APP/Contents/MacOS/Buckshot Roulette"
}

smoke_run() {
  local code=0
  set +e
  $HEAVY "$APP/Contents/MacOS/Buckshot Roulette" --headless --quit-after 300 >"$SMOKE_LOG" 2>&1
  code=$?
  set -e
  local scene label
  scene=$(grep -a '^smoke: scene=' "$SMOKE_LOG" | tail -1 || true)
  label=$(grep -a '^smoke: version_label=' "$SMOKE_LOG" | tail -1 || true)
  echo "smoke: app exit code $code (log: $SMOKE_LOG)"
  echo "$scene"; echo "$label"
  if [ "$scene" != "smoke: scene=res://scenes/menu.tscn" ] || [ "$label" != "smoke: version_label=$MOD_LABEL" ]; then
    echo "SMOKE FAILED: menu scene or modded label not seen"; return 4
  fi
  if [ "$code" -ne 0 ]; then
    echo "SMOKE INCONCLUSIVE: menu and label seen, but the app exited $code (cause not isolated)"; return 3
  fi
  echo "SMOKE OK"
}

preflight
trap 'exit 1' ERR
fetch_godot
copy_source
patch_project
export_app
trap - ERR
smoke_run
