extends CanvasLayer
class_name HUD

signal restart_requested

@onready var objective_label: Label = $TopLeft/Panel/VBox/Objective
@onready var status_label: Label = $TopLeft/Panel/VBox/Status
@onready var health_label: Label = $BottomLeft/Health
@onready var ammo_label: Label = $BottomRight/Ammo
@onready var complete_panel: Control = $MissionComplete
@onready var complete_button: Button = $MissionComplete/Panel/VBox/Restart

var player: Player
var mission: MissionManager

func _ready() -> void:
	complete_panel.visible = false
	complete_button.pressed.connect(_on_restart_pressed)

func bind_player(value: Player) -> void:
	player = value
	_update_player_labels()

func bind_mission(value: MissionManager) -> void:
	if mission:
		mission.objective_changed.disconnect(_on_objective_changed)
		mission.status_changed.disconnect(_on_status_changed)
	mission = value
	mission.objective_changed.connect(_on_objective_changed)
	mission.status_changed.connect(_on_status_changed)

func _process(_delta: float) -> void:
	_update_player_labels()

func _update_player_labels() -> void:
	if not player or not is_instance_valid(player):
		return
	health_label.text = "HEALTH  %d" % player.health
	ammo_label.text = "AMMO  %02d / %03d" % [player.ammo, player.reserve_ammo]

func _on_objective_changed(text: String) -> void:
	objective_label.text = text

func _on_status_changed(text: String) -> void:
	status_label.text = text

func show_gameplay() -> void:
	visible = true
	complete_panel.visible = false

func hide_gameplay() -> void:
	visible = false

func show_mission_complete() -> void:
	visible = true
	complete_panel.visible = true

func hide_mission_complete() -> void:
	complete_panel.visible = false

func _on_restart_pressed() -> void:
	restart_requested.emit()
