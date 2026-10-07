class_name HUD
extends CanvasLayer

const CrosshairWidget := preload("res://UI/crosshair.gd")
const VIGNETTE_SHADER: Shader = preload("res://shaders/vignette.gdshader")

var player: Player

var _post_filter: ColorRect
var _vignette_mat: ShaderMaterial
var _vignette := 0.0
var _vignette_color := Color.RED
var _hp_bar: ProgressBar
var _hp_label: Label
var _dash_box: HBoxContainer
var _dash_pips: Array[ProgressBar] = []
var _scrap_label: Label
var _grenade_label: Label
var _weapon_label: Label
var _slot_box: HBoxContainer
var _slot_labels: Array[Label] = []
var _style_box: VBoxContainer
var _rank_letter: Label
var _rank_name: Label
var _rank_bar: ProgressBar
var _style_feed: VBoxContainer
var _floor_label: Label
var _info_label: Label
var _banner: Label
var _banner_sub: Label
var _banner_t := 0.0
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _speed_h: Label
var _speed_v: Label
var _crosshair: CrosshairWidget


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var post: CanvasLayer = UITheme.make_post_layer()
	add_child(post)
	_post_filter = post.get_node("Filter")
	_build()
	GameState.style_event.connect(_on_style_event)
	GameState.rank_changed.connect(_on_rank_changed)
	GameState.banner.connect(show_banner)
	GameState.boss_update.connect(_on_boss_update)
	GameState.hitmarker.connect(_on_hitmarker)
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.settings_changed.connect(_on_settings_changed)
	_on_rank_changed(GameState.rank)


func setup(p: Player) -> void:
	player = p
	p.hurt.connect(_on_hurt)
	p.healed.connect(_on_healed)
	p.parried.connect(_on_parried)
	p.died.connect(_on_died)
	_rebuild_slots()
	p.weapon_manager.weapon_changed.connect(func(_w: Weapon, _i: int) -> void: _refresh_slots())


## Text shown under the floor label (wave counter etc).
func set_info(text: String) -> void:
	_info_label.text = text


func set_floor_text(text: String) -> void:
	_floor_label.text = text


func show_banner(title: String, subtitle: String = "") -> void:
	_banner.text = title
	_banner_sub.text = subtitle
	_banner_t = 2.5


