class_name AgendaTabView
extends VBoxContainer

signal election_screen_requested(scene_path: String)

const ELECTION_SCENE_PATH := "res://godot/scenes/election_and_epilogue_screen.tscn"
const ACTION_CATEGORIES: Array[String] = [
	"all",
	"Politics",
	"Economy",
	"Security",
	"Regional Affairs",
	"Civil Society",
]

var _sheet_host: BottomSheetHost = null

# Crisis Phase nodes
var _crisis_root: VBoxContainer = null
var _crisis_narrative_scroll: ScrollContainer = null
var _crisis_date_label: Label = null
var _crisis_title_label: Label = null
var _crisis_photo: TextureRect = null
var _crisis_desc_rtl: RichTextLabel = null
var _crisis_options_scroll: ScrollContainer = null
var _crisis_options_vbox: VBoxContainer = null

# Action Phase nodes
var _action_root: VBoxContainer = null
var _action_scroll: ScrollContainer = null
var _action_cards_vbox: VBoxContainer = null
var _category_filter_scroll: ScrollContainer = null
var _category_filter_hbox: HBoxContainer = null
var _action_submode_bar: HBoxContainer = null
var _btn_sub_routines: Button = null
var _btn_sub_decrees: Button = null
var _btn_sub_factions: Button = null
var _btn_end_turn: Button = null

var _action_submode: String = "routines"
var _category_filter: String = "all"
var _selected_faction_id: String = "golkar_habibie"
var _selected_pillar_id: String = "a"

var _golkar_pillars_widget: PanelContainer = null
var _btn_final_appeal: Button = null
var _btn_horse_trading: Button = null
var _active_horse_sheet: VBoxContainer = null


func _init() -> void:
	name = "AgendaTabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_build_crisis_view()
	_build_action_view()


func _ready() -> void:
	if CampaignManager != null:
		CampaignManager.state_changed.connect(refresh_view)
	if SaveAndSettingsService != null:
		SaveAndSettingsService.settings_changed.connect(refresh_view)
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


func _build_crisis_view() -> void:
	_crisis_root = VBoxContainer.new()
	_crisis_root.name = "CrisisPhaseRoot"
	_crisis_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crisis_root.add_theme_constant_override("separation", 8)
	add_child(_crisis_root)

	# Upper Half: Editorial Crisis Card (16:9 photo + narrative)
	var upper_card := PanelContainer.new()
	upper_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crisis_root.add_child(upper_card)

	_crisis_narrative_scroll = ScrollContainer.new()
	_crisis_narrative_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_narrative_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crisis_narrative_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upper_card.add_child(_crisis_narrative_scroll)

	var nar_vb := VBoxContainer.new()
	nar_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nar_vb.add_theme_constant_override("separation", 8)
	_crisis_narrative_scroll.add_child(nar_vb)

	_crisis_date_label = Label.new()
	_crisis_date_label.theme_type_variation = &"MutedLabel"
	nar_vb.add_child(_crisis_date_label)

	_crisis_title_label = Label.new()
	_crisis_title_label.theme_type_variation = &"HeaderLabel"
	_crisis_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nar_vb.add_child(_crisis_title_label)

	_crisis_photo = TextureRect.new()
	_crisis_photo.custom_minimum_size = Vector2(0.0, 152.0)
	_crisis_photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crisis_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	nar_vb.add_child(_crisis_photo)

	_crisis_desc_rtl = RichTextLabel.new()
	_crisis_desc_rtl.bbcode_enabled = true
	_crisis_desc_rtl.fit_content = true
	_crisis_desc_rtl.scroll_active = false
	_crisis_desc_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nar_vb.add_child(_crisis_desc_rtl)

	# Lower Half Thumb Zone: Crisis Options Deck
	_crisis_options_scroll = ScrollContainer.new()
	_crisis_options_scroll.name = "CrisisOptionsScroll"
	_crisis_options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crisis_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_crisis_root.add_child(_crisis_options_scroll)

	_crisis_options_vbox = VBoxContainer.new()
	_crisis_options_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_options_vbox.add_theme_constant_override("separation", 8)
	_crisis_options_scroll.add_child(_crisis_options_vbox)


