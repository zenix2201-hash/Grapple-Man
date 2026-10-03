extends Weapon

@export var shrapnel: PackedScene
@export var shrapnel_count = 5
@export var shrapnel_spread = 5.0

@onready var reload = $Reloading
@onready var muzzle = $Muzzle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func attack() -> void:
	for i in shrapnel_count:
		var shot = shrapnel.instantiate()
		get_tree().current_scene.add_child(shot)

		shot.global_position = muzzle.global_position

		var direction = -muzzle.global_transform.basis.z

		var spread_x = randf_range(-shrapnel_spread, shrapnel_spread)
		var spread_y = randf_range(-shrapnel_spread, shrapnel_spread)

		direction += muzzle.global_transform.basis.x * tan(deg_to_rad(spread_x))
		direction += muzzle.global_transform.basis.y * tan(deg_to_rad(spread_y))

		shot.launch(direction.normalized())
		
	reload.play("reload")
		
