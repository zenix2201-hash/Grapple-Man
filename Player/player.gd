class_name Player
extends CharacterBody3D
## Robot cowboy controller. Fast, momentum-based movement: sprint, slide,
## dash, ground slam (+ slam bounce), wall run, mantle and a grapple that
## swings off walls, zips you to heavy enemies and yanks light ones to you.
## Also handles health, punching and parrying projectiles.

signal health_changed(current: float, maximum: float)
signal hurt(amount: float)
signal healed(amount: float)
signal parried
signal died

const HUD_SCENE: PackedScene = preload("res://UI/hud.tscn")

# --- MOVEMENT & HITBOX SETTINGS ---
@export_group("Movement")
@export var walk_speed: float = 8.0
@export var sprint_speed: float = 13.0
@export var jump_velocity: float = 7.5
@export var gravity_scale: float = 1.6
@export var fall_gravity_mult: float = 1.3 ## Extra gravity when falling, for a snappier arc
@export var ground_accel: float = 80.0
@export var ground_friction: float = 60.0
@export var overspeed_friction: float = 10.0 ## How fast extra momentum bleeds off on the ground
@export var air_accel: float = 8.0
@export var max_fall_speed: float = 55.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var stand_height: float = 2.0
@export var crouch_height: float = 1.0
var speed: float = 8.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- CAMERA & LOOK ---
@export_group("Camera")
@export var base_fov: float = 90.0
@export var enable_head_bob: bool = true
@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.06
@export var lean_amount: float = 0.03
@export var shake_strength: float = 1.0
var bob_time: float = 0.0
var land_dip: float = 0.0

# --- SLIDE, CROUCH & SLAM ---
@export_group("Slide & Slam")
@export var slide_speed_threshold: float = 2.0 ## Below this you crouch instead of slide
@export var slide_boost: float = 16.0
@export var slide_decay: float = 0.5
@export var slide_steer: float = 2.5
@export var slam_speed: float = 45.0
var is_sliding: bool = false
var is_crouching: bool = false
var is_slamming: bool = false
var slide_velocity: Vector3 = Vector3.ZERO
var slam_start_y: float = 0.0
var slam_bounce_power: float = 0.0
var slam_bounce_timer: float = 0.0

# --- DASH ---
@export_group("Dash")
@export var dash_speed: float = 28.0
@export var dash_time: float = 0.16
@export var dash_regen: float = 0.7 ## Charges per second
var is_dashing: bool = false
var dash_charges: float = 3.0
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

# --- GRAPPLE ---
@export_group("Grapple")
@export var grapple_speed: float = 35.0 ## Zip speed when lassoing a heavy enemy
@export var max_grapple_launch_speed: float = 28.0 # Safety clamp for jump-to-zip
@export var rope_reel_speed: float = 3.0 ## Rope slowly shortens so swings gain height
@export var swing_gravity_mult: float = 1.5
@onready var grapple_ray: RayCast3D = $Head/Camera3D/GrappleRay
@onready var grapple_line: MeshInstance3D = $GrappleLine
var is_grappling: bool = false
var grapple_target: Vector3 = Vector3.ZERO
var grapple_enemy: Enemy = null
var grapple_in_range: bool = false
var rope_length: float = 0.0
var grapple_cooldown: float = 0.0

# --- WALL RUN ---
@export_group("Wall Run")
@export var wall_run_speed: float = 14.0
@export var wall_run_gravity: float = 1.0
@export var wall_jump_force: float = 8.0
@export var max_wall_run_time: float = 1.6
@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight
var is_wall_running: bool = false
var wall_side: int = 0
var wall_run_timer: float = 0.0
var last_wall_normal: Vector3 = Vector3.ZERO # Prevents spam-jumping the same wall

# --- MANTLE ---
@export_group("Mantle")
@export var mantle_force: float = 7.0
var is_mantling: bool = false
var mantle_timer: float = 0.0
var mantle_dir: Vector3 = Vector3.ZERO

# --- COMBAT ---
@export_group("Combat")
@export var punch_damage: float = 20.0
@export var punch_cooldown: float = 0.35
@export var explosion_knockback: float = 22.0
var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var iframes: float = 0.0
var punch_timer: float = 0.0

