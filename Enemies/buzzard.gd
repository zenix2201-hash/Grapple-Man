extends Enemy
## Buzzard drone: flies circles around you and lobs slow homing orbs.
## Those orbs are perfect parry practice.

@export var orbit_radius: float = 10.0
@export var hover_height: float = 5.0
@export var orb_speed: float = 11.0
@export var orb_damage: float = 15.0

var _fire_t := 3.0
var _angle := 0.0
var _dir := 1.0
var _rotor: Node3D
var _winding := false


func _init() -> void:
	display_name = "BUZZARD"
	max_health = 28.0
	move_speed = 7.0
	scrap_value = 5
	oil_drops = 1
	kill_style = 30
	flying = true
	body_color = Color(0.7, 0.6, 0.35)
	eye_color = Color(1.0, 0.5, 0.1)
	collision_radius = 0.6
	collision_height = 1.2


func _build_model() -> void:
	add_part(PSX.sphere(0.5, 8), body_color, Vector3(0, 0.6, 0))
	add_part(PSX.cyl(0.55, 0.55, 0.12, 8), body_color.darkened(0.4), Vector3(0, 0.6, 0))
	add_part(PSX.cyl(0.05, 0.05, 0.5, 4), body_color.darkened(0.5), Vector3(0, 1.05, 0))
	add_eye(PSX.sphere(0.16, 6), Vector3(0, 0.55, -0.42))
	add_part(PSX.box(Vector3(0.12, 0.35, 0.12)), body_color.darkened(0.5), Vector3(-0.3, 0.15, 0), Vector3(0, 0, -20))
	add_part(PSX.box(Vector3(0.12, 0.35, 0.12)), body_color.darkened(0.5), Vector3(0.3, 0.15, 0), Vector3(0, 0, 20))
	_rotor = pivot(Vector3(0, 1.3, 0))
	add_part(PSX.box(Vector3(1.6, 0.03, 0.14)), Color(0.25, 0.25, 0.25), Vector3.ZERO, Vector3.ZERO, _rotor)
	add_part(PSX.box(Vector3(0.14, 0.03, 1.6)), Color(0.25, 0.25, 0.25), Vector3.ZERO, Vector3.ZERO, _rotor)
	_angle = randf() * TAU
	_dir = 1.0 if randf() < 0.5 else -1.0
	_fire_t = randf_range(1.5, 3.5)


func _ai(delta: float) -> void:
	_angle += delta * _dir * move_speed / orbit_radius
	var target: Vector3 = player.global_position + Vector3(cos(_angle), 0.0, sin(_angle)) * orbit_radius
	target.y = player.global_position.y + hover_height + sin(_time * 1.3) * 1.0
	var desired: Vector3 = (target - global_position).limit_length(1.0) * move_speed + separation(3.0) * 2.0
	velocity = velocity.lerp(desired, minf(3.0 * delta, 1.0))
	face(player.global_position - global_position, delta, 6.0)
	if is_on_wall():
		_dir = -_dir

	_fire_t -= delta
	if _winding and _telegraph <= 0.0:
		_winding = false
		var from: Vector3 = chest() + (player_chest() - chest()).normalized() * 0.8
		shoot(from, player_chest() - from, orb_speed, orb_damage, Color(1.0, 0.45, 0.1), 0.38, 1.4)
	elif _fire_t <= 0.0 and can_see_player():
		_fire_t = randf_range(2.8, 4.0)
		_winding = true
		telegraph(0.6)


func _animate(delta: float) -> void:
	_rotor.rotate_y(delta * 25.0)
	model.rotation.z = lerpf(model.rotation.z, -velocity.dot(global_transform.basis.x) * 0.05, minf(delta * 5.0, 1.0))