func _build_action_view() -> void:
	_action_root = VBoxContainer.new()
	_action_root.name = "ActionPhaseRoot"
	_action_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_root.add_theme_constant_override("separation", 8)
	add_child(_action_root)

	# Top/Middle scrollable action cards — expands to push filter pills & submode bar right above the 5-tab bar!
	_action_scroll = ScrollContainer.new()
	_action_scroll.name = "ActionCardsScroll"
	_action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_root.add_child(_action_scroll)

	_action_cards_vbox = VBoxContainer.new()
	_action_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_cards_vbox.add_theme_constant_override("separation", 8)
	_action_scroll.add_child(_action_cards_vbox)

	# Bottom Zone 1: Category Filter Pills (anchored right above Submode Bar)
	_category_filter_scroll = ScrollContainer.new()
	_category_filter_scroll.name = "ActionCategoryFilterBar"
	_category_filter_scroll.custom_minimum_size = Vector2(0.0, 50.0)
	_category_filter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_root.add_child(_category_filter_scroll)

	_category_filter_hbox = HBoxContainer.new()
	_category_filter_hbox.add_theme_constant_override("separation", 6)
	_category_filter_scroll.add_child(_category_filter_hbox)

	# Bottom Zone 2: Submode Switcher + End Turn (anchored right above the 5-tab bar!)
	_action_submode_bar = HBoxContainer.new()
	_action_submode_bar.name = "ActionSubmodeBar"
	_action_submode_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_submode_bar.add_theme_constant_override("separation", 6)
	_action_root.add_child(_action_submode_bar)

	_btn_sub_routines = _make_bar_btn("BtnSubRoutines")
	_btn_sub_routines.pressed.connect(func() -> void: set_action_submode("routines"))
	_action_submode_bar.add_child(_btn_sub_routines)

	_btn_sub_decrees = _make_bar_btn("BtnSubDecrees")
	_btn_sub_decrees.pressed.connect(func() -> void: set_action_submode("decrees"))
	_action_submode_bar.add_child(_btn_sub_decrees)

	_btn_sub_factions = _make_bar_btn("BtnSubFactions")
	_btn_sub_factions.pressed.connect(func() -> void: set_action_submode("factions"))
	_action_submode_bar.add_child(_btn_sub_factions)

	_btn_end_turn = _make_bar_btn("BtnEndTurn")
	_btn_end_turn.theme_type_variation = &"AccentButton"
	_btn_end_turn.pressed.connect(end_turn)
	_action_submode_bar.add_child(_btn_end_turn)


static func _make_bar_btn(node_name: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0.0, 50.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	return btn


func get_bottom_zone_controls() -> Array[Control]:
	return [_category_filter_scroll, _action_submode_bar]


func set_action_submode(mode: String) -> void:
	if mode in ["routines", "decrees", "factions"]:
		_action_submode = mode
	refresh_view()


func set_category_filter(cat: String) -> void:
	_category_filter = cat if ACTION_CATEGORIES.has(cat) else "all"
	refresh_view()


func select_faction(faction_id: String) -> void:
	if CampaignManager != null and CampaignManager.factions.has(faction_id):
		_selected_faction_id = faction_id
	refresh_view()


func select_crisis_option(option_idx: int) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false, "reason": "no_manager"}
	if AudioController != null:
		AudioController.play_sfx("click")
	var out := CampaignManager.choose_event_option(option_idx)
	refresh_view()
	if bool(out.get("election_ready", false)) or CampaignManager.is_election_ready():
		election_screen_requested.emit(ELECTION_SCENE_PATH)
	return out


func execute_routine_by_id(routine_id: String) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false, "reason": "no_manager"}
	var out := CampaignManager.execute_routine(routine_id)
	if AudioController != null and not bool(out.get("ok", false)):
		AudioController.play_sfx("blocked")
	refresh_view()
	return out


func enact_decree_by_id(decree_id: String) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false, "reason": "no_manager"}
	var out := CampaignManager.enact_decree(decree_id)
	if AudioController != null and not bool(out.get("ok", false)):
		AudioController.play_sfx("blocked")
	refresh_view()
	return out


func engage_faction_deal(faction_id: String, deal_id: String) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false, "reason": "no_manager"}
	var out := CampaignManager.engage_faction(faction_id, deal_id)
	if AudioController != null:
		AudioController.play_sfx("click" if bool(out.get("ok", false)) else "blocked")
	refresh_view()
	return out