# --- INPUT STATE ---
var input_dir: Vector2 = Vector2.ZERO
var wish_dir: Vector3 = Vector3.ZERO
var jump_buffer: float = 0.0
var coyote_timer: float = 0.0
var air_jumps_left: int = 0
var just_landed: bool = false
var boost_speed: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_manager: WeaponManager = $Head/Camera3D/WeaponManager
@onready var model: RobotCowboyModel = $Model

var hud: HUD


func _ready() -> void:
	add_to_group("player")
	GameState.player = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD_MASK | Layers.ENEMY
	floor_snap_length = 0.35

	if collision_shape.shape is CapsuleShape3D:
		collision_shape.shape = collision_shape.shape.duplicate()
		(collision_shape.shape as CapsuleShape3D).height = stand_height
	grapple_line.mesh = grapple_line.mesh.duplicate()
	grapple_line.visible = false
	camera.fov = base_fov
	camera.set_cull_mask_value(2, false) # hide our own body from the first-person camera

	max_health = GameState.stat("max_health")
	health = GameState.player_health if GameState.player_health > 0.0 else max_health
	health = minf(health, max_health)
	dash_charges = GameState.stat("dash_charges")
	GameState.parts_changed.connect(_on_parts_changed)

	hud = HUD_SCENE.instantiate() as HUD
	add_child(hud)
	hud.setup(self)

	# Give hand-built test levels the PS1 look too.
	if GameState.get_setting("psx_auto_convert"):
		PSX.convert_tree.call_deferred(get_tree().current_scene)


func _exit_tree() -> void:
	if GameState.player == self:
		GameState.player = null


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens: float = GameState.get_setting("mouse_sensitivity")
		rotate_y(-motion.relative.x * sens)
		head.rotate_x(-motion.relative.y * sens)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not get_tree().paused and not GameState.ui_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		_process_camera_effects(delta)
		return

	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var on_floor := is_on_floor()
	_tick_timers(delta, on_floor)

	_update_grapple_ui()
	_process_hitbox(delta)

	# 1. State Machines
	_process_dash(delta)
	_process_slam(on_floor)
	_process_slide(delta, on_floor)
	_process_wall_run(delta, on_floor)
	_process_mantle(delta, on_floor)
	_process_grapple(delta)
	_process_punch()

	# 2. Sprint Handling
	if not is_sliding:
		var base := sprint_speed if Input.is_action_pressed("Sprint") else walk_speed
		speed = base * GameState.stat("speed_mult") + boost_speed

	# 3. Main Velocity Processing
	if is_dashing or is_mantling or is_wall_running or is_slamming or is_grappling:
		pass # Velocity is fully controlled by their respective functions this frame
	elif is_sliding:
		if not on_floor:
			_apply_gravity(delta)
	elif on_floor:
		_ground_move(delta)
	else:
		_apply_gravity(delta)
		_air_move(delta)

	_try_jump(on_floor)
	velocity.y = maxf(velocity.y, -max_fall_speed)

	# 4. Final Application
	var pre_move_velocity := velocity
	move_and_slide()
	_after_move(on_floor, pre_move_velocity)
	_process_camera_effects(delta)
	model.move_speed = Vector2(velocity.x, velocity.z).length()


# --- CORE MOVEMENT ---

func _tick_timers(delta: float, on_floor: bool) -> void:
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = jump_buffer_time
	if on_floor:
		coyote_timer = coyote_time
		air_jumps_left = int(GameState.stat("air_jumps"))
		last_wall_normal = Vector3.ZERO
		wall_run_timer = 0.0
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	slam_bounce_timer = maxf(slam_bounce_timer - delta, 0.0)
	punch_timer = maxf(punch_timer - delta, 0.0)
	grapple_cooldown = maxf(grapple_cooldown - delta, 0.0)
	boost_speed = move_toward(boost_speed, 0.0, 2.0 * delta)
	if not is_dashing:
		dash_charges = minf(dash_charges + dash_regen * GameState.stat("dash_regen") * delta, GameState.stat("dash_charges"))


func _apply_gravity(delta: float) -> void:
	var g := gravity * gravity_scale
	if velocity.y < 0.0:
		g *= fall_gravity_mult
	velocity.y -= g * delta


