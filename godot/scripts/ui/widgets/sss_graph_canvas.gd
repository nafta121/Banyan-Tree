class_name SSSGraphCanvas
extends Control

signal card_rank_requested(card_id: String, new_rank: int)
signal card_focused(card_id: String)

const PAD_X := 28.0
const PAD_Y := 52.0
const CARD_W := 236.0
const CARD_H := 196.0
const GAP_X := 64.0
const GAP_Y := 32.0
const COLS := 6
const ROWS := 4
const OVERVIEW_SCALE := 0.75
const RANK_VALUES: Array[int] = [0, 5, 10, 20]

var zoom_scale: float = 1.0
var highlighted_card_id: String = ""

var _pan_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_accum: float = 0.0
var _button_handled_gesture: bool = false

var _board_surface: Control = null
var _edge_layer: _SSSEdgeLayer = null
var _col_headers: Array[Label] = []
var _card_widgets: Dictionary = {}
var _edges: Array[Dictionary] = []


class _SSSEdgeLayer:
	extends Control
	var host_canvas: SSSGraphCanvas = null

	func _draw() -> void:
		if host_canvas != null:
			host_canvas._draw_edges_on(self)


func _init() -> void:
	name = "SSSGraphCanvas"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(360.0, 320.0)

	_board_surface = Control.new()
	_board_surface.name = "BoardSurface"
	_board_surface.mouse_filter = Control.MOUSE_FILTER_PASS
	_board_surface.size = _compute_board_size()
	add_child(_board_surface)

	_edge_layer = _SSSEdgeLayer.new()
	_edge_layer.name = "EdgeLayer"
	_edge_layer.host_canvas = self
	_edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_layer.size = _compute_board_size()
	_board_surface.add_child(_edge_layer)

	_build_board_nodes()


func _ready() -> void:
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", refresh_from_controller)
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", func(_l: String) -> void: refresh_from_controller())
	var sss := get_node_or_null("/root/SSSController")
	if sss != null and sss.has_signal("state_changed"):
		sss.connect("state_changed", refresh_from_controller)
	refresh_from_controller()


static func _compute_board_size() -> Vector2:
	var w := PAD_X * 2.0 + float(COLS) * CARD_W + float(COLS - 1) * GAP_X
	var h := PAD_Y + float(ROWS) * CARD_H + float(ROWS - 1) * GAP_Y + 32.0
	return Vector2(w, h)


static func _card_pos(col: int, row: int) -> Vector2:
	return Vector2(
		PAD_X + float(col) * (CARD_W + GAP_X),
		PAD_Y + float(row) * (CARD_H + GAP_Y)
	)


func get_card_node_count() -> int:
	return _card_widgets.size()


func get_edge_count() -> int:
	return _edges.size()


func get_pan_offset() -> Vector2:
	return _pan_offset


func pan_by(delta: Vector2) -> void:
	var vp := size if size.x > 40.0 and size.y > 40.0 else Vector2(384.0, 420.0)
	var scaled_board := _compute_board_size() * zoom_scale
	var min_x := minf(0.0, vp.x - scaled_board.x)
	var min_y := minf(0.0, vp.y - scaled_board.y)
	_pan_offset.x = clampf(_pan_offset.x + delta.x, min_x, 0.0)
	_pan_offset.y = clampf(_pan_offset.y + delta.y, min_y, 0.0)
	_apply_transform()


func set_overview_zoom(enabled: bool) -> void:
	zoom_scale = OVERVIEW_SCALE if enabled else 1.0
	pan_by(Vector2.ZERO)
	if _edge_layer != null:
		_edge_layer.queue_redraw()


func reset_view() -> void:
	zoom_scale = 1.0
	_pan_offset = Vector2.ZERO
	_apply_transform()
	if _edge_layer != null:
		_edge_layer.queue_redraw()


