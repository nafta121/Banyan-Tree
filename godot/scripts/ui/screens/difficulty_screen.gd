extends Control

signal campaign_launched(difficulty_id: String)
signal navigated_back(scene_path: String)
signal sss_mode_changed(mode_id: String)

const TITLE_SCENE_PATH := "res://godot/scenes/title_screen.tscn"
const CAMPAIGN_SCENE_PATH := "res://godot/scenes/campaign_shell_screen.tscn"
const STANDARD_DIFFICULTIES: Array[String] = ["easy", "medium", "high", "historical"]
const MODE_LIST := "list_4_tracks"
const MODE_GRAPH := "node_map_2d"
const RANK_VALUES: Array[int] = [0, 5, 10, 20]

var shell: SafeAreaShell = null
var allow_scene_change: bool = true

var selected_difficulty: String = "historical"
var standard_forecast_enabled: bool = false
var sss_board_open: bool = false
var sss_view_mode: String = MODE_LIST

var diff_buttons: Dictionary = {}
var btn_diff_ucn: Button = null
var chk_standard_forecast: CheckBox = null
var btn_back_to_title: Button = null
var btn_briefing: Button = null
var btn_start_campaign: Button = null

var chk_sss_hide_forecast: CheckBox = null
var btn_sss_mode_list: Button = null
var btn_sss_mode_graph: Button = null
var btn_sss_presets: Button = null
var btn_sss_zoom: Button = null
var btn_sss_reset_view: Button = null
var btn_sss_close: Button = null
var btn_sss_launch: Button = null
var sss_graph_canvas: SSSGraphCanvas = null

var _standard_view_root: Control = null
var _diff_header_label: Label = null
var _diff_name_label: Label = null
var _diff_desc_rtl: RichTextLabel = null
var _ucn_lock_hint_label: Label = null

var _sss_view_root: VBoxContainer = null
var _sss_title_label: Label = null
var _sss_banner_label: Label = null
var _track_list_scroll: ScrollContainer = null
var _track_headers: Array[Label] = []
var _track_card_items: Dictionary = {}
var _graph_panel_wrap: VBoxContainer = null
var _graph_zoom_active: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	shell = SafeAreaShell.new()
	shell.custom_back_handler = Callable(self, "_on_custom_back")
	add_child(shell)

	_build_standard_difficulty_view()
	_build_sss_board_view()


func _ready() -> void:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc != null and "settings" in save_svc and save_svc.get("settings") != null:
		var s := save_svc.get("settings") as UserSettingsData
		standard_forecast_enabled = s.show_option_effects_override

	var sss := get_node_or_null("/root/SSSController")
	if sss != null:
		if sss.has_signal("state_changed"):
			sss.connect("state_changed", _refresh_sss_board_contents)
		if chk_sss_hide_forecast != null and "hide_forecast" in sss:
			chk_sss_hide_forecast.set_pressed_no_signal(bool(sss.get("hide_forecast")))

	var ach := get_node_or_null("/root/AchievementService")
	if ach != null and ach.has_signal("achievement_unlocked"):
		ach.connect("achievement_unlocked", func(_id: String) -> void: refresh_ui())

	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", func(_l: String) -> void: refresh_ui())

	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", refresh_ui)

	set_sss_view_mode(MODE_LIST)
	refresh_ui()


