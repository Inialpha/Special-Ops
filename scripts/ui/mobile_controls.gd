extends CanvasLayer
class_name MobileControls

const ACTION_BUTTON_GROUP := "mobile_action_buttons"

var player: Player
@onready var controls: Control = $Controls
@onready var pause_button: Button = $Pause
var aim_touch_index := -1
var gameplay_visible := false

func _ready() -> void:
	controls.mouse_filter = Control.MOUSE_FILTER_PASS
	_configure_action_buttons()
	pause_button.pressed.connect(_toggle_pause)
	_layout_controls()
	get_viewport().size_changed.connect(_layout_controls)

func bind_player(value: Player) -> void:
	player = value

func show_gameplay() -> void:
	gameplay_visible = true
	controls.visible = true
	pause_button.visible = true
	_layout_controls()

func hide_gameplay() -> void:
	gameplay_visible = false
	controls.visible = false
	pause_button.visible = false
	_release_all_actions()
	aim_touch_index = -1

func _configure_action_buttons() -> void:
	for button in get_tree().get_nodes_in_group(ACTION_BUTTON_GROUP):
		if not button is Button:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_NONE
		var action := str(button.get_meta("action", ""))
		if action == "shoot":
			button.button_down.connect(_on_shoot_down)
		elif action == "reload":
			button.pressed.connect(_on_reload_pressed)
		else:
			button.button_down.connect(_press_action.bind(action))
			button.button_up.connect(_release_action.bind(action))

func _layout_controls() -> void:
	_set_control_rect("Forward", 0.0, 1.0, 110, -210, 210, -150)
	_set_control_rect("Back", 0.0, 1.0, 110, -75, 210, -15)
	_set_control_rect("Left", 0.0, 1.0, 15, -145, 105, -85)
	_set_control_rect("Right", 0.0, 1.0, 215, -145, 305, -85)
	_set_control_rect("Sprint", 0.0, 1.0, 15, -275, 115, -220)
	_set_control_rect("Crouch", 0.0, 1.0, 225, -275, 335, -220)
	_set_control_rect("Fire", 1.0, 1.0, -215, -205, -25, -25)
	_set_control_rect("Reload", 1.0, 1.0, -345, -115, -225, -55)
	if pause_button:
		pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pause_button.offset_left = -86
		pause_button.offset_top = 24
		pause_button.offset_right = -20
		pause_button.offset_bottom = 84

func _set_control_rect(node_name: String, anchor_x: float, anchor_y: float, left: float, top: float, right: float, bottom: float) -> void:
	var node := controls.get_node_or_null(node_name) as Control
	if not node:
		return
	node.anchor_left = anchor_x
	node.anchor_right = anchor_x
	node.anchor_top = anchor_y
	node.anchor_bottom = anchor_y
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

func _press_action(action: String) -> void:
	if gameplay_visible and not action.is_empty():
		Input.action_press(action)

func _release_action(action: String) -> void:
	if not action.is_empty():
		Input.action_release(action)

func _on_shoot_down() -> void:
	if gameplay_visible and player:
		player.shoot()

func _on_reload_pressed() -> void:
	if gameplay_visible and player:
		player.reload()

func _toggle_pause() -> void:
	if player:
		player.toggle_pause()

func _input(event: InputEvent) -> void:
	if not gameplay_visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_hits_control(event.position):
				return
			if aim_touch_index == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
				aim_touch_index = event.index
		elif event.index == aim_touch_index:
			aim_touch_index = -1
	elif event is InputEventScreenDrag and event.index == aim_touch_index and player:
		player.apply_look(event.screen_relative)

func _touch_hits_control(position: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group(ACTION_BUTTON_GROUP):
		if node is Control and node.visible and node.get_global_rect().has_point(position):
			return true
	return pause_button.visible and pause_button.get_global_rect().has_point(position)

func _release_all_actions() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(action)
