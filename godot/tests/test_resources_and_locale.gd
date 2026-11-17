extends TestBase


func run() -> int:
	# 0. Verify default LocaleService state ("id", dark palette) and ContentDB catalog loaded
	assert_true(ContentDB != null, "ContentDB autoload mounted")
	assert_true(LocaleService != null, "LocaleService autoload mounted")
	assert_true(ContentDB.catalog != null, "ContentDB.catalog loaded")
	assert_eq(LocaleService.current_locale, "id", "default locale is id")
	assert_eq(LocaleService.active_palette_is_dark, true, "default active_palette_is_dark is true")

	# 1. Exact resource counts from Task 2 brief
	assert_eq(ContentDB.catalog.events.size(), 23, "23 historical crisis events")
	var total_opts := 0
	for ev in ContentDB.catalog.events:
		total_opts += ev.options.size()
	assert_eq(total_opts, 111, "111 total crisis event options")
	assert_eq(ContentDB.catalog.routines.size(), 36, "36 routine actions")
	assert_eq(ContentDB.catalog.decrees.size(), 35, "35 presidential decrees")
	assert_eq(ContentDB.catalog.factions.size(), 10, "10 MPR factions")
	var total_seats := 0
	for f in ContentDB.catalog.factions:
		total_seats += f.initial_seats
	assert_eq(total_seats, 700, "700 total MPR initial seats")
	assert_eq(ContentDB.catalog.difficulties.size(), 5, "5 difficulty definitions (4 standard + ucn)")
	assert_eq(ContentDB.catalog.sss_cards.size(), 24, "24 SSS DAG cards")
	assert_eq(ContentDB.catalog.library_entries.size(), 112, "112 library entries (90 + 14 + 8)")
	assert_eq(ContentDB.catalog.achievements.size(), 59, "59 achievements")
	assert_eq(ContentDB.catalog.music_tracks.size(), 36, "36 active music tracks")

	# 2. Restored 22 loading messages (11 ID + 11 EN)
	LocaleService.set_locale("id")
	var id_loading := LocaleService.get_loading_messages()
	assert_eq(id_loading.size(), 11, "11 Indonesian loading messages")
	LocaleService.set_locale("en")
	var en_loading := LocaleService.get_loading_messages()
	assert_eq(en_loading.size(), 11, "11 English loading messages")
	assert_ne(id_loading[0], en_loading[0], "ID and EN loading messages are distinct")

	# 3. ContentDB lookup helpers & critical simulation fields
	assert_eq(ContentDB.get_event_by_turn(1).id, "ev_post_election", "Turn 1 event")
	assert_eq(ContentDB.get_event_by_turn(18).id, "ev_central_axis", "Turn 18 event")
	assert_eq(ContentDB.get_event_by_turn(21).id, "ev_the_speech", "Turn 21 event")
	assert_eq(ContentDB.get_event_by_turn(23).id, "ev_timtim_merdeka", "Turn 23 event")
	assert_true(ContentDB.get_event_by_turn(0) == null, "Turn 0 out-of-range returns null")
	assert_true(ContentDB.get_event_by_turn(24) == null, "Turn 24 out-of-range returns null")

	var dec_golkar := ContentDB.get_decree("dissolve_golkar_old_guard")
	assert_true(dec_golkar != null, "dissolve_golkar_old_guard exists")
	assert_eq(dec_golkar.seats_vacated, 30, "dissolve_golkar_old_guard vacates 30 seats")
	assert_eq(dec_golkar.req_golkar_pillars, true, "dissolve_golkar_old_guard requires Golkar pillars broken")
	assert_eq(int(dec_golkar.seat_recipients.get("golkar_habibie", 0)), 50, "50 seats transferred to golkar_habibie")

	assert_eq(ContentDB.get_decree("abolish_kodam_territorial").breaks_golkar_pillar, "a", "Pillar A decree")
	assert_eq(ContentDB.get_decree("civil_service_neutrality").breaks_golkar_pillar, "b", "Pillar B decree")
	assert_eq(ContentDB.get_decree("anti_corruption").breaks_golkar_pillar, "g", "Pillar G decree")

	assert_true(ContentDB.get_routine("military").is_military_interaction, "military routine flagged")
	assert_true(ContentDB.get_routine("kostrad_rotation").is_military_interaction, "kostrad_rotation routine flagged")
	assert_false(ContentDB.get_routine("leak").is_military_interaction, "leak routine not military")
	assert_eq(str(ContentDB.get_routine("campaign").dynamic_scaling.get("target", "")), "pop", "campaign dynamic scaling target")

	var pt := ContentDB.get_faction("poros_tengah")
	assert_true(pt != null and pt.merged_state != null, "poros_tengah has FactionMergedData")
	assert_eq(pt.initial_seats, 34, "poros_tengah pre-merge seats == 34")
	assert_eq(pt.merged_state.seats, 163, "poros_tengah merged seats == 163")
	assert_eq(pt.merged_state.deals.size(), 6, "poros_tengah merged deals == 6")
	for deal in pt.deals:
		if deal.is_final_appeal:
			assert_eq(deal.min_turn, 21, "final appeal min_turn == 21")
			assert_eq(deal.max_turn, 22, "final appeal max_turn == 22")

	var abri := ContentDB.get_faction("abri")
	var found_tni_final := false
	for deal in abri.deals:
		if deal.id == "tni_final_appeal":
			found_tni_final = true
			assert_eq(deal.min_turn, 21, "tni_final_appeal min_turn == 21")
			assert_eq(deal.max_turn, 22, "tni_final_appeal max_turn == 22")
	assert_true(found_tni_final, "abri has tni_final_appeal")

	assert_eq(ContentDB.get_difficulty("easy").pc, 75, "easy starting PC == 75")
	assert_eq(ContentDB.get_difficulty("historical").pc, 20, "historical starting PC == 20")

	# 4. Verify all 111 press dispatches parsed cleanly & categories valid
	var valid_press_cats := ["broadsheet", "tabloid", "magazine", "financial", "browser", "international"]
	var seen_cats := {}
	for ev in ContentDB.catalog.events:
		for opt in ev.options:
			assert_true(not opt.press_outlet.is_empty(), "non-empty press_outlet in " + ev.id)
			assert_true(valid_press_cats.has(opt.press_category), "valid press_category " + opt.press_category)
			seen_cats[opt.press_category] = true
			assert_true(LocaleService.has_key(opt.press_headline_key), "headline key exists: " + opt.press_headline_key)
			assert_true(LocaleService.has_key(opt.press_body_key), "body key exists: " + opt.press_body_key)
	assert_eq(seen_cats.size(), 6, "all 6 press categories represented across 111 options")

	# 5. Verify 8 presidents with Criticism alt essays & 36 music tracks with weighted tags
	var pres_with_alt := 0
	var persons_count := 0
	for entry in ContentDB.catalog.library_entries:
		if entry.category == "presidents" and not entry.alt_key.is_empty():
			pres_with_alt += 1
			assert_true(LocaleService.has_key(entry.alt_key), "president alt_key exists: " + entry.alt_key)
		elif entry.category == "persons":
			persons_count += 1
	assert_eq(pres_with_alt, 8, "all 8 presidents have Criticism alt text")
	assert_eq(persons_count, 14, "14 persons entries")

	for track in ContentDB.catalog.music_tracks:
		assert_true(track.file_path.begins_with("res://audio/music/"), "music res:// path")
		assert_true(track.weighted_tags.size() >= 1, "every music track has >= 1 weighted quadrant tag: " + track.title)

	# 6. Review Focus #1: Clean BBCode, balanced color/bold tags, $$ literal dollar, adjacent $A$$B$, palette switch
	var signal_locales: Array[String] = []
	var cb := func(loc: String) -> void: signal_locales.append(loc)
	LocaleService.locale_changed.connect(cb)

	for lang in ["id", "en"]:
		LocaleService.set_locale(lang)
		for ev in ContentDB.catalog.events:
			var desc := LocaleService.tr_fmt(ev.desc_key)
			assert_true(not desc.contains("§") and not desc.contains("<br") and not desc.contains("<font"), "clean BBCode in " + ev.id)
			assert_eq(desc.count("[color="), desc.count("[/color]"), "balanced color in " + ev.id)
			assert_eq(desc.count("[b]"), desc.count("[/b]"), "balanced [b] in " + ev.id)
			for opt in ev.options:
				var body := LocaleService.tr_fmt(opt.press_body_key)
				assert_true(not body.contains("§") and not body.contains("<br"), "clean press body in " + ev.id)
				assert_eq(body.count("[color="), body.count("[/color]"), "balanced color in press body " + ev.id)
		var pill := LocaleService.tr_fmt("faction.golkar_pillars.g.effect", {"DRIFT": "+1"})
		assert_true(not pill.contains("§") and not pill.contains("__"), "resolved tokens in pillar G effect (" + lang + ")")
		assert_eq(pill.count("[color="), pill.count("[/color]"), "balanced color tags in pillar G (" + lang + ")")
		assert_eq(pill.count("[b]"), pill.count("[/b]"), "balanced bold tags in pillar G (" + lang + ")")

		# Adjacent variables $TIER$$FATIGUE$ in ID routine.grants_pc & separated $TIER$...$FATIGUE$ in EN
		var grants := LocaleService.tr_fmt("routine.grants_pc", {"TIER": "besar", "FATIGUE": " (berkurang)"})
		assert_true(not grants.contains("$TIER$") and not grants.contains("$FATIGUE$"), "routine.grants_pc placeholders resolved in " + lang)
		if lang == "id":
			assert_true(grants.contains("besar (berkurang)"), "adjacent $TIER$$FATIGUE$ interpolated cleanly in id")
		else:
			assert_true(grants.contains("besar sum of PC (berkurang)"), "$TIER$ and $FATIGUE$ interpolated cleanly in en")

		# Recursive $tier.cendana.*$ lookup inside difficulty description
		var easy_desc := LocaleService.tr_fmt(ContentDB.get_difficulty("easy").desc_key)
		assert_true(not easy_desc.contains("$tier.") and not easy_desc.contains("<font"), "recursive $tier.*$ resolved in " + lang)
		assert_eq(easy_desc.count("[color="), easy_desc.count("[/color]"), "balanced colors in easy_desc (" + lang + ")")

		# Tutorial adapted for portrait one-handed UI & Show Exact Numbers toggle
		var tut_all := ""
		for i in range(ContentDB.catalog.tutorial_count):
			var t_page := LocaleService.tr_fmt("tutorial.%d.text" % i)
			tut_all += t_page + "\n"
			assert_true(not t_page.contains("<br") and not t_page.contains("<font"), "clean tutorial BBCode page %d (%s)" % [i, lang])
		assert_false(tut_all.to_lower().contains("left panel"), "no legacy desktop 'left panel' in tutorial (" + lang + ")")
		assert_false(tut_all.to_lower().contains("panel sebelah kiri"), "no legacy desktop 'panel sebelah kiri' in tutorial (" + lang + ")")
		assert_true(tut_all.contains("0–100") or tut_all.contains("0-100"), "tutorial mentions 0-100 exact numbers toggle (" + lang + ")")

		# Full pack sweep: every single key in id.tres / en.tres renders clean balanced BBCode
		var pack := ResourceLoader.load("res://godot/resources/locales/%s.tres" % lang) as LocalePackData
		assert_true(pack != null and pack.strings.size() >= 2500, "loaded LocalePackData for " + lang)
		var pack_imbalances := 0
		var pack_raw_html := 0
		for k in pack.strings.keys():
			var rendered := LocaleService.tr_fmt(String(k))
			if rendered.contains("§") or rendered.contains("<br") or rendered.contains("<font") or rendered.contains("<b>") or rendered.contains("<i>"):
				pack_raw_html += 1
			if rendered.count("[color=") != rendered.count("[/color]") or rendered.count("[b]") != rendered.count("[/b]") or rendered.count("[i]") != rendered.count("[/i]"):
				pack_imbalances += 1
		assert_eq(pack_raw_html, 0, "zero raw HTML/§ across all keys in " + lang)
		assert_eq(pack_imbalances, 0, "zero unbalanced BBCode tags across all keys in " + lang)

	LocaleService.locale_changed.disconnect(cb)
	assert_true(signal_locales.size() >= 1, "locale_changed signal emitted on locale switch")

	# Literal $$ escaping (brief case + real epilogue.end.p3 $$11,1 / $$11.1 check)
	assert_eq(LocaleService.tr_fmt("Cadangan US$$43 miliar"), "Cadangan US$43 miliar", "$$ escapes to single $")
	LocaleService.set_locale("id")
	var ep3_id := LocaleService.tr_fmt("epilogue.end.p3")
	assert_true(ep3_id.contains("$11,1") and ep3_id.contains("$3,75") and not ep3_id.contains("$$"), "epilogue.end.p3 ID renders single $")
	LocaleService.set_locale("en")
	var ep3_en := LocaleService.tr_fmt("epilogue.end.p3")
	assert_true(ep3_en.contains("$11.1") and ep3_en.contains("$3.75") and not ep3_en.contains("$$"), "epilogue.end.p3 EN renders single $")
	LocaleService.set_locale("id")

	# Unclosed runtime § tag & malformed §</b> guard
	var malformed := LocaleService.tr_fmt("<b>§R$DRIFT$§</b>", {"DRIFT": "+1"})
	assert_true(not malformed.contains("§") and not malformed.contains("<b>"), "malformed §</b> sanitized")
	assert_eq(malformed.count("[color="), malformed.count("[/color]"), "malformed §</b> balanced color")
	assert_eq(malformed.count("[b]"), malformed.count("[/b]"), "malformed §</b> balanced bold")

	# Dark vs Light palette hex adaptation
	LocaleService.set_locale("id")
	LocaleService.active_palette_is_dark = true
	var dark_pill := LocaleService.tr_fmt("faction.golkar_pillars.g.effect", {"DRIFT": "+1"})
	LocaleService.active_palette_is_dark = false
	var light_pill := LocaleService.tr_fmt("faction.golkar_pillars.g.effect", {"DRIFT": "+1"})
	assert_ne(dark_pill, light_pill, "dark and light palettes resolve distinct hex colors")
	LocaleService.active_palette_is_dark = true

	# Stat tiers, CampaignSaveData, and UserSettingsData schemas
	var settings_res := UserSettingsData.new()
	assert_eq(settings_res.locale, "id", "UserSettingsData default locale == id")
	assert_eq(settings_res.theme_id, "midnight_slate", "UserSettingsData default theme == midnight_slate")
	assert_eq(settings_res.show_exact_numbers, false, "UserSettingsData default show_exact_numbers == false")
	var save_res := CampaignSaveData.new()
	assert_eq(save_res.turn_number, 1, "CampaignSaveData default turn_number == 1")
	assert_eq(ContentDB.catalog.all_stat_tiers.size(), 46, "46 total stat tier definitions (6*7 + 4 mil)")

	return assertions_failed
