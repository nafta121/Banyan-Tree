extends Node

signal achievement_unlocked(ach_id: String)

const CHALLENGE_DIFFICULTIES := ["medium", "high", "historical", "ucn"]
const STANDARD_DIFFICULTIES := ["easy", "medium", "high", "historical"]

const FINAL_APPEAL_IDS := [
	"tni_final_appeal",
	"golkar_final_appeal",
	"loyalist_final_stand",
	"pdip_final_appeal",
	"axis_final_deal",
	"others_final_appeal",
	"daerah_final_appeal",
	"golongan_final_appeal",
]

const CENTER_HOLDS_FACTIONS := [
	"golkar_habibie",
	"golkar_akbar",
	"utusan_daerah",
	"utusan_golongan",
	"other_parties",
	"abri",
]

var unlocked_ids: PackedStringArray = PackedStringArray()
var difficulty_wins: PackedStringArray = PackedStringArray()


func is_unlocked(ach_id: String) -> bool:
	return unlocked_ids.has(ach_id)


func unlock(ach_id: String) -> void:
	if ach_id.is_empty() or unlocked_ids.has(ach_id):
		return
	unlocked_ids.append(ach_id)
	_sync_to_save_service()
	achievement_unlocked.emit(ach_id)


func record_difficulty_win(difficulty_id: String) -> bool:
	if STANDARD_DIFFICULTIES.has(difficulty_id) and not difficulty_wins.has(difficulty_id):
		difficulty_wins.append(difficulty_id)
		_sync_to_save_service()
	for std_diff in STANDARD_DIFFICULTIES:
		if not difficulty_wins.has(std_diff):
			return false
	return true


func _sync_to_save_service() -> void:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc == null:
		return
	if "settings" in save_svc and save_svc.get("settings") != null:
		var settings_obj: UserSettingsData = save_svc.get("settings") as UserSettingsData
		if settings_obj != null:
			settings_obj.unlocked_achievements = unlocked_ids.duplicate()
			settings_obj.difficulty_wins = difficulty_wins.duplicate()
	if save_svc.has_method("save_settings"):
		save_svc.call("save_settings")


func _all_decrees_enacted(ids: Array) -> bool:
	if CampaignManager == null:
		return false
	for raw_id in ids:
		if not bool(CampaignManager.active_decrees.get(String(raw_id), false)):
			return false
	return true


func _all_routines_used(ids: Array) -> bool:
	if CampaignManager == null:
		return false
	for raw_id in ids:
		if int(CampaignManager.action_usage_count.get(String(raw_id), 0)) <= 0:
			return false
	return true


func _any_decree_enacted() -> bool:
	if CampaignManager == null:
		return false
	for raw_id in CampaignManager.active_decrees.keys():
		if bool(CampaignManager.active_decrees[raw_id]):
			return true
	return false


func _has_imf_durability() -> bool:
	return _all_decrees_enacted([
		"imf_fuel_subsidy",
		"imf_bulog_deregulation",
		"imf_ibra_liquidation",
	])


func _faction_aff(faction_id: String, fallback: float = -1.0) -> float:
	if CampaignManager == null or not CampaignManager.factions.has(faction_id):
		return fallback
	return float(CampaignManager.factions[faction_id].get("affinity", fallback))


