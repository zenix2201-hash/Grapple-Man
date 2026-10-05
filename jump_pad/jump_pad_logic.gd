extends CSGBox3D

@export var launch_strength = 10

func _ready() -> void:
	# The player lives on its own physics layer now, so make sure the pad can see it.
	var area := get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_mask |= Layers.PLAYER


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		var player := body as Player
		player.is_slamming = false
		player.velocity.y = maxf(player.velocity.y, launch_strength)
		Sfx.play("jump", -4.0, 0.6)
	elif body is CharacterBody3D:
		body.velocity.y = launch_strength


func _on_area_3d_area_entered(_area: Area3D) -> void:
	pass
