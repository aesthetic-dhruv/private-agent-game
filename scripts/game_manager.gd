extends Node3D
## v0.3 main controller - mini-town, multi-objective heist.
## Order of play (progress tracker shows this at all times):
##  1) Start in the fenced parking lot.
##  2) Go to the guard office, grab the Security Keycard (cyan voxel).
##  3) Carve a path to the warehouse: break the brick barrier wall
##     (or take the long way south), then break the wood door in the
##     metal vault divider (or blow up the metal with explosives).
##  4) Touch the gold Vault. Only now, with the keycard, does the
##     60-second alarm start. Without the keycard the vault stays Locked
##     and no timer starts.
##  5) Run back to the parking lot vehicle, DRIVE, and drive to the
##     green escape zone before the timer hits zero.
## Phases are the same as v0.2: SETUP, ALARM, WIN, LOSE.

enum Phase { SETUP, ALARM, WIN, LOSE }

@export var alarm_seconds: float = 60.0

var phase: Phase = Phase.SETUP
var time_left: float = 0.0
var world: VoxelWorld = null
var player: Player = null
var vehicle: EscapeVehicle = null
var ui: TouchUI = null
var audio: AudioManager = null
var vault_pos: Vector3 = Vector3.ZERO
var keycard_pos: Vector3 = Vector3.ZERO
var vehicle_start: Vector3 = Vector3.ZERO
var escape_zone: Vector3 = Vector3.ZERO
var has_keycard: bool = false
var driving: bool = false
var _alarm_timer: float = 0.0
var _vault_locked_notice: bool = false

func _ready() -> void:
	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	var markers := TestMapBuilder.build(world)
	vault_pos = markers["vault_world_pos"]
	keycard_pos = markers["keycard_world_pos"]
	vehicle_start = markers["vehicle_start"]
	escape_zone = markers["escape_zone"]
	player = Player.new()
	player.name = "Player"
	player.position = markers["player_start"]
	add_child(player)
	player.attacked.connect(_on_player_attacked)
	vehicle = EscapeVehicle.new()
	vehicle.name = "EscapeVehicle"
	vehicle.position = vehicle_start
	vehicle.world = world
	add_child(vehicle)
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	ui = TouchUI.new()
	ui.name = "TouchUI"
	add_child(ui)
	ui.player = player
	ui.game_manager = self
	world.voxel_destroyed.connect(_on_voxel_destroyed)
	world.voxel_blocked.connect(_on_voxel_blocked)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	ground_shape.shape = plane
	ground.add_child(ground_shape)
	add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2
	add_child(light)
	_update_ui()

func _process(delta: float) -> void:
	if phase == Phase.ALARM:
		time_left -= delta
		_alarm_timer -= delta
		if _alarm_timer <= 0.0:
			_alarm_timer = 0.6
			if audio != null:
				audio.alarm_tick()
		if time_left <= 0.0:
			time_left = 0.0
			phase = Phase.LOSE
			_update_ui()
			return
		_update_ui()
	if player == null:
		return
	if driving and vehicle != null:
		vehicle.joystick_vector = player.joystick_vector
		vehicle.position.y = 1.0
		player.global_position = vehicle.global_position + Vector3(0, 1.5, 0)
	# Keycard pickup: proximity only, in SETUP (and ALARM as a safety net).
	if not has_keycard and player.global_position.distance_to(keycard_pos) < 2.0:
		has_keycard = true
		# Remove the keycard voxel so it cannot be collected twice.
		world.destroy_voxel(Vector3i(5, 1, 13), false)
		_update_ui()
	# Vault: locked until the keycard is found.
	if phase == Phase.SETUP and player.global_position.distance_to(vault_pos) < 2.0:
		if has_keycard:
			phase = Phase.ALARM
			time_left = alarm_seconds
			_alarm_timer = 0.0
			_update_ui()
		elif not _vault_locked_notice:
			_vault_locked_notice = true
			_update_ui()
			# Clear the locked notice after 3 seconds so the phase label
			# goes back to the normal setup text.
			var timer := get_tree().create_timer(3.0)
			timer.timeout.connect(func(): _vault_locked_notice = false; _update_ui())
	elif phase == Phase.ALARM and driving and vehicle != null:
		if vehicle.global_position.distance_to(escape_zone) < 4.0:
			phase = Phase.WIN
			vehicle.active = false
			_update_ui()

func _on_player_attacked(point: Vector3, tool: int) -> void:
	if world == null or driving:
		return
	if tool == 0:
		world.hammer_hit(point)
	else:
		world.explode(point, 3.0)

func _on_voxel_destroyed(_grid_pos: Vector3i, _voxel_type: String) -> void:
	if audio != null:
		audio.play_break()

func _on_voxel_blocked(_grid_pos: Vector3i, _voxel_type: String) -> void:
	pass

func toggle_drive() -> bool:
	if vehicle == null or player == null:
		return false
	if driving:
		return true
	if player.global_position.distance_to(vehicle.global_position) < 5.0:
		driving = true
		vehicle.active = true
		player.visible = false
		player.driving = true
		_update_ui()
		return true
	return false

func restart() -> void:
	if world != null:
		world.clear_all()
		var markers := TestMapBuilder.build(world)
		vault_pos = markers["vault_world_pos"]
		keycard_pos = markers["keycard_world_pos"]
		vehicle_start = markers["vehicle_start"]
		escape_zone = markers["escape_zone"]
		player.position = markers["player_start"]
		player.visible = true
		player.driving = false
		if vehicle != null:
			vehicle.position = vehicle_start
			vehicle.rotation.y = 0.0
			vehicle.speed = 0.0
			vehicle.active = false
	has_keycard = false
	driving = false
	_vault_locked_notice = false
	phase = Phase.SETUP
	time_left = 0.0
	_update_ui()

func phase_text() -> String:
	if _vault_locked_notice:
		return "VAULT LOCKED - Find the Keycard in the guard office first!"
	match phase:
		Phase.SETUP:
			if has_keycard:
				return "SETUP - Keycard found! Go to the warehouse Vault."
			return "SETUP - Get the Keycard from the guard office first."
		Phase.ALARM:
			if driving:
				return "ALARM! Drive to the green escape zone!"
			return "ALARM! Get in the parking lot vehicle, then drive to safety!"
		Phase.WIN:
			return "VICTORY - You escaped!"
		Phase.LOSE:
			return "GAME OVER - Time ran out."
	return ""

func _update_ui() -> void:
	if ui != null:
		ui.update_state(phase_text(), time_left, player.tool_name() if player != null else "", phase, driving, has_keycard)
