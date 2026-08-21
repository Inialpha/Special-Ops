extends Area3D
class_name EncounterTrigger

## Placed at a chokepoint (alley mouth, gate, doorway) in the level.
## When the player physically walks into it, it asks the mission
## manager to bring the named encounter group online. Reusable across
## any future level - the level just needs matching group names under
## its "Enemies" node.

@export var encounter_name := ""
@export var one_shot := true

var _fired := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _fired and one_shot:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	var mission := get_tree().get_first_node_in_group("mission_manager")
	if mission and mission.has_method("activate_encounter"):
		mission.activate_encounter(encounter_name)
