# Modding and macOS port

## Result

A universal macOS `.app` was exported from the historical v1.2 Steam decompilation. A small menu-label mod is present in its `.pck` and in its live scene tree during a headless run.

The run is not a clean pass. It initializes the menu, reports the modded label, then exits with code 1 after font, dummy-renderer, and resource-cleanup errors. No window was opened. Gameplay, visual rendering, real Steam services, and distribution on another Mac are unverified.

| Goal | Result |
| --- | --- |
| Build the requested public repository directly | Blocked. Current scripts, gameplay scenes, and project configuration are omitted. |
| Recover a complete historical project | Done through the repository linked in its README. `main.7z` contains the large gameplay scene. |
| Change one visible string | Done. Menu version label changed to `v1.2.0 (decompilation) - MODDED BUILD TEST`. |
| Export macOS | Done. Unsigned 468 MiB universal `.app`, x86_64 and arm64. |
| Run a modded project | Partial. Exported app instantiates the menu and modded label headlessly. Exit 1 makes the smoke result inconclusive. |
| Verify a playable macOS port | Not done. No visual or gameplay check. Steam is stubbed. |
| Recover assets from a locally installed retail copy | Not done. No Buckshot installation or retail `.pck` was found in the searched locations. Account ownership remains unknown. |

This was a timeboxed prototype. It proves export feasibility for the historical project, not parity with the current game.

## Inputs and engine version

All source and game-owned files stay in ignored `_work/`. No game installation or host service was changed. No game files were published or pushed.

The input revisions are the same as the [accuracy report](accuracy-report.md).

- Public repository at `5da18fc8aae5c4209ffee6b80b282e4301cf763f`, under `_work/decomp/`.
- Supplemental repository at `0a573d3b8c835f78d47e1fa5b1143e803b6ffd7f`, under `_work/decomp-full/`.
- Build source is its `v1.2 (Steam)/` directory. The scripts and scene are from the April 2024 v1.2 release. The later `v1.2.2` tag changes only README content.

In the source references below, `G/` means `_work/decomp-full/v1.2 (Steam)/`. `G/../README.md` is the supplemental repository's top-level README.

`G/project.godot:14-15` selects `res://scenes/menu.tscn` and `PackedStringArray("4.1", "Forward Plus")`. The README recommends the Godot `STABLE-4.1` branch at `G/../README.md:23` and warns about newer-engine material issues at `G/../README.md:24`. It notes a Vulkan requirement at `G/../README.md:39`.

The exact original Godot 4.1 patch is not recorded. The prototype uses official Godot 4.1.4 and matching export templates. The editor reports `4.1.4.stable.official.fe0e8e557`. The host is macOS 26.6.2, build 25G83, arm64. Godot's version was checked through `--version`; the host through `sw_vers` and `uname -m`.

| Material | Public root | Supplemental v1.2 project |
| --- | --- | --- |
| `project.godot` | Absent | Present |
| Current gameplay scripts | Omitted. Root `scripts/` holds a zero-byte placeholder. Old v1.1 scripts exist under `!OLD VERSIONS/`. | Present under `scripts/` |
| Gameplay scenes | Omitted from root `scenes/`. A separate main-player scene and historical files exist elsewhere. | Menu, death, ending, and other scenes exist. Main scene is archived. |
| Assets | PNG, audio, models, fonts, materials, and translations exist. | Assets and Godot imported-resource caches exist. |
| `.import` metadata | Some model and historical metadata exists. Not a complete current project. | Metadata and `.godot/imported/` cache exist. |
| Export presets | Absent | Absent. A local macOS preset was added. |
| Native Steam extension | Not enough current project files to run it | Bundled GodotSteam exists, but its macOS library fails to load. |

The supplemental README explains compressed files at `G/../README.md:13-15`. The extracted `main.tscn` is 137,443,904 bytes. It contains the round resources that a script-only inspection would miss.

## Local game and asset recovery

The search was read-only. It checked both located Steam libraries.

- `~/Library/Application Support/Steam/steamapps/`.
- The Steam library in the CrossOver Steam bottle under `~/Library/Application Support/CrossOver/Bottles/Steam/`.

Neither library has an app manifest for Buckshot Roulette, app 2835570. Searches of their configuration and local app metadata found no app-id hit. A Spotlight `.pck` search found no retail game package. These checks do not establish account ownership and do not rule out a copy on an unmounted disk or outside the indexed paths.

No retail asset recovery was attempted. The prototype uses the decompilation already fetched from the user's named repository and its README-linked source. Only official engine tools were downloaded afterward. No retail game archive was downloaded.

[GDRE Tools v2.7.1](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.1) has a macOS archive in the release API response read during this audit. It is a candidate for recovering an owned `.pck` or embedded game pack into `_work/`. It was not downloaded or tested because no retail package was available. A recovered current project would also provide a better source for the post-v1.2 rule changes and multiplayer. Tool availability is not proof that every current script will decompile correctly.

## Changes made only in the build copy

The build copy is `_work/mod-project/`. The original clones are unchanged.

1. Unpack `G/scenes/main.7z` into the copy's `scenes/` directory.
2. Change the menu version label at `G/scenes/menu.tscn:1172` from `v1.2.0 (decompilation)` to `v1.2.0 (decompilation) - MODDED BUILD TEST`.
3. Replace the broken native Steam extension with an original, inert `Steam` autoload stub.
4. Add a local macOS export preset.

The Steam workaround changes more than the visible string. It deliberately disables achievements, friends, and leaderboards. It does not simulate a Steam connection. `G/project.godot:23-24` has the original autoloads. `G/scripts/Steam.gd:3-18` initializes app 2835570 and calls the missing native singleton.

