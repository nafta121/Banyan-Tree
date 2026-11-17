extends Control

signal boot_completed(next_scene_path: String)

const TITLE_SCENE_PATH := "res://godot/scenes/title_screen.tscn"
const BOOT_DURATION := 0.45

var shell: SafeAreaShell = null
var auto_transition: bool = true
var allow_scene_change: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _title_label: Label = null
var _subtitle_label: Label = null
var _status_header_label: Label = null
var _loading_msg_label: Label = null
var _progress_bar: ProgressBar = null
var _continue_btn: Button = null

var _displayed_loading_message: String = ""
var _elapsed: float = 0.0
var _transitioned: bool = false


func _init() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	shell = SafeAreaShell.new()
	add_child(shell)

	var upper_box := VBoxContainer.new()
	upper_box.name = "UpperMasthead"
	upper_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper_box.alignment = BoxContainer.ALIGNMENT_CENTER
	upper_box.add_theme_constant_override("separation", 12)
	shell.content_root.add_child(upper_box)

	var card := PanelContainer.new()
	card.name = "BootEditorialCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_box.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(card_vbox)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = &"MutedLabel"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_subtitle_label)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_title_label)

	card_vbox.add_child(HSeparator.new())

	_status_header_label = Label.new()
	_status_header_label.theme_type_variation = &"MutedLabel"
	_status_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_status_header_label)

	_loading_msg_label = Label.new()
	_loading_msg_label.name = "LoadingMessageLabel"
	_loading_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_loading_msg_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 35.0
	_progress_bar.show_percentage = false
	card_vbox.add_child(_progress_bar)

	# Lower half thumb-zone action deck
	var lower_box := VBoxContainer.new()
	lower_box.name = "LowerThumbDeck"
	lower_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_box.alignment = BoxContainer.ALIGNMENT_END
	shell.content_root.add_child(lower_box)

	_continue_btn = Button.new()
	_continue_btn.name = "BootContinueButton"
	_continue_btn.custom_minimum_size = Vector2(0.0, 48.0)
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.theme_type_variation = &"AccentButton"
	_continue_btn.pressed.connect(transition_to_title)
	lower_box.add_child(_continue_btn)


func _ready() -> void:
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", _on_locale_changed)
	_refresh_texts()
	pick_random_loading_message()
	set_process(auto_transition)


func _process(delta: float) -> void:
	if not auto_transition or _transitioned:
		set_process(false)
		return
	_elapsed += delta
	var ratio := clampf(_elapsed / BOOT_DURATION, 0.0, 1.0)
	if _progress_bar != null:
		_progress_bar.value = ratio * 100.0
	if ratio >= 1.0:
		transition_to_title()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_texts()
	pick_random_loading_message()


func _refresh_texts() -> void:
	var loc := get_node_or_null("/root/LocaleService")
	if loc == null or not loc.has_method("tr_fmt"):
		_title_label.text = "Twilight of the Banyan Tree"
		_subtitle_label.text = "June 1999"
		_status_header_label.text = "LOADING ASSETS"
		_continue_btn.text = "Continue"
		return
	_title_label.text = String(loc.call("tr_fmt", "app.title"))
	_subtitle_label.text = String(loc.call("tr_fmt", "date.title_screen"))
	_status_header_label.text = String(loc.call("tr_fmt", "loader.default_title"))
	_continue_btn.text = String(loc.call("tr_fmt", "common.continue"))


func pick_random_loading_message() -> String:
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_method("get_loading_messages"):
		var pool: PackedStringArray = loc.call("get_loading_messages") as PackedStringArray
		if not pool.is_empty():
			var idx := rng.randi() % pool.size()
			_displayed_loading_message = pool[idx]
			if _loading_msg_label != null:
				_loading_msg_label.text = _displayed_loading_message
			return _displayed_loading_message
	_displayed_loading_message = "Loading..."
	if _loading_msg_label != null:
		_loading_msg_label.text = _displayed_loading_message
	return _displayed_loading_message


func get_displayed_loading_message() -> String:
	return _displayed_loading_message


func transition_to_title() -> void:
	if _transitioned:
		return
	_transitioned = true
	if _progress_bar != null:
		_progress_bar.value = 100.0
	set_process(false)
	boot_completed.emit(TITLE_SCENE_PATH)
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(TITLE_SCENE_PATH):
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)
