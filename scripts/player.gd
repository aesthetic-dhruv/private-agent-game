extends CharacterBody3D
class_name Player
## First-person player for phone + keyboard fallback.
## Movement: joystick vector (from TouchUI) or WASD on desktop.
## Camera: drag on the right half of the screen, or mouse on desktop.
## Tools: 0 = sledgehammer (1 voxel), 1 = explosive (radius 3, placed
## at the aimed point and detonated immediately in this prototype).
## Driving: only when GameManager says the player is near the escape
## vehicle and presses Drive. Driving is deliberately simple in v0.1:
## the same joystick steers, speed is higher, and the player body is
## hidden while the vehicle block is the visual focus. Full VehicleBody3D
## physics is a later milestone, not faked as done here.

signal attacked(point: Vector3, tool: int)
signal tool_changed(tool: int)

@export var walk_speed: float = 5.0
@export var drive_speed: float = 10.0
@export var mouse_sensitivity: float = 0.003

var joystick_vector: Vector2 = Vector2.ZERO
var camera_yaw: float = 0.0
var camera_pitch: float = -0.25
var current_tool: int = 0  # 0 hammer, 1 explosive
var driving: bool = false

var _camera: Camera3D = null
var _pivot: Node3D = null
var _space_state: PhysicsDirectSpaceState3D = null

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.6, 0)
	_pivot.add_child(_camera)
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	body_shape.shape = capsule
	add_child(body_shape)

func _process(_delta: float) -> void:
	# Camera rotation must not depend on _physics_process running:
	# if physics is ever disabled, rotate_camera() still updates the
	# pivot visually on the next rendered frame.
	if _pivot != null:
		_pivot.rotation.y = camera_yaw
		_pivot.rotation.x = camera_pitch

func _physics_process(delta: float) -> void:
	if driving:
		# While driving, GameManager snaps the player to the vehicle and
		# the vehicle takes the joystick input. Do not walk at the same time.
		velocity = Vector3.ZERO
		_pivot.rotation.y = camera_yaw
		_pivot.rotation.x = camera_pitch
		return
	var input_dir := joystick_vector
	if input_dir == Vector2.ZERO:
		input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
	# Convert 2D input to camera-relative 3D movement.
	var forward := -_pivot.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := _pivot.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var move := (forward * -input_dir.y) + (right * input_dir.x)
	if move.length() > 1.0:
		move = move.normalized()
	var speed := drive_speed if driving else walk_speed
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	velocity.y -= 20.0 * delta
	move_and_slide()
	_pivot.rotation.y = camera_yaw
	_pivot.rotation.x = camera_pitch

func rotate_camera(delta_x: float, delta_y: float) -> void:
	camera_yaw -= delta_x * mouse_sensitivity * 10.0
	camera_pitch = clamp(camera_pitch - delta_y * mouse_sensitivity * 10.0, -1.2, 1.2)

func attack() -> void:
	if _camera == null:
		return
	_space_state = get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from + -_camera.global_transform.basis.z * 4.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := _space_state.intersect_ray(query)
	if hit.is_empty():
		return
	attacked.emit(hit["position"], current_tool)

func switch_tool() -> void:
	current_tool = 1 if current_tool == 0 else 0
	tool_changed.emit(current_tool)

func tool_name() -> String:
	return "Sledgehammer" if current_tool == 0 else "Explosive"