func _ground_move(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir != Vector3.ZERO:
		if h.length() > speed + 0.1:
			# Moving faster than we could run (slide-jump, dash, explosion):
			# keep the momentum, steer it, and only bleed it off slowly.
			var new_len := move_toward(h.length(), speed, overspeed_friction * delta)
			h = h.lerp(wish_dir * h.length(), minf(6.0 * delta, 1.0)).normalized() * new_len
		else:
			h = h.move_toward(wish_dir * speed, ground_accel * delta)
	else:
		h = h.move_toward(Vector3.ZERO, ground_friction * delta)
	velocity.x = h.x
	velocity.z = h.z


## Quake-style air control: you can steer and strafe freely but never lose
## the speed you already have.
func _air_move(delta: float, control: float = 1.0) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var current := velocity.dot(wish_dir)
	var add_speed := speed - current
	if add_speed <= 0.0:
		return
	velocity += wish_dir * minf(air_accel * speed * control * delta, add_speed)


func _try_jump(on_floor: bool) -> void:
	if jump_buffer <= 0.0 or is_grappling or is_wall_running or is_dashing or is_mantling:
		return
	if on_floor or coyote_timer > 0.0:
		jump_buffer = 0.0
		coyote_timer = 0.0
		if slam_bounce_timer > 0.0:
			# Slam bounce: jump right after a slam lands to convert the fall into height.
			velocity.y = jump_velocity + slam_bounce_power
			slam_bounce_timer = 0.0
			Sfx.play("jump", -4.0, 0.7)
			Fx.shake(0.1)
		else:
			velocity.y = jump_velocity
			Sfx.play("jump", -8.0)
	elif air_jumps_left > 0 and not is_slamming:
		air_jumps_left -= 1
		jump_buffer = 0.0
		velocity.y = jump_velocity * 0.95
		if wish_dir != Vector3.ZERO:
			var h := maxf(Vector2(velocity.x, velocity.z).length(), speed)
			velocity.x = wish_dir.x * h
			velocity.z = wish_dir.z * h
		Fx.sparks(global_position + Vector3.DOWN, Vector3.DOWN, Color(0.6, 0.9, 1.0), 10, 5.0)
		Sfx.play("jump", -6.0, 1.3)


func _after_move(was_on_floor: bool, pre_velocity: Vector3) -> void:
	var on_floor := is_on_floor()
	just_landed = on_floor and not was_on_floor
	if not just_landed:
		return
	if is_slamming:
		_slam_land()
	elif pre_velocity.y < -6.0:
		land_dip = clampf(-pre_velocity.y * 0.012, 0.0, 0.25)
		Sfx.play("land", -10.0)


# --- SUBSYSTEMS ---

func _update_grapple_ui() -> void:
	grapple_in_range = grapple_ray.is_colliding() and grapple_cooldown <= 0.0


func _process_hitbox(delta: float) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	var target_height := crouch_height if (is_crouching or is_sliding) else stand_height
	if target_height > capsule.height and _ceiling_blocked():
		target_height = capsule.height # can't stand up under a low ceiling
	capsule.height = lerpf(capsule.height, target_height, minf(delta * 12.0, 1.0))
	# Shrink from the top so our feet stay on the ground.
	collision_shape.position.y = -(stand_height - capsule.height) * 0.5
	head.position.y = lerpf(head.position.y, collision_shape.position.y + capsule.height * 0.5 - 0.3, minf(delta * 12.0, 1.0))


func _ceiling_blocked() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.UP * (stand_height * 0.5 + 0.2), Layers.WORLD_MASK)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _process_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and dash_charges >= 1.0 and not is_dashing:
		dash_charges -= 1.0
		var dir := wish_dir
		if dir == Vector3.ZERO:
			dir = -global_transform.basis.z
			dir.y = 0.0
			dir = dir.normalized()
		dash_dir = dir
		is_dashing = true
		dash_timer = dash_time
		iframes = maxf(iframes, dash_time + 0.08)
		is_sliding = false
		is_crouching = false
		is_slamming = false
		if is_grappling:
			_end_grapple()
		Sfx.play("dash", -4.0)
		Fx.shake(0.05)
	if not is_dashing:
		return
	dash_timer -= delta
	velocity = dash_dir * dash_speed
	if jump_buffer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		# Dash-jump: carry the burst into a long, low jump.
		jump_buffer = 0.0
		coyote_timer = 0.0
		is_dashing = false
		velocity = dash_dir * dash_speed * 0.85
		velocity.y = jump_velocity * 0.85
		Sfx.play("jump", -6.0)
		return
	if dash_timer <= 0.0:
		is_dashing = false
		velocity = dash_dir * maxf(speed, dash_speed * 0.5)


