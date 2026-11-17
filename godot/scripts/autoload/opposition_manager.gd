extends Node

const OPP_SCALE := {
	"easy": 0.25,
	"medium": 0.60,
	"high": 0.85,
	"historical": 1.00,
}

const GRIEVANCE_CAP := 20.0
const TENSION_THRESHOLD := 62.0

const DEFAULT_DRAMA := {
	"easy": {"moodSwing": 6, "wildcardChance": 0.25, "wildcardMin": 12, "wildcardMax": 25, "crossoverRate": 0.12},
	"medium": {"moodSwing": 8, "wildcardChance": 0.35, "wildcardMin": 15, "wildcardMax": 35, "crossoverRate": 0.20},
	"high": {"moodSwing": 10, "wildcardChance": 0.45, "wildcardMin": 18, "wildcardMax": 45, "crossoverRate": 0.28},
	"historical": {"moodSwing": 12, "wildcardChance": 1.00, "wildcardMin": 25, "wildcardMax": 50, "crossoverRate": 0.55},
}

const GRIEVANCE_DECREES := {
	"police_military_separation": 2.0,
	"civilian_defense_ministry": 2.0,
	"abolish_kodam_territorial": 3.0,
	"aceh_special_status_law": 2.0,
	"regional_autonomy": 1.0,
	"maluku_irja_division": 1.0,
	"dissolve_golkar_old_guard": 1.0,
}

const REGIONAL_DECREES := {
	"aceh_special_status_law": true,
	"regional_autonomy": true,
	"maluku_irja_division": true,
}

const KNOWN_PEACEFUL_OPTIONS := {
	"ev_referendum_countdown": [0],
	"ev_timor_votes": [0],
	"ev_peacekeeper_decision": [0, 1],
}

# TNI / ABRI configuration (mirrors js/oppositionAI/tni.js)
const MIL_CEILING := {"easy": 0.0, "medium": 0.10, "high": 0.25, "historical": 0.50}
const MIL_PATIENCE_DECAY := {"easy": 3.0, "medium": 4.0, "high": 5.0, "historical": 6.0}
const MIL_ANGER_RISE := {"easy": 6.0, "medium": 8.0, "high": 9.0, "historical": 10.0}
const MIL_STUBBORN := {"easy": 0.25, "medium": 0.35, "high": 0.45, "historical": 0.50}
const MIL_CALM := {"easy": 11.0, "medium": 9.0, "high": 8.0, "historical": 7.0}
const MIL_GOODWILL := {"easy": 6.0, "medium": 5.0, "high": 4.0, "historical": 3.5}
const MIL_GOODWILL_FROM := 55.0
const MIL_GOODWILL_FULL := 85.0
const MIL_RISE_FADE_FROM := 45.0
const MIL_RISE_FADE_TO := 75.0
const MIL_START_PATIENCE := 50.0
const MIL_TOUCH_GAIN := 8.0
const MIL_RETURN_PATIENCE := 15.0
const MIL_INSULT := 0.8
const MIL_ANGER_FROM_INSULT := 0.6
const MIL_INCIDENT_CHANCE := {1: 0.45, 2: 0.80, 3: 0.95}

# PDI-P Street Mobilization configuration (mirrors js/oppositionAI/pdip.js)
const PDIP_START := {"easy": 0.0, "medium": 10.0, "high": 20.0, "historical": 20.0}
const PDIP_RISE := {"easy": 1.2, "medium": 2.2, "high": 3.0, "historical": 3.8}
const PDIP_COST_MAX := {"easy": 3.0, "medium": 5.0, "high": 7.0, "historical": 8.0}
const PDIP_CUT := {"easy": 0.04, "medium": 0.06, "high": 0.08, "historical": 0.10}
const PDIP_MUST_GO := {"easy": 0.04, "medium": 0.06, "high": 0.08, "historical": 0.10}
const PDIP_TIERS := [25.0, 50.0, 75.0, 100.0]
const PDIP_TOUCH_RELIEF := 2.5
const PDIP_EASE := 0.45
const PDIP_DRAG := 0.4
const PDIP_FLOOR_ADJUST := 4.5

# Core opposition state
var last_turn_cendana: int = 95
var grievance: float = 0.0
var tainted: Dictionary = {}
var crisis: bool = false
var abri_abolished: bool = false
var disruption_turn: int = -1
var coalition_ticks: int = 0
var incident_count: int = 0
var opp_log: Array[Dictionary] = []

# TNI meter state
var mil_phase: String = "patience"
var mil_value: float = MIL_START_PATIENCE
var mil_touched: bool = false
var timor_flare: int = 0
var aceh_flare: int = 0

