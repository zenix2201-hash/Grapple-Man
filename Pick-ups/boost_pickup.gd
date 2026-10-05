extends Node3D

@export var pickup_speed = 5

func _ready() -> void:
	# The player lives on its own physics layer now, so make sure the pickup can see it.
	var area := get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_mask |= Layers.PLAYER


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_character"):
		if body.has_method("apply_boost"):
			body.apply_boost(pickup_speed)
		else:
			body.speed += pickup_speed
		Sfx.play("pickup", -6.0)
		queue_free()