func _process_slam(on_floor: bool) -> void:
	if not is_slamming:
		if Input.is_action_just_pressed("crouch") and not on_floor and not is_grappling and not is_wall_running and not is_dashing:
			is_slamming = true
			slam_start_y = global_position.y
			Sfx.play("dash", -6.0, 0.6)
		else:
			return
	velocity = Vector3(0.0, -slam_speed, 0.0)


func _slam_land() -> void:
	is_slamming = false
	var fall := maxf(slam_start_y - global_position.y, 0.0)
	var piledriver: bool = GameState.has_perk("piledriver")
	slam_bounce_power = clampf(fall * 0.7, 3.0, 20.0) * (1.4 if piledriver else 1.0)
	slam_bounce_timer = 0.3
	velocity.x = 0.0
	velocity.z = 0.0
	land_dip = 0.3
	Fx.shake(0.35)
	Sfx.play("slam")
	Fx.sparks(global_position + Vector3.DOWN, Vector3.UP, Color(0.9, 0.7, 0.4), 16, 8.0)
	if piledriver:
		Fx.hurt_enemies(global_position, 6.0, 30.0 + fall * 2.0, "slam", 0.6)
		Fx.flare(global_position + Vector3.DOWN * 0.8, Color(1.0, 0.6, 0.2), 10.0, 0.3)
	else:
		Fx.hurt_enemies(global_position, 3.0, 10.0, "slam", 0.6)


func _process_slide(delta: float, on_floor: bool) -> void:
	var floor_speed := Vector2(velocity.x, velocity.z).length()
	var holding := Input.is_action_pressed("crouch")

	# Start on press, or when landing with crouch already held (chains slams into slides).
	if on_floor and holding and not is_sliding and not is_crouching and not is_slamming and not is_dashing \
			and (Input.is_action_just_pressed("crouch") or just_landed):
		if floor_speed >= slide_speed_threshold or wish_dir != Vector3.ZERO:
			var dir := wish_dir
			if dir == Vector3.ZERO:
				dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
			if dir == Vector3.ZERO:
				dir = -transform.basis.z
			# Never slower than you were going — slides keep momentum.
			slide_velocity = dir * maxf(floor_speed, slide_boost * GameState.stat("slide_mult"))
			is_sliding = true
			Sfx.play("dash", -10.0, 0.5)
		else:
			is_crouching = true

	if is_sliding or is_crouching:
		var jumping := jump_buffer > 0.0 and on_floor
		if not holding or not on_floor or jumping:
			if is_sliding and jumping:
				# Slide-jump: launch out with all of the slide's speed.
				velocity.x = slide_velocity.x
				velocity.z = slide_velocity.z
				velocity.y = jump_velocity * 1.05
				jump_buffer = 0.0
				coyote_timer = 0.0
				Sfx.play("jump", -6.0)
			is_sliding = false
			is_crouching = false
			return

	if is_sliding:
		if wish_dir != Vector3.ZERO:
			var spd := slide_velocity.length()
			slide_velocity = slide_velocity.lerp(wish_dir * spd, minf(slide_steer * delta, 1.0)).normalized() * spd
		velocity.x = slide_velocity.x
		velocity.z = slide_velocity.z
		slide_velocity *= (1.0 - slide_decay * delta)
		if randf() < 0.3:
			Fx.sparks(global_position + Vector3.DOWN * 0.9, Vector3.UP - slide_velocity.normalized(), Color(1.0, 0.75, 0.3), 2, 3.0)
		if slide_velocity.length() < walk_speed * 0.6:
			is_sliding = false
			is_crouching = true


