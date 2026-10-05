class_name Shockwave
extends Node3D
## Expanding ground ring. Hurts the player if they're standing on the ground
## when it passes — jump over it.

var max_radius := 14.0
var duration := 1.0
var damage := 20.0
var _t := 0.0
var _hit := false
var _torus: TorusMesh


func setup(radius: float, time: float, dmg: float, color: Color) -> void:
	max_radius = radius
	duration = time
	damage = dmg
	_torus = PSX.torus(0.2, 0.6)
	_torus.rings = 28
	_torus.ring_segments = 4
	var mi: MeshInstance3D = PSX.part(self, _torus, PSX.glow(color))
	mi.scale = Vector3(1.0, 0.5, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	_t += delta
	var r := lerpf(0.5, max_radius, _t / duration)
	_torus.inner_radius = maxf(r - 0.35, 0.05)
	_torus.outer_radius = r + 0.35
	if not _hit:
		var p: Player = GameState.player
		if p != null and is_instance_valid(p) and not p.is_dead:
			var flat: float = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			var feet_y: float = p.global_position.y - 1.0
			if absf(flat - r) < 0.8 and feet_y - global_position.y < 0.9:
				p.take_damage(damage, global_position, 6.0)
				p.apply_knock(Vector3.UP * 6.0)
				_hit = true
	if _t >= duration:
		queue_free()
