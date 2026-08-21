extends CharacterBody3D
class_name Enemy

signal defeated

@export var move_speed := 2.2
@export var max_health := 100
@export var detection_range := 24.0
@export var attack_range := 12.0
@export var attack_damage := 8
@export var attack_cooldown := 1.0

var health := 100
var target: Player
var attack_timer := 0.0
var gravity := 20.0
var defeated_state := false
var hit_tween: Tween
@onready var mesh: MeshInstance3D = $Mesh
@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	add_to_group("mission_enemy")
	health = max_health
	target = get_tree().get_first_node_in_group("player") as Player
	set_physics_process(target != null)
	var body_collision_layer := collision.get_parent().collision_layer if collision and collision.get_parent() is CollisionObject3D else "N/A"
	var body_collision_mask := collision.get_parent().collision_mask if collision and collision.get_parent() is CollisionObject3D else "N/A"
	print("[SPECIAL OPS] Enemy ready: ", name, " position=", global_position, " health=", health, " body_collision_layer=", body_collision_layer, " body_collision_mask=", body_collision_mask)

func _physics_process(delta: float) -> void:
	if defeated_state: return
	if not target or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player
		return
	if not target.mission_active or get_tree().paused:
		velocity = Vector3.ZERO
		return
	if not is_on_floor(): velocity.y -= gravity * delta
	else: velocity.y = -0.2
	var distance := global_position.distance_to(target.global_position)
	if distance <= detection_range:
		var flat_target := target.global_position
		flat_target.y = global_position.y
		look_at(flat_target, Vector3.UP)
		if distance > attack_range:
			velocity.x = -global_transform.basis.z.x * move_speed
			velocity.z = -global_transform.basis.z.z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				target.take_damage(attack_damage)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

func take_damage(amount: int) -> void:
	if defeated_state:
		print("[SPECIAL OPS] Ignored damage: ", name, " is already defeated.")
		return
	print("[SPECIAL OPS] ENEMY HIT: ", name, " position=", global_position, " health_before=", health, " damage=", amount)
	health -= amount
	print("[SPECIAL OPS] ENEMY HEALTH AFTER HIT: ", name, " health=", health)
	_play_hit_feedback()
	if health <= 0:
		print("[SPECIAL OPS] ENEMY DEFEATED: ", name, " position=", global_position)
		_die()

func _play_hit_feedback() -> void:
	if hit_tween and hit_tween.is_valid(): hit_tween.kill()
	var original_scale := scale
	hit_tween = create_tween()
	hit_tween.tween_property(self, "scale", original_scale * 1.08, 0.04)
	hit_tween.tween_property(self, "scale", original_scale, 0.08)

func _die() -> void:
	defeated_state = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	collision.set_deferred("disabled", true)
	defeated.emit()
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "rotation_degrees:x", -85.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, "position:y", max(0.2, position.y - 0.65), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.set_parallel(false)
	death_tween.tween_interval(0.35)
	death_tween.tween_callback(queue_free)
