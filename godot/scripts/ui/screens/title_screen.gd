extends Control

signal campaign_launched(slot_id: String)
signal difficulty_screen_requested(scene_path: String)

const CAMPAIGN_SCENE_PATH := "res://godot/scenes/campaign_shell_screen.tscn"
const DIFFICULTY_SCENE_PATH := "res://godot/scenes/difficulty_screen.tscn"
const LIB_PAGE_SIZE := 25

const LIBRARY_CATEGORIES: Array[String] = [
	"all",
	"persons",
	"presidents",
	"institutions",
	"laws_decrees",
	"parties_factions",
	"military_security",
	"economy_kkn",
	"society_movements",
	"political_terms",
]

var shell: SafeAreaShell = null
var allow_scene_change: bool = true

var btn_continue_autosave: Button = null
var btn_new_campaign: Button = null
var btn_load_slot: Button = null
var btn_library: Button = null
var btn_achievements: Button = null
var btn_changelog: Button = null
var btn_locale_toggle: Button = null
var btn_theme_toggle: Button = null

var _date_label: Label = null
var _title_label: Label = null
var _quote_label: Label = null
var _autosave_summary_label: Label = null
var _banner_tex_rect: TextureRect = null

var _lib_category: String = "all"
var _lib_query: String = ""
var _lib_page: int = 0
var _lib_alt_open: Dictionary = {}
var _last_rendered_changelog_text: String = ""


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	shell = SafeAreaShell.new()
	add_child(shell)

	var split_root := Control.new()
	split_root.name = "SplitAnchorRoot"
	split_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content_root.add_child(split_root)

	# Upper Half: Editorial Masthead (strictly top 0.00..0.48)
	var upper_card := PanelContainer.new()
	upper_card.name = "HeroMastheadCard"
	upper_card.anchor_left = 0.0
	upper_card.anchor_right = 1.0
	upper_card.anchor_top = 0.0
	upper_card.anchor_bottom = 0.48
	upper_card.offset_left = 0.0
	upper_card.offset_right = 0.0
	upper_card.offset_top = 0.0
	upper_card.offset_bottom = 0.0
	split_root.add_child(upper_card)

	var hero_vbox := VBoxContainer.new()
	hero_vbox.add_theme_constant_override("separation", 8)
	hero_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper_card.add_child(hero_vbox)

	_date_label = Label.new()
	_date_label.theme_type_variation = &"MutedLabel"
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_vbox.add_child(_date_label)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_vbox.add_child(_title_label)

	_banner_tex_rect = TextureRect.new()
	_banner_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner_tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_banner_tex_rect.custom_minimum_size = Vector2(0.0, 96.0)
	if ResourceLoader.exists("res://photo/title_banner.png"):
		_banner_tex_rect.texture = ResourceLoader.load("res://photo/title_banner.png") as Texture2D
	hero_vbox.add_child(_banner_tex_rect)

	_quote_label = Label.new()
	_quote_label.theme_type_variation = &"MutedLabel"
	_quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_label.max_lines_visible = 3
	_quote_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_vbox.add_child(_quote_label)

	_autosave_summary_label = Label.new()
	_autosave_summary_label.theme_type_variation = &"MutedLabel"
	_autosave_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_autosave_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_vbox.add_child(_autosave_summary_label)

	# Lower Half: One-Handed Thumb-Zone Action Deck (strictly 0.51..1.00, all buttons >= 48px)
	var lower_deck := VBoxContainer.new()
	lower_deck.name = "LowerActionDeck"
	lower_deck.anchor_left = 0.0
	lower_deck.anchor_right = 1.0
	lower_deck.anchor_top = 0.51
	lower_deck.anchor_bottom = 1.0
	lower_deck.offset_left = 0.0
	lower_deck.offset_right = 0.0
	lower_deck.offset_top = 0.0
	lower_deck.offset_bottom = 0.0
	lower_deck.alignment = BoxContainer.ALIGNMENT_END
	lower_deck.add_theme_constant_override("separation", 8)
	split_root.add_child(lower_deck)

	# Row 1: Continue Autosave (Full Width)
	btn_continue_autosave = _make_action_btn("BtnContinueAutosave", true)
	btn_continue_autosave.pressed.connect(continue_autosave)
	lower_deck.add_child(btn_continue_autosave)

	# Row 2: New Campaign | Load Slot
	var row_campaign := HBoxContainer.new()
	row_campaign.add_theme_constant_override("separation", 8)
	lower_deck.add_child(row_campaign)

	btn_new_campaign = _make_action_btn("BtnNewCampaign", true)
	btn_new_campaign.pressed.connect(open_difficulty_screen)
	row_campaign.add_child(btn_new_campaign)

	btn_load_slot = _make_action_btn("BtnLoadSlot", false)
	btn_load_slot.pressed.connect(open_load_slots_sheet)
	row_campaign.add_child(btn_load_slot)

	# Row 3: Historical Library | Achievements
	var row_meta := HBoxContainer.new()
	row_meta.add_theme_constant_override("separation", 8)
	lower_deck.add_child(row_meta)

	btn_library = _make_action_btn("BtnLibrary", false)
	btn_library.pressed.connect(open_library_sheet)
	row_meta.add_child(btn_library)

	btn_achievements = _make_action_btn("BtnAchievements", false)
	btn_achievements.pressed.connect(open_achievements_sheet)
	row_meta.add_child(btn_achievements)

	# Row 4: Changelog / Release Notes (Full Width)
	btn_changelog = _make_action_btn("BtnChangelog", false)
	btn_changelog.pressed.connect(open_changelog_sheet)
	lower_deck.add_child(btn_changelog)

	# Row 5: Locale (ID/EN) | Theme (Midnight/Paper)
	var row_prefs := HBoxContainer.new()
	row_prefs.add_theme_constant_override("separation", 8)
	lower_deck.add_child(row_prefs)

	btn_locale_toggle = _make_action_btn("BtnLocaleToggle", false)
	btn_locale_toggle.pressed.connect(toggle_locale)
	row_prefs.add_child(btn_locale_toggle)

	btn_theme_toggle = _make_action_btn("BtnThemeToggle", false)
	btn_theme_toggle.pressed.connect(toggle_theme)
	row_prefs.add_child(btn_theme_toggle)


