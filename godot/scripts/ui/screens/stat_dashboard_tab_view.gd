class_name StatDashboardTabView
extends ScrollContainer

const DISPLAY_STATS: Array[String] = ["pop", "econ", "stab", "ref", "intl", "mil", "cendana"]

var _root_vbox: VBoxContainer = null
var _gov_summary_label: Label = null
var _opp_summary_rtl: RichTextLabel = null
var _pillars_summary_rtl: RichTextLabel = null
var _stat_cards: Dictionary = {}
var _gazette_rtl: RichTextLabel = null


func _init() -> void:
	name = "StatDashboardTabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", 10)
	add_child(_root_vbox)

	# 1. Government Stability & Opposition Pressure Card
	var gov_card := PanelContainer.new()
	gov_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(gov_card)

	var gov_vbox := VBoxContainer.new()
	gov_vbox.add_theme_constant_override("separation", 6)
	gov_card.add_child(gov_vbox)

	_gov_summary_label = Label.new()
	_gov_summary_label.theme_type_variation = &"HeaderLabel"
	_gov_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gov_vbox.add_child(_gov_summary_label)

	_opp_summary_rtl = RichTextLabel.new()
	_opp_summary_rtl.bbcode_enabled = true
	_opp_summary_rtl.fit_content = true
	_opp_summary_rtl.scroll_active = false
	_opp_summary_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gov_vbox.add_child(_opp_summary_rtl)

	# 2. Seven National Metrics (StatCardWidgets)
	for sk in DISPLAY_STATS:
		var card := StatCardWidget.new()
		card.name = "StatCard_" + sk
		_stat_cards[sk] = card
		_root_vbox.add_child(card)

	# 3. Golkar Three Pillars Summary (A-B-G)
	var pil_card := PanelContainer.new()
	pil_card.theme_type_variation = &"SurfaceAltCard"
	pil_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(pil_card)

	_pillars_summary_rtl = RichTextLabel.new()
	_pillars_summary_rtl.bbcode_enabled = true
	_pillars_summary_rtl.fit_content = true
	_pillars_summary_rtl.scroll_active = false
	_pillars_summary_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pil_card.add_child(_pillars_summary_rtl)

	# 4. State Gazette (Enacted Decrees History)
	var gaz_card := PanelContainer.new()
	gaz_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(gaz_card)

	_gazette_rtl = RichTextLabel.new()
	_gazette_rtl.bbcode_enabled = true
	_gazette_rtl.fit_content = true
	_gazette_rtl.scroll_active = false
	_gazette_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gaz_card.add_child(_gazette_rtl)


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


func get_stat_card_count() -> int:
	return _stat_cards.size()


