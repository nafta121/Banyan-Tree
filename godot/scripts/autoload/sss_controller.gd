extends Node

signal state_changed()

const RANKS := [0, 5, 10, 20]
const MAX_LEVEL := 20
const DEFAULT_LEVEL := 10
const GRID_COLS := 6
const GRID_ROWS := 4
const UNLOCK_ACH_ID := "win_historical"
const MAXED_ACH_ID := "sss_20"

var levels: Dictionary = {}
var hide_forecast: bool = true

var active_run_levels: Dictionary = {}
var active_run_hide_forecast: bool = true

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	_init_default_levels()


func _ready() -> void:
	if levels.is_empty():
		_init_default_levels()


func _init_default_levels() -> void:
	levels.clear()
	if ContentDB == null or ContentDB.catalog == null:
		return
	for card in ContentDB.catalog.sss_cards:
		levels[card.id] = DEFAULT_LEVEL
	enforce_prereqs(levels)


static func _js_round(x: float) -> int:
	return int(floor(x + 0.5))


static func _r1(x: float) -> float:
	return float(_js_round(x * 10.0)) / 10.0


static func _r2(x: float) -> float:
	return float(_js_round(x * 100.0)) / 100.0


func snap_rank(v: int) -> int:
	if v <= 2:
		return 0
	if v <= 7:
		return 5
	if v <= 14:
		return 10
	return 20


func is_unlocked() -> bool:
	var ach := get_node_or_null("/root/AchievementService")
	if ach == null:
		return false
	if ach.has_method("is_unlocked"):
		return bool(ach.call("is_unlocked", UNLOCK_ACH_ID))
	if "unlocked_ids" in ach:
		var ids: Variant = ach.get("unlocked_ids")
		if ids is Dictionary:
			return bool(ids.get(UNLOCK_ACH_ID, false))
	return false


func is_card_unlocked(card_id: String, lvl_map: Dictionary = levels) -> bool:
	if ContentDB == null:
		return false
	var card := ContentDB.get_sss_card(card_id)
	if card == null:
		return false
	if card.prereqs.is_empty():
		return true
	for pid in card.prereqs:
		if int(lvl_map.get(pid, 0)) > 0:
			return true
	return false


func enforce_prereqs(lvl_map: Dictionary = levels) -> void:
	if ContentDB == null or ContentDB.catalog == null:
		return
	var ordered := _cards_sorted_by_col()
	var changed := true
	while changed:
		changed = false
		for card in ordered:
			if int(lvl_map.get(card.id, 0)) > 0 and not is_card_unlocked(card.id, lvl_map):
				lvl_map[card.id] = 0
				changed = true


func set_card_rank(card_id: String, rank: int) -> void:
	if levels.is_empty():
		_init_default_levels()
	if ContentDB == null or ContentDB.get_sss_card(card_id) == null:
		return
	var snapped := snap_rank(rank)
	if snapped > 0 and not is_card_unlocked(card_id, levels):
		return
	levels[card_id] = snapped
	enforce_prereqs(levels)
	state_changed.emit()


func set_hide_forecast(hide: bool) -> void:
	hide_forecast = hide
	state_changed.emit()


func apply_preset(rank: int) -> void:
	if levels.is_empty():
		_init_default_levels()
	if ContentDB == null or ContentDB.catalog == null:
		return
	if rank < 0:
		for col in range(GRID_COLS):
			for card in ContentDB.catalog.sss_cards:
				if card.col != col:
					continue
				if not is_card_unlocked(card.id, levels):
					levels[card.id] = 0
				else:
					var active_chance := 0.80 if col == 0 else 0.65
					if rng.randf() < active_chance:
						levels[card.id] = int(RANKS[1 + (rng.randi() % 3)])
					else:
						levels[card.id] = 0
		var any_on := false
		for card in ContentDB.catalog.sss_cards:
			if int(levels.get(card.id, 0)) > 0:
				any_on = true
				break
		if not any_on:
			levels["pc"] = DEFAULT_LEVEL
			levels["s_econ"] = DEFAULT_LEVEL
		enforce_prereqs(levels)
	else:
		var snapped := snap_rank(rank)
		for card in ContentDB.catalog.sss_cards:
			levels[card.id] = snapped
		enforce_prereqs(levels)
	state_changed.emit()


