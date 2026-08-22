extends CharacterBody3D
class_name Player

const ImpactEffectScene := preload("res://scenes/effects/impact_effect.tscn")

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var crouch_speed := 2.5
@export var acceleration := 18.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.0025
@export var touch_sensitivity := 0.0035
@export var max_health := 100
@export var magazine_size := 30
@export var reserve_ammo := 120
@export var fire_rate := 0.12
@export var damage_per_shot := 25

var health := 100
var ammo := 30
var is_reloading := false
var can_fire := true
var is_crouching := false
var mission_active := false
var pitch := -0.12
var mission_controller: Node
var weapon_recoil_tween: Tween
var muzzle_flash_tween: Tween
var shot_flash_tween: Tween
var shot_flash: MeshInstance3D
const WEAPON_REST_POSITION := Vector3(0.45, -0.32, -0.72)
const WEAPON_RECOIL_POSITION := Vector3(0.45, -0.32, -0.60)
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: MeshInstance3D = $Head/Camera3D/Weapon
@onready var muzzle_flash: OmniLight3D = $Head/Camera3D/MuzzleFlash
@onready var shot_sound: AudioStreamPlayer = $Sounds/Shot
@onready var reload_sound: AudioStreamPlayer = $Sounds/Reload
@onready var hurt_sound: AudioStreamPlayer = $Sounds/Hurt

func _ready() -> void:
	_ensure_input_actions()
	health = max_health
	ammo = magazine_size
	camera.current = true
	set_physics_process(false)
	muzzle_flash.visible = false
	weapon.position = WEAPON_REST_POSITION
	weapon.rotation_degrees = Vector3.ZERO
	weapon.scale = Vector3(0.8, 0.8, 0.8)
	_create_shot_flash()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Small camera-attached muzzle-flash quad, layered on top of the
## weapon-tip OmniLight3D for a punchier first-person shot read.
func _create_shot_flash() -> void:
	shot_flash = MeshInstance3D.new()
	shot_flash.name = "RuntimeShotFlash"
	shot_flash.visible = false
	shot_flash.position = Vector3(0.45, -0.32, -1.18)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1.0, 0.55, 0.05, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.02, 1.0)
	material.emission_energy_multiplier = 6.0
	quad.material = material
	shot_flash.mesh = quad
	camera.add_child(shot_flash)

func _ensure_input_actions() -> void:
	var actions := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_C, "reload": KEY_R, "interact": KEY_E}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = actions[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
	if InputMap.action_get_events("shoot").is_empty():
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mouse_event)

func start_mission() -> void:
	mission_active = true
	set_physics_process(true)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func stop_mission() -> void:
	mission_active = false
	set_physics_process(false)
	velocity = Vector3.ZERO
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_pause() -> void:
	if not mission_active:
		return
	get_tree().paused = not get_tree().paused
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED

func apply_look(delta: Vector2) -> void:
	if not mission_active or get_tree().paused:
		return
	rotate_y(-delta.x * touch_sensitivity)
	pitch = clamp(pitch - delta.y * touch_sensitivity, -1.2, 1.0)
	camera.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if not mission_active or get_tree().paused:
		return
	if event is InputEventMouseMotion and not OS.has_feature("mobile") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.2, 1.0)
		camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()

func _physics_process(delta: float) -> void:
	if not mission_active or get_tree().paused:
		return
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
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("reload"):
		reload()

## Hit detection can land on a child CollisionShape's owning body, or on
## a nested part of a more complex rig later on - walk up the tree so
## "shoot()" doesn't silently no-op just because the collider itself
## isn't the node carrying take_damage().
func _find_damage_receiver(collider: Object) -> Node:
	if collider == null:
		return null
	var node := collider as Node
	while node:
		if node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null

func shoot() -> void:
	if not mission_active or get_tree().paused or not can_fire or is_reloading:
		return
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	can_fire = false
	_play_shot_animation()
	_play_sound(shot_sound)

	# Cast from the actual crosshair center rather than a fixed muzzle
	# RayCast3D - keeps hits authoritative to what the player is aiming
	# at regardless of weapon-model offset.
	var viewport_size := get_viewport().get_visible_rect().size
	var crosshair_center := viewport_size * 0.5
	var origin := camera.project_ray_origin(crosshair_center)
	var direction := camera.project_ray_normal(crosshair_center).normalized()
	var ray_end := origin + direction * 100.0

	var query := PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collision_mask = 1
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit and hit.get("collider"):
		var hit_receiver := _find_damage_receiver(hit.collider)
		if hit_receiver:
			hit_receiver.take_damage(damage_per_shot)
		_spawn_impact(hit.get("position", ray_end), hit.get("normal", Vector3.UP))

	if mission_controller and mission_controller.has_method("player_fired"):
		mission_controller.player_fired()

	await get_tree().create_timer(fire_rate).timeout
	if is_inside_tree():
		can_fire = true

func _play_shot_animation() -> void:
	muzzle_flash.visible = true
	muzzle_flash.light_energy = 5.0
	if muzzle_flash_tween and muzzle_flash_tween.is_valid():
		muzzle_flash_tween.kill()
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.07)
	muzzle_flash_tween.tween_callback(func(): muzzle_flash.visible = false)
	if shot_flash:
		shot_flash.visible = true
		shot_flash.scale = Vector3(1.25, 1.25, 1.25)
		if shot_flash_tween and shot_flash_tween.is_valid():
			shot_flash_tween.kill()
		shot_flash_tween = create_tween()
		shot_flash_tween.tween_property(shot_flash, "scale", Vector3(0.15, 0.15, 0.15), 0.08)
		shot_flash_tween.tween_callback(func(): shot_flash.visible = false)
	if weapon_recoil_tween and weapon_recoil_tween.is_valid():
		weapon_recoil_tween.kill()
	weapon_recoil_tween = create_tween()
	weapon_recoil_tween.tween_property(weapon, "position", WEAPON_RECOIL_POSITION, 0.035)
	weapon_recoil_tween.tween_property(weapon, "position", WEAPON_REST_POSITION, 0.09)

func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var effect := ImpactEffectScene.instantiate() as Node3D
	get_tree().current_scene.add_child(effect)
	effect.global_position = point + normal * 0.02
	if normal.length() > 0.01:
		effect.look_at(point + normal, Vector3.UP)

func _play_sound(player: AudioStreamPlayer) -> void:
	# Hook is always safe to call - if no audio asset has been assigned
	# yet, this is a no-op so missing sound files never block gameplay.
	if player and player.stream:
		player.play()

func reload() -> void:
	if not mission_active or get_tree().paused or is_reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return
	is_reloading = true
	_play_sound(reload_sound)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	var needed := magazine_size - ammo
	var loaded: int = min(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false

func take_damage(amount: int) -> void:
	if not mission_active or get_tree().paused:
		return
	health -= amount
	_play_sound(hurt_sound)
	if mission_controller and mission_controller.has_method("player_health_changed"):
		mission_controller.player_health_changed(health)
	if health <= 0:
		stop_mission()