func _build_standard_difficulty_view() -> void:
	_standard_view_root = Control.new()
	_standard_view_root.name = "StandardDifficultyView"
	_standard_view_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_standard_view_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content_root.add_child(_standard_view_root)

	# Upper Half: Selected Difficulty Editorial Dossier (0.00..0.47)
	var summary_card := PanelContainer.new()
	summary_card.name = "DifficultySummaryCard"
	summary_card.anchor_left = 0.0
	summary_card.anchor_right = 1.0
	summary_card.anchor_top = 0.0
	summary_card.anchor_bottom = 0.47
	summary_card.offset_left = 0.0
	summary_card.offset_right = 0.0
	summary_card.offset_top = 0.0
	summary_card.offset_bottom = 0.0
	_standard_view_root.add_child(summary_card)

	var sum_vbox := VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 8)
	sum_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_card.add_child(sum_vbox)

	_diff_header_label = Label.new()
	_diff_header_label.theme_type_variation = &"MutedLabel"
	_diff_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_vbox.add_child(_diff_header_label)

	_diff_name_label = Label.new()
	_diff_name_label.theme_type_variation = &"HeaderLabel"
	_diff_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum_vbox.add_child(_diff_name_label)

	sum_vbox.add_child(HSeparator.new())

	var desc_scroll := ScrollContainer.new()
	desc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sum_vbox.add_child(desc_scroll)

	_diff_desc_rtl = RichTextLabel.new()
	_diff_desc_rtl.bbcode_enabled = true
	_diff_desc_rtl.fit_content = true
	_diff_desc_rtl.scroll_active = false
	_diff_desc_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(_diff_desc_rtl)

	_ucn_lock_hint_label = Label.new()
	_ucn_lock_hint_label.theme_type_variation = &"MutedLabel"
	_ucn_lock_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ucn_lock_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_vbox.add_child(_ucn_lock_hint_label)

	# Lower Half: Thumb-Zone Controls (0.50..1.00, all buttons >= 48px)
	var lower_controls := VBoxContainer.new()
	lower_controls.name = "DifficultyLowerControls"
	lower_controls.anchor_left = 0.0
	lower_controls.anchor_right = 1.0
	lower_controls.anchor_top = 0.50
	lower_controls.anchor_bottom = 1.0
	lower_controls.offset_left = 0.0
	lower_controls.offset_right = 0.0
	lower_controls.offset_top = 0.0
	lower_controls.offset_bottom = 0.0
	lower_controls.alignment = BoxContainer.ALIGNMENT_END
	lower_controls.add_theme_constant_override("separation", 8)
	_standard_view_root.add_child(lower_controls)

	var diff_grid := GridContainer.new()
	diff_grid.columns = 2
	diff_grid.add_theme_constant_override("h_separation", 8)
	diff_grid.add_theme_constant_override("v_separation", 8)
	diff_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_controls.add_child(diff_grid)

	for d_id in STANDARD_DIFFICULTIES:
		var btn := Button.new()
		btn.name = "BtnDiff_" + d_id
		btn.custom_minimum_size = Vector2(0.0, 48.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		var captured_id := d_id
		btn.pressed.connect(func() -> void:
			_play_click()
			select_difficulty(captured_id)
		)
		diff_grid.add_child(btn)
		diff_buttons[d_id] = btn

	btn_diff_ucn = Button.new()
	btn_diff_ucn.name = "BtnDiff_ucn"
	btn_diff_ucn.custom_minimum_size = Vector2(0.0, 48.0)
	btn_diff_ucn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_diff_ucn.clip_text = true
	btn_diff_ucn.pressed.connect(func() -> void:
		_play_click()
		open_sss_board(false)
	)
	lower_controls.add_child(btn_diff_ucn)
	diff_buttons["ucn"] = btn_diff_ucn

	chk_standard_forecast = CheckBox.new()
	chk_standard_forecast.name = "ChkStandardForecast"
	chk_standard_forecast.custom_minimum_size = Vector2(0.0, 48.0)
	chk_standard_forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk_standard_forecast.clip_text = true
	chk_standard_forecast.toggled.connect(func(on: bool) -> void: set_standard_forecast_enabled(on))
	lower_controls.add_child(chk_standard_forecast)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_controls.add_child(bottom_row)

	btn_back_to_title = Button.new()
	btn_back_to_title.name = "BtnBackToTitle"
	btn_back_to_title.custom_minimum_size = Vector2(0.0, 48.0)
	btn_back_to_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back_to_title.pressed.connect(navigate_back_to_title)
	bottom_row.add_child(btn_back_to_title)

	btn_briefing = Button.new()
	btn_briefing.name = "BtnSituationBriefing"
	btn_briefing.custom_minimum_size = Vector2(0.0, 48.0)
	btn_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_briefing.clip_text = true
	btn_briefing.pressed.connect(open_situation_briefing_sheet)
	bottom_row.add_child(btn_briefing)

	btn_start_campaign = Button.new()
	btn_start_campaign.name = "BtnStartCampaign"
	btn_start_campaign.custom_minimum_size = Vector2(0.0, 48.0)
	btn_start_campaign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_start_campaign.theme_type_variation = &"AccentButton"
	btn_start_campaign.pressed.connect(start_selected_campaign)
	bottom_row.add_child(btn_start_campaign)


func _build_sss_board_view() -> void:
	_sss_view_root = VBoxContainer.new()
	_sss_view_root.name = "SSSBoardView"
	_sss_view_root.visible = false
	_sss_view_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sss_view_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sss_view_root.add_theme_constant_override("separation", 8)
	shell.content_root.add_child(_sss_view_root)

	# Compact SSS Header + Max Banner
	var header_card := PanelContainer.new()
	header_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sss_view_root.add_child(header_card)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	header_card.add_child(hv)

	_sss_title_label = Label.new()
	_sss_title_label.theme_type_variation = &"HeaderLabel"
	_sss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_sss_title_label)

	_sss_banner_label = Label.new()
	_sss_banner_label.theme_type_variation = &"MutedLabel"
	_sss_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sss_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_sss_banner_label)

	# Mode A (Default): 4-Track Vertical Mobile List (Daftar 4 Jalur)
	_track_list_scroll = ScrollContainer.new()
	_track_list_scroll.name = "TrackListScroll"
	_track_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sss_view_root.add_child(_track_list_scroll)

	var tracks_vbox := VBoxContainer.new()
	tracks_vbox.add_theme_constant_override("separation", 10)
	tracks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_list_scroll.add_child(tracks_vbox)

	_populate_four_track_cards(tracks_vbox)

	# Mode B: 2D Pannable Node Map (Peta Node 2D)
	_graph_panel_wrap = VBoxContainer.new()
	_graph_panel_wrap.name = "GraphPanelWrap"
	_graph_panel_wrap.visible = false
	_graph_panel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_panel_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_panel_wrap.add_theme_constant_override("separation", 6)
	_sss_view_root.add_child(_graph_panel_wrap)

	sss_graph_canvas = SSSGraphCanvas.new()
	sss_graph_canvas.visible = false
	sss_graph_canvas.card_rank_requested.connect(func(cid: String, rk: int) -> void:
		_play_click()
		set_sss_card_rank(cid, rk)
	)
	_graph_panel_wrap.add_child(sss_graph_canvas)

	var graph_tools_row := HBoxContainer.new()
	graph_tools_row.add_theme_constant_override("separation", 8)
	_graph_panel_wrap.add_child(graph_tools_row)

	btn_sss_zoom = Button.new()
	btn_sss_zoom.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_zoom.pressed.connect(func() -> void:
		_graph_zoom_active = not _graph_zoom_active
		sss_graph_canvas.set_overview_zoom(_graph_zoom_active)
		refresh_ui()
	)
	graph_tools_row.add_child(btn_sss_zoom)

	btn_sss_reset_view = Button.new()
	btn_sss_reset_view.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_reset_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_reset_view.pressed.connect(func() -> void:
		_graph_zoom_active = false
		sss_graph_canvas.reset_view()
		refresh_ui()
	)
	graph_tools_row.add_child(btn_sss_reset_view)

	# Bottom Ergonomic Thumb-Zone Dock for SSS Board (all >= 48px)
	var bottom_dock := VBoxContainer.new()
	bottom_dock.name = "SSSBottomThumbDock"
	bottom_dock.add_theme_constant_override("separation", 6)
	bottom_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sss_view_root.add_child(bottom_dock)

	# Mode Switcher + Presets Sheet Button
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	bottom_dock.add_child(mode_row)

	btn_sss_mode_list = Button.new()
	btn_sss_mode_list.name = "BtnSSSModeList"
	btn_sss_mode_list.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_mode_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_mode_list.clip_text = true
	btn_sss_mode_list.pressed.connect(func() -> void:
		_play_click()
		set_sss_view_mode(MODE_LIST)
	)
	mode_row.add_child(btn_sss_mode_list)

	btn_sss_mode_graph = Button.new()
	btn_sss_mode_graph.name = "BtnSSSModeGraph"
	btn_sss_mode_graph.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_mode_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_mode_graph.clip_text = true
	btn_sss_mode_graph.pressed.connect(func() -> void:
		_play_click()
		set_sss_view_mode(MODE_GRAPH)
	)
	mode_row.add_child(btn_sss_mode_graph)

	btn_sss_presets = Button.new()
	btn_sss_presets.name = "BtnSSSPresets"
	btn_sss_presets.custom_minimum_size = Vector2(88.0, 48.0)
	btn_sss_presets.pressed.connect(open_sss_presets_sheet)
	mode_row.add_child(btn_sss_presets)

	# Fixed Hide Forecast Checkbox (wired directly to SSSController + SaveAndSettingsService)
	chk_sss_hide_forecast = CheckBox.new()
	chk_sss_hide_forecast.name = "ChkSSSHideForecast"
	chk_sss_hide_forecast.custom_minimum_size = Vector2(0.0, 48.0)
	chk_sss_hide_forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk_sss_hide_forecast.button_pressed = true
	chk_sss_hide_forecast.clip_text = true
	chk_sss_hide_forecast.toggled.connect(func(on: bool) -> void: set_sss_hide_forecast(on))
	bottom_dock.add_child(chk_sss_hide_forecast)

	var sss_footer := HBoxContainer.new()
	sss_footer.add_theme_constant_override("separation", 8)
	bottom_dock.add_child(sss_footer)

	btn_sss_close = Button.new()
	btn_sss_close.name = "BtnSSSConfirmClose"
	btn_sss_close.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_close.clip_text = true
	btn_sss_close.pressed.connect(close_sss_board)
	sss_footer.add_child(btn_sss_close)

	btn_sss_launch = Button.new()
	btn_sss_launch.name = "BtnSSSLaunch"
	btn_sss_launch.custom_minimum_size = Vector2(0.0, 48.0)
	btn_sss_launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sss_launch.theme_type_variation = &"AccentButton"
	btn_sss_launch.pressed.connect(launch_sss_campaign)
	sss_footer.add_child(btn_sss_launch)