static func _make_action_btn(node_name: String, is_accent: bool) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0.0, 48.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	if is_accent:
		btn.theme_type_variation = &"AccentButton"
	return btn


func _ready() -> void:
	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_signal("locale_changed"):
		loc.connect("locale_changed", func(_l: String) -> void: refresh_ui())
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_signal("theme_updated"):
		tm.connect("theme_updated", refresh_ui)
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc != null and save_svc.has_signal("slots_changed"):
		save_svc.connect("slots_changed", refresh_ui)
	refresh_ui()


func get_action_buttons() -> Array[Button]:
	return [
		btn_continue_autosave,
		btn_new_campaign,
		btn_load_slot,
		btn_library,
		btn_achievements,
		btn_changelog,
		btn_locale_toggle,
		btn_theme_toggle,
	]


func get_rendered_changelog_text() -> String:
	return _last_rendered_changelog_text


func refresh_ui() -> void:
	var is_id := _is_indonesian()
	_date_label.text = _tr("date.title_screen")
	_title_label.text = _tr("app.title")
	_quote_label.text = _tr("mpr.quote")

	var autosave_meta := _find_slot_meta("autosave")
	var has_auto := bool(autosave_meta.get("exists", false))
	btn_continue_autosave.disabled = not has_auto
	btn_continue_autosave.text = "Lanjutkan Autosave" if is_id else _tr("title.continue")

	if has_auto:
		var t_num := int(autosave_meta.get("turn_number", 1))
		var d_str := String(autosave_meta.get("date_str", ""))
		var phase_str := _tr("title.phase_action" if bool(autosave_meta.get("is_action_phase", false)) else "title.phase_event")
		_autosave_summary_label.text = _tr("title.continue_summary", {
			"TURN": str(t_num),
			"MAX": "23",
			"DATE": d_str,
			"PHASE": phase_str,
		})
	else:
		_autosave_summary_label.text = "Belum ada autosave aktif" if is_id else "No active autosave"

	btn_new_campaign.text = _tr("startmenu.new_campaign")
	btn_load_slot.text = "Muat Slot" if is_id else "Load Slot"
	btn_library.text = _tr("title.library")
	btn_achievements.text = _tr("title.achievements")
	btn_changelog.text = _tr("updates.heading")

	var cur_lang := "ID" if is_id else "EN"
	btn_locale_toggle.text = ("Bahasa: %s" % cur_lang) if is_id else ("Lang: %s" % cur_lang)

	var tm := get_node_or_null("/root/ThemeManager")
	var is_dark := true
	if tm != null and tm.has_method("is_dark"):
		is_dark = bool(tm.call("is_dark"))
	if is_id:
		btn_theme_toggle.text = "Tema: Gelap" if is_dark else "Tema: Kertas"
	else:
		btn_theme_toggle.text = "Theme: Slate" if is_dark else "Theme: Paper"


