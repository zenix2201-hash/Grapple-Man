class_name Weapon
extends Node3D

@export var weapon_name: String = "Generic Gun"
@export var damage: float = 10.0
@export var fire_rate: float = 0.1

var can_fire: bool = true
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# Overridden by individual guns (e.g., Shotgun, Pistol)
func attack() -> void:
	pass

func equip() -> void:
	visible = true

func unequip() -> void:
	visible = false
