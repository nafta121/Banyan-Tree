extends Node

signal state_changed()
signal press_alert_queued(payload: Dictionary)

const INITIAL_PORTRAIT_FACTIONS := [
	"pdip",
	"golkar_akbar",
	"golkar_habibie",
	"poros_tengah",
	"abri",
	"ppp",
	"pkb",
	"utusan_daerah",
	"utusan_golongan",
	"other_parties",
]

const PARLIAMENT_SEATING_ORDER := [
	"pdip",
	"poros_tengah",
	"pkb",
	"ppp",
	"golkar_habibie",
	"golkar_akbar",
	"other_parties",
	"utusan_daerah",
	"utusan_golongan",
	"abri",
]

const POST_SPEECH_LOCKED_DECREES := {
	"abolish_abri_mpr_seats": true,
	"dissolve_golkar_old_guard": true,
	"ban_pdip_subversion": true,
	"enforce_asas_tunggal_ban": true,
	"purge_utusan_golongan": true,
	"direct_presidential_amendment": true,
	"regional_autonomy": true,
	"maluku_irja_division": true,
	"civil_service_neutrality": true,
	"invoke_supersemar_ii": true,
	"cendana_restoration_pact": true,
}

const GOLKAR_PILLAR_DECREES := {
	"a": "abolish_kodam_territorial",
	"abri": "abolish_kodam_territorial",
	"b": "civil_service_neutrality",
	"birokrasi": "civil_service_neutrality",
	"g": "anti_corruption",
	"golkar": "anti_corruption",
}

const HORSE_TRADE_SINGLE_COST := 1
const HORSE_TRADE_BLOC_COST := 3
const HORSE_TRADE_BLOC_OVERTURES := 5
const HORSE_TRADE_BASE_GAIN := 0.38
const HORSE_TRADE_NATIONAL_MIN := 0.50
const HORSE_TRADE_NATIONAL_RANGE := 1.00
const HORSE_TRADE_MOOD_PEAK := 0.45
const HORSE_TRADE_MOOD_FLOOR := 0.35

const STAT_KEYS := ["pop", "mil", "ref", "econ", "intl", "stab", "cendana"]
const NON_CENDANA_STATS := ["pop", "mil", "ref", "econ", "intl", "stab"]

var game_started: bool = false
var current_turn: int = 1
var is_action_phase: bool = false
var selected_difficulty: String = "historical"
var active_difficulty_data: DifficultyData = null
var show_option_effects: bool = false

var turn_executive_used: bool = false
var turn_faction_used: Dictionary = {}
var turn_faction_count: int = 0
var event_resolved_this_turn: bool = false

var stats: Dictionary = {
	"pop": 30,
	"mil": 50,
	"ref": 40,
	"econ": 20,
	"intl": 30,
	"stab": 25,
	"cendana": 95,
}
var pc: int = 20
var global_malus: float = 0.0

var factions: Dictionary = {}
var active_faction_order: PackedStringArray = PackedStringArray()

var active_decrees: Dictionary = {}
var banned_factions: Dictionary = {}
var total_seats_vacated: int = 0
var gazette_history: Array[Dictionary] = []

var min_stats: Dictionary = {"pop": 0, "mil": 0, "ref": 0, "econ": 0, "intl": 0, "stab": 0}
var max_cendana: int = 100
var min_factions: Dictionary = {}

var action_cooldowns: Dictionary = {}
var action_usage_count: Dictionary = {}
var faction_cooldowns: Dictionary = {}
var faction_usage_count: Dictionary = {}
var completed_interactions: Dictionary = {}
var horse_trade_counts: Dictionary = {}
var shuffled_event_options: Dictionary = {}
var pc_log: Array[Dictionary] = []
var prev_stats_snapshot: Dictionary = {}

var decrees_enacted_count: int = 0
var routines_used_count: int = 0
var faction_deals_count: int = 0
var final_appeals_count: int = 0
var favor_built_total: int = 0
var horse_trades_total: int = 0

var lowest_gov_stability: int = 100
var min_stat_watermarks: Dictionary = {}
var max_stat_watermarks: Dictionary = {}
var bank_bali_clean_steps: Dictionary = {}
var timor_promise_steps: Dictionary = {}
var sp3_upheld_with_high_cendana: bool = false
var helped_rais_speaker: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	_reset_factions_to_initial()


func _ready() -> void:
	if factions.is_empty():
		_reset_factions_to_initial()


static func _js_round(x: float) -> int:
	return int(floor(x + 0.5))


func stoch_round(x: float) -> int:
	var f := int(floor(x))
	return f + (1 if rng.randf() < (x - float(f)) else 0)


func clamp_pc(val: float) -> int:
	return clampi(_js_round(val), 0, 100)


func clamp_dashboard(key: String, val: float) -> int:
	var rounded := _js_round(val)
	if key == "cendana":
		return clampi(rounded, 0, max_cendana)
	var floor_v := int(min_stats.get(key, 0))
	return clampi(rounded, floor_v, 100)


func clamp_faction(key: String, val: float) -> float:
	var floor_v := float(min_factions.get(key, 0))
	var rounded_tenths := float(_js_round(val * 10.0)) / 10.0
	return clampf(rounded_tenths, floor_v, 100.0)


func sys_mod(key: String, fallback: float) -> float:
	if ContentDB == null or ContentDB.catalog == null:
		return fallback
	var v: Variant = ContentDB.catalog.system_modifiers.get(key, null)
	if v is int or v is float:
		return float(v)
	return fallback


func _get_diff_data() -> DifficultyData:
	if active_difficulty_data != null and active_difficulty_data.id == selected_difficulty:
		return active_difficulty_data
	if selected_difficulty == "ucn":
		var sss := get_node_or_null("/root/SSSController")
		if sss != null and sss.has_method("build_difficulty_data"):
			var run_lvls: Dictionary = sss.get("active_run_levels") if "active_run_levels" in sss else {}
			if not run_lvls.is_empty():
				active_difficulty_data = sss.call("build_difficulty_data", run_lvls) as DifficultyData
			else:
				active_difficulty_data = sss.call("build_difficulty_data") as DifficultyData
			return active_difficulty_data
	if ContentDB != null:
		var d := ContentDB.get_difficulty(selected_difficulty)
		if d == null:
			d = ContentDB.get_difficulty("historical")
		active_difficulty_data = d
		return d
	return DifficultyData.new()


func _start_mod(stat_key: String, diff: DifficultyData) -> int:
	if diff == null:
		return 0
	if diff.start_mods.has(stat_key):
		return int(diff.start_mods[stat_key])
	return diff.stat_mod


func _total_event_turns() -> int:
	if ContentDB != null and ContentDB.catalog != null and not ContentDB.catalog.events.is_empty():
		return ContentDB.catalog.events.size()
	return 23


func get_speech_turn_number() -> int:
	if ContentDB != null:
		var ev := ContentDB.get_event_by_id("ev_the_speech")
		if ev != null:
			return ev.turn_number
	return 21


func get_long_knives_turn_number() -> int:
	if ContentDB != null:
		var ev := ContentDB.get_event_by_id("ev_eve_of_vote")
		if ev != null:
			return ev.turn_number
	return 22


func is_past_accountability_speech() -> bool:
	return game_started and current_turn >= get_speech_turn_number()


func is_night_of_long_knives_turn() -> bool:
	if not game_started or ContentDB == null:
		return false
	var ev := ContentDB.get_event_by_turn(current_turn)
	return ev != null and ev.id == "ev_eve_of_vote"


func is_election_ready() -> bool:
	return game_started and current_turn > _total_event_turns()


func get_current_date_str() -> String:
	if LocaleService == null:
		return ""
	if not game_started:
		return LocaleService.tr_fmt("date.title_screen")
	var ev := ContentDB.get_event_by_turn(current_turn) if ContentDB != null else null
	if ev != null:
		return LocaleService.tr_fmt(ev.date_key)
	return LocaleService.tr_fmt("date.general_session")


func _reset_factions_to_initial() -> void:
	factions.clear()
	active_faction_order = PackedStringArray(INITIAL_PORTRAIT_FACTIONS)
	if ContentDB == null or ContentDB.catalog == null:
		return
	for fk in INITIAL_PORTRAIT_FACTIONS:
		var fd := ContentDB.get_faction(fk)
		if fd == null:
			continue
		factions[fk] = {
			"id": fk,
			"seats": fd.initial_seats,
			"affinity": float(fd.initial_affinity),
			"base_affinity": float(fd.initial_affinity),
			"favor": 0,
			"has_merged": false,
			"name_key": fd.name_key,
			"portrait_name_key": fd.portrait_name_key,
			"short_key": fd.short_key,
			"summary_key": fd.summary_key,
			"biography_key": fd.biography_key,
			"image_path": fd.image_path,
			"cover_image_path": fd.cover_image_path,
		}


func start_new_campaign(difficulty_id: String, forecast_enabled: bool) -> void:
	var sss := get_node_or_null("/root/SSSController")
	if difficulty_id == "ucn" and sss != null and sss.has_method("start_run"):
		selected_difficulty = "ucn"
		active_difficulty_data = sss.call("start_run") as DifficultyData
		var hide_fc := bool(sss.get("hide_forecast")) if "hide_forecast" in sss else true
		show_option_effects = not hide_fc
	else:
		if sss != null and sss.has_method("clear_run"):
			sss.call("clear_run")
		var d := ContentDB.get_difficulty(difficulty_id) if ContentDB != null else null
		if d == null:
			selected_difficulty = "historical"
			d = ContentDB.get_difficulty("historical") if ContentDB != null else DifficultyData.new()
		else:
			selected_difficulty = difficulty_id
		active_difficulty_data = d
		if selected_difficulty == "historical":
			show_option_effects = false
		else:
			show_option_effects = forecast_enabled

	var diff := _get_diff_data()

	current_turn = 1
	is_action_phase = false
	event_resolved_this_turn = false
	turn_executive_used = false
	turn_faction_used.clear()
	turn_faction_count = 0

	global_malus = 0.0
	active_decrees.clear()
	banned_factions.clear()
	total_seats_vacated = 0
	gazette_history.clear()

	min_stats = {"pop": 0, "mil": 0, "ref": 0, "econ": 0, "intl": 0, "stab": 0}
	max_cendana = 100
	min_factions.clear()

	action_cooldowns.clear()
	action_usage_count.clear()
	faction_cooldowns.clear()
	faction_usage_count.clear()
	completed_interactions.clear()
	horse_trade_counts.clear()
	shuffled_event_options.clear()
	pc_log.clear()

	decrees_enacted_count = 0
	routines_used_count = 0
	faction_deals_count = 0
	final_appeals_count = 0
	favor_built_total = 0
	horse_trades_total = 0

	bank_bali_clean_steps.clear()
	timor_promise_steps.clear()
	sp3_upheld_with_high_cendana = false
	helped_rais_speaker = false

	_reset_factions_to_initial()

	pc = clamp_pc(float(diff.pc))
	stats = {
		"pop": clamp_dashboard("pop", float(30 + _start_mod("pop", diff))),
		"mil": clamp_dashboard("mil", float(35 + _start_mod("mil", diff))),
		"ref": clamp_dashboard("ref", float(40 + _start_mod("ref", diff))),
		"econ": clamp_dashboard("econ", float(20 + _start_mod("econ", diff))),
		"intl": clamp_dashboard("intl", float(30 + _start_mod("intl", diff))),
		"stab": clamp_dashboard("stab", float(25 + _start_mod("stab", diff))),
		"cendana": clamp_dashboard("cendana", float(diff.cendana)),
	}

	for fk in factions.keys():
		var fd := ContentDB.get_faction(fk) if ContentDB != null else null
		var base_init := float(fd.initial_affinity if fd != null else 50)
		var aff := clamp_faction(fk, base_init + float(diff.affinity_mod))
		if fk == "abri":
			aff = clamp_faction("abri", 50.0 + float(diff.start_mods.get("mil", 0)))
		factions[fk]["affinity"] = aff
		factions[fk]["base_affinity"] = aff
		factions[fk]["favor"] = 0

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	prev_stats_snapshot = stats.duplicate(true)
	game_started = true

	lowest_gov_stability = get_gov_stability()
	_reset_watermarks()

	var opp := get_node_or_null("/root/OppositionManager")
	if opp != null:
		if opp.has_method("reset_for_campaign"):
			opp.call("reset_for_campaign")
		elif opp.has_method("reset"):
			opp.call("reset")

	_notify_achievements_mid_campaign()
	state_changed.emit()