func _populate_four_track_cards(tracks_vbox: VBoxContainer) -> void:
	_track_headers.clear()
	_track_card_items.clear()

	var cdb := _get_autoload("ContentDB")
	if cdb == null or not ("catalog" in cdb) or cdb.get("catalog") == null:
		return
	var catalog: GameCatalogData = cdb.get("catalog") as GameCatalogData

	for track_row in range(4):
		var track_hdr := Label.new()
		track_hdr.theme_type_variation = &"HeaderLabel"
		track_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tracks_vbox.add_child(track_hdr)
		_track_headers.append(track_hdr)

		var row_cards: Array[SSSCardData] = []
		for card in catalog.sss_cards:
			if card.row == track_row:
				row_cards.append(card)
		row_cards.sort_custom(func(a: SSSCardData, b: SSSCardData) -> bool: return a.col < b.col)

		for card in row_cards:
			var item_panel := PanelContainer.new()
			item_panel.name = "TrackCard_" + card.id
			item_panel.theme_type_variation = &"SurfaceAltCard"
			item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tracks_vbox.add_child(item_panel)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 6)
			item_panel.add_child(cv)

			var top_row := HBoxContainer.new()
			top_row.add_theme_constant_override("separation", 8)
			cv.add_child(top_row)

			var name_lbl := Label.new()
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			top_row.add_child(name_lbl)

			var badge_lbl := Label.new()
			badge_lbl.theme_type_variation = &"MutedLabel"
			top_row.add_child(badge_lbl)

			var desc_lbl := Label.new()
			desc_lbl.theme_type_variation = &"MutedLabel"
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(desc_lbl)

			var effect_rtl := RichTextLabel.new()
			effect_rtl.bbcode_enabled = true
			effect_rtl.fit_content = true
			effect_rtl.scroll_active = false
			effect_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cv.add_child(effect_rtl)

			var prereq_lbl := Label.new()
			prereq_lbl.theme_type_variation = &"MutedLabel"
			prereq_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(prereq_lbl)

			var rank_row := HBoxContainer.new()
			rank_row.add_theme_constant_override("separation", 6)
			cv.add_child(rank_row)

			var rank_btns: Array[Button] = []
			var r_labels := ["OFF", "I", "II", "III"]
			for idx in range(RANK_VALUES.size()):
				var rk_val: int = RANK_VALUES[idx]
				var rb := Button.new()
				rb.custom_minimum_size = Vector2(0.0, 48.0)
				rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rb.text = r_labels[idx]
				var cid := card.id
				rb.pressed.connect(func() -> void:
					_play_click()
					set_sss_card_rank(cid, rk_val)
				)
				rank_row.add_child(rb)
				rank_btns.append(rb)

			_track_card_items[card.id] = {
				"card": card,
				"panel": item_panel,
				"name": name_lbl,
				"badge": badge_lbl,
				"desc": desc_lbl,
				"effect": effect_rtl,
				"prereq": prereq_lbl,
				"rank_btns": rank_btns,
			}


