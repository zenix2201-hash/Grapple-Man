extends Weapon

@export var spin_up_time: float = 0.9
@export var spin_down_time: float = 1.4
@export var slow_fire_rate: float = 0.22 
@export var min_spread: float = 1.2
@export var max_spread: float = 3.5

var spin := 0.0
var _pre_spin := false
var _barrels: Node3D
var _muzzle: Marker3D


func _ready() -> void:
	_build_model()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var firing: bool = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if visible and (firing or _pre_spin):
		spin = minf(spin + delta / spin_up_time, 1.0)
	else:
		spin = maxf(spin - delta / spin_down_time, 0.0)


func _process(delta: float) -> void:
	if _barrels and spin > 0.0:
		_barrels.rotate_z(delta * spin * 30.0)


func attack() -> void:
	# try_attack() set the cooldown for full spin; slow it down while spinning up.
	cooldown = lerpf(slow_fire_rate, fire_rate, spin) / maxf(GameState.stat("fire_rate_mult"), 0.1)
	var spread: float = lerpf(min_spread, max_spread, spin)
	hitscan(aim_origin(), spread_dir(spread), damage, "gatling", 0,
		_muzzle.global_position, Color(1.0, 0.85, 0.45), 0.02)
	muzzle_flash(_muzzle, Color(1.0, 0.75, 0.35), 0.25)
	Sfx.play("gatling", -6.0, 1.0 + spin * 0.15)
	Fx.shake(0.03)


func alt_attack_pressed() -> void:
	_pre_spin = true


func alt_attack_released() -> void:
	_pre_spin = false


func get_charge() -> float:
	return spin


func unequip() -> void:
	_pre_spin = false
	spin = 0.0
	super.unequip()


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var metal: ShaderMaterial = PSX.material(Color(0.36, 0.36, 0.4), true)
	var dark: ShaderMaterial = PSX.material(Color(0.2, 0.2, 0.23), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	var wood: ShaderMaterial = PSX.material(Color(0.5, 0.27, 0.12), true)
	PSX.part(model, PSX.box(Vector3(0.16, 0.16, 0.24)), brass, Vector3(0, 0, 0.05)) # housing
	PSX.part(model, PSX.cyl(0.07, 0.07, 0.05, 8), dark, Vector3(0, 0, -0.1), Vector3(90, 0, 0)) # front plate
	PSX.part(model, PSX.box(Vector3(0.06, 0.16, 0.08)), wood, Vector3(0, -0.14, 0.12), Vector3(-15, 0, 0)) # grip
	PSX.part(model, PSX.cyl(0.015, 0.015, 0.14, 6), dark, Vector3(0.1, 0.0, 0.08), Vector3(0, 0, 90)) # crank axle
	PSX.part(model, PSX.box(Vector3(0.02, 0.1, 0.02)), brass, Vector3(0.17, -0.04, 0.08)) # crank handle
	PSX.part(model, PSX.cyl(0.035, 0.035, 0.12, 6), dark, Vector3(0, 0.12, 0.05)) # drum mag
	_barrels = Node3D.new()
	_barrels.position = Vector3(0, 0, -0.12)
	model.add_child(_barrels)
	for i in 6:
		var a := TAU * i / 6.0
		PSX.part(_barrels, PSX.cyl(0.016, 0.016, 0.55, 6), metal,
			Vector3(cos(a) * 0.045, sin(a) * 0.045, -0.27), Vector3(90, 0, 0))
	PSX.part(_barrels, PSX.cyl(0.07, 0.07, 0.03, 8), dark, Vector3(0, 0, -0.4), Vector3(90, 0, 0)) # barrel clamp
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0, -0.68)
	add_child(_muzzle)