func continue_autosave() -> void:
	_play_click()
	load_slot_and_launch("autosave")


func load_slot_and_launch(slot_id: String) -> bool:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc == null or not save_svc.has_method("load_campaign_slot"):
		return false
	var ok := bool(save_svc.call("load_campaign_slot", slot_id))
	if not ok:
		return false
	if shell != null and shell.bottom_sheet_host != null:
		shell.bottom_sheet_host.clear_all_sheets()
	campaign_launched.emit(slot_id)
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(CAMPAIGN_SCENE_PATH):
		get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)
	return true


func open_difficulty_screen() -> void:
	_play_click()
	difficulty_screen_requested.emit(DIFFICULTY_SCENE_PATH)
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(DIFFICULTY_SCENE_PATH):
		get_tree().change_scene_to_file(DIFFICULTY_SCENE_PATH)


func toggle_locale() -> void:
	_play_click()
	var loc := get_node_or_null("/root/LocaleService")
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	var cur := "id"
	if loc != null and "current_locale" in loc:
		cur = String(loc.get("current_locale"))
	var next_loc := "en" if cur == "id" else "id"
	if loc != null and loc.has_method("set_locale"):
		loc.call("set_locale", next_loc)
	if save_svc != null:
		if "settings" in save_svc and save_svc.get("settings") != null:
			(save_svc.get("settings") as UserSettingsData).locale = next_loc
		if save_svc.has_method("save_settings"):
			save_svc.call("save_settings")
	refresh_ui()


func toggle_theme() -> void:
	_play_click()
	var tm := get_node_or_null("/root/ThemeManager")
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	var cur_theme := "midnight_slate"
	var scale_val := 1.0
	if tm != null and "active_theme_id" in tm:
		cur_theme = String(tm.get("active_theme_id"))
	if save_svc != null and "settings" in save_svc and save_svc.get("settings") != null:
		scale_val = (save_svc.get("settings") as UserSettingsData).text_scale
	var next_theme := "editorial_paper" if cur_theme == "midnight_slate" else "midnight_slate"
	if tm != null and tm.has_method("apply_theme"):
		tm.call("apply_theme", next_theme, scale_val)
	if save_svc != null:
		if "settings" in save_svc and save_svc.get("settings") != null:
			(save_svc.get("settings") as UserSettingsData).theme_id = next_theme
		if save_svc.has_method("save_settings"):
			save_svc.call("save_settings")
	refresh_ui()