func trigger_final_appeal(faction_id: String) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false, "reason": "no_manager"}
	var out := CampaignManager.execute_final_appeal(faction_id)
	if AudioController != null:
		AudioController.play_sfx("click" if bool(out.get("ok", false)) else "blocked")
	refresh_view()
	return out


func end_turn() -> void:
	if CampaignManager == null or not CampaignManager.is_action_phase:
		return
	if AudioController != null:
		AudioController.play_sfx("notification")
	CampaignManager.finish_action_phase()
	refresh_view()


func has_golkar_pillars_widget() -> bool:
	return _golkar_pillars_widget != null and is_instance_valid(_golkar_pillars_widget) and _golkar_pillars_widget.visible


func is_final_appeal_visible() -> bool:
	return _btn_final_appeal != null and is_instance_valid(_btn_final_appeal) and _btn_final_appeal.visible


func is_horse_trading_button_visible() -> bool:
	return _btn_horse_trading != null and is_instance_valid(_btn_horse_trading) and _btn_horse_trading.visible


func open_horse_trading_sheet() -> Control:
	var host := _resolve_sheet_host()
	if host == null or CampaignManager == null:
		return null
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var vb := VBoxContainer.new()
	vb.name = "HorseTradingDeskSheet"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	_active_horse_sheet = vb
	_populate_horse_trading_sheet(vb)

	var title_txt := LocaleService.tr_fmt("horse.title") if LocaleService != null else ("Meja Dagang Sapi MPR" if is_id else "Horse-Trading Desk")
	host.push_sheet(vb, title_txt)
	return vb


func horse_trade_from_sheet(faction_id: String, overtures: int) -> Dictionary:
	if CampaignManager == null:
		return {"ok": false}
	var out := CampaignManager.execute_horse_trade(faction_id, overtures)
	if _active_horse_sheet != null and is_instance_valid(_active_horse_sheet):
		_populate_horse_trading_sheet(_active_horse_sheet)
	refresh_view()
	return out


func _populate_horse_trading_sheet(vb: VBoxContainer) -> void:
	for ch in vb.get_children():
		vb.remove_child(ch)
		ch.queue_free()

	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers

	var pc_hdr := Label.new()
	pc_hdr.theme_type_variation = &"HeaderLabel"
	pc_hdr.text = ("Modal Politik Tersisa: %d PC" % CampaignManager.pc) if is_id else ("Remaining Political Capital: %d PC" % CampaignManager.pc)
	vb.add_child(pc_hdr)

	for fk in CampaignManager.active_faction_order:
		if not CampaignManager.factions.has(fk) or bool(CampaignManager.banned_factions.get(fk, false)):
			continue
		var f: Dictionary = CampaignManager.factions[fk]
		var seats := int(f.get("seats", 0))
		if seats <= 0:
			continue

		var card := PanelContainer.new()
		card.theme_type_variation = &"SurfaceAltCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(card)

		var fvb := VBoxContainer.new()
		fvb.add_theme_constant_override("separation", 6)
		card.add_child(fvb)

		var f_name := LocaleService.tr_fmt(String(f.get("name_key", fk))) if LocaleService != null else fk
		var aff := float(f.get("affinity", 50.0))
		var mood := CampaignManager.get_faction_mood(fk, aff)
		var mood_txt := LocaleService.tr_fmt(mood.text_key) if (mood != null and LocaleService != null) else ""
		var locked := OppositionManager != null and OppositionManager.is_vote_locked(fk)

		var info_lbl := Label.new()
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if exact:
			info_lbl.text = "%s (%d Kursi) — %s (%.1f/100)" % [f_name, seats, mood_txt, aff]
		else:
			info_lbl.text = "%s (%d Kursi) — %s" % [f_name, seats, mood_txt]
		fvb.add_child(info_lbl)

		var btn_hb := HBoxContainer.new()
		btn_hb.add_theme_constant_override("separation", 8)
		fvb.add_child(btn_hb)

		var cost_1 := CampaignManager.get_horse_trade_cost(fk, 1)
		var cost_5 := CampaignManager.get_horse_trade_cost(fk, 5)

		var btn_1 := Button.new()
		btn_1.name = "HorseTrade1_" + fk
		btn_1.custom_minimum_size = Vector2(0.0, 48.0)
		btn_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_1.text = "+1 Overture (%d PC)" % cost_1
		btn_1.disabled = locked or CampaignManager.pc < cost_1 or aff >= 100.0
		var t_fk1 := fk
		btn_1.pressed.connect(func() -> void: horse_trade_from_sheet(t_fk1, 1))
		btn_hb.add_child(btn_1)

		var btn_5 := Button.new()
		btn_5.name = "HorseTrade5_" + fk
		btn_5.custom_minimum_size = Vector2(0.0, 48.0)
		btn_5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_5.theme_type_variation = &"AccentButton"
		btn_5.text = "+5 Overtures (%d PC)" % cost_5
		btn_5.disabled = locked or CampaignManager.pc < cost_5 or aff >= 100.0
		var t_fk5 := fk
		btn_5.pressed.connect(func() -> void: horse_trade_from_sheet(t_fk5, 5))
		btn_hb.add_child(btn_5)


