# Voxel Heist - Complete Project Summary (v0.1 to v0.3)

Original Godot 4 game, inspired by Teardown's destructible-voxel + heist
concept only. No Teardown code, maps, assets, name or branding are used.

## 1. What we built - checklist

### v0.1 - Core prototype
- [x] Godot 4 project (`project.godot`, mobile renderer, landscape)
- [x] Voxel destruction system (`scripts/voxel_world.gd`)
  - Shared BoxMesh + shared materials, small test map (~300 voxels)
  - Hammer: 1 voxel. Explosive: 3-voxel radius.
- [x] Basic test map (`scripts/test_map.gd`, procedural, no external assets)
  - One building, entrance gap, crates, gold vault, blue escape vehicle
- [x] Heist loop (`scripts/game_manager.gd`)
  - SETUP (no timer) -> touch vault -> 60-second ALARM -> reach vehicle -> WIN/LOSE
- [x] Touch UI (`scripts/touch_ui.gd`)
  - Virtual joystick, right-side camera drag, ATTACK / TOOL / DRIVE / RESTART
  - Desktop fallback: WASD, mouse, Space/Q/E

### v0.2 - Feedback, vehicle, voxel types, polished UI
- [x] Destruction feedback (`scripts/effects.gd`, `scripts/audio_manager.gd`)
  - Dust particles (GPUParticles3D, one-shot) + 3 flying debris cubes per break
  - Placeholder sounds generated in code: break noise, explosion noise,
    alarm beep every 0.6s during ALARM. No audio files needed to run.
- [x] Drivable vehicle (`scripts/vehicle.gd`)
  - CharacterBody car (not VehicleBody3D, so it can ram through voxels)
  - Joystick steering/throttle, acceleration + friction
  - Fast ramming breaks wood/brick ahead; metal stops the car
  - Win now requires driving to the escape zone, not just touching the car
- [x] Voxel types & floating physics (`scripts/voxel_world.gd`)
  - Wood = 1 hammer hit, Brick = 2 hits, Metal = hammer-proof (explosives only)
  - Vault / floor = indestructible
  - Floating voxels: flood-fill from the floor, unsupported voxels fall
    as RigidBody debris and delete themselves after 3 seconds
- [x] Polished heist UI (`scripts/touch_ui.gd`)
  - Large 48pt countdown timer, red under 10 seconds
  - Full-screen Victory and Game Over panels with Restart

### v0.3 - Map expansion and polish
- [x] Mini-town map (`scripts/test_map.gd`, coordinate overview in the file)
  - Fenced parking lot (player + vehicle start, wood fence, east gate)
  - Guard office (brick base, wood upper walls, keycard inside)
  - Two-story warehouse (brick walls y1-6, roof y7, metal vault divider
    with a wood door, vault inside)
  - Brick barrier wall between guard and warehouse, weak wood point,
    long way around via the south
- [x] Multi-objective (`scripts/game_manager.gd`)
  - Security Keycard (cyan voxel, guard office) must be collected first
  - Vault without keycard: "VAULT LOCKED" for 3 seconds, no timer starts
  - Vault with keycard: 60-second alarm starts, then drive to safety
- [x] Progress tracker (`scripts/touch_ui.gd`)
  - Top-right, always visible: "Keycard: Missing/Found" / "Vault: Locked/Ready"
- [x] Mobile performance cap (`scripts/effects.gd`)
  - MAX_ACTIVE_EFFECTS = 40 live effect nodes (particles + debris + falling voxels)
  - New effects prune the oldest effects first, before adding the new one
- [x] Scene tree instructions (`SCENE_TREE.md`)
  - Runtime tree, signal connections, voxel type cheat-sheet, floating rule

## 2. Next steps for Android testing

### Important note first
This project has NOT been run in the Godot editor or on a real phone yet
in this sandbox, because there is no Godot editor installed here. The
steps below are the standard Godot 4 route to do that first real test.
Do not skip the desktop Play test - it catches scene/script errors
before you spend time on an Android build.

### Step 0 - Test on desktop first (on a PC, when you have one)
1. Install Godot 4.2 or newer from godotengine.org.
2. In Godot, Import -> choose this project folder (`project.godot`).
3. Press Play. Main scene is `scenes/main.tscn`.
4. Play the full loop once with keyboard/mouse:
   parking -> guard office keycard -> barrier -> warehouse vault door
   -> vault (alarm) -> back to parking vehicle -> DRIVE -> green escape zone.
5. Fix any errors Godot shows in the Output / Debugger panels before
   moving to Android. A desktop error will also be an Android error.

### Step 1 - Prepare the phone (real Android device)
1. On the phone: Settings -> About phone -> tap Build number 7 times
   to enable Developer options (exact menu wording varies by phone).
2. Settings -> Developer options -> turn ON USB debugging.
3. Connect the phone to the PC with a USB cable. On the phone, tap
   "Allow USB debugging" for that PC when prompted.
