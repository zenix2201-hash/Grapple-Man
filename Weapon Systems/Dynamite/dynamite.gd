extends Weapon
## Dynamite toss. Left click: throw a stick that explodes on impact.
## Right click: detonate every stick still in the air.
## Your own explosions don't hurt you but do launch you — rocket jump away.

@export var throw_speed: float = 26.0
@export var explosion_radius: float = 5.0

var _muzzle: Marker3D
var _held: Node3D


func _ready() -> void:
	_build_model()


func attack() -> void:
	var stick := DynamiteProjectile.new()
	get_tree().current_scene.add_child(stick)
	stick.global_position = _muzzle.global_position
	var v: Vector3 = aim_forward() * throw_speed + Vector3.UP * 3.0
	if player:
		v += player.velocity * 0.5
	stick.launch(v, damage, explosion_radius)
	Sfx.play("throw", -4.0)
	# Hide the stick in hand until the next one is "lit".
	_held.visible = false
	get_tree().create_timer(fire_rate * 0.8).timeout.connect(_held.set.bind("visible", true))


func alt_attack_pressed() -> void:
	for node in get_tree().get_nodes_in_group("player_dynamite"):
		var stick := node as DynamiteProjectile
		if stick:
			stick.explode()


func _process(_delta: float) -> void:
	if _held and _held.visible and randf() < 0.3:
		Fx.flare(_muzzle.global_position, Color(1.0, 0.8, 0.3), 0.08, 0.08)


func _build_model() -> void:
	_held = Node3D.new()
	_held.name = "Model"
	_held.rotation_degrees = Vector3(-60, 0, -15)
	add_child(_held)
	var red: ShaderMaterial = PSX.material(Color(0.75, 0.12, 0.08), true)
	for x in [-0.045, 0.0, 0.045]:
		PSX.part(_held, PSX.cyl(0.025, 0.025, 0.24, 6), red, Vector3(x, 0, 0))
	PSX.part(_held, PSX.box(Vector3(0.13, 0.035, 0.065)), Color(0.4, 0.3, 0.2), Vector3.ZERO)
	PSX.part(_held, PSX.cyl(0.006, 0.006, 0.08, 4), Color(0.9, 0.85, 0.7), Vector3(0, 0.16, 0))
	for mi in _held.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.12, -0.08)
	add_child(_muzzle)
