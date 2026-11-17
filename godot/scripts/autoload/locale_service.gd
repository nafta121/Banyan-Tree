extends Node

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES := ["id", "en"]
const MAX_NESTING := 8
const LOCALE_PATHS := {
	"id": "res://godot/resources/locales/id.tres",
	"en": "res://godot/resources/locales/en.tres",
}

const BUILTIN_STRINGS := {
	"loader.default_title": "LOADING ASSETS",
	"loader.loading": "Loading...",
	"error.fatal_title": "Fatal Error Loading Assets",
	"error.fatal_body": "Failed to load resource files.",
}

const SECTION_CODE_TO_TOKEN := {
	"D": "__STAT_POP__",
	"M": "__STAT_REF__",
	"E": "__STAT_ECON__",
	"T": "__STAT_INTL__",
	"A": "__STAT_STAB__",
	"L": "__STAT_MIL__",
	"C": "__STAT_CENDANA__",
	"B": "__STAT_PC__",
	"R": "__CLR_DARK_RED__",
	"G": "__CLR_DARK_GREEN__",
	"g": "__CLR_GREEN__",
	"N": "__CLR_NAVY__",
	"Y": "__CLR_GOLD__",
	"O": "__CLR_ORANGE_RED__",
	"W": "__CLR_WARM_ORANGE__",
	"F": "__CLR_FIREBRICK__",
	"I": "__CLR_INFO_BLUE__",
	"P": "__CLR_CRIMSON__",
	"X": "__CLR_BRIGHT_RED__",
	"K": "__CLR_INK__",
	"S": "__CLR_MUTED__",
}

const DARK_PALETTE := {
	"__STAT_POP__": "#F472B6",
	"__STAT_REF__": "#C084FC",
	"__STAT_ECON__": "#4ADE80",
	"__STAT_INTL__": "#38BDF8",
	"__STAT_STAB__": "#94A3B8",
	"__STAT_MIL__": "#A3E635",
	"__STAT_CENDANA__": "#FBBF24",
	"__STAT_PC__": "#60A5FA",
	"__CLR_DARK_RED__": "#F87171",
	"__CLR_DARK_GREEN__": "#4ADE80",
	"__CLR_GREEN__": "#34D399",
	"__CLR_NAVY__": "#93C5FD",
	"__CLR_GOLD__": "#FACC15",
	"__CLR_ORANGE_RED__": "#FB923C",
	"__CLR_WARM_ORANGE__": "#FDBA74",
	"__CLR_FIREBRICK__": "#FCA5A5",
	"__CLR_INFO_BLUE__": "#60A5FA",
	"__CLR_CRIMSON__": "#F87171",
	"__CLR_BRIGHT_RED__": "#EF4444",
	"__CLR_INK__": "#ECF2F8",
	"__CLR_MUTED__": "#9CA3AF",
	"__FAC_PDIP__": "#F87171",
	"__FAC_GOLKAR_A__": "#FACC15",
	"__FAC_GOLKAR_H__": "#FBBF24",
	"__FAC_AXIS__": "#60A5FA",
	"__FAC_PKB__": "#4ADE80",
	"__FAC_PPP__": "#34D399",
	"__FAC_OTHER__": "#2DD4BF",
	"__FAC_ABRI__": "#A3E635",
	"__TIER_STEEL__": "#60A5FA",
	"__TIER_SLATE__": "#94A3B8",
	"__TIER_ORANGE__": "#FB923C",
}

const LIGHT_PALETTE := {
	"__STAT_POP__": "#C2185B",
	"__STAT_REF__": "#7B1FA2",
	"__STAT_ECON__": "#1B7837",
	"__STAT_INTL__": "#00798C",
	"__STAT_STAB__": "#37474F",
	"__STAT_MIL__": "#4D6628",
	"__STAT_CENDANA__": "#704D00",
	"__STAT_PC__": "#1D4ED8",
	"__CLR_DARK_RED__": "#8B0000",
	"__CLR_DARK_GREEN__": "#006400",
	"__CLR_GREEN__": "#008000",
	"__CLR_NAVY__": "#003380",
	"__CLR_GOLD__": "#9A6E04",
	"__CLR_ORANGE_RED__": "#D93800",
	"__CLR_WARM_ORANGE__": "#D94E0F",
	"__CLR_FIREBRICK__": "#B22222",
	"__CLR_INFO_BLUE__": "#004C97",
	"__CLR_CRIMSON__": "#B83227",
	"__CLR_BRIGHT_RED__": "#CC0000",
	"__CLR_INK__": "#1A1D21",
	"__CLR_MUTED__": "#555555",
	"__FAC_PDIP__": "#9E1F14",
	"__FAC_GOLKAR_A__": "#7D6000",
	"__FAC_GOLKAR_H__": "#8A5A00",
	"__FAC_AXIS__": "#004488",
	"__FAC_PKB__": "#005500",
	"__FAC_PPP__": "#1E6840",
	"__FAC_OTHER__": "#006068",
	"__FAC_ABRI__": "#3E5022",
	"__TIER_STEEL__": "#2B6CB0",
	"__TIER_SLATE__": "#2F4F4F",
	"__TIER_ORANGE__": "#C05621",
}

