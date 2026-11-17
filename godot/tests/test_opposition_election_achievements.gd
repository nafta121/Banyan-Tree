extends TestBase


func run() -> int:
	_test_tni_patience_anger_resistance_and_crisis()
	_test_pdip_street_mobilization_and_tier4_lock()
	_test_opposition_grievance_tainted_defection_and_json_restore()
	_test_election_roll_call_determinism_and_351_quorum()
	_test_ucn_stat_achievements_and_all_59_achievements()
	return assertions_failed


func _test_tni_patience_anger_resistance_and_crisis() -> void:
	# 1. TNI shock memecah patience -> anger dan memotong perolehan global hingga 50% di Historical
	CampaignManager.start_new_campaign("historical", false)
	var m0 := OppositionManager.get_military_meter()
	assert_eq(bool(m0["live"]), true, "TNI meter live at start")
	assert_eq(String(m0["phase"]), "patience", "TNI starts in patience phase")
	assert_eq(int(m0["value"]), 50, "TNI starts at 50 patience")
	assert_eq(int(m0["hostility"]), 0, "TNI starts at hostility 0 when ABRI == 50")

	OppositionManager.apply_military_shock(60.0) # 50 - 60 = -10 -> anger = 7.5
	var m1 := OppositionManager.get_military_meter()
	assert_eq(String(m1["phase"]), "anger", "TNI shock 60 transitions to anger")
	assert_eq(int(m1["value"]), 8, "TNI anger 7.5 rounds to 8")
	assert_true(OppositionManager.is_military_broken(), "is_military_broken true in anger phase")

	OppositionManager.apply_military_shock(130.0) # dorong ke 100% anger
	assert_eq(int(OppositionManager.get_military_meter()["value"]), 100, "TNI anger clamped at 100")
	assert_near(OppositionManager.get_military_resistance(), 0.50, 0.01, "50% military resistance on Historical")
	assert_near(OppositionManager.get_military_gain_mult(), 0.50, 0.01, "50% military gain_mult (stubborn) on Historical")
	assert_eq(int(OppositionManager.get_military_meter()["hostility"]), 3, "hostility 3 at 100% anger")

	# Verify CampaignManager positive ABRI delta is halved by get_military_gain_mult(), and negative ABRI delta burns patience/anger
	CampaignManager.factions["abri"]["affinity"] = 50.0
	CampaignManager.apply_effects({"abri": 20})
	assert_near(float(CampaignManager.factions["abri"]["affinity"]), 60.0, 0.01, "+20 ABRI halved to +10 at 100% anger")
	assert_eq(int(CampaignManager.stats["mil"]), 60, "stats.mil synced to 60")

	# Verify on_military_interaction calms anger once per turn (7 points on Historical) and returns to patience=15 if <= 0
	OppositionManager.restore_state({"tni": {"phase": "anger", "value": 5.0, "touched": false}})
	OppositionManager.on_military_interaction()
	assert_eq(String(OppositionManager.get_military_meter()["phase"]), "patience", "calming anger <= 0 returns to patience")
	assert_eq(int(OppositionManager.get_military_meter()["value"]), 15, "returns to 15 patience")
	OppositionManager.on_military_interaction() # second call in same turn is ignored
	assert_eq(int(OppositionManager.get_military_meter()["value"]), 15, "on_military_interaction idempotent within turn")

	# Negative military delta via CampaignManager triggers insult (0.8x patience loss -> 0.6x anger overflow)
	OppositionManager.reset_for_campaign() # patience = 50
	CampaignManager.apply_effects({"mil": -30}) # insult(30) -> 50 - 24 = 26 patience
	assert_eq(String(OppositionManager.get_military_meter()["phase"]), "patience", "still patience after -30 mil")
	assert_eq(int(OppositionManager.get_military_meter()["value"]), 26, "patience 50 - 30*0.8 == 26")
	CampaignManager.apply_effects({"mil": -40}) # insult(40) -> 26 - 32 = -6 -> anger = max(5, 3.6) = 5
	assert_eq(String(OppositionManager.get_military_meter()["phase"]), "anger", "second insult crosses into anger")
	assert_eq(int(OppositionManager.get_military_meter()["value"]), 5, "minimum overflow anger == 5")

	# Abolishing ABRI MPR seats triggers constitutional crisis, disables resistance, keeps is_military_broken() true
	CampaignManager.start_new_campaign("historical", false)
	CampaignManager.is_action_phase = true
	CampaignManager.pc = 100
	CampaignManager.stats["ref"] = 90
	CampaignManager.stats["pop"] = 90
	CampaignManager.stats["stab"] = 90
	CampaignManager.current_turn = 10
	for dec_id in ["civilian_defense_ministry", "police_military_separation", "abolish_kodam_territorial"]:
		CampaignManager.turn_executive_used = false
		CampaignManager.pc = 100
		CampaignManager.stats["mil"] = 85
		CampaignManager.factions["abri"]["affinity"] = 85.0
		CampaignManager.enact_decree(dec_id)
	assert_eq(String(OppositionManager.get_military_meter()["phase"]), "anger", "anti-ABRI decrees shocked TNI into anger")
	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	CampaignManager.stats["ref"] = 90
	CampaignManager.stats["pop"] = 90
	var ab_res := CampaignManager.enact_decree("abolish_abri_mpr_seats")
	assert_true(bool(ab_res.get("ok", false)), "abolish_abri_mpr_seats enacted")
	assert_eq(OppositionManager.get_military_resistance(), 0.0, "military resistance drops to 0 once ABRI abolished")
	assert_eq(OppositionManager.get_military_gain_mult(), 1.0, "military gain mult resets to 1.0 once ABRI abolished")
	assert_true(OppositionManager.is_military_broken(), "is_military_broken stays true when ABRI abolished")


