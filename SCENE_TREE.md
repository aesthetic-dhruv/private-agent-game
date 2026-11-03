# Scene tree instructions - Voxel Heist v0.3

## v0.3 additions to the tree

- No new scene nodes are added by hand. The town, keycard voxel and
  escape-zone floor markers are all built by `TestMapBuilder.build()`.
- `GameManager` now tracks `has_keycard` and `keycard_pos` in addition
  to `vault_pos`, `vehicle_start` and `escape_zone`.
- `TouchUI` now has a `_progress_label` (top-right):
  "Keycard: Missing/Found" / "Vault: Locked/Ready", updated on every
  `GameManager._update_ui()` call.
- `DestructionEffects` now has a static `_active` list and
  `MAX_ACTIVE_EFFECTS = 40`. `register_effect()` prunes the oldest
  effect before adding a new one. Falling voxels register themselves
  through the same function.
- Keycard pickup is proximity-based (distance < 2.0), not a button.
  On pickup, GameManager destroys the keycard voxel (no effects) so
  it cannot be collected twice, and Restart rebuilds it via the town builder.

## How the tree is built

`scenes/main.tscn` intentionally contains only one node:

```
Main (Node3D, script: scripts/game_manager.gd)
```

Everything else is spawned in `GameManager._ready()` in code. This is
deliberate for v0.2: the test map is procedural, so there are no models,
textures or hand-placed scenes to break. When you press Play in Godot,
the runtime tree becomes:

```
Main (GameManager)
├── VoxelWorld (VoxelWorld)
│   └── Voxel nodes (Node3D)
│       ├── MeshInstance3D (shared BoxMesh)
│       └── StaticBody3D + CollisionShape3D (not for floor voxels)
├── Player (CharacterBody3D, script: player.gd)
│   ├── CameraPivot (Node3D)
│   │   └── Camera3D
│   └── CollisionShape3D (CapsuleShape3D)
├── EscapeVehicle (CharacterBody3D, script: vehicle.gd)
│   ├── MeshInstance3D (car body box)
│   ├── CollisionShape3D (car box)
│   └── 4x MeshInstance3D (wheel boxes, visual only)
├── AudioManager (Node, script: audio_manager.gd)
│   ├── AudioStreamPlayer (break / explosion)
│   └── AudioStreamPlayer (alarm beep)
├── TouchUI (CanvasLayer, script: touch_ui.gd)
│   ├── Phase Label, Timer Label (48pt), Tool Label
│   ├── Joystick hit-area (bottom-left)
│   ├── Buttons: ATTACK, TOOL, DRIVE, RESTART
│   ├── Victory Panel (PanelContainer, hidden until WIN)
│   └── Game Over Panel (PanelContainer, hidden until LOSE)
├── StaticBody3D (ground plane, WorldBoundaryShape3D)
└── DirectionalLight3D (no shadows, for mobile)
```

## If you want the tree visible in the editor instead

1. Open `scenes/main.tscn` in Godot.
2. Add the nodes above by hand, in the same order, and attach the same
   scripts listed in parentheses.
3. Remove the matching `*.new()` + `add_child()` lines from
   `GameManager._ready()` for any node you added by hand, or you will
   get two copies at runtime.
4. Set `GameManager.world`, `player`, `vehicle`, `ui` and `audio` to
   those editor nodes instead of the spawned ones.

For v0.2, the code-spawned version is the tested path. Do not do both.

## Key connections (all in code, no editor signals needed)

- `Player.attacked -> GameManager._on_player_attacked`
  - Hammer: `VoxelWorld.hammer_hit(point)`
  - Explosive: `VoxelWorld.explode(point, 3.0)`
- `VoxelWorld.voxel_destroyed -> GameManager._on_voxel_destroyed`
  - Plays the placeholder break sound via `AudioManager.play_break()`.
- `VoxelWorld.voxel_blocked` (metal / vault hammer hits)
  - Plays nothing on purpose, so a blocked hit sounds different.
- `TouchUI DRIVE button -> GameManager.toggle_drive()`
  - Only works within 5 units of the vehicle. Sets `driving = true`,
    hides the Player, activates the vehicle, and forwards the joystick.
- `TouchUI RESTART button -> GameManager.restart()`
  - Clears all voxels, rebuilds the test map, resets vehicle, player,
    phase and timer.
- Alarm: `GameManager._process()` ticks every 0.6s in ALARM phase and
  calls `AudioManager.alarm_tick()`. It stops automatically on WIN/LOSE
  because `_process()` only ticks in ALARM.

## Voxel type cheat-sheet for the test map

- Wood (brown): 1 hammer hit. Divider, crates.
- Brick (red-grey): 2 hammer hits. Walls, roof.
- Metal (dark grey): hammer-proof, explosives only. Vault pillars.
- Vault (gold): indestructible, touch it to start the alarm.
- Floor (grey): indestructible visual ground.

## Floating voxels

After any destruction, `VoxelWorld.check_floating()` flood-fills from
floor voxels (y == 0). Voxels not reached are converted to RigidBody3D
debris that falls under gravity and deletes itself after 3 seconds.
