extends Weapon

@export var chain_count: int = 3 ## Extra enemies a bolt can jump to
@export var chain_range: float = 9.0
@export var chain_falloff: float = 0.75 ## Damage multiplier per jump
@export var nova_radius: float = 6.0
@export var nova_damage: float = 25.0
@export var nova_stun: float = 1.2
@export var nova_cooldown: float = 4.0

const BOLT_COLOR := Color(0.55, 0.85, 1.0)

var _nova_cd := 0.0
var _muzzle: Marker3D
var _orb: MeshInstance3D


func _ready() -> void:
	_build_model()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_nova_cd = maxf(_nova_cd - delta, 0.0)


func _process(_delta: float) -> void:
	if _orb:
		var ready_amt: float = 1.0 - _nova_cd / nova_cooldown
		_orb.scale = Vector3.ONE * (0.7 + ready_amt * 0.3 + randf() * 0.15)


func attack() -> void:
	var from: Vector3 = aim_origin()
	var dir: Vector3 = aim_forward()
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_range, Layers.HITSCAN_MASK, exclude)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = from + dir * max_range
	var target: Enemy = null
	if not r.is_empty():
		end = r["position"]
		target = r["collider"] as Enemy
		if target == null:
			Fx.sparks(end, r["normal"], BOLT_COLOR, 6, 5.0)

	_bolt(_muzzle.global_position, end)
	muzzle_flash(_muzzle, BOLT_COLOR, 0.35)
	Sfx.play("zap", -4.0)
	Fx.shake(0.08)
	if target != null:
		_chain(target, dir)


func alt_attack_pressed() -> void:
	if _nova_cd > 0.0 or not visible or player == null:
		return
	_nova_cd = nova_cooldown
	var center: Vector3 = player.global_position + Vector3.UP
	var count: int = Fx.hurt_enemies(center, nova_radius,
		nova_damage * GameState.stat("damage_mult"), "tesla", nova_stun)
	for i in 10:
		var a := TAU * i / 10.0 + randf() * 0.4
		var out := Vector3(cos(a), randf_range(-0.3, 0.4), sin(a)).normalized() * nova_radius
		_bolt(center, center + out, 0.06)
	Fx.flare(center, BOLT_COLOR, nova_radius * 0.6, 0.25)
	Sfx.play("zap", 0.0, 0.6)
	Fx.shake(0.3)
	if manager:
		manager.kick(0.4)
	if count >= 3:
		GameState.add_style("SHOCK THERAPY", 25)


## The bolt hits `first`, then jumps to the closest enemy it hasn't hit yet.
func _chain(first: Enemy, dir: Vector3) -> void:
	var hit: Array[Enemy] = [first]
	var current_pos: Vector3 = first.chest()
	var dmg: float = damage
	_shock(first, dmg, dir)
	for i in chain_count:
		var next := _nearest_unhit(current_pos, hit)
		if next == null:
			break
		dmg *= chain_falloff
		var next_pos: Vector3 = next.chest()
		_bolt(current_pos, next_pos)
		_shock(next, dmg, (next_pos - current_pos).normalized())
		hit.append(next)
		current_pos = next_pos
	if hit.size() >= 3:
		GameState.add_style("CHAIN LIGHTNING", 10 * hit.size())


func _shock(e: Enemy, dmg: float, dir: Vector3) -> void:
	if e.is_dead:
		return
	var crit: bool = randf() < GameState.stat("crit_chance")
	var final_damage: float = dmg * GameState.stat("damage_mult") * (2.0 if crit else 1.0)
	var pos: Vector3 = e.chest()
	e.take_damage(final_damage, pos, dir, "tesla")
	GameState.hitmarker.emit(crit)
	Fx.sparks(pos, -dir, BOLT_COLOR, 8, 6.0)


func _nearest_unhit(from: Vector3, exclude: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_dist := chain_range
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_dead or exclude.has(e):
			continue
		var d: float = from.distance_to(e.chest())
		if d >= best_dist:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, e.chest(), Layers.WORLD_MASK)
		if space.intersect_ray(q).is_empty():
			best = e
			best_dist = d
	return best


## Jagged lightning made of short tracer segments.
func _bolt(a: Vector3, b: Vector3, width: float = 0.04) -> void:
	var segments := 7
	var length: float = a.distance_to(b)
	var jitter: float = minf(length * 0.06, 0.6)
	var prev := a
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p: Vector3 = a.lerp(b, t)
		if i < segments:
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		Fx.tracer(prev, p, BOLT_COLOR, width, 0.1)
		prev = p
	Fx.tracer(a, b, Color(0.9, 0.97, 1.0), width * 0.4, 0.06) # bright core
	Fx.flare(b, BOLT_COLOR, 0.5, 0.12)


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var copper: ShaderMaterial = PSX.material(Color(0.8, 0.45, 0.25), true)
	var dark: ShaderMaterial = PSX.material(Color(0.2, 0.2, 0.24), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	var wood: ShaderMaterial = PSX.material(Color(0.45, 0.25, 0.12), true)
	PSX.part(model, PSX.box(Vector3(0.08, 0.1, 0.22)), dark, Vector3(0, 0, 0.06)) # body
	PSX.part(model, PSX.box(Vector3(0.055, 0.18, 0.08)), wood, Vector3(0, -0.13, 0.13), Vector3(-20, 0, 0)) # grip
	PSX.part(model, PSX.cyl(0.02, 0.02, 0.32, 6), dark, Vector3(0, 0.02, -0.2), Vector3(90, 0, 0)) # rod
	for i in 4: # copper coils along the rod
		PSX.part(model, PSX.torus(0.025, 0.05), copper, Vector3(0, 0.02, -0.08 - i * 0.07), Vector3(90, 0, 0))
	PSX.part(model, PSX.box(Vector3(0.1, 0.02, 0.02)), brass, Vector3(0, 0.02, -0.37)) # prongs
	_orb = PSX.part(model, PSX.sphere(0.035, 6), PSX.glow(BOLT_COLOR), Vector3(0, 0.02, -0.4))
	PSX.part(model, PSX.cyl(0.03, 0.03, 0.08, 6), PSX.glow(Color(0.4, 0.75, 1.0)), Vector3(0, 0.08, 0.06)) # battery glow
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.02, -0.42)
	add_child(_muzzle)