4. On the PC, check the phone is seen: open a terminal and run
   `adb devices`. It should list your phone as "device", not "unauthorized".

### Step 2 - Set up Android Export templates (PC, one time)
1. In Godot: Editor -> Manage Export Templates -> Download and Install.
   This downloads the Android (and other) export templates for your
   exact Godot version. Do not mix versions - templates must match.
2. Install Android SDK + JDK 17:
   - Easiest route: install Android Studio, then in Godot go to
     Editor -> Editor Settings -> Export -> Android, and set
     "Android SDK Path" to Android Studio's SDK folder.
   - Or install the standalone Android command-line tools + platform-tools.
3. In the same Editor Settings page, set the JDK path if Godot asks for it.
   Godot 4.2+ needs JDK 17 for Android builds.
4. Create a debug keystore (one time, for testing only):
   - Godot can generate one when you export, or use keytool from the JDK.
   - For a release build later, keep this keystore file safe - losing it
     means you cannot update the same Play Store app later.

### Step 3 - Configure the Android export preset (PC)
1. Project -> Export -> Add -> Android.
2. Set a unique package name, for example `com.voxelheist.game`.
   Do not use the example package from another project.
3. Set Version Name to `0.3` and Version Code to `3` (increase Code on
   every new build you install over the old one).
4. Under Permissions, keep the default for now. This game needs no
   special Android permissions in v0.3.
5. Under Keystore, point to your debug keystore for testing.
6. Save the preset. It is stored in the project as `export_presets.cfg`.

### Step 4A - Test with Remote Deploy ("Godot Android Remote" style)
There is no separate "Godot Android Remote" app to install for Godot 4.
Remote deploy is built into the editor:
1. Complete Steps 1-3 above, with the phone connected by USB and
   USB debugging allowed.
2. In the Godot editor, look at the device selector in the top-right
   (next to the Play button). Your Android phone should appear there
   after Godot detects it via adb.
3. Select the Android device, then press Play (Remote Deploy).
   Godot builds a debug APK, installs it on the phone via adb, and
   runs it with remote debugging attached to the editor.
4. Play on the phone with touch: joystick, camera drag, ATTACK, TOOL,
   DRIVE, RESTART. Check the Output panel in the editor for errors
   while you play.
5. If the phone does not appear: check `adb devices` again, try a
   different USB cable/port, make sure USB debugging is still on,
   and restart Godot after connecting the phone.
6. To stop: press Stop in the editor, or close the game on the phone.
   The debug APK stays installed until you uninstall it.

### Step 4B - Or, export a debug APK and install it manually
If remote deploy does not work, this is the reliable fallback:
1. Project -> Export -> select your Android preset -> Export Project.
2. Choose "Export With Debug" and save the `.apk` file.
3. Copy the APK to the phone (USB, Drive, or any file transfer you trust),
   or run `adb install -r your-game.apk` from the PC terminal.
4. On the phone, allow "Install unknown apps" for the file manager /
   browser you used, if Android asks. Install, open, and play the
   full loop with touch controls.
5. Note the frame rate, especially when you blow up a wall and many
   voxels fall at once. That is what the 40-effects cap in v0.3 is for.
   If it still lags, the next step is chunking (see v0.4 below), not
   adding more voxels.

### Phone-only alternative (no PC yet)
If you do not have a PC yet, the standard route above cannot run.
The workaround used for other projects here is CI:
1. Push this Godot project to a GitHub repo.
2. Add a GitHub Actions workflow that installs Godot + Android
   templates, exports the Android debug APK, and uploads it as an
   artifact.
3. Download that artifact APK to your phone and install it as in
   Step 4B.
This is a v0.4 setup task, not something to guess at in v0.3, because
the workflow file must match the exact Godot version and SDK you use.

## 3. Future scope - v0.4 ideas (when you are ready)

- Larger map chunking: split the town into chunks and only keep physics
  bodies for nearby chunks active, so a bigger town does not mean
  hundreds of always-on StaticBody voxels.
- Real audio files: replace the generated placeholder tones in
  `audio_manager.gd` with real break / explosion / alarm / victory
  `.wav` files in `res://audio/`, keeping the same call sites.
- Real VehicleBody3D driving: upgrade the CharacterBody car to
  VehicleBody3D + wheels once the ramming + drive loop is proven fun,
  and re-tune ramming so wheels do not get stuck on voxel edges.
- Second-floor interior: add a real second-floor slab + stairs in the
  warehouse, and a second vault / loot objective upstairs.
- Enemies / guards AI: simple patrol guards in the warehouse that
  raise the alarm early if they see the player, plus a stealth option.
- More levels: a second town layout using the same builder, with a
  different keycard / vault / escape placement, and a level-select screen.
- Save + settings: save best escape time, add a settings screen for
  joystick size, camera sensitivity, and sound on/off.
- Polish: real textures / materials instead of flat colours, shadows
  on high-end phones only (with a quality toggle), and a proper
  joystick circle texture instead of the plain hit-area in v0.2/v0.3.
