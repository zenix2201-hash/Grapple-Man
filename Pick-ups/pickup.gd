class_name Pickup
extends Node3D
## Dropped by enemies. OIL heals the player, SCRAP is currency for upgrades.
## Both get sucked toward the player when they're close.

enum Kind { OIL, SCRAP }

const MAGNET_RANGE := 7.0
const COLLECT_RANGE := 1.4

var kind: Kind = Kind.OIL
var amount := 10.0
var velocity := Vector3.ZERO
var life := 20.0
var _grounded := false
var _visual: Node3D


static func spawn(parent: Node, pos: Vector3, pickup_kind: Kind, value: float) -> Pickup:
	var p := Pickup.new()
	p.kind = pickup_kind
	p.amount = value
	p.velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(2.0, 4.5) + Vector3.UP * randf_range(4.0, 7.0)
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if kind == Kind.OIL:
		# Little green repair canister
		PSX.part(_visual, PSX.cyl(0.13, 0.13, 0.32, 6), PSX.glow(Color(0.3, 1.0, 0.45)))
		PSX.part(_visual, PSX.cyl(0.05, 0.05, 0.08, 6), Color(0.2, 0.2, 0.2), Vector3(0, 0.2, 0))
	else:
		# Brass gear
		PSX.part(_visual, PSX.cyl(0.2, 0.2, 0.06, 8), PSX.glow(Color(1.0, 0.75, 0.25)), Vector3.ZERO, Vector3(90, 0, 0))
		for i in 4:
			PSX.part(_visual, PSX.box(Vector3(0.52, 0.08, 0.05)), PSX.glow(Color(0.9, 0.6, 0.2)), Vector3.ZERO, Vector3(0, 0, i * 45.0))
	for mi in _visual.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_visual.rotate_y(delta * 3.0)
	_visual.position.y = 0.15 + sin(life * 4.0) * 0.08

	var player: Player = GameState.player
	var wants: bool = player != null and is_instance_valid(player) and not player.is_dead
	if wants and kind == Kind.OIL and player.health >= player.max_health:
		wants = false
	if wants:
		var to: Vector3 = player.global_position - global_position
		var dist := to.length()
		if dist < COLLECT_RANGE:
			_collect(player)
			return
		if dist < MAGNET_RANGE:
			velocity = velocity.lerp(to / dist * 20.0, minf(8.0 * delta, 1.0))
			global_position += velocity * delta
			return

	if _grounded:
		return
	velocity.y -= 18.0 * delta
	var motion := velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + motion + Vector3.DOWN * 0.15, Layers.WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position += motion
	else:
		global_position = hit["position"] + Vector3.UP * 0.15
		_grounded = true
		velocity = Vector3.ZERO


func _collect(player: Player) -> void:
	if kind == Kind.OIL:
		player.heal(amount)
		Sfx.play("pickup", -8.0)
	else:
		GameState.add_scrap(int(amount))
		Sfx.play("scrap", -8.0, 1.0 + randf() * 0.2)
	queue_free()