func lerp_card(level: float, n: float, h: float, m: float) -> float:
	var l := clampf(level, 0.0, float(MAX_LEVEL))
	if l <= 10.0:
		return n + (h - n) * (l / 10.0)
	return h + (m - h) * ((l - 10.0) / 10.0)


func build_difficulty_data(lvl_map: Dictionary = levels) -> DifficultyData:
	if levels.is_empty():
		_init_default_levels()
	var effective := {}
	if ContentDB != null and ContentDB.catalog != null:
		for card in ContentDB.catalog.sss_cards:
			effective[card.id] = snap_rank(int(lvl_map.get(card.id, DEFAULT_LEVEL)))
		enforce_prereqs(effective)

	var d := DifficultyData.new()
	d.id = "ucn"
	d.name_key = "config.difficulty.ucn.name"
	d.desc_key = "config.difficulty.ucn.desc"
	var ucn_template := ContentDB.get_difficulty("ucn") if ContentDB != null else null
	if ucn_template != null:
		d.name_key = ucn_template.name_key
		d.desc_key = ucn_template.desc_key
		d.image_path = ucn_template.image_path
	d.pc = 20
	d.cendana = 95
	d.malus_cap = 3.25
	d.max_favor = 2
	d.start_mods = {}
	d.opposition = {
		"scale": 1.0,
		"defectionMult": 1.0,
		"drama": {},
	}

	if ContentDB == null or ContentDB.catalog == null:
		return d

	for card in ContentDB.catalog.sss_cards:
		var lv := float(clampi(int(effective.get(card.id, 0)), 0, MAX_LEVEL))
		if not card.is_custom:
			var v := lerp_card(lv, card.n, card.h, card.m)
			match card.target_field:
				"pc":
					d.pc = _js_round(v)
				"passive_pc_mod":
					d.passive_pc_mod = _js_round(v)
				"cooldown_bonus":
					d.cooldown_bonus = _js_round(v)
				"malus_cap":
					d.malus_cap = _r2(v)
				"event_neg_mult":
					d.event_neg_mult = _r2(v)
				"event_pos_mult":
					d.event_pos_mult = _r2(v)
				"faction_drift":
					d.faction_drift = _r2(v)
				"cendana":
					d.cendana = _js_round(v)
				"affinity_mod":
					d.affinity_mod = _js_round(v)
				"cendana_regen":
					d.cendana_regen = _r2(v)
				"gain_mult":
					d.gain_mult = _r2(v)
				"max_favor":
					d.max_favor = _js_round(v)
				"defection_mult":
					d.opposition["defectionMult"] = _r2(v)
				"scale":
					d.opposition["scale"] = _r2(v)
				"start_mod":
					d.start_mods[card.start_stat_key] = _js_round(v)
		else:
			match card.id:
				"cost":
					d.cost_pct = _js_round(lerp_card(lv, 0.0, 15.0, 27.0))
					d.decree_cost_pct = _js_round(lerp_card(lv, 0.0, 8.0, 14.0))
					d.action_cost_mod = _js_round(lerp_card(lv, 0.0, 2.0, 4.0))
				"chaos":
					d.opposition["drama"] = {
						"moodSwing": _js_round(lerp_card(lv, 8.0, 12.0, 16.0)),
						"wildcardChance": _r2(lerp_card(lv, 0.35, 1.5, 1.8)),
						"wildcardMin": _js_round(lerp_card(lv, 15.0, 25.0, 28.0)),
						"wildcardMax": _js_round(lerp_card(lv, 35.0, 50.0, 53.0)),
						"crossoverRate": _r2(lerp_card(lv, 0.20, 0.55, 0.67)),
					}
				"military":
					d.opposition["milCeiling"] = _r2(lerp_card(lv, 0.10, 0.50, 0.75))
					d.opposition["milPatienceDecay"] = _r1(lerp_card(lv, 4.0, 6.0, 9.0))
					d.opposition["milAngerRise"] = _r1(lerp_card(lv, 8.0, 10.0, 14.0))
					d.opposition["milStubborn"] = _r2(lerp_card(lv, 0.35, 0.50, 0.92))
					d.opposition["milCalm"] = _r1(lerp_card(lv, 9.0, 7.0, 2.0))
				"pdip":
					d.opposition["pdipStart"] = _js_round(lerp_card(lv, 10.0, 20.0, 50.0))
					d.opposition["pdipRise"] = _r1(lerp_card(lv, 2.2, 3.8, 5.4))
					d.opposition["pdipCostMax"] = _r1(lerp_card(lv, 5.0, 8.0, 12.0))
					d.opposition["pdipCut"] = _r2(lerp_card(lv, 0.06, 0.10, 0.15))
					d.opposition["pdipMustGo"] = _r2(lerp_card(lv, 0.06, 0.10, 0.16))

	var sm := d.start_mods
	var sum_five := (
		float(sm.get("pop", 0))
		+ float(sm.get("ref", 0))
		+ float(sm.get("econ", 0))
		+ float(sm.get("intl", 0))
		+ float(sm.get("stab", 0))
	)
	d.stat_mod = _js_round(sum_five / 5.0)
	return d