func refresh_view() -> void:
	if CampaignManager == null:
		return
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	var in_action := CampaignManager.is_action_phase

	_crisis_root.visible = not in_action
	_action_root.visible = in_action

	if not in_action:
		_refresh_crisis_phase(is_id)
	else:
		_refresh_action_phase(is_id)


func _refresh_crisis_phase(is_id: bool) -> void:
	for ch in _crisis_options_vbox.get_children():
		_crisis_options_vbox.remove_child(ch)
		ch.queue_free()

	if ContentDB == null:
		return
	var ev := ContentDB.get_event_by_turn(CampaignManager.current_turn)
	if ev == null:
		_crisis_date_label.text = LocaleService.tr_fmt("date.general_session") if LocaleService != null else "20 Oktober 1999"
		_crisis_title_label.text = "Sidang Umum MPR 1999" if is_id else "1999 MPR General Session"
		_crisis_photo.visible = false
		_crisis_desc_rtl.text = ""
		return

	var d_txt := LocaleService.tr_fmt(ev.date_key) if LocaleService != null else ev.date_key
	_crisis_date_label.text = "%s • %s %d/23" % [d_txt, ("Giliran" if is_id else "Turn"), CampaignManager.current_turn]
	_crisis_title_label.text = LocaleService.tr_fmt(ev.title_key) if LocaleService != null else ev.title_key
	_crisis_desc_rtl.text = LocaleService.tr_fmt(ev.desc_key) if LocaleService != null else ev.desc_key

	if not ev.image_path.is_empty() and ResourceLoader.exists(ev.image_path):
		_crisis_photo.texture = ResourceLoader.load(ev.image_path) as Texture2D
		_crisis_photo.visible = true
	else:
		_crisis_photo.visible = false

	var order := CampaignManager.get_shuffled_option_indices(CampaignManager.current_turn)
	for opt_idx in order:
		if opt_idx < 0 or opt_idx >= ev.options.size():
			continue
		var opt := ev.options[opt_idx]
		var opt_btn := Button.new()
		opt_btn.name = "CrisisOptBtn_%d" % opt_idx
		opt_btn.custom_minimum_size = Vector2(0.0, 54.0)
		opt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		opt_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var opt_txt := LocaleService.tr_fmt(opt.text_key) if LocaleService != null else opt.text_key
		if CampaignManager.show_option_effects and not opt.effects.is_empty():
			var hint := _format_effects_preview(opt.effects, is_id)
			if not hint.is_empty():
				opt_txt += "\n[" + hint + "]"
		opt_btn.text = opt_txt
		var chosen_idx := opt_idx
		opt_btn.pressed.connect(func() -> void: select_crisis_option(chosen_idx))
		_crisis_options_vbox.add_child(opt_btn)


