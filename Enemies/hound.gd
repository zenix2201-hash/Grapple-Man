extends Enemy
## Scrap Hound: fast melee rusher. Runs at you, flashes, then lunges.
## Light — lasso it to yank it into your shotgun.

@export var lunge_speed: float = 17.0
@export var bite_damage: float = 15.0

enum State { CHASE, WINDUP, LUNGE, RECOVER }

var state := State.CHASE
var state_t := 0.0
var _bit := false
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _run_t := 0.0


func _init() -> void:
	display_name = "SCRAP HOUND"
	max_health = 35.0
	move_speed = 10.0
	scrap_value = 4
	oil_drops = 1
	kill_style = 25
	body_color = Color(0.55, 0.42, 0.32)
	eye_color = Color(1.0, 0.25, 0.1)
	collision_radius = 0.45
	collision_height = 1.0


func _build_model() -> void:
	var rust := body_color
	var dark := body_color.darkened(0.45)
	add_part(PSX.box(Vector3(0.55, 0.42, 1.0)), rust, Vector3(0, 0.62, 0))
	add_part(PSX.box(Vector3(0.6, 0.12, 0.7)), dark, Vector3(0, 0.86, 0.05)) # back plate
	_head = pivot(Vector3(0, 0.8, -0.55))
	add_part(PSX.box(Vector3(0.42, 0.32, 0.42)), rust, Vector3(0, 0, -0.12), Vector3.ZERO, _head)
	add_part(PSX.box(Vector3(0.36, 0.1, 0.3)), dark, Vector3(0, -0.2, -0.22), Vector3(12, 0, 0), _head) # jaw
	add_part(PSX.prism(Vector3(0.12, 0.18, 0.08)), dark, Vector3(-0.14, 0.24, -0.02), Vector3.ZERO, _head) # ears
	add_part(PSX.prism(Vector3(0.12, 0.18, 0.08)), dark, Vector3(0.14, 0.24, -0.02), Vector3.ZERO, _head)
	add_eye(PSX.box(Vector3(0.08, 0.06, 0.04)), Vector3(-0.1, 0.05, -0.34), _head)
	add_eye(PSX.box(Vector3(0.08, 0.06, 0.04)), Vector3(0.1, 0.05, -0.34), _head)
	_tail = pivot(Vector3(0, 0.75, 0.5))
	add_part(PSX.cyl(0.03, 0.05, 0.45, 5), dark, Vector3(0, 0.15, 0.15), Vector3(-50, 0, 0), _tail)
	for p in [Vector3(-0.2, 0.45, -0.35), Vector3(0.2, 0.45, -0.35), Vector3(-0.2, 0.45, 0.35), Vector3(0.2, 0.45, 0.35)]:
		var leg: Node3D = pivot(p)
		add_part(PSX.box(Vector3(0.12, 0.45, 0.12)), dark, Vector3(0, -0.22, 0), Vector3.ZERO, leg)
		_legs.append(leg)


func _ai(delta: float) -> void:
	var dist: float = dist_to_player()
	var flat: Vector3 = flat_dir_to_player()
	state_t -= delta
	match state:
		State.CHASE:
			var dir: Vector3 = (flat + separation() * 0.4).normalized()
			ground_move(dir, move_speed, delta)
			face(flat, delta, 12.0)
			if dist < 7.0 and is_on_floor() and state_t <= 0.0:
				state = State.WINDUP
				state_t = 0.35
				telegraph(0.35)
		State.WINDUP:
			ground_move(Vector3.ZERO, 0.0, delta, 60.0)
			face(flat, delta, 20.0)
			if state_t <= 0.0:
				state = State.LUNGE
				state_t = 0.5
				_bit = false
				var d: Vector3 = player.global_position + player.velocity * 0.15 - global_position
				d.y = 0.0
				velocity = d.normalized() * lunge_speed + Vector3.UP * 4.5
				Sfx.play_at("dash", chest(), -6.0, 1.4)
		State.LUNGE:
			velocity.y -= gravity * delta
			if not _bit and chest().distance_to(player_chest()) < 1.8:
				_bit = true
				player.take_damage(bite_damage * GameState.enemy_damage_mult(), global_position, 8.0)
			if state_t <= 0.0 or (is_on_floor() and state_t < 0.3):
				state = State.RECOVER
				state_t = 0.6
		State.RECOVER:
			ground_move(Vector3.ZERO, 0.0, delta, 20.0)
			if state_t <= 0.0:
				state = State.CHASE
				state_t = 0.4


func _animate(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	_run_t += delta * (4.0 + spd * 1.6)
	var swing := sin(_run_t) * clampf(spd / 8.0, 0.0, 1.0) * 0.8
	for i in _legs.size():
		_legs[i].rotation.x = swing if i % 3 == 0 else -swing
	_tail.rotation.y = sin(_run_t * 1.5) * 0.4
	_head.rotation.x = -0.5 if state == State.LUNGE else lerpf(_head.rotation.x, 0.0, minf(delta * 8.0, 1.0))
