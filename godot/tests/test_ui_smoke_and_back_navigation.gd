extends TestBase

const SETTINGS_PATH := "user://settings.tres"
const SAVES_DIR := "user://saves"


func run() -> int:
	_clean_user_artifacts()
	LocaleService.set_locale("id")
	AchievementService.restore_state({})
	SSSController._init_default_levels()
	SSSController.set_hide_forecast(true)
	ThemeManager.apply_theme("midnight_slate", 1.0)

	_test_theme_manager_palettes_and_scaling()
	_test_bottom_sheet_host_and_stat_card_unit_contracts()
	await _test_safe_area_shell_back_gesture_ui_cancel_and_pause()
	await _test_boot_loader_screen_random_messages_and_transition()
	await _test_title_screen_thumb_zone_sheets_changelog_and_toggles()
	await _test_difficulty_screen_and_dual_mode_sss_board()

	await tree.process_frame
	await tree.process_frame
	_clean_user_artifacts()
	LocaleService.set_locale("id")
	ThemeManager.apply_theme("midnight_slate", 1.0)
	return assertions_failed


func _clean_user_artifacts() -> void:
	var abs_settings := ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(abs_settings)
	for slot_id in SaveAndSettingsService.SLOT_IDS:
		SaveAndSettingsService.delete_campaign_slot(slot_id)
	SaveAndSettingsService.settings = UserSettingsData.new()


func _test_theme_manager_palettes_and_scaling() -> void:
	var tm := tree.root.get_node_or_null("ThemeManager")
	assert_true(tm != null, "ThemeManager autoload mounted in SceneTree")

	var updated_box: Array[int] = [0]
	var cb := func() -> void: updated_box[0] += 1
	ThemeManager.theme_updated.connect(cb)

	ThemeManager.apply_theme("midnight_slate", 1.0)
	assert_eq(ThemeManager.color("bg"), Color.html("#0F1419"), "midnight_slate bg #0F1419")
	assert_eq(ThemeManager.color("surface"), Color.html("#182028"), "midnight_slate surface #182028")
	assert_eq(ThemeManager.color("border"), Color.html("#26323F"), "midnight_slate border #26323F")
	assert_eq(ThemeManager.color("text"), Color.html("#ECF2F8"), "midnight_slate text #ECF2F8")
	assert_eq(ThemeManager.color("accent"), Color.html("#E5A93C"), "midnight_slate accent #E5A93C")
	assert_eq(LocaleService.active_palette_is_dark, true, "midnight_slate syncs active_palette_is_dark == true")
	assert_true(tree.root.theme != null, "ThemeManager applies theme onto tree.root.theme")

	for role in ["bg", "surface", "surface_alt", "border", "text", "muted", "accent", "good", "bad", "warn"]:
		var c: Color = ThemeManager.color(role)
		assert_true(c.a > 0.9, "ThemeManager.color('%s') returns opaque color" % role)

	var panel_sb := tree.root.theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_true(panel_sb != null, "PanelContainer uses StyleBoxFlat")
	if panel_sb != null:
		assert_eq(panel_sb.corner_radius_top_left, 14, "PanelContainer corner radius == 14px")
		assert_eq(panel_sb.corner_radius_bottom_right, 14, "PanelContainer bottom-right radius == 14px")
		assert_eq(panel_sb.bg_color, Color.html("#182028"), "PanelContainer card fill == #182028")

	var base_font_sz := tree.root.theme.default_font_size

	# Verify Button, CheckBox, and LineEdit minimum touch height >= 48px even at minimum 0.85 text_scale
	ThemeManager.apply_theme("midnight_slate", 0.85)
	var sample_btn := Button.new()
	sample_btn.text = "Uji Sentuh"
	tree.root.add_child(sample_btn)
	assert_true(sample_btn.get_combined_minimum_size().y >= 48.0, "Button min height >= 48px at 0.85 scale")
	sample_btn.free()

	var sample_chk := CheckBox.new()
	sample_chk.text = "Opsi"
	tree.root.add_child(sample_chk)
	assert_true(sample_chk.get_combined_minimum_size().y >= 48.0, "CheckBox min height >= 48px at 0.85 scale")
	sample_chk.free()

	var sample_edit := LineEdit.new()
	sample_edit.placeholder_text = "Cari"
	tree.root.add_child(sample_edit)
	assert_true(sample_edit.get_combined_minimum_size().y >= 48.0, "LineEdit min height >= 48px at 0.85 scale")
	sample_edit.free()

	ThemeManager.apply_theme("editorial_paper", 1.30)
	assert_eq(ThemeManager.color("bg"), Color.html("#F6F4EF"), "editorial_paper bg #F6F4EF")
	assert_eq(ThemeManager.color("surface"), Color.html("#FFFFFF"), "editorial_paper surface #FFFFFF")
	assert_eq(ThemeManager.color("text"), Color.html("#1A1D21"), "editorial_paper text #1A1D21")
	assert_eq(ThemeManager.color("accent"), Color.html("#9E2A2B"), "editorial_paper accent #9E2A2B")
	assert_eq(LocaleService.active_palette_is_dark, false, "editorial_paper syncs active_palette_is_dark == false")
	assert_true(tree.root.theme.default_font_size > base_font_sz, "text_scale 1.30 increases default_font_size")

	ThemeManager.theme_updated.disconnect(cb)
	assert_true(updated_box[0] >= 3, "theme_updated emitted on each apply_theme call")
	ThemeManager.apply_theme("midnight_slate", 1.0)


