# Voxel Heist - v0.3 + Cloud Android Build (Godot 4, original game)

## Cloud Android build - no PC needed (v0.4 CI setup)

Files added for this:
- `.github/workflows/android_build.yml` - the full GitHub Actions workflow
- `export_presets.cfg` - Android preset, package `com.voxelheist.game`,
  version 0.3, code 3, `use_gradle_build = false`
- `.gitignore` - ignores `.godot/`, `build/`, `debug.keystore`, `*.apk`

How to use it, phone-only:
1. Create a new GitHub repo (for example `voxel-heist`) and push this
   whole project folder into it, including the hidden `.github/` folder
   and `export_presets.cfg`. Do not push a real keystore.
2. On GitHub, go to Actions. The workflow "Build Android APK" should
   run on push to `main`, or press Run workflow to run it manually.
3. Wait for the run to finish. If a step fails, open that step's log -
   templates, SDK, keystore and export are separate steps on purpose.
4. On the finished run page, scroll to Artifacts and download
   `voxel-heist-android-apk`. It contains `VoxelHeist.apk`.
5. On your phone, uninstall any older Voxel Heist APK first (each CI
   run generates a fresh debug keystore, so signatures differ),
   then install the downloaded APK and allow install from that source
   if Android asks.
6. Play the full loop with touch controls and check frame rate during
   big explosions (the 40-effects cap in v0.3 is for this).

This workflow has NOT been run in GitHub Actions from this sandbox,
so the first CI run is the test. See the workflow header comments for
the signature warning and for the optional persistent-keystore Secret
route if you want one signature across builds.

## v0.3 changes

- **Mini-town map** (`scripts/test_map.gd`, see the coordinate overview at
  the top of that file): fenced parking lot (player + vehicle start,
  wood fence, gate at east), guard office (brick base, wood upper walls,
  keycard inside), main two-story warehouse (brick walls y1-6, roof y7,
  metal vault divider with a wood door), and a brick barrier wall between
  guard and warehouse with a weak wood point. The long way around the
  barrier is south, via z=19-20.
- **Multi-objective:** Security Keycard (cyan voxel at 5,1,13 in the
  guard office) must be collected before the Vault can start the alarm.
  Touching the vault without it shows "VAULT LOCKED" for 3 seconds and
  starts no timer. After the keycard, the vault is Ready.
- **Progress tracker:** top-right UI label, always visible:
  "Keycard: Missing/Found" and "Vault: Locked/Ready".
- **Performance cap:** `scripts/effects.gd` now caps live effect nodes
  at 40 (particles + flying debris + falling voxels). New effects prune
  the oldest effects first, so a big explosion cannot pile up hundreds
  of bodies on Android. Falling voxels from `VoxelWorld` are registered
  in the same cap.
- **Win condition unchanged in spirit, new route:** alarm -> run back
  to the parking lot vehicle -> drive to the green escape zone
  (x 24-28, z 14-18). This backtrack is intentional heist tension in v0.3.

## v0.2 changes

- **Feedback:** dust particles (GPUParticles3D, one-shot) + 3 flying debris cubes
  on every voxel destruction. Placeholder sounds generated in code:
  break noise, explosion noise, and a repeating alarm beep (0.6s) during ALARM.
  No audio files are needed to run it; replace the generators in
  `scripts/audio_manager.gd` with real .wav files later if you want.
- **Drivable vehicle:** `scripts/vehicle.gd` (EscapeVehicle). DRIVE near the
  vehicle hides the player, gives the joystick to the car, and lets you
  steer/throttle. Fast ramming damages wood/brick in front of the car;
  metal stops the car. Win now requires driving the vehicle to the
  escape zone, not just touching it.
- **Voxel types:** wood = 1 hit, brick = 2 hits, metal = hammer-proof
  (explosives only), vault/floor = indestructible. Floating voxels:
  after any destruction, a flood-fill from the floor finds unsupported
  voxels and turns them into falling RigidBody debris (deleted after 3s).
- **Polished heist UI:** large 48pt countdown timer at the top centre,
  red under 10 seconds, plus full-screen Victory and Game Over panels
  with a Restart button. See `SCENE_TREE.md` for the full node tree
  and signal connections.

## v0.1 (kept below)

Inspired by the *concept* of Teardown (destructible voxels + heist), not a copy.
No Teardown code, maps, assets, name or branding are used. This is an original
test game built from scratch.

## What is in v0.1 - the step you asked to start with

- **Voxel destruction system** (`scripts/voxel_world.gd`)
  - Shared BoxMesh + shared materials per type, to keep mobile draw calls low.
  - Sledgehammer: destroys 1 voxel at the aimed point.
  - Explosive: destroys voxels in a 3-voxel radius around the aimed point.
  - Voxels are individual nodes so they can be removed without rebuilding a mesh.
- **Basic test map** (`scripts/test_map.gd`, built procedurally, no external assets)
  - One building, 12 x 8 voxels, 4 high, with an entrance gap, an interior divider,
    crates to practise on, a gold vault at the back, and a blue escape vehicle outside.
  - About 300 voxels on purpose. A whole city would need chunking first.
- **Heist loop** (`scripts/game_manager.gd`)
  - SETUP: walk around and plan. No timer.
  - Touch the gold vault -> ALARM starts, 60 seconds.
  - Reach the blue escape vehicle before the timer hits zero -> WIN.
  - Timer hits zero -> LOSE. RESTART rebuilds the map.
- **Touch UI** (`scripts/touch_ui.gd`)
  - Bottom-left virtual joystick for movement.
  - Drag on the right half of the screen to rotate the camera.
  - Buttons: ATTACK, TOOL (hammer / explosive), DRIVE (only near the escape vehicle),
    RESTART.
  - Desktop fallback: WASD to move, mouse to look, Space = attack, Q = switch tool, E = drive.

## How to run it in Godot (desktop, for testing)

1. Install Godot 4.2 or newer (free, from godotengine.org).
2. Open Godot, Import, choose this folder (`project.godot`).
3. Press Play. The main scene is `scenes/main.tscn`.

## How to export to Android (next step, not done in this sandbox)

Godot Android export needs, on a PC or in CI:
1. Godot 4.2+ editor.
2. Android export templates installed (Editor > Manage Export Templates).
3. Android SDK + a debug keystore (Godot can generate one).
4. Project > Export > Android, package name e.g. `com.voxelheist.game`, then Export.
5. Install the APK on the phone and test touch controls on the real device.

This sandbox could not do that export end-to-end: it has no Godot editor
installed, and its Gradle path is already known to be blocked, so I am not
claiming an APK is ready. The project above is the verified first step:
voxel system + test map + heist loop + touch UI, ready to open in Godot.

## What is NOT in v0.1 (honest limits)

- No police AI, no wanted level, no VehicleBody3D car physics. DRIVE is a
  simple speed toggle near the vehicle, not real car physics.
- No shadows (turned off for mobile performance), no textures, no sound.
- No second map, no save system, no multiplayer.
- Touch joystick visuals are plain hit-areas in code; circle textures are polish.

## Next milestones, in order

1. Godot editor test on desktop, fix any scene/import warnings.
2. Android export + real-phone touch test.
3. Chunked voxels + more maps, then VehicleBody3D driving, then police AI.
