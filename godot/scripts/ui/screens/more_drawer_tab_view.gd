class_name MoreDrawerTabView
extends ScrollContainer

signal return_to_title_requested()

const TITLE_SCENE_PATH := "res://godot/scenes/title_screen.tscn"
const DEFAULT_BACKUP_PATH := "user://backup_export.json"

var allow_scene_change: bool = true
var _sheet_host: BottomSheetHost = null
var _root_vbox: VBoxContainer = null

# (a) Mini Music Player
var _cover_rect: TextureRect = null
var _track_title_label: Label = null
var _track_meta_label: Label = null
var _seek_slider: HSlider = null
var _btn_prev_track: Button = null
var _btn_play_pause: Button = null
var _btn_next_track: Button = null
var _genre_option: OptionButton = null
var _chk_weighted_shuffle: CheckBox = null

# (b) Save / Load & Backup
var _slots_vbox: VBoxContainer = null
var _backup_status_label: Label = null
var _btn_export_backup: Button = null
var _btn_import_backup: Button = null

# (c) Achievements & (d) Tutorial
var _btn_open_achievements: Button = null
var _btn_open_tutorial: Button = null
var _tutorial_step_idx: int = 0

# (e) Settings
var _btn_lang_id: Button = null
var _btn_lang_en: Button = null
var _btn_theme_dark: Button = null
var _btn_theme_light: Button = null
var _scale_label: Label = null
var _scale_slider: HSlider = null
var _chk_exact_numbers: CheckBox = null
var _chk_auto_advance: CheckBox = null
var _chk_music_enable: CheckBox = null
var _music_vol_slider: HSlider = null
var _chk_sfx_enable: CheckBox = null
var _sfx_vol_slider: HSlider = null
var _btn_return_title: Button = null

var _syncing_ui: bool = false


func _init() -> void:
	name = "MoreDrawerTabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", 12)
	add_child(_root_vbox)

	_build_music_card()
	_build_saves_card()
	_build_meta_buttons_card()
	_build_settings_card()


func _ready() -> void:
	if AudioController != null:
		AudioController.track_changed.connect(func(_t: MusicTrackData) -> void: refresh_view())
	if SaveAndSettingsService != null:
		SaveAndSettingsService.slots_changed.connect(refresh_view)
		SaveAndSettingsService.settings_changed.connect(refresh_view)
	if AchievementService != null:
		AchievementService.achievement_unlocked.connect(func(_id: String) -> void: refresh_view())
	if LocaleService != null:
		LocaleService.locale_changed.connect(func(_l: String) -> void: refresh_view())
	if ThemeManager != null:
		ThemeManager.theme_updated.connect(refresh_view)
	refresh_view()


func bind_sheet_host(host: BottomSheetHost) -> void:
	_sheet_host = host


func _resolve_sheet_host() -> BottomSheetHost:
	if _sheet_host != null:
		return _sheet_host
	var cur: Node = get_parent()
	while cur != null:
		if cur is SafeAreaShell:
			return (cur as SafeAreaShell).bottom_sheet_host
		cur = cur.get_parent()
	return null