func open_load_slots_sheet() -> void:
	_play_click()
	var is_id := _is_indonesian()
	var sheet_title := "Muat Slot Kampanye" if is_id else "Load Campaign Slot"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	var metas: Array = save_svc.call("list_slots_metadata") if (save_svc != null and save_svc.has_method("list_slots_metadata")) else []

	for raw_meta in metas:
		if not (raw_meta is Dictionary):
			continue
		var meta: Dictionary = raw_meta
		var sid := String(meta.get("slot_id", ""))
		var exists := bool(meta.get("exists", false))

		var card := PanelContainer.new()
		card.theme_type_variation = &"SurfaceAltCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		var hdr := Label.new()
		hdr.text = _format_slot_display_name(sid, is_id)
		cv.add_child(hdr)

		var info := Label.new()
		info.theme_type_variation = &"MutedLabel"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if exists:
			var t_num := int(meta.get("turn_number", 1))
			var date_s := String(meta.get("date_str", ""))
			var diff_s := String(meta.get("selected_difficulty", "historical")).to_upper()
			var pc_v := int(meta.get("pc", 0))
			var note_s := String(meta.get("note", ""))
			var base_line := "Turn %d/23 · %s · %s · %d PC" % [t_num, date_s, diff_s, pc_v]
			info.text = (base_line + "\n" + note_s) if not note_s.is_empty() else base_line
		else:
			info.text = "Slot kosong" if is_id else "Empty slot"
		cv.add_child(info)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		cv.add_child(btn_row)

		var load_btn := Button.new()
		load_btn.custom_minimum_size = Vector2(0.0, 48.0)
		load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_btn.disabled = not exists
		load_btn.text = ("Muat" if is_id else "Load")
		if exists:
			load_btn.theme_type_variation = &"AccentButton"
		load_btn.pressed.connect(func() -> void: load_slot_and_launch(sid))
		btn_row.add_child(load_btn)

		if exists:
			var del_btn := Button.new()
			del_btn.custom_minimum_size = Vector2(0.0, 48.0)
			del_btn.text = "Hapus" if is_id else "Delete"
			del_btn.pressed.connect(func() -> void:
				if save_svc != null and save_svc.has_method("delete_campaign_slot"):
					save_svc.call("delete_campaign_slot", sid)
				shell.bottom_sheet_host.pop_top_sheet()
				open_load_slots_sheet()
			)
			btn_row.add_child(del_btn)

	shell.bottom_sheet_host.push_sheet(box, sheet_title)


func open_library_sheet() -> void:
	_play_click()
	_lib_page = 0
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	root_box.add_child(search_row)

	var search_edit := LineEdit.new()
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.custom_minimum_size = Vector2(0.0, 48.0)
	search_edit.placeholder_text = _tr("library.search_placeholder")
	search_edit.text = _lib_query
	search_row.add_child(search_edit)

	var clear_btn := Button.new()
	clear_btn.custom_minimum_size = Vector2(72.0, 48.0)
	clear_btn.text = _tr("library.clear")
	search_row.add_child(clear_btn)

	var cat_scroll := ScrollContainer.new()
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.custom_minimum_size = Vector2(0.0, 54.0)
	cat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(cat_scroll)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_scroll.add_child(cat_row)

	var entries_holder := VBoxContainer.new()
	entries_holder.add_theme_constant_override("separation", 8)
	entries_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(entries_holder)

	var rebuild_fn := Callable(self, "_populate_library_entries").bind(entries_holder, cat_row)
	search_edit.text_changed.connect(func(new_q: String) -> void:
		_lib_query = new_q
		_lib_page = 0
		rebuild_fn.call()
	)
	clear_btn.pressed.connect(func() -> void:
		_lib_query = ""
		_lib_page = 0
		search_edit.text = ""
		rebuild_fn.call()
	)

	_populate_library_entries(entries_holder, cat_row)
	shell.bottom_sheet_host.push_sheet(root_box, _tr("library.title"))