func _process_wall_run(delta: float, on_floor: bool) -> void:
	is_wall_running = false
	if on_floor or is_grappling or is_slamming or is_dashing:
		return
	var on_left := wall_ray_left.is_colliding()
	var on_right := wall_ray_right.is_colliding()
	if not (on_left or on_right) or input_dir.y >= 0.0:
		return
	var normal := wall_ray_left.get_collision_normal() if on_left else wall_ray_right.get_collision_normal()
	if absf(normal.y) > 0.3:
		return # that's a floor or ceiling, not a wall
	# Anti-spam: Only run if it's a different wall than the last one we jumped off
	if normal.distance_to(last_wall_normal) <= 0.1 or wall_run_timer > max_wall_run_time:
		return

	is_wall_running = true
	wall_side = -1 if on_left else 1
	wall_run_timer += delta

	# Calculate forward vector strictly along the wall
	var wall_forward := Vector3.UP.cross(normal).normalized()
	if wall_forward.dot(-transform.basis.z) < 0:
		wall_forward = -wall_forward # Ensure we go the way the player is facing
	var h_speed := maxf(Vector2(velocity.x, velocity.z).length(), wall_run_speed)
	velocity.x = wall_forward.x * h_speed - normal.x * 2.0 # small push keeps us stuck to the wall
	velocity.z = wall_forward.z * h_speed - normal.z * 2.0
	velocity.y = move_toward(velocity.y, -wall_run_gravity, delta * 12.0)

	if jump_buffer > 0.0:
		jump_buffer = 0.0
		velocity = wall_forward * h_speed * 0.85 + normal * wall_jump_force + Vector3.UP * jump_velocity
		last_wall_normal = normal # Lock this wall until we hit the floor
		air_jumps_left = int(GameState.stat("air_jumps"))
		is_wall_running = false
		Sfx.play("jump", -6.0, 1.15)


func _process_mantle(delta: float, on_floor: bool) -> void:
	if is_mantling:
		mantle_timer -= delta
		velocity = mantle_dir * walk_speed + Vector3.UP * mantle_force
		if mantle_timer <= 0.0:
			is_mantling = false
		return
	if on_floor or velocity.y < -15.0 or is_grappling or is_slamming or is_dashing or input_dir.y >= 0:
		return

	var space_state := get_world_3d().direct_space_state
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	# Wall at chest height...
	var chest_pos := global_position
	var chest_query := PhysicsRayQueryParameters3D.create(chest_pos, chest_pos + forward * 1.0, Layers.WORLD_MASK)
	if space_state.intersect_ray(chest_query).is_empty():
		return
	# ...but clear above our head = a ledge we can climb.
	var head_pos := global_position + Vector3(0, stand_height * 0.8, 0)
	var head_query := PhysicsRayQueryParameters3D.create(head_pos, head_pos + forward * 1.0, Layers.WORLD_MASK)
	if not space_state.intersect_ray(head_query).is_empty():
		return
	is_mantling = true
	mantle_timer = 0.18
	mantle_dir = forward


func _process_grapple(delta: float) -> void:
	grapple_ray.target_position = Vector3(0, 0, -GameState.stat("grapple_range"))

	if Input.is_action_just_pressed("grapple") and not is_grappling and grapple_cooldown <= 0.0 and grapple_ray.is_colliding():
		_start_grapple()
	if not is_grappling:
		return

	if grapple_enemy != null:
		if not is_instance_valid(grapple_enemy) or grapple_enemy.is_dead:
			_end_grapple()
			return
		grapple_target = grapple_enemy.chest()

	if jump_buffer > 0.0:
		# Jump-to-zip: controlled momentum boost toward the anchor (no moon jump)
		jump_buffer = 0.0
		var target_dir := (grapple_target - global_position).normalized()
		velocity += target_dir * 12.0
		velocity.y += 4.0
		if velocity.length() > max_grapple_launch_speed:
			velocity = velocity.normalized() * max_grapple_launch_speed
		_end_grapple()
		return
	if not Input.is_action_pressed("grapple"):
		_end_grapple()
		return

	_update_rope_visual()

	var to_target := grapple_target - global_position
	var current_distance := to_target.length()
	var dir_to_target := to_target / maxf(current_distance, 0.001)

	if grapple_enemy != null:
		# Heavy enemy: reel ourselves straight in.
		velocity = velocity.lerp(dir_to_target * grapple_speed, minf(8.0 * delta, 1.0))
		if current_distance < 2.5:
			velocity = dir_to_target * 6.0 + Vector3.UP * 5.0
			_end_grapple()
		return

	# Swing: pendulum gravity + a bit of air control
	if not is_on_floor():
		velocity.y -= gravity * swing_gravity_mult * delta
	_air_move(delta, 0.5)
	rope_length = maxf(rope_length - rope_reel_speed * delta, 2.0)

	# Centripetal Pull
	if current_distance > rope_length:
		var radial_velocity := velocity.dot(dir_to_target)
		if radial_velocity < 0:
			velocity -= dir_to_target * radial_velocity # Kill velocity going directly away from pivot
		# Spring tension to pull you in an arc
		velocity += dir_to_target * (current_distance - rope_length) * 45.0 * delta

	velocity.y = minf(velocity.y, 18.0)
	velocity.x *= 0.999 # Very light air resistance
	velocity.z *= 0.999


