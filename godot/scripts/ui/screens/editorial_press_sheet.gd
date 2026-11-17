class_name EditorialPressSheet
extends VBoxContainer

const OUTLET_META := {
	"KOMPAS": {"color": "#2563EB", "tag_id": "Harian Nasional", "tag_en": "National Broadsheet"},
	"MAJALAH TEMPO": {"color": "#DC2626", "tag_id": "Majalah Investigasi", "tag_en": "Investigative Weekly"},
	"THE JAKARTA POST": {"color": "#1E3A8A", "tag_id": "Harian Berbahasa Inggris", "tag_en": "English-Language Daily"},
	"REPUBLIKA": {"color": "#15803D", "tag_id": "Harian Nasional Islam", "tag_en": "Islamic National Daily"},
	"DETIKCOM": {"color": "#9333EA", "tag_id": "Portal Berita Daring", "tag_en": "Breaking Web Portal"},
	"RAKYAT MERDEKA": {"color": "#EA580C", "tag_id": "Harian Politik", "tag_en": "Political Tabloid"},
	"POS KOTA": {"color": "#D97706", "tag_id": "Harian Ibu Kota", "tag_en": "Metropolitan Tabloid"},
	"BISNIS INDONESIA": {"color": "#0F766E", "tag_id": "Harian Ekonomi & Pasar", "tag_en": "Financial Daily"},
	"MEDIA INDONESIA": {"color": "#1D4ED8", "tag_id": "Harian Umum", "tag_en": "National Broadsheet"},
	"SUARA PEMBARUAN": {"color": "#4338CA", "tag_id": "Harian Sore", "tag_en": "Evening Broadsheet"},
	"SUARA KARYA": {"color": "#CA8A04", "tag_id": "Suara Golongan Karya", "tag_en": "Golkar Organ"},
	"FORUM KEADILAN": {"color": "#B91C1C", "tag_id": "Majalah Hukum & Politik", "tag_en": "Legal & Political Weekly"},
	"HARIAN WASPADA": {"color": "#047857", "tag_id": "Pers Daerah Sumatera", "tag_en": "Regional Daily"},
	"ASIAN WALL STREET JOURNAL": {"color": "#0E7490", "tag_id": "Pers Keuangan Asia", "tag_en": "Asian Financial Press"},
	"FAR EASTERN ECONOMIC REVIEW": {"color": "#7C2D12", "tag_id": "Tinjauan Ekonomi Regional", "tag_en": "Regional Economic Weekly"},
	"SYDNEY MORNING HERALD": {"color": "#0369A1", "tag_id": "Pers Internasional", "tag_en": "International Press"},
}

var _masthead_panel: PanelContainer = null
var _outlet_label: Label = null
var _badge_label: Label = null
var _dateline_label: Label = null
var _headline_label: Label = null
var _body_rtl: RichTextLabel = null
var _deltas_panel: PanelContainer = null
var _deltas_rtl: RichTextLabel = null

var _last_payload: Dictionary = {}
var _show_exact_numbers: bool = false
var _rendered_deltas_text: String = ""


func _init() -> void:
	name = "EditorialPressSheet"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)

	_masthead_panel = PanelContainer.new()
	_masthead_panel.name = "MastheadPanel"
	_masthead_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_masthead_panel)

	var mast_vbox := VBoxContainer.new()
	mast_vbox.add_theme_constant_override("separation", 4)
	_masthead_panel.add_child(mast_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	mast_vbox.add_child(top_row)

	_outlet_label = Label.new()
	_outlet_label.name = "OutletLabel"
	_outlet_label.theme_type_variation = &"HeaderLabel"
	_outlet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outlet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(_outlet_label)

	_badge_label = Label.new()
	_badge_label.name = "OutletBadgeLabel"
	_badge_label.theme_type_variation = &"MutedLabel"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_badge_label)

	_dateline_label = Label.new()
	_dateline_label.name = "DatelineLabel"
	_dateline_label.theme_type_variation = &"MutedLabel"
	_dateline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mast_vbox.add_child(_dateline_label)

	_headline_label = Label.new()
	_headline_label.name = "HeadlineLabel"
	_headline_label.theme_type_variation = &"HeaderLabel"
	_headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_headline_label)

	_body_rtl = RichTextLabel.new()
	_body_rtl.name = "BodyRichText"
	_body_rtl.bbcode_enabled = true
	_body_rtl.fit_content = true
	_body_rtl.scroll_active = false
	_body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body_rtl)

	_deltas_panel = PanelContainer.new()
	_deltas_panel.name = "NumericDeltasPanel"
	_deltas_panel.theme_type_variation = &"SurfaceAltCard"
	_deltas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deltas_panel.visible = false
	add_child(_deltas_panel)

	_deltas_rtl = RichTextLabel.new()
	_deltas_rtl.name = "NumericDeltasRichText"
	_deltas_rtl.bbcode_enabled = true
	_deltas_rtl.fit_content = true
	_deltas_rtl.scroll_active = false
	_deltas_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deltas_panel.add_child(_deltas_rtl)


