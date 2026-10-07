extends Weapon

@export var zoom_fov: float = 0.45 ## Camera FOV multiplier while aiming
@export var zoom_damage_mult: float = 1.5
@export var zoom_pierce: int = 2

var zoomed := false
var _model: Node3D
var _lever: Node3D
var _muzzle: Marker3D


func _ready() -> void:
	_build_model()


func attack() -> void:
	var dmg: float = damage * (zoom_damage_mult if zoomed else 1.0)
	var pierce: int = zoom_pierce if zoomed else 0
	var color: Color = Color(0.6, 0.9, 1.0) if zoomed else Color(1.0, 0.9, 0.55)
	hitscan(aim_origin(), aim_forward(), dmg, "rifle", pierce, _muzzle.global_position, color, 0.05)
	muzzle_flash(_muzzle, Color(1.0, 0.8, 0.4), 0.4)
	Sfx.play("revolver", -1.0, 0.7)
	Fx.shake(0.12)
	_cycle_lever()


func alt_attack_pressed() -> void:
	_set_zoom(true)


func alt_attack_released() -> void:
	_set_zoom(false)


func unequip() -> void:
	_set_zoom(false)
	super.unequip()


func _set_zoom(on: bool) -> void:
	zoomed = on
	if player:
		player.fov_zoom = zoom_fov if on else 1.0
	if _model:
		var tw := create_tween()
		tw.tween_property(_model, "position", Vector3(-0.3, 0.1, 0.1) if on else Vector3.ZERO, 0.12)


func _cycle_lever() -> void:
	if _lever == null:
		return
	var tw := create_tween()
	tw.tween_property(_lever, "rotation_degrees:x", 50.0, fire_rate * 0.3)
	tw.tween_property(_lever, "rotation_degrees:x", 0.0, fire_rate * 0.3)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var metal: ShaderMaterial = PSX.material(Color(0.32, 0.32, 0.36), true)
	var wood: ShaderMaterial = PSX.material(Color(0.52, 0.3, 0.14), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	PSX.part(_model, PSX.cyl(0.025, 0.025, 0.85, 8), metal, Vector3(0, 0.03, -0.5), Vector3(90, 0, 0)) # barrel
	PSX.part(_model, PSX.cyl(0.02, 0.02, 0.6, 6), metal, Vector3(0, -0.02, -0.4), Vector3(90, 0, 0)) # tube magazine
	PSX.part(_model, PSX.box(Vector3(0.06, 0.1, 0.22)), brass, Vector3(0, 0.0, 0.0)) # receiver
	PSX.part(_model, PSX.box(Vector3(0.06, 0.06, 0.3)), wood, Vector3(0, -0.01, -0.3)) # forestock
	PSX.part(_model, PSX.box(Vector3(0.055, 0.13, 0.32)), wood, Vector3(0, -0.06, 0.26), Vector3(-12, 0, 0)) # stock
	PSX.part(_model, PSX.box(Vector3(0.012, 0.03, 0.012)), brass, Vector3(0, 0.07, -0.9)) # front sight
	_lever = Node3D.new()
	_lever.position = Vector3(0, -0.05, 0.05)
	_model.add_child(_lever)
	PSX.part(_lever, PSX.torus(0.03, 0.045), metal, Vector3(0, -0.05, 0.02), Vector3(0, 0, 90))
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.03, -0.95)
	_model.add_child(_muzzle)