func _start_grapple() -> void:
	var collider := grapple_ray.get_collider()
	var point := grapple_ray.get_collision_point()
	Sfx.play("grapple", -4.0)
	grapple_enemy = null
	if collider is Enemy:
		var enemy := collider as Enemy
		if enemy.is_dead:
			return
		if enemy.is_light:
			# Light enemies get yanked to us instead.
			enemy.yank_toward(global_position + Vector3.UP, self)
			Fx.tracer(_rope_start(), point, Color(0.55, 0.38, 0.2), 0.04, 0.15)
			GameState.add_style("WHIPLASH", 10)
			grapple_cooldown = 0.35
			return
		grapple_enemy = enemy
	grapple_target = point
	rope_length = global_position.distance_to(point)
	is_grappling = true
	is_sliding = false
	is_crouching = false
	is_slamming = false
	grapple_line.visible = true
	_update_rope_visual()


func _end_grapple() -> void:
	is_grappling = false
	grapple_enemy = null
	grapple_line.visible = false
	grapple_cooldown = 0.15


func _rope_start() -> Vector3:
	return camera.global_transform * Vector3(-0.35, -0.3, -0.6)


func _update_rope_visual() -> void:
	var start: Vector3 = _rope_start()
	var length := start.distance_to(grapple_target)
	if length < 0.05:
		return
	var dir := (grapple_target - start) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	grapple_line.look_at_from_position((start + grapple_target) * 0.5, grapple_target, up)
	grapple_line.rotate_object_local(Vector3.RIGHT, PI / 2)
	var cylinder_mesh := grapple_line.mesh as CylinderMesh
	if cylinder_mesh:
		cylinder_mesh.height = length


func _process_punch() -> void:
	if not Input.is_action_just_pressed("punch") or punch_timer > 0.0:
		return
	punch_timer = punch_cooldown
	weapon_manager.play_punch()
	Sfx.play("punch", -4.0)

	var aim: Vector3 = -camera.global_transform.basis.z
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, camera.global_position + aim * 1.4)
	q.collision_mask = Layers.ENEMY | Layers.ENEMY_PROJECTILE | Layers.PLAYER_PROJECTILE
	q.collide_with_areas = true

	var did_parry := false
	var hit_enemy := false
	var seen := {}
	var aim_point: Vector3 = get_aim_point()
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c: Object = hit["collider"]
		if c == null or seen.has(c):
			continue
		seen[c] = true
		if c.has_method("parry"):
			var from: Vector3 = (c as Node3D).global_position
			if c.call("parry", self, (aim_point - from).normalized()):
				did_parry = true
		elif c is Enemy:
			var e := c as Enemy
			e.take_damage(punch_damage * GameState.stat("punch_mult"), e.chest(), aim, "punch")
			e.apply_knockback(aim * 10.0 + Vector3.UP * 3.0)
			hit_enemy = true

	if did_parry:
		heal(GameState.stat("parry_heal"))
		GameState.add_style("PARRY", 40)
		Sfx.play("parry")
		Fx.shake(0.3)
		Fx.hitstop(0.12, 0.02)
		parried.emit()
	elif hit_enemy:
		Fx.shake(0.15)
		Fx.hitstop(0.04)


## Where the crosshair is pointing in the world.
func get_aim_point(max_dist: float = 300.0) -> Vector3:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_transform.basis.z * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.HITSCAN_MASK)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return to
	return r["position"]