func evaluate_mid_campaign() -> void:
	if CampaignManager == null or not CampaignManager.game_started:
		return

	var cur_gov_stab := CampaignManager.get_gov_stability()
	if cur_gov_stab < CampaignManager.lowest_gov_stability:
		CampaignManager.lowest_gov_stability = cur_gov_stab

	var s := CampaignManager.stats
	var is_challenge_difficulty := CHALLENGE_DIFFICULTIES.has(CampaignManager.selected_difficulty)

	if is_challenge_difficulty:
		if int(s.get("pop", 0)) >= 90:
			unlock("pop_max")
		if int(s.get("cendana", 100)) <= 0:
			unlock("cendana_zero")
		if CampaignManager.factions.has("pdip") and _faction_aff("pdip") >= 100.0:
			unlock("pdip_max")
		if int(s.get("stab", 0)) >= 90:
			unlock("aman_terkendali")
		if int(s.get("intl", 0)) >= 100 and int(s.get("econ", 100)) <= 15 and int(s.get("pop", 100)) <= 30 and _has_imf_durability():
			unlock("always_more_austerity")

	if CampaignManager.sp3_upheld_with_high_cendana:
		unlock("halo_andi")

	var bb := CampaignManager.bank_bali_clean_steps
	var ci := CampaignManager.completed_interactions
	if (
		bool(bb.get("frozeEGP", false))
		and bool(bb.get("pwcAccess", false))
		and bool(ci.get("pdip_pansus_bankbali", false))
		and bool(bb.get("declassifiedPwC", false))
	):
		unlock("baligate_clean")

	var ad := CampaignManager.active_decrees
	if bool(ad.get("ban_pdip_subversion", false)):
		unlock("kudatuli_redux")
	if bool(ad.get("dissolve_golkar_old_guard", false)):
		unlock("beringin_tumbang")
	if bool(ad.get("abolish_abri_mpr_seats", false)) and bool(ad.get("abolish_kodam_territorial", false)):
		unlock("back_to_the_barracks")
	if bool(ad.get("enforce_asas_tunggal_ban", false)):
		unlock("asas_tunggal_restored")
	if bool(ad.get("unify_golkar_slipi", false)):
		unlock("unify_golkar")
	if bool(ad.get("rainbow_coalition_accord", false)):
		unlock("rainbow_coalition")

	if _all_decrees_enacted([
		"anti_corruption",
		"civil_service_neutrality",
		"direct_presidential_amendment",
		"suharto_asset_seizure_tribunal",
		"political_prisoner_release",
		"human_rights_commission_powers",
		"broadcast_liberalization",
	]):
		unlock("total_reformasi")

	if _all_decrees_enacted([
		"civilian_defense_ministry",
		"police_military_separation",
		"abolish_kodam_territorial",
		"abolish_abri_mpr_seats",
	]):
		unlock("finis_dwifungsi")

	if _all_decrees_enacted([
		"regional_autonomy",
		"aceh_special_status_law",
		"maluku_irja_division",
	]):
		unlock("nkri_terms")

	if bool(ad.get("chinese_cultural_ban_repeal", false)) and _all_routines_used([
		"trisakti_semanggi_commemoration",
		"chinatown_reconciliation",
		"womens_commission",
		"sbkri_review",
		"declassify_1965_files",
	]):
		unlock("tolak_lupa")

	if bool(ad.get("suharto_asset_seizure_tribunal", false)) and _all_routines_used([
		"seize_cendana_tolls",
		"audit_kodam_foundations",
	]):
		unlock("cendana_cashback")

	if _all_decrees_enacted([
		"ratify_kamra_militia_bill",
		"reinstate_siupp_censorship",
		"purge_utusan_golongan",
	]) and _all_routines_used(["mobilize_pam_swakarsa"]):
		unlock("empire_strikes_beringin")

	if bool(ad.get("reinstate_siupp_censorship", false)):
		unlock("siupp_is_back")

	var final_appeals_done := 0
	for fa_id in FINAL_APPEAL_IDS:
		if bool(ci.get(fa_id, false)):
			final_appeals_done += 1
	if final_appeals_done >= 2:
		unlock("halo_halo_senayan")

	var favored_factions := 0
	for fk in CampaignManager.factions.keys():
		if int(CampaignManager.factions[fk].get("favor", 0)) >= 1:
			favored_factions += 1
	if favored_factions >= 6:
		unlock("utang_budi")


