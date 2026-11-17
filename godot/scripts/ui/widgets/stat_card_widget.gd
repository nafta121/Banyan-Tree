class_name StatCardWidget
extends PanelContainer

const SEGMENT_COUNT := 5

var _stat_key: String = "pop"
var _value: int = 50
var _delta_hint: int = 0
var _min_floor: int = 0
var _max_ceil: int = 100
var _exact_mode: bool = false
var _has_binding: bool = false
var _display_value_text: String = ""

var _title_label: Label = null
var _value_label: Label = null
var _lock_label: Label = null
var _segments_row: HBoxContainer = null
var _segment_rects: Array[Panel] = []
var _exact_bar_wrap: Control = null
var _progress_bar: ProgressBar = null
var _floor_marker: ColorRect = null
var _ceil_marker: ColorRect = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(top_row)

	_title_label = Label.new()
	_title_label.name = "StatTitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(_title_label)

	_lock_label = Label.new()
	_lock_label.name = "StatLockLabel"
	_lock_label.theme_type_variation = &"MutedLabel"
	_lock_label.visible = false
	top_row.add_child(_lock_label)

	_value_label = Label.new()
	_value_label.name = "StatValueLabel"
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_value_label)

	# Coarse qualitative segments (shown when exact_mode == false)
	_segments_row = HBoxContainer.new()
	_segments_row.name = "QualitativeSegmentsRow"
	_segments_row.add_theme_constant_override("separation", 4)
	_segments_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(SEGMENT_COUNT):
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(0.0, 8.0)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_segments_row.add_child(seg)
		_segment_rects.append(seg)
	root_vbox.add_child(_segments_row)

	# Continuous progress bar + floor/ceiling lock markers (shown when exact_mode == true)
	_exact_bar_wrap = Control.new()
	_exact_bar_wrap.name = "ExactBarWrap"
	_exact_bar_wrap.custom_minimum_size = Vector2(0.0, 12.0)
	_exact_bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exact_bar_wrap.visible = false
	root_vbox.add_child(_exact_bar_wrap)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ExactProgressBar"
	_progress_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	_exact_bar_wrap.add_child(_progress_bar)

	_floor_marker = ColorRect.new()
	_floor_marker.name = "FloorLockMarker"
	_floor_marker.anchor_top = 0.0
	_floor_marker.anchor_bottom = 1.0
	_floor_marker.offset_left = -1.5
	_floor_marker.offset_right = 1.5
	_floor_marker.color = Color.html("#E5A93C")
	_floor_marker.visible = false
	_exact_bar_wrap.add_child(_floor_marker)

	_ceil_marker = ColorRect.new()
	_ceil_marker.name = "CeilLockMarker"
	_ceil_marker.anchor_top = 0.0
	_ceil_marker.anchor_bottom = 1.0
	_ceil_marker.offset_left = -1.5
	_ceil_marker.offset_right = 1.5
	_ceil_marker.color = Color.html("#F87171")
	_ceil_marker.visible = false
	_exact_bar_wrap.add_child(_ceil_marker)


func _ready() -> void:
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", _on_context_changed)
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", func(_l: String) -> void: _on_context_changed())
	if _has_binding:
		_refresh_view()


func bind_stat(
	stat_key: String,
	value: int,
	delta_hint: int,
	min_floor: int,
	max_ceil: int,
	exact_mode: bool
) -> void:
	_stat_key = stat_key
	_value = clampi(value, 0, 100)
	_delta_hint = delta_hint
	_min_floor = clampi(min_floor, 0, 100)
	_max_ceil = clampi(max_ceil, 0, 100)
	_exact_mode = exact_mode
	_has_binding = true
	_refresh_view()


func get_display_value_text() -> String:
	return _display_value_text


func _on_context_changed() -> void:
	if _has_binding:
		_refresh_view()


