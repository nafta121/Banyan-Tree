class_name CampaignShellScreen
extends Control

const PRESS_SHEET_SCENE_PATH := "res://godot/scenes/editorial_press_sheet.tscn"

var shell: SafeAreaShell = null
var allow_scene_change: bool = true

var _header_panel: PanelContainer = null
var _header_summary_label: Label = null
var _header_opp_label: Label = null

var _toast_panel: PanelContainer = null
var _toast_label: Label = null

var _tabs_host: Control = null
var _tab_views: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _bottom_tab_bar: HBoxContainer = null

var agenda_tab: AgendaTabView = null
var stat_tab: StatDashboardTabView = null
var mpr_tab: MPRParliamentTabView = null
var library_tab: LibraryTabView = null
var more_tab: MoreDrawerTabView = null

var active_tab_index: int = 0
var last_press_sheet: EditorialPressSheet = null
var active_election_screen: Control = null


func _init() -> void:
	name = "CampaignShellScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	shell = SafeAreaShell.new()
	add_child(shell)

	# 1. Top Compact Status Header
	_header_panel = PanelContainer.new()
	_header_panel.name = "TopStatusHeader"
	_header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.content_root.add_child(_header_panel)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.add_theme_constant_override("separation", 3)
	_header_panel.add_child(hdr_vb)

	_header_summary_label = Label.new()
	_header_summary_label.name = "HeaderSummaryLabel"
	_header_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdr_vb.add_child(_header_summary_label)

	_header_opp_label = Label.new()
	_header_opp_label.name = "HeaderOppositionLabel"
	_header_opp_label.theme_type_variation = &"MutedLabel"
	_header_opp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdr_vb.add_child(_header_opp_label)

	# Optional non-blocking Achievement Unlock Toast Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "AchievementToastPanel"
	_toast_panel.theme_type_variation = &"SurfaceAltCard"
	_toast_panel.visible = false
	shell.content_root.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(_toast_label)

	# 2. Middle Expandable Active Tab Host
	_tabs_host = VBoxContainer.new()
	_tabs_host.name = "TabViewsHost"
	_tabs_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content_root.add_child(_tabs_host)

	agenda_tab = AgendaTabView.new()
	agenda_tab.bind_sheet_host(shell.bottom_sheet_host)
	agenda_tab.election_screen_requested.connect(open_election_screen)
	_tabs_host.add_child(agenda_tab)

	stat_tab = StatDashboardTabView.new()
	_tabs_host.add_child(stat_tab)

	mpr_tab = MPRParliamentTabView.new()
	mpr_tab.negotiate_faction_requested.connect(_on_negotiate_faction_from_mpr)
	_tabs_host.add_child(mpr_tab)

	library_tab = LibraryTabView.new()
	_tabs_host.add_child(library_tab)

	more_tab = MoreDrawerTabView.new()
	more_tab.bind_sheet_host(shell.bottom_sheet_host)
	_tabs_host.add_child(more_tab)

	_tab_views = [agenda_tab, stat_tab, mpr_tab, library_tab, more_tab]

	# 3. Bottom 5-Tab Navigation Bar (56px height each, bottom thumb zone)
	_bottom_tab_bar = HBoxContainer.new()
	_bottom_tab_bar.name = "BottomFiveTabBar"
	_bottom_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_tab_bar.add_theme_constant_override("separation", 6)
	shell.content_root.add_child(_bottom_tab_bar)

	for i in range(5):
		var tb := Button.new()
		tb.name = "BottomTabBtn_%d" % i
		tb.custom_minimum_size = Vector2(0.0, 56.0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.clip_text = true
		var idx := i
		tb.pressed.connect(func() -> void: switch_tab(idx))
		_bottom_tab_bar.add_child(tb)
		_tab_buttons.append(tb)


func _ready() -> void:
	if more_tab != null:
		more_tab.allow_scene_change = allow_scene_change
	if shell != null:
		shell.allow_quit_execution = allow_scene_change
		shell.returned_to_main_tab.connect(func(main_idx: int) -> void: switch_tab(main_idx))
		if shell.bottom_sheet_host != null:
			shell.bottom_sheet_host.stack_emptied.connect(_on_bottom_sheets_emptied)

	if CampaignManager != null:
		if not CampaignManager.game_started:
			CampaignManager.start_new_campaign("historical", false)
		CampaignManager.state_changed.connect(refresh_all)
		CampaignManager.press_alert_queued.connect(_on_press_alert_queued)

	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings_changed.connect(refresh_all)
	if LocaleService != null:
		LocaleService.locale_changed.connect(func(_l: String) -> void: refresh_all())
	if ThemeManager != null:
		ThemeManager.theme_updated.connect(refresh_all)
	if AchievementService != null:
		AchievementService.achievement_unlocked.connect(_on_achievement_unlocked)
	if AudioController != null:
		AudioController.ensure_music_started()

	switch_tab(0)
	refresh_all()


func set_allow_scene_change(v: bool) -> void:
	allow_scene_change = v
	if more_tab != null:
		more_tab.allow_scene_change = v
	if shell != null:
		shell.allow_quit_execution = v


func switch_tab(index: int) -> void:
	active_tab_index = clampi(index, 0, _tab_views.size() - 1)
	if shell != null:
		shell.set_active_tab(active_tab_index)
	if more_tab != null:
		more_tab.allow_scene_change = allow_scene_change
	for i in range(_tab_views.size()):
		_tab_views[i].visible = (i == active_tab_index)
	_refresh_tab_button_styles()


func get_active_tab_index() -> int:
	return active_tab_index


func get_tab_buttons() -> Array[Button]:
	return _tab_buttons


func get_tab_view(index: int) -> Control:
	if index >= 0 and index < _tab_views.size():
		return _tab_views[index]
	return null


func get_header_summary_text() -> String:
	return _header_summary_label.text if _header_summary_label != null else ""


func _on_negotiate_faction_from_mpr(faction_id: String) -> void:
	switch_tab(0)
	if agenda_tab != null:
		agenda_tab.set_action_submode("factions")
		agenda_tab.select_faction(faction_id)


func open_election_screen(scene_path: String = "res://godot/scenes/election_and_epilogue_screen.tscn") -> void:
	if shell != null and shell.bottom_sheet_host != null:
		shell.bottom_sheet_host.clear_all_sheets()
	if allow_scene_change and is_inside_tree() and get_tree() != null and get_tree().current_scene != null and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		return
	if active_election_screen != null and is_instance_valid(active_election_screen):
		return
	if ResourceLoader.exists(scene_path):
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate() as Control
			if inst != null:
				inst.set("allow_scene_change", allow_scene_change)
				active_election_screen = inst
				add_child(inst)


func _on_press_alert_queued(payload: Dictionary) -> void:
	# Turn 23 (ev_timtim_merdeka) transitions straight into ElectionAndEpilogueScreen
	if CampaignManager != null and CampaignManager.is_election_ready():
		return
	if shell == null or shell.bottom_sheet_host == null:
		return
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers
	var sheet: EditorialPressSheet = null
	if ResourceLoader.exists(PRESS_SHEET_SCENE_PATH):
		var packed := ResourceLoader.load(PRESS_SHEET_SCENE_PATH) as PackedScene
		if packed != null:
			sheet = packed.instantiate() as EditorialPressSheet
	if sheet == null:
		sheet = EditorialPressSheet.new()
	sheet.populate_alert(payload, exact)
	last_press_sheet = sheet

	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var kind := String(payload.get("kind", "press"))
	if AudioController != null:
		AudioController.play_sfx("notification" if kind == "telex" else "news")
	var modal_title := ("Kawat Istana" if is_id else "Palace Telex") if kind == "telex" else ("Reaksi Pers" if is_id else "Press Reaction")
	shell.bottom_sheet_host.push_sheet(sheet, modal_title)


func _on_bottom_sheets_emptied() -> void:
	# Mirror upstream checkAutoAdvanceTurn() when closing telex after exhausting both action allowances
	if CampaignManager == null or not CampaignManager.is_action_phase:
		return
	if CampaignManager.is_night_of_long_knives_turn() and CampaignManager.pc > 0:
		return
	var auto_adv := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.auto_advance_turn
	if auto_adv and CampaignManager.turn_executive_used and CampaignManager.is_faction_limit_reached():
		CampaignManager.finish_action_phase()


func _on_achievement_unlocked(ach_id: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	var ach := ContentDB.get_achievement(ach_id) if ContentDB != null else null
	var title_txt := (LocaleService.tr_fmt(ach.title_key) if (ach != null and LocaleService != null) else ach_id)
	_toast_label.text = "🏆 " + title_txt
	_toast_panel.visible = true


func _refresh_tab_button_styles() -> void:
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var labels_id := ["Agenda", "Stat", "MPR", "Buku", "≡"]
	var labels_en := ["Agenda", "Stats", "MPR", "Library", "≡"]
	for i in range(_tab_buttons.size()):
		var tb := _tab_buttons[i]
		tb.text = labels_id[i] if is_id else labels_en[i]
		tb.theme_type_variation = &"AccentButton" if i == active_tab_index else &""


func refresh_all() -> void:
	_refresh_tab_button_styles()
	if CampaignManager == null:
		return

	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers

	var date_txt := CampaignManager.get_current_date_str()
	var disp_turn := mini(23, CampaignManager.current_turn)
	var gov_val := CampaignManager.get_gov_stability()
	var gov_tier := LocaleService.tr_fmt("gov." + CampaignManager.get_gov_stability_tier_id()) if LocaleService != null else CampaignManager.get_gov_stability_tier_id()
	var gov_str := ("%s (%d)" % [gov_tier, gov_val]) if exact else gov_tier

	_header_summary_label.text = "%s • %s %d/23 • PC %d • %s" % [
		date_txt,
		("Giliran" if is_id else "Turn"),
		disp_turn,
		CampaignManager.pc,
		gov_str,
	]

	var mil_m := OppositionManager.get_military_meter() if OppositionManager != null else {}
	var pdip_m := OppositionManager.get_pdip_meter() if OppositionManager != null else {}
	var mil_phase := String(mil_m.get("phase", "patience"))
	var mil_lbl := ("Amarah" if is_id else "Anger") if mil_phase == "anger" else ("Sabar" if is_id else "Patience")
	var pdip_tier := int(pdip_m.get("tier", 0))
	var pdip_lbl := LocaleService.tr_fmt("pdip.tier.%d.label" % clampi(pdip_tier, 0, 4)) if LocaleService != null else ("T%d" % pdip_tier)

	if exact:
		_header_opp_label.text = "TNI: %s (%d) • PDI-P: %s (%d)" % [
			mil_lbl,
			int(mil_m.get("value", 50)),
			pdip_lbl,
			int(pdip_m.get("value", 0)),
		]
	else:
		_header_opp_label.text = "TNI: %s • PDI-P: %s" % [mil_lbl, pdip_lbl]
