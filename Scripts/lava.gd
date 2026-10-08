extends Area3D

@export var rising_speed: float = 2.0

var _triggered: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position.y += rising_speed* delta
	

func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body is Player:
		return
		_triggered = true
	get_tree().reload_current_scene.call_deferred()
