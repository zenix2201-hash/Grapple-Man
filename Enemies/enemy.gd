class_name Enemy
extends CharacterBody3D
## Base class for every robot enemy. Handles health, hit flashes, knockback,
## stuns, death (gibs, drops, style points) and has helpers for moving,
## line of sight and shooting.
##
## To make a new enemy: extend Enemy, set stats in _init(), build a model in
## _build_model() and write its behaviour in _ai(delta).
## Origin is at the feet.

signal died(enemy: Enemy)

@export var display_name: String = "ROBOT"
@export var max_health: float = 50.0
@export var move_speed: float = 4.0
@export var scrap_value: int = 5
@export var oil_drops: int = 2
@export var kill_style: int = 30
@export var is_light: bool = true ## Light enemies get yanked by the lasso; heavy ones pull you in
@export var flying: bool = false
@export var is_boss: bool = false
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
@export var body_color: Color = Color(0.6, 0.55, 0.5)
@export var eye_color: Color = Color(1.0, 0.3, 0.1)
@export var collision_radius: float = 0.5
@export var collision_height: float = 1.8
@export var gravity: float = 22.0

var health: float = 50.0
var is_dead := false
var player: Player = null
var stun_timer := 0.0
var knockback := Vector3.ZERO
var model: Node3D
var eye_mat: ShaderMaterial

var _materials: Array[ShaderMaterial] = []
var _flash := 0.0
var _telegraph := 0.0
var _yanked := false
var _spawn_t := 0.5
var _time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD_MASK | Layers.ENEMY | Layers.PLAYER
	health = max_health * GameState.enemy_health_mult()
	max_health = health

	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = collision_radius
		cap.height = maxf(collision_height, collision_radius * 2.0)
		cs.shape = cap
		cs.position.y = collision_height * 0.5
		add_child(cs)

	eye_mat = PSX.glow(eye_color)
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	_build_model()

	# Pop in.
	model.scale = Vector3.ONE * 0.05
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_find_player()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_time += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_telegraph = maxf(_telegraph - delta, 0.0)
	_update_flash()

	if _spawn_t > 0.0:
		_spawn_t -= delta
		if not flying:
			velocity.y -= gravity * delta
			move_and_slide()
		return
	if player == null or not is_instance_valid(player):
		_find_player()

	if stun_timer > 0.0:
		stun_timer -= delta
		if not flying or _yanked:
			velocity.y -= gravity * delta
		var drag := 2.0 if _yanked else 8.0
		velocity.x = move_toward(velocity.x, 0.0, drag * delta * absf(velocity.x))
		velocity.z = move_toward(velocity.z, 0.0, drag * delta * absf(velocity.z))
		velocity += knockback
		move_and_slide()
		velocity -= knockback
		knockback = knockback.move_toward(Vector3.ZERO, 25.0 * delta)
		_animate(delta)
		return
	_yanked = false

	if player == null or player.is_dead:
		_idle(delta)
	else:
		_ai(delta)

	velocity += knockback
	move_and_slide()
	velocity -= knockback
	knockback = knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	_animate(delta)


# --- Overridable hooks ---

func _build_model() -> void:
	add_part(PSX.box(Vector3(0.8, collision_height, 0.6)), body_color, Vector3(0, collision_height * 0.5, 0))


func _ai(delta: float) -> void:
	_idle(delta)


func _idle(delta: float) -> void:
	if flying:
		velocity = velocity.lerp(Vector3.ZERO, minf(3.0 * delta, 1.0))
	else:
		ground_move(Vector3.ZERO, 0.0, delta)


func _animate(_delta: float) -> void:
	pass


func _on_death(_source: String) -> void:
	pass


# --- Damage ---

func take_damage(amount: float, hit_pos: Vector3, dir: Vector3, source: String = "gun") -> void:
	if is_dead:
		return
	health -= amount
	_flash = 1.0
	if dir != Vector3.ZERO:
		apply_knockback(dir.normalized() * clampf(amount * 0.12, 0.5, 7.0))
	Fx.sparks(hit_pos, -dir, Color(0.12, 0.09, 0.05), 6, 5.0) # oil
	Fx.sparks(hit_pos, -dir, Color(1.0, 0.8, 0.3), 3, 7.0)
	Sfx.play_at("hit", hit_pos, -4.0)
	if is_boss:
		GameState.boss_update.emit(display_name, maxf(health, 0.0) / max_health)
	if health <= 0.0:
		die(source)


func apply_knockback(v: Vector3) -> void:
	knockback += v * (1.0 - knockback_resist)


func stun(duration: float) -> void:
	if is_boss:
		duration *= 0.25
	stun_timer = maxf(stun_timer, duration)