func start_run() -> DifficultyData:
	if levels.is_empty():
		_init_default_levels()
	enforce_prereqs(levels)
	active_run_levels = levels.duplicate(true)
	active_run_hide_forecast = hide_forecast
	return build_difficulty_data(active_run_levels)


func clear_run() -> void:
	active_run_levels.clear()
	active_run_hide_forecast = true


func restore_run(saved: Dictionary) -> DifficultyData:
	var saved_lvls: Variant = saved.get("levels", {})
	active_run_levels.clear()
	if ContentDB != null and ContentDB.catalog != null:
		for card in ContentDB.catalog.sss_cards:
			var raw_v := int(saved_lvls.get(card.id, DEFAULT_LEVEL)) if saved_lvls is Dictionary else DEFAULT_LEVEL
			active_run_levels[card.id] = snap_rank(raw_v)
		enforce_prereqs(active_run_levels)
	active_run_hide_forecast = bool(saved.get("hideForecast", true))
	return build_difficulty_data(active_run_levels)


func serialize_run() -> Dictionary:
	if active_run_levels.is_empty():
		return {}
	return {
		"levels": active_run_levels.duplicate(true),
		"hideForecast": active_run_hide_forecast,
	}


func are_levels_at_least(min_level: int, lvl_map: Dictionary = levels) -> bool:
	if ContentDB == null or ContentDB.catalog == null or ContentDB.catalog.sss_cards.is_empty():
		return false
	for card in ContentDB.catalog.sss_cards:
		if int(lvl_map.get(card.id, 0)) < min_level:
			return false
	return true


func is_run_at_least(min_level: int) -> bool:
	if active_run_levels.is_empty():
		return false
	return are_levels_at_least(min_level, active_run_levels)


func is_run_maxed() -> bool:
	return is_run_at_least(MAX_LEVEL)


func find_required_path(target_id: String, lvl_map: Dictionary = levels) -> PackedStringArray:
	if ContentDB == null or is_card_unlocked(target_id, lvl_map):
		return PackedStringArray()
	var card := ContentDB.get_sss_card(target_id)
	if card == null or card.prereqs.is_empty():
		return PackedStringArray()
	var best: PackedStringArray = PackedStringArray()
	var has_best := false
	for pid in card.prereqs:
		if ContentDB.get_sss_card(pid) == null:
			continue
		var sub := find_required_path(pid, lvl_map)
		var cand := PackedStringArray()
		cand.append_array(sub)
		cand.append(pid)
		if not has_best or cand.size() < best.size():
			best = cand
			has_best = true
	return best