var current_locale: String = "id"
var active_palette_is_dark: bool = true

var _packs: Dictionary = {}
var _interp_regex: RegEx = RegEx.new()
var _token_regex: RegEx = RegEx.new()


func _init() -> void:
	_interp_regex.compile("\\$\\$|\\$([A-Za-z0-9_.]+)\\$|\\{([A-Za-z0-9_]+)\\}")
	_token_regex.compile("\\[color=(__[A-Z0-9_]+__)\\]")
	reload_packs()


func reload_packs() -> void:
	_packs.clear()
	for code in LOCALE_PATHS:
		var p: String = LOCALE_PATHS[code]
		if ResourceLoader.exists(p):
			var pack := ResourceLoader.load(p) as LocalePackData
			if pack != null:
				_packs[code] = pack


func set_locale(locale_code: String) -> void:
	var target := locale_code if SUPPORTED_LOCALES.has(locale_code) else "id"
	var changed := (current_locale != target)
	current_locale = target
	if changed:
		locale_changed.emit(current_locale)


func has_key(key: String) -> bool:
	return _lookup(key) != null


func get_loading_messages() -> PackedStringArray:
	var pack: LocalePackData = _packs.get(current_locale, null) as LocalePackData
	if pack != null and not pack.loading_messages.is_empty():
		return pack.loading_messages
	var en_pack: LocalePackData = _packs.get("en", null) as LocalePackData
	if en_pack != null and not en_pack.loading_messages.is_empty():
		return en_pack.loading_messages
	return PackedStringArray([tr_fmt("loader.loading")])


func token_hex(token: String) -> String:
	var pal := DARK_PALETTE if active_palette_is_dark else LIGHT_PALETTE
	return String(pal.get(token, "#ECF2F8" if active_palette_is_dark else "#1A1D21"))


func tr_fmt(key_or_raw: String, vars: Dictionary = {}) -> String:
	var found: Variant = _lookup(key_or_raw)
	var template: String = String(found) if found != null else key_or_raw
	var interpolated := _interpolate(template, vars, 0)
	if interpolated.contains("§") or interpolated.contains("<"):
		interpolated = _sanitize_runtime_markup(interpolated)
	return _resolve_color_tokens(interpolated)


func tr_list(items: Array) -> String:
	var clean: Array[String] = []
	for item in items:
		if item != null and not String(item).is_empty():
			clean.append(String(item))
	if clean.is_empty():
		return ""
	if clean.size() == 1:
		return clean[0]
	if clean.size() == 2:
		return tr_fmt("list.pair", {"A": clean[0], "B": clean[1]})
	var sep := tr_fmt("list.separator")
	var head := sep.join(PackedStringArray(clean.slice(0, clean.size() - 1)))
	return tr_fmt("list.last", {"LIST": head, "LAST": clean[clean.size() - 1]})


func _lookup(key: String) -> Variant:
	var cur_pack: LocalePackData = _packs.get(current_locale, null) as LocalePackData
	if cur_pack != null and cur_pack.strings.has(key):
		return cur_pack.strings[key]
	var en_pack: LocalePackData = _packs.get("en", null) as LocalePackData
	if en_pack != null and en_pack.strings.has(key):
		return en_pack.strings[key]
	if BUILTIN_STRINGS.has(key):
		return BUILTIN_STRINGS[key]
	return null


