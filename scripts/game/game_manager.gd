extends Node
class_name GameManager

const LEVEL_1_SCENE := preload("res://scenes/levels/level_1.tscn")

@onready var level_container: Node3D = $LevelContainer
@onready var mission_manager: MissionManager = $MissionManager
@onready var pre_game: PreGame = $PreGame
@onready var hud: HUD = $HUD
@onready var mobile_controls: MobileControls = $MobileControls

var current_level: Node3D
var current_player: Player

func _ready() -> void:
	pre_game.start_mission_requested.connect(_on_start_mission_requested)
	mission_manager.mission_completed.connect(_on_mission_completed)
	hud.restart_requested.connect(restart_mission)
	hud.hide_gameplay()
	mobile_controls.hide_gameplay()

func _on_start_mission_requested() -> void:
	start_level_1()

func start_level_1() -> void:
	_clear_level()
	current_level = LEVEL_1_SCENE.instantiate() as Node3D
	level_container.add_child(current_level)
	await get_tree().process_frame

	current_player = current_level.get_node_or_null("Player") as Player
	if not current_player:
		push_error("Level 1 does not contain a Player node.")
		return

	mission_manager.start_for_level(current_level, current_player)
	hud.bind_mission(mission_manager)
	hud.bind_player(current_player)
	mobile_controls.bind_player(current_player)

	pre_game.visible = false
	hud.show_gameplay()
	mobile_controls.show_gameplay()
	current_player.start_mission()

func _on_mission_completed() -> void:
	if current_player:
		current_player.stop_mission()
	mobile_controls.hide_gameplay()
	hud.show_mission_complete()

func restart_mission() -> void:
	hud.hide_mission_complete()
	start_level_1()

func return_to_briefing() -> void:
	_clear_level()
	hud.hide_gameplay()
	mobile_controls.hide_gameplay()
	pre_game.visible = true

func _clear_level() -> void:
	if current_level and is_instance_valid(current_level):
		current_level.queue_free()
		current_level = null
	current_player = null
