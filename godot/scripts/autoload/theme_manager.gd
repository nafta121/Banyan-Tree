extends Node

signal theme_updated()

const DEFAULT_THEME_ID := "midnight_slate"
const LIGHT_THEME_ID := "editorial_paper"
const MIN_TEXT_SCALE := 0.85
const MAX_TEXT_SCALE := 1.40
const CARD_CORNER_RADIUS := 14
const MIN_TOUCH_HEIGHT := 48.0

const PALETTES := {
	"midnight_slate": {
		"bg": "#0F1419",
		"surface": "#182028",
		"surface_alt": "#1F2A35",
		"border": "#26323F",
		"text": "#ECF2F8",
		"muted": "#94A3B8",
		"accent": "#E5A93C",
		"good": "#4ADE80",
		"bad": "#F87171",
		"warn": "#FBBF24",
	},
	"editorial_paper": {
		"bg": "#F6F4EF",
		"surface": "#FFFFFF",
		"surface_alt": "#EAE5DA",
		"border": "#D4CFC3",
		"text": "#1A1D21",
		"muted": "#5A626E",
		"accent": "#9E2A2B",
		"good": "#1B7837",
		"bad": "#B83227",
		"warn": "#9A6E04",
	},
}

var active_theme_id: String = DEFAULT_THEME_ID
var active_text_scale: float = 1.0
var theme_id: String = DEFAULT_THEME_ID
var text_scale: float = 1.0
var active_theme: Theme = null


func _ready() -> void:
	var init_theme_id := DEFAULT_THEME_ID
	var init_scale := 1.0
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc != null and "settings" in save_svc:
		var s: UserSettingsData = save_svc.get("settings") as UserSettingsData
		if s != null:
			if not s.theme_id.is_empty():
				init_theme_id = s.theme_id
			init_scale = s.text_scale
	apply_theme(init_theme_id, init_scale)


func is_dark() -> bool:
	return active_theme_id != LIGHT_THEME_ID


func color(role: String) -> Color:
	var pal: Dictionary = PALETTES.get(active_theme_id, PALETTES[DEFAULT_THEME_ID])
	var hex := String(pal.get(role, pal.get("text", "#ECF2F8")))
	return Color.html(hex)


func scaled_px(base_px: int) -> int:
	return maxi(11, int(round(float(base_px) * active_text_scale)))