func get_standard_difficulty_ids() -> Array[String]:
	return STANDARD_DIFFICULTIES.duplicate()


func get_track_list_card_count() -> int:
	return _track_card_items.size()


func select_difficulty(diff_id: String) -> void:
	if STANDARD_DIFFICULTIES.has(diff_id):
		selected_difficulty = diff_id
	elif diff_id == "ucn" and _is_sss_unlocked():
		selected_difficulty = "ucn"
	refresh_ui()


func set_standard_forecast_enabled(enabled: bool) -> void:
	standard_forecast_enabled = enabled
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc != null:
		if "settings" in save_svc and save_svc.get("settings") != null:
			(save_svc.get("settings") as UserSettingsData).show_option_effects_override = enabled
		if save_svc.has_method("save_settings"):
			save_svc.call("save_settings")
	refresh_ui()


func open_sss_board(force: bool = false) -> void:
	if not force and not _is_sss_unlocked():
		var audio := get_node_or_null("/root/AudioController")
		if audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", "blocked")
		return
	selected_difficulty = "ucn"
	sss_board_open = true
	_standard_view_root.visible = false
	_sss_view_root.visible = true
	refresh_ui()


func close_sss_board() -> void:
	sss_board_open = false
	_sss_view_root.visible = false
	_standard_view_root.visible = true
	refresh_ui()


