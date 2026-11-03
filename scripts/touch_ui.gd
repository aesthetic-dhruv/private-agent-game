extends CanvasLayer
class_name TouchUI
## v0.3.2 touch UI — clean CanvasLayer fix.
## Why the old UI could be invisible / unresponsive:
## - Buttons were direct children of the CanvasLayer, with fixed
##   1280x720 coordinates. On a phone with a different viewport size
##   those buttons could be off-screen, and there was no root Control
##   to anchor them to the viewport.
## - The joystick was an invisible Control (no drawing at all), so
##   the user saw no joystick even when touch input worked.
## - A full-rect Control with STOP mouse_filter can swallow touches.
## Fix in this version:
## - CanvasLayer.layer = 10, explicitly visible, added by GameManager
##   as a top-level layer (scene root), not nested under a 3D node.
## - One root Control, full-rect, mouse_filter IGNORE, so it never
##   blocks touches. All labels/buttons are children of that root,
##   positioned from the actual viewport size at _ready time, so
##   buttons are always on-screen on any phone aspect ratio.
## - Visible joystick: a semi-transparent base + a knob that follows
##   player.joystick_vector in _process, so the joystick is seen
##   even before any touch.
## - Labels are mouse_filter IGNORE; only real Buttons keep STOP.

var player: Player = null
var game_manager: Node3D = null

var _root: Control = null
var _phase_label: Label = null
var _timer_label: Label = null
var _tool_label: Label = null
var _progress_label: Label = null
var _victory_panel: PanelContainer = null
var _gameover_panel: PanelContainer = null
var _joystick_base: ColorRect = null
var _joystick_knob: ColorRect = null
var _joystick_centre: Vector2 = Vector2.ZERO
var _joystick_touch_id: int = -1
var _joystick_drag_centre: Vector2 = Vector2.ZERO
var _camera_touch_id: int = -1
var _last_camera_pos: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2(1280, 720)

func _ready() -> void:
	# Top-level, always-on-top layer. This is set here as well as
	# in GameManager, so the layer is correct even if TouchUI is
	# ever instantiated another way.
	layer = 10
	visible = true
	set_process_input(true)
	set_process(true)
	_viewport_size = get_viewport().get_visible_rect().size
	if _viewport_size.x <= 0 or _viewport_size.y <= 0:
		_viewport_size = Vector2(1280, 720)
	# Root Control: full viewport, never blocks input.
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var vp := _viewport_size
	_joystick_centre = Vector2(110, vp.y - 110)
	_phase_label = _make_label(Vector2(20, 10), "SETUP", 24)
	_timer_label = _make_label(Vector2(vp.x / 2.0 - 40, 10), "", 48)
	_tool_label = _make_label(Vector2(20, 70), "Sledgehammer", 24)
	_progress_label = _make_label(Vector2(max(20.0, vp.x - 380), 10), "Keycard: Missing\nVault: Locked", 24)
	# Visible joystick base + knob (ColorRects, mouse_filter IGNORE
	# so they never swallow the drag that TouchUI._input handles).
	_joystick_base = ColorRect.new()
	_joystick_base.color = Color(1, 1, 1, 0.25)
	_joystick_base.position = _joystick_centre - Vector2(70, 70)
	_joystick_base.size = Vector2(140, 140)
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_joystick_base)
	_joystick_knob = ColorRect.new()
	_joystick_knob.color = Color(1, 1, 1, 0.7)
	_joystick_knob.position = _joystick_centre - Vector2(30, 30)
	_joystick_knob.size = Vector2(60, 60)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_joystick_knob)
	# Buttons, positioned from the viewport size (right side, bottom).
	_make_button("ATTACK", Vector2(vp.x - 180, vp.y - 100), func(): _on_attack())
	_make_button("TOOL", Vector2(vp.x - 330, vp.y - 100), func(): _on_tool())
	_make_button("DRIVE", Vector2(vp.x - 180, vp.y - 200), func(): _on_drive())
	_make_button("RESTART", Vector2(vp.x - 330, vp.y - 200), func(): _on_restart())
	_victory_panel = _make_end_panel("VICTORY!\nYou escaped with the loot.")
	_gameover_panel = _make_end_panel("GAME OVER\nThe alarm timer ran out.")

func _process(_delta: float) -> void:
	# Keep the visible joystick knob in sync with the input vector,
	# even if physics is ever paused — camera/joystick visuals must
	# not depend on _physics_process running.
	if _joystick_knob != null and player != null:
		_joystick_knob.position = _joystick_centre - Vector2(30, 30) + player.joystick_vector * 40.0

func _make_label(pos: Vector2, text: String, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func _make_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(130, 60)
	# Buttons keep the default STOP filter: they must receive taps.
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(callback)
	_root.add_child(b)
	return b

func _make_end_panel(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	# The panel itself must not block touches when it is shown;
	# its RESTART button inside still receives taps.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)
	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(200, 60)
	restart.mouse_filter = Control.MOUSE_FILTER_STOP
	restart.pressed.connect(func(): _on_restart())
	vbox.add_child(restart)
	panel.add_child(vbox)
	_root.add_child(panel)
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
			_joystick_drag_centre = event.position
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
			# v0.3.3 parse fix: do NOT use := here. event is typed
			# as InputEvent, which has no position property, so the
			# compiler treats event.position as Variant and := fails
			# with "Cannot infer the type". Explicit Vector2 type
			# fixes it, and this was the real reason TouchUI never
			# loaded, GameManager._ready aborted at TouchUI.new(),
			# and no UI buttons ever appeared on the phone.
			var delta_vec: Vector2 = event.position - _joystick_drag_centre
			if delta_vec.length() > 60:
				delta_vec = delta_vec.normalized() * 60
			player.joystick_vector = delta_vec / 60.0
		elif event.index == _camera_touch_id and player != null:
			# Same parse fix as delta_vec above: explicit Vector2,
			# never :=, for event.position on a base InputEvent.
			var drag_delta: Vector2 = event.position - _last_camera_pos
			_last_camera_pos = event.position
			player.rotate_camera(drag_delta.x, drag_delta.y)