func _build_music_card() -> void:
	var card := PanelContainer.new()
	card.name = "MiniMusicPlayerCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 10)
	vb.add_child(top_hb)

	_cover_rect = TextureRect.new()
	_cover_rect.custom_minimum_size = Vector2(64.0, 64.0)
	_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top_hb.add_child(_cover_rect)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 2)
	top_hb.add_child(info_vb)

	_track_title_label = Label.new()
	_track_title_label.theme_type_variation = &"HeaderLabel"
	_track_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(_track_title_label)

	_track_meta_label = Label.new()
	_track_meta_label.theme_type_variation = &"MutedLabel"
	info_vb.add_child(_track_meta_label)

	_seek_slider = HSlider.new()
	_seek_slider.min_value = 0.0
	_seek_slider.max_value = 100.0
	_seek_slider.step = 1.0
	_seek_slider.custom_minimum_size = Vector2(0.0, 32.0)
	_seek_slider.value_changed.connect(_on_seek_slider_changed)
	vb.add_child(_seek_slider)

	var ctrl_hb := HBoxContainer.new()
	ctrl_hb.add_theme_constant_override("separation", 8)
	vb.add_child(ctrl_hb)

	_btn_prev_track = _make_btn("BtnMusicPrev", false)
	_btn_prev_track.pressed.connect(func() -> void:
		if AudioController != null:
			AudioController.prev_track()
		refresh_view()
	)
	ctrl_hb.add_child(_btn_prev_track)

	_btn_play_pause = _make_btn("BtnMusicPlayPause", true)
	_btn_play_pause.pressed.connect(func() -> void:
		if AudioController != null:
			AudioController.toggle_play_pause()
		refresh_view()
	)
	ctrl_hb.add_child(_btn_play_pause)

	_btn_next_track = _make_btn("BtnMusicNext", false)
	_btn_next_track.pressed.connect(func() -> void:
		if AudioController != null:
			AudioController.next_track()
		refresh_view()
	)
	ctrl_hb.add_child(_btn_next_track)

	_genre_option = OptionButton.new()
	_genre_option.name = "MusicGenreOption"
	_genre_option.custom_minimum_size = Vector2(0.0, 48.0)
	_genre_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_genre_option.item_selected.connect(_on_genre_item_selected)
	vb.add_child(_genre_option)

	_chk_weighted_shuffle = _make_checkbox("ChkWeightedShuffle")
	_chk_weighted_shuffle.toggled.connect(func(on: bool) -> void:
		if not _syncing_ui:
			set_weighted_shuffle_enabled(on)
	)
	vb.add_child(_chk_weighted_shuffle)


func _build_saves_card() -> void:
	var card := PanelContainer.new()
	card.name = "SaveSlotsManagerCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	_slots_vbox = VBoxContainer.new()
	_slots_vbox.add_theme_constant_override("separation", 8)
	vb.add_child(_slots_vbox)

	var backup_hb := HBoxContainer.new()
	backup_hb.add_theme_constant_override("separation", 8)
	vb.add_child(backup_hb)

	_btn_export_backup = _make_btn("BtnExportBackup", false)
	_btn_export_backup.pressed.connect(func() -> void: export_backup_to(DEFAULT_BACKUP_PATH))
	backup_hb.add_child(_btn_export_backup)

	_btn_import_backup = _make_btn("BtnImportBackup", false)
	_btn_import_backup.pressed.connect(func() -> void: import_backup_from(DEFAULT_BACKUP_PATH))
	backup_hb.add_child(_btn_import_backup)

	_backup_status_label = Label.new()
	_backup_status_label.theme_type_variation = &"MutedLabel"
	_backup_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_backup_status_label)


func _build_meta_buttons_card() -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	_btn_open_achievements = _make_btn("BtnOpenAchievements", false)
	_btn_open_achievements.pressed.connect(open_achievements_gallery)
	vb.add_child(_btn_open_achievements)

	_btn_open_tutorial = _make_btn("BtnOpenTutorial", false)
	_btn_open_tutorial.pressed.connect(open_tutorial_sheet)
	vb.add_child(_btn_open_tutorial)


