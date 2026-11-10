extends Weapon


@export var slash_reach: float = 1.8 ## How far in front of the camera the hit sphere sits
@export var slash_radius: float = 1.7
@export var slash_knockback: float = 9.0
@export var lunge_speed: float = 32.0
@export var lunge_time: float = 0.2
@export var lunge_damage: float = 45.0
@export var lunge_cooldown: float = 1.2

var _model: Node3D
var _swing_side := 1.0
var _swing_tween: Tween
var _lunge_timer := 0.0
var _lunge_cd := 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_hit: Dictionary = {}

const REST_ROT := Vector3(-30, 0, -15)


func _ready() -> void:
	_build_model()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_lunge_cd = maxf(_lunge_cd - delta, 0.0)
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
		_process_lunge()


func attack() -> void:
	_play_swing()
	Sfx.play("slash", -2.0, 1.0, 0.15)

	var aim: Vector3 = aim_forward()
	var center: Vector3 = aim_origin() + aim * slash_reach
	var mask := Layers.ENEMY | Layers.ENEMY_PROJECTILE | Layers.PLAYER_PROJECTILE
	var did_parry := false
	var hit_any := false
	var aim_point: Vector3 = player.get_aim_point() if player else center + aim * 50.0
	for c in _overlap(center, slash_radius, mask):
		if c.has_method("parry"):
			var from: Vector3 = (c as Node3D).global_position
			if c.call("parry", player, (aim_point - from).normalized()):
				did_parry = true
		elif c is Enemy:
			_cut(c as Enemy, damage, aim, "sword")
			hit_any = true

	if did_parry:
		if player:
			player.heal(GameState.stat("parry_heal"))
			player.parried.emit()
		GameState.add_style("DEFLECT", 40)
		Sfx.play("parry")
		Fx.shake(0.3)
		Fx.hitstop(0.12, 0.02)
	elif hit_any:
		Fx.shake(0.12)
		Fx.hitstop(0.05)


func alt_attack_pressed() -> void:
	if _lunge_cd > 0.0 or not visible or player == null:
		return
	_lunge_cd = lunge_cooldown
	_lunge_timer = lunge_time
	_lunge_hit.clear()
	_lunge_dir = aim_forward()
	player.apply_knock(_lunge_dir * lunge_speed - player.velocity)
	player.iframes = maxf(player.iframes, lunge_time + 0.05)
	Sfx.play("dash", -4.0, 1.3)
	_play_swing(true)
	if manager:
		manager.kick(0.2)


func unequip() -> void:
	_lunge_timer = 0.0
	super.unequip()


## Keeps the player flying forward and cuts anything they pass through.
func _process_lunge() -> void:
	if player == null or player.is_dead:
		_lunge_timer = 0.0
		return
	player.velocity = _lunge_dir * lunge_speed
	var center: Vector3 = player.global_position + Vector3.UP + _lunge_dir * 0.8
	for c in _overlap(center, 1.6, Layers.ENEMY):
		var e := c as Enemy
		if e == null or _lunge_hit.has(e):
			continue
		_lunge_hit[e] = true
		_cut(e, lunge_damage, _lunge_dir, "lunge")
		Fx.hitstop(0.04)
		Fx.shake(0.15)
	if _lunge_timer <= 0.0:
		player.velocity = _lunge_dir * lunge_speed * 0.45


func _cut(e: Enemy, dmg: float, dir: Vector3, source: String) -> void:
	if e.is_dead:
		return
	var crit: bool = randf() < GameState.stat("crit_chance")
	var final_damage: float = dmg * GameState.stat("damage_mult") * (2.0 if crit else 1.0)
	var hit_pos: Vector3 = e.chest()
	e.take_damage(final_damage, hit_pos, dir, source)
	GameState.hitmarker.emit(crit)
	Fx.sparks(hit_pos, -dir, Color(1.0, 1.0, 0.85), 10, 8.0)
	if not e.is_dead:
		e.apply_knockback(dir * slash_knockback + Vector3.UP * 2.5)


func _overlap(center: Vector3, radius: float, mask: int) -> Array[Object]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = mask
	q.collide_with_areas = true
	if player:
		var ex: Array[RID] = [player.get_rid()]
		q.exclude = ex
	var out: Array[Object] = []
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c: Object = hit["collider"]
		if c != null and not out.has(c):
			out.append(c)
	return out


func _play_swing(stab: bool = false) -> void:
	if _model == null:
		return
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_model.rotation_degrees = REST_ROT
	_model.position = Vector3.ZERO
	_swing_tween = create_tween()
	if stab:
		_swing_tween.set_parallel(true)
		_swing_tween.tween_property(_model, "rotation_degrees", Vector3(-85, 0, 0), 0.06)
		_swing_tween.tween_property(_model, "position", Vector3(-0.2, 0.1, -0.35), 0.06)
		_swing_tween.chain().set_parallel(true)
		_swing_tween.tween_property(_model, "rotation_degrees", REST_ROT, lunge_time + 0.1)
		_swing_tween.tween_property(_model, "position", Vector3.ZERO, lunge_time + 0.1)
		return
	# Alternate forehand / backhand slashes.
	_swing_side = -_swing_side
	var wind := Vector3(-10, -40 * _swing_side, 35 * _swing_side)
	var follow := Vector3(-80, 70 * _swing_side, -50 * _swing_side)
	_model.rotation_degrees = wind
	_swing_tween.tween_property(_model, "rotation_degrees", follow, 0.08).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_model, "rotation_degrees", REST_ROT, 0.22).set_ease(Tween.EASE_IN_OUT)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	_model.rotation_degrees = REST_ROT
	add_child(_model)
	var steel: ShaderMaterial = PSX.material(Color(0.78, 0.8, 0.85), true)
	var edge: ShaderMaterial = PSX.material(Color(0.95, 0.95, 1.0))
	var leather: ShaderMaterial = PSX.material(Color(0.35, 0.18, 0.08), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	PSX.part(_model, PSX.cyl(0.024, 0.026, 0.2, 6), leather, Vector3(0, -0.06, 0)) # grip
	PSX.part(_model, PSX.sphere(0.035, 6), brass, Vector3(0, -0.17, 0)) # pommel
	PSX.part(_model, PSX.box(Vector3(0.2, 0.03, 0.05)), brass, Vector3(0, 0.05, 0)) # crossguard
	PSX.part(_model, PSX.torus(0.05, 0.065), brass, Vector3(0, -0.04, 0.05), Vector3(90, 0, 0)) # knuckle bow
	PSX.part(_model, PSX.box(Vector3(0.045, 0.72, 0.012)), steel, Vector3(0, 0.42, 0)) # blade
	PSX.part(_model, PSX.box(Vector3(0.008, 0.7, 0.014)), edge, Vector3(0.024, 0.42, 0)) # edge
	PSX.part(_model, PSX.prism(Vector3(0.045, 0.1, 0.012)), steel, Vector3(0, 0.83, 0)) # tip
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
