class_name ElectionAndEpilogueScreen
extends Control

signal election_completed(summary: Dictionary)
signal dossier_exported(output_path: String)

const TITLE_SCENE_PATH := "res://godot/scenes/title_screen.tscn"
const SPEED_OPTIONS: Array[int] = [1, 2, 5, 10]
const TOTAL_CHAMBER_SLOTS := 700
const PLENARY_SPAN_MINUTES := 263.0 # 19 Oct 20:30 -> 20 Oct 00:53

const COLOR_UNCOUNTED := Color(0.153, 0.204, 0.267, 1.0)
const COLOR_FOR := Color(0.133, 0.773, 0.369, 1.0)
const COLOR_AGAINST := Color(0.937, 0.267, 0.267, 1.0)
const COLOR_BLANK := Color(0.580, 0.639, 0.722, 1.0)
const COLOR_VACATED := Color(0.42, 0.48, 0.56, 0.25)

var shell: SafeAreaShell = null
var allow_scene_change: bool = true

var _header_title_label: Label = null
var _clock_and_tally_label: Label = null
var _hemicycle: HemicycleCanvas = null

# Sub-views
var _roll_call_scroll: ScrollContainer = null
var _roll_call_rtl: RichTextLabel = null

var _post_scroll: ScrollContainer = null
var _verdict_vbox: VBoxContainer = null
var _verdict_banner_rtl: RichTextLabel = null
var _caucus_table_rtl: RichTextLabel = null
var _tap_mpr_rtl: RichTextLabel = null

var _dossier_vbox: VBoxContainer = null
var _dossier_rtl: RichTextLabel = null
var _dossier_status_label: Label = null

var _epilogue_scroll: ScrollContainer = null
var _epilogue_vbox: VBoxContainer = null
var _epilogue_photo: TextureRect = null
var _epilogue_rtl: RichTextLabel = null

# Bottom thumb-zone bars
var _tally_controls_bar: HBoxContainer = null
var _speed_buttons: Array[Button] = []
var _btn_skip_tally: Button = null

var _post_nav_bar: HBoxContainer = null
var _btn_nav_verdict: Button = null
var _btn_nav_dossier: Button = null
var _btn_export_png: Button = null
var _btn_open_epilogue: Button = null

var _epilogue_nav_bar: HBoxContainer = null
var _btn_epi_back: Button = null
var _btn_epi_title: Button = null

# State
var _summary: Dictionary = {}
var _ballot_sequence: Array[int] = [] # 1=FOR, -1=AGAINST, 0=BLANK, -2=VACATED
var _seat_colors: Array[Color] = []
var _tallied_count: int = 0
var _tally_accum: float = 0.0
var _tally_speed: int = 1
var _roll_call_finished: bool = false
var _active_post_mode: String = "verdict" # "verdict", "dossier", "epilogue"
var _verdict_banner_plain: String = ""
var _tap_mpr_plain: String = ""
var _epilogue_plain: String = ""


