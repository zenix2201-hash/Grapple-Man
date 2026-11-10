extends Control
## Starting loadout picker. Click weapons to add them to your belt (up to
## WeaponDB.MAX_LOADOUT); the order you pick them is their slot number.

@export_file("*.tscn") var play_scene: String = "res://Scenes/Testlevel.tscn"
@export_file("*.tscn") var menu_scene: String = "res://Scenes/main_menu.tscn"

var _selected: Array[String] = []
var _cards: Dictionary = {} # id -> Button
var _slot_labels: Dictionary = {} # id -> Label
var _summary: Label
var _start_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected = GameState.loadout.duplicate() if not GameState.loadout.is_empty() else WeaponDB.DEFAULT_LOADOUT.duplicate()
	_build()
	_refresh()
	_start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.035, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var title := UITheme.label("CHOOSE YOUR LOADOUT", 48, UITheme.BRASS)
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	col.add_child(UITheme.label("PICK UP TO %d WEAPONS. PICK ORDER = SLOT NUMBER." % WeaponDB.MAX_LOADOUT, 16, UITheme.DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	for id in WeaponDB.ORDER:
		grid.add_child(_make_card(id))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)

	var back := UITheme.button("BACK", _on_back)
	back.custom_minimum_size = Vector2(160, 52)
	bottom.add_child(back)

	_summary = UITheme.label("", 18, UITheme.TEXT)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_summary)

	_start_button = UITheme.button("RIDE OUT", _on_start)
	_start_button.custom_minimum_size = Vector2(240, 52)
	_start_button.add_theme_font_size_override("font_size", 24)
	bottom.add_child(_start_button)


func _make_card(id: String) -> Button:
	var info: Dictionary = WeaponDB.get_weapon(id)
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(280, 170)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggled.connect(_on_card_toggled.bind(id))
	card.mouse_entered.connect(Sfx.play.bind("ui_move", -14.0))

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 14)
	card.add_child(pad)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	pad.add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var name_label := UITheme.label(String(info["name"]), 24, UITheme.BRASS)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var slot := UITheme.label("", 22, UITheme.GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(slot)

	box.add_child(UITheme.label(String(info["type"]), 14, UITheme.DIM))
	var desc := UITheme.label(String(info["desc"]), 15, UITheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(desc)

	_cards[id] = card
	_slot_labels[id] = slot
	return card


func _on_card_toggled(on: bool, id: String) -> void:
	if on:
		if _selected.size() >= WeaponDB.MAX_LOADOUT:
			# Belt is full: refuse the pick.
			Sfx.play("hurt", -12.0, 1.6)
			(_cards[id] as Button).set_pressed_no_signal(false)
			_flash_summary()
			return
		if not _selected.has(id):
			_selected.append(id)
		Sfx.play("ui_select", -8.0)
	else:
		_selected.erase(id)
		Sfx.play("ui_move", -8.0, 0.7)
	_refresh()


func _refresh() -> void:
	for id in _cards:
		var idx := _selected.find(id)
		(_cards[id] as Button).set_pressed_no_signal(idx >= 0)
		(_slot_labels[id] as Label).text = "[%d]" % (idx + 1) if idx >= 0 else ""
	var names: PackedStringArray = []
	for id in _selected:
		names.append(String(WeaponDB.get_weapon(id)["name"]))
	_summary.text = "%d/%d  %s" % [_selected.size(), WeaponDB.MAX_LOADOUT, "  ".join(names)]
	_start_button.disabled = _selected.is_empty()


func _flash_summary() -> void:
	_summary.add_theme_color_override("font_color", UITheme.RED)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void: _summary.add_theme_color_override("font_color", UITheme.TEXT))


func _on_start() -> void:
	if _selected.is_empty():
		return
	GameState.loadout = _selected.duplicate()
	GameState.start_run()
	GameState.goto_scene(play_scene)


func _on_back() -> void:
	GameState.goto_scene(menu_scene)