func get_gov_stability() -> int:
	var total := (
		float(stats.get("pop", 0))
		+ float(stats.get("mil", 0))
		+ float(stats.get("ref", 0))
		+ float(stats.get("econ", 0))
		+ float(stats.get("intl", 0))
		+ float(stats.get("stab", 0))
		+ float(100 - int(stats.get("cendana", 0)))
	)
	return _js_round(total / 7.0)


func get_gov_stability_tier_id() -> String:
	var g := get_gov_stability()
	if g >= 80:
		return "secure"
	if g >= 60:
		return "stable"
	if g >= 40:
		return "precarious"
	if g >= 20:
		return "unstable"
	return "collapsing"


func get_stability_cost_modifier() -> int:
	var stab := int(stats.get("stab", 0))
	if stab < 40:
		return int(ceil(float(40 - stab) / 6.0))
	if stab >= 75:
		return -2
	return 0


func golkar_pillar_stands(pillar_id: String) -> bool:
	var key := pillar_id.strip_edges().to_lower()
	if not GOLKAR_PILLAR_DECREES.has(key):
		return false
	if not game_started:
		return false
	var decree_id: String = GOLKAR_PILLAR_DECREES[key]
	return not bool(active_decrees.get(decree_id, false))


static func is_good_delta(key: String, val: float) -> bool:
	if key == "cendana":
		return val < 0.0
	return val > 0.0


func _current_military_resistance() -> float:
	var opp := get_node_or_null("/root/OppositionManager")
	if opp != null and opp.has_method("get_military_resistance"):
		return float(opp.call("get_military_resistance"))
	return 0.0


func _current_pdip_cut() -> float:
	var opp := get_node_or_null("/root/OppositionManager")
	if opp != null and opp.has_method("get_pdip_cut"):
		return float(opp.call("get_pdip_cut"))
	return 0.0


func gain_factor(key: String) -> float:
	var mil_factor := 1.0 - _current_military_resistance()
	var f := mil_factor
	if key == "PC" or key == "pop" or key == "ref":
		f = mil_factor * (1.0 - _current_pdip_cut())

	var pillar_fx: Dictionary = ContentDB.catalog.golkar_pillar_effects if (ContentDB != null and ContentDB.catalog != null) else {}
	var pc_malus := float(pillar_fx.get("pcMalus", 0.20))
	var abri_res := float(pillar_fx.get("abriResistance", 0.15))

	if key == "PC" and golkar_pillar_stands("b"):
		f *= (1.0 - pc_malus)
	if key.begins_with("golkar") and golkar_pillar_stands("a"):
		f *= (1.0 - abri_res)
	return maxf(0.40, f)


func pc_gain_factor() -> float:
	return gain_factor("PC")


func _roll_effect_ranges(eff: Dictionary) -> Dictionary:
	var resolved := {}
	for raw_key in eff.keys():
		var key := String(raw_key)
		var v: Variant = eff[raw_key]
		if v is Array and v.size() == 2:
			var a := int(v[0])
			var b := int(v[1])
			var lo := mini(a, b)
			var hi := maxi(a, b)
			resolved[key] = lo + (rng.randi() % (hi - lo + 1))
		elif v is String and String(v).contains(".."):
			var parts := String(v).split("..", false)
			if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
				var a := parts[0].strip_edges().to_int()
				var b := parts[1].strip_edges().to_int()
				var lo := mini(a, b)
				var hi := maxi(a, b)
				resolved[key] = lo + (rng.randi() % (hi - lo + 1))
			else:
				resolved[key] = String(v).to_int()
		elif v is int or v is float:
			resolved[key] = v
		else:
			resolved[key] = 0
	return resolved


func _scale_effects(eff: Dictionary, good_mult: float, bad_mult: float) -> Dictionary:
	var out := {}
	for raw_key in eff.keys():
		var key := String(raw_key)
		var v := float(eff[raw_key])
		if is_zero_approx(v) or key.ends_with("_favor"):
			out[key] = eff[raw_key]
			continue
		var m := good_mult if is_good_delta(key, v) else bad_mult
		if is_equal_approx(m, 1.0):
			out[key] = eff[raw_key]
		else:
			var sgn := 1 if v > 0.0 else -1
			out[key] = sgn * maxi(1, _js_round(absf(v) * m))
	return out


func _apply_resistance_to_effects(eff: Dictionary) -> Dictionary:
	var opp := get_node_or_null("/root/OppositionManager")
	var pdip_tier := int(opp.call("get_pdip_tier")) if (opp != null and opp.has_method("get_pdip_tier")) else 0
	if (
		_current_military_resistance() <= 0.0
		and _current_pdip_cut() <= 0.0
		and pdip_tier <= 0
		and not golkar_pillar_stands("a")
		and not golkar_pillar_stands("b")
	):
		return eff

	var out := {}
	for raw_key in eff.keys():
		var key := String(raw_key)
		var v := float(eff[raw_key])
		if is_zero_approx(v) or key == "abri" or key == "mil" or key.ends_with("_favor") or not is_good_delta(key, v):
			out[key] = eff[raw_key]
			continue
		var f := gain_factor(key)
		if key == "pdip" and opp != null and opp.has_method("get_pdip_gain_mult"):
			f *= float(opp.call("get_pdip_gain_mult"))
		if f >= 1.0:
			out[key] = eff[raw_key]
		else:
			var sgn := 1 if v > 0.0 else -1
			out[key] = sgn * stoch_round(absf(v) * f)
	return out


func _log_pc_change(delta: int, reason: String) -> void:
	if delta == 0:
		return
	pc_log.append({
		"turn": current_turn,
		"delta": delta,
		"reason": reason,
		"balance_after": pc,
	})


func _apply_military_delta(delta: float) -> void:
	if not factions.has("abri") or is_zero_approx(delta):
		return
	var opp := get_node_or_null("/root/OppositionManager")
	if opp != null:
		var abri_before := float(factions["abri"]["affinity"])
		if opp.has_method("apply_military_delta"):
			opp.call("apply_military_delta", delta)
		elif opp.has_method("on_military_delta"):
			opp.call("on_military_delta", delta)
			if is_equal_approx(float(factions["abri"]["affinity"]), abri_before):
				var mult := 1.0
				if delta > 0.0 and opp.has_method("get_military_gain_mult"):
					mult = float(opp.call("get_military_gain_mult"))
				factions["abri"]["affinity"] = clamp_faction("abri", abri_before + delta * mult)
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))
		return

	factions["abri"]["affinity"] = clamp_faction("abri", float(factions["abri"]["affinity"]) + delta)
	stats["mil"] = _js_round(float(factions["abri"]["affinity"]))


func apply_effects(eff: Dictionary, update_snapshot: bool = true) -> void:
	if eff.is_empty():
		return
	if update_snapshot:
		prev_stats_snapshot = stats.duplicate(true)

	var resolved := _apply_resistance_to_effects(_roll_effect_ranges(eff))

	if resolved.has("PC"):
		var next_pc := clamp_pc(float(pc) + float(resolved["PC"]))
		var pc_delta := next_pc - pc
		pc = next_pc
		_log_pc_change(pc_delta, "effect")

	for sk in ["pop", "ref", "econ", "intl", "stab", "cendana"]:
		if resolved.has(sk):
			stats[sk] = clamp_dashboard(sk, float(stats.get(sk, 0)) + float(resolved[sk]))

	# Deduplicate mil and abri: apply only the stronger magnitude once, then sync stats.mil = round(abri.affinity)
	var mil_raw := float(resolved.get("mil", 0.0))
	var abri_raw := float(resolved.get("abri", 0.0))
	var mil_delta := mil_raw if absf(mil_raw) > absf(abri_raw) else abri_raw
	if not is_zero_approx(mil_delta):
		_apply_military_delta(mil_delta)

	var diff := _get_diff_data()
	var max_fav := diff.max_favor if diff != null else 3
	var opp := get_node_or_null("/root/OppositionManager")

	for raw_key in resolved.keys():
		var key := String(raw_key)
		if key == "abri" or key == "mil" or key == "PC" or STAT_KEYS.has(key):
			continue
		if key.ends_with("_favor"):
			var fac_key := key.trim_suffix("_favor")
			if factions.has(fac_key) and not bool(banned_factions.get(fac_key, false)):
				var before_fav := int(factions[fac_key].get("favor", 0))
				var after_fav := clampi(before_fav + int(resolved[key]), 0, max_fav)
				factions[fac_key]["favor"] = after_fav
				if after_fav > before_fav:
					favor_built_total += (after_fav - before_fav)
		elif factions.has(key) and not bool(banned_factions.get(key, false)):
			var before_aff := float(factions[key]["affinity"])
			var after_aff := clamp_faction(key, before_aff + float(resolved[key]))
			factions[key]["affinity"] = after_aff
			if key == "pdip" and opp != null and opp.has_method("on_pdip_delta"):
				opp.call("on_pdip_delta", after_aff - before_aff)

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))
	_update_watermarks()


func _snapshot_for_deltas() -> Dictionary:
	var fac_aff := {}
	var fac_fav := {}
	for fk in factions.keys():
		fac_aff[fk] = float(factions[fk]["affinity"])
		fac_fav[fk] = int(factions[fk].get("favor", 0))
	return {
		"pc": pc,
		"stats": stats.duplicate(true),
		"fac_aff": fac_aff,
		"fac_fav": fac_fav,
	}


func _compute_net_deltas(before: Dictionary) -> Dictionary:
	var deltas := {}
	var d_pc := pc - int(before.get("pc", pc))
	if d_pc != 0:
		deltas["PC"] = d_pc

	var b_stats: Dictionary = before.get("stats", {})
	for sk in STAT_KEYS:
		var ds := int(stats.get(sk, 0)) - int(b_stats.get(sk, 0))
		if ds != 0:
			deltas[sk] = ds

	var b_aff: Dictionary = before.get("fac_aff", {})
	var b_fav: Dictionary = before.get("fac_fav", {})
	for fk in factions.keys():
		if fk != "abri":
			var da := float(_js_round((float(factions[fk]["affinity"]) - float(b_aff.get(fk, 0.0))) * 10.0)) / 10.0
			if not is_zero_approx(da):
				deltas[fk] = int(da) if is_equal_approx(da, roundf(da)) else da
		var df := int(factions[fk].get("favor", 0)) - int(b_fav.get(fk, 0))
		if df != 0:
			deltas[fk + "_favor"] = df

	return deltas