func _test_pdip_street_mobilization_and_tier4_lock() -> void:
	# 2. PDI-P 100% mengunci biaya 9.0x di Historical & memaksa 0 FOR / 153 AGAINST
	CampaignManager.start_new_campaign("historical", false)
	assert_eq(int(OppositionManager.get_pdip_meter()["value"]), 20, "PDI-P starts at 20% on Historical")
	assert_eq(OppositionManager.get_pdip_tier(), 0, "Tier 0 at 20%")
	assert_near(OppositionManager.get_pdip_cost_mult(), 1.0, 0.001, "1.0x cost mult <= 25%")

	OppositionManager.restore_state({"pdip": {"value": 100.0, "touched": false}})
	assert_true(OppositionManager.is_pdip_locked(), "PDI-P locked at 100%")
	assert_eq(OppositionManager.get_pdip_tier(), 4, "PDI-P tier 4 at 100%")
	assert_near(OppositionManager.get_pdip_cut(), 0.40, 0.001, "PDI-P cut 40% at tier 4 Historical")
	assert_near(OppositionManager.get_pdip_gain_mult(), 0.60, 0.001, "PDI-P gain mult 0.60 at tier 4 Historical")
	assert_near(OppositionManager.get_pdip_cost_mult(), 9.0, 0.01, "PDI-P cost mult 9.0x at 100% Historical")

	var adj := OppositionManager.election_seat_adjust("pdip", 95.0, 140, 13, 0)
	assert_eq(int(adj["votes_for"]), 0, "locked PDI-P forces 0 FOR")
	assert_eq(int(adj["votes_against"]), 153, "locked PDI-P forces 153 AGAINST")
	assert_eq(int(adj["blank_votes"]), 0, "locked PDI-P forces 0 BLANK")
	assert_eq(bool(adj["locked"]), true, "adj marks locked == true")
	assert_eq(OppositionManager.affinity_adjust("pdip"), -18, "Tier 4 floorAdjust -round(4*4.5*1.0) == -18")

	# Horse-trading with PDI-P blocked when locked at 100%
	CampaignManager.current_turn = 22
	CampaignManager.is_action_phase = true
	CampaignManager.pc = 100
	var ht_blocked := CampaignManager.execute_horse_trade("pdip", 1)
	assert_false(bool(ht_blocked.get("ok", true)), "horse trade blocked when PDI-P street locked")
	assert_eq(String(ht_blocked.get("reason", "")), "pdip_street_locked", "reason == pdip_street_locked")

	# UCN rank 20 PDI-P card: start=50%, costMax=12 -> 13.0x at 100%
	SSSController.apply_preset(20)
	CampaignManager.start_new_campaign("ucn", false)
	assert_eq(int(OppositionManager.get_pdip_meter()["value"]), 50, "UCN rank 20 PDI-P starts at 50%")
	assert_eq(OppositionManager.get_pdip_tier(), 2, "Tier 2 at 50%")
	OppositionManager.restore_state({"pdip": {"value": 100.0, "touched": false}})
	assert_near(OppositionManager.get_pdip_cost_mult(), 13.0, 0.01, "UCN rank 20 PDI-P cost mult 13.0x at 100%")
	SSSController.apply_preset(10)


