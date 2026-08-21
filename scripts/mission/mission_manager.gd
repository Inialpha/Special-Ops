extends Node
class_name MissionManager

## Drives mission progression for whichever level is currently loaded.
## Reusable across levels: a level just needs an "Enemies" node whose
## children are either individual Enemy nodes or Node3D groups of
## Enemy nodes (one group per encounter). The first group is live from
## the start; later groups stay dormant until an EncounterTrigger in
## the level activates them by name, which is what turns "spawn all
## enemies at once" into an actual staged mission.

signal objective_changed(text: String)
signal status_changed(text: String)
signal mission_completed

const OBJECTIVE_TEXT := {
	"FirstContact": "OBJECTIVE: Eliminate hostiles on the street ahead",
	"SecondEngagement": "OBJECTIVE: Clear the market alley",
	"MajorAssault": "OBJECTIVE: Break the enemy strongpoint",
}
const DEFAULT_OBJECTIVE := "OBJECTIVE: Eliminate all hostiles in the area"

var current_level: Node3D
var player: Player
var objective_complete := false
var active := false
var shots_fired := 0
var total_enemies_remaining := 0

# Array of Dictionary: {name, enemies: Array[Enemy], remaining, cleared, active}
var encounters: Array = []

func _ready() -> void:
	add_to_group("mission_manager")

func start_for_level(level: Node3D, level_player: Player) -> void:
	current_level = level
	player = level_player
	player.mission_controller = self
	objective_complete = false
	active = true
	shots_fired = 0
	total_enemies_remaining = 0
	encounters.clear()

	var enemies_node := current_level.get_node_or_null("Enemies")
	if enemies_node:
		for group in enemies_node.get_children():
			var enemy_list: Array = []
			if group is Enemy:
				enemy_list.append(group)
			else:
				for child in group.get_children():
					if child is Enemy:
						enemy_list.append(child)
			if enemy_list.is_empty():
				continue
			var idx := encounters.size()
			encounters.append({
				"name": group.name,
				"enemies": enemy_list,
				"remaining": enemy_list.size(),
				"cleared": false,
				"active": false,
			})
			total_enemies_remaining += enemy_list.size()
			for enemy in enemy_list:
				enemy.defeated.connect(_on_enemy_defeated.bind(idx))

	for i in encounters.size():
		_set_encounter_active(i, false)

	if not encounters.is_empty():
		_activate_index(0)
	else:
		objective_complete = true
		objective_changed.emit("OBJECTIVE: Proceed to the extraction point")
		status_changed.emit("AREA CLEAR")

func _process(_delta: float) -> void:
	if not active or not player or not is_instance_valid(player):
		return
	if objective_complete:
		var extraction := current_level.get_node_or_null("Extraction")
		if extraction and player.global_position.distance_to(extraction.global_position) <= 3.5:
			_complete_mission()

func activate_encounter(encounter_name: String) -> void:
	for i in encounters.size():
		if encounters[i]["name"] == encounter_name:
			_activate_index(i)
			return

func _activate_index(idx: int) -> void:
	if idx < 0 or idx >= encounters.size():
		return
	var group: Dictionary = encounters[idx]
	if group["active"] or group["cleared"]:
		return
	group["active"] = true
	_set_encounter_active(idx, true)
	status_changed.emit("HOSTILES REMAINING: %d" % group["remaining"])
	objective_changed.emit(OBJECTIVE_TEXT.get(group["name"], DEFAULT_OBJECTIVE))

func _set_encounter_active(idx: int, is_active: bool) -> void:
	var group: Dictionary = encounters[idx]
	for enemy in group["enemies"]:
		if is_instance_valid(enemy):
			enemy.set_active(is_active)

func _on_enemy_defeated(idx: int) -> void:
	if not active or idx < 0 or idx >= encounters.size():
		return
	var group: Dictionary = encounters[idx]
	group["remaining"] = max(0, group["remaining"] - 1)
	total_enemies_remaining = max(0, total_enemies_remaining - 1)

	if group["remaining"] == 0 and not group["cleared"]:
		group["cleared"] = true
		if _all_cleared():
			objective_complete = true
			objective_changed.emit("OBJECTIVE: Proceed to the extraction point")
			status_changed.emit("ALL HOSTILES DOWN")
		else:
			status_changed.emit("AREA CLEAR")
			objective_changed.emit("OBJECTIVE: Advance and locate remaining hostiles")
	else:
		status_changed.emit("HOSTILES REMAINING: %d" % group["remaining"])

func _all_cleared() -> bool:
	for group in encounters:
		if not group["cleared"]:
			return false
	return true

func player_fired() -> void:
	shots_fired += 1

func player_health_changed(_value: int) -> void:
	pass

func _complete_mission() -> void:
	if not active:
		return
	active = false
	mission_completed.emit()