func _emit_press_or_telex_alert(
	kind: String,
	outlet: String,
	category: String,
	date_str: String,
	headline: String,
	body: String,
	net_deltas: Dictionary
) -> Dictionary:
	var payload := {
		"kind": kind,
		"outlet": outlet,
		"category": category,
		"date_str": date_str,
		"headline": headline,
		"body": body,
		"net_deltas": net_deltas,
	}
	press_alert_queued.emit(payload)
	return payload


func get_shuffled_option_indices(turn_num: int = -1) -> Array[int]:
	var t := current_turn if turn_num < 0 else turn_num
	if shuffled_event_options.has(t) or shuffled_event_options.has(str(t)):
		var raw_cached: Variant = shuffled_event_options.get(t, shuffled_event_options.get(str(t), []))
		var cached: Array[int] = []
		if raw_cached is Array or raw_cached is PackedInt32Array or raw_cached is PackedInt64Array:
			for elem in raw_cached:
				cached.append(_to_int(elem))
		return cached
	var ev := ContentDB.get_event_by_turn(t) if ContentDB != null else null
	var indices: Array[int] = []
	if ev == null:
		return indices
	for i in range(ev.options.size()):
		indices.append(i)
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	shuffled_event_options[t] = indices
	return indices


func choose_event_option(option_idx: int) -> Dictionary:
	if not game_started or ContentDB == null:
		return {"ok": false, "reason": "not_started"}
	if event_resolved_this_turn:
		return {"ok": false, "reason": "already_resolved"}
	var ev := ContentDB.get_event_by_turn(current_turn)
	if ev == null or option_idx < 0 or option_idx >= ev.options.size():
		return {"ok": false, "reason": "invalid_option"}

	var opt := ev.options[option_idx]
	var snap_before := _snapshot_for_deltas()
	event_resolved_this_turn = true

	var opp := get_node_or_null("/root/OppositionManager")
	var adv_sabotaged := false
	var adv_suffix := ""
	var raw_effects: Dictionary = opt.effects

	if opp != null and opp.has_method("on_event_choice"):
		var hook_res: Variant = opp.call("on_event_choice", ev, option_idx, opt)
		if hook_res is Dictionary:
			adv_sabotaged = bool(hook_res.get("sabotaged", false))
			adv_suffix = String(hook_res.get("suffix", ""))
			if adv_sabotaged and hook_res.get("effects") is Dictionary:
				raw_effects = hook_res["effects"]

	if ev.id == "ev_bank_bali" and option_idx == 0:
		bank_bali_clean_steps["frozeEGP"] = true
	if ev.id == "ev_imf_ultimatum" and option_idx == 0:
		bank_bali_clean_steps["pwcAccess"] = true
	if ev.id == "ev_imf_ultimatum" and option_idx == 4:
		bank_bali_clean_steps["defiedIMF"] = true
	if ev.id == "ev_pwc_audit" and option_idx == 0:
		bank_bali_clean_steps["declassifiedPwC"] = true

	if not adv_sabotaged and ev.id == "ev_referendum_countdown" and option_idx == 0:
		timor_promise_steps["countdown"] = true
	if not adv_sabotaged and ev.id == "ev_timor_votes" and option_idx == 0:
		timor_promise_steps["votes"] = true
	if not adv_sabotaged and ev.id == "ev_peacekeeper_decision" and (option_idx == 0 or option_idx == 1):
		timor_promise_steps["peacekeepers"] = true

	if ev.id == "ev_assembly_convenes" and option_idx == 0:
		helped_rais_speaker = true
	if ev.id == "ev_suharto_probe" and option_idx == 1 and int(stats.get("cendana", 0)) >= 80:
		sp3_upheld_with_high_cendana = true

	var diff := _get_diff_data()
	var rolled := _roll_effect_ranges(raw_effects)
	var scaled := _scale_effects(rolled, diff.event_pos_mult, diff.event_neg_mult)
	apply_effects(scaled, true)

	var date_str := LocaleService.tr_fmt(ev.date_key) if LocaleService != null else ""
	var headline_str := LocaleService.tr_fmt(opt.press_headline_key) if LocaleService != null else ""
	var body_str := LocaleService.tr_fmt(opt.press_body_key) if LocaleService != null else ""
	if not adv_suffix.is_empty():
		body_str += "\n\n" + adv_suffix

	if current_turn >= _total_event_turns():
		is_action_phase = false
		current_turn = _total_event_turns() + 1
	else:
		is_action_phase = true

	var net_deltas := _compute_net_deltas(snap_before)
	var alert_payload := _emit_press_or_telex_alert(
		"press",
		opt.press_outlet,
		opt.press_category,
		date_str,
		headline_str,
		body_str,
		net_deltas
	)

	_notify_achievements_mid_campaign()
	if opp != null and opp.has_method("flush_popups"):
		opp.call("flush_popups")
	state_changed.emit()

	return {
		"ok": true,
		"sabotaged": adv_sabotaged,
		"net_deltas": net_deltas,
		"alert": alert_payload,
		"election_ready": is_election_ready(),
	}


func estimate_routine_pc(routine: RoutineActionData) -> int:
	if routine == null or routine.dynamic_pc.is_empty():
		return 0
	var times_used := int(action_usage_count.get(routine.id, 0))
	var repeat_decay := sys_mod("routineRepeatDecay", 0.15)
	var fatigue_factor := maxf(0.4, 1.0 - float(times_used) * repeat_decay)
	var pc_penalty := int(floor(global_malus * 0.75))
	var raw_est := _js_round(float(routine.dynamic_pc.get("base", 0)) * fatigue_factor) - pc_penalty
	var min_pc := int(routine.dynamic_pc.get("min", 0))
	var scaled := _js_round(float(raw_est) * pc_gain_factor()) if raw_est > 0 else raw_est
	return maxi(min_pc, scaled)


func can_execute_routine(id: String) -> Dictionary:
	var reasons: Array[String] = []
	if not game_started:
		reasons.append("not_started")
		return {"ok": false, "reason": "not_started", "reasons": reasons, "cooldown": 0, "estimated_pc": 0}
	var routine := ContentDB.get_routine(id) if ContentDB != null else null
	if routine == null:
		reasons.append("not_found")
		return {"ok": false, "reason": "not_found", "reasons": reasons, "cooldown": 0, "estimated_pc": 0}
	if turn_executive_used:
		reasons.append("executive_used")
	var cd := int(action_cooldowns.get(id, 0))
	if cd > 0:
		reasons.append("cooldown")
	var est_pc := estimate_routine_pc(routine)
	var ok := reasons.is_empty()
	return {
		"ok": ok,
		"reason": "" if ok else reasons[0],
		"reasons": reasons,
		"cooldown": cd,
		"estimated_pc": est_pc,
	}


func execute_routine(id: String) -> Dictionary:
	var check := can_execute_routine(id)
	if not bool(check.get("ok", false)):
		return check

	var routine := ContentDB.get_routine(id)
	var snap_before := _snapshot_for_deltas()
	prev_stats_snapshot = stats.duplicate(true)
	turn_executive_used = true

	var pc_penalty := int(floor(global_malus * 0.75))
	var times_used := int(action_usage_count.get(id, 0))
	var repeat_decay := sys_mod("routineRepeatDecay", 0.15)
	var fatigue_factor := maxf(0.4, 1.0 - float(times_used) * repeat_decay)
	action_usage_count[id] = times_used + 1
	routines_used_count += 1

	var opp := get_node_or_null("/root/OppositionManager")
	if routine.is_military_interaction and opp != null and opp.has_method("on_military_interaction"):
		opp.call("on_military_interaction")

	var chosen_alert_key := routine.alert_msg_key
	var eff_fatigue := maxf(
		sys_mod("routineEffectFloor", 0.6),
		1.0 - float(times_used) * sys_mod("routineEffectDecay", 0.06)
	)

	if not routine.effects.is_empty():
		var base_eff := _scale_effects(_roll_effect_ranges(routine.effects), eff_fatigue, 1.0) if eff_fatigue < 1.0 else routine.effects
		apply_effects(base_eff, false)

	for branch in routine.conditional_branches:
		var cond_stat := String(branch.get("stat", ""))
		var op := String(branch.get("operator", ">="))
		var cond_val := int(branch.get("value", 0))
		var cur_stat_val := int(stats.get(cond_stat, 0))
		var is_match := false
		match op:
			">=":
				is_match = cur_stat_val >= cond_val
			"<":
				is_match = cur_stat_val < cond_val
			"<=":
				is_match = cur_stat_val <= cond_val
			">":
				is_match = cur_stat_val > cond_val
			"==":
				is_match = cur_stat_val == cond_val
		if is_match:
			var br_eff: Dictionary = branch.get("effects", {})
			if not br_eff.is_empty():
				var scaled_br := _scale_effects(_roll_effect_ranges(br_eff), eff_fatigue, 1.0) if eff_fatigue < 1.0 else br_eff
				apply_effects(scaled_br, false)
			var br_alert := String(branch.get("alert_key", ""))
			if not br_alert.is_empty():
				chosen_alert_key = br_alert
			break

	if not routine.dynamic_scaling.is_empty():
		var sc := routine.dynamic_scaling
		var scale_from := String(sc.get("scaleFrom", ""))
		var offset_val := int(stats.get(scale_from, 0)) + int(sc.get("scaleOffset", 0))
		var divisor := maxi(1, int(sc.get("scaleDivisor", 1)))
		var calc_gain := int(sc.get("base", 0)) + int(floor(float(offset_val) / float(divisor)))
		var final_gain := maxi(int(sc.get("min", 0)), calc_gain)
		var target_key := String(sc.get("target", ""))
		if not target_key.is_empty():
			apply_effects({target_key: final_gain}, false)
		if not routine.success_alert_key.is_empty() or not routine.failure_alert_key.is_empty():
			chosen_alert_key = routine.success_alert_key if final_gain > 0 else routine.failure_alert_key

	var pc_gained := 0
	if not routine.dynamic_pc.is_empty():
		var raw_pc := _js_round(float(routine.dynamic_pc.get("base", 0)) * fatigue_factor) - pc_penalty
		if raw_pc > 0:
			raw_pc = stoch_round(float(raw_pc) * pc_gain_factor())
		pc_gained = maxi(int(routine.dynamic_pc.get("min", 0)), raw_pc)
		var next_pc := clamp_pc(float(pc + pc_gained))
		var actual_delta := next_pc - pc
		pc = next_pc
		_log_pc_change(actual_delta, "routine:" + id)

	var diff := _get_diff_data()
	var cd_bonus := diff.cooldown_bonus if diff != null else 0
	action_cooldowns[id] = maxi(1, routine.cooldown) + cd_bonus

	var alert_body := LocaleService.tr_fmt(chosen_alert_key) if (LocaleService != null and not chosen_alert_key.is_empty()) else ""
	if alert_body.contains("{pcGained}"):
		alert_body = alert_body.replace("{pcGained}", str(pc_gained))
	var headline := LocaleService.tr_fmt("news.dispatch_title") if LocaleService != null else "PALACE TELEX"
	var net_deltas := _compute_net_deltas(snap_before)
	var alert_payload := _emit_press_or_telex_alert(
		"telex",
		"",
		"telex",
		get_current_date_str(),
		headline,
		alert_body,
		net_deltas
	)

	_update_watermarks()
	_notify_achievements_mid_campaign()
	if opp != null and opp.has_method("flush_popups"):
		opp.call("flush_popups")
	state_changed.emit()

	return {
		"ok": true,
		"reason": "",
		"pc_gained": pc_gained,
		"net_deltas": net_deltas,
		"alert": alert_payload,
	}


