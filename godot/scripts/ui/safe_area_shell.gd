class_name SafeAreaShell
extends Control

signal back_handled(stage: String)
signal returned_to_main_tab(main_tab: int)
signal exit_confirmation_shown()
signal quit_confirmed()

const DEFAULT_PAD_H := 14
const DEFAULT_PAD_V := 12

var bg_rect: ColorRect = null
var safe_margin_container: MarginContainer = null
var content_root: VBoxContainer = null
var bottom_sheet_host: BottomSheetHost = null

var main_tab_index: int = 0
var active_tab_index: int = 0
var custom_back_handler: Callable = Callable()
var allow_quit_execution: bool = true


func _init() -> void:
	name = "SafeAreaShell"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	bg_rect = ColorRect.new()
	bg_rect.name = "BackgroundRect"
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.color = Color.html("#0F1419")
	add_child(bg_rect)

	safe_margin_container = MarginContainer.new()
	safe_margin_container.name = "SafeMarginContainer"
	safe_margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_margin_values(DEFAULT_PAD_H, DEFAULT_PAD_V, DEFAULT_PAD_H, DEFAULT_PAD_V)
	add_child(safe_margin_container)

	content_root = VBoxContainer.new()
	content_root.name = "ContentRoot"
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_theme_constant_override("separation", 10)
	safe_margin_container.add_child(content_root)

	bottom_sheet_host = BottomSheetHost.new()
	add_child(bottom_sheet_host)


func _ready() -> void:
	if get_tree() != null:
		get_tree().set_quit_on_go_back(false)

	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null:
		if tm.has_signal("theme_updated"):
			tm.connect("theme_updated", _refresh_theme_colors)
		_refresh_theme_colors()

	update_safe_area_insets()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED:
			_save_settings_on_pause()
		NOTIFICATION_RESIZED:
			if is_inside_tree():
				update_safe_area_insets()


func _unhandled_input(event: InputEvent) -> void:
	if event != null and event.is_action_pressed("ui_cancel"):
		if handle_back_request() and is_inside_tree() and get_viewport() != null:
			get_viewport().set_input_as_handled()


func set_active_tab(tab_idx: int) -> void:
	active_tab_index = tab_idx


func handle_back_request() -> bool:
	if bottom_sheet_host != null and bottom_sheet_host.pop_top_sheet():
		back_handled.emit("bottom_sheet")
		return true

	if custom_back_handler.is_valid():
		var handled := bool(custom_back_handler.call())
		if handled:
			back_handled.emit("custom")
			return true

	if active_tab_index != main_tab_index:
		active_tab_index = main_tab_index
		returned_to_main_tab.emit(main_tab_index)
		back_handled.emit("main_tab")
		return true

	show_exit_confirmation_sheet()
	back_handled.emit("exit_prompt")
	return true


func show_exit_confirmation_sheet() -> void:
	if bottom_sheet_host == null:
		return

	var loc := get_node_or_null("/root/LocaleService") if is_inside_tree() else null
	var is_id := true
	if loc != null and "current_locale" in loc:
		is_id = String(loc.get("current_locale")) == "id"

	var sheet_title := "Konfirmasi Keluar" if is_id else "Confirm Exit"
	var body_text := (
		"Keluar dari Twilight of the Banyan Tree? Kemajuan terakhir Anda telah tersimpan otomatis."
		if is_id
		else "Exit Twilight of the Banyan Tree? Your latest progress and settings are saved."
	)
	var confirm_label := "Keluar Aplikasi" if is_id else "Exit Application"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var msg_lbl := Label.new()
	msg_lbl.text = body_text
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg_lbl)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmExitButton"
	confirm_btn.text = confirm_label
	confirm_btn.custom_minimum_size = Vector2(0.0, 48.0)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.theme_type_variation = &"AccentButton"
	confirm_btn.pressed.connect(_on_confirm_quit_pressed)
	box.add_child(confirm_btn)

	bottom_sheet_host.push_sheet(box, sheet_title)
	exit_confirmation_shown.emit()


func _on_confirm_quit_pressed() -> void:
	_save_settings_on_pause()
	quit_confirmed.emit()
	if allow_quit_execution and is_inside_tree() and get_tree() != null:
		get_tree().quit()


func _save_settings_on_pause() -> void:
	if not is_inside_tree():
		return
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc != null and save_svc.has_method("save_settings"):
		save_svc.call("save_settings")


func _refresh_theme_colors() -> void:
	if bg_rect == null or not is_inside_tree():
		return
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_method("color"):
		bg_rect.color = tm.call("color", "bg") as Color


func update_safe_area_insets() -> void:
	if safe_margin_container == null:
		return

	var left_pad := DEFAULT_PAD_H
	var top_pad := DEFAULT_PAD_V
	var right_pad := DEFAULT_PAD_H
	var bottom_pad := DEFAULT_PAD_V

	if DisplayServer.get_name() != "headless" and is_inside_tree() and get_viewport() != null:
		var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
		var win_size: Vector2i = DisplayServer.window_get_size()
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if win_size.x > 0 and win_size.y > 0 and safe_rect.size.x > 0 and safe_rect.size.y > 0 and vp_size.x > 0.0 and vp_size.y > 0.0:
			var sx := vp_size.x / float(win_size.x)
			var sy := vp_size.y / float(win_size.y)
			var inset_l := int(round(float(maxi(0, safe_rect.position.x)) * sx))
			var inset_t := int(round(float(maxi(0, safe_rect.position.y)) * sy))
			var inset_r := int(round(float(maxi(0, win_size.x - (safe_rect.position.x + safe_rect.size.x))) * sx))
			var inset_b := int(round(float(maxi(0, win_size.y - (safe_rect.position.y + safe_rect.size.y))) * sy))
			left_pad = maxi(DEFAULT_PAD_H, inset_l + 8)
			top_pad = maxi(DEFAULT_PAD_V, inset_t + 8)
			right_pad = maxi(DEFAULT_PAD_H, inset_r + 8)
			bottom_pad = maxi(DEFAULT_PAD_V, inset_b + 8)

	_apply_margin_values(left_pad, top_pad, right_pad, bottom_pad)


func _apply_margin_values(left_v: int, top_v: int, right_v: int, bottom_v: int) -> void:
	if safe_margin_container == null:
		return
	safe_margin_container.add_theme_constant_override("margin_left", left_v)
	safe_margin_container.add_theme_constant_override("margin_top", top_v)
	safe_margin_container.add_theme_constant_override("margin_right", right_v)
	safe_margin_container.add_theme_constant_override("margin_bottom", bottom_v)