func _build_settings_card() -> void:
	var card := PanelContainer.new()
	card.name = "SettingsDrawerCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var lang_hb := HBoxContainer.new()
	lang_hb.add_theme_constant_override("separation", 8)
	vb.add_child(lang_hb)

	_btn_lang_id = _make_btn("BtnSetLangID", false)
	_btn_lang_id.text = "Bahasa Indonesia"
	_btn_lang_id.pressed.connect(func() -> void: set_locale_code("id"))
	lang_hb.add_child(_btn_lang_id)

	_btn_lang_en = _make_btn("BtnSetLangEN", false)
	_btn_lang_en.text = "English"
	_btn_lang_en.pressed.connect(func() -> void: set_locale_code("en"))
	lang_hb.add_child(_btn_lang_en)

	var theme_hb := HBoxContainer.new()
	theme_hb.add_theme_constant_override("separation", 8)
	vb.add_child(theme_hb)

	_btn_theme_dark = _make_btn("BtnSetThemeDark", false)
	_btn_theme_dark.pressed.connect(func() -> void: set_theme_choice("midnight_slate"))
	theme_hb.add_child(_btn_theme_dark)

	_btn_theme_light = _make_btn("BtnSetThemeLight", false)
	_btn_theme_light.pressed.connect(func() -> void: set_theme_choice("editorial_paper"))
	theme_hb.add_child(_btn_theme_light)

	_scale_label = Label.new()
	_scale_label.theme_type_variation = &"MutedLabel"
	vb.add_child(_scale_label)

	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.85
	_scale_slider.max_value = 1.40
	_scale_slider.step = 0.05
	_scale_slider.custom_minimum_size = Vector2(0.0, 36.0)
	_scale_slider.value_changed.connect(func(v: float) -> void:
		if not _syncing_ui:
			set_text_scale_value(v)
	)
	vb.add_child(_scale_slider)

	_chk_exact_numbers = _make_checkbox("ChkShowExactNumbers")
	_chk_exact_numbers.toggled.connect(func(on: bool) -> void:
		if not _syncing_ui:
			set_exact_numbers_enabled(on)
	)
	vb.add_child(_chk_exact_numbers)

	_chk_auto_advance = _make_checkbox("ChkAutoAdvanceTurn")
	_chk_auto_advance.toggled.connect(func(on: bool) -> void:
		if not _syncing_ui:
			set_auto_advance_enabled(on)
	)
	vb.add_child(_chk_auto_advance)

	_chk_music_enable = _make_checkbox("ChkMusicEnabled")
	_chk_music_enable.toggled.connect(func(on: bool) -> void:
		if not _syncing_ui:
			set_music_enabled_state(on)
	)
	vb.add_child(_chk_music_enable)

	_music_vol_slider = HSlider.new()
	_music_vol_slider.min_value = 0.0
	_music_vol_slider.max_value = 1.0
	_music_vol_slider.step = 0.05
	_music_vol_slider.custom_minimum_size = Vector2(0.0, 32.0)
	_music_vol_slider.value_changed.connect(func(v: float) -> void:
		if not _syncing_ui:
			set_music_volume_value(v)
	)
	vb.add_child(_music_vol_slider)

	_chk_sfx_enable = _make_checkbox("ChkSFXEnabled")
	_chk_sfx_enable.toggled.connect(func(on: bool) -> void:
		if not _syncing_ui:
			set_sfx_enabled_state(on)
	)
	vb.add_child(_chk_sfx_enable)

	_sfx_vol_slider = HSlider.new()
	_sfx_vol_slider.min_value = 0.0
	_sfx_vol_slider.max_value = 1.0
	_sfx_vol_slider.step = 0.05
	_sfx_vol_slider.custom_minimum_size = Vector2(0.0, 32.0)
	_sfx_vol_slider.value_changed.connect(func(v: float) -> void:
		if not _syncing_ui:
			set_sfx_volume_value(v)
	)
	vb.add_child(_sfx_vol_slider)

	_btn_return_title = _make_btn("BtnReturnToTitle", false)
	_btn_return_title.pressed.connect(_on_return_to_title_pressed)
	vb.add_child(_btn_return_title)


static func _make_btn(node_name: String, accent: bool) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0.0, 48.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if accent:
		btn.theme_type_variation = &"AccentButton"
	return btn


static func _make_checkbox(node_name: String) -> CheckBox:
	var chk := CheckBox.new()
	chk.name = node_name
	chk.custom_minimum_size = Vector2(0.0, 48.0)
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chk.clip_text = false
	return chk