func _apply_transform() -> void:
	if _board_surface == null:
		return
	_board_surface.scale = Vector2(zoom_scale, zoom_scale)
	_board_surface.position = _pan_offset


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
		_drag_accum = 0.0
		_button_handled_gesture = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_drag_accum += sd.relative.length()
		pan_by(sd.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_drag_accum = 0.0
			_button_handled_gesture = false
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _dragging:
			var mm := event as InputEventMouseMotion
			_drag_accum += mm.relative.length()
			if _drag_accum > 6.0:
				pan_by(mm.relative)
				accept_event()


func _build_board_nodes() -> void:
	_col_headers.clear()
	_card_widgets.clear()
	_edges.clear()

	for c in range(COLS):
		var hdr := Label.new()
		hdr.name = "ColHeader_%d" % c
		hdr.position = Vector2(PAD_X + float(c) * (CARD_W + GAP_X), 14.0)
		hdr.size = Vector2(CARD_W, 28.0)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.theme_type_variation = &"MutedLabel"
		_board_surface.add_child(hdr)
		_col_headers.append(hdr)

	var cdb := _get_autoload("ContentDB")
	if cdb == null or not ("catalog" in cdb) or cdb.get("catalog") == null:
		return
	var catalog: GameCatalogData = cdb.get("catalog") as GameCatalogData
	if catalog == null:
		return

	var card_lookup := {}
	for card in catalog.sss_cards:
		card_lookup[card.id] = card
		var entry := _create_card_node(card)
		_card_widgets[card.id] = entry

	for card in catalog.sss_cards:
		for pid in card.prereqs:
			if card_lookup.has(pid):
				_edges.append({
					"from_id": pid,
					"to_id": card.id,
					"from_card": card_lookup[pid],
					"to_card": card,
				})


func _create_card_node(card: SSSCardData) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "GraphCard_" + card.id
	panel.position = _card_pos(card.col, card.row)
	panel.size = Vector2(CARD_W, CARD_H)
	panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_cid: String = card.id
	panel.gui_input.connect(func(ev: InputEvent) -> void: _on_card_panel_gui_input(panel_cid, ev))
	_board_surface.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(title_lbl)

	var badge_lbl := Label.new()
	badge_lbl.theme_type_variation = &"MutedLabel"
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(badge_lbl)

	var effect_rtl := RichTextLabel.new()
	effect_rtl.bbcode_enabled = true
	effect_rtl.fit_content = false
	effect_rtl.scroll_active = false
	effect_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(effect_rtl)

	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 4)
	rank_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rank_row)

	var rank_btns: Array[Button] = []
	var labels := ["OFF", "I", "II", "III"]
	for idx in range(RANK_VALUES.size()):
		var rk_val: int = RANK_VALUES[idx]
		var rb := Button.new()
		rb.text = labels[idx]
		rb.custom_minimum_size = Vector2(0.0, 48.0)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.mouse_filter = Control.MOUSE_FILTER_PASS
		var cid := card.id
		rb.button_down.connect(func() -> void:
			if not _dragging:
				_drag_accum = 0.0
				_button_handled_gesture = false
		)
		rb.pressed.connect(func() -> void: _on_rank_button_pressed(cid, rk_val))
		rank_row.add_child(rb)
		rank_btns.append(rb)

	return {
		"card": card,
		"panel": panel,
		"title": title_lbl,
		"badge": badge_lbl,
		"effect": effect_rtl,
		"rank_btns": rank_btns,
	}


