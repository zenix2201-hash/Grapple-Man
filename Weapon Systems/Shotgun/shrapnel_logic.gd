extends RigidBody3D

@export var speed = 10.0
@export var damage = 5

func launch(direction: Vector3) -> void:
	linear_velocity = direction * speed

	await get_tree().create_timer(1.0).timeout
	queue_free()