func _init() -> void:
	name = "ElectionAndEpilogueScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	shell = SafeAreaShell.new()
	shell.custom_back_handler = _handle_custom_back
	add_child(shell)

	# Top Plenary Header & Hemicycle Card
	var top_card := PanelContainer.new()
	top_card.name = "PlenaryHeaderCard"
	top_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.content_root.add_child(top_card)

	var top_vb := VBoxContainer.new()
	top_vb.add_theme_constant_override("separation", 6)
	top_card.add_child(top_vb)

	_header_title_label = Label.new()
	_header_title_label.theme_type_variation = &"HeaderLabel"
	_header_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_vb.add_child(_header_title_label)

	_clock_and_tally_label = Label.new()
	_clock_and_tally_label.theme_type_variation = &"MutedLabel"
	_clock_and_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_and_tally_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_vb.add_child(_clock_and_tally_label)

	_hemicycle = HemicycleCanvas.new()
	_hemicycle.custom_minimum_size = Vector2(280.0, 168.0)
	top_vb.add_child(_hemicycle)

	# Middle Expandable Body Area
	_roll_call_scroll = ScrollContainer.new()
	_roll_call_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_call_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roll_call_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.content_root.add_child(_roll_call_scroll)

	var rc_card := PanelContainer.new()
	rc_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_call_scroll.add_child(rc_card)

	_roll_call_rtl = RichTextLabel.new()
	_roll_call_rtl.bbcode_enabled = true
	_roll_call_rtl.fit_content = true
	_roll_call_rtl.scroll_active = false
	_roll_call_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc_card.add_child(_roll_call_rtl)

	_post_scroll = ScrollContainer.new()
	_post_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_post_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_post_scroll.visible = false
	shell.content_root.add_child(_post_scroll)

	var post_host := VBoxContainer.new()
	post_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_host.add_theme_constant_override("separation", 10)
	_post_scroll.add_child(post_host)

	# Verdict + TAP MPR View
	_verdict_vbox = VBoxContainer.new()
	_verdict_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_verdict_vbox.add_theme_constant_override("separation", 10)
	post_host.add_child(_verdict_vbox)

	var v_card := PanelContainer.new()
	v_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_verdict_vbox.add_child(v_card)
	_verdict_banner_rtl = _make_rtl()
	v_card.add_child(_verdict_banner_rtl)

	var c_card := PanelContainer.new()
	c_card.theme_type_variation = &"SurfaceAltCard"
	c_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_verdict_vbox.add_child(c_card)
	_caucus_table_rtl = _make_rtl()
	c_card.add_child(_caucus_table_rtl)

	var tap_card := PanelContainer.new()
	tap_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_verdict_vbox.add_child(tap_card)
	_tap_mpr_rtl = _make_rtl()
	tap_card.add_child(_tap_mpr_rtl)

	# State of the Republic Dossier View
	_dossier_vbox = VBoxContainer.new()
	_dossier_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_vbox.add_theme_constant_override("separation", 10)
	_dossier_vbox.visible = false
	post_host.add_child(_dossier_vbox)

	var dos_card := PanelContainer.new()
	dos_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_vbox.add_child(dos_card)
	_dossier_rtl = _make_rtl()
	dos_card.add_child(_dossier_rtl)

	_dossier_status_label = Label.new()
	_dossier_status_label.theme_type_variation = &"MutedLabel"
	_dossier_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dossier_vbox.add_child(_dossier_status_label)

	# Epilogue View
	_epilogue_scroll = ScrollContainer.new()
	_epilogue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epilogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_epilogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_epilogue_scroll.visible = false
	shell.content_root.add_child(_epilogue_scroll)

	var epi_card := PanelContainer.new()
	epi_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epilogue_scroll.add_child(epi_card)

	_epilogue_vbox = VBoxContainer.new()
	_epilogue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epilogue_vbox.add_theme_constant_override("separation", 10)
	epi_card.add_child(_epilogue_vbox)

	_epilogue_photo = TextureRect.new()
	_epilogue_photo.custom_minimum_size = Vector2(0.0, 168.0)
	_epilogue_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epilogue_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_epilogue_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://photo/epilogue/epilogue_end.png"):
		_epilogue_photo.texture = ResourceLoader.load("res://photo/epilogue/epilogue_end.png") as Texture2D
	_epilogue_vbox.add_child(_epilogue_photo)

	_epilogue_rtl = _make_rtl()
	_epilogue_vbox.add_child(_epilogue_rtl)

	# Bottom Thumb-Zone Bar A: Roll Call Speed Controls (1x, 2x, 5x, 10x, Skip)
	_tally_controls_bar = HBoxContainer.new()
	_tally_controls_bar.name = "TallySpeedControlsBar"
	_tally_controls_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tally_controls_bar.add_theme_constant_override("separation", 6)
	shell.content_root.add_child(_tally_controls_bar)

	for spd in SPEED_OPTIONS:
		var s_btn := _make_bottom_btn("BtnTallySpeed_%dx" % spd, false)
		s_btn.text = "%dx" % spd
		var target_spd := spd
		s_btn.pressed.connect(func() -> void: set_tally_speed(target_spd))
		_tally_controls_bar.add_child(s_btn)
		_speed_buttons.append(s_btn)

	_btn_skip_tally = _make_bottom_btn("BtnSkipRollCall", true)
	_btn_skip_tally.pressed.connect(skip_roll_call)
	_tally_controls_bar.add_child(_btn_skip_tally)

	# Bottom Thumb-Zone Bar B: Post-Verdict Navigation
	_post_nav_bar = HBoxContainer.new()
	_post_nav_bar.name = "PostVerdictNavBar"
	_post_nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_post_nav_bar.add_theme_constant_override("separation", 6)
	_post_nav_bar.visible = false
	shell.content_root.add_child(_post_nav_bar)

	_btn_nav_verdict = _make_bottom_btn("BtnShowVerdict", true)
	_btn_nav_verdict.pressed.connect(show_verdict_view)
	_post_nav_bar.add_child(_btn_nav_verdict)

	_btn_nav_dossier = _make_bottom_btn("BtnShowDossier", false)
	_btn_nav_dossier.pressed.connect(show_dossier_view)
	_post_nav_bar.add_child(_btn_nav_dossier)

	_btn_export_png = _make_bottom_btn("BtnExportDossierPNG", false)
	_btn_export_png.pressed.connect(func() -> void: export_dossier_png(""))
	_post_nav_bar.add_child(_btn_export_png)

	_btn_open_epilogue = _make_bottom_btn("BtnOpenEpilogue", true)
	_btn_open_epilogue.pressed.connect(open_epilogue_view)
	_post_nav_bar.add_child(_btn_open_epilogue)

	# Bottom Thumb-Zone Bar C: Epilogue Navigation
	_epilogue_nav_bar = HBoxContainer.new()
	_epilogue_nav_bar.name = "EpilogueNavBar"
	_epilogue_nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_epilogue_nav_bar.add_theme_constant_override("separation", 8)
	_epilogue_nav_bar.visible = false
	shell.content_root.add_child(_epilogue_nav_bar)

	_btn_epi_back = _make_bottom_btn("BtnEpilogueBackToVerdict", false)
	_btn_epi_back.pressed.connect(show_verdict_view)
	_epilogue_nav_bar.add_child(_btn_epi_back)

	_btn_epi_title = _make_bottom_btn("BtnEpilogueReturnTitle", true)
	_btn_epi_title.pressed.connect(_return_to_title)
	_epilogue_nav_bar.add_child(_btn_epi_title)