func compute_decree_cost(base_cost: int) -> int:
	var diff := _get_diff_data()
	var diff_flat := diff.action_cost_mod if diff != null else 0
	var pct := 1.0 + float(diff.decree_cost_pct if diff != null else 0) / 100.0
	var stab_mod := get_stability_cost_modifier()
	return maxi(5, _js_round(float(base_cost) * pct + float(diff_flat + stab_mod)))


func is_decree_event_unlocked(decree: DecreeData) -> bool:
	if decree == null:
		return false
	if decree.unlock_event.is_empty():
		return true
	if not game_started or ContentDB == null:
		return false
	var ev := ContentDB.get_event_by_id(decree.unlock_event)
	if ev == null:
		return true
	return current_turn >= ev.turn_number


func is_decree_locked_by_session(decree: DecreeData) -> bool:
	if decree == null or not is_past_accountability_speech():
		return false
	if not decree.ban_factions.is_empty():
		return true
	if not decree.seat_recipients.is_empty():
		return true
	return POST_SPEECH_LOCKED_DECREES.has(decree.id)


func is_decree_blocked_by_mutex(decree: DecreeData) -> bool:
	if decree == null:
		return false
	for mid in decree.mutex_decrees:
		if bool(active_decrees.get(mid, false)):
			return true
	if ContentDB != null and ContentDB.catalog != null:
		for other in ContentDB.catalog.decrees:
			if bool(active_decrees.get(other.id, false)) and other.mutex_decrees.has(decree.id):
				return true
	return false


func can_enact_decree(id: String) -> Dictionary:
	var reasons: Array[String] = []
	if not game_started:
		reasons.append("not_started")
		return {"ok": false, "reason": "not_started", "reasons": reasons, "cost": 0}
	var decree := ContentDB.get_decree(id) if ContentDB != null else null
	if decree == null:
		reasons.append("not_found")
		return {"ok": false, "reason": "not_found", "reasons": reasons, "cost": 0}

	var cost := compute_decree_cost(decree.base_cost)
	var is_passed := bool(active_decrees.get(id, false))
	var is_event_unlocked := is_decree_event_unlocked(decree)
	var is_session_locked := (not is_passed) and is_decree_locked_by_session(decree)
	var is_mutex_locked := (not is_passed) and is_decree_blocked_by_mutex(decree)

	if not decree.ban_factions.is_empty() and not is_passed:
		var all_already_gone := true
		for fk in decree.ban_factions:
			if factions.has(fk) and not bool(banned_factions.get(fk, false)) and int(factions[fk]["seats"]) > 0:
				all_already_gone = false
				break
		if all_already_gone:
			is_mutex_locked = true

	if is_passed:
		reasons.append("already_passed")
	if turn_executive_used:
		reasons.append("executive_used")
	if not is_event_unlocked:
		reasons.append("event_locked")
	if is_session_locked:
		reasons.append("session_locked")
	if is_mutex_locked:
		reasons.append("mutex_locked")

	if not decree.req_decree.is_empty() and not bool(active_decrees.get(decree.req_decree, false)):
		reasons.append("req_decree:" + decree.req_decree)

	if decree.req_golkar_pillars:
		for pid in ["a", "b", "g"]:
			if golkar_pillar_stands(pid):
				reasons.append("req_golkar_pillar:" + pid)

	for req in decree.req_stats:
		var sk := String(req.get("key", ""))
		var sv := int(req.get("val", 0))
		var op := String(req.get("op", ">="))
		var cur_v := int(stats.get(sk, 0))
		if op == ">=" and cur_v < sv:
			reasons.append("req_stat:" + sk)
		elif op == "<=" and cur_v > sv:
			reasons.append("req_stat:" + sk)

	for req in decree.req_factions:
		var fk := String(req.get("key", ""))
		if not factions.has(fk) or bool(banned_factions.get(fk, false)) or int(factions[fk]["seats"]) <= 0:
			continue
		var fv := float(req.get("val", 0))
		var op := String(req.get("op", ">="))
		var cur_aff := float(factions[fk]["affinity"])
		if op == "<=" and cur_aff > fv:
			reasons.append("req_faction:" + fk)
		elif op != "<=" and cur_aff < fv:
			reasons.append("req_faction:" + fk)

	if pc < cost:
		reasons.append("insufficient_pc")

	var ok := reasons.is_empty()
	return {
		"ok": ok,
		"reason": "" if ok else reasons[0],
		"reasons": reasons,
		"cost": cost,
		"is_passed": is_passed,
		"is_mutex_locked": is_mutex_locked,
		"is_session_locked": is_session_locked,
		"is_event_unlocked": is_event_unlocked,
	}


func _is_merged_away_faction(fk: String) -> bool:
	if (fk == "ppp" or fk == "pkb") and factions.has("poros_tengah") and bool(factions["poros_tengah"].get("has_merged", false)):
		return true
	return false


func _distribute_seats_largest_remainder(transferable: int, weights_by_faction: Dictionary) -> void:
	if transferable <= 0 or weights_by_faction.is_empty():
		return
	var valid_keys: Array[String] = []
	var weight_total := 0.0
	for raw_k in weights_by_faction.keys():
		var rk := String(raw_k)
		var w := float(weights_by_faction[raw_k])
		if w > 0.0 and factions.has(rk) and not bool(banned_factions.get(rk, false)) and not _is_merged_away_faction(rk):
			valid_keys.append(rk)
			weight_total += w

	if valid_keys.is_empty() or weight_total <= 0.0:
		# Fallback: distribute across remaining active unbanned factions weighted by current seats, or vacate if none remain
		for fk in active_faction_order:
			if factions.has(fk) and not bool(banned_factions.get(fk, false)) and int(factions[fk]["seats"]) > 0:
				valid_keys.append(fk)
				weight_total += float(factions[fk]["seats"])
		if valid_keys.is_empty() or weight_total <= 0.0:
			total_seats_vacated += transferable
			return
		var fallback_entries: Array[Dictionary] = []
		var fb_allocated := 0
		for idx in range(valid_keys.size()):
			var rk := valid_keys[idx]
			var exact := (float(factions[rk]["seats"]) / weight_total) * float(transferable)
			var base_share := int(floor(exact))
			factions[rk]["seats"] = int(factions[rk]["seats"]) + base_share
			fb_allocated += base_share
			fallback_entries.append({"key": rk, "rem": exact - float(base_share), "idx": idx})
		var fb_leftover := transferable - fb_allocated
		fallback_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a["rem"]), float(b["rem"])):
				return float(a["rem"]) > float(b["rem"])
			return int(a["idx"]) < int(b["idx"])
		)
		for i in range(fb_leftover):
			var win_k := String(fallback_entries[i]["key"])
			factions[win_k]["seats"] = int(factions[win_k]["seats"]) + 1
		return

	var entries: Array[Dictionary] = []
	var allocated := 0
	for idx in range(valid_keys.size()):
		var rk := valid_keys[idx]
		var w := float(weights_by_faction[rk])
		var exact := (w / weight_total) * float(transferable)
		var base_share := int(floor(exact))
		factions[rk]["seats"] = int(factions[rk]["seats"]) + base_share
		allocated += base_share
		entries.append({"key": rk, "rem": exact - float(base_share), "idx": idx})

	var leftover := transferable - allocated
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["rem"]), float(b["rem"])):
			return float(a["rem"]) > float(b["rem"])
		return int(a["idx"]) < int(b["idx"])
	)
	for i in range(leftover):
		var win_k := String(entries[i]["key"])
		factions[win_k]["seats"] = int(factions[win_k]["seats"]) + 1


func enact_decree(id: String) -> Dictionary:
	var check := can_enact_decree(id)
	if not bool(check.get("ok", false)):
		return check

	var decree := ContentDB.get_decree(id)
	var cost := int(check.get("cost", compute_decree_cost(decree.base_cost)))
	var snap_before := _snapshot_for_deltas()
	prev_stats_snapshot = stats.duplicate(true)

	pc = clamp_pc(float(pc - cost))
	_log_pc_change(-cost, "decree:" + id)
	active_decrees[id] = true
	turn_executive_used = true
	decrees_enacted_count += 1

	var opp := get_node_or_null("/root/OppositionManager")
	var adv_seat_snap: Variant = null
	if opp != null and opp.has_method("snapshot_seats"):
		adv_seat_snap = opp.call("snapshot_seats")

	var dissolved_this_decree: Array[String] = []
	var vacated_seats := 0
	if not decree.ban_factions.is_empty():
		var total_banned_seats := 0
		for fk in decree.ban_factions:
			banned_factions[fk] = true
			dissolved_this_decree.append(fk)
			if factions.has(fk) and int(factions[fk]["seats"]) > 0:
				total_banned_seats += int(factions[fk]["seats"])
				factions[fk]["seats"] = 0
				factions[fk]["favor"] = 0

		vacated_seats = clampi(decree.seats_vacated, 0, total_banned_seats)
		total_seats_vacated += vacated_seats
		var transferable_seats := total_banned_seats - vacated_seats
		if transferable_seats > 0:
			_distribute_seats_largest_remainder(transferable_seats, decree.seat_recipients)

	var seat_changes: Variant = decree.locks.get("seatChanges", null)
	if seat_changes is Dictionary:
		for raw_fk in seat_changes.keys():
			var fk := String(raw_fk)
			if factions.has(fk) and not bool(banned_factions.get(fk, false)):
				factions[fk]["seats"] = maxi(0, int(factions[fk]["seats"]) + int(seat_changes[raw_fk]))

	if opp != null and opp.has_method("record_seat_transfer"):
		opp.call("record_seat_transfer", adv_seat_snap)

	if not decree.stat_effects.is_empty():
		apply_effects(decree.stat_effects, false)
	if not decree.faction_effects.is_empty():
		apply_effects(decree.faction_effects, false)

	if not decree.min_stats.is_empty():
		var stat_cap := int(sys_mod("maxStatFloor", 90.0))
		var stat_grant := int(sys_mod("floorEnactGrant", 5.0))
		for raw_stat in decree.min_stats.keys():
			var stat_k := String(raw_stat)
			var target := mini(stat_cap, int(decree.min_stats[raw_stat]))
			var start_floor := mini(target, int(stats.get(stat_k, 0)) + stat_grant)
			min_stats[stat_k] = maxi(int(min_stats.get(stat_k, 0)), start_floor)
			stats[stat_k] = clamp_dashboard(stat_k, float(maxi(int(stats.get(stat_k, 0)), int(min_stats[stat_k]))))

	if decree.max_cendana >= 0:
		max_cendana = mini(max_cendana, decree.max_cendana)
		stats["cendana"] = clamp_dashboard("cendana", float(mini(int(stats.get("cendana", 0)), max_cendana)))

	if not decree.min_factions.is_empty():
		var fac_cap := float(sys_mod("maxFactionFloor", 85.0))
		var fac_grant := float(sys_mod("factionFloorEnactGrant", 8.0))
		for raw_fac in decree.min_factions.keys():
			var fac_k := String(raw_fac)
			var target := minf(fac_cap, float(decree.min_factions[raw_fac]))
			var cur_aff := float(factions[fac_k]["affinity"]) if factions.has(fac_k) else 0.0
			var start_floor := minf(target, cur_aff + fac_grant)
			min_factions[fac_k] = maxf(float(min_factions.get(fac_k, 0.0)), start_floor)
			if factions.has(fac_k):
				factions[fac_k]["affinity"] = clamp_faction(fac_k, maxf(float(factions[fac_k]["affinity"]), float(min_factions[fac_k])))

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	gazette_history.append({
		"id": decree.id,
		"turn": current_turn,
		"date_str": get_current_date_str(),
		"text_key": decree.text_key,
		"dissolved_factions": dissolved_this_decree,
		"seats_vacated": vacated_seats,
	})

	if opp != null:
		if opp.has_method("on_decree_enacted"):
			opp.call("on_decree_enacted", decree)
		elif decree.military_shock > 0 and opp.has_method("apply_military_shock"):
			opp.call("apply_military_shock", float(decree.military_shock))

	var alert_body := LocaleService.tr_fmt(decree.alert_msg_key) if (LocaleService != null and not decree.alert_msg_key.is_empty()) else ""
	if alert_body.is_empty() and LocaleService != null:
		alert_body = LocaleService.tr_fmt("decree.default_alert")
	var headline := LocaleService.tr_fmt("news.dispatch_title") if LocaleService != null else "PALACE TELEX"
	var net_deltas := _compute_net_deltas(snap_before)
	var alert_payload := _emit_press_or_telex_alert(
		"telex",
		"",
		"telex",
		get_current_date_str(),
		headline,
		alert_body,
		net_deltas
	)

	_update_watermarks()
	_notify_achievements_mid_campaign()
	if opp != null and opp.has_method("flush_popups"):
		opp.call("flush_popups")
	state_changed.emit()

	return {
		"ok": true,
		"reason": "",
		"cost": cost,
		"net_deltas": net_deltas,
		"alert": alert_payload,
	}