func _test_bottom_sheet_host_and_stat_card_unit_contracts() -> void:
	# Verbatim snippet from Task 6 brief (standalone instantiation before SceneTree mount)
	var host := BottomSheetHost.new()
	var dummy_a := Control.new()
	var dummy_b := Control.new()
	host.push_sheet(dummy_a, "Sheet A")
	host.push_sheet(dummy_b, "Sheet B")
	assert_eq(host.get_open_count(), 2, "BottomSheetHost open count == 2 after two pushes")
	assert_true(host.pop_top_sheet(), "first pop_top_sheet returns true")
	assert_eq(host.get_open_count(), 1, "BottomSheetHost open count == 1 after first pop")
	assert_true(host.pop_top_sheet(), "second pop_top_sheet returns true")
	assert_eq(host.pop_top_sheet(), false, "third pop_top_sheet on empty stack returns false")

	var dummy_c := Control.new()
	var dummy_d := Control.new()
	host.push_sheet(dummy_c, "Sheet C")
	host.push_sheet(dummy_d, "Sheet D")
	assert_eq(host.get_open_count(), 2, "2 sheets open before clear_all_sheets")
	host.clear_all_sheets()
	assert_eq(host.get_open_count(), 0, "clear_all_sheets empties stack")
	host.free()

	var card := StatCardWidget.new()
	card.bind_stat("pop", 62, 1, 0, 100, false)
	var foggy_text := card.get_display_value_text()
	assert_true(not foggy_text.contains("62"), "qualitative fog hides raw integer 62")
	assert_true(foggy_text.contains("↑"), "qualitative fog shows positive trend arrow ↑")

	card.bind_stat("pop", 62, 1, 50, 100, true)
	var exact_text := card.get_display_value_text()
	assert_true(exact_text.contains("62"), "exact_mode shows integer 62")
	assert_true(exact_text.contains("50"), "exact_mode displays floor lock 50")

	card.bind_stat("cendana", 74, -2, 0, 80, false)
	var cen_fog := card.get_display_value_text()
	assert_true(not cen_fog.contains("74") and not cen_fog.contains("80"), "cendana fog hides value and ceiling")
	assert_true(cen_fog.contains("↓"), "cendana fog shows negative delta arrow ↓")

	card.bind_stat("cendana", 74, -2, 0, 80, true)
	var cen_exact := card.get_display_value_text()
	assert_true(cen_exact.contains("74") and cen_exact.contains("80"), "cendana exact_mode shows 74 and ceiling 80")

	for s_key in ["stab", "econ", "pop", "ref", "mil", "cendana"]:
		card.bind_stat(s_key, 47, 0, 15, 85, false)
		assert_false(card.get_display_value_text().contains("47"), "fog hides 47 for stat " + s_key)
		card.bind_stat(s_key, 47, 0, 15, 85, true)
		assert_true(card.get_display_value_text().contains("47"), "exact_mode shows 47 for stat " + s_key)
	card.free()


