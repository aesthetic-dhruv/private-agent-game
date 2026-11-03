extends Node
class_name TestMapBuilder
## v0.3 mini-town layout (Heist Zone), built in code, no external assets.
## Coordinate overview (grid, x east, z south, y up, voxel = 1 unit):
##
##   z 0-10:  WAREHOUSE (x 12-22, walls y1-6, roof y7, two stories tall)
##            Vault room east side, divider x=19 (metal, wood door at z=5)
##            Entrance west wall x=12, gap at z=5, y1-2
##   z 4-14: BARRIER WALL x=10, brick y1-3, weak wood point at z=9, y1-2
##            This is the efficient shortcut. The long way is around z=20+.
##   z 10-16: GUARD OFFICE (x 2-8, walls y1-3, roof y4)
##            Walls: y1 brick, y2-3 wood. Entrance west x=2, gap z=13, y1-2
##            Keycard (cyan) inside at (5,1,13)
##   z 10-20: FENCED PARKING LOT (x -10 to -1, fence wood y=1)
##            Gate east x=0, gap z=14-15. Player + vehicle start here.
##   z 14-18: ESCAPE ZONE (x 24-28, green floor markers) - drive here to win.
##
## Path logic for the player:
##  Parking -> gate -> guard office -> grab keycard -> break barrier
##  (or go the long way south) -> warehouse entrance -> break wood door
##  (or blow up metal divider) -> touch vault (now unlocked) -> alarm
##  -> get in vehicle in parking lot -> drive to escape zone.
## Note: after the alarm starts, the player must run/drive back to the
## parking lot vehicle, which is a deliberate backtrack. That is the
## heist tension in v0.3. A vehicle parked closer to the warehouse
## is a v0.4 balance option.

static func _floor_rect(world: VoxelWorld, x0: int, x1: int, z0: int, z1: int, voxel_type: String = "floor") -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			world.add_voxel(Vector3i(x, 0, z), voxel_type)

static func build(world: VoxelWorld) -> Dictionary:
	# --- Floors ---
	_floor_rect(world, -10, -1, 10, 20)  # parking lot
	_floor_rect(world, 0, 1, 12, 16)  # path parking -> guard
	_floor_rect(world, 3, 7, 11, 15)  # guard interior
	_floor_rect(world, 9, 11, 8, 12)  # path guard -> barrier -> warehouse
	_floor_rect(world, 13, 21, 1, 9)  # warehouse interior
	_floor_rect(world, 24, 28, 14, 18, "escape")  # escape zone markers
	_floor_rect(world, 9, 23, 19, 20)  # long way south around the barrier

	# --- Fenced parking lot: wood fence y=1, gate at east x=0, z=14-15 ---
	for z in range(10, 21):
		if z == 14 or z == 15:
			continue
		world.add_voxel(Vector3i(0, 1, z), "wood")
		world.add_voxel(Vector3i(-10, 1, z), "wood")
	for x in range(-10, 1):
		world.add_voxel(Vector3i(x, 1, 10), "wood")
		world.add_voxel(Vector3i(x, 1, 20), "wood")

	# --- Guard office: x 2-8, z 10-16, y1 brick, y2-3 wood, roof y4 ---
	for y in range(1, 4):
		var mat := "brick" if y == 1 else "wood"
		for x in range(2, 9):
			world.add_voxel(Vector3i(x, y, 10), mat)
			world.add_voxel(Vector3i(x, y, 16), mat)
		# Entrance: west wall x=2, z=13, y1-2 gap (handled below).
		for z in range(11, 16):
			if not (z == 13 and y <= 2):
				world.add_voxel(Vector3i(2, y, z), mat)
			world.add_voxel(Vector3i(8, y, z), mat)
	for x in range(2, 9):
		for z in range(10, 17):
			world.add_voxel(Vector3i(x, 4, z), "wood")
	# Keycard inside the guard office.
	var keycard_pos := Vector3i(5, 1, 13)
	world.add_voxel(keycard_pos, "keycard")

	# --- Barrier wall: x=10, z 4-14, y1-3 brick, weak wood at z=9 ---
	for y in range(1, 4):
		for z in range(4, 15):
			if z == 9 and y <= 2:
				world.add_voxel(Vector3i(10, y, z), "wood")
			else:
				world.add_voxel(Vector3i(10, y, z), "brick")

	# --- Warehouse: x 12-22, z 0-10, walls y1-6 brick, roof y7 ---
	for y in range(1, 7):
		for x in range(12, 23):
			world.add_voxel(Vector3i(x, y, 0), "brick")
			world.add_voxel(Vector3i(x, y, 10), "brick")
		for z in range(1, 10):
			# Entrance: west wall x=12, z=5, y1-2 gap.
			if not (z == 5 and y <= 2):
				world.add_voxel(Vector3i(12, y, z), "brick")
			world.add_voxel(Vector3i(22, y, z), "brick")
	for x in range(12, 23):
		for z in range(0, 11):
			world.add_voxel(Vector3i(x, 7, z), "brick")
	# Vault room divider: x=19, z 0-10, y1-6 metal, wood door at z=5, y1-2.
	for y in range(1, 7):
		for z in range(0, 11):
			if z == 5 and y <= 2:
				world.add_voxel(Vector3i(19, y, z), "wood")
			else:
				world.add_voxel(Vector3i(19, y, z), "metal")
	# Metal pillars around the vault for readability.
	for pos in [Vector3i(20, 2, 4), Vector3i(20, 2, 6)]:
		world.add_voxel(pos, "metal")
	var vault_pos := Vector3i(20, 1, 5)
	world.add_voxel(vault_pos, "vault")

	return {
		"vault_world_pos": Vector3(vault_pos) + Vector3(0.5, 0.5, 0.5),
		"keycard_world_pos": Vector3(keycard_pos) + Vector3(0.5, 0.5, 0.5),
		"vehicle_start": Vector3(-5.0, 1.0, 15.0),
		"escape_zone": Vector3(26.0, 1.0, 16.0),
		"player_start": Vector3(-5.0, 2.0, 18.0),
	}