func _interpolate(text: String, vars: Dictionary, depth: int) -> String:
	if not text.contains("$") and not text.contains("{"):
		return text
	var matches := _interp_regex.search_all(text)
	if matches.is_empty():
		return text
	var out := ""
	var last_end := 0
	for m in matches:
		out += text.substr(last_end, m.get_start() - last_end)
		var full := m.get_string(0)
		if full == "$$":
			out += "$"
		else:
			var dollar_name := m.get_string(1)
			var curly_name := m.get_string(2)
			var var_name := dollar_name if not dollar_name.is_empty() else curly_name
			if vars.has(var_name):
				var v: Variant = vars[var_name]
				out += "" if v == null else String(v)
			elif not dollar_name.is_empty() and depth < MAX_NESTING:
				var nested: Variant = _lookup(dollar_name)
				if nested != null:
					out += _interpolate(String(nested), vars, depth + 1)
				else:
					out += full
			else:
				out += full
		last_end = m.get_end()
	out += text.substr(last_end)
	return out


func _resolve_color_tokens(text: String) -> String:
	if not text.contains("[color=__"):
		return text
	var matches := _token_regex.search_all(text)
	if matches.is_empty():
		return text
	var pal := DARK_PALETTE if active_palette_is_dark else LIGHT_PALETTE
	var out := ""
	var last_end := 0
	for m in matches:
		out += text.substr(last_end, m.get_start() - last_end)
		var tok := m.get_string(1)
		var hex: String = String(pal.get(tok, "#ECF2F8" if active_palette_is_dark else "#1A1D21"))
		out += "[color=%s]" % hex
		last_end = m.get_end()
	out += text.substr(last_end)
	return out


func _sanitize_runtime_markup(src: String) -> String:
	var s := src.replace("<br<br>", "\n\n")
	var out := ""
	var stack: Array[String] = []
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "§":
			if i + 1 < n:
				var code := s[i + 1]
				if code == "!":
					out += _close_top_color(stack)
					i += 2
					continue
				elif SECTION_CODE_TO_TOKEN.has(code):
					var tok: String = SECTION_CODE_TO_TOKEN[code]
					stack.append("color=" + tok)
					out += "[color=%s]" % tok
					i += 2
					continue
			# Malformed/bare § (e.g., <b>§R$DRIFT$§</b>): treat as closing active § color if open
			out += _close_top_color(stack)
			i += 1
			continue
		elif ch == "<":
			var close_idx := s.find(">", i)
			if close_idx != -1:
				var raw_tag := s.substr(i + 1, close_idx - i - 1).strip_edges()
				var lower_tag := raw_tag.to_lower()
				if lower_tag == "b":
					stack.append("b")
					out += "[b]"
					i = close_idx + 1
					continue
				elif lower_tag == "/b":
					out += _close_until_tag(stack, "b")
					i = close_idx + 1
					continue
				elif lower_tag == "i":
					stack.append("i")
					out += "[i]"
					i = close_idx + 1
					continue
				elif lower_tag == "/i":
					out += _close_until_tag(stack, "i")
					i = close_idx + 1
					continue
				elif lower_tag == "u":
					stack.append("u")
					out += "[u]"
					i = close_idx + 1
					continue
				elif lower_tag == "/u":
					out += _close_until_tag(stack, "u")
					i = close_idx + 1
					continue
				elif lower_tag.begins_with("br"):
					out += "\n"
					i = close_idx + 1
					continue
		out += ch
		i += 1
	while not stack.is_empty():
		var top: String = stack.pop_back()
		out += "[/color]" if top.begins_with("color=") else "[/%s]" % top
	return out


func _close_top_color(stack: Array[String]) -> String:
	for idx in range(stack.size() - 1, -1, -1):
		if stack[idx].begins_with("color="):
			var closed := ""
			var reopen: Array[String] = []
			while stack.size() > idx:
				var popped: String = stack.pop_back()
				closed += "[/color]" if popped.begins_with("color=") else "[/%s]" % popped
				if stack.size() > idx:
					reopen.push_front(popped)
			for tag in reopen:
				stack.append(tag)
				closed += "[%s]" % tag
			return closed
	return ""


func _close_until_tag(stack: Array[String], target: String) -> String:
	for idx in range(stack.size() - 1, -1, -1):
		if stack[idx] == target:
			var closed := ""
			var reopen: Array[String] = []
			while stack.size() > idx:
				var popped: String = stack.pop_back()
				closed += "[/color]" if popped.begins_with("color=") else "[/%s]" % popped
				if stack.size() > idx:
					reopen.push_front(popped)
			for tag in reopen:
				stack.append(tag)
				closed += "[%s]" % tag
			return closed
	return ""
