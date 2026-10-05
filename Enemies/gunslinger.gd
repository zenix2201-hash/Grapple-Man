extends Enemy
## Gunslinger: an outlaw robot. Keeps mid range, strafes, flashes, then fires
## a 3-round burst you can dodge or parry.

@export var preferred_min: float = 9.0
@export var preferred_max: float = 17.0
@export var shot_speed: float = 30.0
@export var shot_damage: float = 9.0

var _fire_t := 2.0
var _shots_left := 0
var _shot_gap := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _cowboy: RobotCowboyModel


func _init() -> void:
	display_name = "GUNSLINGER"
	max_health = 60.0
	move_speed = 5.0
	scrap_value = 6
	oil_drops = 2
	kill_style = 30
	body_color = Color(0.35, 0.36, 0.4)
	eye_color = Color(1.0, 0.2, 0.15)
	collision_radius = 0.45
	collision_height = 2.1


func _build_model() -> void:
	_cowboy = RobotCowboyModel.new()
	_cowboy.metal_color = body_color
	_cowboy.dark_metal_color = body_color.darkened(0.5)
	_cowboy.hat_color = Color(0.12, 0.1, 0.1)
	_cowboy.poncho_color = Color(0.3, 0.22, 0.18)
	_cowboy.bandana_color = Color(0.1, 0.1, 0.12)
	_cowboy.eye_color = eye_color
	model.add_child(_cowboy)
	_materials.append_array(_cowboy.materials)
	_fire_t = randf_range(1.0, 2.5)


func _ai(delta: float) -> void:
	var dist: float = dist_to_player()
	var flat: Vector3 = flat_dir_to_player()
	face(flat, delta, 8.0)

	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.8)
		_strafe = -_strafe
	var side := flat.cross(Vector3.UP) * _strafe
	var dir := side * 0.8
	if dist > preferred_max:
		dir += flat
	elif dist < preferred_min:
		dir -= flat
	dir += separation() * 0.5
	var spd := move_speed * (0.4 if _shots_left > 0 else 1.0)
	ground_move(dir.normalized(), spd, delta)

	var sees: bool = can_see_player()
	_fire_t -= delta
	if _shots_left > 0:
		_shot_gap -= delta
		if _shot_gap <= 0.0 and _telegraph <= 0.0:
			_shot_gap = 0.13
			_shots_left -= 1
			var from: Vector3 = _muzzle_pos()
			shoot(from, lead_target(from, shot_speed) - from, shot_speed, shot_damage, Color(1.0, 0.8, 0.25), 0.18)
	elif _fire_t <= 0.0 and sees and dist < 35.0:
		_fire_t = randf_range(2.0, 3.0)
		_shots_left = 3
		_shot_gap = 0.0
		telegraph(0.5, _muzzle_pos())
	_cowboy.aiming = _shots_left > 0 or _telegraph > 0.0


func _animate(_delta: float) -> void:
	_cowboy.move_speed = Vector2(velocity.x, velocity.z).length()


func _muzzle_pos() -> Vector3:
	return global_transform * Vector3(0.34, 1.55, -0.8)