func format_card_effect(card_id: String, level: int = -1) -> String:
	if ContentDB == null or LocaleService == null:
		return ""
	var card := ContentDB.get_sss_card(card_id)
	if card == null:
		return ""
	var lv := float(levels.get(card_id, DEFAULT_LEVEL) if level < 0 else level)
	var v := lerp_card(lv, card.n, card.h, card.m)
	if not card.start_stat_key.is_empty():
		var start_v := card.start_stat_base + _js_round(v)
		return LocaleService.tr_fmt(card.value_key, {"V": str(start_v)})
	match card.id:
		"pc", "cooldown", "s_cendana", "favor":
			return LocaleService.tr_fmt(card.value_key, {"V": str(_js_round(v))})
		"s_goodwill", "passive":
			var sv := _js_round(v)
			return LocaleService.tr_fmt(card.value_key, {"V": ("+%d" % sv) if sv > 0 else str(sv)})
		"malus":
			return LocaleService.tr_fmt(card.value_key, {"V": _fmt_js_num(_r1(minf(5.0, v)))})
		"bad", "good", "erosion", "regen", "yield", "defect", "army":
			return LocaleService.tr_fmt(card.value_key, {"V": _fmt_js_num(_r2(v))})
		"cost":
			return LocaleService.tr_fmt(card.value_key, {
				"C": str(_js_round(lerp_card(lv, 0.0, 15.0, 27.0))),
				"D": str(_js_round(lerp_card(lv, 0.0, 8.0, 14.0))),
				"F": str(_js_round(lerp_card(lv, 0.0, 2.0, 4.0))),
			})
		"chaos":
			var mood_swing := _js_round(lerp_card(lv, 8.0, 12.0, 16.0))
			var wc := _r2(lerp_card(lv, 0.35, 1.5, 1.8))
			var co := _r2(lerp_card(lv, 0.20, 0.55, 0.67))
			return LocaleService.tr_fmt(card.value_key, {
				"M": str(mood_swing),
				"W": str(mini(100, _js_round(wc * 100.0))),
				"X": str(_js_round(co * 100.0)),
			})
		"military":
			var mc := _r2(lerp_card(lv, 0.10, 0.50, 0.75))
			var mpd := _r1(lerp_card(lv, 4.0, 6.0, 9.0))
			var mar := _r1(lerp_card(lv, 8.0, 10.0, 14.0))
			var ms := _r2(lerp_card(lv, 0.35, 0.50, 0.92))
			var mk := _r1(lerp_card(lv, 9.0, 7.0, 2.0))
			return LocaleService.tr_fmt(card.value_key, {
				"C": str(_js_round(mc * 100.0)),
				"D": _fmt_js_num(mpd),
				"R": _fmt_js_num(mar),
				"S": str(_js_round(ms * 100.0)),
				"K": _fmt_js_num(mk),
			})
		"pdip":
			var ps := _js_round(lerp_card(lv, 10.0, 20.0, 50.0))
			var pr := _r1(lerp_card(lv, 2.2, 3.8, 5.4))
			var pcm := _r1(lerp_card(lv, 5.0, 8.0, 12.0))
			var pcut := _r2(lerp_card(lv, 0.06, 0.10, 0.15))
			var pmg := _r2(lerp_card(lv, 0.06, 0.10, 0.16))
			return LocaleService.tr_fmt(card.value_key, {
				"S": str(ps),
				"R": _fmt_js_num(pr),
				"C": str(_js_round(pcut * 100.0)),
				"G": str(_js_round(pmg * 100.0)),
				"M": _fmt_js_num(pcm + 1.0),
			})
		_:
			return LocaleService.tr_fmt(card.value_key, {"V": str(_js_round(v))})


func _fmt_js_num(x: float) -> String:
	if is_equal_approx(x, roundf(x)):
		return str(int(roundf(x)))
	var s := "%.2f" % x
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _cards_sorted_by_col() -> Array[SSSCardData]:
	var arr: Array[SSSCardData] = []
	if ContentDB == null or ContentDB.catalog == null:
		return arr
	arr.assign(ContentDB.catalog.sss_cards)
	arr.sort_custom(func(a: SSSCardData, b: SSSCardData) -> bool:
		if a.col != b.col:
			return a.col < b.col
		return a.row < b.row
	)
	return arr