# PDI-P meter state
var pdip_has_value: bool = false
var pdip_value: float = 0.0
var pdip_touched: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset_for_campaign()


static func _js_round(x: float) -> int:
	return int(floor(x + 0.5))


func reset() -> void:
	reset_for_campaign()


func reset_for_campaign() -> void:
	last_turn_cendana = int(CampaignManager.stats.get("cendana", 95)) if CampaignManager != null else 95
	grievance = 0.0
	tainted.clear()
	crisis = false
	abri_abolished = false
	disruption_turn = -1
	coalition_ticks = 0
	incident_count = 0
	opp_log.clear()

	mil_phase = "patience"
	mil_value = MIL_START_PATIENCE
	mil_touched = false
	timor_flare = 0
	aceh_flare = 0

	pdip_has_value = false
	pdip_value = 0.0
	pdip_touched = false
	if CampaignManager != null and CampaignManager.game_started:
		_pdip_val()


func flush_popups() -> void:
	pass


func _diff_opp() -> Dictionary:
	if CampaignManager == null:
		return {}
	var diff := CampaignManager.get_difficulty_data()
	if diff != null and not diff.opposition.is_empty():
		return diff.opposition
	return {}


func _opp_scale() -> float:
	var o := _diff_opp()
	if o.has("scale") and (o["scale"] is int or o["scale"] is float):
		return float(o["scale"])
	var diff_id := CampaignManager.selected_difficulty if CampaignManager != null else "historical"
	return float(OPP_SCALE.get(diff_id, 1.0))


func _diff_val(table: Dictionary, override_key: String) -> float:
	var o := _diff_opp()
	if not override_key.is_empty() and o.has(override_key) and (o[override_key] is int or o[override_key] is float):
		return float(o[override_key])
	var diff_id := CampaignManager.selected_difficulty if CampaignManager != null else "historical"
	if table.has(diff_id):
		return float(table[diff_id])
	return float(table.get("historical", 0.0))


func is_faction_active(faction_id: String) -> bool:
	if CampaignManager == null or not CampaignManager.factions.has(faction_id):
		return false
	if bool(CampaignManager.banned_factions.get(faction_id, false)):
		return false
	return int(CampaignManager.factions[faction_id].get("seats", 0)) > 0


func _mil_live() -> bool:
	return is_faction_active("abri") and not abri_abolished


func _anger_frac() -> float:
	if mil_phase != "anger":
		return 0.0
	return clampf(mil_value / 100.0, 0.0, 1.0)


func get_military_resistance() -> float:
	if not _mil_live() or abri_abolished:
		return 0.0
	return clampf(_diff_val(MIL_CEILING, "milCeiling") * _anger_frac(), 0.0, 0.95)


func get_military_gain_mult() -> float:
	if not _mil_live() or abri_abolished:
		return 1.0
	return maxf(0.0, 1.0 - _diff_val(MIL_STUBBORN, "milStubborn") * _anger_frac())


func get_military_hostility() -> int:
	if CampaignManager == null or not CampaignManager.factions.has("abri"):
		return 0
	if not _mil_live() or abri_abolished or bool(CampaignManager.banned_factions.get("abri", false)):
		return 0
	var aff := float(CampaignManager.factions["abri"]["affinity"])
	var lvl := 0
	if aff < 20.0:
		lvl = 3
	elif aff < 30.0:
		lvl = 2
	elif aff < 45.0:
		lvl = 1

	var m := 0
	if mil_phase == "anger":
		if mil_value >= 60.0:
			m = 3
		elif mil_value >= 25.0:
			m = 2
		else:
			m = 1
	elif mil_value <= 20.0:
		m = 1
	return maxi(lvl, m)


func is_military_broken() -> bool:
	if abri_abolished:
		return true
	if CampaignManager == null or not CampaignManager.factions.has("abri"):
		return false
	return mil_phase == "anger" or float(CampaignManager.factions["abri"]["affinity"]) < 30.0


func get_military_meter() -> Dictionary:
	return {
		"live": _mil_live(),
		"phase": mil_phase,
		"value": _js_round(mil_value),
		"hostility": get_military_hostility(),
		"ceiling": _diff_val(MIL_CEILING, "milCeiling"),
		"resistance": get_military_resistance(),
		"stubborn": _diff_val(MIL_STUBBORN, "milStubborn"),
	}


func _insult_military(points: float) -> void:
	if not _mil_live() or points <= 0.0:
		return
	if mil_phase == "patience":
		var left := mil_value - points * MIL_INSULT
		if left > 0.0:
			mil_value = left
			return
		mil_phase = "anger"
		mil_value = clampf(-left * MIL_ANGER_FROM_INSULT, 5.0, 100.0)
	else:
		mil_value = minf(100.0, mil_value + points * MIL_ANGER_FROM_INSULT)


