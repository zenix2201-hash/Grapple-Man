extends CharacterBody3D

#Movement Settings
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003 # Fixed sensitivity scale (0.03 was too fast)

#Camera Bobbing
@export var enable_head_bob: bool = true
@export var bob_frequency: float = 2.4 #speed of bob 
@export var bob_amplitude: float = 0.06 #up/down
@export var lean_amount: float = 0.03 #cam tilt

var bob_time: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $CollisionShape3D/head
@onready var camera: Camera3D = $CollisionShape3D/head/Camera3D

@export var grapple_speed: float = 35.0
@onready var grapple_ray: RayCast3D = $CollisionShape3D/head/Camera3D/Grapple_hook


#Crouching / sliding
@export var slide_speed_threshold: float = 7.0 # Must be moving faster than this to slide
@export var slide_boost: float = 14.0

var is_sliding: bool = false
var is_crouching: bool = false
var slide_velocity: Vector3 = Vector3.ZERO

#grapple
var is_grappling: bool = false
var grapple_target: Vector3 = Vector3.ZERO

#Grapple Line
@onready var grapple_line: MeshInstance3D = $CollisionShape3D/head/Camera3D/Grapple_Line

#Sprint
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.8

#Speed Counter
@onready var speed_counter_h = $CanvasLayer/speed_counter
@onready var speed_counter_v = $CanvasLayer/speed_counter_v

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void: #mouse look with vertical clamping
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process_slide(delta: float) -> void:
	var floor_speed = Vector2(velocity.x, velocity.z).length()
	
	# Check for Crouch/Slide input press
	if Input.is_action_just_pressed("crouch") and is_on_floor():
		if not is_sliding and not is_crouching:
			# If going fast (sprinting/momentum), trigger a slide!
			if floor_speed >= slide_speed_threshold:
				var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
				var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
				
				if dir == Vector3.ZERO:
					slide_velocity = -transform.basis.z * floor_speed
				else:
					slide_velocity = dir * max(floor_speed, sprint_speed)
					
				slide_velocity = slide_velocity.normalized() * slide_boost
				is_sliding = true
			else:
				# Otherwise, just normal low-speed crouch
				is_crouching = true

	# Handle exit conditions when letting go of crouch or jumping
	if is_sliding or is_crouching:
		if not Input.is_action_pressed("crouch") or not is_on_floor() or Input.is_action_just_pressed("jump"):
			if is_sliding and Input.is_action_just_pressed("jump") and is_on_floor():
				# Slide-jump feature: convert slide momentum into an explosive jump
				velocity = slide_velocity
				velocity.y = jump_velocity
				
			is_sliding = false
			is_crouching = false
			return

	# Handle active sliding physics
	if is_sliding:
		velocity.x = slide_velocity.x
		velocity.z = slide_velocity.z
		
		# Friction decay over time
		slide_velocity *= (1.0 - 2.5 * delta)
		
		# Stop sliding if speed drops below walk speed threshold
		if Vector2(slide_velocity.x, slide_velocity.z).length() < walk_speed:
			is_sliding = false
			is_crouching = true # Transition smoothly into a normal crouch if holding key

func _physics_process(delta: float) -> void: #Gravity
	
	# 1. Handle Slide & Crouch Check
	_process_slide(delta)
	
	# Handle Sprint Input (switches speed based on shift/sprint key) - Bypassed while sliding
	if not is_sliding:
		if Input.is_action_pressed("Sprint") and is_on_floor():
			speed = sprint_speed
		else:
			speed = walk_speed
		
	var current_speed_h = Vector2(velocity.x, velocity.z).length()
	var current_speed_v = velocity.y
	
	# Standard gravity & jumping (bypassed while grappling or sliding)
	if not is_grappling and not is_sliding:
		if not is_on_floor():
			velocity.y -= gravity * delta 
		
		if Input.is_action_just_pressed("jump") and is_on_floor(): #Jump
			velocity.y = jump_velocity
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down") 
	
	# Standard WASD movement (bypassed while grappling or sliding to protect momentum)
	if not is_grappling and not is_sliding:
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			
	speed_counter_h.text = "H Speed " + str(round(current_speed_h))
	speed_counter_v.text = "V Speed " + str(round(current_speed_v))
	
	_process_wall_run(delta)
	_process_grapple(delta)
	_process_wall_run(delta)
	move_and_slide()
	_process_camera_effects(delta, input_dir)