func get_faction_deals(faction_id: String) -> Array[FactionDealData]:
	var empty: Array[FactionDealData] = []
	if ContentDB == null:
		return empty
	var fd := ContentDB.get_faction(faction_id)
	if fd == null:
		return empty
	if factions.has(faction_id) and bool(factions[faction_id].get("has_merged", false)) and fd.merged_state != null:
		return fd.merged_state.deals
	return fd.deals


func get_faction_moods(faction_id: String) -> Array[StatTierData]:
	var empty: Array[StatTierData] = []
	if ContentDB == null:
		return empty
	var fd := ContentDB.get_faction(faction_id)
	if fd == null:
		return empty
	if factions.has(faction_id) and bool(factions[faction_id].get("has_merged", false)) and fd.merged_state != null:
		return fd.merged_state.moods
	return fd.moods


func get_faction_mood(faction_id: String, affinity: float) -> StatTierData:
	var moods := get_faction_moods(faction_id)
	for tier in moods:
		if affinity >= float(tier.min_value):
			return tier
	return moods[moods.size() - 1] if not moods.is_empty() else null


func get_faction_leverage(faction_id: String) -> Dictionary:
	var fd := ContentDB.get_faction(faction_id) if ContentDB != null else null
	if fd == null or fd.leverage_metrics.is_empty():
		return {
			"val": 50,
			"tier_id": "moderate",
			"cost_mult": 1.0,
			"gain_mult": 1.0,
		}
	var sum_m := 0.0
	for mk in fd.leverage_metrics:
		sum_m += float(stats.get(mk, 0))
	var avg := _js_round(sum_m / float(fd.leverage_metrics.size()))
	var tier_id := "nonexistent"
	if avg >= 80:
		tier_id = "absolute"
	elif avg >= 60:
		tier_id = "strong"
	elif avg >= 40:
		tier_id = "moderate"
	elif avg >= 20:
		tier_id = "weak"

	var t01 := clampf(float(avg), 0.0, 100.0) / 100.0
	var cost_mult := float(_js_round((1.30 - 0.55 * t01) * 1000.0)) / 1000.0
	var gain_mult := float(_js_round((0.75 + 0.75 * t01) * 1000.0)) / 1000.0
	return {
		"val": avg,
		"tier_id": tier_id,
		"cost_mult": cost_mult,
		"gain_mult": gain_mult,
	}


func _compute_turn_faction_count() -> int:
	var total := 0
	for fk in turn_faction_used.keys():
		total += maxi(0, int(turn_faction_used[fk]))
	return total


func is_faction_limit_reached() -> bool:
	var used_any := _compute_turn_faction_count() > 0
	return used_any and (is_past_accountability_speech() or is_night_of_long_knives_turn())


func get_faction_surcharge() -> int:
	var cnt := _compute_turn_faction_count()
	if is_past_accountability_speech() or cnt <= 0:
		return 0
	return _js_round(float(cnt) * sys_mod("factionEngageSurcharge", 5.0))


func compute_faction_action_cost(faction_id: String, base_cost: int) -> int:
	var surcharge := get_faction_surcharge()
	if base_cost <= 0:
		return surcharge
	var diff := _get_diff_data()
	var diff_flat := diff.action_cost_mod if diff != null else 0
	var pct := 1.0 + float(diff.cost_pct if diff != null else 0) / 100.0
	var stab_mod := get_stability_cost_modifier()
	var lev := get_faction_leverage(faction_id)
	var cost_mult := float(lev.get("cost_mult", 1.0))
	var street_mult := 1.0
	var opp := get_node_or_null("/root/OppositionManager")
	if faction_id == "pdip" and opp != null and opp.has_method("get_pdip_cost_mult"):
		street_mult = float(opp.call("get_pdip_cost_mult"))
	var core := _js_round((float(base_cost) * pct * cost_mult + float(diff_flat + stab_mod)) * street_mult)
	return maxi(3, core) + surcharge


func _find_faction_deal(faction_id: String, deal_id: String) -> FactionDealData:
	for deal in get_faction_deals(faction_id):
		if deal.id == deal_id:
			return deal
	return null


func _find_final_appeal_deal(faction_id: String) -> FactionDealData:
	for deal in get_faction_deals(faction_id):
		if deal.is_final_appeal:
			return deal
	return null


func can_engage_faction(faction_id: String, deal_id: String) -> Dictionary:
	var reasons: Array[String] = []
	if not game_started:
		reasons.append("not_started")
		return {"ok": false, "reason": "not_started", "reasons": reasons, "cost": 0, "surcharge": 0, "cooldown": 0}
	if not factions.has(faction_id) or bool(banned_factions.get(faction_id, false)) or int(factions[faction_id]["seats"]) <= 0:
		reasons.append("faction_inactive")
		return {"ok": false, "reason": "faction_inactive", "reasons": reasons, "cost": 0, "surcharge": 0, "cooldown": 0}

	var deal := _find_faction_deal(faction_id, deal_id)
	if deal == null:
		reasons.append("deal_not_found")
		return {"ok": false, "reason": "deal_not_found", "reasons": reasons, "cost": 0, "surcharge": 0, "cooldown": 0}

	var surcharge := get_faction_surcharge()
	var cost := compute_faction_action_cost(faction_id, deal.cost)
	var action_key := faction_id + ":" + deal.id
	var cd := int(faction_cooldowns.get(action_key, 0))
	var is_committed := (not deal.repeatable) and bool(completed_interactions.get(deal.id, false))
	var is_post_speech_locked := is_past_accountability_speech() and (not deal.is_final_appeal)
	var is_mutex_locked := (not deal.mutex_group.is_empty()) and bool(completed_interactions.get(deal.mutex_group, false)) and (not is_committed)

	if deal.min_turn > 0 and current_turn < deal.min_turn:
		reasons.append("before_min_turn")
	if deal.max_turn > 0 and current_turn > deal.max_turn:
		reasons.append("after_max_turn")
	if is_faction_limit_reached():
		reasons.append("turn_faction_limit")
	if is_post_speech_locked:
		reasons.append("session_closed")
	if is_committed:
		reasons.append("already_committed")
	if is_mutex_locked:
		reasons.append("mutex_locked")
	if cd > 0:
		reasons.append("cooldown")

	if deal.min_affinity >= 0 and float(factions[faction_id]["affinity"]) < float(deal.min_affinity):
		reasons.append("min_affinity")
	if not deal.req_decree.is_empty() and not bool(active_decrees.get(deal.req_decree, false)):
		reasons.append("req_decree:" + deal.req_decree)
	if not deal.min_stat_key.is_empty() and deal.min_stat_val >= 0:
		var cur_sv := int(stats.get(deal.min_stat_key, 0))
		if deal.min_stat_key == "cendana":
			if cur_sv > deal.min_stat_val:
				reasons.append("min_stat:" + deal.min_stat_key)
		else:
			if cur_sv < deal.min_stat_val:
				reasons.append("min_stat:" + deal.min_stat_key)

	if pc < cost:
		reasons.append("insufficient_pc")

	var ok := reasons.is_empty()
	return {
		"ok": ok,
		"reason": "" if ok else reasons[0],
		"reasons": reasons,
		"cost": cost,
		"surcharge": surcharge,
		"cooldown": cd,
		"is_committed": is_committed,
		"is_locked": is_post_speech_locked or is_mutex_locked,
	}


