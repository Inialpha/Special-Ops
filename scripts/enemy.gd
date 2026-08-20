extends CharacterBody3D
class_name Enemy

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

func _ready() -> void:
	health = max_health
	target = get_tree().get_first_node_in_group("player") as Player
	set_physics_process(target != null)

func _physics_process(delta: float) -> void:
	if not target:
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
	if distance <= detection_range:
		var flat_target := target.global_position
		flat_target.y = global_position.y
		look_at(flat_target, Vector3.UP)
		if distance > attack_range:
			velocity.x = -global_transform.basis.z.x * move_speed
			velocity.z = -global_transform.basis.z.z * move_speed
		else:
			velocity.x = 0
			velocity.z = 0
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = attack_cooldown
				target.take_damage(attack_damage)
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var controller := get_tree().get_first_node_in_group("mission_controller")
		if controller and controller.has_method("enemy_eliminated"):
			controller.enemy_eliminated()
		queue_free()