func on_military_delta(delta: float) -> void:
	if delta < 0.0:
		_insult_military(-delta)


func apply_military_shock(points: float) -> void:
	if not _mil_live() or points <= 0.0:
		return
	if mil_phase == "patience":
		var left := mil_value - points
		if left > 0.0:
			mil_value = left
			return
		mil_phase = "anger"
		mil_value = clampf(-left * 0.75, 5.0, 100.0)
	else:
		mil_value = minf(100.0, mil_value + points * 0.75)


func on_military_interaction() -> void:
	if not _mil_live() or mil_touched:
		return
	mil_touched = true
	if mil_phase == "patience":
		mil_value = minf(100.0, mil_value + MIL_TOUCH_GAIN)
	else:
		mil_value = maxf(0.0, mil_value - _diff_val(MIL_CALM, "milCalm"))
		if mil_value <= 0.0:
			mil_phase = "patience"
			mil_value = MIL_RETURN_PATIENCE


func _pdip_val() -> float:
	if not pdip_has_value:
		pdip_value = clampf(_diff_val(PDIP_START, "pdipStart"), 0.0, 100.0)
		pdip_has_value = true
	return pdip_value


func get_pdip_tier() -> int:
	if not is_faction_active("pdip"):
		return 0
	var v := _pdip_val()
	var t := 0
	for thresh in PDIP_TIERS:
		if v >= float(thresh):
			t += 1
	return t


func get_pdip_cut() -> float:
	return minf(0.9, float(get_pdip_tier()) * _diff_val(PDIP_CUT, "pdipCut"))


func get_pdip_gain_mult() -> float:
	return maxf(0.1, 1.0 - float(get_pdip_tier()) * _diff_val(PDIP_MUST_GO, "pdipMustGo"))


func get_pdip_cost_mult() -> float:
	if not is_faction_active("pdip"):
		return 1.0
	var g := clampf((_pdip_val() / 100.0 - 0.25) / 0.75, 0.0, 1.0)
	return 1.0 + _diff_val(PDIP_COST_MAX, "pdipCostMax") * g * g


func is_pdip_locked() -> bool:
	return is_faction_active("pdip") and _pdip_val() >= 100.0


func is_vote_locked(faction_id: String) -> bool:
	return faction_id == "pdip" and is_pdip_locked()


func get_pdip_meter() -> Dictionary:
	var t := get_pdip_tier()
	return {
		"live": is_faction_active("pdip"),
		"value": _js_round(_pdip_val()),
		"tier": t,
		"cut": get_pdip_cut(),
		"gain_mult": get_pdip_gain_mult(),
		"cost_mult": get_pdip_cost_mult(),
		"adjust": -_js_round(float(t) * PDIP_FLOOR_ADJUST * _opp_scale()),
		"locked": is_pdip_locked(),
	}


func on_pdip_interaction() -> void:
	if not is_faction_active("pdip") or pdip_touched:
		return
	pdip_touched = true
	pdip_value = maxf(0.0, _pdip_val() - PDIP_TOUCH_RELIEF)
	pdip_has_value = true


func on_pdip_delta(delta: float) -> void:
	if not is_faction_active("pdip") or is_zero_approx(delta):
		return
	pdip_value = clampf(_pdip_val() - delta * PDIP_EASE, 0.0, 100.0)
	pdip_has_value = true


func _add_grievance(amount: float, why: String) -> void:
	if is_zero_approx(amount):
		return
	grievance = clampf(grievance + amount, 0.0, GRIEVANCE_CAP)
	if not why.is_empty():
		var t_num := CampaignManager.current_turn if CampaignManager != null else 1
		opp_log.append({"turn": t_num, "grievance": amount, "why": why})


func _mark_disruption() -> void:
	if CampaignManager != null:
		disruption_turn = CampaignManager.current_turn


func _quiet_turn() -> bool:
	if CampaignManager == null:
		return true
	return disruption_turn != CampaignManager.current_turn


func _flare_running() -> bool:
	return timor_flare > 0 or aceh_flare > 0


func _start_flare(theatre: String) -> void:
	if _flare_running():
		return
	if theatre == "timor":
		timor_flare = 3
	else:
		aceh_flare = 3


func _fire_incident(incident_id: String) -> void:
	if incident_id.is_empty():
		return
	_mark_disruption()
	var t_num := CampaignManager.current_turn if CampaignManager != null else 1
	opp_log.append({"turn": t_num, "incident": incident_id})
	incident_count += 1