func _test_safe_area_shell_back_gesture_ui_cancel_and_pause() -> void:
	var shell := SafeAreaShell.new()
	shell.allow_quit_execution = false
	tree.root.add_child(shell)
	await tree.process_frame

	assert_true(shell.bottom_sheet_host != null, "SafeAreaShell creates bottom_sheet_host")

	# Push 2 sheets and verify NOTIFICATION_WM_GO_BACK_REQUEST pops top-first
	shell.bottom_sheet_host.push_sheet(Label.new(), "Layer 1")
	shell.bottom_sheet_host.push_sheet(Label.new(), "Layer 2")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 2, "2 sheets stacked in SafeAreaShell")

	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Back notification pops Layer 2 first")

	# Verify ui_cancel action also pops the remaining sheet
	var cancel_ev := InputEventAction.new()
	cancel_ev.action = &"ui_cancel"
	cancel_ev.pressed = true
	shell._unhandled_input(cancel_ev)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "ui_cancel pops Layer 1")

	# Verify pressing ScrimButton and SheetCloseButton inside mounted BottomSheetHost pops cleanly
	shell.bottom_sheet_host.push_sheet(Label.new(), "Scrim Test")
	var scrim_btn := shell.bottom_sheet_host.find_child("ScrimButton", true, false) as Button
	assert_true(scrim_btn != null, "ScrimButton mounted inside BottomSheetHost")
	scrim_btn.pressed.emit()
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "ScrimButton press pops active sheet")
	await tree.process_frame

	shell.bottom_sheet_host.push_sheet(Label.new(), "CloseBtn Test")
	var close_btn := shell.bottom_sheet_host.find_child("SheetCloseButton", true, false) as Button
	assert_true(close_btn != null, "SheetCloseButton mounted inside BottomSheetHost")
	close_btn.pressed.emit()
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "SheetCloseButton press pops active sheet")
	await tree.process_frame

	# Verify non-main tab falls back to main tab before showing exit prompt
	var returned_tabs: Array[int] = []
	shell.returned_to_main_tab.connect(func(tab_idx: int) -> void: returned_tabs.append(tab_idx))
	shell.set_active_tab(2)
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.active_tab_index, 0, "Back on secondary tab returns to main tab 0")
	assert_eq(returned_tabs.size(), 1, "returned_to_main_tab signal emitted")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "no exit sheet opened while returning to main tab")

	# Verify Back on main tab with 0 sheets opens bottom exit confirmation sheet
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Back on root opens bottom exit confirmation sheet")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "second Back dismisses exit confirmation sheet")

	# Verify NOTIFICATION_APPLICATION_PAUSED persists settings immediately
	var saved_box: Array[int] = [0]
	var save_cb := func() -> void: saved_box[0] += 1
	SaveAndSettingsService.settings_changed.connect(save_cb)
	shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	SaveAndSettingsService.settings_changed.disconnect(save_cb)
	assert_eq(saved_box[0], 1, "NOTIFICATION_APPLICATION_PAUSED saves settings on Android pause")
	assert_true(FileAccess.file_exists(SETTINGS_PATH), "settings.tres written on application pause")

	shell.queue_free()
	await tree.process_frame


func _test_boot_loader_screen_random_messages_and_transition() -> void:
	var packed := ResourceLoader.load("res://godot/scenes/boot_loader_screen.tscn") as PackedScene
	assert_true(packed != null, "boot_loader_screen.tscn loads as PackedScene")
	var boot := packed.instantiate()
	assert_true(boot != null, "boot_loader_screen.tscn instantiates cleanly")
	boot.set("allow_scene_change", false)
	boot.set("auto_transition", false)
	tree.root.add_child(boot)
	await tree.process_frame

	LocaleService.set_locale("id")
	var id_pool := LocaleService.get_loading_messages()
	var msg_id := String(boot.call("get_displayed_loading_message"))
	assert_true(not msg_id.is_empty(), "BootLoaderScreen displays non-empty ID loading message")
	assert_true(id_pool.has(msg_id), "Displayed ID loading message comes from 11 ID loading messages")

	LocaleService.set_locale("en")
	var en_pool := LocaleService.get_loading_messages()
	var msg_en := String(boot.call("get_displayed_loading_message"))
	assert_true(en_pool.has(msg_en), "Locale switch updates BootLoaderScreen to EN loading message pool")

	var target_paths: Array[String] = []
	boot.connect("boot_completed", func(next_path: String) -> void: target_paths.append(next_path))
	boot.call("transition_to_title")
	assert_eq(target_paths.size(), 1, "transition_to_title emits boot_completed")
	assert_eq(target_paths[0], "res://godot/scenes/title_screen.tscn", "BootLoaderScreen transitions to title_screen.tscn")

	LocaleService.set_locale("id")
	boot.queue_free()
	await tree.process_frame


