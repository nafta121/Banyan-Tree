extends Node

signal settings_changed()
signal slots_changed()

const SLOT_IDS := ["autosave", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]
const SETTINGS_PATH := "user://settings.tres"
const SAVES_DIR := "user://saves"
const BACKUP_FORMAT_VERSION := 1

var settings: UserSettingsData = UserSettingsData.new()
var _boot_complete: bool = false


func _ready() -> void:
	_ensure_saves_dir()
	load_settings()
	_boot_complete = true


func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVES_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVES_DIR))


func _slot_path(slot_id: String) -> String:
	return SAVES_DIR.path_join(slot_id + ".tres")


func has_slot(slot_id: String) -> bool:
	if not SLOT_IDS.has(slot_id):
		return false
	return FileAccess.file_exists(_slot_path(slot_id))


func save_settings() -> void:
	if settings == null:
		settings = UserSettingsData.new()
	if settings.sss_levels.is_empty():
		var sss := get_node_or_null("/root/SSSController")
		if sss != null and "levels" in sss:
			var cur_lvls: Variant = sss.get("levels")
			if cur_lvls is Dictionary and not (cur_lvls as Dictionary).is_empty():
				settings.sss_levels = (cur_lvls as Dictionary).duplicate(true)
	ResourceSaver.save(settings, SETTINGS_PATH)
	settings_changed.emit()


func load_settings() -> void:
	var loaded_data: UserSettingsData = null
	if FileAccess.file_exists(SETTINGS_PATH):
		var raw_res := ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if raw_res is UserSettingsData:
			loaded_data = _clone_settings_resource(raw_res as UserSettingsData)
	if loaded_data == null:
		loaded_data = UserSettingsData.new()
	settings = loaded_data

	var apply_audio_buses := _boot_complete or DisplayServer.get_name() != "headless"
	_hydrate_subsystems(apply_audio_buses)
	settings_changed.emit()


func _clone_settings_resource(src: UserSettingsData) -> UserSettingsData:
	var copy := UserSettingsData.new()
	copy.locale = src.locale if not src.locale.is_empty() else "id"
	copy.theme_id = src.theme_id if not src.theme_id.is_empty() else "midnight_slate"
	copy.text_scale = clampf(float(src.text_scale), 0.85, 1.40)
	copy.show_exact_numbers = bool(src.show_exact_numbers)
	copy.show_option_effects_override = bool(src.show_option_effects_override)
	copy.music_enabled = bool(src.music_enabled)
	copy.music_volume = clampf(float(src.music_volume), 0.0, 1.0)
	copy.sfx_enabled = bool(src.sfx_enabled)
	copy.sfx_volume = clampf(float(src.sfx_volume), 0.0, 1.0)
	copy.active_genre = src.active_genre if not src.active_genre.is_empty() else "all"
	copy.weighted_shuffle = bool(src.weighted_shuffle)
	copy.auto_advance_turn = bool(src.auto_advance_turn)
	copy.default_tally_speed = maxi(1, int(src.default_tally_speed))
	copy.reduce_motion = bool(src.reduce_motion)
	copy.sss_levels = src.sss_levels.duplicate(true)
	copy.sss_hide_forecast = bool(src.sss_hide_forecast)
	copy.unlocked_achievements = src.unlocked_achievements.duplicate()
	copy.difficulty_wins = src.difficulty_wins.duplicate()
	return copy


