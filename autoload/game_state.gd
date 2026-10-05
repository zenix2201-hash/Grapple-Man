extends Node
## Autoload "GameState": run progress (floor, scrap, equipped parts), the
## style meter, player stats and saved settings.

signal style_event(label: String, points: int)
signal rank_changed(rank: int)
signal scrap_changed(amount: int)
signal parts_changed
signal settings_changed
signal banner(title: String, subtitle: String)
signal hitmarker(crit: bool)
signal enemy_killed(enemy: Node)
signal boss_update(boss_name: String, fraction: float)

const SETTINGS_PATH := "user://settings.cfg"

const BASE_STATS := {
	"max_health": 100.0,
	"speed_mult": 1.0,
	"damage_mult": 1.0,
	"fire_rate_mult": 1.0,
	"dash_charges": 3.0,
	"dash_regen": 1.0,
	"air_jumps": 0.0,
	"grapple_range": 45.0,
	"slide_mult": 1.0,
	"heal_mult": 1.0,
	"crit_chance": 0.0,
	"punch_mult": 1.0,
	"kill_heal": 0.0,
	"parry_heal": 25.0,
}

const RANK_SIZE := 100.0
const RANKS := [
	{"letter": "D", "name": "DUSTY", "color": Color(0.55, 0.65, 1.0)},
	{"letter": "C", "name": "COWPOKE", "color": Color(0.4, 0.9, 0.5)},
	{"letter": "B", "name": "BANDIT", "color": Color(1.0, 0.85, 0.3)},
	{"letter": "A", "name": "OUTLAW", "color": Color(1.0, 0.55, 0.2)},
	{"letter": "S", "name": "SHOWDOWN", "color": Color(1.0, 0.25, 0.2)},
	{"letter": "SS", "name": "SIX-SHOOTER", "color": Color(1.0, 0.25, 0.55)},
	{"letter": "SSS", "name": "SUNDOWN", "color": Color(1.0, 0.92, 0.95)},
]

var settings := {
	"mouse_sensitivity": 0.003,
	"psx_filter": true,
	"pixel_size": 3.0,
	"volume": 0.8,
	"psx_auto_convert": true,
}

var player: Player = null
var ui_open := false

# --- Run state ---
var run_active := false
var floor_num := 1
var scrap := 0
var kills := 0
var run_time := 0.0
var best_rank := -1
var player_health := -1.0 ## Carried between floors. -1 = full.
var equipped: Dictionary = PartsDB.STARTERS.duplicate()

# --- Style ---
var style_points := 0.0
var rank := -1

var _stat_cache: Dictionary = {}
var _recent_kills: Array = []
var _time := 0.0


func _ready() -> void:
	_load_settings()
	_apply_settings()


func _process(delta: float) -> void:
	_time += delta
	if run_active and player != null and not player.is_dead:
		run_time += delta
	if style_points > 0.0:
		style_points = maxf(style_points - (5.0 + maxi(rank, 0) * 5.0) * delta, 0.0)
		_update_rank()


# --- Run flow ---

func start_run() -> void:
	run_active = true
	floor_num = 1
	scrap = 0
	kills = 0
	run_time = 0.0
	best_rank = -1
	player_health = -1.0
	style_points = 0.0
	rank = -1
	equipped = PartsDB.STARTERS.duplicate()
	_stat_cache.clear()
	parts_changed.emit()
	scrap_changed.emit(scrap)


func advance_floor() -> void:
	floor_num += 1
	style_points *= 0.5
	_update_rank()


func end_run() -> void:
	run_active = false