func refresh_view() -> void:
	if CampaignManager == null:
		return
	var exact := SaveAndSettingsService != null and SaveAndSettingsService.settings != null and SaveAndSettingsService.settings.show_exact_numbers
	var is_id := LocaleService == null or LocaleService.current_locale == "id"

	var gov_val := CampaignManager.get_gov_stability()
	var gov_tier_key := "gov." + CampaignManager.get_gov_stability_tier_id()
	var gov_tier_txt := LocaleService.tr_fmt(gov_tier_key) if LocaleService != null else CampaignManager.get_gov_stability_tier_id()
	var gov_lbl := LocaleService.tr_fmt("hud.government_stability") if LocaleService != null else "Stabilitas Pemerintahan"
	_gov_summary_label.text = ("%s: %s (%d/100)" % [gov_lbl, gov_tier_txt, gov_val]) if exact else ("%s: %s" % [gov_lbl, gov_tier_txt])

	# TNI & PDI-P pressure lines respecting show_exact_numbers
	var mil_m := OppositionManager.get_military_meter() if OppositionManager != null else {}
	var pdip_m := OppositionManager.get_pdip_meter() if OppositionManager != null else {}
	var mil_phase := String(mil_m.get("phase", "patience"))
	var mil_title := LocaleService.tr_fmt("military.anger.title" if mil_phase == "anger" else "military.patience.title") if LocaleService != null else mil_phase
	var pdip_tier := int(pdip_m.get("tier", 0))
	var pdip_tier_lbl := LocaleService.tr_fmt("pdip.tier.%d.label" % clampi(pdip_tier, 0, 4)) if LocaleService != null else ("Tier %d" % pdip_tier)

	if exact:
		var mil_val := int(mil_m.get("value", 50))
		var mil_res := int(roundf(float(mil_m.get("resistance", 0.0)) * 100.0))
		var pdip_val := int(pdip_m.get("value", 0))
		var pdip_mult := float(pdip_m.get("cost_mult", 1.0))
		_opp_summary_rtl.text = (
			"[b]TNI:[/b] %s (%d/100 • Resistensi %d%%)\n[b]PDI-P:[/b] %s (%d/100 • Biaya ×%.2f)"
			% [mil_title, mil_val, mil_res, pdip_tier_lbl, pdip_val, pdip_mult]
			if is_id
			else "[b]TNI:[/b] %s (%d/100 • Resistance %d%%)\n[b]PDI-P:[/b] %s (%d/100 • Cost ×%.2f)"
			% [mil_title, mil_val, mil_res, pdip_tier_lbl, pdip_val, pdip_mult]
		)
	else:
		_opp_summary_rtl.text = "[b]TNI:[/b] %s\n[b]PDI-P:[/b] %s" % [mil_title, pdip_tier_lbl]

	for sk in DISPLAY_STATS:
		var card: StatCardWidget = _stat_cards[sk]
		var val := int(CampaignManager.stats.get(sk, 50))
		var prev := int(CampaignManager.prev_stats_snapshot.get(sk, val))
		var d_hint := clampi(val - prev, -1, 1)
		var f_lock := 0 if sk == "cendana" else int(CampaignManager.min_stats.get(sk, 0))
		var c_lock := CampaignManager.max_cendana if sk == "cendana" else 100
		card.bind_stat(sk, val, d_hint, f_lock, c_lock, exact)

	# Golkar Pillars A-B-G
	var p_lines: PackedStringArray = PackedStringArray()
	var p_heading := "[b]Jalur Tiga Pilar Golkar (A-B-G)[/b]" if is_id else "[b]Golkar Three Pillars (A-B-G)[/b]"
	p_lines.append(p_heading)
	for p_pair in [["a", "A • ABRI"], ["b", "B • Birokrasi"], ["g", "G • Golkar"]]:
		var pid: String = p_pair[0]
		var plbl: String = p_pair[1]
		var stands := CampaignManager.golkar_pillar_stands(pid)
		var status_txt := ("Tegak" if is_id else "Standing") if stands else ("Runtuh" if is_id else "Collapsed")
		p_lines.append("• %s: [b]%s[/b]" % [plbl, status_txt])
	_pillars_summary_rtl.text = "\n".join(p_lines)

	# Gazette history
	var gaz_title := LocaleService.tr_fmt("gazette.title") if LocaleService != null else ("Lembaran Negara" if is_id else "State Gazette")
	if CampaignManager.gazette_history.is_empty():
		var empty_txt := LocaleService.tr_fmt("gazette.empty") if LocaleService != null else ("Belum ada dekrit disahkan." if is_id else "No decrees enacted yet.")
		_gazette_rtl.text = "[b]%s[/b]\n%s" % [gaz_title, empty_txt]
	else:
		var g_lines: PackedStringArray = PackedStringArray(["[b]%s (%d)[/b]" % [gaz_title, CampaignManager.gazette_history.size()]])
		for entry in CampaignManager.gazette_history:
			var t_key := String(entry.get("text_key", ""))
			var d_name := LocaleService.tr_fmt(t_key) if LocaleService != null else t_key
			var d_date := String(entry.get("date_str", ""))
			g_lines.append("• [i]%s[/i] — %s" % [d_date, d_name])
		_gazette_rtl.text = "\n".join(g_lines)
