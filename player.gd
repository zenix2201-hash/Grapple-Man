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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void: #mouse look with vertical clamping
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void: #Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta # FIX 1: Subtract gravity over time instead of setting velocity.y = jump_velocity
	
	if Input.is_action_just_pressed("jump") and is_on_floor(): #Jump
		velocity.y = jump_velocity
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down") # FIX 2: Fixed input action names ("move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed) # FIX 3: Target velocity.z instead of velocity.y
	
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
