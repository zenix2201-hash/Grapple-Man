extends Node
## Autoload "Fx": game feel helpers — screen shake, hitstop, sparks, tracers,
## explosions, gibs and pickup drops.

var trauma := 0.0 ## 0..1, read by the player camera for screen shake.

var _hitstop_active := false
var _particle_mesh: BoxMesh


func _process(delta: float) -> void:
	trauma = maxf(trauma - delta * 1.8, 0.0)


func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Briefly freezes time so big hits feel heavy.
func hitstop(duration: float = 0.06, time_scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func _root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root


func _fade_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m


func sparks(pos: Vector3, normal: Vector3, color: Color = Color(1.0, 0.8, 0.35), amount: int = 8, speed: float = 6.0) -> void:
	if _particle_mesh == null:
		_particle_mesh = BoxMesh.new()
		_particle_mesh.size = Vector3.ONE * 0.07
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.vertex_color_use_as_albedo = true
		_particle_mesh.material = pm
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount, 1)
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = normal if normal.length_squared() > 0.001 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.mesh = _particle_mesh
	p.color = color
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.5), width: float = 0.03, life: float = 0.08) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	var mat := _fade_mat(color)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.look_at_from_position((from + to) * 0.5, to, up)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)


## A quick glowing pop, used for muzzle flashes and attack telegraphs.
func flare(pos: Vector3, color: Color, size: float = 0.6, life: float = 0.25) -> void:
	var mat := _fade_mat(color)
	var s: SphereMesh = PSX.sphere(0.5, 8)
	s.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, life * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## Glowing ring + beam where an enemy is about to appear.
func spawn_portal(pos: Vector3, color: Color = Color(1.0, 0.35, 0.15), life: float = 0.7) -> void:
	var holder := Node3D.new()
	_root().add_child(holder)
	holder.global_position = pos
	var ring_mat := _fade_mat(color)
	var ring: TorusMesh = PSX.torus(0.9, 1.2)
	ring.material = ring_mat
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	holder.add_child(ring_mi)
	var beam_mat := _fade_mat(Color(color, 0.5))
	var beam: CylinderMesh = PSX.cyl(0.6, 0.9, 6.0, 8)
	beam.material = beam_mat
	var beam_mi := MeshInstance3D.new()
	beam_mi.mesh = beam
	beam_mi.position.y = 3.0
	holder.add_child(beam_mi)
	var tw := holder.create_tween().set_parallel(true)
	tw.tween_property(ring_mi, "scale", Vector3(0.2, 1.0, 0.2), life)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, life)
	tw.tween_property(beam_mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(holder.queue_free)
	Sfx.play_at("spawn", pos, -6.0)


## Damages enemies (and optionally the player) in a radius and throws them around.
## Player-made explosions don't hurt the player, but still knock them back,
## so dynamite can be used for rocket jumps.
func explosion(pos: Vector3, radius: float, damage: float, from_player: bool, source: String = "explosion") -> void:
	var mat := _fade_mat(Color(1.0, 0.6, 0.15))
	var s: SphereMesh = PSX.sphere(1.0, 10)
	s.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(0.3, 0.1, 0.05, 0.0), 0.4)
	tw.chain().tween_callback(mi.queue_free)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	_root().add_child(light)
	light.global_position = pos
	var ltw := light.create_tween()
	ltw.tween_property(light, "light_energy", 0.0, 0.35)
	ltw.tween_callback(light.queue_free)

	sparks(pos, Vector3.UP, Color(1.0, 0.7, 0.2), 24, 14.0)
	sparks(pos, Vector3.UP, Color(0.25, 0.2, 0.2), 12, 8.0)
	Sfx.play_at("explosion", pos)

	var player: Player = GameState.player
	if player != null and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(pos)
		shake(clampf(1.0 - dist / (radius * 5.0), 0.0, 0.7))

	var space := mi.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = Layers.ENEMY | Layers.PLAYER
	var seen := {}
	for hit in space.intersect_shape(q, 32):
		var body: Object = hit["collider"]
		if body == null or seen.has(body):
			continue
		seen[body] = true
		if body is Enemy:
			var e: Enemy = body
			var to: Vector3 = e.chest() - pos
			var falloff := clampf(1.0 - to.length() / (radius * 1.3), 0.35, 1.0)
			var dir := to.normalized() if to.length() > 0.01 else Vector3.UP
			e.take_damage(damage * falloff, e.chest(), dir + Vector3.UP * 0.4, source)
		elif body is Player:
			(body as Player).apply_explosion(pos, radius, damage, from_player)


## Damages enemies in a radius (slams, punches). Returns how many were hit.
func hurt_enemies(center: Vector3, radius: float, damage: float, source: String, stun: float = 0.0) -> int:
	var world := get_viewport().find_world_3d()
	if world == null:
		return 0
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = Layers.ENEMY
	var seen := {}
	var count := 0
	for hit in world.direct_space_state.intersect_shape(q, 32):
		var e := hit["collider"] as Enemy
		if e == null or seen.has(e) or e.is_dead:
			continue
		seen[e] = true
		var dir: Vector3 = e.global_position - center
		dir.y = 0.0
		e.take_damage(damage, e.chest(), dir.normalized() + Vector3.UP * 0.6, source)
		if stun > 0.0 and not e.is_dead:
			e.stun(stun)
		count += 1
	return count


func gibs(pos: Vector3, color: Color, count: int = 6, size: float = 0.25) -> void:
	var mat: ShaderMaterial = PSX.material(color, true)
	var dark: ShaderMaterial = PSX.material(color.darkened(0.5), true)
	for i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = Layers.WORLD_MASK
		var s := size * randf_range(0.6, 1.4)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * s
		cs.shape = bs
		rb.add_child(cs)
		PSX.part(rb, PSX.box(Vector3.ONE * s), mat if i % 2 == 0 else dark)
		_root().add_child(rb)
		rb.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.5), randf_range(-0.4, 0.4))
		rb.linear_velocity = Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1)).normalized() * randf_range(5.0, 11.0)
		rb.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		get_tree().create_timer(randf_range(3.0, 5.0)).timeout.connect(rb.queue_free)


func drop_pickups(pos: Vector3, oil_count: int, scrap_amount: int) -> void:
	for i in oil_count:
		Pickup.spawn(_root(), pos, Pickup.Kind.OIL, 10.0)
	if scrap_amount > 0:
		Pickup.spawn(_root(), pos, Pickup.Kind.SCRAP, float(scrap_amount))
