extends Node

var enemies_remaining := 6
var shots_fired := 0
var player: Player
var objective_complete := false
var status_label: Label
var objective_label: Label
var ammo_label: Label
var health_label: Label
var mission_complete_panel: Panel

func _ready() -> void:
	add_to_group("mission_controller")
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.mission_controller = self
	status_label = get_node_or_null("../UI/Margin/VBox/Status")
	objective_label = get_node_or_null("../UI/Margin/VBox/Objective")
	ammo_label = get_node_or_null("../UI/Margin/VBox/Ammo")
	health_label = get_node_or_null("../UI/Margin/VBox/Health")
	mission_complete_panel = get_node_or_null("../UI/CompletePanel")
	update_ui()

func enemy_eliminated() -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0:
		objective_complete = true
		if objective_label:
			objective_label.text = "OBJECTIVE COMPLETE — Reach extraction"
			status_label.text = "ALL HOSTILES DOWN"
	else:
		if status_label:
			status_label.text = "HOSTILES REMAINING: %d" % enemies_remaining

func player_fired() -> void:
	shots_fired += 1
	update_ui()

func player_health_changed(value: int) -> void:
	if health_label:
		health_label.text = "HEALTH  %d" % value

func update_ui() -> void:
	if player and ammo_label:
		ammo_label.text = "AMMO  %02d / %03d" % [player.ammo, player.reserve_ammo]
	if player and health_label:
		health_label.text = "HEALTH  %d" % player.health

func _process(_delta: float) -> void:
	update_ui()
	if objective_complete and player:
		var extraction := get_tree().get_first_node_in_group("extraction")
		if extraction and player.global_position.distance_to(extraction.global_position) < 3.5:
			mission_complete()

func mission_complete() -> void:
	objective_complete = false
	if mission_complete_panel:
		mission_complete_panel.visible = true
		get_tree().paused = true