func _refresh_action_phase(is_id: bool) -> void:
	_golkar_pillars_widget = null
	_btn_final_appeal = null
	_btn_horse_trading = null

	_btn_sub_routines.text = ("Rutin ✓" if CampaignManager.turn_executive_used else "Rutin") if is_id else ("Routine ✓" if CampaignManager.turn_executive_used else "Routine")
	_btn_sub_decrees.text = "Dekrit" if is_id else "Decrees"
	_btn_sub_factions.text = ("Fraksi (%d)" % CampaignManager.turn_faction_count) if is_id else ("Factions (%d)" % CampaignManager.turn_faction_count)
	_btn_end_turn.text = "Akhiri Giliran" if is_id else "End Turn"

	_btn_sub_routines.theme_type_variation = &"AccentButton" if _action_submode == "routines" else &""
	_btn_sub_decrees.theme_type_variation = &"AccentButton" if _action_submode == "decrees" else &""
	_btn_sub_factions.theme_type_variation = &"AccentButton" if _action_submode == "factions" else &""

	# Category filter pills (visible in routines & decrees)
	_category_filter_scroll.visible = (_action_submode != "factions")
	for ch in _category_filter_hbox.get_children():
		_category_filter_hbox.remove_child(ch)
		ch.queue_free()

	if _category_filter_scroll.visible:
		for cat in ACTION_CATEGORIES:
			var pill := Button.new()
			pill.name = "CatFilterPill_" + cat.replace(" ", "_")
			pill.custom_minimum_size = Vector2(0.0, 48.0)
			pill.text = ("Semua" if is_id else "All") if cat == "all" else _localize_action_category(cat, is_id)
			if cat == _category_filter:
				pill.theme_type_variation = &"AccentButton"
			var target_cat := cat
			pill.pressed.connect(func() -> void: set_category_filter(target_cat))
			_category_filter_hbox.add_child(pill)

	for ch in _action_cards_vbox.get_children():
		_action_cards_vbox.remove_child(ch)
		ch.queue_free()

	# Turn 22 Horse-Trading Desk banner button (visible across action submodes on Turn 22!)
	if CampaignManager.is_night_of_long_knives_turn():
		_btn_horse_trading = Button.new()
		_btn_horse_trading.name = "BtnOpenHorseTrading"
		_btn_horse_trading.custom_minimum_size = Vector2(0.0, 52.0)
		_btn_horse_trading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn_horse_trading.theme_type_variation = &"AccentButton"
		_btn_horse_trading.text = "⚖ " + (LocaleService.tr_fmt("horse.title") if LocaleService != null else ("Meja Dagang Sapi MPR (+1 / +5 Overtures)" if is_id else "Horse-Trading Desk (+1 / +5 Overtures)"))
		_btn_horse_trading.pressed.connect(open_horse_trading_sheet)
		_action_cards_vbox.add_child(_btn_horse_trading)

	match _action_submode:
		"routines":
			_populate_routines_list(is_id)
		"decrees":
			_populate_decrees_list(is_id)
		"factions":
			_populate_factions_view(is_id)


