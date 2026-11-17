class_name HemicycleCanvas
extends Control

var _seat_colors: Array[Color] = []
var _layout_cache: Array[Dictionary] = []
var _cached_count: int = -1
var _highlight_quorum: bool = false
var _quorum_seat_index: int = 350 # 351st seat (0-indexed 350)


func _init() -> void:
	name = "HemicycleCanvas"
	custom_minimum_size = Vector2(280.0, 176.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", queue_redraw)


func set_seats_data(seat_colors: Array[Color], highlight_quorum: bool = false) -> void:
	_seat_colors = seat_colors.duplicate()
	_highlight_quorum = highlight_quorum
	var count := _seat_colors.size()
	if count != _cached_count:
		_cached_count = count
		_rebuild_layout(count)
	queue_redraw()


func get_seat_count() -> int:
	return _seat_colors.size()


func _rebuild_layout(count: int) -> void:
	_layout_cache.clear()
	if count <= 0:
		return
	var em := get_node_or_null("/root/ElectionManager")
	if em != null and em.has_method("generate_hemicycle_layout"):
		_layout_cache = em.call("generate_hemicycle_layout", count)
		return
	# Fallback standalone generator if called outside SceneTree
	for i in range(count):
		var row_idx := i % 13
		var u := float(i) / float(maxi(1, count - 1))
		var theta := PI * (1.0 - (0.05 + u * 0.90))
		var rx := 21.0 + (float(row_idx) / 12.0) * 26.5
		var ry := rx * 1.90
		_layout_cache.append({
			"x": 50.0 + rx * cos(theta),
			"y": 92.0 - ry * sin(theta),
			"theta": theta,
			"row": row_idx,
			"sector": mini(4, int(floor(u * 5.0))),
		})


func _resolve_color(role: String, fallback: Color) -> Color:
	if is_inside_tree():
		var tm := get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("color"):
			return tm.call("color", role) as Color
	return fallback


func _draw() -> void:
	var rect_sz := size
	if rect_sz.x <= 8.0 or rect_sz.y <= 8.0:
		return

	var pad_x := 8.0
	var pad_top := 8.0
	var pad_bot := 10.0
	var avail_w := maxf(40.0, rect_sz.x - pad_x * 2.0)
	var avail_h := maxf(30.0, rect_sz.y - pad_top - pad_bot)

	# Aspect ratio of logical 0..100 x 0..96 hemicycle box (~1.85 : 1)
	var target_w := minf(avail_w, avail_h * 1.88)
	var target_h := target_w / 1.88
	var origin_x := (rect_sz.x - target_w) * 0.5
	var origin_y := pad_top + (avail_h - target_h) * 0.5

	# Subtle rostrum / podium arc at the center bottom of the chamber
	var rostrum_center := Vector2(origin_x + target_w * 0.50, origin_y + target_h * 0.94)
	var border_col := _resolve_color("border", Color.html("#26323F"))
	var accent_col := _resolve_color("accent", Color.html("#E5A93C"))
	draw_arc(rostrum_center, target_w * 0.13, PI, TAU, 32, border_col, 1.5, true)
	draw_circle(rostrum_center, maxf(3.0, target_w * 0.022), accent_col.lerp(border_col, 0.45))

	if _highlight_quorum:
		# Vertical majority midline indicator (351 / 700 seats)
		var q_top := Vector2(rostrum_center.x, origin_y + 2.0)
		var q_bot := Vector2(rostrum_center.x, rostrum_center.y - target_w * 0.14)
		draw_dashed_line(q_top, q_bot, accent_col.lerp(border_col, 0.2), 1.5, 4.0, true)

	var n := mini(_seat_colors.size(), _layout_cache.size())
	if n <= 0:
		return

	var dot_radius := clampf(target_w / 145.0, 1.65, 4.2)
	for i in range(n):
		var pt: Dictionary = _layout_cache[i]
		var px := origin_x + (float(pt.get("x", 50.0)) / 100.0) * target_w
		var py := origin_y + (float(pt.get("y", 92.0)) / 96.0) * target_h
		var col: Color = _seat_colors[i]
		draw_circle(Vector2(px, py), dot_radius, col)
		if _highlight_quorum and i == _quorum_seat_index:
			draw_arc(Vector2(px, py), dot_radius + 1.4, 0.0, TAU, 12, accent_col, 1.1, true)
