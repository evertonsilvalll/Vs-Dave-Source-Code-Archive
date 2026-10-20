# Vs Dave & Bambi 2.0 — Android

This port targets the original `2.0 - 7a57a2b` snapshot, not 2.0b or 2.5.
The other archived snapshots in this repository are unchanged.

## Play

Install the debug APK from the **Android 2.0 APK** GitHub Actions artifact.
It includes ARMv7 and ARM64 native libraries, uses a separate application ID
(`org.vsdave.android.v2`), and stores scores/settings in application-private storage.
Android 5.0/API 21 or newer and a GPU supporting 4096-pixel textures are required.
The legacy native libraries are intended for devices using 4 KB memory pages;
16 KB-only devices are not supported by this pinned Lime toolchain.
Physical-device compatibility and performance must be checked before a release.

- The colored Psych Engine 0.7.3 mobile D-pad navigates menus and plays notes.
- **A** confirms, advances dialogue, retries, or leaves an ending. **B** goes
  back or chooses no on the initial shader warning.
- The Psych pause icon at the top right pauses a song. Android Back also pauses;
  in menus it acts as B. Pause menus and dialogue always restore the D-pad/A/B.
- In **Options**, select **Mobile Psych Pad** and press A to switch to
  **Mobile Hitbox**: four full-height lanes, left/down/up/right. Press A on
  **Hitbox Visible** to switch to **Hitbox Invisible**. Invisible lanes keep
  exactly the same touch regions. The pause icon remains visible in either mode
  and its touch region takes priority over the right lane.
- On the first warning, **A** enables visual effects and **B** disables them.
  The Eyesores option can change this later. Settings persist in the app save.

The debugger and song editor/debug shortcuts are disabled on Android, including
in debug-signed APKs. Touch input reads native Lime start/move/end/cancel events;
fresh starts can recover reused Android pointer IDs after an interrupted release.
Several fingers, held notes and slides are supported. A finger already held at a
state/pause transition stays blocked until lifted, avoiding accidental menu input.

The game uses a 1280×720 logical viewport in landscape, letterboxed on wider
screens, and 60 FPS. The on-screen buttons stay outside the game cameras so
camera zoom/shake does not move their touch regions.

### Differences from desktop

- WebM cutscenes are skipped, continuing through the normal loading transition.
  This source's WebM player only supports desktop; it is not bundled on Android.
- Discord RPC and Newgrounds online scores/medals are disabled. Local highscores
  and progression remain available.
- Filesystem mod loading and desktop chart/animation editing are not exposed
  through touch controls. The original packaged mod content is included.
- Intentional process-exit easter eggs return to the main menu on Android.
- This is a sideload/debug build, not a Play Store release. It targets API 28 to
  retain the source engine's platform contract. Store publication requires a
  modernized engine/SDK, signing configuration, and device validation.

## Build on Linux

Install Haxe 4.1.5, Neko (required by haxelib), Python 3.10+, and JDK 11.
The included `.mise.toml` declares Haxe and Java versions. With mise installed:

```sh
mise install
mise exec -- bash tools/install_android_deps.sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r tools/requirements-android.txt
```

Install Android SDK platform 28, build tools 30.0.3, and NDK 21.4.7075529 using
Android Studio or `sdkmanager`. Recent `sdkmanager` versions require JDK 17;
switch back to JDK 11 for the legacy game build. Accept SDK licenses locally.

```sh
sdkmanager 'platforms;android-28' 'build-tools;30.0.3' 'ndk;21.4.7075529'
export ANDROID_SDK=/your/android-sdk
export ANDROID_NDK_ROOT="$ANDROID_SDK/ndk/21.4.7075529"
export JAVA_HOME=/your/jdk-11
mise exec -- bash tools/build_android.sh
```

Run these commands from this snapshot directory. `build_android.sh` prepares
assets and invokes Lime with debug signing. The APK is written to:

```text
export/debug/android/bin/app/build/outputs/apk/debug/VsDave-debug.apk
```

The root `.github/workflows/android-2.0.yml` performs the same build and uploads
that APK. No personal API keys or release signing secrets are needed.
Dependencies are pinned in `tools/install_android_deps.sh`; do not use
`haxelib upgrade` for this source snapshot. Gradle 7.5.1 / Android Gradle plugin
7.4.2 use Maven Central and Google instead of the retired JCenter repository.

## Assets and memory

`tools/prepare_android_assets.py` creates the ignored `android-assets/` tree.
The original assets are never modified. Oversized Sparrow atlases are repacked
losslessly into pages no larger than 4096×4096, retaining frame order, pixels,
trim offsets and rotation metadata. Android `Paths.getSparrowAtlas` combines
those pages; desktop continues to use the original PNG/XML files.

For this snapshot, 12 oversized atlases become 33 pages. Their total decoded
area drops from 1,984.0 MiB to 1,371.8 MiB across all atlases (not simultaneous
usage). This does not guarantee a particular peak RAM use on a device.

Shared and song manifests are registered at startup. Lime 7.9.0's native
uncompressed libraries do not decode all assets merely because library
`preload` is true. Gameplay explicitly loads its song and relevant week;
mod weeks use shared assets instead of nonexistent week libraries.

## Validation

```sh
bash tests/test-mobile-input.sh
python -m unittest discover -s tools -p 'test_prepare_android_assets.py'
```

The touch tests cover chords, sustain releases, slides, fast taps, multiple
fingers on one button, state transitions, interrupted/reused touch IDs, menu and
hitbox geometry, letterboxing and pause priority. Atlas tests
check metadata/pixel preservation, deterministic output and invalid inputs.
Run the repository's Haxe formatter on changed Haxe files:
`haxelib run formatter -s path/to/ChangedFile.hx`.

Before distributing a release, test on actual ARMv7 and ARM64 devices:

- Cold start, both warning choices, menu navigation, and save persistence.
- Story and Freeplay, character selection, chords and sustained notes.
- Pause/resume, retry, Back, switching apps mid-song and returning.
- All mod weeks, the OST menu, cutscene-to-song transitions and endings.
- Aspect ratios with letterboxing, sound synchronization, memory and long sessions.

## Mobile graphics attribution

The unmodified PNGs in `assets/preload/mobile/` come from the active
[FunkinPortingMobile/Psych-Engine-0.7.3-Mobile](https://github.com/FunkinPortingMobile/Psych-Engine-0.7.3-Mobile)
port. The pinned source revision, attribution and Apache 2.0 license are included
in that directory and packaged with the Android assets. The overlay crops their
normal/pressed frames at runtime. No engine upgrade is implied by these controls.
