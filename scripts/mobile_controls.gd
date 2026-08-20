extends CanvasLayer
class_name MobileControls

const ACTION_BUTTON_GROUP := "mobile_action_buttons"
const LOOK_MARGIN := 24.0

var player: Player
var controls: Control
var start_overlay: ColorRect
var pause_button: Button
var aim_touch_index := -1
var gameplay_visible := false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	controls = get_node_or_null("Controls") as Control
	if controls:
		controls.mouse_filter = Control.MOUSE_FILTER_PASS
		controls.visible = false

	_configure_action_buttons()
	_create_start_overlay()
	_create_pause_button()

func _configure_action_buttons() -> void:
	for button in get_tree().get_nodes_in_group(ACTION_BUTTON_GROUP):
		if not button is Button:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var action := str(button.get_meta("action", ""))
		if action == "shoot":
			button.pressed.connect(_on_shoot_pressed)
		elif action == "reload":
			button.pressed.connect(_on_reload_pressed)
		else:
			button.button_down.connect(_press_action.bind(action))
			button.button_up.connect(_release_action.bind(action))

func _press_action(action: String) -> void:
	if not gameplay_visible or action.is_empty():
		return
	Input.action_press(action)

func _release_action(action: String) -> void:
	if action.is_empty():
		return
	Input.action_release(action)

func _on_shoot_pressed() -> void:
	if gameplay_visible and player:
		player.shoot()

func _on_reload_pressed() -> void:
	if gameplay_visible and player:
		player.reload()

func _create_start_overlay() -> void:
	start_overlay = ColorRect.new()
	start_overlay.name = "MissionBriefing"
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.color = Color(0.015, 0.02, 0.018, 0.94)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_overlay)

	var center := VBoxContainer.new()
	center.name = "Briefing"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-260, -180)
	center.size = Vector2(520, 360)
	center.add_theme_constant_override("separation", 14)
	start_overlay.add_child(center)

	var title := Label.new()
	title.text = "SPECIAL OPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MISSION 01  //  THE DROP"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	center.add_child(subtitle)

	var objective := Label.new()
	objective.text = "OBJECTIVE\nEliminate all hostiles, then reach extraction."
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 20)
	center.add_child(objective)

	var start := Button.new()
	start.name = "StartMission"
	start.text = "START MISSION"
	start.custom_minimum_size = Vector2(0, 70)
	start.add_theme_font_size_override("font_size", 24)
	start.pressed.connect(_start_mission)
	center.add_child(start)

func _create_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "Pause"
	pause_button.text = "Ⅱ"
	pause_button.position = Vector2(1130, 24)
	pause_button.size = Vector2(70, 60)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.visible = false
	pause_button.pressed.connect(_toggle_pause)
	add_child(pause_button)

func _start_mission() -> void:
	gameplay_visible = true
	start_overlay.visible = false
	if controls:
		controls.visible = true
	pause_button.visible = true
	if player:
		player.start_mission()

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
		else:
			if event.index == aim_touch_index:
				aim_touch_index = -1
	elif event is InputEventScreenDrag and event.index == aim_touch_index and player:
		player.apply_look(event.screen_relative)

func _touch_hits_control(position: Vector2) -> bool:
	if controls:
		for node in get_tree().get_nodes_in_group(ACTION_BUTTON_GROUP):
			if node is Control and node.visible and node.get_global_rect().has_point(position):
				return true
	if pause_button and pause_button.visible and pause_button.get_global_rect().has_point(position):
		return true
	return false