func set_sss_view_mode(mode_id: String) -> void:
	sss_view_mode = MODE_GRAPH if mode_id == MODE_GRAPH else MODE_LIST
	var is_graph := (sss_view_mode == MODE_GRAPH)
	if _track_list_scroll != null:
		_track_list_scroll.visible = not is_graph
	if _graph_panel_wrap != null:
		_graph_panel_wrap.visible = is_graph
	if sss_graph_canvas != null:
		sss_graph_canvas.visible = is_graph
		if is_graph:
			sss_graph_canvas.refresh_from_controller()
	refresh_ui()
	sss_mode_changed.emit(sss_view_mode)


func set_sss_card_rank(card_id: String, rank_val: int) -> void:
	var sss := get_node_or_null("/root/SSSController")
	if sss == null or not sss.has_method("set_card_rank"):
		return
	sss.call("set_card_rank", card_id, rank_val)
	_persist_sss_settings()
	_refresh_sss_board_contents()


func apply_sss_preset(preset_rank: int) -> void:
	var sss := get_node_or_null("/root/SSSController")
	if sss == null or not sss.has_method("apply_preset"):
		return
	sss.call("apply_preset", preset_rank)
	_persist_sss_settings()
	_refresh_sss_board_contents()


func set_sss_hide_forecast(hide: bool) -> void:
	var sss := get_node_or_null("/root/SSSController")
	if sss != null and sss.has_method("set_hide_forecast"):
		sss.call("set_hide_forecast", hide)
	if chk_sss_hide_forecast != null:
		chk_sss_hide_forecast.set_pressed_no_signal(hide)
	_persist_sss_settings()


