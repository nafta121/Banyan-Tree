class_name BottomSheetHost
extends Control

signal sheet_pushed(open_count: int)
signal sheet_popped(open_count: int)
signal stack_emptied()

var _sheet_stack: Array[Control] = []


func _init() -> void:
	name = "BottomSheetHost"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", _on_theme_updated)
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", _on_locale_changed)
	_sync_visibility()


func get_open_count() -> int:
	return _sheet_stack.size()


func push_sheet(content: Control, title: String = "") -> void:
	if content == null:
		return
	if content.get_parent() != null:
		content.get_parent().remove_child(content)

	var layer := _build_sheet_layer(content, title)
	_sheet_stack.append(layer)
	add_child(layer)
	_sync_visibility()
	sheet_pushed.emit(_sheet_stack.size())


func pop_top_sheet() -> bool:
	if _sheet_stack.is_empty():
		_sync_visibility()
		return false

	var top_layer: Control = _sheet_stack.pop_back()
	if is_instance_valid(top_layer):
		top_layer.visible = false
		top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_inside_tree():
			top_layer.queue_free()
		else:
			if top_layer.get_parent() == self:
				remove_child(top_layer)
			top_layer.free()

	_sync_visibility()
	sheet_popped.emit(_sheet_stack.size())
	if _sheet_stack.is_empty():
		stack_emptied.emit()
	return true


func clear_all_sheets() -> void:
	while not _sheet_stack.is_empty():
		var layer: Control = _sheet_stack.pop_back()
		if is_instance_valid(layer):
			layer.visible = false
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if is_inside_tree():
				layer.queue_free()
			else:
				if layer.get_parent() == self:
					remove_child(layer)
				layer.free()
	_sync_visibility()
	stack_emptied.emit()


func _sync_visibility() -> void:
	var has_sheets := not _sheet_stack.is_empty()
	visible = has_sheets
	mouse_filter = Control.MOUSE_FILTER_STOP if has_sheets else Control.MOUSE_FILTER_IGNORE
	for i in range(_sheet_stack.size()):
		var layer := _sheet_stack[i]
		if is_instance_valid(layer):
			layer.visible = (i == _sheet_stack.size() - 1)


func _build_sheet_layer(content: Control, title: String) -> Control:
	var layer := Control.new()
	layer.name = "SheetLayer_%d" % _sheet_stack.size()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := Button.new()
	scrim.name = "ScrimButton"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.flat = false
	scrim.focus_mode = Control.FOCUS_NONE
	var scrim_sb := StyleBoxFlat.new()
	scrim_sb.bg_color = Color(0.0, 0.0, 0.0, 0.58)
	scrim.add_theme_stylebox_override("normal", scrim_sb)
	scrim.add_theme_stylebox_override("hover", scrim_sb)
	scrim.add_theme_stylebox_override("pressed", scrim_sb)
	scrim.add_theme_stylebox_override("focus", scrim_sb)
	scrim.pressed.connect(func() -> void: pop_top_sheet())
	layer.add_child(scrim)

	var card := PanelContainer.new()
	card.name = "SheetCard"
	card.anchor_left = 0.0
	card.anchor_right = 1.0
	card.anchor_top = 0.16
	card.anchor_bottom = 1.0
	card.offset_left = 0.0
	card.offset_right = 0.0
	card.offset_top = 0.0
	card.offset_bottom = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_sheet_card(card)
	layer.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.name = "SheetVBox"
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Drag handle pill
	var handle_center := CenterContainer.new()
	var handle_pill := Panel.new()
	handle_pill.custom_minimum_size = Vector2(44.0, 5.0)
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = _resolve_color("muted", Color.html("#94A3B8"))
	pill_sb.set_corner_radius_all(3)
	handle_pill.add_theme_stylebox_override("panel", pill_sb)
	handle_center.add_child(handle_pill)
	vbox.add_child(handle_center)

	# Sheet Title
	var title_lbl := Label.new()
	title_lbl.name = "SheetTitleLabel"
	title_lbl.text = title
	title_lbl.visible = not title.strip_edges().is_empty()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.theme_type_variation = &"HeaderLabel"
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	sep.visible = title_lbl.visible
	vbox.add_child(sep)

	# Scrollable body container so tall content never overflows 412x915
	var scroll := ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content.size_flags_vertical == 0:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Bottom thumb-zone close button (>= 48px)
	var close_btn := Button.new()
	close_btn.name = "SheetCloseButton"
	close_btn.custom_minimum_size = Vector2(0.0, 48.0)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.text = _resolve_back_text()
	close_btn.pressed.connect(func() -> void: pop_top_sheet())
	vbox.add_child(close_btn)

	return layer


func _style_sheet_card(card: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _resolve_color("surface", Color.html("#182028"))
	sb.border_color = _resolve_color("border", Color.html("#26323F"))
	sb.border_width_top = 2
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", sb)


func _resolve_color(role: String, fallback: Color) -> Color:
	if is_inside_tree():
		var tm := get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("color"):
			return tm.call("color", role) as Color
	return fallback


func _resolve_back_text() -> String:
	if is_inside_tree():
		var loc := get_node_or_null("/root/LocaleService")
		if loc != null and loc.has_method("tr_fmt"):
			return String(loc.call("tr_fmt", "common.back"))
	return "Back"


func _on_theme_updated() -> void:
	for layer in _sheet_stack:
		if not is_instance_valid(layer):
			continue
		var card := layer.get_node_or_null("SheetCard") as PanelContainer
		if card != null:
			_style_sheet_card(card)


func _on_locale_changed(_new_locale: String) -> void:
	var back_txt := _resolve_back_text()
	for layer in _sheet_stack:
		if not is_instance_valid(layer):
			continue
		var close_btn := layer.get_node_or_null("SheetCard/SheetVBox/SheetCloseButton") as Button
		if close_btn != null:
			close_btn.text = back_txt