func _on_card_panel_gui_input(card_id: String, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var is_release := false
	if event is InputEventScreenTouch:
		is_release = not (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		is_release = (mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed)
	if is_release and not _button_handled_gesture and _drag_accum <= 10.0:
		_on_card_tapped(card_id)


func _on_card_tapped(card_id: String) -> void:
	highlighted_card_id = card_id
	card_focused.emit(card_id)
	var sss := _get_autoload("SSSController")
	if sss != null and sss.has_method("is_card_unlocked") and not bool(sss.call("is_card_unlocked", card_id)):
		var audio := _get_autoload("AudioController")
		if audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", "blocked")
	if _edge_layer != null:
		_edge_layer.queue_redraw()


func _on_rank_button_pressed(card_id: String, rank_val: int) -> void:
	_button_handled_gesture = true
	if _drag_accum > 10.0:
		_drag_accum = 0.0
		return
	_on_card_tapped(card_id)
	var sss := _get_autoload("SSSController")
	if sss != null and sss.has_method("is_card_unlocked") and not bool(sss.call("is_card_unlocked", card_id)):
		return
	card_rank_requested.emit(card_id, rank_val)


func refresh_from_controller() -> void:
	var loc := _get_autoload("LocaleService")
	var sss := _get_autoload("SSSController")
	var tm := _get_autoload("ThemeManager")

	for c in range(_col_headers.size()):
		if loc != null and loc.has_method("tr_fmt"):
			_col_headers[c].text = String(loc.call("tr_fmt", "ucn.cc.col.%d" % c))
		else:
			_col_headers[c].text = "TIER %d" % (c + 1)

	var c_surface := Color.html("#182028")
	var c_surface_alt := Color.html("#1F2A35")
	var c_border := Color.html("#26323F")
	var c_accent := Color.html("#E5A93C")
	var c_muted := Color.html("#94A3B8")
	if tm != null and tm.has_method("color"):
		c_surface = tm.call("color", "surface") as Color
		c_surface_alt = tm.call("color", "surface_alt") as Color
		c_border = tm.call("color", "border") as Color
		c_accent = tm.call("color", "accent") as Color
		c_muted = tm.call("color", "muted") as Color

	var off_label := "OFF"
	if loc != null and loc.has_method("tr_fmt"):
		off_label = String(loc.call("tr_fmt", "ucn.cc.btn_off"))

	for cid in _card_widgets.keys():
		var item: Dictionary = _card_widgets[cid]
		var card: SSSCardData = item["card"]
		var panel: PanelContainer = item["panel"]
		var title_lbl: Label = item["title"]
		var badge_lbl: Label = item["badge"]
		var effect_rtl: RichTextLabel = item["effect"]
		var rank_btns: Array = item["rank_btns"]

		var lv := 10
		var unlocked := true
		if sss != null:
			var lv_map: Dictionary = sss.get("levels") if "levels" in sss else {}
			lv = int(lv_map.get(card.id, 10))
			if sss.has_method("is_card_unlocked"):
				unlocked = bool(sss.call("is_card_unlocked", card.id))

		if loc != null and loc.has_method("tr_fmt"):
			title_lbl.text = String(loc.call("tr_fmt", card.name_key))
		else:
			title_lbl.text = card.id

		badge_lbl.text = _format_rank_badge(lv, unlocked, loc)
		if sss != null and sss.has_method("format_card_effect"):
			effect_rtl.text = String(sss.call("format_card_effect", card.id, lv))

		var card_sb := StyleBoxFlat.new()
		card_sb.set_corner_radius_all(14)
		card_sb.content_margin_left = 10.0
		card_sb.content_margin_right = 10.0
		card_sb.content_margin_top = 8.0
		card_sb.content_margin_bottom = 8.0
		if not unlocked:
			card_sb.bg_color = c_surface.lerp(Color.BLACK, 0.18)
			card_sb.border_color = c_border
			card_sb.set_border_width_all(1)
		elif lv > 0:
			card_sb.bg_color = c_surface_alt
			card_sb.border_color = c_accent
			card_sb.set_border_width_all(2 if lv >= 20 else 1)
		else:
			card_sb.bg_color = c_surface
			card_sb.border_color = c_muted.lerp(c_border, 0.5)
			card_sb.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", card_sb)

		for idx in range(rank_btns.size()):
			var rb := rank_btns[idx] as Button
			if idx == 0:
				rb.text = off_label
			rb.disabled = not unlocked
			rb.mouse_filter = Control.MOUSE_FILTER_IGNORE if not unlocked else Control.MOUSE_FILTER_PASS
			var is_sel: bool = unlocked and lv == RANK_VALUES[idx]
			rb.theme_type_variation = &"AccentButton" if is_sel else &""

	if _edge_layer != null:
		_edge_layer.queue_redraw()


static func _format_rank_badge(lv: int, unlocked: bool, loc: Node) -> String:
	if not unlocked:
		return String(loc.call("tr_fmt", "ucn.cc.locked_badge")) if loc != null else "LOCKED"
	if lv <= 0:
		return String(loc.call("tr_fmt", "ucn.cc.rank_0")) if loc != null else "OFF"
	if lv <= 5:
		return String(loc.call("tr_fmt", "ucn.cc.rank_1")) if loc != null else "I"
	if lv <= 10:
		return String(loc.call("tr_fmt", "ucn.cc.rank_2")) if loc != null else "II"
	return String(loc.call("tr_fmt", "ucn.cc.rank_3")) if loc != null else "III"


func _draw_edges_on(canvas: Control) -> void:
	var sss := _get_autoload("SSSController")
	var tm := _get_autoload("ThemeManager")
	var c_border := Color.html("#26323F")
	var c_accent := Color.html("#E5A93C")
	var c_warn := Color.html("#FBBF24")
	if tm != null and tm.has_method("color"):
		c_border = tm.call("color", "border") as Color
		c_accent = tm.call("color", "accent") as Color
		c_warn = tm.call("color", "warn") as Color

	var req_path: PackedStringArray = PackedStringArray()
	if not highlighted_card_id.is_empty() and sss != null and sss.has_method("find_required_path"):
		req_path = sss.call("find_required_path", highlighted_card_id) as PackedStringArray

	var lv_map: Dictionary = sss.get("levels") if (sss != null and "levels" in sss) else {}

	for edge in _edges:
		var from_card: SSSCardData = edge["from_card"]
		var to_card: SSSCardData = edge["to_card"]
		var p0 := _card_pos(from_card.col, from_card.row) + Vector2(CARD_W, CARD_H * 0.5)
		var p3 := _card_pos(to_card.col, to_card.row) + Vector2(0.0, CARD_H * 0.5)
		var dx := (p3.x - p0.x) * 0.5
		var p1 := p0 + Vector2(dx, 0.0)
		var p2 := p3 - Vector2(dx, 0.0)

		var parent_on := int(lv_map.get(from_card.id, 0)) > 0
		var child_on := int(lv_map.get(to_card.id, 0)) > 0
		var in_req := req_path.has(from_card.id) and (req_path.has(to_card.id) or to_card.id == highlighted_card_id)

		var line_col := c_border
		var width := 2.0
		if in_req:
			line_col = c_warn
			width = 3.5
		elif parent_on and child_on:
			line_col = c_accent
			width = 3.0
		elif parent_on:
			line_col = c_accent.lerp(c_border, 0.45)
			width = 2.2

		var pts := PackedVector2Array()
		var steps := 14
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var u := 1.0 - t
			var pt := (
				u * u * u * p0
				+ 3.0 * u * u * t * p1
				+ 3.0 * u * t * t * p2
				+ t * t * t * p3
			)
			pts.append(pt)
		canvas.draw_polyline(pts, line_col, width, true)
		canvas.draw_circle(p0, 3.5, line_col)
		canvas.draw_circle(p3, 4.0, line_col)


func _get_autoload(auto_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + auto_name)
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.root != null:
		return ml.root.get_node_or_null(auto_name)
	return null