static func _make_rtl() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rtl


static func _make_bottom_btn(node_name: String, accent: bool) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0.0, 50.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	if accent:
		btn.theme_type_variation = &"AccentButton"
	return btn


func _ready() -> void:
	if shell != null:
		shell.allow_quit_execution = allow_scene_change
	if SaveAndSettingsService != null and SaveAndSettingsService.settings != null:
		var def_spd := SaveAndSettingsService.settings.default_tally_speed
		if SPEED_OPTIONS.has(def_spd):
			_tally_speed = def_spd
	if LocaleService != null:
		LocaleService.locale_changed.connect(func(_l: String) -> void: _refresh_labels_and_documents())
	if ThemeManager != null:
		ThemeManager.theme_updated.connect(_refresh_labels_and_documents)

	start_roll_call()


func _process(delta: float) -> void:
	if _roll_call_finished or _ballot_sequence.is_empty():
		return
	var seats_per_sec := 18.0 * float(_tally_speed)
	_tally_accum += delta * seats_per_sec
	var steps := int(floor(_tally_accum))
	if steps <= 0:
		return
	_tally_accum -= float(steps)
	_advance_tally_by(steps)


func _handle_custom_back() -> bool:
	if _active_post_mode == "epilogue":
		show_verdict_view()
		return true
	if _active_post_mode == "dossier":
		show_verdict_view()
		return true
	return false


func get_tally_control_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for sb in _speed_buttons:
		out.append(sb)
	out.append(_btn_skip_tally)
	return out


func set_tally_speed(speed_mult: int) -> void:
	if SPEED_OPTIONS.has(speed_mult):
		_tally_speed = speed_mult
	else:
		_tally_speed = maxi(1, speed_mult)
	for i in range(SPEED_OPTIONS.size()):
		_speed_buttons[i].theme_type_variation = &"AccentButton" if SPEED_OPTIONS[i] == _tally_speed else &""


func get_tally_speed() -> int:
	return _tally_speed


func is_roll_call_finished() -> bool:
	return _roll_call_finished


func get_tallied_seat_count() -> int:
	return _tallied_count


func get_verdict_banner_text() -> String:
	return _verdict_banner_plain


func get_tap_mpr_document_text() -> String:
	return _tap_mpr_plain


func is_epilogue_open() -> bool:
	return _roll_call_finished and _active_post_mode == "epilogue" and _epilogue_scroll.visible


func get_epilogue_text() -> String:
	return _epilogue_plain


func start_roll_call() -> void:
	var summary_data: Dictionary = {}
	if ElectionManager != null:
		var r := CampaignManager.rng if CampaignManager != null else null
		summary_data = ElectionManager.compute_election_roll_call(r)
	else:
		summary_data = {
			"accepted": true,
			"quorum_failed": false,
			"total_for": 355,
			"total_against": 322,
			"total_blank": 23,
			"chamber_seats": 700,
			"original_chamber_seats": 700,
			"factions": [],
		}
	_setup_sequence_from_summary(summary_data, false)


func apply_election_summary(custom_summary: Dictionary) -> void:
	_setup_sequence_from_summary(custom_summary, true)


func _setup_sequence_from_summary(summary_data: Dictionary, finish_immediately: bool) -> void:
	_summary = summary_data.duplicate(true)
	_ballot_sequence.clear()
	_seat_colors.clear()
	_tallied_count = 0
	_tally_accum = 0.0
	_roll_call_finished = false
	_active_post_mode = "verdict"

	var f_rows: Array = _summary.get("factions", [])
	if not f_rows.is_empty():
		for raw_f in f_rows:
			var f: Dictionary = raw_f as Dictionary
			for _i in range(int(f.get("votes_for", 0))):
				_ballot_sequence.append(1)
			for _i in range(int(f.get("votes_against", 0))):
				_ballot_sequence.append(-1)
			for _i in range(int(f.get("blank_votes", 0))):
				_ballot_sequence.append(0)
	else:
		for _i in range(int(_summary.get("total_for", 0))):
			_ballot_sequence.append(1)
		for _i in range(int(_summary.get("total_against", 0))):
			_ballot_sequence.append(-1)
		for _i in range(int(_summary.get("total_blank", 0))):
			_ballot_sequence.append(0)

	var orig_total := maxi(TOTAL_CHAMBER_SLOTS, int(_summary.get("original_chamber_seats", TOTAL_CHAMBER_SLOTS)))
	while _ballot_sequence.size() < orig_total:
		_ballot_sequence.append(-2)

	for code in _ballot_sequence:
		_seat_colors.append(COLOR_VACATED if code == -2 else COLOR_UNCOUNTED)

	_hemicycle.set_seats_data(_seat_colors, true)
	set_tally_speed(_tally_speed)
	_sync_mode_visibility()
	_refresh_labels_and_documents()

	if finish_immediately:
		skip_roll_call()