func _hydrate_subsystems(apply_audio_buses: bool) -> void:
	if settings == null:
		return

	var loc := get_node_or_null("/root/LocaleService")
	if loc != null and loc.has_method("set_locale"):
		loc.call("set_locale", settings.locale)

	var ach := get_node_or_null("/root/AchievementService")
	if ach != null and ach.has_method("restore_state"):
		ach.call("restore_state", {
			"unlocked_ids": settings.unlocked_achievements.duplicate(),
			"difficulty_wins": settings.difficulty_wins.duplicate(),
		})

	var sss := get_node_or_null("/root/SSSController")
	if sss != null:
		if not settings.sss_levels.is_empty() and ContentDB != null and ContentDB.catalog != null:
			var norm_levels := {}
			for card in ContentDB.catalog.sss_cards:
				var raw_rank := _to_int(settings.sss_levels.get(card.id, 10), 10)
				norm_levels[card.id] = int(sss.call("snap_rank", raw_rank)) if sss.has_method("snap_rank") else raw_rank
			if sss.has_method("enforce_prereqs"):
				sss.call("enforce_prereqs", norm_levels)
			sss.set("levels", norm_levels)
		elif "levels" in sss and (sss.get("levels") as Dictionary).is_empty() and sss.has_method("_init_default_levels"):
			sss.call("_init_default_levels")
		if sss.has_method("set_hide_forecast"):
			sss.call("set_hide_forecast", settings.sss_hide_forecast)
		elif "hide_forecast" in sss:
			sss.set("hide_forecast", settings.sss_hide_forecast)

	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null and tm.has_method("apply_theme"):
		tm.call("apply_theme", settings.theme_id, settings.text_scale)

	var audio := get_node_or_null("/root/AudioController")
	if audio != null:
		if audio.has_method("set_genre"):
			audio.call("set_genre", settings.active_genre)
		if audio.has_method("set_weighted_shuffle"):
			audio.call("set_weighted_shuffle", settings.weighted_shuffle)
		if apply_audio_buses:
			if audio.has_method("set_music_enabled"):
				audio.call("set_music_enabled", settings.music_enabled)
			if audio.has_method("set_sfx_enabled"):
				audio.call("set_sfx_enabled", settings.sfx_enabled)
			if audio.has_method("set_music_volume"):
				audio.call("set_music_volume", settings.music_volume)
			if audio.has_method("set_sfx_volume"):
				audio.call("set_sfx_volume", settings.sfx_volume)
		else:
			if "music_enabled" in audio:
				audio.set("music_enabled", settings.music_enabled)
			if "sfx_enabled" in audio:
				audio.set("sfx_enabled", settings.sfx_enabled)
			if "music_volume" in audio:
				audio.set("music_volume", settings.music_volume)
			if "sfx_volume" in audio:
				audio.set("sfx_volume", settings.sfx_volume)


func save_campaign_slot(slot_id: String, note: String = "") -> bool:
	if not SLOT_IDS.has(slot_id):
		return false
	var cm := get_node_or_null("/root/CampaignManager")
	if cm == null or not bool(cm.get("game_started")):
		return false

	_ensure_saves_dir()
	var full_state: Dictionary = (cm.call("serialize_state") as Dictionary).duplicate(true)
	var now_unix := maxi(1, int(Time.get_unix_time_from_system()))
	var now_iso := Time.get_datetime_string_from_unix_time(now_unix, true) + "Z"

	var save_res := CampaignSaveData.new()
	save_res.slot_id = slot_id
	save_res.note = note
	save_res.saved_at_unix = now_unix
	save_res.saved_at_iso = now_iso
	save_res.turn_number = int(cm.get("current_turn"))
	save_res.date_str = String(cm.call("get_current_date_str")) if cm.has_method("get_current_date_str") else ""
	save_res.is_action_phase = bool(cm.get("is_action_phase"))
	save_res.selected_difficulty = String(cm.get("selected_difficulty"))
	save_res.show_option_effects = bool(cm.get("show_option_effects"))
	save_res.pc = int(cm.get("pc"))
	save_res.gov_stability_tier = String(cm.call("get_gov_stability_tier_id")) if cm.has_method("get_gov_stability_tier_id") else "precarious"
	save_res.campaign_state = full_state
	save_res.opposition_state = (full_state.get("opposition_state", {}) as Dictionary).duplicate(true) if full_state.get("opposition_state") is Dictionary else {}
	save_res.sss_state = (full_state.get("sss_run", {}) as Dictionary).duplicate(true) if full_state.get("sss_run") is Dictionary else {}
	save_res.achievement_flags = {
		"bank_bali_clean_steps": (full_state.get("bank_bali_clean_steps", {}) as Dictionary).duplicate(true) if full_state.get("bank_bali_clean_steps") is Dictionary else {},
		"timor_promise_steps": (full_state.get("timor_promise_steps", {}) as Dictionary).duplicate(true) if full_state.get("timor_promise_steps") is Dictionary else {},
		"sp3_upheld_with_high_cendana": bool(full_state.get("sp3_upheld_with_high_cendana", false)),
		"helped_rais_speaker": bool(full_state.get("helped_rais_speaker", false)),
		"lowest_gov_stability": _to_int(full_state.get("lowest_gov_stability", 100), 100),
	}

	var err := ResourceSaver.save(save_res, _slot_path(slot_id))
	if err != OK:
		return false
	slots_changed.emit()
	return true