func _process_camera_effects(delta: float, input_dir: Vector2) -> void:
	if enable_head_bob and is_on_floor() and velocity.length() > 0.1:
		bob_time += delta * velocity.length() * bob_frequency
		camera.transform.origin.y = sin(bob_time) * bob_amplitude
		camera.transform.origin.x = cos(bob_time * 0.5) * bob_amplitude
	else:
		bob_time = 0.0
		camera.transform.origin.y = lerp(camera.transform.origin.y, 0.0, delta * 10.0)
		camera.transform.origin.x = lerp(camera.transform.origin.x, 0.0, delta * 10.0)

	var target_tilt = -input_dir.x * lean_amount
	camera.rotation.z = lerp(camera.rotation.z, target_tilt, delta * 10.0)
	
	#Wall Running
@export var wall_run_gravity: float = 2.0
@export var wall_jump_force: float = 6.0

@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight

var is_wall_running: bool = false

func _process_wall_run(delta: float) -> void:
	var on_left: bool = wall_ray_left.is_colliding()
	var on_right: bool = wall_ray_right.is_colliding()
	
	if (on_left or on_right) and not is_on_floor() and velocity.y <0:
		is_wall_running = true
		velocity.y = move_toward(velocity.y, -wall_run_gravity, delta * 10.0)
		
		if Input.is_action_just_pressed("jump"):
			var normal = wall_ray_left.get_collision_normal() if on_left else wall_ray_right.get_collision_normal()
			velocity = (normal + Vector3.UP).normalized() * wall_jump_force
			is_wall_running = false
			
	else:
		is_wall_running = false

#Grapple
var rope_length: float = 0.0

func _process_grapple(delta: float) -> void:
	if Input.is_action_just_pressed("grapple"):
		if grapple_ray.is_colliding():
			grapple_target = grapple_ray.get_collision_point()
			rope_length = global_position.distance_to(grapple_target)
			is_grappling = true
			grapple_line.visible = true
			
	# If you release grapple OR press jump while grappling, handle exit
	if Input.is_action_just_released("grapple") or (is_grappling and Input.is_action_just_pressed("jump")):
		
		# Jump-to-zip: Blasts you straight toward the hook when you press jump mid-swing
		if is_grappling and Input.is_action_just_pressed("jump"):
			var target_dir = (grapple_target - global_position).normalized()
			velocity = target_dir * 45.0 # High-speed launch directly to the anchor
			
		is_grappling = false
		grapple_line.visible = false
		return
		
	if is_grappling:
		# Keep visual line offsets
		var forward_offset = grapple_ray.global_transform.basis.z * -0.5
		var side_offset = grapple_ray.global_transform.basis.x * 0.4 
		var start_pos = grapple_ray.global_position + forward_offset + side_offset
		
		# --- VISUAL LINE CODE ---
		grapple_line.rotation = Vector3.ZERO
		grapple_line.global_position = (start_pos + grapple_target) / 2.0
		grapple_line.look_at(grapple_target, Vector3.UP)
		grapple_line.rotate_object_local(Vector3.RIGHT, PI / 2)
		
		var cylinder_mesh: CylinderMesh = grapple_line.mesh as CylinderMesh
		if cylinder_mesh:
			cylinder_mesh.height = start_pos.distance_to(grapple_target)
		# ------------------------
			
		# --- MOMENTUM-PRESERVING SWING PHYSICS ---
		var to_target = grapple_target - global_position
		var current_distance = to_target.length()
		var dir_to_target = to_target.normalized()
		
		# Balanced asymmetric gravity
		if not is_on_floor():
			if velocity.y < 0:
				velocity.y -= 35.0 * delta # Heavy falling gravity for speed
			else:
				velocity.y -= 28.0 * delta # Strong upward gravity to arc you down
				
		# Rope constraint tension force: redirects your existing run/jump speed into an arc
		if current_distance > rope_length:
			var radial_velocity = velocity.dot(dir_to_target)
			if radial_velocity < 0:
				velocity -= dir_to_target * radial_velocity
			velocity += dir_to_target * (current_distance - rope_length) * 40.0 * delta
			
		# Cap maximum upward velocity so it doesn't rocket you
		if velocity.y > 15.0:
			velocity.y = 15.0
			
		# Lower friction so your sprint/jump momentum carries far without dying out instantly
		velocity.x *= 0.998
		velocity.z *= 0.998