func _persist_sss_settings() -> void:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	var sss := get_node_or_null("/root/SSSController")
	if save_svc == null:
		return
	if "settings" in save_svc and save_svc.get("settings") != null and sss != null:
		var s := save_svc.get("settings") as UserSettingsData
		if "levels" in sss and sss.get("levels") is Dictionary:
			s.sss_levels = (sss.get("levels") as Dictionary).duplicate(true)
		if "hide_forecast" in sss:
			s.sss_hide_forecast = bool(sss.get("hide_forecast"))
	if save_svc.has_method("save_settings"):
		save_svc.call("save_settings")


func open_sss_presets_sheet() -> void:
	_play_click()
	var is_id := _is_indonesian()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var presets := [
		{"rank": 0, "label": _tr("ucn.preset.zero")},
		{"rank": 10, "label": _tr("ucn.preset.historical")},
		{"rank": 20, "label": _tr("ucn.preset.max")},
		{"rank": -1, "label": _tr("ucn.preset.random")},
	]
	for p in presets:
		var p_btn := Button.new()
		p_btn.custom_minimum_size = Vector2(0.0, 48.0)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.text = String(p["label"])
		if int(p["rank"]) == 20:
			p_btn.theme_type_variation = &"AccentButton"
		var rk := int(p["rank"])
		p_btn.pressed.connect(func() -> void:
			_play_click()
			apply_sss_preset(rk)
			shell.bottom_sheet_host.pop_top_sheet()
		)
		box.add_child(p_btn)

	shell.bottom_sheet_host.push_sheet(box, "Preset SSS" if is_id else "SSS Presets")


func open_situation_briefing_sheet() -> void:
	_play_click()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var prompt_lbl := Label.new()
	prompt_lbl.text = _tr("situation.choice_prompt")
	prompt_lbl.theme_type_variation = &"MutedLabel"
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt_lbl)

	var paragraphs: Array[String] = ["[b]%s[/b]" % _tr("situation.salutation")]
	for i in range(1, 8):
		paragraphs.append(_tr("situation.p%d" % i))

	var lore_rtl := RichTextLabel.new()
	lore_rtl.bbcode_enabled = true
	lore_rtl.fit_content = true
	lore_rtl.scroll_active = false
	lore_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_rtl.text = "\n\n".join(paragraphs)
	box.add_child(lore_rtl)

	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(0.0, 48.0)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.theme_type_variation = &"AccentButton"
	start_btn.text = _tr("situation.start")
	start_btn.pressed.connect(func() -> void:
		shell.bottom_sheet_host.clear_all_sheets()
		start_selected_campaign()
	)
	box.add_child(start_btn)

	shell.bottom_sheet_host.push_sheet(box, _tr("situation.title"))


func start_selected_campaign() -> void:
	_play_click()
	_launch_campaign_internal(selected_difficulty)


func launch_sss_campaign() -> void:
	_play_click()
	selected_difficulty = "ucn"
	_launch_campaign_internal("ucn")


func _launch_campaign_internal(diff_id: String) -> void:
	var cm := get_node_or_null("/root/CampaignManager")
	var fc := false if diff_id == "historical" else standard_forecast_enabled
	if cm != null and cm.has_method("start_new_campaign"):
		cm.call("start_new_campaign", diff_id, fc)
	if shell != null and shell.bottom_sheet_host != null:
		shell.bottom_sheet_host.clear_all_sheets()
	campaign_launched.emit(diff_id)
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(CAMPAIGN_SCENE_PATH):
		get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)