func _populate_library_entries(entries_holder: VBoxContainer, cat_row: HBoxContainer) -> void:
	if not is_instance_valid(entries_holder) or not is_instance_valid(cat_row):
		return
	for ch in cat_row.get_children():
		cat_row.remove_child(ch)
		ch.queue_free()
	for ch in entries_holder.get_children():
		entries_holder.remove_child(ch)
		ch.queue_free()

	for cat_id in LIBRARY_CATEGORIES:
		var c_btn := Button.new()
		c_btn.custom_minimum_size = Vector2(0.0, 48.0)
		c_btn.text = _tr("library.category." + cat_id)
		if _lib_category == cat_id:
			c_btn.theme_type_variation = &"AccentButton"
		var captured_cat: String = String(cat_id)
		c_btn.pressed.connect(func() -> void:
			_lib_category = captured_cat
			_lib_page = 0
			_populate_library_entries(entries_holder, cat_row)
		)
		cat_row.add_child(c_btn)

	var cdb := get_node_or_null("/root/ContentDB")
	if cdb == null or cdb.get("catalog") == null:
		return
	var catalog: GameCatalogData = cdb.get("catalog") as GameCatalogData

	var q := _lib_query.strip_edges().to_lower()
	var filtered: Array[LibraryEntryData] = []
	for entry in catalog.library_entries:
		if _lib_category != "all" and entry.category != _lib_category:
			continue
		if not q.is_empty():
			var hay := (
				_tr(entry.term_key) + " "
				+ _tr(entry.subtitle_key) + " "
				+ _tr(entry.desc_key)
			).to_lower()
			if not hay.contains(q):
				continue
		filtered.append(entry)

	if filtered.is_empty():
		var empty_rtl := RichTextLabel.new()
		empty_rtl.bbcode_enabled = true
		empty_rtl.fit_content = true
		empty_rtl.scroll_active = false
		empty_rtl.text = _tr("library.no_match", {
			"QUERY": _lib_query,
			"CATEGORY": _tr("library.category." + _lib_category),
		})
		entries_holder.add_child(empty_rtl)
		return

	var count_rtl := RichTextLabel.new()
	count_rtl.bbcode_enabled = true
	count_rtl.fit_content = true
	count_rtl.scroll_active = false
	count_rtl.text = _tr("library.showing_one" if filtered.size() == 1 else "library.showing_many", {
		"COUNT": str(filtered.size()),
	})
	entries_holder.add_child(count_rtl)

	var total_pages := maxi(1, int(ceil(float(filtered.size()) / float(LIB_PAGE_SIZE))))
	_lib_page = clampi(_lib_page, 0, total_pages - 1)
	var start_i := _lib_page * LIB_PAGE_SIZE
	var end_i := mini(filtered.size(), start_i + LIB_PAGE_SIZE)

	for idx in range(start_i, end_i):
		var item := filtered[idx]
		var card := PanelContainer.new()
		card.theme_type_variation = &"SurfaceAltCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entries_holder.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		var term_lbl := Label.new()
		term_lbl.text = _tr(item.term_key)
		term_lbl.theme_type_variation = &"HeaderLabel"
		term_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(term_lbl)

		if not item.subtitle_key.is_empty():
			var sub_lbl := Label.new()
			sub_lbl.text = _tr(item.subtitle_key)
			sub_lbl.theme_type_variation = &"MutedLabel"
			sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(sub_lbl)

		var show_alt := bool(_lib_alt_open.get(item.id, false)) and not item.alt_key.is_empty()
		var body_rtl := RichTextLabel.new()
		body_rtl.bbcode_enabled = true
		body_rtl.fit_content = true
		body_rtl.scroll_active = false
		body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_rtl.text = _tr(item.alt_key if show_alt else item.desc_key)
		cv.add_child(body_rtl)

		if not item.alt_key.is_empty():
			var alt_title := _tr(item.alt_title_key) if not item.alt_title_key.is_empty() else _tr("library.alt_label")
			var toggle_btn := Button.new()
			toggle_btn.custom_minimum_size = Vector2(0.0, 48.0)
			toggle_btn.text = _tr("library.portrait_hint_back") if show_alt else alt_title
			var entry_id := item.id
			toggle_btn.pressed.connect(func() -> void:
				_lib_alt_open[entry_id] = not bool(_lib_alt_open.get(entry_id, false))
				_populate_library_entries(entries_holder, cat_row)
			)
			cv.add_child(toggle_btn)

	if total_pages > 1:
		var pager := HBoxContainer.new()
		pager.add_theme_constant_override("separation", 8)
		entries_holder.add_child(pager)

		var prev_btn := Button.new()
		prev_btn.custom_minimum_size = Vector2(0.0, 48.0)
		prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prev_btn.disabled = (_lib_page <= 0)
		prev_btn.text = _tr("common.previous")
		prev_btn.pressed.connect(func() -> void:
			_lib_page = maxi(0, _lib_page - 1)
			_populate_library_entries(entries_holder, cat_row)
		)
		pager.add_child(prev_btn)

		var page_lbl := Label.new()
		page_lbl.text = _tr("common.page_of", {"N": str(_lib_page + 1), "TOTAL": str(total_pages)})
		page_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pager.add_child(page_lbl)

		var next_btn := Button.new()
		next_btn.custom_minimum_size = Vector2(0.0, 48.0)
		next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_btn.disabled = (_lib_page >= total_pages - 1)
		next_btn.text = _tr("common.next")
		next_btn.pressed.connect(func() -> void:
			_lib_page = mini(total_pages - 1, _lib_page + 1)
			_populate_library_entries(entries_holder, cat_row)
		)
		pager.add_child(next_btn)


