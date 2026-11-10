class_name WeaponManager
extends Node3D

signal weapon_changed(weapon: Weapon, index: int)

const MAX_WEAPONS := 5
const SLOT_ACTIONS := ["weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5"]

@export var sway_amount: float = 0.0006 ## Per pixel of mouse movement
@export var sway_max: float = 0.06
@export var sway_smooth: float = 10.0
@export var bob_amount: float = 0.02

var current_weapon: Weapon = null
var weapons: Array[Weapon] = []
var player: Player = null
var camera: Camera3D = null

var _mouse_delta := Vector2.ZERO
var _sway := Vector2.ZERO
var _recoil := 0.0
var _switch_dip := 0.0
var _bob_t := 0.0
var _arm: Node3D
var _arm_rest := Vector3(-0.36, -0.42, -0.5)
var _arm_tween: Tween


func _ready() -> void:
	camera = get_parent() as Camera3D
	player = owner as Player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player

	if not GameState.loadout.is_empty():
		_apply_loadout(GameState.loadout)

	# Automatically find and register all weapons placed inside this manager
	for child in get_children():
		if child is Weapon:
			if weapons.size() >= MAX_WEAPONS:
				push_warning("WeaponManager: more than %d weapons, '%s' was ignored." % [MAX_WEAPONS, child.name])
				(child as Weapon).unequip()
				continue
			var w := child as Weapon
			weapons.append(w)
			w.manager = self
			w.player = player
			w.camera = camera
			w.unequip() # Hide all guns initially
	_build_arm()

	# Equip the first gun if any exist
	if weapons.size() > 0:
		switch_weapon(0)


func _apply_loadout(ids: Array) -> void:
	for child in get_children():
		if child is Weapon:
			remove_child(child)
			child.queue_free()
	for id in ids:
		var w: Weapon = WeaponDB.instantiate(String(id))
		if w != null:
			add_child(w)



func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.is_dead:
		return
	if event is InputEventMouseMotion:
		_mouse_delta += (event as InputEventMouseMotion).relative

	for i in SLOT_ACTIONS.size():
		var action: String = SLOT_ACTIONS[i]
		if InputMap.has_action(action) and event.is_action_pressed(action):
			switch_weapon(i)
			break

	if current_weapon != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("alt_fire"):
			current_weapon.alt_attack_pressed()
		elif event.is_action_released("alt_fire"):
			current_weapon.alt_attack_released()


func _physics_process(_delta: float) -> void:
	if current_weapon == null or player == null or player.is_dead:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _switch_dip > 0.5:
		return
	if Input.is_action_pressed("fire"):
		current_weapon.try_attack()


func _process(delta: float) -> void:
	# Sway: the gun lags behind mouse movement.
	var target := Vector2(
		clampf(-_mouse_delta.x * sway_amount, -sway_max, sway_max),
		clampf(_mouse_delta.y * sway_amount, -sway_max, sway_max))
	_mouse_delta = Vector2.ZERO
	_sway = _sway.lerp(target, minf(sway_smooth * delta, 1.0))

	# Bob while running.
	var bob := Vector3.ZERO
	var fall := 0.0
	if player != null:
		var h_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if player.is_on_floor() and h_speed > 0.5 and not player.is_sliding:
			_bob_t += delta * h_speed * 1.1
		bob = Vector3(cos(_bob_t * 0.5) * bob_amount, -absf(sin(_bob_t * 0.5)) * bob_amount, 0.0)
		fall = clampf(-player.velocity.y * 0.003, -0.05, 0.05)

	_recoil = lerpf(_recoil, 0.0, minf(delta * 12.0, 1.0))
	_switch_dip = move_toward(_switch_dip, 0.0, delta * 5.0)

	position = Vector3(_sway.x, _sway.y + fall - _switch_dip * 0.5, _recoil * 0.25) + bob
	rotation = Vector3(_recoil * 0.6 - _switch_dip * 0.6, _sway.x * 2.0, _sway.x * 3.0)


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if current_weapon == weapons[index]:
		return

	if current_weapon:
		current_weapon.alt_attack_released()
		current_weapon.unequip()

	current_weapon = weapons[index]
	current_weapon.equip()
	_switch_dip = 1.0
	Sfx.play("ui_move", -10.0, 0.8)
	weapon_changed.emit(current_weapon, index)


func cycle_weapon(direction: int) -> void:
	if weapons.is_empty():
		return
	var current_index := weapons.find(current_weapon)
	var new_index := posmod(current_index + direction, weapons.size())
	switch_weapon(new_index)


func current_index() -> int:
	return weapons.find(current_weapon)


func kick(amount: float) -> void:
	_recoil = minf(_recoil + amount, 0.6)


func play_punch() -> void:
	if _arm == null:
		return
	if _arm_tween and _arm_tween.is_valid():
		_arm_tween.kill()
	_arm.position = _arm_rest
	_arm_tween = create_tween()
	_arm_tween.tween_property(_arm, "position", _arm_rest + Vector3(0.22, 0.14, -0.45), 0.06)
	_arm_tween.tween_property(_arm, "position", _arm_rest, 0.2).set_ease(Tween.EASE_OUT)


func _build_arm() -> void:
	_arm = Node3D.new()
	_arm.name = "PunchArm"
	_arm.position = _arm_rest
	_arm.rotation_degrees = Vector3(10, 8, 0)
	add_child(_arm)
	var metal: ShaderMaterial = PSX.material(Color(0.6, 0.62, 0.66), true)
	var dark: ShaderMaterial = PSX.material(Color(0.25, 0.26, 0.3), true)
	var brass: ShaderMaterial = PSX.material(Color(0.85, 0.65, 0.3))
	PSX.part(_arm, PSX.box(Vector3(0.11, 0.11, 0.42)), metal, Vector3(0, 0, 0.18))
	PSX.part(_arm, PSX.cyl(0.02, 0.02, 0.36, 6), dark, Vector3(0.07, 0.03, 0.18), Vector3(90, 0, 0))
	PSX.part(_arm, PSX.box(Vector3(0.15, 0.14, 0.14)), dark, Vector3(0, 0, -0.07))
	PSX.part(_arm, PSX.box(Vector3(0.16, 0.05, 0.05)), brass, Vector3(0, 0.03, -0.15))
	for mi in _arm.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
