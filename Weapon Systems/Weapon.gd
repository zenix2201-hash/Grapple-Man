class_name Weapon
extends Node3D
## Base class for guns. Put a Weapon scene under the WeaponManager and it is
## picked up automatically. Override attack() for left click and
## alt_attack_pressed()/alt_attack_released() for right click.

signal fired

@export var weapon_name: String = "Generic Gun"
@export var damage: float = 10.0
@export var fire_rate: float = 0.1 ## Seconds between shots
@export var recoil: float = 0.15 ## Viewmodel kick per shot
@export var max_range: float = 200.0

var cooldown: float = 0.0
var player: Player = null
var camera: Camera3D = null
var manager: WeaponManager = null
var can_fire: bool:
	get:
		return cooldown <= 0.0 and visible

@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func try_attack() -> void:
	if not can_fire:
		return
	cooldown = fire_rate / maxf(GameState.stat("fire_rate_mult"), 0.1)
	attack()
	if manager:
		manager.kick(recoil)
	fired.emit()


# Overridden by individual guns (e.g., Shotgun, Revolver)
func attack() -> void:
	pass


func alt_attack_pressed() -> void:
	pass


func alt_attack_released() -> void:
	pass


## 0..1, shown on the HUD for chargeable alt-fires.
func get_charge() -> float:
	return 0.0


func equip() -> void:
	visible = true


func unequip() -> void:
	visible = false


# --- Helpers for subclasses ---

func aim_origin() -> Vector3:
	return camera.global_position


func aim_forward() -> Vector3:
	return -camera.global_transform.basis.z


func spread_dir(spread_deg: float) -> Vector3:
	var b: Basis = camera.global_transform.basis
	var d := -b.z
	d += b.x * tan(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	d += b.y * tan(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	return d.normalized()


## Instant-hit bullet. Returns {"point", "normal", "hit_world", "hit_enemy"}.
## `pierce` = how many enemies it passes through.
func hitscan(from: Vector3, dir: Vector3, dmg: float, source: String, pierce: int = 0,
		visual_from: Vector3 = Vector3.INF, tracer_color: Color = Color(1.0, 0.9, 0.5),
		tracer_width: float = 0.03, dist: float = -1.0) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	var end := from + dir * (max_range if dist < 0.0 else dist)
	var result := {"point": end, "normal": Vector3.ZERO, "hit_world": false, "hit_enemy": false}
	var remaining := pierce
	while true:
		var q := PhysicsRayQueryParameters3D.create(from, end, Layers.HITSCAN_MASK, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var point: Vector3 = r["position"]
		result["point"] = point
		result["normal"] = r["normal"]
		var enemy := r["collider"] as Enemy
		if enemy != null:
			var crit: bool = randf() < GameState.stat("crit_chance")
			var final_damage: float = dmg * GameState.stat("damage_mult") * (2.0 if crit else 1.0)
			enemy.take_damage(final_damage, point, dir, source)
			GameState.hitmarker.emit(crit)
			if crit:
				Fx.sparks(point, -dir, Color(1.0, 1.0, 0.4), 10, 9.0)
			result["hit_enemy"] = true
			if remaining > 0:
				remaining -= 1
				exclude.append(enemy.get_rid())
				continue
			break
		Fx.sparks(point, r["normal"], Color(1.0, 0.85, 0.4), 5, 4.0)
		result["hit_world"] = true
		break
	Fx.tracer(from if visual_from == Vector3.INF else visual_from, result["point"], tracer_color, tracer_width)
	return result


## Closest living enemy that `from` has line of sight to.
func find_visible_enemy(from: Vector3, radius: float) -> Enemy:
	var best: Enemy = null
	var best_dist := radius
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_dead:
			continue
		var d: float = from.distance_to(e.chest())
		if d >= best_dist:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, e.chest(), Layers.WORLD_MASK)
		if space.intersect_ray(q).is_empty():
			best = e
			best_dist = d
	return best


func muzzle_flash(at: Node3D, color: Color = Color(1.0, 0.8, 0.4), size: float = 0.35) -> void:
	if at == null:
		return
	Fx.flare(at.global_position, color, size, 0.06)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 6.0
	at.add_child(light)
	get_tree().create_timer(0.05).timeout.connect(light.queue_free)