func goto_scene(path: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	ui_open = false
	player = null
	get_tree().change_scene_to_file(path)


## Reloads the current level with full health and an empty style meter.
func restart_level() -> void:
	player_health = -1.0
	style_points = 0.0
	_update_rank()
	var scene := get_tree().current_scene
	if scene != null:
		goto_scene(scene.scene_file_path)


# --- Parts & stats ---

func stat(key: String) -> float:
	if _stat_cache.has(key):
		return _stat_cache[key]
	var v: float = BASE_STATS.get(key, 0.0)
	for slot in equipped:
		var part: Dictionary = PartsDB.get_part(equipped[slot])
		var stats: Dictionary = part.get("stats", {})
		v += float(stats.get(key, 0.0))
	_stat_cache[key] = v
	return v


func has_perk(perk: String) -> bool:
	for slot in equipped:
		var part: Dictionary = PartsDB.get_part(equipped[slot])
		var perks: Array = part.get("perks", [])
		if perks.has(perk):
			return true
	return false


func equip(part_id: String) -> void:
	var part: Dictionary = PartsDB.get_part(part_id)
	if part.is_empty():
		return
	var old_max := stat("max_health")
	equipped[part["slot"]] = part_id
	_stat_cache.clear()
	# Max HP upgrades also fill the new space.
	var gained := stat("max_health") - old_max
	if player_health > 0.0 and gained > 0.0:
		player_health += gained
	parts_changed.emit()


func enemy_health_mult() -> float:
	return 1.0 + 0.15 * (floor_num - 1)


func enemy_damage_mult() -> float:
	return 1.0 + 0.07 * (floor_num - 1)


# --- Scrap ---

func add_scrap(amount: int) -> void:
	var bonus := 1.0 + maxi(rank, 0) * 0.15
	scrap += int(roundf(amount * bonus))
	scrap_changed.emit(scrap)


func spend_scrap(amount: int) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true


# --- Style meter ---

func add_style(label: String, points: int) -> void:
	style_points = minf(style_points + points, RANK_SIZE * RANKS.size() - 1.0)
	style_event.emit(label, points)
	_update_rank()


func rank_progress() -> float:
	if rank < 0:
		return 0.0
	return fmod(style_points, RANK_SIZE) / RANK_SIZE


func _update_rank() -> void:
	var r := -1
	if style_points > 0.0:
		r = mini(int(style_points / RANK_SIZE), RANKS.size() - 1)
	if r != rank:
		if r > rank and r >= 0:
			Sfx.play("rank_up", -6.0, 1.0 + r * 0.08)
		rank = r
		best_rank = maxi(best_rank, rank)
		rank_changed.emit(rank)


func on_player_hurt(_amount: float) -> void:
	style_points = maxf(style_points - 60.0, 0.0)
	_update_rank()


func on_enemy_killed(enemy: Enemy, source: String) -> void:
	kills += 1
	enemy_killed.emit(enemy)

	var points: int = enemy.kill_style
	var label := "KILL"
	match source:
		"pierce":
			label = "PIERCED"
			points += 15
		"ricoshot":
			label = "RICOSHOT"
			points += 30
		"parry":
			label = "RETURN TO SENDER"
			points += 40
		"dynamite", "explosion", "volatile":
			label = "FIREWORKS"
			points += 10
		"punch":
			label = "KNOCKOUT"
			points += 20
		"slam":
			label = "GROUND POUND"
			points += 25
	if enemy.is_boss:
		label = "BIG GAME"
	add_style(label, points)

	if not enemy.flying and not enemy.is_on_floor():
		add_style("AIRSHOT", 20)
	if player != null and is_instance_valid(player):
		if player.is_sliding:
			add_style("SLIDE BY", 10)
		elif not player.is_on_floor():
			add_style("AERIAL", 10)
		if source == "shotgun" and player.global_position.distance_to(enemy.global_position) < 3.5:
			add_style("POINT BLANK", 15)
		var heal := stat("kill_heal")
		if heal > 0.0:
			player.heal(heal)

	_recent_kills.append(_time)
	_recent_kills = _recent_kills.filter(func(t: float) -> bool: return _time - t < 0.75)
	match _recent_kills.size():
		1:
			pass
		2:
			add_style("DOUBLE KILL", 15)
		3:
			add_style("TRIPLE KILL", 30)
		_:
			add_style("MULTIKILL", 40)


func rank_letter(r: int) -> String:
	return "" if r < 0 else String(RANKS[r]["letter"])


# --- Settings ---

func get_setting(key: String) -> Variant:
	return settings.get(key)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	_save_settings()
	settings_changed.emit()


func _apply_settings() -> void:
	var vol: float = settings["volume"]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.0001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		settings[key] = cfg.get_value("settings", key, settings[key])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)