func _effect_mid(v: Variant) -> float:
	if v is Array and v.size() == 2:
		return (float(v[0]) + float(v[1])) / 2.0
	if v is String and String(v).contains(".."):
		var parts := String(v).split("..", false)
		if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
			return (parts[0].strip_edges().to_float() + parts[1].strip_edges().to_float()) / 2.0
		return 0.0
	if v is int or v is float:
		return float(v)
	return 0.0


func _detect_theatre(ev_id: String) -> String:
	var id_low := ev_id.to_lower()
	for kw in ["timor", "referendum", "peacekeeper", "interfet", "dili"]:
		if id_low.contains(kw):
			return "timor"
	if id_low.contains("aceh"):
		return "aceh"
	# Word-boundary match for "gam"
	var tokens := id_low.replace("-", "_").split("_", false)
	if tokens.has("gam"):
		return "aceh"
	return ""


func _is_peaceful_option(ev: CrisisEventData, option_idx: int, opt: EventOptionData) -> bool:
	if ev != null and KNOWN_PEACEFUL_OPTIONS.has(ev.id):
		var known: Array = KNOWN_PEACEFUL_OPTIONS[ev.id]
		if known.has(option_idx):
			return true
	if opt == null:
		return false
	var e := opt.effects
	var cred_gain := _effect_mid(e.get("intl", 0)) + _effect_mid(e.get("ref", 0))
	var mil_gain := _effect_mid(e.get("mil", 0)) + _effect_mid(e.get("abri", 0))
	return cred_gain > 0.0 and mil_gain <= 0.0


func on_event_choice(ev: CrisisEventData, option_idx: int, opt: EventOptionData) -> Dictionary:
	if ev != null and opt != null:
		var theatre := _detect_theatre(ev.id)
		if not theatre.is_empty() and _is_peaceful_option(ev, option_idx, opt):
			_add_grievance(2.0, theatre + "_concession")
	return {
		"sabotaged": false,
		"effects": null,
		"suffix": "",
	}


func snapshot_seats() -> Dictionary:
	var snap: Dictionary = {}
	if CampaignManager == null:
		return snap
	for fk in CampaignManager.factions.keys():
		snap[String(fk)] = int(CampaignManager.factions[fk].get("seats", 0))
	return snap


func record_seat_transfer(before: Dictionary) -> void:
	if before.is_empty() or CampaignManager == null:
		return
	for fk in CampaignManager.factions.keys():
		var key := String(fk)
		var cur_seats := int(CampaignManager.factions[key].get("seats", 0))
		var prev_seats := int(before.get(key, 0))
		var gain := cur_seats - prev_seats
		if gain > 0:
			tainted[key] = int(tainted.get(key, 0)) + gain


func _trigger_constitutional_crisis() -> void:
	crisis = true
	abri_abolished = true
	mil_phase = "patience"
	mil_value = 0.0
	mil_touched = false
	timor_flare = 0
	aceh_flare = 0
	_add_grievance(6.0, "abolished_abri_seats")
	_mark_disruption()


func on_decree_enacted(decree: DecreeData) -> void:
	if decree == null:
		return
	var dtype := decree.id
	if GRIEVANCE_DECREES.has(dtype):
		_add_grievance(float(GRIEVANCE_DECREES[dtype]), "decree:" + dtype)
	if dtype == "abolish_abri_mpr_seats":
		_trigger_constitutional_crisis()
	if decree.military_shock > 0:
		apply_military_shock(float(decree.military_shock))
	if REGIONAL_DECREES.has(dtype) and get_military_hostility() >= 2 and _quiet_turn():
		_mark_disruption()
		if dtype == "aceh_special_status_law":
			_start_flare("aceh")
		_add_grievance(2.0, "regional_reform")


