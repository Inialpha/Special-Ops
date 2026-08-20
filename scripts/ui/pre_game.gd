extends Control
class_name PreGame

signal start_mission_requested

@onready var briefing: MissionBriefing = $MissionBriefing

func _ready() -> void:
	briefing.start_mission_requested.connect(_on_start_mission_requested)

func _on_start_mission_requested() -> void:
	start_mission_requested.emit()
