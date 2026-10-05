class_name DynamiteProjectile
extends Area3D
## A thrown stick of dynamite. Explodes on impact. Punch it mid-air to bat it
## somewhere else for a bigger boom. Right click with the dynamite out
## detonates every stick in the air (great for rocket jumps).

var velocity := Vector3.ZERO
var damage := 60.0
var radius := 5.0
var gravity_force := 16.0
var life := 4.0
var exploded := false
var batted := false
var _visual: Node3D


func _init() -> void:
	collision_layer = Layers.PLAYER_PROJECTILE
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("player_dynamite")
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.4
	cs.shape = s
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	var red: ShaderMaterial = PSX.material(Color(0.75, 0.12, 0.08), true)
	for x in [-0.07, 0.0, 0.07]:
		PSX.part(_visual, PSX.cyl(0.04, 0.04, 0.32, 6), red, Vector3(x, 0, 0))
	PSX.part(_visual, PSX.box(Vector3(0.2, 0.05, 0.1)), Color(0.4, 0.3, 0.2), Vector3.ZERO)
	PSX.part(_visual, PSX.sphere(0.05, 6), PSX.glow(Color(1.0, 0.8, 0.3)), Vector3(0, 0.2, 0))


func launch(initial_velocity: Vector3, dmg: float, blast_radius: float) -> void:
	velocity = initial_velocity
	damage = dmg
	radius = blast_radius


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		explode()
		return
	velocity.y -= gravity_force * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.HITSCAN_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		global_position = p + n * 0.2
		explode()
		return
	global_position = to
	_visual.rotate_x(delta * 14.0)
	if randf() < 0.5:
		Fx.sparks(global_position, Vector3.UP, Color(1.0, 0.8, 0.3), 1, 2.0)


func explode() -> void:
	if exploded:
		return
	exploded = true
	var r := radius * (1.3 if batted else 1.0)
	var d := damage * (1.5 if batted else 1.0)
	Fx.explosion(global_position, r, d, true, "dynamite")
	queue_free()


## Called when the player punches it.
func parry(_by: Node, dir: Vector3) -> bool:
	if exploded:
		return false
	velocity = dir * 45.0
	gravity_force = 4.0
	batted = true
	life = 3.0
	GameState.add_style("HOME RUN", 30)
	Sfx.play("parry", -6.0, 0.8)
	return false # batting your own dynamite doesn't count as a healing parry