func _test_opposition_grievance_tainted_defection_and_json_restore() -> void:
	CampaignManager.start_new_campaign("historical", false)

	# Peaceful Timor event choice adds +2 grievance (both via KNOWN_PEACEFUL_OPTIONS and effect-midpoint heuristic)
	var ev_ref := ContentDB.get_event_by_id("ev_referendum_countdown")
	assert_eq(ev_ref.turn_number, 5, "ev_referendum_countdown is Turn 5")
	CampaignManager.current_turn = ev_ref.turn_number
	CampaignManager.choose_event_option(0)
	assert_near(float(OppositionManager.serialize_state()["grievance"]), 2.0, 0.01, "+2 grievance from ev_referendum_countdown option 0")

	var ev_dili := ContentDB.get_event_by_id("ev_dili_flames")
	CampaignManager.current_turn = ev_dili.turn_number
	CampaignManager.event_resolved_this_turn = false
	CampaignManager.choose_event_option(0) # hardline military option -> no grievance added
	assert_near(float(OppositionManager.serialize_state()["grievance"]), 2.0, 0.01, "hardline ev_dili_flames option 0 adds 0 grievance")
	CampaignManager.current_turn = ev_dili.turn_number
	CampaignManager.event_resolved_this_turn = false
	CampaignManager.choose_event_option(1) # peaceful heuristic option -> +2 grievance
	assert_near(float(OppositionManager.serialize_state()["grievance"]), 4.0, 0.01, "peaceful ev_dili_flames option 1 adds +2 grievance")

	# Seat transfer tainting + walkout in election_seat_adjust
	CampaignManager.stats["ref"] = 20
	CampaignManager.stats["mil"] = 85
	CampaignManager.factions["abri"]["affinity"] = 85.0
	CampaignManager.pc = 100
	var purge_res := CampaignManager.enact_decree("purge_utusan_golongan")
	assert_true(bool(purge_res.get("ok", false)), "enacted purge_utusan_golongan")
	var opp_ser := OppositionManager.serialize_state()
	var tainted_map: Dictionary = opp_ser["tainted"]
	var total_tainted := 0
	for fk in tainted_map.keys():
		total_tainted += int(tainted_map[fk])
	assert_eq(total_tainted, 65, "all 65 redistributed seats recorded as tainted")

	# golkar_habibie has low 0.02 loyalist defection rate, plus tainted seats cause blank walkouts
	var gh_tainted := int(tainted_map.get("golkar_habibie", 0))
	assert_true(gh_tainted > 0, "golkar_habibie received tainted seats")
	var gh_adj := OppositionManager.election_seat_adjust("golkar_habibie", 90.0, 60, 5, 0)
	assert_true(int(gh_adj["blank_votes"]) > 0, "tainted seats walk out into blank_votes")
	assert_eq(int(gh_adj["votes_for"]) + int(gh_adj["votes_against"]) + int(gh_adj["blank_votes"]), 65, "seat count conserved across defection + walkout")

	# Double-dealing coalition tension (PDI-P & Poros Tengah both >= 62 at EOT; both >= 65 at election)
	CampaignManager.factions["pdip"]["affinity"] = 78.0
	CampaignManager.factions["poros_tengah"]["affinity"] = 78.0
	OppositionManager.on_end_of_turn()
	CampaignManager.factions["pdip"]["affinity"] = 78.0
	CampaignManager.factions["poros_tengah"]["affinity"] = 78.0
	OppositionManager.on_end_of_turn()
	assert_true(int(OppositionManager.serialize_state()["coalition_ticks"]) >= 2, "coalition_ticks incremented when PDI-P & Poros Tengah >= 62")
	assert_true(OppositionManager.affinity_adjust("poros_tengah") < 0, "double-dealing penalizes poros_tengah affinity_adjust")

	# JSON stringify -> parse_string -> restore_state type safety for Task 5 backup import
	OppositionManager.apply_military_shock(70.0)
	var full_json := JSON.stringify(CampaignManager.serialize_state())
	var parsed: Dictionary = JSON.parse_string(full_json)
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.restore_state(parsed)
	var restored_opp := OppositionManager.serialize_state()
	assert_eq(String(OppositionManager.get_military_meter()["phase"]), "anger", "restored TNI anger phase from JSON")
	assert_eq(typeof(restored_opp["coalition_ticks"]), TYPE_INT, "coalition_ticks normalized to TYPE_INT")
	assert_eq(typeof(restored_opp["tainted"]["golkar_habibie"]), TYPE_INT, "tainted seat count normalized to TYPE_INT")


