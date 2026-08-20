extends Node
class_name MissionManager

signal objective_changed(text: String)
signal status_changed(text: String)
signal mission_completed

var current_level: Node3D
var player: Player
var enemies_remaining := 0
var objective_complete := false
var active := false
var shots_fired := 0

func start_for_level(level: Node3D, level_player: Player) -> void:
	current_level = level
	player = level_player
	player.mission_controller = self
	enemies_remaining = 0
	objective_complete = false
	active = true
	shots_fired = 0

	var enemies := current_level.get_tree().get_nodes_in_group("mission_enemy")
	for enemy in enemies:
		if enemy.get_parent() == current_level.get_node_or_null("Enemies"):
			enemies_remaining += 1
			if enemy.has_signal("defeated"):
				enemy.defeated.connect(_on_enemy_defeated)

	objective_changed.emit("OBJECTIVE: Eliminate all hostiles")
	status_changed.emit("HOSTILES REMAINING: %d" % enemies_remaining)

func _process(_delta: float) -> void:
	if not active or not player or not is_instance_valid(player):
		return
	if objective_complete:
		var extraction := current_level.get_node_or_null("Extraction")
		if extraction and player.global_position.distance_to(extraction.global_position) <= 3.5:
			_complete_mission()

func _on_enemy_defeated() -> void:
	if not active:
		return
	enemies_remaining = max(0, enemies_remaining - 1)
	if enemies_remaining == 0:
		objective_complete = true
		objective_changed.emit("OBJECTIVE: Reach the extraction zone")
		status_changed.emit("ALL HOSTILES DOWN")
	else:
		status_changed.emit("HOSTILES REMAINING: %d" % enemies_remaining)

func player_fired() -> void:
	shots_fired += 1

func player_health_changed(_value: int) -> void:
	pass

func _complete_mission() -> void:
	if not active:
		return
	active = false
	mission_completed.emit()