func engage_faction(faction_id: String, deal_id: String) -> Dictionary:
	var check := can_engage_faction(faction_id, deal_id)
	if not bool(check.get("ok", false)):
		return check

	var deal := _find_faction_deal(faction_id, deal_id)
	var cost := int(check.get("cost", compute_faction_action_cost(faction_id, deal.cost)))
	var snap_before := _snapshot_for_deltas()
	prev_stats_snapshot = stats.duplicate(true)

	pc = clamp_pc(float(pc - cost))
	_log_pc_change(-cost, "faction:" + faction_id + ":" + deal_id)
	turn_faction_used[faction_id] = int(turn_faction_used.get(faction_id, 0)) + 1
	turn_faction_count = _compute_turn_faction_count()
	faction_deals_count += 1
	if deal.is_final_appeal:
		final_appeals_count += 1

	var opp := get_node_or_null("/root/OppositionManager")
	if faction_id == "abri" and opp != null and opp.has_method("on_military_interaction"):
		opp.call("on_military_interaction")
	if faction_id == "pdip" and opp != null and opp.has_method("on_pdip_interaction"):
		opp.call("on_pdip_interaction")

	var mil_res_at_start := _current_military_resistance() if faction_id != "abri" else 0.0

	if not deal.repeatable:
		completed_interactions[deal.id] = true
	if deal.locks_group and not deal.mutex_group.is_empty():
		completed_interactions[deal.mutex_group] = true

	var action_key := faction_id + ":" + deal.id
	var times_used := int(faction_usage_count.get(action_key, 0)) + 1
	faction_usage_count[action_key] = times_used

	var diff := _get_diff_data()
	if deal.repeatable:
		faction_cooldowns[action_key] = 3 + (diff.cooldown_bonus if diff != null else 0)

	var lev := get_faction_leverage(faction_id)
	var lev_gain_mult := float(lev.get("gain_mult", 1.0))
	var delta_from_leverage := 0

	if not deal.effects.is_empty():
		var effects_to_apply := _roll_effect_ranges(deal.effects)
		if effects_to_apply.has(faction_id) and float(effects_to_apply[faction_id]) > 0.0:
			var orig_val := float(effects_to_apply[faction_id])
			var repeat_mult := (
				maxf(sys_mod("factionRepeatFloor", 0.5), 1.0 - float(times_used - 1) * sys_mod("factionRepeatDecay", 0.2))
				if deal.repeatable
				else 1.0
			)
			var gain_mult := diff.gain_mult if diff != null else 1.0
			var mod_val := maxi(1, _js_round(orig_val * lev_gain_mult * repeat_mult * gain_mult))
			delta_from_leverage = _js_round(orig_val * lev_gain_mult) - _js_round(orig_val)
			effects_to_apply[faction_id] = mod_val
		apply_effects(effects_to_apply, false)

	var favor_bonus := 0
	var cur_favor := int(factions[faction_id].get("favor", 0))
	if deal.is_final_appeal and cur_favor > 0:
		favor_bonus = mini(28, _js_round(sqrt(float(cur_favor)) * 14.0))
		if faction_id == "abri" and opp != null and opp.has_method("get_military_gain_mult"):
			favor_bonus = _js_round(float(favor_bonus) * float(opp.call("get_military_gain_mult")))
		elif mil_res_at_start > 0.0:
			favor_bonus = _js_round(float(favor_bonus) * (1.0 - mil_res_at_start))
		if faction_id == "pdip" and opp != null and opp.has_method("get_pdip_gain_mult"):
			favor_bonus = _js_round(float(favor_bonus) * float(opp.call("get_pdip_gain_mult")))
		factions[faction_id]["favor"] = 0
		factions[faction_id]["affinity"] = clamp_faction(faction_id, float(factions[faction_id]["affinity"]) + float(favor_bonus))
		if faction_id == "pdip" and opp != null and opp.has_method("on_pdip_delta"):
			opp.call("on_pdip_delta", float(favor_bonus))

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	var alert_body := LocaleService.tr_fmt(deal.alert_msg_key) if (LocaleService != null and not deal.alert_msg_key.is_empty()) else ""
	if alert_body.is_empty() and LocaleService != null:
		alert_body = LocaleService.tr_fmt("faction.default_alert")
	if LocaleService != null:
		if delta_from_leverage > 0:
			alert_body += "\n\n[b]" + LocaleService.tr_fmt("faction.leverage_boost") + "[/b]"
		elif delta_from_leverage < 0:
			alert_body += "\n\n[b]" + LocaleService.tr_fmt("faction.leverage_blunt") + "[/b]"
		if favor_bonus > 0:
			alert_body += "\n\n[b]" + LocaleService.tr_fmt("faction.favor_redeemed") + "[/b]"
		if mil_res_at_start > 0.0:
			alert_body += "\n\n[b]" + LocaleService.tr_fmt("military.blunted", {"RES": str(_js_round(mil_res_at_start * 100.0))}) + "[/b]"

	var headline := LocaleService.tr_fmt("news.dispatch_title") if LocaleService != null else "PALACE TELEX"
	var net_deltas := _compute_net_deltas(snap_before)
	var alert_payload := _emit_press_or_telex_alert(
		"telex",
		"",
		"telex",
		get_current_date_str(),
		headline,
		alert_body,
		net_deltas
	)

	_update_watermarks()
	_notify_achievements_mid_campaign()
	if opp != null and opp.has_method("flush_popups"):
		opp.call("flush_popups")
	state_changed.emit()

	return {
		"ok": true,
		"reason": "",
		"cost": cost,
		"favor_bonus": favor_bonus,
		"net_deltas": net_deltas,
		"alert": alert_payload,
	}


func can_final_appeal(faction_id: String) -> Dictionary:
	var final_deal := _find_final_appeal_deal(faction_id)
	if final_deal == null:
		var reasons: Array[String] = ["no_final_appeal"]
		return {"ok": false, "reason": "no_final_appeal", "reasons": reasons, "cost": 0, "deal_id": ""}
	var check := can_engage_faction(faction_id, final_deal.id)
	check["deal_id"] = final_deal.id
	return check


func execute_final_appeal(faction_id: String) -> Dictionary:
	var final_deal := _find_final_appeal_deal(faction_id)
	if final_deal == null:
		return {"ok": false, "reason": "no_final_appeal"}
	return engage_faction(faction_id, final_deal.id)


func get_horse_trade_cost(faction_id: String, overtures: int) -> int:
	var n := HORSE_TRADE_BLOC_OVERTURES if overtures >= HORSE_TRADE_BLOC_OVERTURES else maxi(1, overtures)
	var base_cost := HORSE_TRADE_BLOC_COST if n >= HORSE_TRADE_BLOC_OVERTURES else n * HORSE_TRADE_SINGLE_COST
	var opp := get_node_or_null("/root/OppositionManager")
	if faction_id == "pdip" and opp != null and opp.has_method("get_pdip_cost_mult"):
		return maxi(base_cost, _js_round(float(base_cost) * float(opp.call("get_pdip_cost_mult"))))
	return base_cost


func get_horse_trade_receptiveness_mult(faction_id: String, affinity: float) -> float:
	var moods := get_faction_moods(faction_id)
	var pos := 0.5
	if moods.size() > 1:
		var matched_idx := moods.size() - 1
		for i in range(moods.size()):
			if affinity >= float(moods[i].min_value):
				matched_idx = i
				break
		pos = float(matched_idx) / float(moods.size() - 1)
	var max_dist := maxf(HORSE_TRADE_MOOD_PEAK, 1.0 - HORSE_TRADE_MOOD_PEAK)
	var d := (pos - HORSE_TRADE_MOOD_PEAK) / max_dist
	return HORSE_TRADE_MOOD_FLOOR + (1.0 - HORSE_TRADE_MOOD_FLOOR) * (1.0 - d * d)


func execute_horse_trade(faction_id: String, overtures: int) -> Dictionary:
	if not game_started or not is_action_phase or not is_night_of_long_knives_turn():
		return {"ok": false, "reason": "not_long_knives_turn"}
	if not factions.has(faction_id) or bool(banned_factions.get(faction_id, false)) or int(factions[faction_id]["seats"]) <= 0:
		return {"ok": false, "reason": "faction_inactive"}

	var opp := get_node_or_null("/root/OppositionManager")
	if faction_id == "pdip" and opp != null and opp.has_method("is_pdip_locked") and bool(opp.call("is_pdip_locked")):
		return {"ok": false, "reason": "pdip_street_locked"}

	var n := HORSE_TRADE_BLOC_OVERTURES if overtures >= HORSE_TRADE_BLOC_OVERTURES else 1
	var cost := get_horse_trade_cost(faction_id, n)
	if pc < cost:
		return {"ok": false, "reason": "insufficient_pc", "cost": cost}
	if float(factions[faction_id]["affinity"]) >= 100.0:
		return {"ok": false, "reason": "affinity_maxed", "cost": cost}

	prev_stats_snapshot = stats.duplicate(true)
	var aff_before := float(factions[faction_id]["affinity"])
	pc = clamp_pc(float(pc - cost))
	_log_pc_change(-cost, "horse_trade:" + faction_id)

	var national_mult := HORSE_TRADE_NATIONAL_MIN + (float(get_gov_stability()) / 100.0) * HORSE_TRADE_NATIONAL_RANGE
	var stance_mult := get_horse_trade_receptiveness_mult(faction_id, aff_before)

	var total_gain := 0.0
	var prior_uses := int(horse_trade_counts.get(faction_id, 0))
	for _i in range(n):
		var fatigue := maxf(0.55, 1.0 - float(prior_uses) * 0.015)
		var jitter := 0.9 + rng.randf() * 0.2
		total_gain += HORSE_TRADE_BASE_GAIN * national_mult * stance_mult * fatigue * jitter
		prior_uses += 1
	horse_trade_counts[faction_id] = prior_uses
	horse_trades_total += n

	if faction_id == "abri":
		_apply_military_delta(total_gain)
	else:
		total_gain *= (1.0 - _current_military_resistance())
		if faction_id == "pdip" and opp != null:
			if opp.has_method("get_pdip_gain_mult"):
				total_gain *= float(opp.call("get_pdip_gain_mult"))
			if opp.has_method("on_pdip_delta"):
				opp.call("on_pdip_delta", total_gain)
		factions[faction_id]["affinity"] = clamp_faction(faction_id, aff_before + total_gain)

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	var aff_after := float(factions[faction_id]["affinity"])
	_update_watermarks()
	_notify_achievements_mid_campaign()
	state_changed.emit()

	return {
		"ok": true,
		"cost": cost,
		"overtures": n,
		"affinity_delta": aff_after - aff_before,
	}


func ramp_decree_floors() -> void:
	if ContentDB == null or ContentDB.catalog == null:
		return
	var stat_cap := int(sys_mod("maxStatFloor", 90.0))
	var fac_cap := float(sys_mod("maxFactionFloor", 85.0))
	var stat_ramp := int(sys_mod("floorRampStat", 4.0))
	var fac_ramp := float(sys_mod("floorRampFaction", 5.0))

	for d in ContentDB.catalog.decrees:
		if not bool(active_decrees.get(d.id, false)):
			continue
		for raw_stat in d.min_stats.keys():
			var stat_k := String(raw_stat)
			if stat_k == "cendana" or stat_k == "mil":
				continue
			var target := mini(stat_cap, int(d.min_stats[raw_stat]))
			var cur_floor := int(min_stats.get(stat_k, 0))
			if cur_floor < target:
				min_stats[stat_k] = mini(target, cur_floor + stat_ramp)
				stats[stat_k] = clamp_dashboard(stat_k, float(stats.get(stat_k, 0)))

		for raw_fac in d.min_factions.keys():
			var fac_k := String(raw_fac)
			if not factions.has(fac_k) or bool(banned_factions.get(fac_k, false)):
				continue
			var target := minf(fac_cap, float(d.min_factions[raw_fac]))
			var cur_floor := float(min_factions.get(fac_k, 0.0))
			if cur_floor < target:
				min_factions[fac_k] = minf(target, cur_floor + fac_ramp)
				factions[fac_k]["affinity"] = clamp_faction(fac_k, float(factions[fac_k]["affinity"]))