func _refresh_view() -> void:
	var loc := _get_autoload("LocaleService")
	var cdb := _get_autoload("ContentDB")
	var tm := _get_autoload("ThemeManager")

	var name_key := "effect_name." + _stat_key
	var stat_title := _stat_key.to_upper()
	if loc != null and loc.has_method("has_key") and bool(loc.call("has_key", name_key)):
		stat_title = String(loc.call("tr_fmt", name_key))
	elif loc != null and _stat_key.to_lower() == "pc" and bool(loc.call("has_key", "effect_name.PC")):
		stat_title = String(loc.call("tr_fmt", "effect_name.PC"))
	_title_label.text = stat_title

	var tier_label := "Stable"
	if loc != null and loc.has_method("tr_fmt"):
		tier_label = String(loc.call("tr_fmt", "stat.tier_fallback"))

	var tier_col := Color.html("#E5A93C")
	if tm != null and tm.has_method("color"):
		tier_col = tm.call("color", "accent") as Color

	if cdb != null and cdb.has_method("get_stat_tier"):
		var tier: StatTierData = cdb.call("get_stat_tier", _stat_key, float(_value)) as StatTierData
		if tier != null:
			if loc != null and loc.has_method("tr_fmt") and not tier.text_key.is_empty():
				tier_label = String(loc.call("tr_fmt", tier.text_key))
			if loc != null and loc.has_method("token_hex") and not tier.color_token.is_empty():
				tier_col = Color.html(String(loc.call("token_hex", tier.color_token)))
			elif not tier.color_hex.is_empty():
				tier_col = Color.html(tier.color_hex)

	var arrow := ""
	if _delta_hint > 0:
		arrow = " ↑"
	elif _delta_hint < 0:
		arrow = " ↓"

	_value_label.add_theme_color_override("font_color", tier_col)

	var inactive_col := Color.html("#1F2A35")
	if tm != null and tm.has_method("color"):
		inactive_col = tm.call("color", "surface_alt") as Color

	if not _exact_mode:
		# Qualitative fog: ONLY qualitative tier + trend arrow + 5 coarse segments; ZERO raw 0-100 integers
		_display_value_text = "%s%s" % [tier_label, arrow]
		_value_label.text = _display_value_text
		_lock_label.text = ""
		_lock_label.visible = false
		_segments_row.visible = true
		_exact_bar_wrap.visible = false

		var lit_segments := 0 if _value <= 0 else clampi(int(ceil(float(_value) / 20.0)), 1, SEGMENT_COUNT)
		for i in range(_segment_rects.size()):
			var seg_sb := StyleBoxFlat.new()
			seg_sb.bg_color = tier_col if i < lit_segments else inactive_col
			seg_sb.set_corner_radius_all(3)
			_segment_rects[i].add_theme_stylebox_override("panel", seg_sb)
	else:
		# Exact numbers mode: exact 0-100 integer + continuous progress bar + floor/ceiling lock markers
		var lock_parts: Array[String] = []
		if _min_floor > 0:
			lock_parts.append("≥%d" % _min_floor)
		if _max_ceil < 100:
			lock_parts.append("≤%d" % _max_ceil)
		var lock_suffix := (" [%s]" % " · ".join(lock_parts)) if not lock_parts.is_empty() else ""

		_value_label.text = "%s · %d/100%s" % [tier_label, _value, arrow]
		_display_value_text = "%s%s" % [_value_label.text, lock_suffix]
		_lock_label.text = " · ".join(lock_parts)
		_lock_label.visible = not lock_parts.is_empty()

		_segments_row.visible = false
		_exact_bar_wrap.visible = true
		_progress_bar.value = float(_value)

		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = tier_col
		fill_sb.set_corner_radius_all(5)
		_progress_bar.add_theme_stylebox_override("fill", fill_sb)

		_floor_marker.visible = _min_floor > 0
		if _min_floor > 0:
			var fx := clampf(float(_min_floor) / 100.0, 0.0, 1.0)
			_floor_marker.anchor_left = fx
			_floor_marker.anchor_right = fx

		_ceil_marker.visible = _max_ceil < 100
		if _max_ceil < 100:
			var cx := clampf(float(_max_ceil) / 100.0, 0.0, 1.0)
			_ceil_marker.anchor_left = cx
			_ceil_marker.anchor_right = cx


func _get_autoload(auto_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + auto_name)
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.root != null:
		return ml.root.get_node_or_null(auto_name)
	return null