func set_music_genre(genre: String) -> void:
	if AudioController != null:
		AudioController.set_genre(genre)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.active_genre = AudioController.active_genre if AudioController != null else genre
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_weighted_shuffle_enabled(enabled: bool) -> void:
	if AudioController != null:
		AudioController.set_weighted_shuffle(enabled)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.weighted_shuffle = enabled
		SaveAndSettingsService.save_settings()
	refresh_view()


func _on_genre_item_selected(idx: int) -> void:
	if _syncing_ui or AudioController == null:
		return
	if idx >= 0 and idx < AudioController.GENRES.size():
		set_music_genre(AudioController.GENRES[idx])


func _on_seek_slider_changed(pct: float) -> void:
	if _syncing_ui or AudioController == null:
		return
	var length := AudioController.get_stream_length()
	if length > 0.0:
		AudioController.seek_to((pct / 100.0) * length)


func save_slot(slot_id: String) -> bool:
	if SaveAndSettingsService == null:
		return false
	var ok := SaveAndSettingsService.save_campaign_slot(slot_id)
	refresh_view()
	return ok


func load_slot(slot_id: String) -> bool:
	if SaveAndSettingsService == null:
		return false
	var ok := SaveAndSettingsService.load_campaign_slot(slot_id)
	refresh_view()
	return ok


func export_backup_to(target_path: String) -> bool:
	if SaveAndSettingsService == null:
		return false
	var ok := SaveAndSettingsService.export_backup_json(target_path)
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	if _backup_status_label != null:
		_backup_status_label.text = (
			("Cadangan berhasil diekspor: " + target_path) if ok else "Gagal mengekspor cadangan."
		) if is_id else (
			("Backup exported: " + target_path) if ok else "Backup export failed."
		)
	return ok


func import_backup_from(source_path: String) -> bool:
	if SaveAndSettingsService == null:
		return false
	var ok := SaveAndSettingsService.import_backup_json(source_path)
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	if _backup_status_label != null:
		_backup_status_label.text = (
			"Cadangan berhasil diimpor." if ok else "Berkas cadangan tidak valid."
		) if is_id else (
			"Backup imported." if ok else "Invalid backup file."
		)
	refresh_view()
	return ok


func set_locale_code(code: String) -> void:
	if LocaleService != null:
		LocaleService.set_locale(code)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.locale = code
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_theme_choice(t_id: String) -> void:
	var sc := SaveAndSettingsService.settings.text_scale if (SaveAndSettingsService != null and SaveAndSettingsService.settings != null) else 1.0
	if ThemeManager != null:
		ThemeManager.apply_theme(t_id, sc)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.theme_id = ThemeManager.active_theme_id if ThemeManager != null else t_id
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_text_scale_value(scale_v: float) -> void:
	var clamped := clampf(scale_v, 0.85, 1.40)
	var t_id := ThemeManager.active_theme_id if ThemeManager != null else "midnight_slate"
	if ThemeManager != null:
		ThemeManager.apply_theme(t_id, clamped)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.text_scale = clamped
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_exact_numbers_enabled(enabled: bool) -> void:
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.show_exact_numbers = enabled
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_auto_advance_enabled(enabled: bool) -> void:
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.auto_advance_turn = enabled
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_music_enabled_state(enabled: bool) -> void:
	if AudioController != null:
		AudioController.set_music_enabled(enabled)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.music_enabled = enabled
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_music_volume_value(vol: float) -> void:
	if AudioController != null:
		AudioController.set_music_volume(vol)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.music_volume = vol
		SaveAndSettingsService.save_settings()


func set_sfx_enabled_state(enabled: bool) -> void:
	if AudioController != null:
		AudioController.set_sfx_enabled(enabled)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.sfx_enabled = enabled
		SaveAndSettingsService.save_settings()
	refresh_view()


func set_sfx_volume_value(vol: float) -> void:
	if AudioController != null:
		AudioController.set_sfx_volume(vol)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings.sfx_volume = vol
		SaveAndSettingsService.save_settings()


