extends CharacterBody3D
class_name Player

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var crouch_speed := 2.5
@export var acceleration := 18.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.0025
@export var max_health := 100
@export var magazine_size := 30
@export var reserve_ammo := 120
@export var fire_rate := 0.12

var health := 100
var ammo := 30
var is_reloading := false
var is_crouching := false
var can_fire := true
var pitch := -0.12
var mission_controller: Node
var camera: Camera3D
var weapon_ray: RayCast3D

func _ready() -> void:
	health = max_health
	ammo = magazine_size
	camera = get_node("Head/Camera3D")
	weapon_ray = get_node("Head/Camera3D/WeaponRay")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.2, 1.0)
		camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	is_crouching = Input.is_action_pressed("crouch")
	var speed := crouch_speed if is_crouching else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	if Input.is_action_just_pressed("shoot") and can_fire and not is_reloading:
		shoot()
	if Input.is_action_just_pressed("reload") and not is_reloading and ammo < magazine_size and reserve_ammo > 0:
		reload()

func shoot() -> void:
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	can_fire = false
	weapon_ray.force_raycast_update()
	if weapon_ray.is_colliding():
		var target := weapon_ray.get_collider()
		if target and target.has_method("take_damage"):
			target.take_damage(25)
	if mission_controller and mission_controller.has_method("player_fired"):
		mission_controller.player_fired()
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func reload() -> void:
	is_reloading = true
	await get_tree().create_timer(1.1).timeout
	var needed := magazine_size - ammo
	var loaded := min(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false

func take_damage(amount: int) -> void:
	health -= amount
	if mission_controller and mission_controller.has_method("player_health_changed"):
		mission_controller.player_health_changed(health)
	if health <= 0:
		get_tree().reload_current_scene()
