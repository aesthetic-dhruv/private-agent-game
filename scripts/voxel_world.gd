extends Node3D
class_name VoxelWorld
## v0.2 destructible voxel system.
## Voxel types and hammer rules:
## - wood: 1 hammer hit. Crates and interior divider.
## - brick: 2 hammer hits. Main walls and roof.
## - metal: hammer-proof. Only explosives destroy it. Vault surround.
## - vault: special objective, indestructible in v0.2 (touch it to start alarm).
## - floor: visual ground voxels, indestructible (the ground plane stays).
## - vehicle: no longer used as a voxel in v0.2, the escape vehicle is a
##   separate EscapeVehicle node. Kept in the material table for backwards
##   compatibility with old test maps.
## Floating rule: after any destruction, a flood-fill from the floor
## (y == 0) marks every connected voxel. Any voxel not reached has lost
## all support, so it is converted to a falling debris body instead of
## vanishing in place.

signal voxel_destroyed(grid_pos: Vector3i, voxel_type: String)
signal voxel_damaged(grid_pos: Vector3i, voxel_type: String, hits_left: int)
signal voxel_blocked(grid_pos: Vector3i, voxel_type: String)

@export var voxel_size: float = 1.0

var voxels: Dictionary = {}  # Vector3i -> Node3D
var health: Dictionary = {}  # Vector3i -> int hits left (metal/vault/floor = -1)
var _box_mesh: BoxMesh = null
var _materials: Dictionary = {}

const TYPE_HITS: Dictionary = {
	"wood": 1, "crate": 1, "brick": 2, "wall": 2,
	"metal": -1, "vault": -1, "floor": -1, "vehicle": -1,
	"keycard": -1, "escape": -1,
}

func _ready() -> void:
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3(voxel_size, voxel_size, voxel_size)
	_materials = {
		"wood": _make_material(Color(0.65, 0.45, 0.22)),
		"crate": _make_material(Color(0.65, 0.45, 0.22)),
		"brick": _make_material(Color(0.62, 0.42, 0.38)),
		"wall": _make_material(Color(0.62, 0.42, 0.38)),
		"metal": _make_material(Color(0.35, 0.38, 0.42)),
		"vault": _make_material(Color(0.85, 0.70, 0.15)),
		"floor": _make_material(Color(0.45, 0.45, 0.48)),
		"keycard": _make_material(Color(0.2, 0.85, 0.9)),
		"escape": _make_material(Color(0.25, 0.85, 0.35)),
		"vehicle": _make_material(Color(0.15, 0.45, 0.85)),
		"glass": _make_material(Color(0.55, 0.80, 0.90)),
	}

func _make_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m

func add_voxel(grid_pos: Vector3i, voxel_type: String) -> Node3D:
	if voxels.has(grid_pos):
		return voxels[grid_pos]
	var root := Node3D.new()
	root.position = Vector3(grid_pos) * voxel_size + Vector3(0.5, 0.5, 0.5) * voxel_size
	root.set_meta("grid_pos", grid_pos)
	root.set_meta("voxel_type", voxel_type)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh
	mesh.material_override = _materials.get(voxel_type, _materials["brick"])
	root.add_child(mesh)
	if voxel_type != "floor" and voxel_type != "keycard" and voxel_type != "escape":
		var body := StaticBody3D.new()
		body.set_meta("grid_pos", grid_pos)
		body.set_meta("voxel_type", voxel_type)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(voxel_size, voxel_size, voxel_size)
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
	add_child(root)
	voxels[grid_pos] = root
	health[grid_pos] = TYPE_HITS.get(voxel_type, 1)
	return root

func _remove_voxel_node(grid_pos: Vector3i) -> String:
	var node: Node3D = voxels[grid_pos]
	var voxel_type: String = str(node.get_meta("voxel_type"))
	voxels.erase(grid_pos)
	health.erase(grid_pos)
	node.queue_free()
	return voxel_type

func destroy_voxel(grid_pos: Vector3i, spawn_effects: bool = true) -> bool:
	if not voxels.has(grid_pos):
		return false
	var node: Node3D = voxels[grid_pos]
	var pos: Vector3 = node.position
	var voxel_type: String = str(node.get_meta("voxel_type"))
	_remove_voxel_node(grid_pos)
	voxel_destroyed.emit(grid_pos, voxel_type)
	if spawn_effects:
		DestructionEffects.spawn_burst(self, pos, _materials.get(voxel_type, _materials["brick"]))
	return true

