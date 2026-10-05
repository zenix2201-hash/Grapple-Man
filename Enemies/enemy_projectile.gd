class_name EnemyProjectile
extends Area3D
## Glowing enemy bullet. Punch it (F) just before it hits to parry it back —
## parried shots are much faster, hit enemies, and heal you.
## Uses ray casts each frame so fast shots never tunnel through walls.

var velocity := Vector3.ZERO
var damage := 10.0
var homing := 0.0
var gravity_force := 0.0
var explode_radius := 0.0 ## > 0 makes it explode on impact (mortars)
var life := 7.0
var parried := false
var _core_mat: ShaderMaterial
var _shell_mat: ShaderMaterial
var _visual: Node3D


func _init() -> void:
	collision_layer = Layers.ENEMY_PROJECTILE
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("enemy_projectiles")


func setup(pos: Vector3, vel: Vector3, dmg: float, color: Color, size: float, homing_strength: float = 0.0) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	homing = homing_strength
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = maxf(size, 0.35) # generous so parries are easy to land
	cs.shape = s
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	_shell_mat = PSX.glow(color)
	_core_mat = PSX.glow(Color(1.0, 1.0, 0.9))
	var shell: MeshInstance3D = PSX.part(_visual, PSX.sphere(size, 6), _shell_mat)
	var core: MeshInstance3D = PSX.part(_visual, PSX.sphere(size * 0.55, 6), _core_mat)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_impact(global_position)
		return

	var player: Player = GameState.player
	if homing > 0.0 and not parried and player != null and is_instance_valid(player):
		var desired: Vector3 = (player.global_position + Vector3.UP * 0.3 - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(desired, minf(homing * delta, 1.0))
	velocity.y -= gravity_force * delta

	var from := global_position
	var to := from + velocity * delta
	var mask := (Layers.WORLD_MASK | Layers.ENEMY) if parried else (Layers.WORLD_MASK | Layers.PLAYER)
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		var point: Vector3 = hit["position"]
		if body is Player:
			var p := body as Player
			if p.is_invulnerable():
				global_position = to # dashed through it
				return
			if explode_radius <= 0.0:
				p.take_damage(damage, from)
		elif body is Enemy and parried:
			(body as Enemy).take_damage(damage, point, velocity.normalized(), "parry")
		_impact(point)
		return
	global_position = to
	_visual.rotate_y(delta * 10.0)


## Punched by the player: fire it back where they're aiming.
func parry(_by: Node, dir: Vector3) -> bool:
	if parried:
		return false
	parried = true
	velocity = dir * maxf(velocity.length() * 2.0, 45.0)
	damage = maxf(damage * 4.0, 40.0)
	homing = 0.0
	gravity_force = 0.0
	life = 4.0
	_shell_mat.set_shader_parameter("albedo", Color(0.4, 0.95, 1.0))
	Fx.flare(global_position, Color(0.6, 1.0, 1.0), 1.2, 0.2)
	return true


func _impact(pos: Vector3) -> void:
	if explode_radius > 0.0:
		Fx.explosion(pos, explode_radius, damage, parried, "parry" if parried else "explosion")
	else:
		Fx.sparks(pos, -velocity.normalized(), Color(1.0, 0.6, 0.2), 6, 4.0)
	queue_free()