func apply_end_of_turn_economy() -> Dictionary:
	ramp_decree_floors()
	var diff := _get_diff_data()
	var gov_stability := get_gov_stability()

	var low_thresh := int(sys_mod("lowStatThreshold", 40.0))
	var high_thresh := int(sys_mod("highStatThreshold", 60.0))
	var malus_mult := sys_mod("malusMultiplier", 0.45)
	var malus_decay_normal := sys_mod("malusDecayNormal", 0.5)
	var malus_decay_high := sys_mod("malusDecayHigh", 1.5)
	var max_global_malus := sys_mod("maxGlobalMalus", 10.0)
	var bonus_mult := sys_mod("bonusMultiplier", 0.3)
	var max_bonus_drift := sys_mod("maxBonusDrift", 2.0)
	var loyalist_mitigation := sys_mod("loyalistDrainMitigation", 0.35)

	var severity_malus := 0
	var severity_bonus := 0

	if gov_stability < low_thresh:
		var deficit := low_thresh - gov_stability
		severity_malus = int(ceil(float(deficit) / 5.0))
		global_malus = minf(max_global_malus, global_malus + float(severity_malus) * malus_mult)
	elif gov_stability >= high_thresh:
		var surplus := gov_stability - high_thresh
		severity_bonus = int(ceil(float(surplus) / 5.0))
		global_malus = maxf(0.0, global_malus - malus_decay_high)
	else:
		global_malus = maxf(0.0, global_malus - malus_decay_normal)

	var cap := diff.malus_cap if diff != null else 3.25
	var current_drain := minf(cap, global_malus / 2.0)
	var pc_penalty := int(floor(global_malus * 0.75))

	var current_bonus := 0.0
	if severity_bonus > 0:
		current_bonus = minf(max_bonus_drift, float(severity_bonus) * bonus_mult)

	var passive_pc := diff.passive_pc_mod if diff != null else 0
	if gov_stability >= 60:
		passive_pc += severity_bonus
	elif gov_stability < 35 and cap > 0.0:
		passive_pc -= mini(3, int(ceil(float(35 - gov_stability) / 8.0)))

	if factions.has("golkar_habibie") and not bool(banned_factions.get("golkar_habibie", false)):
		var gh_aff := float(factions["golkar_habibie"]["affinity"])
		if gh_aff >= 70.0:
			passive_pc += 2
		elif gh_aff < 40.0:
			passive_pc -= 1

	if passive_pc > 0:
		passive_pc = stoch_round(float(passive_pc) * pc_gain_factor())
	if passive_pc != 0:
		var next_pc := clamp_pc(float(pc + passive_pc))
		var pc_delta := next_pc - pc
		pc = next_pc
		_log_pc_change(pc_delta, "end-of-turn passive ledger")

	# Golkar Pillar G: Cendana creeps up by +1 each turn while Pillar G stands
	if golkar_pillar_stands("g"):
		var pillar_fx: Dictionary = ContentDB.catalog.golkar_pillar_effects if (ContentDB != null and ContentDB.catalog != null) else {}
		var c_drift := int(pillar_fx.get("cendanaDrift", 1))
		stats["cendana"] = clamp_dashboard("cendana", float(int(stats.get("cendana", 0)) + c_drift))

	var econ_v := int(stats.get("econ", 0))
	if econ_v <= 20:
		stats["pop"] = clamp_dashboard("pop", float(int(stats.get("pop", 0)) - 2))
		stats["stab"] = clamp_dashboard("stab", float(int(stats.get("stab", 0)) - 2))
	elif econ_v >= 75:
		stats["pop"] = clamp_dashboard("pop", float(int(stats.get("pop", 0)) + 1))
		stats["stab"] = clamp_dashboard("stab", float(int(stats.get("stab", 0)) + 1))

	var intl_v := int(stats.get("intl", 0))
	if intl_v <= 20:
		stats["econ"] = clamp_dashboard("econ", float(int(stats.get("econ", 0)) - 2))
	elif intl_v >= 75:
		stats["econ"] = clamp_dashboard("econ", float(int(stats.get("econ", 0)) + 2))

	var ref_v := int(stats.get("ref", 0))
	if ref_v <= 20:
		stats["stab"] = clamp_dashboard("stab", float(int(stats.get("stab", 0)) - 2))
		stats["pop"] = clamp_dashboard("pop", float(int(stats.get("pop", 0)) - 1))

	var pop_drift_mod := 0.0
	var pop_v := int(stats.get("pop", 0))
	if pop_v >= 75:
		pop_drift_mod = 0.5
	elif pop_v <= 20 and cap > 0.0:
		pop_drift_mod = -0.5

	var net_drift := current_bonus - current_drain + pop_drift_mod

	for fk in factions.keys():
		if int(factions[fk]["seats"]) <= 0 or bool(banned_factions.get(fk, false)):
			continue
		var noise := (rng.randf() * 2.0) - 1.0
		if fk == "golkar_habibie" and net_drift < 0.0:
			var loyalist_drain := minf(loyalist_mitigation, absf(net_drift))
			factions[fk]["affinity"] = clamp_faction(fk, float(factions[fk]["affinity"]) - loyalist_drain + noise)
		else:
			factions[fk]["affinity"] = clamp_faction(fk, float(factions[fk]["affinity"]) + net_drift + noise)

	var drift_rate := diff.faction_drift if diff != null else 0.0
	if drift_rate > 0.0:
		for fk in factions.keys():
			if int(factions[fk]["seats"]) <= 0 or bool(banned_factions.get(fk, false)) or fk == "golkar_habibie":
				continue
			var cur_a := float(factions[fk]["affinity"])
			var base_a := float(factions[fk].get("base_affinity", cur_a))
			if cur_a > base_a:
				factions[fk]["affinity"] = clamp_faction(fk, cur_a - minf(drift_rate, cur_a - base_a))

	var regen := diff.cendana_regen if diff != null else 0.0
	var start_cendana := diff.cendana if diff != null else 95
	var cur_cendana := int(stats.get("cendana", 0))
	if regen > 0.0 and cur_cendana < start_cendana and cur_cendana < max_cendana:
		var bump := stoch_round(regen)
		if bump > 0:
			stats["cendana"] = clamp_dashboard("cendana", float(cur_cendana + bump))

	# Stat gravity (>78 -> -2/turn; <22 -> +1/turn on easy/medium)
	for sk in ["pop", "ref", "econ", "intl", "stab"]:
		var sv := int(stats.get(sk, 0))
		if sv > 78:
			stats[sk] = clamp_dashboard(sk, float(sv - 2))
		elif sv < 22 and (selected_difficulty == "easy" or selected_difficulty == "medium"):
			stats[sk] = clamp_dashboard(sk, float(sv + 1))

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	return {"pc_penalty": pc_penalty, "passive_pc": passive_pc}


func _merge_poros_tengah() -> void:
	if not factions.has("poros_tengah") or bool(banned_factions.get("poros_tengah", false)):
		return
	if bool(factions["poros_tengah"].get("has_merged", false)):
		return
	var pt_res := ContentDB.get_faction("poros_tengah") if ContentDB != null else null
	if pt_res == null or pt_res.merged_state == null:
		return

	factions["poros_tengah"]["has_merged"] = true

	var pan_seats := int(factions["poros_tengah"]["seats"])
	var ppp_seats := int(factions["ppp"]["seats"]) if (factions.has("ppp") and not bool(banned_factions.get("ppp", false))) else 0
	var pkb_seats := int(factions["pkb"]["seats"]) if (factions.has("pkb") and not bool(banned_factions.get("pkb", false))) else 0
	var oth_transfer := (
		mini(20, int(factions["other_parties"]["seats"]))
		if (factions.has("other_parties") and not bool(banned_factions.get("other_parties", false)))
		else 0
	)
	var total_merged_seats := pan_seats + ppp_seats + pkb_seats + oth_transfer

	var pan_aff := float(factions["poros_tengah"]["affinity"])
	var ppp_aff := float(factions["ppp"]["affinity"]) if factions.has("ppp") else pan_aff
	var pkb_aff := float(factions["pkb"]["affinity"]) if factions.has("pkb") else pan_aff
	var oth_aff := float(factions["other_parties"]["affinity"]) if factions.has("other_parties") else pan_aff

	var weighted_aff := (
		(pan_aff * float(pan_seats) + ppp_aff * float(ppp_seats) + pkb_aff * float(pkb_seats) + oth_aff * float(oth_transfer))
		/ float(total_merged_seats)
		if total_merged_seats > 0
		else pan_aff
	)

	var ms := pt_res.merged_state
	factions["poros_tengah"]["name_key"] = ms.name_key
	factions["poros_tengah"]["portrait_name_key"] = ms.portrait_name_key
	factions["poros_tengah"]["summary_key"] = ms.summary_key
	factions["poros_tengah"]["biography_key"] = ms.biography_key
	if not ms.cover_image_path.is_empty():
		factions["poros_tengah"]["cover_image_path"] = ms.cover_image_path
	factions["poros_tengah"]["seats"] = total_merged_seats
	factions["poros_tengah"]["affinity"] = clamp_faction("poros_tengah", weighted_aff)

	var ppp_favors := int(factions["ppp"].get("favor", 0)) if (factions.has("ppp") and not bool(banned_factions.get("ppp", false))) else 0
	var pkb_favors := int(factions["pkb"].get("favor", 0)) if (factions.has("pkb") and not bool(banned_factions.get("pkb", false))) else 0
	var inherited_favor := mini(2, int(floor(float(ppp_favors + pkb_favors) * 0.5)))
	var diff := _get_diff_data()
	var max_fav := diff.max_favor if diff != null else 3
	factions["poros_tengah"]["favor"] = mini(max_fav, int(factions["poros_tengah"].get("favor", 0)) + inherited_favor)

	if factions.has("ppp"):
		factions["ppp"]["seats"] = 0
	if factions.has("pkb"):
		factions["pkb"]["seats"] = 0
	if factions.has("other_parties") and oth_transfer > 0:
		factions["other_parties"]["seats"] = maxi(0, int(factions["other_parties"]["seats"]) - oth_transfer)

	var next_order := PackedStringArray()
	for fk in active_faction_order:
		if fk != "ppp" and fk != "pkb":
			next_order.append(fk)
	active_faction_order = next_order


func _enter_turn() -> void:
	is_action_phase = false
	event_resolved_this_turn = false
	turn_executive_used = false
	turn_faction_used.clear()
	turn_faction_count = 0

	if current_turn > _total_event_turns():
		return

	for rk in action_cooldowns.keys():
		var cd := int(action_cooldowns[rk])
		if cd > 0:
			action_cooldowns[rk] = cd - 1
	for fk in faction_cooldowns.keys():
		var cd := int(faction_cooldowns[fk])
		if cd > 0:
			faction_cooldowns[fk] = cd - 1

	var ev := ContentDB.get_event_by_turn(current_turn) if ContentDB != null else null
	if ev != null and ev.id == "ev_central_axis":
		_merge_poros_tengah()


func finish_action_phase() -> void:
	if not game_started:
		return
	apply_end_of_turn_economy()
	var opp := get_node_or_null("/root/OppositionManager")
	if opp != null and opp.has_method("on_end_of_turn"):
		opp.call("on_end_of_turn")
	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))
	_update_watermarks()

	current_turn += 1
	_enter_turn()

	_update_watermarks()
	_notify_achievements_mid_campaign()
	state_changed.emit()


func _reset_watermarks() -> void:
	min_stat_watermarks.clear()
	max_stat_watermarks.clear()
	for sk in STAT_KEYS:
		var v := int(stats.get(sk, 0))
		min_stat_watermarks[sk] = v
		max_stat_watermarks[sk] = v
	lowest_gov_stability = get_gov_stability()


func _update_watermarks() -> void:
	if not game_started:
		return
	var g := get_gov_stability()
	if g < lowest_gov_stability:
		lowest_gov_stability = g
	for sk in STAT_KEYS:
		var v := int(stats.get(sk, 0))
		if not min_stat_watermarks.has(sk) or v < int(min_stat_watermarks[sk]):
			min_stat_watermarks[sk] = v
		if not max_stat_watermarks.has(sk) or v > int(max_stat_watermarks[sk]):
			max_stat_watermarks[sk] = v


func _notify_achievements_mid_campaign() -> void:
	var ach := get_node_or_null("/root/AchievementService")
	if ach != null and ach.has_method("evaluate_mid_campaign"):
		ach.call("evaluate_mid_campaign")


