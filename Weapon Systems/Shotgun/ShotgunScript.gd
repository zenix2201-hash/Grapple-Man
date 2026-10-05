extends Weapon
## Scattergun. Left click: a wide hitscan blast. Right click: a weaker blast
## that shoves you away from where you're aiming (aim down = shotgun jump).

@export var shrapnel_count: int = 10
@export var shrapnel_spread: float = 7.0
@export var self_knockback: float = 16.0

@onready var reload: AnimationPlayer = $Reloading
@onready var muzzle: Marker3D = $Muzzle


func attack() -> void:
	_blast(1.0)


func alt_attack_pressed() -> void:
	if not can_fire:
		return
	cooldown = fire_rate * 1.2 / maxf(GameState.stat("fire_rate_mult"), 0.1)
	_blast(0.6)
	var push: Vector3 = -aim_forward() * self_knockback
	player.apply_knock(push)
	if manager:
		manager.kick(recoil * 1.5)


func _blast(damage_scale: float) -> void:
	for i in shrapnel_count:
		hitscan(aim_origin(), spread_dir(shrapnel_spread), damage * damage_scale, "shotgun", 0,
			muzzle.global_position, Color(1.0, 0.75, 0.3), 0.025, 60.0)
	muzzle_flash(muzzle, Color(1.0, 0.7, 0.3), 0.6)
	Sfx.play("shotgun", -2.0)
	Fx.shake(0.18)
	if reload:
		reload.stop()
		reload.play("reload")
