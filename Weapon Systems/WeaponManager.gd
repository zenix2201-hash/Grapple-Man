class_name WeaponManager
extends Node3D

var current_weapon: Weapon = null
var weapons: Array[Weapon] = []

func _ready() -> void:
	# Automatically find and register all weapons placed inside this manager
	for child in get_children():
		if child is Weapon:
			weapons.append(child)
			child.unequip() # Hide all guns initially
			
	# Equip the first gun if any exist
	if weapons.size() > 0:
		switch_weapon(0)

func _unhandled_input(event: InputEvent) -> void:
	# Handle shooting input without touching player physics
	if current_weapon:
		if event.is_action_pressed("fire") and current_weapon.can_fire:
			current_weapon.attack()
			
	# Handle weapon switching via scroll wheel or number keys
	if event.is_action_pressed("weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle_weapon(-1)

func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
		
	if current_weapon:
		current_weapon.unequip()
		
	current_weapon = weapons[index]
	current_weapon.equip()

func cycle_weapon(direction: int) -> void:
	if weapons.is_empty():
		return
	var current_index = weapons.find(current_weapon)
	var new_index = (current_index + direction) % weapons.size()
	if new_index < 0:
		new_index = weapons.size() - 1
	switch_weapon(new_index)