func skip_roll_call() -> void:
	if _roll_call_finished:
		return
	var rem := _ballot_sequence.size() - _tallied_count
	if rem > 0:
		_advance_tally_by(rem)
	else:
		_finalize_roll_call()


func _advance_tally_by(steps: int) -> void:
	var target := mini(_ballot_sequence.size(), _tallied_count + steps)
	while _tallied_count < target:
		var code := _ballot_sequence[_tallied_count]
		match code:
			1:
				_seat_colors[_tallied_count] = COLOR_FOR
			-1:
				_seat_colors[_tallied_count] = COLOR_AGAINST
			0:
				_seat_colors[_tallied_count] = COLOR_BLANK
			_:
				_seat_colors[_tallied_count] = COLOR_VACATED
		_tallied_count += 1

	_hemicycle.set_seats_data(_seat_colors, true)
	_update_live_clock_and_tally()

	if _tallied_count >= _ballot_sequence.size():
		_finalize_roll_call()


func _finalize_roll_call() -> void:
	_roll_call_finished = true
	if AchievementService != null:
		AchievementService.evaluate_election_end(_summary)
	if SaveAndSettingsService != null:
		if AchievementService != null:
			SaveAndSettingsService.settings.unlocked_achievements = AchievementService.unlocked_ids.duplicate()
			SaveAndSettingsService.settings.difficulty_wins = AchievementService.difficulty_wins.duplicate()
		SaveAndSettingsService.save_settings()
	_active_post_mode = "verdict"
	_sync_mode_visibility()
	_refresh_labels_and_documents()
	election_completed.emit(_summary)


func show_verdict_view() -> void:
	_active_post_mode = "verdict"
	_sync_mode_visibility()


func show_dossier_view() -> void:
	_active_post_mode = "dossier"
	_sync_mode_visibility()


func open_epilogue_view() -> void:
	_active_post_mode = "epilogue"
	_sync_mode_visibility()


func _sync_mode_visibility() -> void:
	_roll_call_scroll.visible = not _roll_call_finished
	_tally_controls_bar.visible = not _roll_call_finished

	var in_epi := _roll_call_finished and _active_post_mode == "epilogue"
	_post_scroll.visible = _roll_call_finished and not in_epi
	_verdict_vbox.visible = _roll_call_finished and _active_post_mode == "verdict"
	_dossier_vbox.visible = _roll_call_finished and _active_post_mode == "dossier"
	_post_nav_bar.visible = _roll_call_finished and not in_epi

	_epilogue_scroll.visible = in_epi
	_epilogue_nav_bar.visible = in_epi

	_btn_nav_verdict.theme_type_variation = &"AccentButton" if _active_post_mode == "verdict" else &""
	_btn_nav_dossier.theme_type_variation = &"AccentButton" if _active_post_mode == "dossier" else &""


func _update_live_clock_and_tally() -> void:
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var total := maxi(1, _ballot_sequence.size())
	var frac := clampf(float(_tallied_count) / float(total), 0.0, 1.0)
	var elapsed_min := int(roundf(frac * PLENARY_SPAN_MINUTES))

	# Start: 19 Oct 20:30 (1230 min from midnight)
	var abs_min := 20 * 60 + 30 + elapsed_min
	var day_num := 19 + int(abs_min / 1440)
	var day_min := abs_min % 1440
	var hh := int(day_min / 60)
	var mm := day_min % 60
	var clock_str := "%d Okt 1999 • %02d:%02d WIB" % [day_num, hh, mm] if is_id else "Oct %d, 1999 • %02d:%02d" % [day_num, hh, mm]

	var c_for := 0
	var c_against := 0
	var c_blank := 0
	for i in range(_tallied_count):
		match _ballot_sequence[i]:
			1:
				c_for += 1
			-1:
				c_against += 1
			0:
				c_blank += 1

	var lbl_for := LocaleService.tr_fmt("republic.label_for") if LocaleService != null else ("TERIMA" if is_id else "ACCEPT")
	var lbl_ag := LocaleService.tr_fmt("republic.label_against") if LocaleService != null else ("TOLAK" if is_id else "REJECT")
	var lbl_bl := LocaleService.tr_fmt("republic.label_blank") if LocaleService != null else "ABSTAIN"

	_clock_and_tally_label.text = "%s   |   %s: %d  •  %s: %d  •  %s: %d  (Kuorum: 351)" % [
		clock_str,
		lbl_for,
		c_for,
		lbl_ag,
		c_against,
		lbl_bl,
		c_blank,
	]

	_roll_call_rtl.text = (
		"[center][b]Penghitungan Suara Paripurna Sedang Berlangsung (%d / %d)[/b]\nMayoritas Konstitusional: 351 Suara[/center]"
		% [_tallied_count, _ballot_sequence.size()]
		if is_id
		else "[center][b]Plenary Roll-Call Tally in Progress (%d / %d)[/b]\nConstitutional Majority: 351 Votes[/center]"
		% [_tallied_count, _ballot_sequence.size()]
	)


