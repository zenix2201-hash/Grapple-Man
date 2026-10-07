extends Control

const TEX: Texture2D = preload("res://assets/crosshair.png")

var grapple_state := 0 ## 0 = out of range, 1 = in range, 2 = attached
var health_frac := 1.0
var dash_frac := 1.0
var dash_count := 3
var charge := 0.0

var _hit_t := 0.0
var _kill_t := 0.0
var _crit := false


func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(crit: bool) -> void:
	_hit_t = 0.15
	_crit = crit


func kill() -> void:
	_kill_t = 0.3


func _process(delta: float) -> void:
	_hit_t = maxf(_hit_t - delta, 0.0)
	_kill_t = maxf(_kill_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ts := Vector2(28, 28)
	draw_texture_rect(TEX, Rect2(c - ts * 0.5, ts), false)

	# Lasso ring
	var ring := Color(1, 1, 1, 0.12)
	if grapple_state == 1:
		ring = Color(0.35, 1.0, 0.45, 0.9)
	elif grapple_state == 2:
		ring = Color(1.0, 0.75, 0.3, 1.0)
	draw_arc(c, 20.0, 0.0, TAU, 24, ring, 2.0)

	# Health arc (left) and dash arc (right)
	var r := 34.0
	var span := PI * 0.6
	draw_arc(c, r, PI - span * 0.5, PI + span * 0.5, 16, Color(0, 0, 0, 0.5), 5.0)
	var hp_col: Color = UITheme.RED if health_frac < 0.3 else Color(0.95, 0.35, 0.25)
	if health_frac > 0.0:
		draw_arc(c, r, PI + span * 0.5 - span * health_frac, PI + span * 0.5, 16, hp_col, 4.0)
	draw_arc(c, r, -span * 0.5, span * 0.5, 16, Color(0, 0, 0, 0.5), 5.0)
	if dash_frac > 0.0:
		draw_arc(c, r, span * 0.5 - span * dash_frac, span * 0.5, 16, UITheme.CYAN, 4.0)
	for i in range(1, dash_count):
		var a := span * 0.5 - span * float(i) / dash_count
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 4.0), c + Vector2(cos(a), sin(a)) * (r + 4.0), Color(0, 0, 0, 0.9), 2.0)

	# Alt-fire charge
	if charge > 0.0:
		draw_arc(c, 26.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 24, Color(0.4, 0.9, 1.0) if charge >= 1.0 else UITheme.BRASS, 3.0)

	# Hit markers
	if _hit_t > 0.0 or _kill_t > 0.0:
		var col := Color.WHITE
		if _kill_t > 0.0:
			col = UITheme.RED
		elif _crit:
			col = Color(1.0, 0.95, 0.3)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 7.0, c + d * 14.0, col, 3.0)
