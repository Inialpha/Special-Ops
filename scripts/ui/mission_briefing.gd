extends Control
class_name MissionBriefing

signal start_mission_requested

@onready var start_button: Button = $Center/Panel/VBox/StartMission

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	start_mission_requested.emit()