func serialize_state() -> Dictionary:
	var sss := get_node_or_null("/root/SSSController")
	var sss_run: Dictionary = sss.call("serialize_run") if (sss != null and sss.has_method("serialize_run")) else {}
	var opp := get_node_or_null("/root/OppositionManager")
	var opp_state: Dictionary = opp.call("serialize_state") if (opp != null and opp.has_method("serialize_state")) else {}

	return {
		"version": 1,
		"game_started": game_started,
		"current_turn": current_turn,
		"is_action_phase": is_action_phase,
		"selected_difficulty": selected_difficulty,
		"show_option_effects": show_option_effects,
		"sss_run": sss_run,
		"turn_executive_used": turn_executive_used,
		"turn_faction_used": turn_faction_used.duplicate(true),
		"turn_faction_count": turn_faction_count,
		"event_resolved_this_turn": event_resolved_this_turn,
		"stats": stats.duplicate(true),
		"pc": pc,
		"global_malus": global_malus,
		"factions": factions.duplicate(true),
		"active_faction_order": Array(active_faction_order),
		"active_decrees": active_decrees.duplicate(true),
		"banned_factions": banned_factions.duplicate(true),
		"total_seats_vacated": total_seats_vacated,
		"gazette_history": gazette_history.duplicate(true),
		"min_stats": min_stats.duplicate(true),
		"max_cendana": max_cendana,
		"min_factions": min_factions.duplicate(true),
		"action_cooldowns": action_cooldowns.duplicate(true),
		"action_usage_count": action_usage_count.duplicate(true),
		"faction_cooldowns": faction_cooldowns.duplicate(true),
		"faction_usage_count": faction_usage_count.duplicate(true),
		"completed_interactions": completed_interactions.duplicate(true),
		"horse_trade_counts": horse_trade_counts.duplicate(true),
		"shuffled_event_options": shuffled_event_options.duplicate(true),
		"pc_log": pc_log.duplicate(true),
		"prev_stats_snapshot": prev_stats_snapshot.duplicate(true),
		"decrees_enacted_count": decrees_enacted_count,
		"routines_used_count": routines_used_count,
		"faction_deals_count": faction_deals_count,
		"final_appeals_count": final_appeals_count,
		"favor_built_total": favor_built_total,
		"horse_trades_total": horse_trades_total,
		"lowest_gov_stability": lowest_gov_stability,
		"min_stat_watermarks": min_stat_watermarks.duplicate(true),
		"max_stat_watermarks": max_stat_watermarks.duplicate(true),
		"bank_bali_clean_steps": bank_bali_clean_steps.duplicate(true),
		"timor_promise_steps": timor_promise_steps.duplicate(true),
		"sp3_upheld_with_high_cendana": sp3_upheld_with_high_cendana,
		"helped_rais_speaker": helped_rais_speaker,
		"opposition_state": opp_state,
	}


func restore_state(data: Dictionary) -> void:
	if data.is_empty():
		return

	_reset_factions_to_initial()

	selected_difficulty = String(data.get("selected_difficulty", "historical"))
	var sss := get_node_or_null("/root/SSSController")
	var sss_run: Variant = data.get("sss_run", {})
	if selected_difficulty == "ucn" and sss != null and sss.has_method("restore_run") and sss_run is Dictionary and not sss_run.is_empty():
		active_difficulty_data = sss.call("restore_run", sss_run) as DifficultyData
	else:
		if sss != null and sss.has_method("clear_run"):
			sss.call("clear_run")
		active_difficulty_data = ContentDB.get_difficulty(selected_difficulty) if ContentDB != null else null
		if active_difficulty_data == null and ContentDB != null:
			selected_difficulty = "historical"
			active_difficulty_data = ContentDB.get_difficulty("historical")

	game_started = bool(data.get("game_started", true))
	current_turn = _to_int(data.get("current_turn", 1), 1)
	is_action_phase = bool(data.get("is_action_phase", false))
	show_option_effects = bool(data.get("show_option_effects", false))
	if selected_difficulty == "historical":
		show_option_effects = false

	turn_executive_used = bool(data.get("turn_executive_used", false))
	turn_faction_used = _to_int_dict(data.get("turn_faction_used", {}))
	turn_faction_count = _to_int(data.get("turn_faction_count", _compute_turn_faction_count()), _compute_turn_faction_count())
	event_resolved_this_turn = bool(data.get("event_resolved_this_turn", false))

	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for sk in STAT_KEYS:
			if saved_stats.has(sk):
				stats[sk] = _to_int(saved_stats[sk], int(stats.get(sk, 0)))
	pc = _to_int(data.get("pc", 20), 20)
	global_malus = _to_float(data.get("global_malus", 0.0), 0.0)

	var saved_factions: Variant = data.get("factions", {})
	if saved_factions is Dictionary:
		for fk in saved_factions.keys():
			var fk_str := str(fk)
			if saved_factions[fk] is Dictionary:
				var base_fac: Dictionary = factions[fk_str] if factions.has(fk_str) else {}
				factions[fk_str] = _normalize_faction_entry(fk_str, saved_factions[fk], base_fac)

	var saved_order: Variant = data.get("active_faction_order", INITIAL_PORTRAIT_FACTIONS)
	var restored_order := PackedStringArray()
	if saved_order is Array or saved_order is PackedStringArray:
		for item in saved_order:
			restored_order.append(str(item))
	if restored_order.is_empty():
		restored_order = PackedStringArray(INITIAL_PORTRAIT_FACTIONS)
	active_faction_order = restored_order

	active_decrees = _to_bool_dict(data.get("active_decrees", {}))
	banned_factions = _to_bool_dict(data.get("banned_factions", {}))
	total_seats_vacated = _to_int(data.get("total_seats_vacated", 0), 0)

	gazette_history.clear()
	var gh: Variant = data.get("gazette_history", [])
	if gh is Array:
		for entry in gh:
			if entry is Dictionary:
				var norm_entry: Dictionary = entry.duplicate(true)
				if norm_entry.has("id"):
					norm_entry["id"] = str(norm_entry["id"])
				if norm_entry.has("turn"):
					norm_entry["turn"] = _to_int(norm_entry["turn"], 1)
				if norm_entry.has("date_str"):
					norm_entry["date_str"] = str(norm_entry["date_str"])
				if norm_entry.has("text_key"):
					norm_entry["text_key"] = str(norm_entry["text_key"])
				if norm_entry.has("seats_vacated"):
					norm_entry["seats_vacated"] = _to_int(norm_entry["seats_vacated"], 0)
				if norm_entry.has("dissolved_factions") and norm_entry["dissolved_factions"] is Array:
					var df_arr: Array[String] = []
					for df in norm_entry["dissolved_factions"]:
						df_arr.append(str(df))
					norm_entry["dissolved_factions"] = df_arr
				gazette_history.append(norm_entry)

	min_stats = {"pop": 0, "mil": 0, "ref": 0, "econ": 0, "intl": 0, "stab": 0}
	var loaded_min_stats := _to_int_dict(data.get("min_stats", {}))
	for msk in loaded_min_stats.keys():
		min_stats[msk] = int(loaded_min_stats[msk])
	max_cendana = _to_int(data.get("max_cendana", 100), 100)
	min_factions = _to_float_dict(data.get("min_factions", {}))

	action_cooldowns = _to_int_dict(data.get("action_cooldowns", {}))
	action_usage_count = _to_int_dict(data.get("action_usage_count", {}))
	faction_cooldowns = _to_int_dict(data.get("faction_cooldowns", {}))
	faction_usage_count = _to_int_dict(data.get("faction_usage_count", {}))
	completed_interactions = _to_bool_dict(data.get("completed_interactions", {}))
	horse_trade_counts = _to_int_dict(data.get("horse_trade_counts", {}))
	shuffled_event_options = _normalize_shuffled_options(data.get("shuffled_event_options", {}))

	pc_log.clear()
	var pl: Variant = data.get("pc_log", [])
	if pl is Array:
		for entry in pl:
			if entry is Dictionary:
				var norm_pl: Dictionary = entry.duplicate(true)
				if norm_pl.has("turn"):
					norm_pl["turn"] = _to_int(norm_pl["turn"], 1)
				if norm_pl.has("delta"):
					norm_pl["delta"] = _to_int(norm_pl["delta"], 0)
				if norm_pl.has("balance_after"):
					norm_pl["balance_after"] = _to_int(norm_pl["balance_after"], 0)
				if norm_pl.has("reason"):
					norm_pl["reason"] = str(norm_pl["reason"])
				pc_log.append(norm_pl)

	prev_stats_snapshot = _to_int_dict(data.get("prev_stats_snapshot", stats))

	decrees_enacted_count = _to_int(data.get("decrees_enacted_count", active_decrees.size()), active_decrees.size())
	routines_used_count = _to_int(data.get("routines_used_count", 0), 0)
	faction_deals_count = _to_int(data.get("faction_deals_count", 0), 0)
	final_appeals_count = _to_int(data.get("final_appeals_count", 0), 0)
	favor_built_total = _to_int(data.get("favor_built_total", 0), 0)
	horse_trades_total = _to_int(data.get("horse_trades_total", 0), 0)

	lowest_gov_stability = _to_int(data.get("lowest_gov_stability", get_gov_stability()), get_gov_stability())
	min_stat_watermarks = _to_int_dict(data.get("min_stat_watermarks", stats))
	max_stat_watermarks = _to_int_dict(data.get("max_stat_watermarks", stats))
	bank_bali_clean_steps = _to_bool_dict(data.get("bank_bali_clean_steps", {}))
	timor_promise_steps = _to_bool_dict(data.get("timor_promise_steps", {}))
	sp3_upheld_with_high_cendana = bool(data.get("sp3_upheld_with_high_cendana", false))
	helped_rais_speaker = bool(data.get("helped_rais_speaker", false))

	if factions.has("abri"):
		stats["mil"] = _js_round(float(factions["abri"]["affinity"]))

	var opp := get_node_or_null("/root/OppositionManager")
	var opp_state: Variant = data.get("opposition_state", {})
	if opp != null and opp.has_method("restore_state") and opp_state is Dictionary:
		opp.call("restore_state", opp_state)

	state_changed.emit()


static func _to_int(v: Variant, fallback: int = 0) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return _js_round(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v).strip_edges()
			if s.is_valid_int():
				return s.to_int()
			if s.is_valid_float():
				return _js_round(s.to_float())
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


static func _to_int_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v.keys():
			out[str(k)] = _to_int(v[k], 0)
	return out


static func _to_float_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v.keys():
			out[str(k)] = _to_float(v[k], 0.0)
	return out


static func _to_bool_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v.keys():
			out[str(k)] = bool(v[k])
	return out


static func _normalize_faction_entry(fk_str: String, raw: Dictionary, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for k in raw.keys():
		out[str(k)] = raw[k]
	out["id"] = str(out.get("id", fk_str))
	out["seats"] = _to_int(out.get("seats", defaults.get("seats", 0)), 0)
	var aff := _to_float(out.get("affinity", defaults.get("affinity", 0.0)), 0.0)
	out["affinity"] = aff
	out["base_affinity"] = _to_float(out.get("base_affinity", defaults.get("base_affinity", aff)), aff)
	out["favor"] = _to_int(out.get("favor", defaults.get("favor", 0)), 0)
	out["has_merged"] = bool(out.get("has_merged", defaults.get("has_merged", false)))
	for str_key in ["name_key", "portrait_name_key", "short_key", "summary_key", "biography_key", "image_path", "cover_image_path"]:
		if out.has(str_key):
			out[str_key] = str(out[str_key])
	return out


static func _normalize_shuffled_options(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for raw_turn in v.keys():
			var turn_key := _to_int(raw_turn, -1)
			if turn_key < 0:
				continue
			var typed_arr: Array[int] = []
			var raw_arr: Variant = v[raw_turn]
			if raw_arr is Array or raw_arr is PackedInt32Array or raw_arr is PackedInt64Array:
				for elem in raw_arr:
					typed_arr.append(_to_int(elem, 0))
			out[turn_key] = typed_arr
	return out