func _process_camera_effects(delta: float) -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var cam_pos := Vector3.ZERO
	if enable_head_bob and is_on_floor() and h_speed > 0.5 and not is_sliding and not is_dead:
		bob_time += delta * h_speed * bob_frequency * 0.5
		cam_pos.y = sin(bob_time) * bob_amplitude
		cam_pos.x = cos(bob_time * 0.5) * bob_amplitude
	else:
		bob_time = 0.0
		cam_pos.y = lerpf(camera.position.y + land_dip, 0.0, minf(delta * 10.0, 1.0))
		cam_pos.x = lerpf(camera.position.x, 0.0, minf(delta * 10.0, 1.0))
	land_dip = lerpf(land_dip, 0.0, minf(delta * 8.0, 1.0))
	camera.position = cam_pos - Vector3(0, land_dip, 0)

	var target_tilt := -input_dir.x * lean_amount
	if is_wall_running:
		target_tilt = deg_to_rad(-12.0) if wall_side < 0 else deg_to_rad(12.0)
	elif is_sliding:
		target_tilt += deg_to_rad(4.0)
	elif is_dead:
		target_tilt = deg_to_rad(30.0)
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, minf(delta * 10.0, 1.0))

	# Speed lines without the lines: widen the FOV as you go faster.
	var target_fov := base_fov + clampf((h_speed - walk_speed) * 0.7, 0.0, 22.0)
	if is_dashing:
		target_fov += 10.0
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 8.0, 1.0))

	var shake: float = Fx.trauma * Fx.trauma * shake_strength
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.25
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.25
	camera.rotation.z += randf_range(-1.0, 1.0) * shake * 0.03


# --- HEALTH ---

func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, knock: float = 0.0) -> void:
	if is_dead or iframes > 0.0:
		return
	health -= amount
	iframes = 0.2
	hurt.emit(amount)
	health_changed.emit(health, max_health)
	GameState.on_player_hurt(amount)
	Fx.shake(0.35)
	Sfx.play("hurt", -2.0)
	if knock > 0.0 and from_pos != Vector3.ZERO:
		var d := global_position - from_pos
		d.y = 0.0
		velocity += d.normalized() * knock + Vector3.UP * knock * 0.3
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var before := health
	health = minf(health + amount * GameState.stat("heal_mult"), max_health)
	if health > before:
		healed.emit(health - before)
		health_changed.emit(health, max_health)


func is_invulnerable() -> bool:
	return iframes > 0.0 or is_dead


## Called by explosions. Your own explosions only push you (rocket jumps!).
func apply_explosion(center: Vector3, radius: float, damage: float, from_player: bool) -> void:
	var d := global_position - center
	var dist := d.length()
	var dir := d / dist if dist > 0.01 else Vector3.UP
	var power := explosion_knockback * clampf(1.0 - dist / (radius * 1.5), 0.3, 1.0)
	velocity += dir * power + Vector3.UP * power * 0.4
	is_slamming = false
	is_sliding = false
	if not from_player:
		take_damage(damage * clampf(1.0 - dist / (radius * 1.3), 0.35, 1.0), center)


## Pushes the player (enemy lassos, knockback attacks).
func apply_knock(v: Vector3) -> void:
	if is_dead:
		return
	if is_grappling:
		_end_grapple()
	is_sliding = false
	is_slamming = false
	velocity += v


## Used by the old boost pickups: a temporary burst of top speed.
func apply_boost(amount: float) -> void:
	boost_speed = minf(boost_speed + amount, 15.0)


func _die() -> void:
	is_dead = true
	health = 0.0
	if is_grappling:
		_end_grapple()
	weapon_manager.visible = false
	Sfx.play("explosion", -4.0, 1.3)
	Fx.sparks(global_position, Vector3.UP, Color(1.0, 0.6, 0.2), 20, 8.0)
	Fx.shake(0.8)
	GameState.player_health = -1.0
	died.emit()


func _on_parts_changed() -> void:
	var old_max := max_health
	max_health = GameState.stat("max_health")
	if max_health > old_max:
		health += max_health - old_max
	health = minf(health, max_health)
	health_changed.emit(health, max_health)