func _test_title_screen_thumb_zone_sheets_changelog_and_toggles() -> void:
	SaveAndSettingsService.delete_campaign_slot("autosave")
	var packed := ResourceLoader.load("res://godot/scenes/title_screen.tscn") as PackedScene
	assert_true(packed != null, "title_screen.tscn loads as PackedScene")
	var title := packed.instantiate()
	assert_true(title != null, "title_screen.tscn instantiates cleanly")
	title.set("allow_scene_change", false)
	tree.root.add_child(title)
	await tree.process_frame
	await tree.process_frame

	var action_buttons: Array = title.call("get_action_buttons")
	assert_eq(action_buttons.size(), 8, "TitleScreen exposes all 8 required action buttons")
	var half_y := float(ProjectSettings.get_setting("display/window/size/viewport_height")) * 0.5
	for raw_btn in action_buttons:
		var btn := raw_btn as Button
		assert_true(btn != null, "action entry is a Button")
		if btn != null:
			assert_true(btn.size.y >= 48.0 or btn.get_combined_minimum_size().y >= 48.0, "Title button '%s' height >= 48px" % btn.name)
			assert_true(btn.global_position.y >= half_y - 2.0, "Title button '%s' sits in lower half of portrait screen (y=%s)" % [btn.name, str(btn.global_position.y)])

	var continue_btn := title.get("btn_continue_autosave") as Button
	assert_true(continue_btn != null and continue_btn.disabled, "Continue Autosave disabled when no autosave exists")

	# Create an autosave and verify Continue Autosave enables and launches cleanly
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.current_turn = 4
	assert_true(SaveAndSettingsService.save_campaign_slot("autosave"), "autosave slot created")
	await tree.process_frame
	assert_false(continue_btn.disabled, "Continue Autosave enabled once autosave exists")

	var launched_slots: Array[String] = []
	title.connect("campaign_launched", func(slot_id: String) -> void: launched_slots.append(slot_id))
	title.call("continue_autosave")
	assert_eq(launched_slots.size(), 1, "continue_autosave emits campaign_launched without requiring Task 7 scene")
	assert_eq(launched_slots[0], "autosave", "continue_autosave launched autosave slot")
	assert_eq(CampaignManager.current_turn, 4, "autosave campaign state loaded")

	# Verify BottomSheets on TitleScreen (Load Slot, Library, Achievements, Changelog) & Back navigation
	var shell := title.get("shell") as SafeAreaShell
	assert_true(shell != null, "TitleScreen uses SafeAreaShell")

	title.call("open_load_slots_sheet")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Load Slots opens BottomSheet")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "Back closes Load Slots BottomSheet")

	title.call("open_library_sheet")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Historical Library opens BottomSheet")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "Back closes Library BottomSheet")

	title.call("open_achievements_sheet")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Achievements opens BottomSheet")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "Back closes Achievements BottomSheet")

	title.call("open_changelog_sheet")
	assert_eq(shell.bottom_sheet_host.get_open_count(), 1, "Changelog opens BottomSheet")
	var changelog_bbcode := String(title.call("get_rendered_changelog_text"))
	assert_true(changelog_bbcode.contains("[i]\"Rekayasa Politik\"[/i]"), "Changelog formats version via updates.version into clean BBCode [i]")
	assert_false(changelog_bbcode.contains("<i>"), "Changelog contains zero raw HTML <i> tags")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(shell.bottom_sheet_host.get_open_count(), 0, "Back closes Changelog BottomSheet")

	# Verify Locale & Theme toggles persist immediately to SaveAndSettingsService
	assert_eq(LocaleService.current_locale, "id", "starts in Indonesian")
	title.call("toggle_locale")
	assert_eq(LocaleService.current_locale, "en", "toggle_locale switches to English")
	assert_eq(SaveAndSettingsService.settings.locale, "en", "toggle_locale updates settings.locale")

	assert_eq(ThemeManager.active_theme_id, "midnight_slate", "starts in midnight_slate")
	title.call("toggle_theme")
	assert_eq(ThemeManager.active_theme_id, "editorial_paper", "toggle_theme switches to editorial_paper")
	assert_eq(SaveAndSettingsService.settings.theme_id, "editorial_paper", "toggle_theme updates settings.theme_id")

	# Reload from disk to prove save_settings() was invoked by UI toggles
	SaveAndSettingsService.load_settings()
	assert_eq(SaveAndSettingsService.settings.locale, "en", "persisted locale reloaded from settings.tres")
	assert_eq(SaveAndSettingsService.settings.theme_id, "editorial_paper", "persisted theme_id reloaded from settings.tres")

	LocaleService.set_locale("id")
	ThemeManager.apply_theme("midnight_slate", 1.0)
	title.queue_free()
	await tree.process_frame


