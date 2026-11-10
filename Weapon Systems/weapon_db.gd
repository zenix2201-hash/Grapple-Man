class_name WeaponDB
extends RefCounted
## Every weapon the player can pick on the loadout screen.
## To add a new one: make a scene whose root extends Weapon, then add an entry
## here (and its id to ORDER). `position` is where it sits in the viewmodel.

const MAX_LOADOUT := 3 ## Matches the weapon_1..weapon_3 input actions
const DEFAULT_LOADOUT: Array[String] = ["revolver", "shotgun", "rifle"]

const ORDER: Array[String] = ["revolver", "shotgun", "rifle", "sword", "gatling", "tesla"]

const WEAPONS := {
	"revolver": {
		"name": "PEACEMAKER",
		"type": "REVOLVER",
		"desc": "Fast, accurate shots. Hold RMB to charge a shot that pierces enemies.",
		"scene": "res://Weapon Systems/Revolver/revolver.tscn",
		"position": Vector3(0.3, -0.28, -0.5),
	},
	"shotgun": {
		"name": "SCATTERGUN",
		"type": "SHOTGUN",
		"desc": "Wide blast up close. RMB fires a weaker blast that launches you backwards.",
		"scene": "res://Weapon Systems/Shotgun/shotgun2.tscn",
		"position": Vector3(0.30923456, -0.26516318, -1.1499362),
	},
	"rifle": {
		"name": "LONGHORN",
		"type": "LEVER RIFLE",
		"desc": "Heavy, slow shots. Hold RMB to zoom for bonus damage and piercing.",
		"scene": "res://Weapon Systems/Rifle/rifle.tscn",
		"position": Vector3(0.28, -0.3, -0.45),
	},
	"sword": {
		"name": "SIDEWINDER",
		"type": "SABRE",
		"desc": "Slash everything in front of you and bat enemy shots back. RMB lunges through enemies.",
		"scene": "res://Weapon Systems/Sword/sword.tscn",
		"position": Vector3(0.34, -0.36, -0.55),
	},
	"gatling": {
		"name": "DUST DEVIL",
		"type": "GATLING",
		"desc": "Hold to spin up: fires faster the longer you hold. Hold RMB to keep it spinning.",
		"scene": "res://Weapon Systems/Gatling/gatling.tscn",
		"position": Vector3(0.3, -0.34, -0.55),
	},
	"tesla": {
		"name": "STORMCALLER",
		"type": "TESLA COIL",
		"desc": "Lightning that arcs between nearby enemies. RMB discharges a stunning shock ring.",
		"scene": "res://Weapon Systems/Tesla/tesla.tscn",
		"position": Vector3(0.3, -0.3, -0.5),
	},
}


static func get_weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, {})


## Creates the weapon node for `id`, ready to add under a WeaponManager.
static func instantiate(id: String) -> Weapon:
	var info := get_weapon(id)
	if info.is_empty():
		push_warning("WeaponDB: unknown weapon '%s'" % id)
		return null
	var packed := load(String(info["scene"])) as PackedScene
	if packed == null:
		push_warning("WeaponDB: couldn't load scene for '%s'" % id)
		return null
	var w := packed.instantiate() as Weapon
	if w == null:
		push_warning("WeaponDB: scene for '%s' isn't a Weapon" % id)
		return null
	w.name = id.capitalize()
	w.position = info["position"]
	return w
