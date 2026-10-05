class_name UITheme
extends RefCounted
## Shared look for all menus and the HUD: chunky monospace text, dark rusty
## panels with brass borders. Also builds the PS1 post-process layer.

const BRASS := Color(0.88, 0.68, 0.32)
const RUST := Color(0.55, 0.22, 0.12)
const TEXT := Color(0.96, 0.9, 0.78)
const DIM := Color(0.65, 0.6, 0.52)
const RED := Color(0.9, 0.2, 0.14)
const GREEN := Color(0.35, 0.95, 0.45)
const CYAN := Color(0.4, 0.85, 1.0)
const PANEL_BG := Color(0.07, 0.05, 0.04, 0.82)

const POST_SHADER: Shader = preload("res://shaders/psx_post.gdshader")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Liberation Mono", "DejaVu Sans Mono", "Consolas", "monospace"])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE

	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color.BLACK)
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	t.set_stylebox("normal", "Button", _button_style(Color(0.16, 0.1, 0.07, 0.95), BRASS.darkened(0.4)))
	t.set_stylebox("hover", "Button", _button_style(Color(0.35, 0.18, 0.08, 0.95), BRASS))
	t.set_stylebox("pressed", "Button", _button_style(RUST, BRASS))
	t.set_stylebox("focus", "Button", _button_style(Color(0.35, 0.18, 0.08, 0.95), BRASS))
	t.set_stylebox("disabled", "Button", _button_style(Color(0.1, 0.08, 0.07, 0.8), Color(0.3, 0.3, 0.3)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_focus_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	t.set_color("font_color", "CheckButton", TEXT)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_border_width_all(2)
	bg.border_color = Color(0, 0, 0, 0.9)
	t.set_stylebox("background", "ProgressBar", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BRASS
	t.set_stylebox("fill", "ProgressBar", fill)

	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.2, 0.15, 0.1)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	_theme = t
	return t


static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(2)
	sb.border_color = BRASS.darkened(0.3)
	sb.set_content_margin_all(12)
	return sb


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 18, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func bar(fill_color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.max_value = 1.0
	b.step = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(Sfx.play.bind("ui_select", -8.0))
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(Sfx.play.bind("ui_move", -14.0))
	return b


## Full-screen PS1 filter (pixelation + dithering). Sits under the HUD.
## Call apply_post_settings() on its "Filter" child when settings change.
static func make_post_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PSXPost"
	layer.layer = 1
	var rect := ColorRect.new()
	rect.name = "Filter"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	rect.material = mat
	layer.add_child(rect)
	apply_post_settings(rect)
	return layer


static func apply_post_settings(rect: ColorRect) -> void:
	if not is_instance_valid(rect):
		return
	rect.visible = bool(GameState.get_setting("psx_filter"))
	(rect.material as ShaderMaterial).set_shader_parameter("pixel_size", float(GameState.get_setting("pixel_size")))
