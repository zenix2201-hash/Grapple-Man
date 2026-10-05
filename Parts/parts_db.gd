class_name PartsDB
extends RefCounted
## Every swappable robot part. Each slot holds one part; picking a new one
## replaces the old. Add new parts by adding entries to PARTS.
##
## "stats" are added on top of GameState.BASE_STATS.
## "perks" are special behaviours checked with GameState.has_perk().

const SLOTS := ["HEAD", "ARM", "CORE", "LEGS"]
const RARITY_NAMES := ["STOCK", "COMMON", "RARE", "LEGENDARY"]
const RARITY_COLORS := [
	Color(0.65, 0.65, 0.65),
	Color(0.9, 0.86, 0.78),
	Color(0.35, 0.75, 1.0),
	Color(1.0, 0.72, 0.2),
]
const RARITY_WEIGHTS := [0, 6, 3, 1]

const STARTERS := {
	"HEAD": "tin_lid",
	"ARM": "rusty_arm",
	"CORE": "coal_furnace",
	"LEGS": "spur_boots",
}

const PARTS := {
	# --- HEAD ---
	"tin_lid": {"name": "Tin Lid", "slot": "HEAD", "rarity": 0,
		"desc": "Factory-standard noggin. Dented, but it's yours.", "stats": {}},
	"hawk_optic": {"name": "Hawk-Eye Optic", "slot": "HEAD", "rarity": 1,
		"desc": "Sharper sights. Bullets find the soft bits.",
		"stats": {"damage_mult": 0.15, "crit_chance": 0.05}},
	"ten_gallon": {"name": "Ten-Gallon Plating", "slot": "HEAD", "rarity": 1,
		"desc": "A hat so big it counts as armour.", "stats": {"max_health": 40.0}},
	"lucky_lens": {"name": "Lucky Lens", "slot": "HEAD", "rarity": 2,
		"desc": "Sometimes the dice roll your way.", "stats": {"crit_chance": 0.2}},
	"trickshot_optic": {"name": "Trick-Shot Optic", "slot": "HEAD", "rarity": 3,
		"desc": "Revolver shots that hit a wall ricochet into the nearest enemy.",
		"stats": {"damage_mult": 0.05}, "perks": ["ricochet"]},

	# --- ARM ---
	"rusty_arm": {"name": "Rusty Hook-Arm", "slot": "ARM", "rarity": 0,
		"desc": "Punches. Parries. Squeaks a little.", "stats": {}},
	"piston_fist": {"name": "Piston Fist", "slot": "ARM", "rarity": 1,
		"desc": "Punches hit like a freight train. Parries repair more.",
		"stats": {"punch_mult": 1.0, "parry_heal": 15.0}},
	"quickdraw_servo": {"name": "Quickdraw Servo", "slot": "ARM", "rarity": 2,
		"desc": "Hair-trigger actuators. Every gun fires faster.",
		"stats": {"fire_rate_mult": 0.3}},
	"magnet_lasso": {"name": "Magnet Lasso", "slot": "ARM", "rarity": 1,
		"desc": "A longer lasso with a magnetic tip.", "stats": {"grapple_range": 25.0}},

	# --- CORE ---
	"coal_furnace": {"name": "Coal Furnace", "slot": "CORE", "rarity": 0,
		"desc": "Burns anything. Including you, eventually.", "stats": {}},
	"overclocked_boiler": {"name": "Overclocked Boiler", "slot": "CORE", "rarity": 2,
		"desc": "An extra dash and faster dash recharge.",
		"stats": {"dash_charges": 1.0, "dash_regen": 0.35}},
	"oil_siphon": {"name": "Oil Siphon", "slot": "CORE", "rarity": 1,
		"desc": "Drink deep. Kills repair you and oil heals more.",
		"stats": {"heal_mult": 0.5, "kill_heal": 4.0}},
	"reinforced_core": {"name": "Reinforced Core", "slot": "CORE", "rarity": 1,
		"desc": "Thicker plating around the important bits.",
		"stats": {"max_health": 25.0, "heal_mult": 0.2}},
	"volatile_core": {"name": "Volatile Core", "slot": "CORE", "rarity": 3,
		"desc": "Enemies you kill explode, hurting anything nearby.",
		"stats": {}, "perks": ["volatile"]},

	# --- LEGS ---
	"spur_boots": {"name": "Spur Boots", "slot": "LEGS", "rarity": 0,
		"desc": "Jingle jangle.", "stats": {}},
	"spring_shanks": {"name": "Spring Shanks", "slot": "LEGS", "rarity": 2,
		"desc": "Adds a mid-air jump.", "stats": {"air_jumps": 1.0}},
	"greased_treads": {"name": "Greased Treads", "slot": "LEGS", "rarity": 1,
		"desc": "Faster slides and a little more top speed.",
		"stats": {"slide_mult": 0.3, "speed_mult": 0.1}},
	"jackrabbit_legs": {"name": "Jackrabbit Legs", "slot": "LEGS", "rarity": 1,
		"desc": "Lighter frame, quicker feet.", "stats": {"speed_mult": 0.18}},
	"piledriver": {"name": "Piledriver", "slot": "LEGS", "rarity": 3,
		"desc": "Ground slams send out a damaging shockwave and bounce you higher.",
		"stats": {}, "perks": ["piledriver"]},
}

const STAT_LABELS := {
	"max_health": "%+d MAX HP",
	"speed_mult": "%+d%% MOVE SPEED",
	"damage_mult": "%+d%% DAMAGE",
	"fire_rate_mult": "%+d%% FIRE RATE",
	"dash_charges": "%+d DASH",
	"dash_regen": "%+d%% DASH RECHARGE",
	"air_jumps": "%+d AIR JUMP",
	"grapple_range": "%+dm LASSO RANGE",
	"slide_mult": "%+d%% SLIDE SPEED",
	"heal_mult": "%+d%% HEALING",
	"crit_chance": "%+d%% CRIT CHANCE",
	"punch_mult": "%+d%% PUNCH DAMAGE",
	"kill_heal": "+%d HP PER KILL",
	"parry_heal": "%+d HP PER PARRY",
}
const PERCENT_STATS := ["speed_mult", "damage_mult", "fire_rate_mult", "dash_regen",
	"slide_mult", "heal_mult", "crit_chance", "punch_mult"]


static func get_part(id: String) -> Dictionary:
	return PARTS.get(id, {})


static func describe_stats(id: String) -> String:
	var part := get_part(id)
	var lines: PackedStringArray = []
	var stats: Dictionary = part.get("stats", {})
	for key in stats:
		var value: float = stats[key]
		if key in PERCENT_STATS:
			value *= 100.0
		lines.append(String(STAT_LABELS.get(key, key + " %+d")) % int(roundf(value)))
	return "\n".join(lines)


## Picks `count` random non-stock parts that aren't already equipped,
## weighted by rarity.
static func random_offer(count: int, equipped: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: String in PARTS:
		var rarity: int = PARTS[id]["rarity"]
		if rarity > 0 and not equipped.values().has(id):
			pool.append(id)
	var result: Array[String] = []
	while result.size() < count and not pool.is_empty():
		var total := 0
		for id in pool:
			total += RARITY_WEIGHTS[PARTS[id]["rarity"]]
		var roll := rng.randi_range(0, total - 1)
		for id in pool:
			roll -= RARITY_WEIGHTS[PARTS[id]["rarity"]]
			if roll < 0:
				result.append(id)
				pool.erase(id)
				break
	return result
