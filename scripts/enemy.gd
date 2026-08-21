extends CharacterBody3D
class_name Enemy

## Extensible combat-opponent state machine.
## States are intentionally simple (per design directive: prioritize
## believable gameplay over a heavy AI framework) but keep clean seams
## for future work (cover-seeking, squad coordination, etc).
enum State { IDLE, PATROL, ALERT, ENGAGE, DEAD }

signal defeated

@export var move_speed := 2.2
@export var max_health := 100
@export var detection_range := 24.0
@export var attack_range := 12.0
@export var attack_damage := 8
@export var attack_cooldown := 1.0
## Chance (0-1) that an attack tick actually lands. Lets some enemies
## read as a real ranged threat without one-shot-hitscan-perfect aim.
@export var aim_accuracy := 0.6
## Time spent "noticing" the player before actively engaging - gives
## the player a beat to react instead of instant omniscient AI.
@export var alert_delay := 0.4
## Optional patrol route. Populate with Marker3D children under a
## "PatrolPoints" node in the enemy's parent context, or leave empty
## for a stationary guard.
@export var patrol_points: Array[NodePath] = []
@export var patrol_wait := 1.5

var health := 100
var target: Player
var attack_timer := 0.0
var alert_timer := 0.0
var gravity := 20.0
var defeated_state := false
var hit_tween: Tween
var state: State = State.IDLE
var patrol_index := 0
var patrol_wait_timer := 0.0
var muzzle_flash_tween: Tween
var is_active := true

@onready var mesh: MeshInstance3D = $Mesh
@onready var collision: CollisionShape3D = $Collision
@onready var weapon: MeshInstance3D = $Weapon
@onready var muzzle_flash: OmniLight3D = $Weapon/MuzzleFlash
@onready var shot_sound: AudioStreamPlayer3D = $Sounds/Shot
@onready var death_sound: AudioStreamPlayer3D = $Sounds/Death

func _ready() -> void:
	add_to_group("mission_enemy")
	health = max_health
	target = get_tree().get_first_node_in_group("player") as Player
	state = State.PATROL if not patrol_points.is_empty() else State.IDLE
	muzzle_flash.visible = false
	set_physics_process(is_active and target != null)

## Called by the mission/encounter system to enable or disable this
## enemy without destroying it - keeps inactive encounter groups from
## costing physics/AI cycles until the player reaches them.
func set_active(active: bool) -> void:
	is_active = active
	visible = active
	if collision:
		collision.set_deferred("disabled", not active or defeated_state)
	set_physics_process(active and not defeated_state)

func _physics_process(delta: float) -> void:
	if defeated_state:
		return
	if not target or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player
		return
	if not target.mission_active or get_tree().paused:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2

	var distance := global_position.distance_to(target.global_position)

	match state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if distance <= detection_range and _has_line_of_sight():
				_enter_alert()
		State.PATROL:
			_process_patrol(delta)
			if distance <= detection_range and _has_line_of_sight():
				_enter_alert()
		State.ALERT:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(target.global_position)
			alert_timer -= delta
			if distance > detection_range * 1.4:
				state = State.PATROL if not patrol_points.is_empty() else State.IDLE
			elif alert_timer <= 0.0:
				state = State.ENGAGE
		State.ENGAGE:
			_process_engage(delta, distance)

	move_and_slide()

func _has_line_of_sight() -> bool:
	# Lightweight check - avoids enemies "sensing" the player through
	# entire buildings while staying cheap for mobile hardware.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, target.global_position + Vector3.UP * 0.8)
	query.exclude = [self]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _enter_alert() -> void:
	state = State.ALERT
	alert_timer = alert_delay

func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var point_node := get_node_or_null(patrol_points[patrol_index])
	if not point_node:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var point: Vector3 = point_node.global_position
	var flat_here := global_position
	flat_here.y = 0.0
	var flat_point := point
	flat_point.y = 0.0
	if flat_here.distance_to(flat_point) <= 0.6:
		velocity.x = 0.0
		velocity.z = 0.0
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			patrol_index = (patrol_index + 1) % patrol_points.size()
			patrol_wait_timer = patrol_wait
		return
	_face(point)
	var dir := (point - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed * 0.6
	velocity.z = dir.z * move_speed * 0.6

func _process_engage(delta: float, distance: float) -> void:
	_face(target.global_position)
	if distance > attack_range:
		velocity.x = -global_transform.basis.z.x * move_speed
		velocity.z = -global_transform.basis.z.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_fire_at_target()
	if distance > detection_range * 1.6:
		state = State.PATROL if not patrol_points.is_empty() else State.IDLE

func _face(point: Vector3) -> void:
	var flat_target := point
	flat_target.y = global_position.y
	if flat_target.distance_to(global_position) > 0.01:
		look_at(flat_target, Vector3.UP)

func _fire_at_target() -> void:
	_play_muzzle_flash()
	_play_sound(shot_sound)
	if randf() <= aim_accuracy:
		target.take_damage(attack_damage)

func _play_sound(player: AudioStreamPlayer3D) -> void:
	# No-op until an audio asset is assigned - keeps missing sound
	# files from ever blocking gameplay.
	if player and player.stream:
		player.play()

func _play_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_flash.light_energy = 4.0
	if muzzle_flash_tween and muzzle_flash_tween.is_valid():
		muzzle_flash_tween.kill()
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.08)
	muzzle_flash_tween.tween_callback(func(): muzzle_flash.visible = false)

func take_damage(amount: int) -> void:
	if defeated_state:
		return
	health -= amount
	_play_hit_feedback()
	# Taking fire is itself detection - a hit enemy reacts even if it
	# hadn't noticed the player yet (shot from behind/from range).
	if state == State.IDLE or state == State.PATROL:
		_enter_alert()
		alert_timer = min(alert_timer, 0.15)
	if health <= 0:
		_die()

func _play_hit_feedback() -> void:
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
	var original_scale := scale
	hit_tween = create_tween()
	hit_tween.tween_property(self, "scale", original_scale * 1.08, 0.04)
	hit_tween.tween_property(self, "scale", original_scale, 0.08)

func _die() -> void:
	defeated_state = true
	state = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)
	collision.set_deferred("disabled", true)
	muzzle_flash.visible = false
	_play_sound(death_sound)
	_drop_weapon()
	defeated.emit()
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "rotation_degrees:x", -85.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, "position:y", max(0.2, position.y - 0.65), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_interval(0.35)
	death_tween.tween_callback(queue_free)

func _drop_weapon() -> void:
	if not weapon:
		return
	var dropped := MeshInstance3D.new()
	dropped.mesh = weapon.mesh
	dropped.global_transform = weapon.global_transform
	get_tree().current_scene.add_child(dropped)
	var drop_tween := dropped.create_tween()
	var ground_y: float = global_position.y - 0.75
	drop_tween.tween_property(dropped, "global_position:y", ground_y, 0.35).set_trans(Tween.TRANS_BOUNCE)
	drop_tween.parallel().tween_property(dropped, "rotation_degrees", Vector3(0, randf_range(0, 360), 80), 0.35)
	weapon.visible = false