func _populate_routines_list(is_id: bool) -> void:
	if ContentDB == null or ContentDB.catalog == null:
		return
	for routine in ContentDB.catalog.routines:
		if _category_filter != "all" and routine.category != _category_filter:
			continue
		var check := CampaignManager.can_execute_routine(routine.id)
		var ok := bool(check.get("ok", false))
		var cd := int(check.get("cooldown", 0))
		var est_pc := int(check.get("estimated_pc", 0))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_cards_vbox.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var t_lbl := Label.new()
		t_lbl.theme_type_variation = &"HeaderLabel"
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.text = LocaleService.tr_fmt(routine.text_key) if LocaleService != null else routine.id
		vb.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.theme_type_variation = &"MutedLabel"
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.text = LocaleService.tr_fmt(routine.desc_key) if LocaleService != null else routine.desc_key
		vb.add_child(d_lbl)

		if CampaignManager.show_option_effects and not routine.effects.is_empty():
			var eff_lbl := Label.new()
			eff_lbl.theme_type_variation = &"MutedLabel"
			eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff_lbl.text = _format_effects_preview(routine.effects, is_id)
			vb.add_child(eff_lbl)

		var btn := Button.new()
		btn.name = "ExecRoutine_" + routine.id
		btn.custom_minimum_size = Vector2(0.0, 48.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not ok
		var pc_tag := ("+%d PC" % est_pc) if est_pc > 0 else "0 PC"
		if cd > 0:
			btn.text = ("Jeda %d Giliran" % cd) if is_id else ("Cooldown %dT" % cd)
		elif CampaignManager.turn_executive_used:
			btn.text = ("Aksi Eksekutif Terpakai" if is_id else "Executive Action Used")
		else:
			btn.text = ("Jalankan (%s)" % pc_tag) if is_id else ("Execute (%s)" % pc_tag)
		var rid := routine.id
		btn.pressed.connect(func() -> void: execute_routine_by_id(rid))
		vb.add_child(btn)


func _populate_decrees_list(is_id: bool) -> void:
	if ContentDB == null or ContentDB.catalog == null:
		return
	for decree in ContentDB.catalog.decrees:
		if _category_filter != "all" and decree.category != _category_filter:
			continue
		var check := CampaignManager.can_enact_decree(decree.id)
		var ok := bool(check.get("ok", false))
		var cost := int(check.get("cost", decree.base_cost))
		var is_passed := bool(CampaignManager.active_decrees.get(decree.id, false))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_cards_vbox.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var t_lbl := Label.new()
		t_lbl.theme_type_variation = &"HeaderLabel"
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.text = ("✓ " if is_passed else "") + (LocaleService.tr_fmt(decree.text_key) if LocaleService != null else decree.id)
		vb.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.theme_type_variation = &"MutedLabel"
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.text = LocaleService.tr_fmt(decree.desc_key) if LocaleService != null else decree.desc_key
		vb.add_child(d_lbl)

		var btn := Button.new()
		btn.name = "EnactDecree_" + decree.id
		btn.custom_minimum_size = Vector2(0.0, 48.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not ok
		if is_passed:
			btn.text = LocaleService.tr_fmt("overlay.passed") if LocaleService != null else ("Disahkan" if is_id else "Enacted")
		elif not ok:
			btn.text = "%d PC • %s" % [cost, String(check.get("reason", "locked"))]
		else:
			btn.theme_type_variation = &"AccentButton"
			btn.text = ("Sahkan Dekrit (%d PC)" % cost) if is_id else ("Enact Decree (%d PC)" % cost)
		var did := decree.id
		btn.pressed.connect(func() -> void: enact_decree_by_id(did))
		vb.add_child(btn)


func _populate_factions_view(is_id: bool) -> void:
	# 1. Faction selector pills
	var fac_scroll := ScrollContainer.new()
	fac_scroll.custom_minimum_size = Vector2(0.0, 52.0)
	fac_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_cards_vbox.add_child(fac_scroll)

	var fac_hb := HBoxContainer.new()
	fac_hb.add_theme_constant_override("separation", 6)
	fac_scroll.add_child(fac_hb)

	if not CampaignManager.factions.has(_selected_faction_id) or bool(CampaignManager.banned_factions.get(_selected_faction_id, false)):
		for cand in CampaignManager.active_faction_order:
			if CampaignManager.factions.has(cand) and not bool(CampaignManager.banned_factions.get(cand, false)) and int(CampaignManager.factions[cand].get("seats", 0)) > 0:
				_selected_faction_id = cand
				break

	for fk in CampaignManager.active_faction_order:
		if not CampaignManager.factions.has(fk) or bool(CampaignManager.banned_factions.get(fk, false)):
			continue
		var f: Dictionary = CampaignManager.factions[fk]
		if int(f.get("seats", 0)) <= 0:
			continue
		var f_pill := Button.new()
		f_pill.name = "SelectFaction_" + fk
		f_pill.custom_minimum_size = Vector2(0.0, 48.0)
		var short_k := String(f.get("short_key", ""))
		f_pill.text = (LocaleService.tr_fmt(short_k) if (LocaleService != null and not short_k.is_empty()) else fk.to_upper())
		if fk == _selected_faction_id:
			f_pill.theme_type_variation = &"AccentButton"
		var target_fk := fk
		f_pill.pressed.connect(func() -> void: select_faction(target_fk))
		fac_hb.add_child(f_pill)

	if not CampaignManager.factions.has(_selected_faction_id):
		return

	var sel_f: Dictionary = CampaignManager.factions[_selected_faction_id]
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers

	# 2. Selected Faction Header Card
	var hdr_card := PanelContainer.new()
	hdr_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_cards_vbox.add_child(hdr_card)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.add_theme_constant_override("separation", 6)
	hdr_card.add_child(hdr_vb)

	var f_title := Label.new()
	f_title.theme_type_variation = &"HeaderLabel"
	f_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f_title.text = "%s (%d Kursi)" % [
		(LocaleService.tr_fmt(String(sel_f.get("name_key", _selected_faction_id))) if LocaleService != null else _selected_faction_id),
		int(sel_f.get("seats", 0)),
	]
	hdr_vb.add_child(f_title)

	var aff := float(sel_f.get("affinity", 50.0))
	var fav := int(sel_f.get("favor", 0))
	var mood := CampaignManager.get_faction_mood(_selected_faction_id, aff)
	var mood_txt := LocaleService.tr_fmt(mood.text_key) if (mood != null and LocaleService != null) else ""
	var lev := CampaignManager.get_faction_leverage(_selected_faction_id)
	var lev_name := LocaleService.tr_fmt("leverage." + String(lev.get("tier_id", "moderate")) + ".name") if LocaleService != null else String(lev.get("tier_id", "moderate"))

	var f_meta := Label.new()
	f_meta.theme_type_variation = &"MutedLabel"
	f_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if exact:
		f_meta.text = "%s (%.1f/100) • Favor: %d ★ • Daya Tawar: %s" % [mood_txt, aff, fav, lev_name]
	else:
		f_meta.text = "%s • Favor: %d ★ • Daya Tawar: %s" % [mood_txt, fav, lev_name]
	hdr_vb.add_child(f_meta)

	# 3. Interactive Golkar Three Pillars Widget (A, B, G) for golkar_akbar & golkar_habibie
	if _selected_faction_id in ["golkar_akbar", "golkar_habibie"]:
		_golkar_pillars_widget = _build_golkar_pillars_widget(is_id)
		_action_cards_vbox.add_child(_golkar_pillars_widget)

	# 4. Turns 21–22 Final Appeal (0 PC) button
	if CampaignManager.is_past_accountability_speech():
		var fa_check := CampaignManager.can_final_appeal(_selected_faction_id)
		var fa_ok := bool(fa_check.get("ok", false))
		_btn_final_appeal = Button.new()
		_btn_final_appeal.name = "BtnFinalAppeal"
		_btn_final_appeal.custom_minimum_size = Vector2(0.0, 50.0)
		_btn_final_appeal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn_final_appeal.theme_type_variation = &"AccentButton"
		_btn_final_appeal.disabled = not fa_ok
		_btn_final_appeal.text = (
			("★ Final Appeal — Cairkan %d Favor (0 PC)" % fav) if is_id else ("★ Final Appeal — Cash Out %d Favor (0 PC)" % fav)
		)
		var target_fa_fk := _selected_faction_id
		_btn_final_appeal.pressed.connect(func() -> void: trigger_final_appeal(target_fa_fk))
		_action_cards_vbox.add_child(_btn_final_appeal)

	# 5. Faction Deals List
	var deals := CampaignManager.get_faction_deals(_selected_faction_id)
	for deal in deals:
		if deal.is_final_appeal:
			continue
		var check := CampaignManager.can_engage_faction(_selected_faction_id, deal.id)
		var ok := bool(check.get("ok", false))
		var cost := int(check.get("cost", deal.cost))

		var d_card := PanelContainer.new()
		d_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_cards_vbox.add_child(d_card)

		var dvb := VBoxContainer.new()
		dvb.add_theme_constant_override("separation", 6)
		d_card.add_child(dvb)

		var dt_lbl := Label.new()
		dt_lbl.theme_type_variation = &"HeaderLabel"
		dt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dt_lbl.text = LocaleService.tr_fmt(deal.text_key) if LocaleService != null else deal.id
		dvb.add_child(dt_lbl)

		var dd_lbl := Label.new()
		dd_lbl.theme_type_variation = &"MutedLabel"
		dd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dd_lbl.text = LocaleService.tr_fmt(deal.desc_key) if LocaleService != null else deal.desc_key
		dvb.add_child(dd_lbl)

		var d_btn := Button.new()
		d_btn.name = "EngageDeal_" + deal.id
		d_btn.custom_minimum_size = Vector2(0.0, 48.0)
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.disabled = not ok
		d_btn.text = (
			("Negosiasi (%d PC)" % cost if is_id else "Negotiate (%d PC)" % cost)
			if ok
			else ("%d PC • %s" % [cost, String(check.get("reason", "locked"))])
		)
		var tfk := _selected_faction_id
		var tdid := deal.id
		d_btn.pressed.connect(func() -> void: engage_faction_deal(tfk, tdid))
		dvb.add_child(d_btn)


func _build_golkar_pillars_widget(is_id: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "GolkarPillarsWidget"
	panel.theme_type_variation = &"SurfaceAltCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var hdr := Label.new()
	hdr.text = "Jalur Tiga Pilar Golkar (A • B • G)" if is_id else "Golkar Three Pillars (A • B • G)"
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hdr)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)

	var pillars_meta := [
		{"id": "a", "letter": "A", "name_id": "ABRI", "name_en": "Military (ABRI)", "decree": "abolish_kodam_territorial"},
		{"id": "b", "letter": "B", "name_id": "Birokrasi", "name_en": "Bureaucracy", "decree": "civil_service_neutrality"},
		{"id": "g", "letter": "G", "name_id": "Golkar", "name_en": "Golkar Patronage", "decree": "anti_corruption"},
	]

	var selected_meta: Dictionary = pillars_meta[0]
	for pm in pillars_meta:
		var pid := String(pm["id"])
		if pid == _selected_pillar_id:
			selected_meta = pm
		var stands := CampaignManager.golkar_pillar_stands(pid)
		var p_btn := Button.new()
		p_btn.name = "GolkarPillarBtn_" + pid
		p_btn.custom_minimum_size = Vector2(0.0, 48.0)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.text = "%s • %s" % [String(pm["letter"]), ("Tegak" if is_id else "Intact") if stands else ("Runtuh" if is_id else "Broken")]
		if pid == _selected_pillar_id:
			p_btn.theme_type_variation = &"AccentButton"
		p_btn.pressed.connect(func() -> void:
			_selected_pillar_id = pid
			refresh_view()
		)
		hb.add_child(p_btn)

	var dec_id := String(selected_meta["decree"])
	var dec_obj := ContentDB.get_decree(dec_id) if ContentDB != null else null
	var dec_name := (LocaleService.tr_fmt(dec_obj.text_key) if (dec_obj != null and LocaleService != null) else dec_id)
	var sel_stands := CampaignManager.golkar_pillar_stands(String(selected_meta["id"]))

	var detail_lbl := Label.new()
	detail_lbl.theme_type_variation = &"MutedLabel"
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.text = (
		"Pilar %s (%s): %s — Dekrit Pemutus: %s"
		% [
			String(selected_meta["letter"]),
			String(selected_meta["name_id"]),
			("Masih berdiri menopang mesin lama" if sel_stands else "Telah diruntuhkan"),
			dec_name,
		]
		if is_id
		else "Pillar %s (%s): %s — Breaking Decree: %s"
		% [
			String(selected_meta["letter"]),
			String(selected_meta["name_en"]),
			("Still standing" if sel_stands else "Collapsed"),
			dec_name,
		]
	)
	vb.add_child(detail_lbl)
	return panel


static func _localize_action_category(cat: String, is_id: bool) -> String:
	if not is_id:
		return cat
	match cat:
		"Politics":
			return "Politik"
		"Economy":
			return "Ekonomi"
		"Security":
			return "Keamanan"
		"Regional Affairs":
			return "Daerah"
		"Civil Society":
			return "Masyarakat"
		_:
			return cat


static func _format_effects_preview(effects: Dictionary, is_id: bool) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var loc: Node = null
	if Engine.get_main_loop() is SceneTree:
		loc = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("LocaleService")
	for raw_k in effects.keys():
		var k := String(raw_k)
		var v: Variant = effects[raw_k]
		var range_txt := ""
		if v is Array and (v as Array).size() >= 2:
			var a := int((v as Array)[0])
			var b := int((v as Array)[1])
			range_txt = ("%+d..%+d" % [a, b]) if a != b else ("%+d" % a)
		elif v is int or v is float:
			var iv := int(roundf(float(v)))
			if iv == 0:
				continue
			range_txt = "%+d" % iv
		if range_txt.is_empty():
			continue
		var lbl := k.capitalize()
		if loc != null and loc.has_method("has_key") and bool(loc.call("has_key", "effect_name." + k)):
			lbl = String(loc.call("tr_fmt", "effect_name." + k))
		elif k.ends_with("_favor"):
			lbl = ("★ " + k.trim_suffix("_favor").to_upper()) if is_id else ("★ " + k.trim_suffix("_favor").to_upper())
		parts.append("%s %s" % [lbl, range_txt])
	return ", ".join(parts)