func open_achievements_gallery() -> void:
	var host := _resolve_sheet_host()
	if host == null or ContentDB == null or ContentDB.catalog == null:
		return
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for ach in ContentDB.catalog.achievements:
		var unlocked := AchievementService != null and AchievementService.is_unlocked(ach.id)
		var card := PanelContainer.new()
		card.theme_type_variation = &"SurfaceAltCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		if not ach.icon_path.is_empty() and ResourceLoader.exists(ach.icon_path):
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(44.0, 44.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = ResourceLoader.load(ach.icon_path) as Texture2D
			icon.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.5, 0.5, 0.5, 0.45)
			hb.add_child(icon)

		var tvb := VBoxContainer.new()
		tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tvb)

		var t_lbl := Label.new()
		var badge := "✓ " if unlocked else "🔒 "
		t_lbl.text = badge + (LocaleService.tr_fmt(ach.title_key) if LocaleService != null else ach.id)
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tvb.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.theme_type_variation = &"MutedLabel"
		d_lbl.text = LocaleService.tr_fmt(ach.desc_key) if LocaleService != null else ach.desc_key
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tvb.add_child(d_lbl)

	var unlocked_cnt := AchievementService.unlocked_ids.size() if AchievementService != null else 0
	var sheet_title := "%s (%d/%d)" % [
		(LocaleService.tr_fmt("title.achievements") if LocaleService != null else ("Pencapaian" if is_id else "Achievements")),
		unlocked_cnt,
		ContentDB.catalog.achievements.size(),
	]
	host.push_sheet(vb, sheet_title)


func open_tutorial_sheet() -> void:
	var host := _resolve_sheet_host()
	if host == null:
		return
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var total_steps := ContentDB.catalog.tutorial_count if (ContentDB != null and ContentDB.catalog != null) else 6
	_tutorial_step_idx = clampi(_tutorial_step_idx, 0, maxi(0, total_steps - 1))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var step_title_lbl := Label.new()
	step_title_lbl.theme_type_variation = &"HeaderLabel"
	step_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(step_title_lbl)

	var step_body_rtl := RichTextLabel.new()
	step_body_rtl.bbcode_enabled = true
	step_body_rtl.fit_content = true
	step_body_rtl.scroll_active = false
	step_body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(step_body_rtl)

	var nav_hb := HBoxContainer.new()
	nav_hb.add_theme_constant_override("separation", 8)
	vb.add_child(nav_hb)

	var prev_btn := _make_btn("TutorialPrevBtn", false)
	prev_btn.text = "◀ Sebelumnya" if is_id else "◀ Previous"
	nav_hb.add_child(prev_btn)

	var next_btn := _make_btn("TutorialNextBtn", true)
	next_btn.text = "Berikutnya ▶" if is_id else "Next ▶"
	nav_hb.add_child(next_btn)

	var render_step := func() -> void:
		var idx := clampi(_tutorial_step_idx, 0, total_steps - 1)
		var t_key := "tutorial.%d.title" % idx
		var b_key := "tutorial.%d.text" % idx
		step_title_lbl.text = "(%d/%d) %s" % [idx + 1, total_steps, (LocaleService.tr_fmt(t_key) if LocaleService != null else t_key)]
		step_body_rtl.text = LocaleService.tr_fmt(b_key) if LocaleService != null else b_key
		prev_btn.disabled = idx <= 0
		next_btn.disabled = idx + 1 >= total_steps

	prev_btn.pressed.connect(func() -> void:
		_tutorial_step_idx = maxi(0, _tutorial_step_idx - 1)
		render_step.call()
	)
	next_btn.pressed.connect(func() -> void:
		_tutorial_step_idx = mini(total_steps - 1, _tutorial_step_idx + 1)
		render_step.call()
	)
	render_step.call()

	var hdr := LocaleService.tr_fmt("tutorial.title") if LocaleService != null else ("Panduan Permainan" if is_id else "Tutorial Guide")
	host.push_sheet(vb, hdr)


