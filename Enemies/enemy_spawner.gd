extends Marker3D
## Drop this into any level (like the test level) to get enemies to fight.
## Spawns `enemy_scene` here and respawns it a few seconds after it dies.

@export var enemy_scene: PackedScene
@export var respawn_time: float = 4.0
@export var respawn: bool = true

var _current: Node = null
var _timer := 0.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or enemy_scene == null:
		return
	if _current != null and is_instance_valid(_current) and not (_current as Enemy).is_dead:
		return
	if _current != null and not respawn:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = respawn_time
	var e := enemy_scene.instantiate() as Node3D
	e.position = global_position
	get_tree().current_scene.add_child(e)
	Fx.spawn_portal(global_position)
	_current = e
