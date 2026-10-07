extends Control

@export_file("*.tscn") var play_scene: String = "res://Scenes/Testlevel.tscn"
@export var game_title: String = "GRAPPLE-MAN"
@export var tagline: String = "His name is Angus"
@export var version_text: String = "v0.1"

var _main_panel: VBoxContainer
var _settings_panel: PanelContainer
var _play_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_panel.visible:
		_show_settings(false)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.035, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = Color(UITheme.RUST, 0.35)
	stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_left = 0
	stripe.offset_right = 6
	add_child(stripe)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var row := HBoxContainer.new()
	margin.add_child(row)

	_main_panel = VBoxContainer.new()
	_main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_theme_constant_override("separation", 14)
	_main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_main_panel)

	var title := UITheme.label(game_title, 80, UITheme.BRASS)
	title.add_theme_constant_override("outline_size", 12)
	_main_panel.add_child(title)
	_main_panel.add_child(UITheme.label(tagline.to_upper(), 18, UITheme.DIM))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	_main_panel.add_child(gap)

	_play_button = _menu_button("PLAY", _on_play)
	_main_panel.add_child(_play_button)
	_main_panel.add_child(_menu_button("SETTINGS", _show_settings.bind(true)))
	_main_panel.add_child(_menu_button("QUIT", func() -> void: get_tree().quit()))

	_settings_panel = _build_settings()
	_settings_panel.visible = false
	_settings_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_settings_panel)

	var version := UITheme.label(version_text, 14, UITheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -200
	version.offset_top = -40
	version.offset_right = -24
	version.offset_bottom = -16
	add_child(version)


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := UITheme.button(text, on_pressed)
	b.custom_minimum_size = Vector2(300, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	return b


func _build_settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(UITheme.label("SETTINGS", 28, UITheme.BRASS))
	box.add_child(_slider("MOUSE SENSITIVITY", "mouse_sensitivity", 0.0005, 0.01, 0.0001))
	box.add_child(_slider("VOLUME", "volume", 0.0, 1.0, 0.05))
	box.add_child(_slider("PIXEL SIZE", "pixel_size", 1.0, 6.0, 1.0))

	var psx := CheckButton.new()
	psx.text = "PS1 FILTER"
	psx.button_pressed = bool(GameState.get_setting("psx_filter"))
	psx.toggled.connect(func(on: bool) -> void: GameState.set_setting("psx_filter", on))
	box.add_child(psx)

	var back := UITheme.button("BACK", _show_settings.bind(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(back)
	return panel


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> Control:
	var box := VBoxContainer.new()
	box.add_child(UITheme.label(text, 14, UITheme.DIM))
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(GameState.get_setting(key))
	slider.custom_minimum_size = Vector2(340, 20)
	slider.value_changed.connect(func(v: float) -> void: GameState.set_setting(key, v))
	box.add_child(slider)
	return box


func _show_settings(open: bool) -> void:
	_settings_panel.visible = open
	if not open:
		_play_button.grab_focus()


func _on_play() -> void:
	GameState.start_run()
	GameState.goto_scene(play_scene)