func load_campaign_slot(slot_id: String) -> bool:
	if not SLOT_IDS.has(slot_id):
		return false
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false

	var raw_res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (raw_res is CampaignSaveData):
		return false
	var save_res := raw_res as CampaignSaveData
	if save_res.campaign_state.is_empty():
		return false

	var cm := get_node_or_null("/root/CampaignManager")
	if cm == null or not cm.has_method("restore_state"):
		return false

	var state_copy: Dictionary = save_res.campaign_state.duplicate(true)
	if not state_copy.has("opposition_state") and not save_res.opposition_state.is_empty():
		state_copy["opposition_state"] = save_res.opposition_state.duplicate(true)
	if not state_copy.has("sss_run") and not save_res.sss_state.is_empty():
		state_copy["sss_run"] = save_res.sss_state.duplicate(true)

	# Account-wide achievements in AchievementService are intentionally preserved and never downgraded on slot load.
	cm.call("restore_state", state_copy)
	return true


func delete_campaign_slot(slot_id: String) -> void:
	if not SLOT_IDS.has(slot_id):
		return
	var path := _slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		slots_changed.emit()


func list_slots_metadata() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for sid in SLOT_IDS:
		var path := _slot_path(sid)
		if not FileAccess.file_exists(path):
			entries.append({
				"slot_id": sid,
				"exists": false,
				"note": "",
				"saved_at_unix": 0,
				"saved_at_iso": "",
				"turn_number": 0,
				"date_str": "",
				"is_action_phase": false,
				"selected_difficulty": "",
				"show_option_effects": false,
				"pc": 0,
				"gov_stability_tier": "",
			})
			continue

		var raw_res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (raw_res is CampaignSaveData):
			entries.append({
				"slot_id": sid,
				"exists": false,
				"note": "",
				"saved_at_unix": 0,
				"saved_at_iso": "",
				"turn_number": 0,
				"date_str": "",
				"is_action_phase": false,
				"selected_difficulty": "",
				"show_option_effects": false,
				"pc": 0,
				"gov_stability_tier": "",
			})
			continue

		var sd := raw_res as CampaignSaveData
		entries.append({
			"slot_id": sid,
			"exists": true,
			"note": sd.note,
			"saved_at_unix": sd.saved_at_unix,
			"saved_at_iso": sd.saved_at_iso,
			"turn_number": sd.turn_number,
			"date_str": sd.date_str,
			"is_action_phase": sd.is_action_phase,
			"selected_difficulty": sd.selected_difficulty,
			"show_option_effects": sd.show_option_effects,
			"pc": sd.pc,
			"gov_stability_tier": sd.gov_stability_tier,
		})
	return entries


