extends TestBase


func run() -> int:
	_clean_user_test_artifacts()
	_test_review_focus_3_poros_tengah_rollback_and_achievements()
	_test_multi_slot_crud_overwrite_and_guards()
	_test_all_eight_autosave_hooks()
	_test_settings_hydration_and_backup_json_roundtrip()
	_test_review_focus_4_dual_bus_weighted_shuffle_and_corrupt_skip()
	_clean_user_test_artifacts()
	return assertions_failed


func _test_review_focus_3_poros_tengah_rollback_and_achievements() -> void:
	assert_true(SaveAndSettingsService != null, "SaveAndSettingsService autoload mounted")
	assert_true(AudioController != null, "AudioController autoload mounted")

	AchievementService.restore_state({})

	# 1. Review Focus #3: Simpan slot_1 di Turn 10 (10 fraksi, Poros Tengah 34 kursi), maju ke Turn 19 (163 kursi + anger), lalu muat slot_1
	CampaignManager.start_new_campaign("high", true)
	CampaignManager.current_turn = 10
	CampaignManager.pc = 77
	CampaignManager.stats["pop"] = 92
	AchievementService.evaluate_mid_campaign()
	assert_true(AchievementService.is_unlocked("pop_max"), "pop_max unlocked prior to manual save")

	assert_true(SaveAndSettingsService.save_campaign_slot("slot_1", "Sebelum Baligate"), "save slot_1 at Turn 10")
	CampaignManager.current_turn = 17
	CampaignManager.finish_action_phase() # Turn 18 merger -> Poros Tengah 163, PPP 0
	OppositionManager.apply_military_shock(80.0)
	assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 163, "Turn 18 merged Poros Tengah to 163 seats")
	assert_eq(CampaignManager.factions["ppp"]["seats"], 0, "Turn 18 merged PPP to 0 seats")
	assert_eq(CampaignManager.factions["pkb"]["seats"], 0, "Turn 18 merged PKB to 0 seats")
	assert_eq(CampaignManager.active_faction_order.size(), 8, "Turn 18 active_faction_order reduced to 8")
	assert_eq(OppositionManager.get_military_meter()["phase"], "anger", "TNI shock pushed meter into anger")

	# Unlock a global achievement on the post-Turn-18 timeline; loading an older save must NOT revoke it
	AchievementService.unlock("siupp_is_back")
	assert_true(AchievementService.is_unlocked("siupp_is_back"), "siupp_is_back unlocked before loading older slot")

	assert_true(SaveAndSettingsService.load_campaign_slot("slot_1"), "load slot_1 from post-Poros-Tengah turn")
	assert_eq(CampaignManager.current_turn, 10, "current_turn rolled back to 10")
	assert_eq(CampaignManager.pc, 77, "pc rolled back to 77")
	assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 34, "Poros Tengah seats rolled back to 34")
	assert_eq(CampaignManager.factions["ppp"]["seats"], 58, "PPP seats rolled back to 58")
	assert_eq(CampaignManager.factions["pkb"]["seats"], 51, "PKB seats rolled back to 51")
	assert_eq(CampaignManager.factions["poros_tengah"]["has_merged"], false, "Poros Tengah has_merged rolled back to false")
	assert_eq(CampaignManager.active_faction_order.size(), 10, "active_faction_order restored to 10 factions")
	assert_eq(OppositionManager.get_military_meter()["phase"], "patience", "TNI phase rolled back to patience")
	assert_true(AchievementService.is_unlocked("pop_max"), "pop_max preserved after loading slot_1")
	assert_true(AchievementService.is_unlocked("siupp_is_back"), "global achievement never downgraded by older slot load")

	# Pastikan pencapaian tetap bisa dibuka sesudah load manual
	CampaignManager.stats["cendana"] = 0
	AchievementService.evaluate_mid_campaign()
	assert_true(AchievementService.is_unlocked("cendana_zero"), "cendana_zero unlocks cleanly after manual slot load")

	# Prove zero mutable reference leak: mutate loaded factions & re-merge, then reload slot_1 a second time
	CampaignManager.factions["poros_tengah"]["seats"] = 99
	CampaignManager.current_turn = 17
	CampaignManager.finish_action_phase()
	assert_true(int(CampaignManager.factions["poros_tengah"]["seats"]) > 163, "mutated seats merged on second pass")
	assert_true(SaveAndSettingsService.load_campaign_slot("slot_1"), "second reload of slot_1")
	assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 34, "zero reference leak into saved slot_1 Resource")
	assert_eq(CampaignManager.factions["ppp"]["seats"], 58, "PPP still 58 on second reload")