func _run_military_incidents() -> bool:
	if not _mil_live() or abri_abolished or not _quiet_turn():
		return false
	if timor_flare > 0:
		_fire_incident("timor_militia")
		timor_flare -= 1
		return true
	if aceh_flare > 0:
		_fire_incident("aceh_flare")
		aceh_flare -= 1
		return true

	var lvl := get_military_hostility()
	if lvl == 0:
		return false
	var base_chance := float(MIL_INCIDENT_CHANCE.get(lvl, 0.5))
	var chance := base_chance * minf(1.0, 0.4 + 0.6 * _opp_scale())
	if rng.randf() > chance:
		return false

	var cendana_v := int(CampaignManager.stats.get("cendana", 0)) if CampaignManager != null else 0
	var stab_v := int(CampaignManager.stats.get("stab", 0)) if CampaignManager != null else 0
	var econ_v := int(CampaignManager.stats.get("econ", 0)) if CampaignManager != null else 0

	var candidates: Array[Dictionary] = [
		{"id": "kostrad_gates", "min_lvl": 2, "max_lvl": 3, "weight": 3, "ok": true},
		{"id": "bais_cash", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": cendana_v < 95},
		{"id": "armed_protesters", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": cendana_v >= 55},
		{"id": "shops_burning", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": stab_v < 60},
		{"id": "minority_scapegoat", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": cendana_v >= 60},
		{"id": "dossier_leak", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": true},
		{"id": "banyuwangi_ninjas", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": true},
		{"id": "maluku_ammo", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": true},
		{"id": "capital_flight_panic", "min_lvl": 2, "max_lvl": 3, "weight": 2, "ok": econ_v < 65},
		{"id": "censure_talks", "min_lvl": 3, "max_lvl": 3, "weight": 3, "ok": true},
		{"id": "grumbling", "min_lvl": 1, "max_lvl": 1, "weight": 3, "ok": true},
	]

	var pool: Array[Dictionary] = []
	var total_w := 0
	for inc in candidates:
		if bool(inc["ok"]) and lvl >= int(inc["min_lvl"]) and lvl <= int(inc["max_lvl"]):
			pool.append(inc)
			total_w += int(inc["weight"])
	if pool.is_empty() or total_w <= 0:
		return false

	var r := rng.randf() * float(total_w)
	var picked := String(pool[0]["id"])
	for inc in pool:
		r -= float(inc["weight"])
		if r <= 0.0:
			picked = String(inc["id"])
			break
	_fire_incident(picked)
	return true


func _step_military_meter() -> void:
	if not _mil_live() or abri_abolished:
		mil_touched = false
		return
	var lvl := get_military_hostility()
	var aff := float(CampaignManager.factions["abri"]["affinity"]) if (CampaignManager != null and CampaignManager.factions.has("abri")) else 0.0
	if mil_phase == "anger":
		var g := clampf((aff - MIL_GOODWILL_FROM) / (MIL_GOODWILL_FULL - MIL_GOODWILL_FROM), 0.0, 1.0)
		if g > 0.0:
			mil_value = maxf(0.0, mil_value - _diff_val(MIL_GOODWILL, "milGoodwill") * g)
		if not mil_touched:
			var open_f := clampf(1.0 - (aff - MIL_RISE_FADE_FROM) / (MIL_RISE_FADE_TO - MIL_RISE_FADE_FROM), 0.0, 1.0)
			var rate := (_diff_val(MIL_ANGER_RISE, "milAngerRise") + (2.0 if lvl >= 2 else 0.0)) * open_f
			mil_value = minf(100.0, mil_value + rate)
		if mil_value <= 0.0:
			mil_phase = "patience"
			mil_value = MIL_RETURN_PATIENCE
		mil_touched = false
		return

	if mil_touched:
		mil_touched = false
		return
	var decay_rate := _diff_val(MIL_PATIENCE_DECAY, "milPatienceDecay") * (1.5 if lvl >= 2 else 1.0)
	mil_value = maxf(0.0, mil_value - decay_rate)
	if mil_value <= 0.0:
		mil_phase = "anger"
		mil_value = 0.0


func _step_pdip_end_of_turn() -> void:
	if not is_faction_active("pdip"):
		pdip_touched = false
		return
	var aff := float(CampaignManager.factions["pdip"]["affinity"])
	if not pdip_touched:
		var pop_v := float(CampaignManager.stats.get("pop", 0))
		var ref_v := float(CampaignManager.stats.get("ref", 0))
		var public_goodwill := (pop_v + ref_v) / 2.0
		var reform_dampener := 0.65 if public_goodwill >= 65.0 else (0.85 if public_goodwill >= 50.0 else 1.0)
		var aff_mod := 1.1 if aff < 25.0 else (1.0 if aff < 50.0 else 0.8)
		pdip_value = minf(100.0, _pdip_val() + _diff_val(PDIP_RISE, "pdipRise") * aff_mod * reform_dampener)
		pdip_has_value = true
	pdip_touched = false
	var t := get_pdip_tier()
	if t > 0:
		CampaignManager.factions["pdip"]["affinity"] = CampaignManager.clamp_faction(
			"pdip",
			float(CampaignManager.factions["pdip"]["affinity"]) - PDIP_DRAG * float(t) * _opp_scale()
		)


func on_end_of_turn() -> void:
	if CampaignManager == null or not CampaignManager.game_started:
		return
	var lvl := get_military_hostility()
	if opp_log.size() > 60:
		opp_log = opp_log.slice(opp_log.size() - 60)

	_run_military_incidents()
	_step_military_meter()
	_step_pdip_end_of_turn()

	if lvl >= 2:
		_add_grievance(2.0 if lvl == 3 else 1.0, "hostile_military")
	elif lvl == 0 and grievance > 0.0 and not crisis:
		grievance = maxf(0.0, grievance - 0.5)

	if _opp_scale() > 0.25 and is_faction_active("pdip") and is_faction_active("poros_tengah"):
		var a := float(CampaignManager.factions["pdip"]["affinity"])
		var b := float(CampaignManager.factions["poros_tengah"]["affinity"])
		if a >= TENSION_THRESHOLD and b >= TENSION_THRESHOLD:
			coalition_ticks += 1

	last_turn_cendana = int(CampaignManager.stats.get("cendana", 95))


func get_betrayal_pressure() -> float:
	if CampaignManager == null:
		return 0.0
	var s := CampaignManager.stats
	var stab_v := int(s.get("stab", 0))
	var econ_v := int(s.get("econ", 0))
	var cendana_v := int(s.get("cendana", 0))
	var pop_v := int(s.get("pop", 0))
	var ref_v := int(s.get("ref", 0))

	var pressure := 0.0
	if stab_v < 25:
		pressure += 14.0
	elif stab_v < 45:
		pressure += 7.0
	elif stab_v >= 75:
		pressure -= 5.0

	if econ_v < 25:
		pressure += 12.0
	elif econ_v < 45:
		pressure += 6.0
	elif econ_v >= 75:
		pressure -= 4.0

	if cendana_v >= 80:
		pressure += 14.0
	elif cendana_v >= 60:
		pressure += 7.0
	elif cendana_v <= 30:
		pressure -= 5.0

	if pop_v < 30:
		pressure += 8.0
	elif pop_v < 45:
		pressure += 4.0

	if ref_v < 30:
		pressure += 8.0
	elif ref_v < 45:
		pressure += 4.0

	return maxf(0.0, pressure * _opp_scale())


func get_defection_rate(faction_id: String, eff_aff: float) -> float:
	if faction_id == "golkar_habibie":
		return 0.02

	var pressure := get_betrayal_pressure()
	var susceptibility := 1.0
	match faction_id:
		"golkar_akbar":
			susceptibility = 1.45
		"utusan_daerah":
			susceptibility = 1.30
		"poros_tengah":
			susceptibility = 1.35
		"other_parties":
			susceptibility = 1.25
		"abri":
			susceptibility = 0.50

	var loyalty_shield := 1.25
	if eff_aff >= 85.0:
		loyalty_shield = 0.20
	elif eff_aff >= 70.0:
		loyalty_shield = 0.50
	elif eff_aff >= 50.0:
		loyalty_shield = 0.90

	var base_defection := (pressure * 0.0085) * susceptibility * loyalty_shield
	var o := _diff_opp()
	var def_mult := float(o["defectionMult"]) if (o.has("defectionMult") and (o["defectionMult"] is int or o["defectionMult"] is float)) else 1.0
	return clampf(base_defection * def_mult, 0.0, 0.55)


func affinity_adjust(faction_id: String) -> int:
	var s := _opp_scale()
	var adj := 0
	if s > 0.0:
		if faction_id == "pdip":
			adj -= mini(18, _js_round(grievance * 1.35 * s))

		if (faction_id == "pdip" or faction_id == "poros_tengah") and is_faction_active("pdip") and is_faction_active("poros_tengah"):
			var a := float(CampaignManager.factions["pdip"]["affinity"])
			var b := float(CampaignManager.factions["poros_tengah"]["affinity"])
			if a >= 65.0 and b >= 65.0:
				var me := a if faction_id == "pdip" else b
				adj -= _js_round(minf(me - 60.0, 16.0) * 0.65 * s)

		if crisis:
			if faction_id == "golkar_akbar":
				adj -= _js_round(12.0 * s)
			elif faction_id == "utusan_daerah":
				adj -= _js_round(6.0 * s)

	if faction_id == "pdip":
		adj -= _js_round(float(get_pdip_tier()) * PDIP_FLOOR_ADJUST * s)

	return adj


func taint_loss(faction_id: String, vote_rate: float) -> float:
	var t := float(int(tainted.get(faction_id, 0)))
	return t * 0.35 * _opp_scale() * vote_rate


func election_seat_adjust(
	faction_id: String,
	final_aff: float,
	votes_for: int,
	votes_against: int,
	blank_votes: int
) -> Dictionary:
	var s := _opp_scale()
	var vf := votes_for
	var va := votes_against
	var vb := blank_votes
	var locked := false

	if s >= 0.5 and vf > 0:
		var rate := get_defection_rate(faction_id, final_aff) * 0.65
		var flip := mini(vf, _js_round(float(vf) * rate))
		vf -= flip
		va += flip

	var t := int(tainted.get(faction_id, 0))
	if t > 0 and vf > 0:
		var share := float(vf) / float(maxi(1, vf + va))
		var lost := mini(vf, _js_round(float(t) * 0.35 * s * share))
		vf -= lost
		vb += lost

	if is_vote_locked(faction_id):
		var seats := vf + va + vb
		if CampaignManager != null and CampaignManager.factions.has(faction_id):
			seats = int(CampaignManager.factions[faction_id].get("seats", seats))
		vf = 0
		va = seats
		vb = 0
		locked = true

	return {
		"votes_for": vf,
		"votes_against": va,
		"blank_votes": vb,
		"locked": locked,
	}


func original_chamber_size() -> int:
	if ContentDB != null and ContentDB.catalog != null and not ContentDB.catalog.factions.is_empty():
		var total := 0
		for fd in ContentDB.catalog.factions:
			total += fd.initial_seats
		if total > 0:
			return total
	return 700


func meets_quorum(votes_for: int) -> bool:
	var orig := original_chamber_size()
	return votes_for >= int(floor(float(orig) / 2.0)) + 1


func get_election_drama() -> Dictionary:
	var out := {
		"moodSwing": 7,
		"wildcardChance": 0.50,
		"wildcardMin": 20,
		"wildcardMax": 50,
		"crossoverRate": 0.35,
		"surgeBias": 15,
		"blocBias": 10,
	}
	var diff_id := CampaignManager.selected_difficulty if CampaignManager != null else "historical"
	var base_drama: Dictionary = DEFAULT_DRAMA.get(diff_id, DEFAULT_DRAMA["high"])
	for k in base_drama.keys():
		out[String(k)] = base_drama[k]
	var o := _diff_opp()
	var ov_drama: Variant = o.get("drama", null)
	if ov_drama is Dictionary:
		for k in ov_drama.keys():
			out[String(k)] = ov_drama[k]
	return out


func get_whip_margin() -> float:
	if CampaignManager == null or not CampaignManager.game_started:
		return 0.0
	var gov_stability := CampaignManager.get_gov_stability()
	var cendana_sabotage := _js_round(float(int(CampaignManager.stats.get("cendana", 0)) - 50) / 10.0)
	var stability_floor_mod := _js_round(float(gov_stability - 50) / 10.0)

	var est_votes := 0.0
	var active_total_seats := 0

	for key in CampaignManager.active_faction_order:
		if not CampaignManager.factions.has(key) or bool(CampaignManager.banned_factions.get(key, false)):
			continue
		var f: Dictionary = CampaignManager.factions[key]
		var seats := int(f.get("seats", 0))
		if seats <= 0:
			continue
		active_total_seats += seats
		if is_vote_locked(key):
			continue
		var favor_bonus := int(f.get("favor", 0)) * 8
		var adv_adj := affinity_adjust(key)
		var eff_aff := CampaignManager.clamp_faction(
			key,
			float(f["affinity"]) + float(favor_bonus + stability_floor_mod - cendana_sabotage + adv_adj)
		)
		var baseline_turnout := 0.0
		if key == "pdip" or key == "poros_tengah" or key == "abri":
			if eff_aff >= 80.0:
				baseline_turnout = 0.96
			elif eff_aff >= 65.0:
				baseline_turnout = 0.72
			elif eff_aff >= 50.0:
				baseline_turnout = 0.42
			elif eff_aff >= 35.0:
				baseline_turnout = 0.15
		else:
			baseline_turnout = eff_aff / 100.0
		var def_rate := get_defection_rate(key, eff_aff)
		var actual_vote_rate := maxf(0.0, baseline_turnout - def_rate)
		est_votes += float(seats) * actual_vote_rate
		est_votes -= taint_loss(key, actual_vote_rate)

	var majority_mark := maxi(int(floor(float(active_total_seats) / 2.0)) + 1, int(floor(float(original_chamber_size()) / 2.0)) + 1)
	return est_votes - float(majority_mark)


func serialize_state() -> Dictionary:
	var pdip_serialized: Variant = null
	if pdip_has_value:
		pdip_serialized = float(_js_round(pdip_value * 100.0)) / 100.0
	return {
		"last_turn_cendana": last_turn_cendana,
		"grievance": grievance,
		"tainted": tainted.duplicate(true),
		"crisis": crisis,
		"abri_abolished": abri_abolished,
		"disruption_turn": disruption_turn,
		"coalition_ticks": coalition_ticks,
		"incident_count": incident_count,
		"log": opp_log.duplicate(true),
		"tni": {
			"phase": mil_phase,
			"value": mil_value,
			"touched": mil_touched,
			"timor_flare": timor_flare,
			"aceh_flare": aceh_flare,
		},
		"pdip": {
			"value": pdip_serialized,
			"touched": pdip_touched,
		},
	}


func restore_state(data: Dictionary) -> void:
	reset_for_campaign()
	if data.is_empty():
		return

	if data.has("last_turn_cendana") or data.has("lastTurnCendana"):
		last_turn_cendana = _to_int(data.get("last_turn_cendana", data.get("lastTurnCendana", last_turn_cendana)), last_turn_cendana)
	if data.has("grievance"):
		grievance = clampf(_to_float(data["grievance"], 0.0), 0.0, GRIEVANCE_CAP)
	if data.has("tainted") and data["tainted"] is Dictionary:
		tainted.clear()
		var raw_tainted: Dictionary = data["tainted"]
		for rk in raw_tainted.keys():
			tainted[str(rk)] = _to_int(raw_tainted[rk], 0)
	if data.has("crisis"):
		crisis = bool(data["crisis"])
	if data.has("abri_abolished") or data.has("abriAbolished"):
		abri_abolished = bool(data.get("abri_abolished", data.get("abriAbolished", false)))
	if data.has("disruption_turn") or data.has("disruptionTurn"):
		disruption_turn = _to_int(data.get("disruption_turn", data.get("disruptionTurn", -1)), -1)
	if data.has("coalition_ticks") or data.has("coalitionTicks"):
		coalition_ticks = _to_int(data.get("coalition_ticks", data.get("coalitionTicks", 0)), 0)
	if data.has("incident_count") or data.has("incidentCount"):
		incident_count = _to_int(data.get("incident_count", data.get("incidentCount", 0)), 0)

	if data.has("log") and data["log"] is Array:
		opp_log.clear()
		for raw_entry in data["log"]:
			if raw_entry is Dictionary:
				var norm_entry: Dictionary = raw_entry.duplicate(true)
				if norm_entry.has("turn"):
					norm_entry["turn"] = _to_int(norm_entry["turn"], 1)
				if norm_entry.has("grievance"):
					norm_entry["grievance"] = _to_float(norm_entry["grievance"], 0.0)
				opp_log.append(norm_entry)

	var mods_dict: Dictionary = data["mods"] if (data.has("mods") and data["mods"] is Dictionary) else {}

	var tni_src: Dictionary = {}
	if data.has("tni") and data["tni"] is Dictionary:
		tni_src = data["tni"]
	elif mods_dict.has("tni") and mods_dict["tni"] is Dictionary:
		tni_src = mods_dict["tni"]
	elif data.has("milPhase") or data.has("timorFlare"):
		tni_src = {
			"phase": data.get("milPhase", "patience"),
			"value": data.get("milValue", MIL_START_PATIENCE),
			"touched": data.get("milTouched", false),
			"timor_flare": data.get("timorFlare", 0),
			"aceh_flare": data.get("acehFlare", 0),
		}

	if not tni_src.is_empty():
		var ph := str(tni_src.get("phase", mil_phase))
		if ph == "anger" or ph == "patience":
			mil_phase = ph
		if tni_src.has("value") and tni_src["value"] != null:
			mil_value = clampf(_to_float(tni_src["value"], mil_value), 0.0, 100.0)
		mil_touched = bool(tni_src.get("touched", false))
		timor_flare = _to_int(tni_src.get("timor_flare", tni_src.get("timorFlare", 0)), 0)
		aceh_flare = _to_int(tni_src.get("aceh_flare", tni_src.get("acehFlare", 0)), 0)

	var pdip_src: Dictionary = {}
	if data.has("pdip") and data["pdip"] is Dictionary:
		pdip_src = data["pdip"]
	elif mods_dict.has("pdip") and mods_dict["pdip"] is Dictionary:
		pdip_src = mods_dict["pdip"]

	if not pdip_src.is_empty():
		if pdip_src.has("value"):
			if pdip_src["value"] == null:
				pdip_has_value = false
				pdip_value = 0.0
			else:
				pdip_value = clampf(_to_float(pdip_src["value"], 0.0), 0.0, 100.0)
				pdip_has_value = true
		pdip_touched = bool(pdip_src.get("touched", false))


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