func make_box(
	bg_col: Color,
	border_col: Color,
	radius: int = CARD_CORNER_RADIUS,
	border_width: int = 1,
	margin_h: float = 14.0,
	margin_v: float = 12.0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


func apply_theme(p_theme_id: String, p_text_scale: float = active_text_scale) -> void:
	var norm_id := LIGHT_THEME_ID if p_theme_id.strip_edges() == LIGHT_THEME_ID else DEFAULT_THEME_ID
	var clamped_scale := clampf(p_text_scale, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	active_theme_id = norm_id
	active_text_scale = clamped_scale
	theme_id = norm_id
	text_scale = clamped_scale

	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and "active_palette_is_dark" in loc:
		loc.set("active_palette_is_dark", is_dark())

	active_theme = _build_theme()
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		get_tree().root.theme = active_theme

	theme_updated.emit()


func _build_theme() -> Theme:
	var t := Theme.new()
	var body_size := scaled_px(15)
	var small_size := scaled_px(13)
	var heading_size := scaled_px(19)
	t.default_font_size = body_size

	var c_bg := color("bg")
	var c_surface := color("surface")
	var c_surface_alt := color("surface_alt")
	var c_border := color("border")
	var c_text := color("text")
	var c_muted := color("muted")
	var c_accent := color("accent")

	# PanelContainer & Panel: 14px editorial card
	var panel_sb := make_box(c_surface, c_border, CARD_CORNER_RADIUS, 1, 14.0, 12.0)
	t.set_stylebox("panel", "PanelContainer", panel_sb)
	t.set_stylebox("panel", "Panel", make_box(c_surface, c_border, CARD_CORNER_RADIUS, 1, 0.0, 0.0))

	# SurfaceAltCard variation
	t.set_type_variation("SurfaceAltCard", "PanelContainer")
	t.set_stylebox("panel", "SurfaceAltCard", make_box(c_surface_alt, c_border, CARD_CORNER_RADIUS, 1, 12.0, 10.0))

	# Button: >= 48px touch height guaranteed across 0.85..1.40 text_scale, 14px corner radius
	var btn_v_pad := 16.0
	var btn_normal := make_box(c_surface_alt, c_border, CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad)
	var btn_hover := make_box(c_surface_alt.lightened(0.06) if is_dark() else c_surface_alt.darkened(0.04), c_accent, CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad)
	var btn_pressed := make_box(c_accent.darkened(0.65) if is_dark() else c_accent.lightened(0.78), c_accent, CARD_CORNER_RADIUS, 2, 16.0, btn_v_pad)
	var btn_disabled := make_box(c_bg.lerp(c_surface, 0.5), c_border.lerp(c_bg, 0.35), CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad)
	var btn_focus := make_box(Color(0, 0, 0, 0), c_accent, CARD_CORNER_RADIUS, 2, 16.0, btn_v_pad)

	for btn_type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", btn_type, btn_normal)
		t.set_stylebox("hover", btn_type, btn_hover)
		t.set_stylebox("pressed", btn_type, btn_pressed)
		t.set_stylebox("disabled", btn_type, btn_disabled)
		t.set_stylebox("focus", btn_type, btn_focus)
		t.set_font_size("font_size", btn_type, body_size)
		t.set_color("font_color", btn_type, c_text)
		t.set_color("font_hover_color", btn_type, c_text)
		t.set_color("font_pressed_color", btn_type, c_text)
		t.set_color("font_focus_color", btn_type, c_text)
		t.set_color("font_disabled_color", btn_type, c_muted.lerp(c_bg, 0.25))

	# Primary AccentButton variation
	t.set_type_variation("AccentButton", "Button")
	var acc_fg := Color.html("#0F1419") if is_dark() else Color.html("#FFFFFF")
	t.set_stylebox("normal", "AccentButton", make_box(c_accent, c_accent, CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad))
	t.set_stylebox("hover", "AccentButton", make_box(c_accent.lightened(0.08), c_accent.lightened(0.12), CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad))
	t.set_stylebox("pressed", "AccentButton", make_box(c_accent.darkened(0.12), c_accent, CARD_CORNER_RADIUS, 1, 16.0, btn_v_pad))
	t.set_stylebox("disabled", "AccentButton", btn_disabled)
	t.set_color("font_color", "AccentButton", acc_fg)
	t.set_color("font_hover_color", "AccentButton", acc_fg)
	t.set_color("font_pressed_color", "AccentButton", acc_fg)
	t.set_color("font_focus_color", "AccentButton", acc_fg)

	# CheckBox / CheckButton (>= 48px touch target)
	for chk_type in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", chk_type, make_box(c_surface_alt, c_border, CARD_CORNER_RADIUS, 1, 14.0, btn_v_pad))
		t.set_stylebox("hover", chk_type, make_box(c_surface_alt, c_accent, CARD_CORNER_RADIUS, 1, 14.0, btn_v_pad))
		t.set_stylebox("pressed", chk_type, make_box(c_surface_alt, c_accent, CARD_CORNER_RADIUS, 1, 14.0, btn_v_pad))
		t.set_stylebox("hover_pressed", chk_type, make_box(c_surface_alt, c_accent, CARD_CORNER_RADIUS, 1, 14.0, btn_v_pad))
		t.set_stylebox("disabled", chk_type, btn_disabled)
		t.set_stylebox("focus", chk_type, btn_focus)
		t.set_font_size("font_size", chk_type, body_size)
		t.set_color("font_color", chk_type, c_text)
		t.set_color("font_pressed_color", chk_type, c_text)
		t.set_color("font_hover_color", chk_type, c_text)
		t.set_color("font_hover_pressed_color", chk_type, c_text)
		t.set_color("font_disabled_color", chk_type, c_muted)

	# Labels & RichTextLabel
	t.set_font_size("font_size", "Label", body_size)
	t.set_color("font_color", "Label", c_text)

	t.set_type_variation("HeaderLabel", "Label")
	t.set_font_size("font_size", "HeaderLabel", heading_size)
	t.set_color("font_color", "HeaderLabel", c_text)

	t.set_type_variation("MutedLabel", "Label")
	t.set_font_size("font_size", "MutedLabel", small_size)
	t.set_color("font_color", "MutedLabel", c_muted)

	t.set_color("default_color", "RichTextLabel", c_text)
	t.set_font_size("normal_font_size", "RichTextLabel", body_size)
	t.set_font_size("bold_font_size", "RichTextLabel", body_size)
	t.set_font_size("italics_font_size", "RichTextLabel", body_size)
	t.set_font_size("bold_italics_font_size", "RichTextLabel", body_size)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	# LineEdit (>= 48px touch target)
	t.set_stylebox("normal", "LineEdit", make_box(c_surface_alt, c_border, 12, 1, 14.0, btn_v_pad))
	t.set_stylebox("focus", "LineEdit", make_box(c_surface_alt, c_accent, 12, 2, 14.0, btn_v_pad))
	t.set_color("font_color", "LineEdit", c_text)
	t.set_color("font_placeholder_color", "LineEdit", c_muted)
	t.set_color("caret_color", "LineEdit", c_accent)
	t.set_font_size("font_size", "LineEdit", body_size)

	# ProgressBar
	var pb_bg := make_box(c_surface_alt, c_border, 6, 1, 0.0, 0.0)
	var pb_fill := make_box(c_accent, c_accent, 6, 0, 0.0, 0.0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# HSeparator
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = c_border
	sep_sb.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep_sb)

	return t
