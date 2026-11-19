class_name LibraryTabView
extends VBoxContainer

const PAGE_SIZE := 25
const CATEGORIES: Array[String] = [
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

var _entries_scroll: ScrollContainer = null
var _entries_vbox: VBoxContainer = null
var _count_label: Label = null
var _pager_row: HBoxContainer = null
var _prev_page_btn: Button = null
var _page_info_label: Label = null
var _next_page_btn: Button = null
var _cat_scroll: ScrollContainer = null
var _cat_hbox: HBoxContainer = null
var _search_row: HBoxContainer = null
var _search_edit: LineEdit = null
var _clear_btn: Button = null

var _active_category: String = "all"
var _search_query: String = ""
var _current_page: int = 0
var _alt_open: Dictionary = {}
var _filtered_entries: Array[LibraryEntryData] = []
var _rendered_bodies: Dictionary = {}


func _init() -> void:
	name = "LibraryTabView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_count_label = Label.new()
	_count_label.theme_type_variation = &"MutedLabel"
	add_child(_count_label)

	# Upper & middle scrollable entry cards
	_entries_scroll = ScrollContainer.new()
	_entries_scroll.name = "LibraryEntriesScroll"
	_entries_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_entries_scroll)

	_entries_vbox = VBoxContainer.new()
	_entries_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_vbox.add_theme_constant_override("separation", 10)
	_entries_scroll.add_child(_entries_vbox)

	# Pager row (only visible when > PAGE_SIZE entries)
	_pager_row = HBoxContainer.new()
	_pager_row.add_theme_constant_override("separation", 8)
	add_child(_pager_row)

	_prev_page_btn = Button.new()
	_prev_page_btn.custom_minimum_size = Vector2(56.0, 48.0)
	_prev_page_btn.text = "◀"
	_prev_page_btn.pressed.connect(_on_prev_page)
	_pager_row.add_child(_prev_page_btn)

	_page_info_label = Label.new()
	_page_info_label.theme_type_variation = &"MutedLabel"
	_page_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pager_row.add_child(_page_info_label)

	_next_page_btn = Button.new()
	_next_page_btn.custom_minimum_size = Vector2(56.0, 48.0)
	_next_page_btn.text = "▶"
	_next_page_btn.pressed.connect(_on_next_page)
	_pager_row.add_child(_next_page_btn)

	# Bottom thumb-zone category filter pills + search box
	_cat_scroll = ScrollContainer.new()
	_cat_scroll.name = "LibraryCategoryBar"
	_cat_scroll.custom_minimum_size = Vector2(0.0, 52.0)
	_cat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_cat_scroll)

	_cat_hbox = HBoxContainer.new()
	_cat_hbox.add_theme_constant_override("separation", 6)
	_cat_scroll.add_child(_cat_hbox)

	_search_row = HBoxContainer.new()
	_search_row.name = "LibrarySearchRow"
	_search_row.add_theme_constant_override("separation", 8)
	add_child(_search_row)

	_search_edit = LineEdit.new()
	_search_edit.name = "LibrarySearchEdit"
	_search_edit.custom_minimum_size = Vector2(0.0, 48.0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	_search_row.add_child(_search_edit)

	_clear_btn = Button.new()
	_clear_btn.name = "LibraryClearSearchBtn"
	_clear_btn.custom_minimum_size = Vector2(72.0, 48.0)
	_clear_btn.pressed.connect(_on_clear_pressed)
	_search_row.add_child(_clear_btn)


func _ready() -> void:
	if LocaleService != null:
		LocaleService.locale_changed.connect(func(_l: String) -> void: refresh_view())
	if ThemeManager != null:
		ThemeManager.theme_updated.connect(refresh_view)
	refresh_view()


func set_category(cat: String) -> void:
	var norm := cat.strip_edges()
	_active_category = norm if CATEGORIES.has(norm) else "all"
	_current_page = 0
	if _entries_scroll != null:
		_entries_scroll.scroll_vertical = 0
	refresh_view()


func set_search_query(q: String) -> void:
	_search_query = q.strip_edges()
	if _search_edit != null and _search_edit.text != _search_query:
		_search_edit.text = _search_query
	_current_page = 0
	if _entries_scroll != null:
		_entries_scroll.scroll_vertical = 0
	refresh_view()


func get_filtered_count() -> int:
	return _filtered_entries.size()


func get_first_visible_entry_id() -> String:
	if _filtered_entries.is_empty():
		return ""
	var start_idx := _current_page * PAGE_SIZE
	if start_idx >= 0 and start_idx < _filtered_entries.size():
		return _filtered_entries[start_idx].id
	return _filtered_entries[0].id


func is_entry_showing_alt(entry_id: String) -> bool:
	return bool(_alt_open.get(entry_id, false))


func toggle_entry_alt(entry_id: String) -> bool:
	var next_state := not bool(_alt_open.get(entry_id, false))
	_alt_open[entry_id] = next_state
	refresh_view()
	return next_state


func get_entry_rendered_body(entry_id: String) -> String:
	if _rendered_bodies.has(entry_id):
		return String(_rendered_bodies[entry_id])
	if ContentDB != null and ContentDB.catalog != null:
		for e in ContentDB.catalog.library_entries:
			if e.id == entry_id:
				var key := e.alt_key if (is_entry_showing_alt(entry_id) and not e.alt_key.is_empty()) else e.desc_key
				return LocaleService.tr_fmt(key) if LocaleService != null else key
	return ""


func _on_search_changed(new_text: String) -> void:
	_search_query = new_text.strip_edges()
	_current_page = 0
	if _entries_scroll != null:
		_entries_scroll.scroll_vertical = 0
	refresh_view()


func _on_clear_pressed() -> void:
	set_search_query("")


func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		if _entries_scroll != null:
			_entries_scroll.scroll_vertical = 0
		refresh_view()


func _on_next_page() -> void:
	var total_pages := maxi(1, int(ceil(float(_filtered_entries.size()) / float(PAGE_SIZE))))
	if _current_page + 1 < total_pages:
		_current_page += 1
		if _entries_scroll != null:
			_entries_scroll.scroll_vertical = 0
		refresh_view()


func refresh_view() -> void:
	var is_id := LocaleService == null or LocaleService.current_locale == "id"
	_search_edit.placeholder_text = LocaleService.tr_fmt("library.search_placeholder") if LocaleService != null else ("Cari pustaka..." if is_id else "Search library...")
	_clear_btn.text = LocaleService.tr_fmt("library.clear") if LocaleService != null else ("Hapus" if is_id else "Clear")

	# Rebuild category pills
	for ch in _cat_hbox.get_children():
		_cat_hbox.remove_child(ch)
		ch.queue_free()

	for cat in CATEGORIES:
		var pill := Button.new()
		pill.name = "LibCatPill_" + cat
		pill.custom_minimum_size = Vector2(0.0, 48.0)
		var c_key := "library.category." + cat
		pill.text = LocaleService.tr_fmt(c_key) if LocaleService != null else cat.capitalize()
		if cat == _active_category:
			pill.theme_type_variation = &"AccentButton"
		var target_cat := cat
		pill.pressed.connect(func() -> void: set_category(target_cat))
		_cat_hbox.add_child(pill)

	# Filter entries
	_filtered_entries.clear()
	var q_lower := _search_query.to_lower()
	if ContentDB != null and ContentDB.catalog != null:
		for entry in ContentDB.catalog.library_entries:
			if _active_category != "all" and entry.category != _active_category:
				continue
			if not q_lower.is_empty():
				var term_s := (LocaleService.tr_fmt(entry.term_key) if LocaleService != null else entry.term_key).to_lower()
				var sub_s := (LocaleService.tr_fmt(entry.subtitle_key) if LocaleService != null else entry.subtitle_key).to_lower()
				var desc_s := (LocaleService.tr_fmt(entry.desc_key) if LocaleService != null else entry.desc_key).to_lower()
				if not term_s.contains(q_lower) and not sub_s.contains(q_lower) and not desc_s.contains(q_lower):
					continue
			_filtered_entries.append(entry)

	var total := _filtered_entries.size()
	var total_all := ContentDB.catalog.library_entries.size() if (ContentDB != null and ContentDB.catalog != null) else total
	_count_label.text = (
		"%d / %d entri pustaka sejarah" % [total, total_all]
		if is_id
		else "%d / %d historical library entries" % [total, total_all]
	)

	var total_pages := maxi(1, int(ceil(float(total) / float(PAGE_SIZE))))
	_current_page = clampi(_current_page, 0, total_pages - 1)
	_pager_row.visible = total > PAGE_SIZE
	_prev_page_btn.disabled = _current_page <= 0
	_next_page_btn.disabled = _current_page + 1 >= total_pages
	_page_info_label.text = "%d / %d" % [_current_page + 1, total_pages]

	for ch in _entries_vbox.get_children():
		_entries_vbox.remove_child(ch)
		ch.queue_free()
	_rendered_bodies.clear()

	if _filtered_entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = LocaleService.tr_fmt("library.no_match") if LocaleService != null else ("Tidak ada entri cocok." if is_id else "No matching entries.")
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries_vbox.add_child(empty_lbl)
		return

	var start_idx := _current_page * PAGE_SIZE
	var end_idx := mini(total, start_idx + PAGE_SIZE)
	for i in range(start_idx, end_idx):
		var entry := _filtered_entries[i]
		_entries_vbox.add_child(_build_entry_card(entry, is_id))


func _build_entry_card(entry: LibraryEntryData, is_id: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "LibraryCard_" + entry.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 10)
	vb.add_child(top_hb)

	var has_alt := not entry.alt_key.is_empty()
	var showing_alt := has_alt and is_entry_showing_alt(entry.id)

	if has_alt:
		# Interactive portrait toggle button for the 8 Indonesian Presidents (biography <-> Criticism essay)
		var p_btn := Button.new()
		p_btn.name = "PortraitToggle_" + entry.id
		p_btn.custom_minimum_size = Vector2(76.0, 76.0)
		if not entry.image_path.is_empty() and ResourceLoader.exists(entry.image_path):
			p_btn.icon = ResourceLoader.load(entry.image_path) as Texture2D
			p_btn.expand_icon = true
		p_btn.tooltip_text = LocaleService.tr_fmt("library.portrait_hint_back" if showing_alt else "library.portrait_hint") if LocaleService != null else ""
		p_btn.text = "↺" if showing_alt else "⚖"
		if showing_alt:
			p_btn.theme_type_variation = &"AccentButton"
		var eid := entry.id
		p_btn.pressed.connect(func() -> void: toggle_entry_alt(eid))
		top_hb.add_child(p_btn)
	elif not entry.image_path.is_empty() and ResourceLoader.exists(entry.image_path):
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(64.0, 64.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.texture = ResourceLoader.load(entry.image_path) as Texture2D
		top_hb.add_child(tex_rect)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 2)
	top_hb.add_child(title_vb)

	var term_lbl := Label.new()
	term_lbl.theme_type_variation = &"HeaderLabel"
	term_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	term_lbl.text = LocaleService.tr_fmt(entry.term_key) if LocaleService != null else entry.term_key
	title_vb.add_child(term_lbl)

	if not entry.subtitle_key.is_empty():
		var sub_lbl := Label.new()
		sub_lbl.theme_type_variation = &"MutedLabel"
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.text = LocaleService.tr_fmt(entry.subtitle_key) if LocaleService != null else entry.subtitle_key
		title_vb.add_child(sub_lbl)

	if has_alt:
		var hint_lbl := Label.new()
		hint_lbl.theme_type_variation = &"MutedLabel"
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if showing_alt:
			var alt_hdr := LocaleService.tr_fmt(entry.alt_title_key) if (LocaleService != null and not entry.alt_title_key.is_empty()) else ("Esai Kritik" if is_id else "Criticism Essay")
			hint_lbl.text = "⚖ %s (Ketuk potret untuk kembali ke biografi)" % alt_hdr if is_id else "⚖ %s (Tap portrait to return to biography)" % alt_hdr
		else:
			hint_lbl.text = LocaleService.tr_fmt("library.portrait_hint") if LocaleService != null else ("Ketuk potret untuk membaca esai Kritik" if is_id else "Tap portrait to read Criticism essay")
		title_vb.add_child(hint_lbl)

	var body_key := entry.alt_key if showing_alt else entry.desc_key
	var body_txt := LocaleService.tr_fmt(body_key) if LocaleService != null else body_key
	_rendered_bodies[entry.id] = body_txt

	var body_rtl := RichTextLabel.new()
	body_rtl.name = "EntryBody_" + entry.id
	body_rtl.bbcode_enabled = true
	body_rtl.fit_content = true
	body_rtl.scroll_active = false
	body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_rtl.text = body_txt
	vb.add_child(body_rtl)

	return card