func _refresh_labels_and_documents() -> void:
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	_header_title_label.text = LocaleService.tr_fmt("election.plenary_title") if LocaleService != null else "Rapat Paripurna ke-12 Sidang Umum MPR 1999"
	_btn_skip_tally.text = "Lewati" if is_id else "Skip"
	_btn_nav_verdict.text = "TAP MPR" if is_id else "Verdict"
	_btn_nav_dossier.text = "Dossier"
	_btn_export_png.text = "PNG"
	_btn_open_epilogue.text = LocaleService.tr_fmt("epilogue.title") if LocaleService != null else "Epilog"
	_btn_epi_back.text = LocaleService.tr_fmt("epilogue.btn_back") if LocaleService != null else ("Tinjau Putusan" if is_id else "Review Verdict")
	_btn_epi_title.text = LocaleService.tr_fmt("epilogue.btn_title") if LocaleService != null else ("Menu Utama" if is_id else "Main Menu")

	_update_live_clock_and_tally()
	_populate_verdict_and_tap(is_id)
	_populate_dossier_text(is_id)
	_populate_epilogue_text(is_id)


func _populate_verdict_and_tap(is_id: bool) -> void:
	var accepted := bool(_summary.get("accepted", false))
	var quorum_failed := bool(_summary.get("quorum_failed", false))
	var v_for := int(_summary.get("total_for", 0))
	var v_ag := int(_summary.get("total_against", 0))
	var v_bl := int(_summary.get("total_blank", 0))

	var verdict_word := LocaleService.tr_fmt("election.verdict_accepted" if accepted else "election.verdict_rejected") if LocaleService != null else ("DITERIMA" if accepted else "DITOLAK")
	var diff_margin := v_for - v_ag
	var tier_prefix := ""
	if accepted:
		if diff_margin >= 90:
			tier_prefix = "election.win_overwhelming"
		elif diff_margin >= 35:
			tier_prefix = "election.win_comfortable"
		else:
			tier_prefix = "election.win_narrow"
	else:
		if diff_margin >= -25:
			tier_prefix = "election.lose_narrow"
		elif diff_margin >= -95:
			tier_prefix = "election.lose_decisive"
		else:
			tier_prefix = "election.lose_overwhelming"

	var t_title := LocaleService.tr_fmt(tier_prefix + ".title") if LocaleService != null else verdict_word
	var t_desc := LocaleService.tr_fmt(tier_prefix + ".desc") if LocaleService != null else ""

	var quorum_line := ""
	if quorum_failed:
		var q_msg := LocaleService.tr_fmt("election.quorum_failure", {"VOTES": str(v_for)}) if LocaleService != null else ("Ambang batas kuorum 351 tidak terpenuhi (%d suara)." % v_for)
		quorum_line = "\n⚠ %s (Kuorum Konstitusional: 351 / 700)" % q_msg

	_verdict_banner_plain = "%s — %s (%d – %d • Abstain %d)%s\n%s" % [
		verdict_word,
		t_title,
		v_for,
		v_ag,
		v_bl,
		quorum_line,
		t_desc,
	]
	_verdict_banner_rtl.text = "[b]%s — %s (%d – %d • Abstain %d)[/b]%s\n\n%s" % [
		verdict_word,
		t_title,
		v_for,
		v_ag,
		v_bl,
		quorum_line,
		t_desc,
	]

	# Caucus breakdown
	var c_lines: PackedStringArray = PackedStringArray()
	c_lines.append("[b]%s[/b]" % ("Rincian Suara Fraksi MPR" if is_id else "MPR Caucus Vote Breakdown"))
	var f_rows: Array = _summary.get("factions", [])
	for raw_f in f_rows:
		var f: Dictionary = raw_f as Dictionary
		var fn := LocaleService.tr_fmt(String(f.get("name_key", f.get("id", "")))) if LocaleService != null else String(f.get("id", ""))
		c_lines.append("• %s (%d): [b]%d[/b] Terima / [b]%d[/b] Tolak / %d Abstain" % [
			fn,
			int(f.get("seats", 0)),
			int(f.get("votes_for", 0)),
			int(f.get("votes_against", 0)),
			int(f.get("blank_votes", 0)),
		])
	_caucus_table_rtl.text = "\n".join(c_lines)

	# Official TAP MPR No. III/MPR/1999
	var tap_title := _tr("tap.decree_title", "KETETAPAN MAJELIS PERMUSYAWARATAN RAKYAT REPUBLIK INDONESIA\nNOMOR III/MPR/1999")
	var tap_grace := _tr("tap.grace", "DENGAN RAHMAT TUHAN YANG MAHA ESA")
	var tap_conc := _tr("tap.concerning", "TENTANG PERTANGGUNGJAWABAN PRESIDEN REPUBLIK INDONESIA")
	var tap_cons_h := _tr("tap.considering_heading", "Menimbang:")
	var tap_ca := _tr("tap.considering.a", "")
	var tap_cb := _tr("tap.considering.b", "")
	var tap_cc := _tr("tap.considering.c", "")
	var tap_cd := _tr("tap.considering.d", "")
	var tap_obs := LocaleService.tr_fmt("tap.observed", {"FOR": str(v_for), "AGAINST": str(v_ag), "VERDICT": verdict_word}) if LocaleService != null else ""
	var tap_dec := _tr("tap.decides", "MEMUTUSKAN")
	var tap_to_enact := _tr("tap.to_enact", "")
	var tap_a1h := _tr("tap.article1_heading", "Pasal 1")
	var tap_a1 := LocaleService.tr_fmt("tap.article1", {"VERDICT": verdict_word}) if LocaleService != null else verdict_word
	var tap_a2h := _tr("tap.article2_heading", "Pasal 2")
	var tap_a2 := _tr("tap.article2", "")
	var tap_enacted := _tr("tap.enacted", "Ditetapkan di Jakarta pada tanggal 19 Oktober 1999")
	var tap_chair := _tr("tap.chairman", "KETUA MPR RI,")
	var tap_chair_name := _tr("tap.chairman_name", "Prof. Dr. H. M. Amien Rais, M.A.")
	var tap_vc_lbl := _tr("tap.vice_chairmen_label", "WAKIL KETUA:")
	var tap_vc := _tr("tap.vice_chairmen", "")

	var tap_doc := "[center][b]%s[/b]\n\n%s\n\n%s[/center]\n\n[b]%s[/b]\na. %s\nb. %s\nc. %s\nd. %s\n\n%s\n\n[center][b]%s[/b][/center]\n%s\n\n[b]%s[/b]\n%s\n\n[b]%s[/b]\n%s\n\n%s\n%s\n[b]%s[/b]\n\n%s %s" % [
		tap_title, tap_grace, tap_conc, tap_cons_h, tap_ca, tap_cb, tap_cc, tap_cd,
		tap_obs, tap_dec, tap_to_enact, tap_a1h, tap_a1, tap_a2h, tap_a2,
		tap_enacted, tap_chair, tap_chair_name, tap_vc_lbl, tap_vc,
	]
	_tap_mpr_plain = tap_doc
	_tap_mpr_rtl.text = tap_doc