func _on_return_to_title_pressed() -> void:
	return_to_title_requested.emit()
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(TITLE_SCENE_PATH):
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func refresh_view() -> void:
	_syncing_ui = true
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var s := SaveAndSettingsService.settings if SaveAndSettingsService != null else UserSettingsData.new()

	# (a) Music Player
	var track := AudioController.get_current_track() if AudioController != null else null
	if track != null:
		_track_title_label.text = track.title
		_track_meta_label.text = "#%d • %s" % [track.index + 1, track.genre.capitalize()]
		if not track.cover_path.is_empty() and ResourceLoader.exists(track.cover_path):
			_cover_rect.texture = ResourceLoader.load(track.cover_path) as Texture2D
	else:
		_track_title_label.text = "Pemutar Musik" if is_id else "Music Player"
		_track_meta_label.text = ""

	_btn_prev_track.text = "⏮"
	_btn_play_pause.text = ("⏸ Jeda" if is_id else "⏸ Pause") if (AudioController != null and AudioController.is_playing) else ("▶ Putar" if is_id else "▶ Play")
	_btn_next_track.text = "⏭"

	if AudioController != null:
		var dur := AudioController.get_stream_length()
		var pos := AudioController.get_playback_position()
		_seek_slider.value = clampf((pos / dur) * 100.0, 0.0, 100.0) if dur > 0.0 else 0.0

		_genre_option.clear()
		var sel_g_idx := 0
		for i in range(AudioController.GENRES.size()):
			var g: String = AudioController.GENRES[i]
			var g_lbl := LocaleService.tr_fmt("music.genre." + g) if LocaleService != null else g.capitalize()
			_genre_option.add_item(g_lbl, i)
			if g == AudioController.active_genre:
				sel_g_idx = i
		_genre_option.selected = sel_g_idx
		_chk_weighted_shuffle.button_pressed = AudioController.weighted_shuffle

	_chk_weighted_shuffle.text = "Acak Berbobot Suasana (Weighted Shuffle)" if is_id else "Mood-Weighted Shuffle"

	# (b) Save Slots
	for ch in _slots_vbox.get_children():
		_slots_vbox.remove_child(ch)
		ch.queue_free()

	var slots_meta := SaveAndSettingsService.list_slots_metadata() if SaveAndSettingsService != null else []
	for meta in slots_meta:
		var sid := String(meta.get("slot_id", ""))
		var exists := bool(meta.get("exists", false))
		var row_card := PanelContainer.new()
		row_card.theme_type_variation = &"SurfaceAltCard"
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slots_vbox.add_child(row_card)

		var rvb := VBoxContainer.new()
		rvb.add_theme_constant_override("separation", 6)
		row_card.add_child(rvb)

		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var slot_title := "Autosave" if sid == "autosave" else ("Slot Manual " + sid.trim_prefix("slot_") if is_id else "Manual Slot " + sid.trim_prefix("slot_"))
		if exists:
			lbl.text = "%s — Giliran %d/23 (%s • PC %d)" % [slot_title, int(meta.get("turn_number", 1)), String(meta.get("date_str", "")), int(meta.get("pc", 0))]
		else:
			lbl.text = "%s — %s" % [slot_title, ("Kosong" if is_id else "Empty")]
		rvb.add_child(lbl)

		var bhb := HBoxContainer.new()
		bhb.add_theme_constant_override("separation", 6)
		rvb.add_child(bhb)

		if sid != "autosave":
			var s_btn := _make_btn("SaveBtn_" + sid, true)
			s_btn.text = "Simpan" if is_id else "Save"
			var target_save := sid
			s_btn.pressed.connect(func() -> void: save_slot(target_save))
			bhb.add_child(s_btn)

		var l_btn := _make_btn("LoadBtn_" + sid, false)
		l_btn.text = "Muat" if is_id else "Load"
		l_btn.disabled = not exists
		var target_load := sid
		l_btn.pressed.connect(func() -> void: load_slot(target_load))
		bhb.add_child(l_btn)

		if sid != "autosave" and exists:
			var d_btn := _make_btn("DeleteBtn_" + sid, false)
			d_btn.text = "Hapus" if is_id else "Delete"
			var target_del := sid
			d_btn.pressed.connect(func() -> void:
				SaveAndSettingsService.delete_campaign_slot(target_del)
				refresh_view()
			)
			bhb.add_child(d_btn)

	_btn_export_backup.text = LocaleService.tr_fmt("settings.data.export") if LocaleService != null else ("Ekspor Cadangan" if is_id else "Export Backup")
	_btn_import_backup.text = LocaleService.tr_fmt("settings.data.import") if LocaleService != null else ("Impor Cadangan" if is_id else "Import Backup")

	# (c) & (d) Achievements & Tutorial
	var ach_unlocked := AchievementService.unlocked_ids.size() if AchievementService != null else 0
	var ach_total := ContentDB.catalog.achievements.size() if (ContentDB != null and ContentDB.catalog != null) else 59
	_btn_open_achievements.text = "🏆 %s (%d/%d)" % [
		(LocaleService.tr_fmt("title.achievements") if LocaleService != null else ("Pencapaian" if is_id else "Achievements")),
		ach_unlocked,
		ach_total,
	]
	_btn_open_tutorial.text = "📖 %s" % (LocaleService.tr_fmt("title.tutorial") if LocaleService != null else ("Panduan Tutorial" if is_id else "Tutorial Guide"))

	# (e) Settings
	_btn_lang_id.theme_type_variation = &"AccentButton" if is_id else &""
	_btn_lang_en.theme_type_variation = &"AccentButton" if not is_id else &""

	var is_dark := ThemeManager == null or ThemeManager.is_dark()
	_btn_theme_dark.text = "Midnight Slate (Gelap)" if is_id else "Midnight Slate (Dark)"
	_btn_theme_light.text = "Editorial Paper (Terang)" if is_id else "Editorial Paper (Light)"
	_btn_theme_dark.theme_type_variation = &"AccentButton" if is_dark else &""
	_btn_theme_light.theme_type_variation = &"AccentButton" if not is_dark else &""

	var pct := int(roundf(s.text_scale * 100.0))
	_scale_label.text = ("Skala Teks: %d%% (85%%–140%%)" % pct) if is_id else ("Text Scale: %d%% (85%%–140%%)" % pct)
	_scale_slider.value = s.text_scale

	_chk_exact_numbers.text = "Tampilkan Angka Eksak (0–100 & Delta)" if is_id else "Show Exact Numbers (0–100 & Deltas)"
	_chk_exact_numbers.button_pressed = s.show_exact_numbers

	_chk_auto_advance.text = LocaleService.tr_fmt("settings.gameplay.auto_advance") if LocaleService != null else ("Otomatis Lanjut Giliran" if is_id else "Auto-Advance Turn")
	_chk_auto_advance.button_pressed = s.auto_advance_turn

	_chk_music_enable.text = "%s (%d%%)" % [
		(LocaleService.tr_fmt("settings.audio.music") if LocaleService != null else "Musik"),
		int(roundf(s.music_volume * 100.0)),
	]
	_chk_music_enable.button_pressed = s.music_enabled
	_music_vol_slider.value = s.music_volume

	_chk_sfx_enable.text = "%s (%d%%)" % [
		(LocaleService.tr_fmt("settings.audio.sfx") if LocaleService != null else "SFX"),
		int(roundf(s.sfx_volume * 100.0)),
	]
	_chk_sfx_enable.button_pressed = s.sfx_enabled
	_sfx_vol_slider.value = s.sfx_volume

	_btn_return_title.text = LocaleService.tr_fmt("startmenu.return_to_title") if LocaleService != null else ("Kembali ke Menu Utama" if is_id else "Return to Title")
	_syncing_ui = false