func _test_difficulty_screen_and_dual_mode_sss_board() -> void:
	AchievementService.restore_state({})
	SSSController._init_default_levels()
	SSSController.set_hide_forecast(true)

	var packed := ResourceLoader.load("res://godot/scenes/difficulty_screen.tscn") as PackedScene
	assert_true(packed != null, "difficulty_screen.tscn loads as PackedScene")
	var diff_screen := packed.instantiate()
	assert_true(diff_screen != null, "difficulty_screen.tscn instantiates cleanly")
	diff_screen.set("allow_scene_change", false)
	tree.root.add_child(diff_screen)
	await tree.process_frame
	await tree.process_frame

	# 1. Verify 4 standard difficulties + locked SSS before winning Historical + lower-half thumb zone
	var half_y := float(ProjectSettings.get_setting("display/window/size/viewport_height")) * 0.5
	assert_eq(diff_screen.call("get_standard_difficulty_ids"), ["easy", "medium", "high", "historical"], "4 standard difficulties")
	var sss_btn := diff_screen.get("btn_diff_ucn") as Button
	assert_true(sss_btn != null and sss_btn.disabled, "SSS button locked before win_historical achievement")
	var diff_btn_map: Dictionary = diff_screen.get("diff_buttons")
	for d_key in diff_btn_map.keys():
		var d_btn := diff_btn_map[d_key] as Button
		assert_true(d_btn != null and d_btn.global_position.y >= half_y - 2.0, "Difficulty button '%s' sits in lower half thumb zone" % str(d_key))
	var start_btn := diff_screen.get("btn_start_campaign") as Button
	assert_true(start_btn != null and start_btn.global_position.y >= half_y, "Start Campaign button sits in lower half thumb zone")

	# 2. Standard difficulty selection + forecast toggle + campaign launch
	diff_screen.call("select_difficulty", "medium")
	diff_screen.call("set_standard_forecast_enabled", true)
	var launched_diffs: Array[String] = []
	diff_screen.connect("campaign_launched", func(d_id: String) -> void: launched_diffs.append(d_id))
	diff_screen.call("start_selected_campaign")
	assert_eq(launched_diffs.size(), 1, "start_selected_campaign emits campaign_launched")
	assert_eq(launched_diffs[0], "medium", "launched medium campaign")
	assert_eq(CampaignManager.selected_difficulty, "medium", "CampaignManager difficulty == medium")
	assert_eq(CampaignManager.show_option_effects, true, "CampaignManager forecast enabled on medium")

	# Historical locks forecast off
	diff_screen.call("select_difficulty", "historical")
	diff_screen.call("start_selected_campaign")
	assert_eq(CampaignManager.selected_difficulty, "historical", "CampaignManager difficulty == historical")
	assert_eq(CampaignManager.show_option_effects, false, "Historical difficulty forces show_option_effects == false")

	# 3. Unlock win_historical and open dual-mode 24-card SSS board
	AchievementService.unlock("win_historical")
	await tree.process_frame
	assert_false(sss_btn.disabled, "SSS button unlocks immediately when win_historical is unlocked")

	diff_screen.call("open_sss_board")
	await tree.process_frame
	assert_eq(bool(diff_screen.get("sss_board_open")), true, "SSS board view opened")
	assert_eq(String(diff_screen.get("sss_view_mode")), "list_4_tracks", "default SSS view mode is list_4_tracks (Daftar 4 Jalur)")
	assert_eq(int(diff_screen.call("get_track_list_card_count")), 24, "Daftar 4 Jalur renders all 24 SSS cards across 4 tracks")
	var mode_list_btn := diff_screen.get("btn_sss_mode_list") as Button
	var mode_graph_btn := diff_screen.get("btn_sss_mode_graph") as Button
	assert_true(mode_list_btn != null and mode_list_btn.global_position.y >= half_y, "BtnSSSModeList sits in lower half thumb zone")
	assert_true(mode_graph_btn != null and mode_graph_btn.global_position.y >= half_y, "BtnSSSModeGraph sits in lower half thumb zone")

	# Switch to 2D Node Map (Peta Node 2D) via bottom switcher
	diff_screen.call("set_sss_view_mode", "node_map_2d")
	assert_eq(String(diff_screen.get("sss_view_mode")), "node_map_2d", "switched SSS view mode to node_map_2d (Peta Node 2D)")
	var graph := diff_screen.get("sss_graph_canvas") as SSSGraphCanvas
	assert_true(graph != null and graph.visible, "SSSGraphCanvas visible in node_map_2d mode")
	assert_eq(graph.get_card_node_count(), 24, "SSSGraphCanvas mounts all 24 DAG card nodes")
	assert_eq(graph.get_edge_count(), 36, "SSSGraphCanvas wires all 36 DAG prerequisite edges")

	graph.pan_by(Vector2(-180.0, -90.0))
	assert_true(graph.get_pan_offset().length() > 10.0, "SSSGraphCanvas supports 2D panning")
	graph.set_overview_zoom(true)
	assert_near(graph.zoom_scale, 0.75, 0.05, "SSSGraphCanvas supports overview zoom")
	graph.reset_view()
	assert_eq(graph.get_pan_offset(), Vector2.ZERO, "SSSGraphCanvas reset_view resets pan offset to zero")

	# Verify DAG cascade and settings persistence when changing rank from SSS board
	diff_screen.call("set_sss_card_rank", "pc", 0)
	assert_eq(int(SSSController.levels.get("pc", -1)), 0, "pc set to 0")
	assert_eq(int(SSSController.levels.get("passive", -1)), 0, "dependent card passive cascaded to 0")
	assert_eq(int(SaveAndSettingsService.settings.sss_levels.get("pc", -1)), 0, "sss_levels synced to SaveAndSettingsService")

	# Verify fixed Hide Forecast checkbox in SSS board!
	var hide_cb := diff_screen.get("chk_sss_hide_forecast") as CheckBox
	assert_true(hide_cb != null, "SSS Hide Forecast CheckBox exists")
	assert_true(hide_cb.button_pressed, "SSS Hide Forecast defaults to true")

	diff_screen.call("set_sss_hide_forecast", false)
	assert_eq(SSSController.hide_forecast, false, "SSSController.hide_forecast updated to false")
	assert_eq(SaveAndSettingsService.settings.sss_hide_forecast, false, "settings.sss_hide_forecast persisted as false")

	diff_screen.call("launch_sss_campaign")
	assert_eq(CampaignManager.selected_difficulty, "ucn", "launched ucn (SSS) campaign")
	assert_eq(CampaignManager.show_option_effects, true, "unchecking Hide Forecast enables show_option_effects in SSS run")

	diff_screen.call("set_sss_hide_forecast", true)
	diff_screen.call("launch_sss_campaign")
	assert_eq(CampaignManager.show_option_effects, false, "checking Hide Forecast disables show_option_effects in SSS run")

	# Verify Back gesture inside SSS board closes SSS board back to difficulty selection first
	var shell := diff_screen.get("shell") as SafeAreaShell
	assert_eq(bool(diff_screen.get("sss_board_open")), true, "SSS board still open before Back")
	shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(bool(diff_screen.get("sss_board_open")), false, "Back closes SSS board back to standard difficulty view")

	diff_screen.queue_free()
	await tree.process_frame