func populate_alert(payload: Dictionary, show_exact_numbers: bool) -> void:
	_last_payload = payload.duplicate(true)
	_show_exact_numbers = show_exact_numbers

	var is_id := _is_indonesian()
	var kind := String(payload.get("kind", "press"))
	var raw_outlet := String(payload.get("outlet", "")).strip_edges()
	var outlet_upper := raw_outlet.to_upper()
	var date_str := String(payload.get("date_str", ""))
	var headline := String(payload.get("headline", ""))
	var body := String(payload.get("body", ""))

	var accent_hex := "#E5A93C"
	var badge_text := ""
	if kind == "telex" or outlet_upper.is_empty():
		_outlet_label.text = raw_outlet if not raw_outlet.is_empty() else ("KAWAT SEKRETARIAT NEGARA" if is_id else "STATE SECRETARIAT DISPATCH")
		badge_text = "Telex Istana" if is_id else "Palace Dispatch"
		accent_hex = "#D97706"
	else:
		_outlet_label.text = raw_outlet
		var meta: Dictionary = OUTLET_META.get(outlet_upper, {})
		accent_hex = String(meta.get("color", "#2563EB"))
		badge_text = String(meta.get("tag_id" if is_id else "tag_en", String(payload.get("category", "Pers"))))

	_badge_label.text = badge_text
	_dateline_label.text = date_str
	_dateline_label.visible = not date_str.is_empty()

	_headline_label.text = headline
	_headline_label.visible = not headline.strip_edges().is_empty()
	_body_rtl.text = body

	_style_masthead(Color.html(accent_hex))
	_populate_deltas(payload.get("net_deltas", {}) as Dictionary, show_exact_numbers, is_id)


func has_visible_numeric_deltas() -> bool:
	return _deltas_panel != null and _deltas_panel.visible and not _rendered_deltas_text.is_empty()


func get_rendered_deltas_text() -> String:
	return _rendered_deltas_text


func _style_masthead(brand_col: Color) -> void:
	var surface_alt := Color.html("#1F2A35")
	var border_col := Color.html("#26323F")
	if is_inside_tree():
		var tm := get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("color"):
			surface_alt = tm.call("color", "surface_alt") as Color
			border_col = tm.call("color", "border") as Color

	var sb := StyleBoxFlat.new()
	sb.bg_color = surface_alt.lerp(brand_col, 0.14)
	sb.border_color = brand_col
	sb.border_width_left = 5
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = brand_col
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_masthead_panel.add_theme_stylebox_override("panel", sb)


func _populate_deltas(net_deltas: Dictionary, show_exact: bool, is_id: bool) -> void:
	_rendered_deltas_text = ""
	if not show_exact or net_deltas == null or net_deltas.is_empty():
		_deltas_panel.visible = false
		_deltas_rtl.text = ""
		return

	var good_hex := "#4ADE80"
	var bad_hex := "#F87171"
	if is_inside_tree():
		var tm := get_node_or_null("/root/ThemeManager")
		if tm != null and tm.has_method("color"):
			good_hex = (tm.call("color", "good") as Color).to_html(false)
			bad_hex = (tm.call("color", "bad") as Color).to_html(false)

	var chips_bb: PackedStringArray = PackedStringArray()
	var chips_plain: PackedStringArray = PackedStringArray()

	for raw_k in net_deltas.keys():
		var k := String(raw_k)
		var v_num := float(net_deltas[raw_k])
		if is_zero_approx(v_num):
			continue
		var sign_str := "+" if v_num > 0.0 else ""
		var val_str := str(int(roundf(v_num))) if is_equal_approx(v_num, roundf(v_num)) else ("%.1f" % v_num)
		var label_str := _resolve_effect_label(k, is_id)
		var is_positive_good := (v_num < 0.0) if k == "cendana" else (v_num > 0.0)
		var hex := good_hex if is_positive_good else bad_hex
		var plain_chip := "%s%s %s" % [sign_str, val_str, label_str]
		chips_plain.append(plain_chip)
		chips_bb.append("[color=#%s][b]%s[/b][/color]" % [hex, plain_chip])

	if chips_plain.is_empty():
		_deltas_panel.visible = false
		_deltas_rtl.text = ""
		return

	_rendered_deltas_text = "  •  ".join(chips_plain)
	var header_txt := "Dampak Numerik:" if is_id else "Numeric Effects:"
	_deltas_rtl.text = "[b]%s[/b]  %s" % [header_txt, "   ".join(chips_bb)]
	_deltas_panel.visible = true


func _resolve_effect_label(k: String, is_id: bool) -> String:
	var loc := _get_loc()
	if k.ends_with("_favor"):
		var fk := k.trim_suffix("_favor")
		var fac_lbl := _tr_or(loc, "effect_name." + fk, fk.to_upper())
		return ("★ Favor " + fac_lbl) if is_id else ("★ " + fac_lbl + " Favor")
	return _tr_or(loc, "effect_name." + k, k.capitalize())


func _get_loc() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/LocaleService")
	if Engine.get_main_loop() is SceneTree:
		return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("LocaleService")
	return null


func _is_indonesian() -> bool:
	var loc := _get_loc()
	if loc != null and "current_locale" in loc:
		return String(loc.get("current_locale")) == "id"
	return true


static func _tr_or(loc: Node, key: String, fallback: String) -> String:
	if loc != null and loc.has_method("has_key") and bool(loc.call("has_key", key)):
		return String(loc.call("tr_fmt", key))
	return fallback