func _populate_dossier_text(is_id: bool) -> void:
	var accepted := bool(_summary.get("accepted", false))
	var v_for := int(_summary.get("total_for", 0))
	var v_ag := int(_summary.get("total_against", 0))
	var v_bl := int(_summary.get("total_blank", 0))
	var verdict_word := "DITERIMA" if accepted else "DITOLAK"
	var diff_id := CampaignManager.selected_difficulty if CampaignManager != null else "historical"
	var final_pc := CampaignManager.pc if CampaignManager != null else 0

	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]%s[/b]" % _tr("republic.title", "KEADAAN REPUBLIK"))
	lines.append("%s %s" % [_tr("republic.dossier.administration_label", "PEMERINTAHAN:"), _tr("republic.dossier.administration_value", "Pres. B.J. Habibie (1998–1999)")])
	lines.append("%s %s   •   PC Akhir: %d" % [_tr("republic.dossier.difficulty_label", "KESULITAN:"), diff_id.to_upper(), final_pc])
	lines.append("%s [b]%s[/b] (%d Terima – %d Tolak – %d Abstain)" % [_tr("republic.dossier.verdict_label", "PUTUSAN MPR:"), verdict_word, v_for, v_ag, v_bl])
	lines.append("")
	lines.append("[b]%s[/b]" % _tr("republic.dossier.pillars_heading", "Tujuh Pilar Negara"))
	if CampaignManager != null:
		for sk in ["pop", "econ", "stab", "ref", "intl", "mil", "cendana"]:
			var sv := int(CampaignManager.stats.get(sk, 50))
			var slbl := _tr("effect_name." + sk, sk.capitalize())
			lines.append("• %s: [b]%d / 100[/b]" % [slbl, sv])

	lines.append("")
	var gaz_cnt := CampaignManager.gazette_history.size() if CampaignManager != null else 0
	lines.append("[b]%s (%d)[/b]" % [_tr("republic.dossier.gazette_heading", "Lembaran Negara"), gaz_cnt])
	if CampaignManager != null and not CampaignManager.gazette_history.is_empty():
		for g in CampaignManager.gazette_history:
			lines.append("• %s" % _tr(String(g.get("text_key", "")), String(g.get("id", ""))))
	else:
		lines.append(_tr("republic.no_decrees", "Tidak ada dekrit luar biasa."))

	var ach_cnt := AchievementService.unlocked_ids.size() if AchievementService != null else 0
	var ach_tot := ContentDB.catalog.achievements.size() if (ContentDB != null and ContentDB.catalog != null) else 59
	lines.append("")
	lines.append("[b]Pencapaian Terbuka: %d / %d[/b]" % [ach_cnt, ach_tot] if is_id else "[b]Achievements Unlocked: %d / %d[/b]" % [ach_cnt, ach_tot])
	_dossier_rtl.text = "\n".join(lines)