### Why the Steam workaround was necessary

`G/addons/godotsteam/godotsteam.gdextension:6-7` names macOS debug and release frameworks. Its dependencies block at lines 17-21 has entries for Windows and Linux, not macOS.

The initial run logged a dynamic-library failure for `_SteamAPI_Init`. The debug framework references that symbol, but its bundled `libsteam_api.dylib` does not export it. It exports `_SteamAPI_InitSafe` and related symbols instead. This was checked with `nm -u` and `nm -gU`. The failure prevents Godot from declaring `Steam`, so scripts using it fail to parse.

The prototype removes that extension only from the build copy. `scripts/mod-support/SteamStub.gd` supplies the exact members the historical scripts call. It also reads the active scene and menu label one frame after startup for the smoke check.

A production repair needs a matching GodotSteam macOS library and compatible Steamworks library. Neither was fetched. The stub is enough to investigate local export, not enough for a real Steam-enabled port.

## Tools and exact commands

Official downloads came from the [Godot 4.1.4 release](https://github.com/godotengine/godot/releases/tag/4.1.4-stable).

- `Godot_v4.1.4-stable_macos.universal.zip`.
- `Godot_v4.1.4-stable_export_templates.tpz`.
- `SHA512-SUMS.txt`.

Both downloaded archives passed `shasum -a 512 -c` against that release's checksum file. The editor is under `_work/tools/godot-4.1.4/Godot.app/`. Only the macOS template and its version file were extracted from the template package. Self-contained editor markers keep editor data under `_work/` rather than the user's Library directory.

The extraction command was:

```sh
nice -n 10 nix run nixpkgs#_7zz -- x -y 	-o_work/mod-project/scenes 	"_work/mod-project/scenes/main.7z"
```

The first import attempt used `--import`. Godot 4.1 does not support that flag. It started the project instead and hit the Steam error. The owned process was stopped. A subsequent `--headless --editor --quit` scan had no script errors after the stub, but exited 1 before a clean import finish. This is not recorded as a successful import.

Export itself processed resources and completed with exit 0. From the build-copy directory, its command was:

```sh
nice -n 10 ../tools/godot-4.1.4/Godot.app/Contents/MacOS/Godot 	--headless --path . --export-release macOS
```

The preset exports to `_work/evidence/modding/out/BuckshotRouletteMod.app`. It uses universal architecture, bundle ID `local.test.buckshotmod`, and no signing or notarization.

The retained script reproduces the copy, extraction, patches, export, and smoke check. It requires the supplemental clone to be present. It validates the source anchors and `_work` path before deleting its prior build copy. It can download the official editor and templates if missing. The template package is roughly 820 MB, so allow disk space and time.

```sh
nice -n 10 bash scripts/rebuild-macos.sh
```

The script support files are `scripts/mod-support/SteamStub.gd` and `scripts/mod-support/export_presets.cfg`. They contain original local-build support, not game assets.

Script exit statuses distinguish build success from a healthy run.

| Status | Meaning |
| ---: | --- |
| 0 | Export succeeded. Menu and modded label instantiated. App exited 0. |
| 1 | A build step failed. |
| 2 | Input or tool preflight failed. |
| 3 | Export succeeded and menu plus label instantiated, but the app exited nonzero. Smoke is inconclusive. |
| 4 | Export succeeded, but smoke did not report the expected menu and label. |

The verified prototype returns 3. It must not be reported as a clean pass.

## Export and smoke evidence

`file` reports both x86_64 and arm64 Mach-O architectures. The app is 468 MiB on disk. Its `.pck` is 341,199,424 bytes. A binary-string check finds the mod text exactly once.

A direct run of the exported executable used:

```sh
nice -n 10 "_work/evidence/modding/out/BuckshotRouletteMod.app/Contents/MacOS/Buckshot Roulette" 	--headless --quit-after 300
```

It reports these live values:

```text
steam init: { "status": 1, "verbal": "steam stub (no Steam)" }
smoke: scene=res://scenes/menu.tscn
smoke: version_label=v1.2.0 (decompilation) - MODDED BUILD TEST
```

This proves the modded menu scene instantiated. It does not prove the label rendered correctly. The direct verification run exits 1. It logs `FreeType: Error loading font: ''`, dummy-renderer mesh errors, leaked instances, and resources in use at exit. The cause of the nonzero exit was not isolated inside the timebox. Font or resource damage must not be dismissed as harmless headless behavior without a visual test.

Build and smoke logs are under `_work/evidence/modding/logs/`. The direct final smoke output is `_work/verified-app-smoke.log`. Its process handle recorded exit 1. The final retained-script log at `_work/final-rebuild.log` explicitly records `app exit code 1` and `SMOKE INCONCLUSIVE`. Its process completion reports script status 3. The original clone statuses were checked after the prototype.

## Remaining blockers

- The project is historical v1.2, not the current game. Official v1.2.1 and v1.2.2 notes already prove some gameplay changes after this snapshot. See the accuracy report.
- No current multiplayer scripts are available in the supplied public source.
- Real Steam initialization, achievements, and leaderboards are disabled in the prototype.
- The headless run has a nonzero exit. Rendering, fonts, audio, and full gameplay need investigation on a real window.
- The `.app` is unsigned and unnotarized. Gatekeeper may block distribution. No system security settings were changed.
- The exact original Godot patch is unknown. 4.1.4 exports this project, but that does not establish 4.1.4 as the original build engine.
- No owned retail package was available to validate the decompilation's assets against a shipping build.

The next useful step is a lawful current package or complete current project, followed by a proper GodotSteam repair and visual gameplay checks. The existing export is a useful local prototype, not a finished macOS port.