func evaluate_election_end(summary: Dictionary) -> void:
	if CampaignManager == null:
		return

	evaluate_mid_campaign()

	var accepted := bool(summary.get("accepted", summary.get("won", false)))
	var total_for := int(summary.get("total_for", summary.get("forVotes", 0)))
	var total_blank := int(summary.get("total_blank", summary.get("blankVotes", 0)))
	var raw_factions: Variant = summary.get("factions", summary.get("factionBreakdown", []))
	var faction_rows: Array = raw_factions if raw_factions is Array else []

	var s := CampaignManager.stats
	var ad := CampaignManager.active_decrees
	var ci := CampaignManager.completed_interactions
	var bb := CampaignManager.bank_bali_clean_steps
	var tp := CampaignManager.timor_promise_steps

	unlock("complete_run")
	if CampaignManager.pc >= 100:
		unlock("sedia_payung")

	if (
		_faction_aff("pdip") >= 60.0
		and _faction_aff("poros_tengah") >= 60.0
		and _faction_aff("golkar_akbar") >= 60.0
		and _faction_aff("abri") >= 60.0
	):
		unlock("bhinneka_coalition")

	if (
		bool(bb.get("defiedIMF", false))
		and bool(ad.get("currency_board", false))
		and int(s.get("econ", 0)) >= 60
	):
		unlock("camdessus_arms")

	if accepted:
		unlock("win_any")
		if OppositionManager != null:
			if OppositionManager.is_pdip_locked():
				unlock("kaos_merah")
			var mil_meter := OppositionManager.get_military_meter()
			if bool(mil_meter.get("live", false)) and not OppositionManager.is_military_broken():
				unlock("ngopi_dulu")
			if (
				OppositionManager.is_faction_active("pdip")
				and OppositionManager.is_faction_active("poros_tengah")
				and OppositionManager.coalition_ticks >= 2
				and _faction_aff("pdip") >= 70.0
				and _faction_aff("poros_tengah") >= 70.0
			):
				unlock("odd_bedfellows")

		if CampaignManager.selected_difficulty == "historical":
			unlock("win_historical")

		if (
			int(s.get("intl", 0)) >= 100
			and int(s.get("econ", 100)) <= 15
			and int(s.get("pop", 100)) <= 30
			and _has_imf_durability()
		):
			unlock("bruning_impressed")

		if CampaignManager.lowest_gov_stability < 35:
			unlock("mr_crack")

		if bool(ci.get("loyalist_bppt", false)) and bool(ci.get("loyalist_n250", false)):
			unlock("cleared_for_takeoff")

		if (
			OppositionManager != null
			and OppositionManager.is_military_broken()
			and bool(ad.get("police_military_separation", false))
			and bool(ad.get("human_rights_commission_powers", false))
		):
			unlock("dwifungsi_kaput")

		if (
			bool(tp.get("countdown", false))
			and bool(tp.get("votes", false))
			and bool(tp.get("peacekeepers", false))
		):
			unlock("thankless_burden")

		if int(s.get("cendana", 0)) >= 85 and int(s.get("ref", 100)) <= 25:
			unlock("enak_jamanku")

		if CampaignManager.pc == 0:
			unlock("fumes_in_the_tank")

		if int(s.get("econ", 100)) < 15:
			unlock("utang_nanti_dulu")
		if int(s.get("intl", 100)) < 15:
			unlock("persona_non_grata")
		if int(s.get("pop", 100)) < 15:
			unlock("sinetron_villain")

		if not _any_decree_enacted():
			unlock("presiden_rebahan")

		if record_difficulty_win(CampaignManager.selected_difficulty):
			unlock("khatam")

		if CampaignManager.selected_difficulty == "ucn" and SSSController != null and SSSController.is_run_maxed():
			unlock(SSSController.MAXED_ACH_ID)

		if (
			_faction_aff("poros_tengah") >= 85.0
			and _faction_aff("utusan_golongan") >= 80.0
			and _faction_aff("other_parties") >= 80.0
		):
			unlock("habibi_ya_habibi")

		if _all_center_blocs_backed(faction_rows):
			unlock("the_center_holds")

		if int(s.get("ref", 0)) >= 85 and int(s.get("cendana", 100)) <= 25:
			unlock("singa_reformasi")

		if bool(ad.get("invoke_supersemar_ii", false)) and bool(ad.get("cendana_restoration_pact", false)):
			unlock("orba_jilid_dua")

		if total_for >= 450:
			unlock("win_overwhelming")
		elif total_for >= 380:
			unlock("win_comfortable")
		else:
			unlock("win_narrow")
	else:
		var gov_tier := CampaignManager.get_gov_stability_tier_id()
		if gov_tier == "secure" or gov_tier == "stable":
			unlock("dipecat_dengan_hormat")

		if total_for >= 318 and total_for <= 326:
			unlock("deja_vu_322")

		if total_for >= 330 and total_for <= 350 and (total_for + total_blank) >= 351:
			unlock("those_who_stayed_silent")

		if (
			CampaignManager.factions.has("golkar_habibie")
			and _faction_aff("golkar_habibie") >= 85.0
			and CampaignManager.factions.has("golkar_akbar")
			and _faction_aff("golkar_akbar", 100.0) < 35.0
		):
			unlock("et_tu_akbar")

		if CampaignManager.helped_rais_speaker and _faction_aff("poros_tengah") >= 65.0:
			unlock("gus_dur_twist")

		if total_for >= 320:
			unlock("lose_narrow")
		elif total_for >= 200:
			unlock("lose_decisive")
		else:
			unlock("lose_overwhelming")


func _all_center_blocs_backed(faction_rows: Array) -> bool:
	for req_key in CENTER_HOLDS_FACTIONS:
		var matched := false
		for entry in faction_rows:
			if not (entry is Dictionary):
				continue
			var row: Dictionary = entry
			var row_key := String(row.get("id", row.get("key", "")))
			if row_key != req_key:
				continue
			var seats := int(row.get("seats", row.get("totalSeats", 0)))
			var v_for := int(row.get("votes_for", row.get("forVotes", row.get("targetFor", 0))))
			if seats > 0 and float(v_for) > float(seats) / 2.0:
				matched = true
			break
		if not matched:
			return false
	return true


func serialize_state() -> Dictionary:
	return {
		"unlocked_ids": Array(unlocked_ids),
		"difficulty_wins": Array(difficulty_wins),
	}


func restore_state(data: Dictionary) -> void:
	unlocked_ids.clear()
	difficulty_wins.clear()
	var raw_unlocked: Variant = data.get("unlocked_ids", data.get("unlocked_achievements", []))
	if raw_unlocked is Array or raw_unlocked is PackedStringArray:
		for item in raw_unlocked:
			var s := str(item).strip_edges()
			if not s.is_empty() and not unlocked_ids.has(s):
				unlocked_ids.append(s)
	var raw_wins: Variant = data.get("difficulty_wins", [])
	if raw_wins is Array or raw_wins is PackedStringArray:
		for item in raw_wins:
			var s := str(item).strip_edges()
			if STANDARD_DIFFICULTIES.has(s) and not difficulty_wins.has(s):
				difficulty_wins.append(s)