## Damage with a tool. Returns: 2 = destroyed, 1 = damaged, 0 = blocked/no voxel.
func damage_voxel(grid_pos: Vector3i, tool: int) -> int:
	# tool: 0 = hammer, 1 = explosive
	if not voxels.has(grid_pos):
		return 0
	var voxel_type: String = str(voxels[grid_pos].get_meta("voxel_type"))
	if voxel_type == "floor" or voxel_type == "vault" or voxel_type == "keycard" or voxel_type == "escape":
		voxel_blocked.emit(grid_pos, voxel_type)
		return 0
	if tool == 1:
		# Explosives destroy brick, wood and metal in one blast.
		destroy_voxel(grid_pos)
		check_floating()
		return 2
	# Hammer path.
	if voxel_type == "metal":
		voxel_blocked.emit(grid_pos, voxel_type)
		return 0
	var hits: int = health.get(grid_pos, 1)
	hits -= 1
	health[grid_pos] = hits
	if hits <= 0:
		destroy_voxel(grid_pos)
		check_floating()
		return 2
	voxel_damaged.emit(grid_pos, voxel_type, hits)
	return 1

func destroy_at_world_point(point: Vector3, tool: int = 0) -> int:
	var grid_pos := Vector3i(
		floori(point.x / voxel_size),
		floori(point.y / voxel_size),
		floori(point.z / voxel_size)
	)
	return damage_voxel(grid_pos, tool)

func hammer_hit(point: Vector3) -> int:
	return destroy_at_world_point(point, 0)

func explode(centre: Vector3, radius: float = 3.0) -> int:
	var destroyed := 0
	var r := int(ceili(radius))
	var centre_grid := Vector3i(
		floori(centre.x / voxel_size),
		floori(centre.y / voxel_size),
		floori(centre.z / voxel_size)
	)
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var pos := centre_grid + Vector3i(x, y, z)
				var world := Vector3(pos) * voxel_size
				if world.distance_to(centre) <= radius * voxel_size:
					if voxels.has(pos):
						var t: String = str(voxels[pos].get_meta("voxel_type"))
						if t != "floor" and t != "vault" and t != "keycard" and t != "escape":
							if destroy_voxel(pos, false):
								destroyed += 1
	if destroyed > 0:
		DestructionEffects.spawn_burst(self, centre, _materials["brick"])
		check_floating()
	return destroyed

func check_floating() -> void:
	# Flood-fill from every floor voxel (y == 0).
	var connected: Dictionary = {}
	var queue: Array[Vector3i] = []
	for pos in voxels.keys():
		if pos.y == 0:
			connected[pos] = true
			queue.append(pos)
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		for d in dirs:
			var nxt := cur + d
			if voxels.has(nxt) and not connected.has(nxt):
				connected[nxt] = true
				queue.append(nxt)
	# Anything not connected and above the floor is now falling debris.
	# Collect first, then convert, so we do not mutate the dict while iterating.
	var floating: Array[Vector3i] = []
	for pos in voxels.keys():
		if pos.y > 0 and not connected.has(pos):
			floating.append(pos)
	for pos in floating:
		_make_falling(pos)

func _make_falling(grid_pos: Vector3i) -> void:
	if not voxels.has(grid_pos):
		return
	var node: Node3D = voxels[grid_pos]
	var pos: Vector3 = node.position
	var voxel_type: String = str(node.get_meta("voxel_type"))
	var mat: Material = _materials.get(voxel_type, _materials["brick"])
	voxels.erase(grid_pos)
	health.erase(grid_pos)
	node.queue_free()
	var body := RigidBody3D.new()
	body.position = pos
	body.mass = 1.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(voxel_size, voxel_size, voxel_size)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	DestructionEffects.register_effect(body)
	body.linear_velocity = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	# Debris cleans itself up after 3 seconds, so falling voxels do not pile up.
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func(): DestructionEffects.unregister_effect(body); if is_instance_valid(body): body.queue_free())

func voxel_count() -> int:
	return voxels.size()

func clear_all() -> void:
	for node in voxels.values():
		(node as Node3D).queue_free()
	voxels.clear()
	health.clear()
