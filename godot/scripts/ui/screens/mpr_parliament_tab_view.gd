class_name MPRParliamentTabView
extends ScrollContainer

signal negotiate_faction_requested(faction_id: String)

const FACTION_HEX := {
	"pdip": "#DC2626",
	"poros_tengah": "#0D9488",
	"pkb": "#16A34A",
	"ppp": "#15803D",
	"golkar_habibie": "#EAB308",
	"golkar_akbar": "#CA8A04",
	"other_parties": "#8B5CF6",
	"utusan_daerah": "#3B82F6",
	"utusan_golongan": "#06B6D4",
	"abri": "#65A30D",
}

var _root_vbox: VBoxContainer = null
var _hemicycle: HemicycleCanvas = null
var _whip_summary_rtl: RichTextLabel = null
var _faction_list_vbox: VBoxContainer = null


func _init() -> void:
	name = "MPRParliamentTabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", 10)
	add_child(_root_vbox)

	var chamber_card := PanelContainer.new()
	chamber_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(chamber_card)

	var chamber_vbox := VBoxContainer.new()
	chamber_vbox.add_theme_constant_override("separation", 8)
	chamber_card.add_child(chamber_vbox)

	_hemicycle = HemicycleCanvas.new()
	_hemicycle.custom_minimum_size = Vector2(280.0, 184.0)
	chamber_vbox.add_child(_hemicycle)

	_whip_summary_rtl = RichTextLabel.new()
	_whip_summary_rtl.bbcode_enabled = true
	_whip_summary_rtl.fit_content = true
	_whip_summary_rtl.scroll_active = false
	_whip_summary_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chamber_vbox.add_child(_whip_summary_rtl)

	_faction_list_vbox = VBoxContainer.new()
	_faction_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_list_vbox.add_theme_constant_override("separation", 8)
	_root_vbox.add_child(_faction_list_vbox)


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


func get_hemicycle_canvas() -> HemicycleCanvas:
	return _hemicycle


func refresh_view() -> void:
	if CampaignManager == null:
		return
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers
	var is_id := LocaleService == null or LocaleService.current_locale == "id"

	# Build 700-seat color array along PARLIAMENT_SEATING_ORDER + vacated seats
	var seat_colors: Array[Color] = []
	var active_seats_sum := 0
	for fk in CampaignManager.PARLIAMENT_SEATING_ORDER:
		if not CampaignManager.factions.has(fk):
			continue
		if bool(CampaignManager.banned_factions.get(fk, false)):
			continue
		var s_cnt := int(CampaignManager.factions[fk].get("seats", 0))
		if s_cnt <= 0:
			continue
		active_seats_sum += s_cnt
		var f_col := Color.html(String(FACTION_HEX.get(fk, "#94A3B8")))
		for _i in range(s_cnt):
			seat_colors.append(f_col)

	var orig_total := OppositionManager.original_chamber_size() if OppositionManager != null else 700
	var vacated_col := Color(0.45, 0.50, 0.56, 0.28)
	while seat_colors.size() < orig_total:
		seat_colors.append(vacated_col)

	_hemicycle.set_seats_data(seat_colors, true)

	# Whip projection summary
	var margin := OppositionManager.get_whip_margin() if OppositionManager != null else 0.0
	var whip_key := "whip.too_close"
	if margin >= 45.0:
		whip_key = "whip.commanding"
	elif margin >= 15.0:
		whip_key = "whip.leading"
	elif margin <= -45.0:
		whip_key = "whip.very_unpopular"
	elif margin <= -15.0:
		whip_key = "whip.waning"
	var whip_lbl := LocaleService.tr_fmt(whip_key) if LocaleService != null else whip_key
	var seats_hdr := "%d / %d Kursi Aktif (Kuorum: 351)" % [active_seats_sum, orig_total] if is_id else "%d / %d Active Seats (Quorum: 351)" % [active_seats_sum, orig_total]
	if exact:
		var sign_s := "+" if margin >= 0.0 else ""
		_whip_summary_rtl.text = "[b]%s[/b]\n%s (Margin Whip: %s%.1f)" % [seats_hdr, whip_lbl, sign_s, margin]
	else:
		_whip_summary_rtl.text = "[b]%s[/b]\n%s" % [seats_hdr, whip_lbl]

	# Rebuild faction caucus cards
	for ch in _faction_list_vbox.get_children():
		_faction_list_vbox.remove_child(ch)
		ch.queue_free()

	for raw_fk in CampaignManager.INITIAL_PORTRAIT_FACTIONS:
		var fk := String(raw_fk)
		if not CampaignManager.factions.has(fk):
			continue
		var f: Dictionary = CampaignManager.factions[fk]
		var is_banned := bool(CampaignManager.banned_factions.get(fk, false))
		var seats := 0 if is_banned else int(f.get("seats", 0))
		var aff := float(f.get("affinity", 50.0))
		var fav := int(f.get("favor", 0))
		var f_name: String = LocaleService.tr_fmt(String(f.get("name_key", fk))) if LocaleService != null else fk

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_faction_list_vbox.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var top_hb := HBoxContainer.new()
		top_hb.add_theme_constant_override("separation", 8)
		vb.add_child(top_hb)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(12.0, 22.0)
		swatch.color = Color(0.45, 0.5, 0.56, 0.4) if is_banned else Color.html(String(FACTION_HEX.get(fk, "#94A3B8")))
		top_hb.add_child(swatch)

		var title_lbl := Label.new()
		title_lbl.text = f_name
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top_hb.add_child(title_lbl)

		var seats_lbl := Label.new()
		seats_lbl.theme_type_variation = &"MutedLabel"
		seats_lbl.text = ("Dibubarkan" if is_id else "Dissolved") if is_banned else ("%d Kursi" % seats if is_id else "%d Seats" % seats)
		top_hb.add_child(seats_lbl)

		var mood_tier := CampaignManager.get_faction_mood(fk, aff)
		var mood_txt := LocaleService.tr_fmt(mood_tier.text_key) if (mood_tier != null and LocaleService != null) else ""
		var fav_txt := (" • " + "★".repeat(fav)) if fav > 0 else ""
		var lock_txt := " • [TERKUNCI 0 SUARA]" if (OppositionManager != null and OppositionManager.is_vote_locked(fk)) else ""

		var meta_lbl := Label.new()
		meta_lbl.theme_type_variation = &"MutedLabel"
		meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if is_banned:
			meta_lbl.text = LocaleService.tr_fmt("parliament.legend_dissolved") if LocaleService != null else "Dissolved"
		elif exact:
			meta_lbl.text = "%s (%.1f/100)%s%s" % [mood_txt, aff, fav_txt, lock_txt]
		else:
			meta_lbl.text = "%s%s%s" % [mood_txt, fav_txt, lock_txt]
		vb.add_child(meta_lbl)

		if not is_banned and seats > 0 and CampaignManager.is_action_phase:
			var neg_btn := Button.new()
			neg_btn.name = "NegotiateBtn_" + fk
			neg_btn.custom_minimum_size = Vector2(0.0, 48.0)
			neg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			neg_btn.text = LocaleService.tr_fmt("parliament.negotiate") if LocaleService != null else ("Negosiasi Fraksi" if is_id else "Negotiate")
			var target_fk := fk
			neg_btn.pressed.connect(func() -> void: negotiate_faction_requested.emit(target_fk))
			vb.add_child(neg_btn)