## Lasso pull (light enemies only).
func yank_toward(target_pos: Vector3, _by: Node) -> void:
	if not is_light or is_dead:
		return
	stun_timer = 0.9
	_yanked = true
	knockback = Vector3.ZERO
	var d := target_pos - global_position
	velocity = d.normalized() * clampf(d.length() * 2.2, 10.0, 32.0) + Vector3.UP * 5.0


func die(source: String = "gun") -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	died.emit(self)
	if source != "self": # "self" = blew itself up, no credit to the player
		GameState.on_enemy_killed(self, source)
	var c: Vector3 = chest()
	Fx.gibs(c, body_color, 5 + int(max_health / 60.0), 0.2 + collision_radius * 0.15)
	Fx.sparks(c, Vector3.UP, Color(1.0, 0.6, 0.2), 16, 9.0)
	Fx.shake(0.12)
	Fx.hitstop(0.05 if not is_boss else 0.3)
	Sfx.play_at("kill", c)
	Fx.drop_pickups(c, oil_drops, scrap_value)
	if is_boss:
		GameState.boss_update.emit(display_name, -1.0)
	if source != "volatile" and source != "self" and GameState.has_perk("volatile"):
		Fx.explosion(c, 3.5, 25.0, true, "volatile")
	_on_death(source)
	queue_free()


# --- Helpers ---

func chest() -> Vector3:
	return global_position + Vector3.UP * collision_height * 0.6


func player_chest() -> Vector3:
	return player.global_position + Vector3.UP * 0.3


func dist_to_player() -> float:
	return global_position.distance_to(player.global_position)


func flat_dir_to_player() -> Vector3:
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	return d.normalized()


func can_see_player(from: Vector3 = Vector3.INF) -> bool:
	if player == null:
		return false
	var f: Vector3 = chest() if from == Vector3.INF else from
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(f, player_chest(), Layers.WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Turn to face a direction (model forward is -Z).
func face(dir: Vector3, delta: float, turn_speed: float = 10.0) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(turn_speed * delta, 1.0))


## Walk along the ground. Hops over obstacles it bumps into.
func ground_move(dir: Vector3, spd: float, delta: float, accel: float = 30.0) -> void:
	var target := dir * spd
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif is_on_wall() and spd > 0.1:
		velocity.y = 7.5


## Keeps enemies from stacking on top of each other.
func separation(radius: float = 2.0) -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Node3D
		if other == self or other == null:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < radius and l > 0.01:
			push += d / l * (radius - l)
	return push


## Where the player will probably be by the time a shot arrives.
func lead_target(from: Vector3, projectile_speed: float, accuracy: float = 0.7) -> Vector3:
	var t: float = from.distance_to(player_chest()) / maxf(projectile_speed, 0.1)
	var v: Vector3 = player.velocity
	v.y *= 0.3
	return player_chest() + v * t * accuracy


func shoot(from: Vector3, dir: Vector3, spd: float, dmg: float, color: Color = Color(1.0, 0.55, 0.15),
		size: float = 0.22, homing: float = 0.0) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	get_tree().current_scene.add_child(p)
	p.setup(from, dir.normalized() * spd, dmg * GameState.enemy_damage_mult(), color, size, homing)
	Sfx.play_at("enemy_shot", from, -6.0)
	return p


## Flash yellow and beep before attacking so the player can react.
func telegraph(duration: float = 0.4, at: Vector3 = Vector3.INF) -> void:
	_telegraph = duration
	Sfx.play_at("telegraph", chest(), -6.0, 1.0 + randf() * 0.1)
	Fx.flare(chest() if at == Vector3.INF else at, Color(1.0, 0.9, 0.3), 0.9, 0.3)


## Registers a material so it flashes when hit. Use for every body part.
func mat(color: Color) -> ShaderMaterial:
	var m: ShaderMaterial = PSX.material(color, true)
	m.set_shader_parameter("uv_scale", 3.0)
	_materials.append(m)
	return m


func add_part(mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return PSX.part(parent if parent != null else model, mesh, mat(color), pos, rot)


func add_eye(mesh: Mesh, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	return PSX.part(parent if parent != null else model, mesh, eye_mat, pos)


func pivot(pos: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	(parent if parent != null else model).add_child(n)
	return n


func _find_player() -> void:
	player = GameState.player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player


func _update_flash() -> void:
	var amount := _flash
	var color := Color(1, 1, 1)
	if _telegraph > 0.0 and _flash < 0.1:
		amount = 0.35 + 0.35 * sin(_time * 40.0)
		color = Color(1.0, 0.85, 0.2)
	for m in _materials:
		m.set_shader_parameter("flash_amount", amount)
		m.set_shader_parameter("flash_color", color)
