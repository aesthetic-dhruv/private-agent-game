extends CanvasLayer
class_name TouchUI
## v0.2 touch UI.
## - Top centre: large countdown timer, red and large during ALARM.
##   It is a plain Label with a large font size, not a small HUD line.
## - Victory / Game Over: full-screen panels with a label and a Restart
##   button. They are hidden in SETUP and ALARM and only shown on WIN/LOSE.
## - Joystick, camera drag, ATTACK / TOOL / DRIVE / RESTART as in v0.1.
## DRIVE in v0.2 calls GameManager.toggle_drive(), which is the real
##   enter-vehicle action, not a cosmetic toggle.

var player: Player = null
var game_manager: Node3D = null

var _phase_label: Label = null
var _timer_label: Label = null
var _tool_label: Label = null
var _progress_label: Label = null
var _victory_panel: PanelContainer = null
var _gameover_panel: PanelContainer = null
var _joystick_touch_id: int = -1
var _joystick_centre: Vector2 = Vector2.ZERO
var _camera_touch_id: int = -1
var _last_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_phase_label = _make_label(Vector2(20, 10), "SETUP", 24)
	_timer_label = _make_label(Vector2(500, 10), "", 48)
	_tool_label = _make_label(Vector2(20, 70), "Sledgehammer", 24)
	_progress_label = _make_label(Vector2(900, 10), "Keycard: Missing\nVault: Locked", 24)
	_make_circle(Vector2(110, 620), 70)
	_make_button("ATTACK", Vector2(1050, 620), func(): _on_attack())
	_make_button("TOOL", Vector2(900, 620), func(): _on_tool())
	_make_button("DRIVE", Vector2(1050, 520), func(): _on_drive())
	_make_button("RESTART", Vector2(900, 520), func(): _on_restart())
	_victory_panel = _make_end_panel("VICTORY!\nYou escaped with the loot.")
	_gameover_panel = _make_end_panel("GAME OVER\nThe alarm timer ran out.")

func _make_label(pos: Vector2, text: String, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label

func _make_circle(pos: Vector2, radius: float) -> Control:
	var c := Control.new()
	c.position = pos - Vector2(radius, radius)
	c.size = Vector2(radius * 2, radius * 2)
	add_child(c)
	return c

func _make_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(130, 60)
	b.pressed.connect(callback)
	add_child(b)
	return b

func _make_end_panel(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(label)
	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(200, 60)
	restart.pressed.connect(func(): _on_restart())
	vbox.add_child(restart)
	panel.add_child(vbox)
	add_child(panel)
	return panel

## Backwards-compatible aliases for v0.1 / v0.2 callers.
func update_labels(phase_text: String, time_left: float, tool_name: String) -> void:
	update_state(phase_text, time_left, tool_name, 0, false, false)

func update_state(phase_text: String, time_left: float, tool_name: String, phase: int, driving: bool, has_keycard: bool = false) -> void:
	if _phase_label != null:
		_phase_label.text = phase_text
	if _timer_label != null:
		if time_left > 0:
			_timer_label.text = "%d" % int(ceili(time_left))
			# Red when the alarm is urgent, white otherwise.
			if time_left <= 10:
				_timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
			else:
				_timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			_timer_label.text = ""
	if _tool_label != null:
		_tool_label.text = "Tool: " + tool_name + (" | DRIVING" if driving else "")
	if _progress_label != null:
		var keycard_text := "Found" if has_keycard else "Missing"
		var vault_text := "Ready" if has_keycard else "Locked"
		_progress_label.text = "Keycard: " + keycard_text + "\nVault: " + vault_text
	if _victory_panel != null:
		_victory_panel.visible = (phase == 2)
	if _gameover_panel != null:
		_gameover_panel.visible = (phase == 3)

func _on_attack() -> void:
	if player != null:
		player.attack()

func _on_tool() -> void:
	if player != null:
		player.switch_tool()
		if game_manager != null and game_manager.has_method("_update_ui"):
			game_manager.call("_update_ui")

func _on_drive() -> void:
	if game_manager != null and game_manager.has_method("toggle_drive"):
		game_manager.call("toggle_drive")

func _on_restart() -> void:
	if game_manager != null and game_manager.has_method("restart"):
		game_manager.call("restart")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < 400 and _joystick_touch_id == -1:
			_joystick_touch_id = event.index
			_joystick_centre = event.position
		elif not event.pressed and event.index == _joystick_touch_id:
			_joystick_touch_id = -1
			if player != null:
				player.joystick_vector = Vector2.ZERO
		elif event.pressed and event.position.x >= 400 and _camera_touch_id == -1:
			_camera_touch_id = event.index
			_last_camera_pos = event.position
		elif not event.pressed and event.index == _camera_touch_id:
			_camera_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_id and player != null:
			var delta_vec := event.position - _joystick_centre
			if delta_vec.length() > 60:
				delta_vec = delta_vec.normalized() * 60
			player.joystick_vector = delta_vec / 60.0
		elif event.index == _camera_touch_id and player != null:
			var drag_delta := event.position - _last_camera_pos
			_last_camera_pos = event.position
			player.rotate_camera(drag_delta.x, drag_delta.y)