func export_backup_json(target_path: String) -> bool:
	var clean_target := target_path.strip_edges()
	if clean_target.is_empty():
		return false

	if settings == null:
		settings = UserSettingsData.new()

	var ach := get_node_or_null("/root/AchievementService")
	var ach_state := {"unlocked_ids": Array(settings.unlocked_achievements), "difficulty_wins": Array(settings.difficulty_wins)}
	if ach != null and ach.has_method("serialize_state"):
		ach_state = ach.call("serialize_state") as Dictionary

	var sss := get_node_or_null("/root/SSSController")
	var sss_lvls := settings.sss_levels.duplicate(true)
	if sss != null and "levels" in sss and not (sss.get("levels") as Dictionary).is_empty():
		sss_lvls = (sss.get("levels") as Dictionary).duplicate(true)

	var settings_dict := {
		"locale": settings.locale,
		"theme_id": settings.theme_id,
		"text_scale": settings.text_scale,
		"show_exact_numbers": settings.show_exact_numbers,
		"show_option_effects_override": settings.show_option_effects_override,
		"music_enabled": settings.music_enabled,
		"music_volume": settings.music_volume,
		"sfx_enabled": settings.sfx_enabled,
		"sfx_volume": settings.sfx_volume,
		"active_genre": settings.active_genre,
		"weighted_shuffle": settings.weighted_shuffle,
		"auto_advance_turn": settings.auto_advance_turn,
		"default_tally_speed": settings.default_tally_speed,
		"reduce_motion": settings.reduce_motion,
		"sss_levels": sss_lvls,
		"sss_hide_forecast": settings.sss_hide_forecast,
		"unlocked_achievements": ach_state.get("unlocked_ids", []),
		"difficulty_wins": ach_state.get("difficulty_wins", []),
	}

	var slots_dict := {}
	for sid in SLOT_IDS:
		var path := _slot_path(sid)
		if not FileAccess.file_exists(path):
			continue
		var raw_res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (raw_res is CampaignSaveData):
			continue
		var sd := raw_res as CampaignSaveData
		slots_dict[sid] = {
			"slot_id": sid,
			"note": sd.note,
			"saved_at_unix": sd.saved_at_unix,
			"saved_at_iso": sd.saved_at_iso,
			"turn_number": sd.turn_number,
			"date_str": sd.date_str,
			"is_action_phase": sd.is_action_phase,
			"selected_difficulty": sd.selected_difficulty,
			"show_option_effects": sd.show_option_effects,
			"pc": sd.pc,
			"gov_stability_tier": sd.gov_stability_tier,
			"campaign_state": sd.campaign_state.duplicate(true),
			"opposition_state": sd.opposition_state.duplicate(true),
			"sss_state": sd.sss_state.duplicate(true),
			"achievement_flags": sd.achievement_flags.duplicate(true),
		}

	var payload := {
		"version": BACKUP_FORMAT_VERSION,
		"exported_at_unix": int(Time.get_unix_time_from_system()),
		"settings": settings_dict,
		"achievements": ach_state,
		"slots": slots_dict,
	}

	var abs_parent := ProjectSettings.globalize_path(clean_target).get_base_dir()
	if not abs_parent.is_empty() and not DirAccess.dir_exists_absolute(abs_parent):
		DirAccess.make_dir_recursive_absolute(abs_parent)

	var file := FileAccess.open(clean_target, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return FileAccess.file_exists(clean_target)


func import_backup_json(source_path: String) -> bool:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty() or not FileAccess.file_exists(clean_source):
		return false

	var file := FileAccess.open(clean_source, FileAccess.READ)
	if file == null:
		return false
	var raw_text := file.get_as_text()
	file.close()
	if raw_text.strip_edges().is_empty():
		return false

	var json := JSON.new()
	if json.parse(raw_text) != OK:
		return false
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return false
	var root_dict := parsed as Dictionary
	if not root_dict.has("settings") and not root_dict.has("slots"):
		return false

	# Union local achievements with imported achievements so progress is never lost
	var merged_unlocked: PackedStringArray = PackedStringArray()
	var merged_wins: PackedStringArray = PackedStringArray()
	var ach := get_node_or_null("/root/AchievementService")
	if ach != null and ach.has_method("serialize_state"):
		var cur_ach: Dictionary = ach.call("serialize_state") as Dictionary
		_append_unique_strings(merged_unlocked, cur_ach.get("unlocked_ids", []))
		_append_unique_strings(merged_wins, cur_ach.get("difficulty_wins", []))
	elif settings != null:
		_append_unique_strings(merged_unlocked, settings.unlocked_achievements)
		_append_unique_strings(merged_wins, settings.difficulty_wins)

	if root_dict.get("achievements") is Dictionary:
		var imp_ach := root_dict["achievements"] as Dictionary
		_append_unique_strings(merged_unlocked, imp_ach.get("unlocked_ids", []))
		_append_unique_strings(merged_wins, imp_ach.get("difficulty_wins", []))

	var new_settings := UserSettingsData.new()
	if root_dict.get("settings") is Dictionary:
		var sd := root_dict["settings"] as Dictionary
		new_settings.locale = str(sd.get("locale", "id"))
		new_settings.theme_id = str(sd.get("theme_id", "midnight_slate"))
		new_settings.text_scale = clampf(_to_float(sd.get("text_scale", 1.0), 1.0), 0.85, 1.40)
		new_settings.show_exact_numbers = bool(sd.get("show_exact_numbers", false))
		new_settings.show_option_effects_override = bool(sd.get("show_option_effects_override", false))
		new_settings.music_enabled = bool(sd.get("music_enabled", true))
		new_settings.music_volume = clampf(_to_float(sd.get("music_volume", 0.3), 0.3), 0.0, 1.0)
		new_settings.sfx_enabled = bool(sd.get("sfx_enabled", true))
		new_settings.sfx_volume = clampf(_to_float(sd.get("sfx_volume", 0.8), 0.8), 0.0, 1.0)
		new_settings.active_genre = str(sd.get("active_genre", "all"))
		new_settings.weighted_shuffle = bool(sd.get("weighted_shuffle", false))
		new_settings.auto_advance_turn = bool(sd.get("auto_advance_turn", false))
		new_settings.default_tally_speed = maxi(1, _to_int(sd.get("default_tally_speed", 1), 1))
		new_settings.reduce_motion = bool(sd.get("reduce_motion", false))
		new_settings.sss_hide_forecast = bool(sd.get("sss_hide_forecast", true))
		var raw_sss_lvls: Variant = sd.get("sss_levels", {})
		var norm_sss_lvls := {}
		if raw_sss_lvls is Dictionary:
			for k in (raw_sss_lvls as Dictionary).keys():
				norm_sss_lvls[str(k)] = _to_int((raw_sss_lvls as Dictionary)[k], 10)
		new_settings.sss_levels = norm_sss_lvls
		_append_unique_strings(merged_unlocked, sd.get("unlocked_achievements", []))
		_append_unique_strings(merged_wins, sd.get("difficulty_wins", []))

	new_settings.unlocked_achievements = merged_unlocked
	new_settings.difficulty_wins = merged_wins
	settings = new_settings
	save_settings()
	_hydrate_subsystems(true)

	if root_dict.get("slots") is Dictionary:
		_ensure_saves_dir()
		var slots_in := root_dict["slots"] as Dictionary
		for raw_sid in slots_in.keys():
			var sid := str(raw_sid)
			if not SLOT_IDS.has(sid):
				continue
			if not (slots_in[raw_sid] is Dictionary):
				continue
			var slot_dict := slots_in[raw_sid] as Dictionary
			var c_state: Variant = slot_dict.get("campaign_state", {})
			if not (c_state is Dictionary) or (c_state as Dictionary).is_empty():
				continue
			var save_res := CampaignSaveData.new()
			save_res.slot_id = sid
			save_res.note = str(slot_dict.get("note", ""))
			save_res.saved_at_unix = _to_int(slot_dict.get("saved_at_unix", 0), 0)
			save_res.saved_at_iso = str(slot_dict.get("saved_at_iso", ""))
			save_res.turn_number = _to_int(slot_dict.get("turn_number", 1), 1)
			save_res.date_str = str(slot_dict.get("date_str", ""))
			save_res.is_action_phase = bool(slot_dict.get("is_action_phase", false))
			save_res.selected_difficulty = str(slot_dict.get("selected_difficulty", "historical"))
			save_res.show_option_effects = bool(slot_dict.get("show_option_effects", false))
			save_res.pc = _to_int(slot_dict.get("pc", 20), 20)
			save_res.gov_stability_tier = str(slot_dict.get("gov_stability_tier", "precarious"))
			save_res.campaign_state = (c_state as Dictionary).duplicate(true)
			save_res.opposition_state = (slot_dict.get("opposition_state", {}) as Dictionary).duplicate(true) if slot_dict.get("opposition_state") is Dictionary else {}
			save_res.sss_state = (slot_dict.get("sss_state", {}) as Dictionary).duplicate(true) if slot_dict.get("sss_state") is Dictionary else {}
			save_res.achievement_flags = (slot_dict.get("achievement_flags", {}) as Dictionary).duplicate(true) if slot_dict.get("achievement_flags") is Dictionary else {}
			ResourceSaver.save(save_res, _slot_path(sid))
		slots_changed.emit()

	return true


static func _append_unique_strings(target: PackedStringArray, source: Variant) -> void:
	if source is Array or source is PackedStringArray:
		for item in source:
			var s := str(item).strip_edges()
			if not s.is_empty() and not target.has(s):
				target.append(s)


static func _to_int(v: Variant, fallback: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(floor(v + 0.5))
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v).strip_edges()
			if s.is_valid_int():
				return s.to_int()
			if s.is_valid_float():
				return int(floor(s.to_float() + 0.5))
			return fallback
		_:
			return fallback


static func _to_float(v: Variant, fallback: float = 0.0) -> float:
	match typeof(v):
		TYPE_FLOAT:
			return v
		TYPE_INT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v).strip_edges()
			if s.is_valid_float():
				return s.to_float()
			return fallback
		_:
			return fallback
