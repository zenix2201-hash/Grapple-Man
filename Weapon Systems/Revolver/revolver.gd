extends Weapon
## Peacemaker revolver. Left click: fast, accurate hitscan.
## Right click (hold, release): charged piercing shot that goes through enemies.

@export var charge_time: float = 0.9
@export var charged_damage: float = 90.0
@export var charged_pierce: int = 3

var charging := false
var charge := 0.0
var _drum: Node3D
var _muzzle: Marker3D
var _model: Node3D
var _charge_sound_played := false


func _ready() -> void:
	_build_model()


func attack() -> void:
	_fire_shot(damage, 0, Color(1.0, 0.9, 0.5), 0.03, "revolver")
	Sfx.play("revolver", -3.0)
	Fx.shake(0.06)


func alt_attack_pressed() -> void:
	if cooldown > 0.0:
		return
	charging = true
	charge = 0.0
	_charge_sound_played = false


func alt_attack_released() -> void:
	if not charging:
		return
	charging = false
	if charge >= 1.0:
		_fire_shot(charged_damage, charged_pierce, Color(0.4, 0.9, 1.0), 0.1, "pierce")
		Sfx.play("charge_shot", -2.0)
		Fx.shake(0.25)
		if manager:
			manager.kick(0.5)
		cooldown = fire_rate * 2.0
	charge = 0.0
	_model.position = Vector3.ZERO


func get_charge() -> float:
	return charge if charging else 0.0


func unequip() -> void:
	charging = false
	charge = 0.0
	super.unequip()


func _process(delta: float) -> void:
	if _drum:
		_drum.rotation.z = lerp_angle(_drum.rotation.z, 0.0, minf(delta * 10.0, 1.0))
	if charging:
		charge = minf(charge + delta / charge_time, 1.0)
		if charge >= 1.0:
			if not _charge_sound_played:
				_charge_sound_played = true
				Sfx.play("charge", -8.0, 1.4)
			_model.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004


func _fire_shot(dmg: float, pierce: int, color: Color, width: float, source: String) -> void:
	var dir: Vector3 = aim_forward()
	var res: Dictionary = hitscan(aim_origin(), dir, dmg, source, pierce, _muzzle.global_position, color, width)
	muzzle_flash(_muzzle, color, 0.3 + width * 3.0)
	if _drum:
		_drum.rotation.z += TAU / 6.0
	# Trick-Shot Optic: bounce off walls into the nearest enemy.
	if res["hit_world"] and GameState.has_perk("ricochet"):
		var point: Vector3 = res["point"]
		var normal: Vector3 = res["normal"]
		var from := point + normal * 0.1
		var target: Enemy = find_visible_enemy(from, 40.0)
		if target != null:
			hitscan(from, (target.chest() - from).normalized(), dmg * 1.25, "ricoshot", 0, point,
				Color(1.0, 0.45, 0.2), width * 1.5)
			Sfx.play("parry", -10.0, 1.5)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var metal: ShaderMaterial = PSX.material(Color(0.5, 0.5, 0.55), true)
	var dark: ShaderMaterial = PSX.material(Color(0.22, 0.22, 0.25), true)
	var wood: ShaderMaterial = PSX.material(Color(0.5, 0.27, 0.12), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	PSX.part(_model, PSX.cyl(0.03, 0.03, 0.4, 8), metal, Vector3(0, 0.03, -0.24), Vector3(90, 0, 0)) # barrel
	PSX.part(_model, PSX.box(Vector3(0.025, 0.02, 0.36)), dark, Vector3(0, 0.065, -0.22)) # top rib
	PSX.part(_model, PSX.box(Vector3(0.015, 0.03, 0.015)), brass, Vector3(0, 0.09, -0.41)) # front sight
	_drum = Node3D.new()
	_drum.position = Vector3(0, 0.0, -0.02)
	_model.add_child(_drum)
	PSX.part(_drum, PSX.cyl(0.065, 0.065, 0.11, 6), dark, Vector3.ZERO, Vector3(90, 0, 0))
	PSX.part(_model, PSX.box(Vector3(0.065, 0.1, 0.18)), metal, Vector3(0, 0.0, 0.08)) # frame
	PSX.part(_model, PSX.box(Vector3(0.055, 0.2, 0.08)), wood, Vector3(0, -0.12, 0.15), Vector3(-22, 0, 0)) # grip
	PSX.part(_model, PSX.box(Vector3(0.02, 0.05, 0.04)), brass, Vector3(0, 0.07, 0.15), Vector3(-30, 0, 0)) # hammer
	PSX.part(_model, PSX.torus(0.03, 0.045), dark, Vector3(0, -0.06, 0.05), Vector3(0, 0, 90)) # trigger guard
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.03, -0.46)
	add_child(_muzzle)
