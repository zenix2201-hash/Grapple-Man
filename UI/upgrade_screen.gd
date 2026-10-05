class_name UpgradeScreen
extends Control
## Shown between floors while the lift rises. Pick one of three parts to bolt
## on (it replaces whatever is in that slot), spend scrap on repairs or a
## reroll, then head up.

signal finished

const REPAIR_COST := 25
const REPAIR_AMOUNT := 40.0
const REROLL_COST := 15

var _offers: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _cards: HBoxContainer
var _scrap_label: Label
var _hp_label: Label
var _repair_button: Button
var _reroll_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	GameState.ui_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rng.randomize()
	_build()
	_roll()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.02, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title: Label = UITheme.label("FLOOR %d CLEARED" % GameState.floor_num, 44, UITheme.BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	box.add_child(UITheme.label("THE LIFT IS RISING. BOLT ON A NEW PART.", 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 16)
	box.add_child(_cards)

	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 30)
	box.add_child(info)
	_scrap_label = UITheme.label("", 20, UITheme.BRASS)
	_hp_label = UITheme.label("", 20, UITheme.RED)
	info.add_child(_scrap_label)
	info.add_child(_hp_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_repair_button = UITheme.button("REPAIR +%d HP (%d SCRAP)" % [int(REPAIR_AMOUNT), REPAIR_COST], _repair)
	_reroll_button = UITheme.button("REROLL (%d SCRAP)" % REROLL_COST, _reroll)
	buttons.add_child(_repair_button)
	buttons.add_child(_reroll_button)
	buttons.add_child(UITheme.button("SKIP", _close))


func _roll() -> void:
	_offers = PartsDB.random_offer(3, GameState.equipped, _rng)
	for c in _cards.get_children():
		c.queue_free()
	for id in _offers:
		_cards.add_child(_make_card(id))
	_refresh()


func _make_card(id: String) -> Control:
	var part: Dictionary = PartsDB.get_part(id)
	var rarity: int = part["rarity"]
	var color: Color = PartsDB.RARITY_COLORS[rarity]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 300)
	var sb: StyleBoxFlat = UITheme.panel_style()
	sb.border_color = color
	sb.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UITheme.label("%s  |  %s" % [part["slot"], PartsDB.RARITY_NAMES[rarity]], 14, color))
	var name_label: Label = UITheme.label(part["name"], 24, color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(name_label)
	var desc: Label = UITheme.label(part["desc"], 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)
	box.add_child(UITheme.label(PartsDB.describe_stats(id), 16, UITheme.GREEN))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var current: Dictionary = PartsDB.get_part(GameState.equipped.get(part["slot"], ""))
	box.add_child(UITheme.label("REPLACES: %s" % current.get("name", "-"), 13, UITheme.DIM))
	box.add_child(UITheme.button("EQUIP", _pick.bind(id)))
	return panel


func _refresh() -> void:
	var max_hp: float = GameState.stat("max_health")
	var hp: float = GameState.player_health if GameState.player_health > 0.0 else max_hp
	_scrap_label.text = "SCRAP %d" % GameState.scrap
	_hp_label.text = "HP %d / %d" % [int(hp), int(max_hp)]
	_repair_button.disabled = GameState.scrap < REPAIR_COST or hp >= max_hp
	_reroll_button.disabled = GameState.scrap < REROLL_COST


func _repair() -> void:
	if not GameState.spend_scrap(REPAIR_COST):
		return
	var max_hp: float = GameState.stat("max_health")
	var hp: float = GameState.player_health if GameState.player_health > 0.0 else max_hp
	GameState.player_health = minf(hp + REPAIR_AMOUNT, max_hp)
	Sfx.play("pickup")
	_refresh()


func _reroll() -> void:
	if not GameState.spend_scrap(REROLL_COST):
		return
	_roll()


func _pick(id: String) -> void:
	GameState.equip(id)
	Sfx.play("rank_up")
	_close()


func _close() -> void:
	GameState.ui_open = false
	get_tree().paused = false
	finished.emit()
	queue_free()