func navigate_back_to_title() -> void:
	_play_click()
	navigated_back.emit(TITLE_SCENE_PATH)
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(TITLE_SCENE_PATH):
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _on_custom_back() -> bool:
	if sss_board_open:
		close_sss_board()
		return true
	navigate_back_to_title()
	return true


func refresh_ui() -> void:
	var is_id := _is_indonesian()
	var cdb := get_node_or_null("/root/ContentDB")

	_diff_header_label.text = _tr("difficulty.title")

	for d_id in STANDARD_DIFFICULTIES:
		var btn: Button = diff_buttons.get(d_id, null) as Button
		if btn == null:
			continue
		var d_res: DifficultyData = cdb.call("get_difficulty", d_id) as DifficultyData if cdb != null else null
		btn.text = _tr(d_res.name_key) if d_res != null else _tr("difficulty.%s.name" % d_id)
		btn.theme_type_variation = &"AccentButton" if (selected_difficulty == d_id and not sss_board_open) else &""

	var ucn_open := _is_sss_unlocked()
	if btn_diff_ucn != null:
		btn_diff_ucn.disabled = not ucn_open
		var sss_name := _tr("difficulty.ucn.name")
		if ucn_open:
			btn_diff_ucn.text = "★ " + sss_name
		else:
			btn_diff_ucn.text = "🔒 %s (%s)" % [sss_name, _tr("ucn.locked.label")]
		btn_diff_ucn.theme_type_variation = &"AccentButton" if selected_difficulty == "ucn" else &""

	_ucn_lock_hint_label.visible = not ucn_open
	_ucn_lock_hint_label.text = _tr("ucn.locked.hint")

	var active_diff: DifficultyData = cdb.call("get_difficulty", selected_difficulty) as DifficultyData if cdb != null else null
	if active_diff != null:
		_diff_name_label.text = _tr(active_diff.name_key)
		_diff_desc_rtl.text = _tr(active_diff.desc_key)
	else:
		_diff_name_label.text = _tr("difficulty.historical.name")
		_diff_desc_rtl.text = _tr("difficulty.historical.desc")

	if chk_standard_forecast != null:
		var is_hist := (selected_difficulty == "historical")
		chk_standard_forecast.disabled = is_hist
		chk_standard_forecast.set_pressed_no_signal(false if is_hist else standard_forecast_enabled)
		chk_standard_forecast.text = _tr("difficulty.forecast_toggle")

	if btn_back_to_title != null:
		btn_back_to_title.text = _tr("common.back")
	if btn_briefing != null:
		btn_briefing.text = "Situasi" if is_id else "Briefing"
	if btn_start_campaign != null:
		btn_start_campaign.text = _tr("title.play")

	_refresh_sss_board_contents()