func _test_election_roll_call_determinism_and_351_quorum() -> void:
	# 3. Review Focus #2: 30 kursi Golkar dikosongkan (670 aktif); 345 FOR vs 325 AGAINST tetap DITOLAK (< 351)
	CampaignManager.start_new_campaign("historical", false)
	CampaignManager.total_seats_vacated = 30
	CampaignManager.factions["golkar_akbar"]["seats"] = 0
	CampaignManager.banned_factions["golkar_akbar"] = true
	CampaignManager.factions["golkar_habibie"]["seats"] = 90
	assert_eq(OppositionManager.original_chamber_size(), 700, "original_chamber_size is always 700")
	assert_eq(OppositionManager.meets_quorum(345), false, "345 FOR fails 351 quorum")
	assert_eq(OppositionManager.meets_quorum(350), false, "350 FOR fails 351 quorum")
	assert_eq(OppositionManager.meets_quorum(351), true, "351 FOR meets 351 quorum")

	# Deterministic seeded roll call: identical seeds produce identical results
	CampaignManager.start_new_campaign("historical", false)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 19991020
	var roll_a := ElectionManager.compute_election_roll_call(rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 19991020
	var roll_b := ElectionManager.compute_election_roll_call(rng_b)

	assert_eq(int(roll_a["total_for"]), int(roll_b["total_for"]), "deterministic total_for with same RNG seed")
	assert_eq(int(roll_a["total_against"]), int(roll_b["total_against"]), "deterministic total_against with same RNG seed")
	assert_eq(int(roll_a["total_blank"]), int(roll_b["total_blank"]), "deterministic total_blank with same RNG seed")
	assert_eq(int(roll_a["chamber_seats"]), 700, "700 active chamber seats in standard session")
	assert_eq(int(roll_a["original_chamber_seats"]), 700, "700 original chamber seats")
	assert_eq(int(roll_a["total_for"]) + int(roll_a["total_against"]) + int(roll_a["total_blank"]), 700, "FOR + AGAINST + BLANK == 700")

	# Verify PDI-P 100% street lock inside full ElectionManager.compute_election_roll_call()
	OppositionManager.restore_state({"pdip": {"value": 100.0, "touched": false}})
	CampaignManager.factions["pdip"]["affinity"] = 100.0
	var rng_lock := RandomNumberGenerator.new()
	rng_lock.seed = 42
	var roll_locked := ElectionManager.compute_election_roll_call(rng_lock)
	var pdip_row: Dictionary = {}
	for f_row in roll_locked["factions"]:
		if String(f_row["id"]) == "pdip":
			pdip_row = f_row
			break
	assert_eq(int(pdip_row["votes_for"]), 0, "PDI-P 100% lock yields 0 FOR in roll call")
	assert_eq(int(pdip_row["votes_against"]), 153, "PDI-P 100% lock yields 153 AGAINST in roll call")
	assert_eq(int(pdip_row["blank_votes"]), 0, "PDI-P 100% lock yields 0 BLANK in roll call")

	# Full ElectionManager.compute_election_roll_call() verification of Review Focus #2 (670 seated, >50% of 670 FOR, but < 351 -> quorum_failed!)
	CampaignManager.start_new_campaign("easy", false)
	CampaignManager.total_seats_vacated = 30
	CampaignManager.factions["golkar_akbar"]["seats"] = 0
	CampaignManager.banned_factions["golkar_akbar"] = true
	CampaignManager.factions["golkar_habibie"]["seats"] = 90
	CampaignManager.stats = {"pop": 60, "mil": 60, "ref": 60, "econ": 60, "intl": 60, "stab": 60, "cendana": 40}
	# Tune affinities so expected FOR in 670-seat chamber lands around ~342 (> 335 majority of 670, but < 351 constitutional quorum)
	for fk in CampaignManager.factions.keys():
		CampaignManager.factions[fk]["affinity"] = 54.0
	CampaignManager.factions["golkar_habibie"]["affinity"] = 85.0
	CampaignManager.factions["pdip"]["affinity"] = 36.0 # 15% step
	CampaignManager.factions["poros_tengah"]["affinity"] = 55.0 # 42% step
	CampaignManager.factions["abri"]["affinity"] = 68.0 # 72% step

	var found_quorum_failure := false
	for s in range(1, 200):
		var test_rng := RandomNumberGenerator.new()
		test_rng.seed = s
		var res := ElectionManager.compute_election_roll_call(test_rng)
		assert_eq(int(res["chamber_seats"]), 670, "seated chamber == 670 when 30 Golkar seats vacated")
		assert_eq(int(res["original_chamber_seats"]), 700, "original_chamber_seats stays 700")
		assert_eq(int(res["total_for"]) + int(res["total_against"]) + int(res["total_blank"]), 670, "votes sum to 670")
		if int(res["total_for"]) > int(res["total_against"]) and int(res["total_for"]) < 351:
			assert_false(bool(res["accepted"]), "plurality < 351 in 670-seat chamber MUST be rejected")
			assert_true(bool(res["quorum_failed"]), "quorum_failed MUST be true when total_for > total_against but < 351")
			found_quorum_failure = true
			break
	assert_true(found_quorum_failure, "verified real roll call quorum_failed case with 670 active seats")


func _test_ucn_stat_achievements_and_all_59_achievements() -> void:
	assert_eq(ContentDB.catalog.achievements.size(), 59, "59 achievements in ContentDB catalog")

	var emitted_ids: Array[String] = []
	var on_unlock := func(ach_id: String) -> void: emitted_ids.append(ach_id)
	AchievementService.achievement_unlocked.connect(on_unlock)

	# 4. Perbaikan bug hulu: mode 'ucn' (SSS) tetap memicu achievement ambang statistik (pop_max, dll.), sementara 'easy' tidak
	AchievementService.unlocked_ids.clear()
	AchievementService.difficulty_wins.clear()

	CampaignManager.start_new_campaign("easy", false)
	CampaignManager.stats["pop"] = 95
	CampaignManager.stats["cendana"] = 0
	CampaignManager.stats["stab"] = 95
	CampaignManager.factions["pdip"]["affinity"] = 100.0
	AchievementService.evaluate_mid_campaign()
	assert_false(AchievementService.is_unlocked("pop_max"), "easy does not unlock pop_max")
	assert_false(AchievementService.is_unlocked("cendana_zero"), "easy does not unlock cendana_zero")

	CampaignManager.start_new_campaign("ucn", false)
	CampaignManager.stats["pop"] = 92
	AchievementService.evaluate_mid_campaign()
	assert_true(AchievementService.is_unlocked("pop_max"), "ucn unlocks pop_max")
	assert_eq(emitted_ids.count("pop_max"), 1, "achievement_unlocked signal emitted once for pop_max")
	AchievementService.evaluate_mid_campaign()
	assert_eq(emitted_ids.count("pop_max"), 1, "achievement_unlocked not re-emitted when already unlocked")

	# Manual save/load never disqualifies achievements
	var mid_snap := CampaignManager.serialize_state()
	CampaignManager.restore_state(mid_snap)
	CampaignManager.stats["cendana"] = 0
	CampaignManager.stats["stab"] = 91
	CampaignManager.factions["pdip"]["affinity"] = 100.0
	AchievementService.evaluate_mid_campaign()
	assert_true(AchievementService.is_unlocked("cendana_zero"), "cendana_zero unlocked after manual restore on ucn")
	assert_true(AchievementService.is_unlocked("aman_terkendali"), "aman_terkendali unlocked after manual restore on ucn")
	assert_true(AchievementService.is_unlocked("pdip_max"), "pdip_max unlocked after manual restore on ucn")

	# Now trigger ALL remaining achievements through evaluate_mid_campaign() and evaluate_election_end() to prove 59/59 parity!
	# Mid-campaign austerity + story/decree/routine/faction achievements:
	CampaignManager.stats["intl"] = 100
	CampaignManager.stats["econ"] = 10
	CampaignManager.stats["pop"] = 20
	for dec_id in [
		"imf_fuel_subsidy", "imf_bulog_deregulation", "imf_ibra_liquidation",
		"ban_pdip_subversion", "dissolve_golkar_old_guard",
		"abolish_abri_mpr_seats", "abolish_kodam_territorial", "civilian_defense_ministry", "police_military_separation",
		"enforce_asas_tunggal_ban", "unify_golkar_slipi", "rainbow_coalition_accord",
		"anti_corruption", "civil_service_neutrality", "direct_presidential_amendment",
		"suharto_asset_seizure_tribunal", "political_prisoner_release", "human_rights_commission_powers", "broadcast_liberalization",
		"regional_autonomy", "aceh_special_status_law", "maluku_irja_division",
		"chinese_cultural_ban_repeal",
		"ratify_kamra_militia_bill", "reinstate_siupp_censorship", "purge_utusan_golongan",
	]:
		CampaignManager.active_decrees[dec_id] = true
	for rout_id in [
		"trisakti_semanggi_commemoration", "chinatown_reconciliation", "womens_commission",
		"sbkri_review", "declassify_1965_files",
		"seize_cendana_tolls", "audit_kodam_foundations",
		"mobilize_pam_swakarsa",
	]:
		CampaignManager.action_usage_count[rout_id] = 1
	CampaignManager.sp3_upheld_with_high_cendana = true
	CampaignManager.bank_bali_clean_steps = {"frozeEGP": true, "pwcAccess": true, "declassifiedPwC": true}
	CampaignManager.completed_interactions["pdip_pansus_bankbali"] = true
	CampaignManager.completed_interactions["tni_final_appeal"] = true
	CampaignManager.completed_interactions["golkar_final_appeal"] = true
	var fav_count := 0
	for fk in CampaignManager.factions.keys():
		if fav_count < 6:
			CampaignManager.factions[fk]["favor"] = 1
			fav_count += 1
	AchievementService.evaluate_mid_campaign()

	# Election Win #1: Historical overwhelming win (460 FOR) + bruning_impressed + mr_crack + cleared_for_takeoff + dwifungsi_kaput + thankless_burden + fumes_in_the_tank + bottom stats + habibi_ya_habibi + the_center_holds + kaos_merah + odd_bedfellows
	CampaignManager.start_new_campaign("historical", false)
	CampaignManager.pc = 0
	CampaignManager.lowest_gov_stability = 25
	CampaignManager.stats = {"pop": 10, "mil": 65, "ref": 90, "econ": 10, "intl": 100, "stab": 60, "cendana": 20}
	CampaignManager.active_decrees = {
		"imf_fuel_subsidy": true,
		"imf_bulog_deregulation": true,
		"imf_ibra_liquidation": true,
		"police_military_separation": true,
		"human_rights_commission_powers": true,
	}
	CampaignManager.completed_interactions = {"loyalist_bppt": true, "loyalist_n250": true}
	CampaignManager.timor_promise_steps = {"countdown": true, "votes": true, "peacekeepers": true}
	CampaignManager.factions["pdip"]["affinity"] = 75.0
	CampaignManager.factions["poros_tengah"]["affinity"] = 90.0
	CampaignManager.factions["golkar_akbar"]["affinity"] = 70.0
	CampaignManager.factions["abri"]["affinity"] = 65.0
	CampaignManager.factions["utusan_golongan"]["affinity"] = 85.0
	CampaignManager.factions["other_parties"]["affinity"] = 85.0
	OppositionManager.restore_state({
		"coalition_ticks": 3,
		"tni": {"phase": "anger", "value": 40.0, "touched": false},
		"pdip": {"value": 100.0, "touched": false},
	})
	var center_factions: Array[Dictionary] = [
		{"id": "golkar_habibie", "seats": 50, "votes_for": 45, "votes_against": 5, "blank_votes": 0},
		{"id": "golkar_akbar", "seats": 70, "votes_for": 55, "votes_against": 15, "blank_votes": 0},
		{"id": "utusan_daerah", "seats": 135, "votes_for": 100, "votes_against": 35, "blank_votes": 0},
		{"id": "utusan_golongan", "seats": 65, "votes_for": 55, "votes_against": 10, "blank_votes": 0},
		{"id": "other_parties", "seats": 46, "votes_for": 35, "votes_against": 11, "blank_votes": 0},
		{"id": "abri", "seats": 38, "votes_for": 30, "votes_against": 8, "blank_votes": 0},
		{"id": "poros_tengah", "seats": 143, "votes_for": 140, "votes_against": 3, "blank_votes": 0},
		{"id": "pdip", "seats": 153, "votes_for": 0, "votes_against": 153, "blank_votes": 0},
	]
	assert_false(SSSController.is_unlocked(), "SSSController locked before win_historical")
	AchievementService.evaluate_election_end({
		"accepted": true,
		"quorum_failed": false,
		"total_for": 460,
		"total_against": 240,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": center_factions,
	})
	assert_true(SSSController.is_unlocked(), "SSSController unlocked once real AchievementService unlocks win_historical")

	# Election Win #2: Easy comfortable win (390 FOR) + sedia_payung + presiden_rebahan + ngopi_dulu + persona_non_grata + enak_jamanku + camdessus_arms? (presiden_rebahan needs 0 decrees first!)
	CampaignManager.start_new_campaign("easy", false)
	CampaignManager.pc = 100
	CampaignManager.stats = {"pop": 50, "mil": 75, "ref": 20, "econ": 65, "intl": 10, "stab": 60, "cendana": 90}
	AchievementService.evaluate_election_end({
		"accepted": true,
		"quorum_failed": false,
		"total_for": 390,
		"total_against": 310,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	# Election Win #3: Medium narrow win (355 FOR) + camdessus_arms + orba_jilid_dua
	CampaignManager.start_new_campaign("medium", false)
	CampaignManager.bank_bali_clean_steps = {"defiedIMF": true}
	CampaignManager.active_decrees = {
		"currency_board": true,
		"invoke_supersemar_ii": true,
		"cendana_restoration_pact": true,
	}
	CampaignManager.stats["econ"] = 65
	AchievementService.evaluate_election_end({
		"accepted": true,
		"quorum_failed": false,
		"total_for": 355,
		"total_against": 345,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	# Election Win #4: High win -> completes Easy + Medium + High + Historical -> unlocks khatam!
	assert_false(AchievementService.is_unlocked("khatam"), "khatam not unlocked before 4th standard difficulty win")
	CampaignManager.start_new_campaign("high", false)
	AchievementService.evaluate_election_end({
		"accepted": true,
		"quorum_failed": false,
		"total_for": 360,
		"total_against": 340,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})
	assert_true(AchievementService.is_unlocked("khatam"), "khatam unlocked once all 4 standard difficulties won")

	# Election Win #5: UCN 24/20 maxed win -> unlocks ucn_6am!
	SSSController.apply_preset(20)
	CampaignManager.start_new_campaign("ucn", false)
	AchievementService.evaluate_election_end({
		"accepted": true,
		"quorum_failed": false,
		"total_for": 351,
		"total_against": 349,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})
	assert_true(AchievementService.is_unlocked("ucn_6am"), "ucn_6am unlocked on maxed 24/20 SSS win")
	SSSController.apply_preset(10)

	# Defeat #1: Narrow loss with 322 FOR -> deja_vu_322, lose_narrow, dipecat_dengan_hormat, et_tu_akbar, gus_dur_twist
	CampaignManager.start_new_campaign("historical", false)
	CampaignManager.stats = {"pop": 80, "mil": 80, "ref": 80, "econ": 80, "intl": 80, "stab": 80, "cendana": 20}
	CampaignManager.factions["golkar_habibie"]["affinity"] = 90.0
	CampaignManager.factions["golkar_akbar"]["affinity"] = 25.0
	CampaignManager.factions["poros_tengah"]["affinity"] = 70.0
	CampaignManager.helped_rais_speaker = true
	AchievementService.evaluate_election_end({
		"accepted": false,
		"quorum_failed": false,
		"total_for": 322,
		"total_against": 355,
		"total_blank": 23,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	# Defeat #2: Quorum / silent abstention loss (340 FOR, 15 BLANK -> 340+15 >= 351) -> those_who_stayed_silent
	AchievementService.evaluate_election_end({
		"accepted": false,
		"quorum_failed": true,
		"total_for": 340,
		"total_against": 345,
		"total_blank": 15,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	# Defeat #3: Decisive loss (250 FOR) -> lose_decisive
	AchievementService.evaluate_election_end({
		"accepted": false,
		"quorum_failed": false,
		"total_for": 250,
		"total_against": 450,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	# Defeat #4: Overwhelming loss (150 FOR) -> lose_overwhelming
	AchievementService.evaluate_election_end({
		"accepted": false,
		"quorum_failed": false,
		"total_for": 150,
		"total_against": 550,
		"total_blank": 0,
		"chamber_seats": 700,
		"original_chamber_seats": 700,
		"factions": [],
	})

	for ach in ContentDB.catalog.achievements:
		assert_true(AchievementService.is_unlocked(ach.id), "All 59 catalog achievements reachable: " + ach.id)
	assert_eq(AchievementService.unlocked_ids.size(), 59, "Exact 59/59 achievements unlocked")

	AchievementService.achievement_unlocked.disconnect(on_unlock)
	AchievementService.unlocked_ids.clear()
	AchievementService.difficulty_wins.clear()