# --- Building ---

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	# Screen flash (damage / heal / parry)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER
	vignette.material = _vignette_mat
	root.add_child(vignette)

	# Crosshair
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_crosshair = CrosshairWidget.new()
	center.add_child(_crosshair)

	# Banner (upper middle)
	var banner_box := VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.offset_top = 150
	banner_box.offset_left = -400
	banner_box.offset_right = 400
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_box)
	_banner = UITheme.label("", 44, UITheme.BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner_sub = UITheme.label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	banner_box.add_child(_banner)
	banner_box.add_child(_banner_sub)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)

	# --- Top row ---
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(top)

	var top_left := VBoxContainer.new()
	top_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_left)
	_speed_h = UITheme.label("H SPEED 0", 14, UITheme.DIM)
	_speed_v = UITheme.label("V SPEED 0", 14, UITheme.DIM)
	top_left.add_child(_speed_h)
	top_left.add_child(_speed_v)

	var top_mid := VBoxContainer.new()
	top_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_mid)
	_floor_label = UITheme.label("", 22, UITheme.BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_info_label = UITheme.label("", 16, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	top_mid.add_child(_floor_label)
	top_mid.add_child(_info_label)
	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_mid.add_child(_boss_box)
	_boss_name = UITheme.label("", 20, UITheme.RED, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_bar = UITheme.bar(UITheme.RED, Vector2(420, 16))
	_boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(_boss_name)
	_boss_box.add_child(_boss_bar)

	var top_right := VBoxContainer.new()
	top_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_right)
	_style_box = VBoxContainer.new()
	_style_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_box.custom_minimum_size = Vector2(240, 0)
	_style_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(_style_box)
	var style_panel := PanelContainer.new()
	style_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_box.add_child(style_panel)
	var style_inner := VBoxContainer.new()
	style_panel.add_child(style_inner)
	var rank_row := HBoxContainer.new()
	style_inner.add_child(rank_row)
	_rank_letter = UITheme.label("D", 54)
	_rank_letter.add_theme_constant_override("outline_size", 8)
	rank_row.add_child(_rank_letter)
	_rank_name = UITheme.label("", 18)
	_rank_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(_rank_name)
	_rank_bar = UITheme.bar(UITheme.BRASS, Vector2(210, 8))
	style_inner.add_child(_rank_bar)
	_style_feed = VBoxContainer.new()
	_style_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_box.add_child(_style_feed)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	# --- Bottom row ---
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(bottom)

	var vitals := PanelContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(vitals)
	var vitals_box := VBoxContainer.new()
	vitals.add_child(vitals_box)
	var hp_row := HBoxContainer.new()
	vitals_box.add_child(hp_row)
	hp_row.add_child(UITheme.label("HP", 20, UITheme.RED))
	_hp_bar = UITheme.bar(Color(0.85, 0.22, 0.15), Vector2(240, 22))
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_label = UITheme.label("100", 20)
	_hp_label.custom_minimum_size = Vector2(48, 0)
	hp_row.add_child(_hp_label)
	var dash_row := HBoxContainer.new()
	vitals_box.add_child(dash_row)
	dash_row.add_child(UITheme.label("DASH", 14, UITheme.CYAN))
	_dash_box = HBoxContainer.new()
	_dash_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dash_row.add_child(_dash_box)
	_scrap_label = UITheme.label("SCRAP 0", 16, UITheme.BRASS)
	vitals_box.add_child(_scrap_label)
	_grenade_label = UITheme.label("GRENADE READY", 16, UITheme.TEXT)
	vitals_box.add_child(_grenade_label)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_spacer)

	var weapon_panel := PanelContainer.new()
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(weapon_panel)
	var weapon_box := VBoxContainer.new()
	weapon_panel.add_child(weapon_box)
	_weapon_label = UITheme.label("", 26, UITheme.BRASS, HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_box.add_child(_weapon_label)
	_slot_box = HBoxContainer.new()
	_slot_box.alignment = BoxContainer.ALIGNMENT_END
	weapon_box.add_child(_slot_box)


# --- Per-frame ---

func _process(delta: float) -> void:
	_vignette = maxf(_vignette - delta * 1.8, 0.0)
	_vignette_mat.set_shader_parameter("intensity", _vignette)
	_vignette_mat.set_shader_parameter("tint", _vignette_color)

	_banner_t = maxf(_banner_t - delta, 0.0)
	var banner_alpha := clampf(_banner_t / 0.5, 0.0, 1.0)
	_banner.modulate.a = banner_alpha
	_banner_sub.modulate.a = banner_alpha

	if player == null or not is_instance_valid(player):
		return

	var hp_frac: float = player.health / maxf(player.max_health, 1.0)
	_hp_bar.value = lerpf(_hp_bar.value, hp_frac, minf(delta * 12.0, 1.0))
	_hp_label.text = str(int(ceilf(player.health)))
	_hp_label.add_theme_color_override("font_color", UITheme.RED if hp_frac < 0.3 else UITheme.TEXT)

	var dash_max: int = int(GameState.stat("dash_charges"))
	if _dash_pips.size() != dash_max:
		_rebuild_dash_pips(dash_max)
	for i in _dash_pips.size():
		_dash_pips[i].value = clampf(player.dash_charges - i, 0.0, 1.0)
	_scrap_label.text = "SCRAP %d" % GameState.scrap
	if player.grenade_timer > 0.0:
		_grenade_label.text = "GRENADE %.1f" % player.grenade_timer
		_grenade_label.add_theme_color_override("font_color", UITheme.DIM)
	else:
		_grenade_label.text = "GRENADE READY [G]"
		_grenade_label.add_theme_color_override("font_color", UITheme.TEXT)

	_speed_h.text = "H SPEED %d" % int(roundf(Vector2(player.velocity.x, player.velocity.z).length()))
	_speed_v.text = "V SPEED %d" % int(roundf(player.velocity.y))

	_crosshair.health_frac = hp_frac
	_crosshair.dash_frac = player.dash_charges / maxf(GameState.stat("dash_charges"), 1.0)
	_crosshair.dash_count = dash_max
	_crosshair.grapple_state = 2 if player.is_grappling else (1 if player.grapple_in_range else 0)
	var weapon: Weapon = player.weapon_manager.current_weapon
	_crosshair.charge = weapon.get_charge() if weapon != null else 0.0

	_rank_bar.value = GameState.rank_progress()
	_style_box.modulate.a = lerpf(_style_box.modulate.a, 1.0 if GameState.rank >= 0 or _style_feed.get_child_count() > 0 else 0.0, minf(delta * 6.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	# Esc frees the mouse; click in the game window to capture it again.
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _rebuild_dash_pips(count: int) -> void:
	for c in _dash_box.get_children():
		c.queue_free()
	_dash_pips.clear()
	for i in count:
		var pip: ProgressBar = UITheme.bar(UITheme.CYAN, Vector2(44, 12))
		_dash_box.add_child(pip)
		_dash_pips.append(pip)


func _rebuild_slots() -> void:
	for c in _slot_box.get_children():
		c.queue_free()
	_slot_labels.clear()
	for i in player.weapon_manager.weapons.size():
		var l: Label = UITheme.label("", 14, UITheme.DIM)
		_slot_box.add_child(l)
		_slot_labels.append(l)
	_refresh_slots()


func _refresh_slots() -> void:
	var wm: WeaponManager = player.weapon_manager
	for i in _slot_labels.size():
		var w: Weapon = wm.weapons[i]
		var active: bool = w == wm.current_weapon
		_slot_labels[i].text = "[%d %s]" % [i + 1, w.weapon_name] if active else " %d %s " % [i + 1, w.weapon_name]
		_slot_labels[i].add_theme_color_override("font_color", UITheme.TEXT if active else UITheme.DIM)
	if wm.current_weapon:
		_weapon_label.text = wm.current_weapon.weapon_name


# --- Events ---

func _on_style_event(text: String, points: int) -> void:
	var l: Label = UITheme.label("+ %s" % text, 17 if points < 30 else 20, UITheme.TEXT if points < 30 else UITheme.BRASS, HORIZONTAL_ALIGNMENT_RIGHT)
	_style_feed.add_child(l)
	_style_feed.move_child(l, 0)
	while _style_feed.get_child_count() > 6:
		var old := _style_feed.get_child(_style_feed.get_child_count() - 1)
		_style_feed.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_rank_changed(rank: int) -> void:
	if rank < 0:
		_rank_letter.text = ""
		_rank_name.text = ""
		return
	var info: Dictionary = GameState.RANKS[rank]
	var col: Color = info["color"]
	_rank_letter.text = info["letter"]
	_rank_name.text = info["name"]
	_rank_letter.add_theme_color_override("font_color", col)
	_rank_name.add_theme_color_override("font_color", col)
	(_rank_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col


func _on_boss_update(boss_name: String, fraction: float) -> void:
	_boss_box.visible = fraction >= 0.0
	_boss_name.text = boss_name
	_boss_bar.value = fraction


func _on_hitmarker(crit: bool) -> void:
	_crosshair.hit(crit)
	Sfx.play("hit", -12.0, 1.4 if crit else 1.0)


func _on_enemy_killed(_enemy: Node) -> void:
	_crosshair.kill()


func _on_hurt(_amount: float) -> void:
	_flash(UITheme.RED, 0.9)


func _on_healed(_amount: float) -> void:
	_flash(UITheme.GREEN, 0.4)


func _on_parried() -> void:
	_flash(Color(1, 1, 1), 1.0)
	show_banner("PARRY", "")
	_banner_t = 0.6


func _flash(color: Color, amount: float) -> void:
	_vignette_color = color
	_vignette = maxf(_vignette, amount)


func _on_died() -> void:
	show_banner("SCRAPPED", "")
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	GameState.restart_level()


func _on_settings_changed() -> void:
	UITheme.apply_post_settings(_post_filter)