func _refresh_sss_board_contents() -> void:
	var is_id := _is_indonesian()
	var sss := get_node_or_null("/root/SSSController")

	if _sss_title_label != null:
		_sss_title_label.text = _tr("ucn.panel.title")

	var all_max := false
	if sss != null and sss.has_method("are_levels_at_least"):
		all_max = bool(sss.call("are_levels_at_least", 20))
	if _sss_banner_label != null:
		_sss_banner_label.text = _tr("ucn.banner.maxed" if all_max else "ucn.banner.hint")

	var track_names_id := [
		"Jalur I — Kelumpuhan Eksekutif & Istana",
		"Jalur II — Warisan Mei 1998",
		"Jalur III — Patronase Cendana & Senayan",
		"Jalur IV — Jalanan & Barak",
	]
	var track_names_en := [
		"Track I — Executive & Palace Paralysis",
		"Track II — The May 1998 Inheritance",
		"Track III — Cendana & Senayan Patronage",
		"Track IV — Streets & Barracks",
	]
	for idx in range(_track_headers.size()):
		_track_headers[idx].text = track_names_id[idx] if is_id else track_names_en[idx]

	var off_txt := _tr("ucn.cc.btn_off")
	var lv_map: Dictionary = sss.get("levels") if (sss != null and "levels" in sss) else {}

	for cid in _track_card_items.keys():
		var item: Dictionary = _track_card_items[cid]
		var card: SSSCardData = item["card"]
		var lv := int(lv_map.get(card.id, 10))
		var unlocked := bool(sss.call("is_card_unlocked", card.id)) if (sss != null and sss.has_method("is_card_unlocked")) else true

		(item["name"] as Label).text = "%s · %s" % [_tr("ucn.cc.col.%d" % card.col), _tr(card.name_key)]
		(item["badge"] as Label).text = SSSGraphCanvas._format_rank_badge(lv, unlocked, get_node_or_null("/root/LocaleService"))
		(item["desc"] as Label).text = _tr(card.desc_key)
		if sss != null and sss.has_method("format_card_effect"):
			(item["effect"] as RichTextLabel).text = String(sss.call("format_card_effect", card.id, lv))

		var prereq_lbl := item["prereq"] as Label
		if card.prereqs.is_empty():
			prereq_lbl.text = "◆ " + _tr("ucn.cc.root_node")
		else:
			var p_names: Array[String] = []
			for pid in card.prereqs:
				p_names.append(_tr("ucn.slider.%s.name" % pid))
			var prefix := _tr("ucn.cc.linked_from") if unlocked else ("🔒 " + _tr("ucn.cc.requires"))
			prereq_lbl.text = "%s %s" % [prefix, " / ".join(p_names)]

		var r_btns: Array = item["rank_btns"]
		for idx in range(r_btns.size()):
			var rb := r_btns[idx] as Button
			if idx == 0:
				rb.text = off_txt
			rb.disabled = not unlocked
			rb.theme_type_variation = &"AccentButton" if (unlocked and lv == RANK_VALUES[idx]) else &""

	if sss_graph_canvas != null and sss_view_mode == MODE_GRAPH:
		sss_graph_canvas.refresh_from_controller()

	if btn_sss_mode_list != null:
		btn_sss_mode_list.text = "Daftar 4 Jalur" if is_id else "4-Track List"
		btn_sss_mode_list.theme_type_variation = &"AccentButton" if sss_view_mode == MODE_LIST else &""
	if btn_sss_mode_graph != null:
		btn_sss_mode_graph.text = "Peta Node 2D" if is_id else "2D Node Map"
		btn_sss_mode_graph.theme_type_variation = &"AccentButton" if sss_view_mode == MODE_GRAPH else &""
	if btn_sss_presets != null:
		btn_sss_presets.text = "Preset"
	if btn_sss_zoom != null:
		btn_sss_zoom.text = _tr("ucn.cc.zoom_btn")
		btn_sss_zoom.theme_type_variation = &"AccentButton" if _graph_zoom_active else &""
	if btn_sss_reset_view != null:
		btn_sss_reset_view.text = _tr("ucn.cc.reset_view")
	if chk_sss_hide_forecast != null:
		chk_sss_hide_forecast.text = _tr("ucn.hide_forecast")
		if sss != null and "hide_forecast" in sss:
			chk_sss_hide_forecast.set_pressed_no_signal(bool(sss.get("hide_forecast")))
	if btn_sss_close != null:
		btn_sss_close.text = _tr("ucn.cc.confirm_close")
	if btn_sss_launch != null:
		btn_sss_launch.text = _tr("common.continue")


func _is_sss_unlocked() -> bool:
	var sss := get_node_or_null("/root/SSSController")
	if sss != null and sss.has_method("is_unlocked"):
		return bool(sss.call("is_unlocked"))
	return false


func _is_indonesian() -> bool:
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and "current_locale" in loc:
		return String(loc.get("current_locale")) == "id"
	return true


func _tr(key: String, vars: Dictionary = {}) -> String:
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_method("tr_fmt"):
		return String(loc.call("tr_fmt", key, vars))
	return key


func _play_click() -> void:
	var audio := get_node_or_null("/root/AudioController")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", "click")


func _get_autoload(auto_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + auto_name)
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.root != null:
		return ml.root.get_node_or_null(auto_name)
	return null