func open_achievements_sheet() -> void:
	_play_click()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cdb := get_node_or_null("/root/ContentDB")
	var ach_svc := get_node_or_null("/root/AchievementService")
	var catalog: GameCatalogData = cdb.get("catalog") as GameCatalogData if cdb != null else null
	var total := catalog.achievements.size() if catalog != null else 0
	var unlocked_cnt := 0
	if catalog != null and ach_svc != null and ach_svc.has_method("is_unlocked"):
		for a in catalog.achievements:
			if bool(ach_svc.call("is_unlocked", a.id)):
				unlocked_cnt += 1

	var intro_lbl := Label.new()
	intro_lbl.text = "%s (%d / %d)" % [_tr("achievements.intro"), unlocked_cnt, total]
	intro_lbl.theme_type_variation = &"MutedLabel"
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro_lbl)

	if catalog != null:
		for ach in catalog.achievements:
			var is_open := ach_svc != null and ach_svc.has_method("is_unlocked") and bool(ach_svc.call("is_unlocked", ach.id))
			var card := PanelContainer.new()
			card.theme_type_variation = &"SurfaceAltCard"
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(card)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 4)
			card.add_child(cv)

			var t_lbl := Label.new()
			t_lbl.text = ("%s %s" % ["✓" if is_open else "🔒", _tr(ach.title_key)])
			t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(t_lbl)

			var d_rtl := RichTextLabel.new()
			d_rtl.bbcode_enabled = true
			d_rtl.fit_content = true
			d_rtl.scroll_active = false
			d_rtl.text = _tr(ach.desc_key)
			cv.add_child(d_rtl)

	shell.bottom_sheet_host.push_sheet(box, _tr("title.achievements"))


func open_changelog_sheet() -> void:
	_play_click()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cdb := get_node_or_null("/root/ContentDB")
	var catalog: GameCatalogData = cdb.get("catalog") as GameCatalogData if cdb != null else null
	var full_chunks: Array[String] = []

	if catalog != null:
		for entry in catalog.changelog_entries:
			var ver_raw := String(entry.get("version", ""))
			var ver_bb := _tr("updates.version", {"VERSION": ver_raw})
			var date_bb := _tr(String(entry.get("date_key", "")))
			var title_bb := _tr(String(entry.get("title_key", "")))

			var card := PanelContainer.new()
			card.theme_type_variation = &"SurfaceAltCard"
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(card)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 6)
			card.add_child(cv)

			var header_rtl := RichTextLabel.new()
			header_rtl.bbcode_enabled = true
			header_rtl.fit_content = true
			header_rtl.scroll_active = false
			header_rtl.text = "%s — %s\n[b]%s[/b]" % [ver_bb, date_bb, title_bb]
			cv.add_child(header_rtl)

			var notes_lines: Array[String] = []
			var raw_notes: Variant = entry.get("note_keys", [])
			if raw_notes is Array:
				for nk in raw_notes:
					notes_lines.append("• " + _tr(String(nk)))
			var body_text := "\n\n".join(notes_lines)

			var notes_rtl := RichTextLabel.new()
			notes_rtl.bbcode_enabled = true
			notes_rtl.fit_content = true
			notes_rtl.scroll_active = false
			notes_rtl.text = body_text
			cv.add_child(notes_rtl)

			full_chunks.append(header_rtl.text + "\n" + body_text)

	_last_rendered_changelog_text = "\n\n".join(full_chunks)
	shell.bottom_sheet_host.push_sheet(box, _tr("updates.heading"))


func _find_slot_meta(slot_id: String) -> Dictionary:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc == null or not save_svc.has_method("list_slots_metadata"):
		return {}
	var list: Array = save_svc.call("list_slots_metadata")
	for item in list:
		if item is Dictionary and String((item as Dictionary).get("slot_id", "")) == slot_id:
			return item as Dictionary
	return {}


static func _format_slot_display_name(slot_id: String, is_id: bool) -> String:
	if slot_id == "autosave":
		return "Autosave"
	var num := slot_id.trim_prefix("slot_")
	return ("Slot Manual %s" % num) if is_id else ("Manual Slot %s" % num)


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
