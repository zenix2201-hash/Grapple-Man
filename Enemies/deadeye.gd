extends Enemy
## Deadeye: long-range sniper. A red laser tracks you, turns white and locks,
## then fires a heavy instant shot along it. Dash (i-frames) or break line
## of sight when the laser goes white.

@export var aim_time: float = 1.6
@export var lock_time: float = 0.4
@export var shot_damage: float = 30.0

enum State { REPOSITION, AIM, LOCK, COOLDOWN }

var state := State.REPOSITION
var state_t := 1.0
var _aim_point := Vector3.ZERO
var _locked_dir := Vector3.FORWARD
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D
var _laser_mesh: BoxMesh
var _move_dir := Vector3.ZERO


func _init() -> void:
	display_name = "DEADEYE"
	max_health = 45.0
	move_speed = 4.0
	scrap_value = 8
	oil_drops = 2
	kill_style = 40
	body_color = Color(0.3, 0.38, 0.32)
	eye_color = Color(1.0, 0.1, 0.1)
	collision_radius = 0.4
	collision_height = 2.4


func _build_model() -> void:
	var dark := body_color.darkened(0.5)
	add_part(PSX.box(Vector3(0.12, 1.0, 0.12)), dark, Vector3(-0.15, 0.5, 0))
	add_part(PSX.box(Vector3(0.12, 1.0, 0.12)), dark, Vector3(0.15, 0.5, 0))
	add_part(PSX.box(Vector3(0.45, 0.8, 0.3)), body_color, Vector3(0, 1.4, 0))
	add_part(PSX.cyl(0.12, 0.38, 0.5, 6), Color(0.25, 0.2, 0.15), Vector3(0, 1.55, 0)) # duster coat
	add_part(PSX.box(Vector3(0.26, 0.3, 0.28)), body_color, Vector3(0, 2.0, 0))
	add_part(PSX.cyl(0.32, 0.32, 0.03, 8), Color(0.15, 0.12, 0.1), Vector3(0, 2.17, 0)) # flat hat
	add_part(PSX.cyl(0.15, 0.17, 0.14, 8), Color(0.15, 0.12, 0.1), Vector3(0, 2.25, 0))
	add_eye(PSX.sphere(0.07, 6), Vector3(0.06, 2.02, -0.15))
	# Long rifle held at the shoulder.
	add_part(PSX.box(Vector3(0.07, 0.1, 1.3)), dark, Vector3(0.22, 1.75, -0.5))
	add_part(PSX.cyl(0.05, 0.05, 0.25, 6), dark, Vector3(0.22, 1.85, -0.35), Vector3(90, 0, 0)) # scope

	_laser_mesh = BoxMesh.new()
	_laser_mesh.size = Vector3(0.025, 0.025, 1.0)
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.albedo_color = Color(1.0, 0.1, 0.1)
	_laser_mesh.material = _laser_mat
	_laser = MeshInstance3D.new()
	_laser.mesh = _laser_mesh
	_laser.top_level = true
	_laser.visible = false
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser)


func _ai(delta: float) -> void:
	var dist: float = dist_to_player()
	var flat: Vector3 = flat_dir_to_player()
	state_t -= delta
	match state:
		State.REPOSITION:
			_laser.visible = false
			if _move_dir == Vector3.ZERO or is_on_wall():
				var side := flat.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
				_move_dir = (side - flat * (1.0 if dist < 14.0 else -0.3)).normalized()
			ground_move(_move_dir, move_speed * (1.6 if dist < 8.0 else 1.0), delta)
			face(flat, delta, 6.0)
			if state_t <= 0.0 and can_see_player(_muzzle()):
				state = State.AIM
				state_t = aim_time
				_aim_point = player_chest() + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2))
				Sfx.play_at("laser", chest(), -8.0, 0.8)
		State.AIM:
			ground_move(Vector3.ZERO, 0.0, delta, 40.0)
			face(flat, delta, 10.0)
			# The laser lags a little behind you — keep moving.
			_aim_point = _aim_point.lerp(player_chest(), minf(3.5 * delta, 1.0))
			_laser_mat.albedo_color = Color(1.0, 0.1, 0.1)
			_update_laser((_aim_point - _muzzle()).normalized())
			if not can_see_player(_muzzle()):
				state = State.REPOSITION
				state_t = 0.8
			elif state_t <= 0.0:
				state = State.LOCK
				state_t = lock_time
				_locked_dir = (_aim_point - _muzzle()).normalized()
				telegraph(lock_time, _muzzle())
		State.LOCK:
			ground_move(Vector3.ZERO, 0.0, delta, 40.0)
			var blink := 0.5 + 0.5 * sin(_time * 50.0)
			_laser_mat.albedo_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.3), blink)
			_update_laser(_locked_dir)
			if state_t <= 0.0:
				_fire()
				state = State.COOLDOWN
				state_t = 1.2
		State.COOLDOWN:
			_laser.visible = false
			ground_move(Vector3.ZERO, 0.0, delta)
			if state_t <= 0.0:
				state = State.REPOSITION
				state_t = randf_range(1.0, 2.0)
				_move_dir = Vector3.ZERO


func _muzzle() -> Vector3:
	return global_transform * Vector3(0.22, 1.75, -1.2)


func _laser_end(dir: Vector3) -> Dictionary:
	var from: Vector3 = _muzzle()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, Layers.WORLD_MASK | Layers.PLAYER)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"point": from + dir * 200.0, "collider": null}
	return {"point": r["position"], "collider": r["collider"]}


func _update_laser(dir: Vector3) -> void:
	var from: Vector3 = _muzzle()
	var end: Vector3 = _laser_end(dir)["point"]
	var length := from.distance_to(end)
	if length < 0.1:
		_laser.visible = false
		return
	_laser.visible = true
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	_laser.look_at_from_position((from + end) * 0.5, end, up)
	_laser.scale = Vector3(1.0, 1.0, length)


func _fire() -> void:
	_laser.visible = false
	var from: Vector3 = _muzzle()
	var res: Dictionary = _laser_end(_locked_dir)
	var end: Vector3 = res["point"]
	var target: Object = res["collider"]
	Fx.tracer(from, end, Color(1.0, 0.9, 0.8), 0.12, 0.2)
	Fx.flare(from, Color(1.0, 0.8, 0.5), 1.0, 0.15)
	Sfx.play_at("charge_shot", from, 0.0, 1.3)
	if target is Player:
		(target as Player).take_damage(shot_damage * GameState.enemy_damage_mult(), from, 10.0)
	else:
		Fx.sparks(end, -_locked_dir, Color(1.0, 0.8, 0.5), 10, 6.0)


func _on_death(_source: String) -> void:
	_laser.visible = false