func _test_multi_slot_crud_overwrite_and_guards() -> void:
	assert_eq(
		SaveAndSettingsService.SLOT_IDS,
		["autosave", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5"],
		"SLOT_IDS matches exact 6-slot contract"
	)

	# Reject invalid slot IDs and unstarted campaigns
	assert_false(SaveAndSettingsService.save_campaign_slot("slot_99", "Invalid"), "reject invalid slot_id on save")
	assert_false(SaveAndSettingsService.load_campaign_slot("slot_99"), "reject invalid slot_id on load")
	assert_false(SaveAndSettingsService.load_campaign_slot("slot_5"), "reject missing slot_5 on load")

	CampaignManager.game_started = false
	assert_false(SaveAndSettingsService.save_campaign_slot("slot_4", "Not started"), "reject save when game_started is false")

	# Overwrite same slot twice to verify CACHE_MODE_IGNORE loads latest disk Resource
	CampaignManager.start_new_campaign("medium", true)
	CampaignManager.current_turn = 5
	CampaignManager.pc = 41
	assert_true(SaveAndSettingsService.save_campaign_slot("slot_2", "Catatan Awal"), "first save to slot_2")

	CampaignManager.current_turn = 14
	CampaignManager.is_action_phase = true
	CampaignManager.pc = 88
	assert_true(SaveAndSettingsService.save_campaign_slot("slot_2", "Catatan Revisi"), "overwrite save to slot_2")

	CampaignManager.current_turn = 2
	CampaignManager.pc = 12
	assert_true(SaveAndSettingsService.load_campaign_slot("slot_2"), "reload overwritten slot_2")
	assert_eq(CampaignManager.current_turn, 14, "overwritten slot_2 loaded Turn 14 (no stale ResourceLoader cache)")
	assert_eq(CampaignManager.pc, 88, "overwritten slot_2 loaded PC 88")
	assert_eq(CampaignManager.is_action_phase, true, "overwritten slot_2 loaded is_action_phase == true")

	var metas := SaveAndSettingsService.list_slots_metadata()
	assert_eq(metas.size(), 6, "list_slots_metadata returns all 6 slots")
	var slot2_meta: Dictionary = metas[2]
	assert_eq(String(slot2_meta.get("slot_id", "")), "slot_2", "slot_2 metadata slot_id")
	assert_eq(bool(slot2_meta.get("exists", false)), true, "slot_2 metadata exists == true")
	assert_eq(String(slot2_meta.get("note", "")), "Catatan Revisi", "slot_2 metadata note updated")
	assert_eq(int(slot2_meta.get("turn_number", 0)), 14, "slot_2 metadata turn_number == 14")
	assert_eq(int(slot2_meta.get("pc", 0)), 88, "slot_2 metadata pc == 88")
	assert_eq(String(slot2_meta.get("selected_difficulty", "")), "medium", "slot_2 metadata difficulty == medium")
	assert_true(not String(slot2_meta.get("saved_at_iso", "")).is_empty(), "slot_2 metadata saved_at_iso populated")
	assert_true(int(slot2_meta.get("saved_at_unix", 0)) > 0, "slot_2 metadata saved_at_unix > 0")

	SaveAndSettingsService.delete_campaign_slot("slot_2")
	assert_false(SaveAndSettingsService.load_campaign_slot("slot_2"), "deleted slot_2 cannot be loaded")
	var metas_after := SaveAndSettingsService.list_slots_metadata()
	assert_eq(bool(metas_after[2].get("exists", true)), false, "deleted slot_2 metadata exists == false")


func _autosave_exists() -> bool:
	for entry in SaveAndSettingsService.list_slots_metadata():
		if String(entry.get("slot_id", "")) == "autosave":
			return bool(entry.get("exists", false))
	return false


func _test_all_eight_autosave_hooks() -> void:
	SaveAndSettingsService.delete_campaign_slot("autosave")
	assert_false(_autosave_exists(), "autosave cleared before hook tests")

	CampaignManager.start_new_campaign("easy", true)

	# Hook 1: Crisis option choice (choose_event_option)
	SaveAndSettingsService.delete_campaign_slot("autosave")
	var ev_res := CampaignManager.choose_event_option(0)
	assert_true(bool(ev_res.get("ok", false)), "Turn 1 event option chosen")
	assert_true(_autosave_exists(), "autosave triggered after choose_event_option")

	# Hook 2: Routine action (execute_routine)
	SaveAndSettingsService.delete_campaign_slot("autosave")
	CampaignManager.pc = 90
	var rt_res := CampaignManager.execute_routine("leak")
	assert_true(bool(rt_res.get("ok", false)), "routine leak executed")
	assert_true(_autosave_exists(), "autosave triggered after execute_routine")

	# Hook 3: Presidential decree (enact_decree)
	SaveAndSettingsService.delete_campaign_slot("autosave")
	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 90
	var dec_res := CampaignManager.enact_decree("civil_service_neutrality")
	assert_true(bool(dec_res.get("ok", false)), "decree civil_service_neutrality enacted")
	assert_true(_autosave_exists(), "autosave triggered after enact_decree")

	# Hook 4: Faction deal (engage_faction)
	SaveAndSettingsService.delete_campaign_slot("autosave")
	CampaignManager.pc = 90
	var fac_res := CampaignManager.engage_faction("golkar_habibie", "loyalist_icmi")
	assert_true(bool(fac_res.get("ok", false)), "faction deal loyalist_icmi engaged")
	assert_true(_autosave_exists(), "autosave triggered after engage_faction")

	# Hook 5: Turn advance (finish_action_phase)
	SaveAndSettingsService.delete_campaign_slot("autosave")
	CampaignManager.finish_action_phase()
	assert_eq(CampaignManager.current_turn, 2, "advanced to Turn 2")
	assert_true(_autosave_exists(), "autosave triggered after finish_action_phase")

	# Hook 6: Final appeal (execute_final_appeal at Turn 21)
	CampaignManager.current_turn = CampaignManager.get_speech_turn_number()
	CampaignManager.event_resolved_this_turn = true
	CampaignManager.is_action_phase = true
	CampaignManager.turn_faction_used.clear()
	CampaignManager.turn_faction_count = 0
	CampaignManager.pc = 90
	CampaignManager.factions["golkar_habibie"]["favor"] = 2
	SaveAndSettingsService.delete_campaign_slot("autosave")
	var fa_res := CampaignManager.execute_final_appeal("golkar_habibie")
	assert_true(bool(fa_res.get("ok", false)), "final appeal executed on Turn 21")
	assert_true(_autosave_exists(), "autosave triggered after execute_final_appeal")

	# Hook 7: Horse-trading (execute_horse_trade at Turn 22)
	CampaignManager.current_turn = CampaignManager.get_long_knives_turn_number()
	CampaignManager.event_resolved_this_turn = true
	CampaignManager.is_action_phase = true
	CampaignManager.pc = 50
	CampaignManager.factions["utusan_golongan"]["affinity"] = 50.0
	SaveAndSettingsService.delete_campaign_slot("autosave")
	var ht_res := CampaignManager.execute_horse_trade("utusan_golongan", 1)
	assert_true(bool(ht_res.get("ok", false)), "horse trade executed on Turn 22")
	assert_true(_autosave_exists(), "autosave triggered after execute_horse_trade")

	# Hook 8: Pre-election roll call (ElectionManager.compute_election_roll_call)
	CampaignManager.current_turn = 24
	CampaignManager.is_action_phase = false
	CampaignManager.pc = 63
	SaveAndSettingsService.delete_campaign_slot("autosave")
	var det_rng := RandomNumberGenerator.new()
	det_rng.seed = 19991020
	var summary := ElectionManager.compute_election_roll_call(det_rng)
	assert_true(summary.has("accepted"), "compute_election_roll_call returned summary")
	assert_true(_autosave_exists(), "autosave triggered right before ElectionManager roll call")

	# Verify loading that pre-election autosave restores Turn 24 & PC 63 cleanly
	CampaignManager.current_turn = 3
	CampaignManager.pc = 11
	assert_true(SaveAndSettingsService.load_campaign_slot("autosave"), "load pre-election autosave")
	assert_eq(CampaignManager.current_turn, 24, "pre-election autosave restored Turn 24")
	assert_eq(CampaignManager.pc, 63, "pre-election autosave restored PC 63")


func _test_settings_hydration_and_backup_json_roundtrip() -> void:
	# Prepare custom settings, SSS build, global achievements, and a UCN campaign slot
	SSSController.apply_preset(10)
	SSSController.set_card_rank("pc", 20)
	SSSController.set_card_rank("s_econ", 5)
	SSSController.set_hide_forecast(false)

	AchievementService.restore_state({
		"unlocked_ids": ["win_historical", "baligate_clean"],
		"difficulty_wins": ["historical", "high"],
	})

	CampaignManager.start_new_campaign("ucn", true)
	CampaignManager.current_turn = 9
	CampaignManager.pc = 54
	var ucn_t9_options := CampaignManager.get_shuffled_option_indices(9)
	assert_true(SaveAndSettingsService.save_campaign_slot("slot_3", "UCN Cadangan"), "saved UCN campaign to slot_3")

	var s := SaveAndSettingsService.settings
	s.locale = "en"
	s.theme_id = "editorial_paper"
	s.text_scale = 1.25
	s.show_exact_numbers = true
	s.show_option_effects_override = true
	s.music_enabled = true
	s.music_volume = 0.45
	s.sfx_enabled = true
	s.sfx_volume = 0.65
	s.active_genre = "national"
	s.weighted_shuffle = true
	s.auto_advance_turn = true
	s.default_tally_speed = 5
	s.reduce_motion = true
	s.sss_levels = SSSController.levels.duplicate(true)
	s.sss_hide_forecast = false
	s.unlocked_achievements = AchievementService.unlocked_ids.duplicate()
	s.difficulty_wins = AchievementService.difficulty_wins.duplicate()
	SaveAndSettingsService.save_settings()

	# Mount a temporary mock ThemeManager to verify Task 6 ThemeManager seam hydration
	var mock_tm := _MockThemeManager.new()
	mock_tm.name = "ThemeManager"
	tree.root.add_child(mock_tm)

	# Scramble live state across LocaleService, SSSController, AchievementService, and AudioController
	LocaleService.set_locale("id")
	SSSController.apply_preset(5)
	SSSController.set_hide_forecast(true)
	AchievementService.restore_state({})
	AudioController.set_genre("pop")
	AudioController.set_weighted_shuffle(false)

	SaveAndSettingsService.load_settings()

	assert_eq(LocaleService.current_locale, "en", "load_settings hydrated LocaleService to en")
	assert_eq(mock_tm.applied_theme_id, "editorial_paper", "load_settings hydrated ThemeManager theme_id")
	assert_near(mock_tm.applied_text_scale, 1.25, 0.001, "load_settings hydrated ThemeManager text_scale")
	assert_eq(int(SSSController.levels.get("pc", 0)), 20, "load_settings hydrated SSSController pc rank 20")
	assert_eq(int(SSSController.levels.get("s_econ", 0)), 5, "load_settings hydrated SSSController s_econ rank 5")
	assert_eq(SSSController.hide_forecast, false, "load_settings hydrated SSSController hide_forecast == false")
	assert_true(AchievementService.is_unlocked("win_historical"), "load_settings hydrated AchievementService win_historical")
	assert_true(AchievementService.difficulty_wins.has("historical"), "load_settings hydrated difficulty_wins")

	tree.root.remove_child(mock_tm)
	mock_tm.free()

	# Export full backup JSON (settings + achievements + all existing save slots)
	var backup_path := "user://test_backup.json"
	assert_true(SaveAndSettingsService.export_backup_json(backup_path), "export_backup_json succeeded")
	assert_true(FileAccess.file_exists(backup_path), "backup JSON file written to disk")

	# Wipe slots, reset settings to defaults, and unlock one new local achievement ("win_any")
	for sid in SaveAndSettingsService.SLOT_IDS:
		SaveAndSettingsService.delete_campaign_slot(sid)
	SaveAndSettingsService.settings = UserSettingsData.new()
	SaveAndSettingsService.save_settings()
	LocaleService.set_locale("id")
	SSSController.apply_preset(10)
	SSSController.set_hide_forecast(true)
	AchievementService.restore_state({"unlocked_ids": ["win_any"], "difficulty_wins": ["easy"]})
	CampaignManager.start_new_campaign("easy", false)

	# Verify malformed/missing backup paths fail safely without crashing
	assert_false(SaveAndSettingsService.import_backup_json("user://nonexistent_backup_999.json"), "reject missing backup JSON")
	var bad_file := FileAccess.open("user://bad_backup.json", FileAccess.WRITE)
	bad_file.store_string("{not valid json")
	bad_file.close()
	assert_false(SaveAndSettingsService.import_backup_json("user://bad_backup.json"), "reject malformed backup JSON")

	# Import valid backup JSON and verify full round-trip
	assert_true(SaveAndSettingsService.import_backup_json(backup_path), "import_backup_json succeeded")
	assert_eq(SaveAndSettingsService.settings.locale, "en", "imported locale == en")
	assert_eq(LocaleService.current_locale, "en", "LocaleService updated to en on import")
	assert_eq(SaveAndSettingsService.settings.theme_id, "editorial_paper", "imported theme_id == editorial_paper")
	assert_near(SaveAndSettingsService.settings.text_scale, 1.25, 0.001, "imported text_scale == 1.25")
	assert_eq(SaveAndSettingsService.settings.show_exact_numbers, true, "imported show_exact_numbers == true")
	assert_eq(typeof(SaveAndSettingsService.settings.default_tally_speed), TYPE_INT, "default_tally_speed normalized to TYPE_INT")
	assert_eq(SaveAndSettingsService.settings.default_tally_speed, 5, "imported default_tally_speed == 5")
	assert_eq(SaveAndSettingsService.settings.reduce_motion, true, "imported reduce_motion == true")
	assert_eq(int(SSSController.levels.get("pc", 0)), 20, "imported SSSController pc == 20")
	assert_eq(SSSController.hide_forecast, false, "imported SSSController hide_forecast == false")

	# Global achievements must union backed-up unlocks with existing local unlocks
	assert_true(AchievementService.is_unlocked("win_historical"), "backed-up win_historical restored")
	assert_true(AchievementService.is_unlocked("baligate_clean"), "backed-up baligate_clean restored")
	assert_true(AchievementService.is_unlocked("win_any"), "existing local win_any preserved on backup import")
	assert_true(AchievementService.difficulty_wins.has("historical"), "backed-up historical win restored")
	assert_true(AchievementService.difficulty_wins.has("easy"), "existing local easy win preserved")

	# Load restored UCN slot_3 from backup and verify frozen SSS levels & int types
	assert_true(SaveAndSettingsService.load_campaign_slot("slot_3"), "load imported UCN slot_3")
	assert_eq(CampaignManager.selected_difficulty, "ucn", "imported slot_3 difficulty == ucn")
	assert_eq(CampaignManager.current_turn, 9, "imported slot_3 turn == 9")
	assert_eq(CampaignManager.pc, 54, "imported slot_3 pc == 54")
	assert_eq(typeof(CampaignManager.factions["pdip"]["seats"]), TYPE_INT, "imported slot_3 seats normalized to TYPE_INT")
	assert_eq(CampaignManager.get_shuffled_option_indices(9), ucn_t9_options, "imported slot_3 shuffled options preserved")
	assert_eq(int(SSSController.active_run_levels.get("pc", 0)), 20, "imported slot_3 frozen UCN pc == 20")


func _test_review_focus_4_dual_bus_weighted_shuffle_and_corrupt_skip() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")

	# 2. Review Focus #4: Music volume 0% tidak membisukan SFX, weighted_shuffle + international tidak macet, stream gagal auto-skip
	AudioController.set_music_enabled(true)
	AudioController.set_sfx_enabled(true)
	AudioController.set_music_volume(0.0)
	AudioController.set_sfx_volume(0.8)
	assert_true(AudioServer.get_bus_volume_db(sfx_idx) > -20.0, "SFX bus stays audible (> -20 dB) when Music is 0%")
	assert_false(AudioServer.is_bus_mute(sfx_idx), "SFX bus is NOT muted when Music volume is 0.0")
	assert_true(
		AudioServer.is_bus_mute(music_idx) or AudioServer.get_bus_volume_db(music_idx) <= -79.0,
		"Music bus muted at linear 0.0"
	)

	# Reverse check: SFX volume 0% never mutes Music bus
	AudioController.set_music_volume(0.75)
	AudioController.set_sfx_volume(0.0)
	assert_true(AudioServer.get_bus_volume_db(music_idx) > -20.0, "Music bus stays audible (> -20 dB) when SFX is 0%")
	assert_false(AudioServer.is_bus_mute(music_idx), "Music bus is NOT muted when SFX volume is 0.0")
	assert_true(
		AudioServer.is_bus_mute(sfx_idx) or AudioServer.get_bus_volume_db(sfx_idx) <= -79.0,
		"SFX bus muted at linear 0.0"
	)
	AudioController.set_sfx_volume(0.8)

	# Weighted shuffle + international (empty tag intersection -> safe fallback to international genre)
	AudioController.set_genre("international")
	AudioController.set_weighted_shuffle(true)
	for _i in range(15):
		AudioController.next_track()
		assert_eq(
			ContentDB.catalog.music_tracks[AudioController.current_track_index].genre,
			"international",
			"weighted_shuffle + international always selects an international track"
		)

	# Weighted shuffle + critique in highorder_highreform (empty intersection -> safe fallback to critique genre)
	CampaignManager.start_new_campaign("easy", true)
	for sk in ["pop", "mil", "ref", "econ", "intl", "stab"]:
		CampaignManager.stats[sk] = 85
	CampaignManager.stats["cendana"] = 10
	AudioController.set_genre("critique")
	AudioController.set_weighted_shuffle(true)
	AudioController.next_track()
	assert_eq(
		ContentDB.catalog.music_tracks[AudioController.current_track_index].genre,
		"critique",
		"weighted_shuffle + critique in highorder_highreform safely falls back to critique"
	)

	# Weighted shuffle + all across all 4 (stab >= 50 x ref >= 50) quadrants
	AudioController.set_genre("all")
	var quadrants := [
		{"stab": 80, "ref": 80, "tag": "highorder_highreform"},
		{"stab": 80, "ref": 20, "tag": "highorder_lowreform"},
		{"stab": 20, "ref": 80, "tag": "loworder_highreform"},
		{"stab": 20, "ref": 20, "tag": "loworder_lowreform"},
	]
	for q in quadrants:
		var stab_v := int(q["stab"])
		var ref_v := int(q["ref"])
		var expected_tag := String(q["tag"])
		CampaignManager.stats["stab"] = stab_v
		CampaignManager.stats["ref"] = ref_v
		CampaignManager.stats["pop"] = stab_v
		CampaignManager.stats["mil"] = stab_v
		CampaignManager.stats["econ"] = stab_v
		CampaignManager.stats["intl"] = stab_v
		CampaignManager.stats["cendana"] = 100 - stab_v
		for _step in range(5):
			AudioController.next_track()
			var picked_tags := ContentDB.catalog.music_tracks[AudioController.current_track_index].weighted_tags
			assert_true(
				picked_tags.has(expected_tag),
				"weighted_shuffle in all genre matches quadrant " + expected_tag
			)

	AudioController.set_weighted_shuffle(false)

	# Missing file path auto-skips immediately without freezing and emits track_changed
	var signal_tracks: Array[MusicTrackData] = []
	var on_track := func(t: MusicTrackData) -> void:
		signal_tracks.append(t)
	AudioController.track_changed.connect(on_track)

	var orig_path := ContentDB.catalog.music_tracks[0].file_path
	ContentDB.catalog.music_tracks[0].file_path = "res://audio/music/nonexistent_corrupt_track.mp3"
	AudioController.set_genre("all")
	assert_true(AudioController.play_track(0), "play_track(0) recovers when track 0 file is missing")
	assert_true(AudioController.current_track_index != 0, "play_track(0) auto-skipped missing track 0")
	assert_true(AudioController.is_playing, "AudioController.is_playing is true after fallback track loads")
	assert_true(signal_tracks.size() >= 1 and signal_tracks[signal_tracks.size() - 1].index == AudioController.current_track_index, "track_changed emitted with active MusicTrackData")
	ContentDB.catalog.music_tracks[0].file_path = orig_path

	# Corrupt bytes on disk auto-skips cleanly without crashing
	var corrupt_path := "user://corrupt_garbage.mp3"
	var cf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	cf.store_buffer(PackedByteArray([0, 255, 13, 37, 0, 0, 99, 128]))
	cf.close()
	var orig_path_1 := ContentDB.catalog.music_tracks[1].file_path
	ContentDB.catalog.music_tracks[1].file_path = corrupt_path
	assert_true(AudioController.play_track(1), "play_track(1) recovers when track 1 contains corrupt bytes")
	assert_true(AudioController.current_track_index != 1, "play_track(1) auto-skipped corrupt track 1")
	ContentDB.catalog.music_tracks[1].file_path = orig_path_1

	# Unimported raw MP3 on disk (no .import/.remap file) loads cleanly via AudioStreamMP3 byte decoder
	var raw_mp3_path := "user://valid_unimported_test.mp3"
	var valid_mp3_bytes := FileAccess.get_file_as_bytes("res://audio/sfx/news.mp3")
	var vf := FileAccess.open(raw_mp3_path, FileAccess.WRITE)
	vf.store_buffer(valid_mp3_bytes)
	vf.close()
	var orig_path_2 := ContentDB.catalog.music_tracks[2].file_path
	ContentDB.catalog.music_tracks[2].file_path = raw_mp3_path
	assert_true(AudioController.play_track(2), "play_track(2) loads unimported raw MP3 from bytes")
	assert_eq(AudioController.current_track_index, 2, "unimported raw MP3 played directly on track 2 without skipping")
	assert_true(AudioController.get_stream_length() > 0.2, "unimported raw MP3 decoded positive duration")
	ContentDB.catalog.music_tracks[2].file_path = orig_path_2

	# Bounded termination when ALL tracks are missing (returns false cleanly, zero infinite loop)
	var saved_paths: Array[String] = []
	for t in ContentDB.catalog.music_tracks:
		saved_paths.append(t.file_path)
		t.file_path = "res://audio/music/missing_%d.mp3" % t.index
	assert_false(AudioController.play_track(0), "play_track returns false cleanly when all 36 tracks fail")
	assert_false(AudioController.is_playing, "is_playing is false when all tracks fail")
	for i in range(ContentDB.catalog.music_tracks.size()):
		ContentDB.catalog.music_tracks[i].file_path = saved_paths[i]

	AudioController.track_changed.disconnect(on_track)

	# Valid playback controls: play_track, stream length, seek_to, toggle_play_pause, prev_track, play_sfx
	assert_true(AudioController.play_track(0), "play_track(0) succeeds on valid track 0")
	assert_eq(AudioController.current_track_index, 0, "current_track_index == 0")
	assert_true(AudioController.get_stream_length() > 1.0, "get_stream_length() > 1.0s on valid MP3")
	AudioController.seek_to(1.25)
	assert_near(AudioController.get_playback_position(), 1.25, 0.1, "get_playback_position() reflects seek_to(1.25)")
	AudioController.seek_to(4.5)
	AudioController.prev_track()
	assert_eq(AudioController.current_track_index, 0, "prev_track() when >3s restarts current track")
	assert_near(AudioController.get_playback_position(), 0.0, 0.1, "prev_track() when >3s rewinds to 0.0")
	AudioController.toggle_play_pause()
	assert_false(AudioController.is_playing, "toggle_play_pause pauses active track")
	AudioController.toggle_play_pause()
	assert_true(AudioController.is_playing, "toggle_play_pause resumes paused track")
	AudioController.next_track()
	var after_next := AudioController.current_track_index
	assert_ne(after_next, 0, "next_track advances away from track 0")
	AudioController.prev_track()
	assert_eq(AudioController.current_track_index, 0, "prev_track pops track history back to track 0")

	for sfx_id in ["click", "blocked", "notification", "news", "achievement", "unknown_noop"]:
		AudioController.play_sfx(sfx_id)


func _clean_user_test_artifacts() -> void:
	var saves_dir := DirAccess.open("user://saves")
	if saves_dir != null:
		saves_dir.list_dir_begin()
		while true:
			var fname := saves_dir.get_next()
			if fname.is_empty():
				break
			if not saves_dir.current_is_dir():
				saves_dir.remove(fname)
		saves_dir.list_dir_end()

	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		for temp_file in ["settings.tres", "test_backup.json", "bad_backup.json", "corrupt_garbage.mp3", "valid_unimported_test.mp3"]:
			if user_dir.file_exists(temp_file):
				user_dir.remove(temp_file)
		if user_dir.dir_exists("saves"):
			user_dir.remove("saves")

	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, false)
		AudioServer.set_bus_volume_db(music_idx, 0.0)
	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, false)
		AudioServer.set_bus_volume_db(sfx_idx, 0.0)

	var audio := tree.root.get_node_or_null("AudioController") if (tree != null and tree.root != null) else null
	if audio != null:
		if audio.has_method("stop_all"):
			audio.call("stop_all")
		audio.call("set_genre", "all")
		audio.call("set_weighted_shuffle", false)

	var save_svc := tree.root.get_node_or_null("SaveAndSettingsService") if (tree != null and tree.root != null) else null
	if save_svc != null and "settings" in save_svc:
		save_svc.set("settings", UserSettingsData.new())

	if LocaleService != null:
		LocaleService.set_locale("id")
	if SSSController != null:
		SSSController.apply_preset(10)
		SSSController.hide_forecast = true
		SSSController.clear_run()
	if AchievementService != null:
		AchievementService.restore_state({})
	if CampaignManager != null:
		CampaignManager.game_started = false


class _MockThemeManager:
	extends Node
	var applied_theme_id: String = ""
	var applied_text_scale: float = 0.0

	func apply_theme(theme_id: String, text_scale: float) -> void:
		applied_theme_id = theme_id
		applied_text_scale = text_scale