func _populate_epilogue_text(_is_id: bool) -> void:
	var accepted := bool(_summary.get("accepted", false))
	var paras: PackedStringArray = PackedStringArray()
	paras.append("[center][b]%s[/b][/center]" % _tr("epilogue.title", "EPILOG"))
	paras.append(_tr("epilogue.intro_common", ""))
	paras.append(_tr("epilogue.intro_won" if accepted else "epilogue.intro_lost", ""))
	for i in range(1, 9):
		var p_txt := _tr("epilogue.end.p%d" % i, "")
		if not p_txt.is_empty():
			paras.append(p_txt)
	paras.append("[center][i]%s[/i]\n[b]%s[/b][/center]" % [_tr("epilogue.end.caption", "Jakarta, 1999–2026"), _tr("epilogue.closing", "")])
	_epilogue_plain = "\n\n".join(paras)
	_epilogue_rtl.text = _epilogue_plain


func export_dossier_png(output_path: String = "") -> Error:
	var target_path := output_path.strip_edges()
	if target_path.is_empty():
		var docs_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if not docs_dir.is_empty() and DirAccess.dir_exists_absolute(docs_dir):
			target_path = docs_dir.path_join("keadaan-republik-1999.png")
		else:
			target_path = "user://exports/keadaan-republik-1999.png"

	var abs_target := ProjectSettings.globalize_path(target_path) if target_path.begins_with("user://") else target_path
	var parent_dir := abs_target.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var img: Image = null
	var is_dummy_renderer := (
		DisplayServer.get_name() == "headless"
		or RenderingServer.get_current_rendering_driver_name().to_lower() == "dummy"
	)

	if not is_dummy_renderer and is_inside_tree():
		img = await _capture_subviewport_dossier_image()

	if img == null or img.get_width() != 1080:
		img = _rasterize_dossier_image_cpu()

	var err := img.save_png(abs_target)
	if err == OK:
		if _dossier_status_label != null:
			_dossier_status_label.text = "PNG tersimpan (1080px): " + target_path
		dossier_exported.emit(target_path)
	return err


func _capture_subviewport_dossier_image() -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 1520)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color.html("#0F1419")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	vp.add_child(margin)

	var card := PanelContainer.new()
	margin.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	var hemi := HemicycleCanvas.new()
	hemi.custom_minimum_size = Vector2(940.0, 440.0)
	hemi.set_seats_data(_seat_colors, true)
	vb.add_child(hemi)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 24)
	rtl.add_theme_font_size_override("bold_font_size", 26)
	rtl.text = _dossier_rtl.text
	vb.add_child(rtl)

	add_child(vp)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var captured: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	return captured


