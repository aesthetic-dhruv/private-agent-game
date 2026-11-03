extends CharacterBody3D
class_name EscapeVehicle
## Drivable escape vehicle, v0.2. Deliberately NOT VehicleBody3D in v0.2:
## VehicleBody3D + 4 wheels is heavier to tune on mobile and, on its own,
## does not ram through StaticBody voxels - it just stops at them.
## This controller is a CharacterBody3D car:
## - Joystick Y = throttle / reverse, Joystick X = steering.
## - Speed builds with acceleration and decays with friction, so it feels
##   like driving, not like sliding a box.
## - Ramming: while moving fast, voxels directly in front of the car are
##   damaged through VoxelWorld. Wood/brick break, metal blocks the car.
## - The car is a simple box body + 4 wheel boxes, no external model needed.
## A VehicleBody3D upgrade is a later milestone, after this loop is proven
## fun on a real phone.

signal rammed_voxel(grid_pos: Vector3i)

@export var max_speed: float = 12.0
@export var acceleration: float = 8.0
@export var steer_rate: float = 1.8

var world: VoxelWorld = null
var joystick_vector: Vector2 = Vector2.ZERO
var speed: float = 0.0
var active: bool = false

func _ready() -> void:
	var body_mesh := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(2.0, 0.8, 3.5)
	body_mesh.mesh = body_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.45, 0.85)
	body_mesh.material_override = mat
	body_mesh.position = Vector3(0, 0.7, 0)
	add_child(body_mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 3.5)
	shape.shape = box
	shape.position = Vector3(0, 0.7, 0)
	add_child(shape)
	# 4 wheel visuals, no separate physics bodies.
	for wx in [-0.9, 0.9]:
		for wz in [-1.2, 1.2]:
			var wheel := MeshInstance3D.new()
			var wheel_box := BoxMesh.new()
			wheel_box.size = Vector3(0.3, 0.6, 0.6)
			wheel.mesh = wheel_box
			wheel.position = Vector3(wx, 0.3, wz)
			add_child(wheel)

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	# Steering: only effective while moving, like a real car.
	var steer := -joystick_vector.x
	if absf(speed) > 0.5:
		rotation.y += steer * steer_rate * delta * signf(speed)
	# Throttle: joystick up (negative Y in our joystick mapping) = forward.
	var throttle := -joystick_vector.y
	speed += throttle * acceleration * delta
	speed = clamp(speed, -max_speed * 0.5, max_speed)
	# Friction when no throttle.
	if absf(throttle) < 0.1:
		speed = move_toward(speed, 0.0, 4.0 * delta)
	var forward := -global_transform.basis.z
	velocity = forward * speed
	velocity.y = 0.0
	move_and_slide()
	_ram_check()

func _ram_check() -> void:
	if world == null or absf(speed) < 3.0:
		return
	# Check the 3 voxels directly in front of the car.
	var forward := -global_transform.basis.z
	var front := global_position + forward * 2.0
	var grid := Vector3i(
		floori(front.x / world.voxel_size),
		floori(front.y / world.voxel_size),
		floori(front.z / world.voxel_size)
	)
	for dy in [0, 1]:
		var pos := grid + Vector3i(0, dy, 0)
		if world.voxels.has(pos):
			var t: String = str(world.voxels[pos].get_meta("voxel_type"))
			if t == "metal" or t == "vault" or t == "floor":
				# Metal stops the car: hard stop, no destruction.
				speed = 0.0
				return
			# Ram damage counts as an explosive-strength hit for wood/brick,
			# so a fast car breaks through a wall instead of bouncing off it.
			world.damage_voxel(pos, 1)
			rammed_voxel.emit(pos)
			return
