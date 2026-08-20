extends CanvasLayer

func _ready() -> void:
	for button in get_tree().get_nodes_in_group("mobile_action_buttons"):
		var action: String = button.get_meta("action")
		button.button_down.connect(_press.bind(action))
		button.button_up.connect(_release.bind(action))

func _press(action: String) -> void:
	Input.action_press(action)

func _release(action: String) -> void:
	Input.action_release(action)