func _rasterize_dossier_image_cpu() -> Image:
	const W := 1080
	const H := 1520
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.059, 0.078, 0.098, 1.0))

	# Fast horizontal-band slate gradient
	for band in range(38):
		var by := band * 40
		var grad := float(band) / 37.0
		img.fill_rect(
			Rect2i(0, by, W, 40),
			Color(lerpf(0.058, 0.088, grad), lerpf(0.078, 0.118, grad), lerpf(0.098, 0.148, grad), 1.0)
		)

	# Outer card frame & gold editorial header rule
	var c_surface := Color(0.094, 0.125, 0.157, 1.0)
	var c_accent := Color(0.898, 0.663, 0.235, 1.0)
	var c_border := Color(0.149, 0.196, 0.247, 1.0)
	img.fill_rect(Rect2i(40, 40, W - 80, H - 80), c_surface)
	img.fill_rect(Rect2i(40, 40, W - 80, 10), c_accent)

	# Subtle historical MPR hall banner backdrop strip inside header
	if ResourceLoader.exists("res://photo/epilogue/epilogue_end.png"):
		var bg_tex := ResourceLoader.load("res://photo/epilogue/epilogue_end.png") as Texture2D
		if bg_tex != null:
			var bg_img := bg_tex.get_image()
			if bg_img != null:
				var bg_copy := bg_img.duplicate() as Image
				bg_copy.convert(Image.FORMAT_RGBA8)
				bg_copy.resize(W - 88, 200, Image.INTERPOLATE_BILINEAR)
				img.blend_rect(bg_copy, Rect2i(0, 0, W - 88, 200), Vector2i(44, 54))
				img.fill_rect(Rect2i(44, 54, W - 88, 200), Color(0.094, 0.125, 0.157, 0.72))
				img.blend_rect(bg_copy, Rect2i(0, 0, W - 88, 4), Vector2i(44, 250))

	# Blit presidential portrait emblem if available
	if ResourceLoader.exists("res://photo/habibi.png"):
		var p_tex := ResourceLoader.load("res://photo/habibi.png") as Texture2D
		if p_tex != null:
			var p_img := p_tex.get_image()
			if p_img != null:
				var p_copy := p_img.duplicate() as Image
				p_copy.convert(Image.FORMAT_RGBA8)
				p_copy.resize(160, 160, Image.INTERPOLATE_BILINEAR)
				img.blend_rect(p_copy, Rect2i(0, 0, 160, 160), Vector2i(76, 76))

	# Verdict banner strip
	var accepted := bool(_summary.get("accepted", false))
	var verdict_col := COLOR_FOR if accepted else COLOR_AGAINST
	img.fill_rect(Rect2i(260, 96, 744, 68), verdict_col.darkened(0.45))
	img.fill_rect(Rect2i(260, 96, 10, 68), verdict_col)

	# Vote tally bar (FOR vs AGAINST vs BLANK)
	var v_for := int(_summary.get("total_for", 0))
	var v_ag := int(_summary.get("total_against", 0))
	var v_tot := maxi(1, int(_summary.get("original_chamber_seats", 700)))
	var bar_w := 744
	var w_for := clampi(int(roundf((float(v_for) / float(v_tot)) * float(bar_w))), 0, bar_w)
	var w_ag := clampi(int(roundf((float(v_ag) / float(v_tot)) * float(bar_w))), 0, bar_w - w_for)
	img.fill_rect(Rect2i(260, 184, bar_w, 34), c_border)
	if w_for > 0:
		img.fill_rect(Rect2i(260, 184, w_for, 34), COLOR_FOR)
	if w_ag > 0:
		img.fill_rect(Rect2i(260 + w_for, 184, w_ag, 34), COLOR_AGAINST)
	# 351 quorum marker tick
	var q_x := 260 + int(roundf((351.0 / 700.0) * float(bar_w)))
	img.fill_rect(Rect2i(q_x - 2, 178, 4, 46), c_accent)

	# 700-seat MPR Hemicycle Plot (y = 260..730)
	var layout := ElectionManager.generate_hemicycle_layout(_seat_colors.size()) if ElectionManager != null else []
	var hemi_x := 90.0
	var hemi_y := 270.0
	var hemi_w := 900.0
	var hemi_h := 460.0
	for i in range(mini(layout.size(), _seat_colors.size())):
		var pt: Dictionary = layout[i]
		var cx := int(roundf(hemi_x + (float(pt.get("x", 50.0)) / 100.0) * hemi_w))
		var cy := int(roundf(hemi_y + (float(pt.get("y", 92.0)) / 96.0) * hemi_h))
		_draw_disc_on_image(img, cx, cy, 5, _seat_colors[i])

	# Seven National Pillar Bars (y = 770..1360)
	var stat_keys := ["pop", "econ", "stab", "ref", "intl", "mil", "cendana"]
	for idx in range(stat_keys.size()):
		var sk: String = stat_keys[idx]
		var sv := int(CampaignManager.stats.get(sk, 50)) if CampaignManager != null else 50
		var row_y := 780 + idx * 80
		img.fill_rect(Rect2i(90, row_y, 900, 52), Color.html("#1F2A35"))
		var fill_w := clampi(int(roundf((float(sv) / 100.0) * 892.0)), 4, 892)
		var bar_col := (COLOR_AGAINST if sv >= 60 else COLOR_FOR) if sk == "cendana" else (COLOR_FOR if sv >= 50 else c_accent)
		img.fill_rect(Rect2i(94, row_y + 4, fill_w, 44), bar_col)

	# Golkar Three Pillars Footer Blocks (A, B, G)
	var p_ids := ["a", "b", "g"]
	for pi in range(3):
		var stands := CampaignManager.golkar_pillar_stands(p_ids[pi]) if CampaignManager != null else true
		var px := 90 + pi * 308
		img.fill_rect(Rect2i(px, 1368, 284, 72), c_accent if stands else c_border)

	return img


static func _draw_disc_on_image(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := float(r * r)
	for dy in range(-r - 1, r + 2):
		var py := cy + dy
		if py < 0 or py >= h:
			continue
		for dx in range(-r - 1, r + 2):
			var px := cx + dx
			if px < 0 or px >= w:
				continue
			var d2 := float(dx * dx + dy * dy)
			if d2 <= r2:
				img.set_pixel(px, py, col)
			elif d2 <= float((r + 1) * (r + 1)):
				var bg := img.get_pixel(px, py)
				img.set_pixel(px, py, bg.lerp(col, 0.45))


func _return_to_title() -> void:
	if allow_scene_change and is_inside_tree() and get_tree() != null and ResourceLoader.exists(TITLE_SCENE_PATH):
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


static func _tr(key: String, fallback: String) -> String:
	if Engine.get_main_loop() is SceneTree:
		var loc := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("LocaleService")
		if loc != null and loc.has_method("has_key") and bool(loc.call("has_key", key)):
			return String(loc.call("tr_fmt", key))
	return fallback
