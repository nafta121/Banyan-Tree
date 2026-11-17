extends TestBase


func run() -> int:
	_test_sss_dag_and_difficulty_builder()
	_test_issue_4_forecast_toggle()
	_test_opening_hand_mil_sync_gravity_and_golkar_pillars()
	_test_poros_tengah_merger_turn_18()
	_test_chained_seat_reallocation_700_invariant()
	_test_events_routines_decrees_factions_and_horse_trading()
	_test_serialize_and_restore_roundtrip()
	_test_floor_ramping_turn_23_ucn_restore_and_task4_seams()
	return assertions_failed


func _sum_active_seats() -> int:
	var active_sum := 0
	for k in CampaignManager.factions.keys():
		if not CampaignManager.banned_factions.get(k, false):
			active_sum += int(CampaignManager.factions[k]["seats"])
	return active_sum


func _test_sss_dag_and_difficulty_builder() -> void:
	assert_true(SSSController != null, "SSSController autoload mounted")
	assert_eq(SSSController.RANKS, [0, 5, 10, 20], "SSSController RANKS constant")
	assert_eq(SSSController.levels.size(), 24, "24 SSS card levels initialized")
	assert_eq(SSSController.hide_forecast, true, "SSSController hide_forecast defaults to true")

	# Piecewise linear interpolation: 0 -> n, 10 -> h, 20 -> m
	assert_near(SSSController.lerp_card(0.0, 50.0, 20.0, 8.0), 50.0, 0.001, "lerp_card at 0")
	assert_near(SSSController.lerp_card(5.0, 50.0, 20.0, 8.0), 35.0, 0.001, "lerp_card at 5")
	assert_near(SSSController.lerp_card(10.0, 50.0, 20.0, 8.0), 20.0, 0.001, "lerp_card at 10")
	assert_near(SSSController.lerp_card(15.0, 50.0, 20.0, 8.0), 14.0, 0.001, "lerp_card at 15")
	assert_near(SSSController.lerp_card(20.0, 50.0, 20.0, 8.0), 8.0, 0.001, "lerp_card at 20")

	# Default all-10 build matches Historical difficulty parameters
	SSSController.apply_preset(10)
	var d10 := SSSController.build_difficulty_data()
	assert_eq(d10.id, "ucn", "built DifficultyData id == ucn")
	assert_eq(d10.pc, 20, "SSS rank 10 pc == 20")
	assert_eq(d10.cendana, 95, "SSS rank 10 cendana == 95")
	assert_near(d10.malus_cap, 3.25, 0.001, "SSS rank 10 malus_cap == 3.25")
	assert_eq(d10.cost_pct, 15, "SSS rank 10 cost_pct == 15")
	assert_eq(d10.decree_cost_pct, 8, "SSS rank 10 decree_cost_pct == 8")
	assert_eq(d10.action_cost_mod, 2, "SSS rank 10 action_cost_mod == 2")
	assert_eq(d10.cooldown_bonus, 1, "SSS rank 10 cooldown_bonus == 1")
	assert_near(d10.event_neg_mult, 1.1, 0.001, "SSS rank 10 event_neg_mult == 1.1")
	assert_near(d10.event_pos_mult, 0.95, 0.001, "SSS rank 10 event_pos_mult == 0.95")
	assert_near(d10.gain_mult, 0.95, 0.001, "SSS rank 10 gain_mult == 0.95")
	assert_eq(d10.max_favor, 2, "SSS rank 10 max_favor == 2")
	assert_near(d10.faction_drift, 0.4, 0.001, "SSS rank 10 faction_drift == 0.4")
	assert_near(d10.cendana_regen, 1.0, 0.001, "SSS rank 10 cendana_regen == 1.0")
	assert_eq(d10.stat_mod, -1, "SSS rank 10 stat_mod == -1")
	assert_near(float(d10.opposition.get("scale", 0.0)), 1.0, 0.001, "SSS rank 10 opposition scale == 1.0")
	assert_near(float(d10.opposition.get("defectionMult", 0.0)), 1.3, 0.001, "SSS rank 10 defectionMult == 1.3")

	# DAG prerequisite cascade: setting pc = 0 disables passive (prereq: [pc]),
	# while s_intl (prereq: [pc, s_econ]) stays active until s_econ is also 0.
	SSSController.set_card_rank("pc", 0)
	assert_eq(int(SSSController.levels["pc"]), 0, "pc set to 0")
	assert_eq(int(SSSController.levels["passive"]), 0, "passive cascaded to 0 when pc == 0")
	assert_false(SSSController.is_card_unlocked("passive"), "passive locked when pc == 0")
	assert_true(SSSController.is_card_unlocked("s_intl"), "s_intl still unlocked via s_econ")
	assert_eq(int(SSSController.levels["s_intl"]), 10, "s_intl remains 10 via s_econ")

	SSSController.set_card_rank("s_econ", 0)
	assert_eq(int(SSSController.levels["s_intl"]), 0, "s_intl cascaded to 0 when both pc and s_econ == 0")
	assert_eq(int(SSSController.levels["cost"]), 0, "cost cascaded to 0 when passive & s_intl == 0")
	assert_eq(int(SSSController.levels["s_pop"]), 0, "s_pop cascaded to 0 when passive & s_intl == 0")

	# Preset 20 (24/20 maxed) & Preset -1 (random valid DAG)
	SSSController.apply_preset(20)
	var d20 := SSSController.build_difficulty_data()
	assert_eq(d20.pc, 8, "SSS rank 20 pc == 8")
	assert_eq(d20.cost_pct, 27, "SSS rank 20 cost_pct == 27")
	assert_eq(int(d20.opposition.get("pdipStart", 0)), 50, "SSS rank 20 pdipStart == 50")
	assert_near(float(d20.opposition.get("milCeiling", 0.0)), 0.75, 0.001, "SSS rank 20 milCeiling == 0.75")

	SSSController.apply_preset(-1)
	var any_active := false
	for card in ContentDB.catalog.sss_cards:
		var lv := int(SSSController.levels.get(card.id, 0))
		if lv > 0:
			any_active = true
			assert_true(SSSController.is_card_unlocked(card.id), "random DAG card " + card.id + " satisfies prereqs")
	assert_true(any_active, "random preset activates at least one card")
	SSSController.apply_preset(10)


func _test_issue_4_forecast_toggle() -> void:
	# 1. Perbaikan Issue #4 pada SSS: uncheck hide_forecast mengaktifkan show_option_effects
	CampaignManager.start_new_campaign("historical", true)
	assert_eq(CampaignManager.show_option_effects, false, "historical always locks show_option_effects off")

	SSSController.hide_forecast = false
	CampaignManager.start_new_campaign("ucn", false)
	assert_eq(CampaignManager.show_option_effects, true, "ucn with hide_forecast=false enables show_option_effects")

	SSSController.hide_forecast = true
	CampaignManager.start_new_campaign("ucn", true)
	assert_eq(CampaignManager.show_option_effects, false, "ucn with hide_forecast=true disables show_option_effects")

	CampaignManager.start_new_campaign("medium", true)
	assert_eq(CampaignManager.show_option_effects, true, "standard difficulty respects forecast_enabled=true")
	CampaignManager.start_new_campaign("medium", false)
	assert_eq(CampaignManager.show_option_effects, false, "standard difficulty respects forecast_enabled=false")


func _test_opening_hand_mil_sync_gravity_and_golkar_pillars() -> void:
	# 2. Hardcoded mil=50 awal, Stat Gravity (>78 -> -2/turn), & Tiga Pilar Golkar (A = -15% Golkar, B = -20% PC, G = +1 Cendana)
	CampaignManager.start_new_campaign("medium", true)
	assert_eq(CampaignManager.stats["mil"], 50, "opening stats.mil hardcoded to 50 on medium")
	assert_eq(int(round(CampaignManager.factions["abri"]["affinity"])), 50, "opening abri.affinity hardcoded to 50 on medium")
	assert_eq(CampaignManager.stats["pop"], 35, "opening pop == 30 + stat_mod(5) on medium")

	# All three Golkar pillars stand initially
	assert_true(CampaignManager.golkar_pillar_stands("a"), "Golkar Pillar A stands initially")
	assert_true(CampaignManager.golkar_pillar_stands("b"), "Golkar Pillar B stands initially")
	assert_true(CampaignManager.golkar_pillar_stands("g"), "Golkar Pillar G stands initially")

	# Pillar G (+1 Cendana at end of turn) & Stat Gravity (>78 -> -2, <22 -> +1 on easy/medium)
	var cendana_before := int(CampaignManager.stats["cendana"]) # 60 on medium
	CampaignManager.stats["pop"] = 85
	CampaignManager.stats["intl"] = 18 # <= 20 also penalizes econ -2, and < 22 bounces +1 on medium -> 19
	CampaignManager.stats["econ"] = 50
	CampaignManager.stats["ref"] = 50
	CampaignManager.finish_action_phase()
	assert_eq(CampaignManager.stats["pop"], 83, "Stat gravity reduces pop > 78 by -2")
	assert_eq(CampaignManager.stats["intl"], 19, "Low-stat bounce adds +1 to intl < 22 on medium")
	assert_eq(CampaignManager.stats["cendana"], cendana_before + 1, "Pillar G adds +1 Cendana at end of turn")

	# Deduplication of mil and abri in a single effect payload (larger magnitude wins, never summed)
	CampaignManager.start_new_campaign("easy", true)
	assert_eq(CampaignManager.stats["mil"], 50, "easy starts at mil=50")
	CampaignManager.choose_event_option(0) # enter action phase cleanly or test apply_effects via routine/helper
	# Direct check of deduplicated mil+abri effect via CampaignManager.apply_effects
	CampaignManager.factions["abri"]["affinity"] = 50.0
	CampaignManager.stats["mil"] = 50
	CampaignManager.apply_effects({"mil": -6, "abri": -15})
	assert_eq(int(round(CampaignManager.factions["abri"]["affinity"])), 35, "mil/abri deduplicates to larger magnitude (-15, not -21)")
	assert_eq(CampaignManager.stats["mil"], 35, "stats.mil stays synced to abri.affinity")

	CampaignManager.apply_effects({"mil": 12, "abri": 4})
	assert_eq(int(round(CampaignManager.factions["abri"]["affinity"])), 47, "mil/abri deduplicates positive delta (+12, not +16)")
	assert_eq(CampaignManager.stats["mil"], 47, "stats.mil synced to 47")

	# Pillar B (-20% PC gain) and Pillar A (-15% Golkar gain) + breaking all 3 pillars unlocks req_golkar_pillars decrees
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.pc = 10
	CampaignManager.apply_effects({"PC": 50}) # 50 * 0.80 = 40 exact -> 10 + 40 = 50
	assert_eq(CampaignManager.pc, 50, "Pillar B cuts +50 PC gain by 20% to +40")

	CampaignManager.factions["golkar_akbar"]["affinity"] = 20.0
	CampaignManager.apply_effects({"golkar_akbar": 20}) # 20 * 0.85 = 17 exact -> 37
	assert_eq(int(round(CampaignManager.factions["golkar_akbar"]["affinity"])), 37, "Pillar A cuts +20 Golkar gain by 15% to +17")

	# dissolve_golkar_old_guard requires all 3 Golkar pillars broken
	CampaignManager.is_action_phase = true
	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	CampaignManager.stats["ref"] = 85
	CampaignManager.stats["pop"] = 85
	CampaignManager.stats["cendana"] = 20
	var pre_pillar_check := CampaignManager.can_enact_decree("dissolve_golkar_old_guard")
	assert_false(bool(pre_pillar_check.get("ok", true)), "dissolve_golkar_old_guard blocked while Golkar pillars stand")

	# Break Pillar A, B, and G
	CampaignManager.stats["mil"] = 80
	CampaignManager.factions["abri"]["affinity"] = 80.0
	assert_true(bool(CampaignManager.enact_decree("abolish_kodam_territorial").get("ok", false)), "enact abolish_kodam_territorial (breaks A)")
	assert_false(CampaignManager.golkar_pillar_stands("a"), "Pillar A broken")

	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	assert_true(bool(CampaignManager.enact_decree("civil_service_neutrality").get("ok", false)), "enact civil_service_neutrality (breaks B)")
	assert_false(CampaignManager.golkar_pillar_stands("b"), "Pillar B broken")

	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	assert_true(bool(CampaignManager.enact_decree("anti_corruption").get("ok", false)), "enact anti_corruption (breaks G)")
	assert_false(CampaignManager.golkar_pillar_stands("g"), "Pillar G broken")

	# With Pillar B broken, +20 PC grants full +20
	CampaignManager.pc = 20
	CampaignManager.apply_effects({"PC": 20})
	assert_eq(CampaignManager.pc, 40, "Full +20 PC granted once Pillar B is broken")


func _test_poros_tengah_merger_turn_18() -> void:
	# 3. Peleburan Poros Tengah pada awal Turn 18 = tepat 163 kursi & total 700 kursi terjaga
	CampaignManager.start_new_campaign("medium", true)
	assert_eq(CampaignManager.active_faction_order.size(), 10, "10 active portrait factions before Turn 18")
	CampaignManager.factions["ppp"]["favor"] = 2
	CampaignManager.factions["pkb"]["favor"] = 2
	CampaignManager.factions["poros_tengah"]["favor"] = 0

	CampaignManager.current_turn = 17
	CampaignManager.finish_action_phase() # maju ke Turn 18 -> memicu merger
	assert_eq(CampaignManager.current_turn, 18, "advanced to Turn 18")
	assert_true(bool(CampaignManager.factions["poros_tengah"]["has_merged"]), "poros_tengah has_merged == true")
	assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 163, "poros_tengah merged seats == 163")
	assert_eq(CampaignManager.factions["ppp"]["seats"], 0, "ppp seats == 0 after merger")
	assert_eq(CampaignManager.factions["pkb"]["seats"], 0, "pkb seats == 0 after merger")
	assert_eq(CampaignManager.factions["other_parties"]["seats"], 26, "other_parties seats == 26 after transferring 20")
	assert_eq(CampaignManager.factions["poros_tengah"]["favor"], 2, "inherited min(2, floor((2+2)*0.5)) == 2 favors")
	assert_eq(CampaignManager.active_faction_order.size(), 8, "ppp and pkb removed from active_faction_order (8 left)")
	assert_false(CampaignManager.active_faction_order.has("ppp"), "ppp not in active_faction_order")
	assert_false(CampaignManager.active_faction_order.has("pkb"), "pkb not in active_faction_order")
	assert_eq(_sum_active_seats() + CampaignManager.total_seats_vacated, 700, "700 total seats preserved after Poros Tengah merger")


func _test_chained_seat_reallocation_700_invariant() -> void:
	# 4. Review Focus #2: purge_utusan_golongan diikuti ban_pdip_subversion tidak membuang kursi ke fraksi terlarang
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.is_action_phase = true
	CampaignManager.stats["ref"] = 20
	CampaignManager.stats["mil"] = 85
	CampaignManager.factions["abri"]["affinity"] = 85.0
	CampaignManager.pc = 100

	var r1 := CampaignManager.enact_decree("purge_utusan_golongan")
	assert_true(bool(r1.get("ok", false)), "purge_utusan_golongan enacted")
	assert_eq(CampaignManager.factions["utusan_golongan"]["seats"], 0, "utusan_golongan seats == 0")
	assert_eq(_sum_active_seats() + CampaignManager.total_seats_vacated, 700, "700 invariant after purge_utusan_golongan")

	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	var r2 := CampaignManager.enact_decree("invoke_supersemar_ii")
	assert_true(bool(r2.get("ok", false)), "invoke_supersemar_ii enacted")

	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	var r3 := CampaignManager.enact_decree("ban_pdip_subversion")
	assert_true(bool(r3.get("ok", false)), "ban_pdip_subversion enacted")
	assert_eq(CampaignManager.factions["utusan_golongan"]["seats"], 0, "banned utusan_golongan receives 0 seats from PDI-P ban")
	assert_eq(CampaignManager.factions["pdip"]["seats"], 0, "pdip seats == 0 after ban")
	assert_eq(_sum_active_seats() + CampaignManager.total_seats_vacated, 700, "700 invariant preserved across chained bans")

	# Also test seats_vacated (dissolve_golkar_old_guard vacates 30 of 70 seats)
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.is_action_phase = true
	CampaignManager.stats["mil"] = 85
	CampaignManager.factions["abri"]["affinity"] = 85.0
	CampaignManager.stats["ref"] = 85
	CampaignManager.stats["pop"] = 85
	for dec_id in ["abolish_kodam_territorial", "civil_service_neutrality", "anti_corruption"]:
		CampaignManager.turn_executive_used = false
		CampaignManager.pc = 100
		assert_true(bool(CampaignManager.enact_decree(dec_id).get("ok", false)), "break pillar via " + dec_id)
	CampaignManager.turn_executive_used = false
	CampaignManager.pc = 100
	CampaignManager.stats["ref"] = 85
	CampaignManager.stats["pop"] = 85
	CampaignManager.stats["cendana"] = 20
	var r_golkar := CampaignManager.enact_decree("dissolve_golkar_old_guard")
	assert_true(bool(r_golkar.get("ok", false)), "dissolve_golkar_old_guard enacted")
	assert_eq(CampaignManager.total_seats_vacated, 30, "total_seats_vacated == 30")
	assert_eq(_sum_active_seats(), 670, "active seats == 670")
	assert_eq(_sum_active_seats() + CampaignManager.total_seats_vacated, 700, "670 active + 30 vacated == 700")


func _test_events_routines_decrees_factions_and_horse_trading() -> void:
	var alerts: Array[Dictionary] = []
	var on_alert := func(payload: Dictionary) -> void: alerts.append(payload)
	CampaignManager.press_alert_queued.connect(on_alert)

	CampaignManager.start_new_campaign("medium", true)
	assert_eq(CampaignManager.current_turn, 1, "starts on Turn 1")
	assert_eq(CampaignManager.is_action_phase, false, "starts in event phase")

	# Resolve Turn 1 crisis event -> emits press dispatch with net_deltas and enters action phase
	var ev_res := CampaignManager.choose_event_option(0)
	assert_true(bool(ev_res.get("ok", false)), "choose_event_option(0) succeeded")
	assert_true(CampaignManager.is_action_phase, "entered action phase after Turn 1 event")
	assert_true(CampaignManager.event_resolved_this_turn, "event_resolved_this_turn == true")
	assert_eq(alerts.size(), 1, "1 press alert emitted")
	assert_eq(String(alerts[0].get("kind", "")), "press", "event alert kind == press")
	assert_true(not String(alerts[0].get("outlet", "")).is_empty(), "press alert has outlet")
	assert_true(alerts[0].get("net_deltas") is Dictionary, "press alert carries net_deltas dictionary")

	# Execute a routine action -> emits telex alert, sets cooldown and turn_executive_used
	var can_rout := CampaignManager.can_execute_routine("wednesday_cabinet")
	assert_true(bool(can_rout.get("ok", false)), "can_execute_routine(wednesday_cabinet) ok")
	var rout_res := CampaignManager.execute_routine("wednesday_cabinet")
	assert_true(bool(rout_res.get("ok", false)), "execute_routine(wednesday_cabinet) ok")
	assert_true(CampaignManager.turn_executive_used, "turn_executive_used == true after routine")
	assert_eq(String(alerts[alerts.size() - 1].get("kind", "")), "telex", "routine alert kind == telex")
	assert_false(bool(CampaignManager.can_execute_routine("wednesday_cabinet").get("ok", true)), "cannot execute 2nd executive action in same turn")

	# Pre-speech faction engagements: unlimited per turn with +5 PC surcharge per prior engagement
	CampaignManager.pc = 100
	var c1 := int(CampaignManager.can_engage_faction("golkar_habibie", "loyalist_bppt").get("cost", -1))
	assert_true(c1 >= 3, "valid cost for loyalist_bppt")
	var f_res1 := CampaignManager.engage_faction("golkar_habibie", "loyalist_bppt")
	assert_true(bool(f_res1.get("ok", false)), "engaged loyalist_bppt")
	var check2 := CampaignManager.can_engage_faction("golkar_habibie", "loyalist_icmi")
	var c2 := int(check2.get("cost", -1))
	var c2_surcharge := int(check2.get("surcharge", 0))
	assert_eq(c2_surcharge, 5, "+5 PC surcharge on 2nd faction engagement before Speech")
	assert_true(c2 >= 8, "2nd engagement includes +5 surcharge")

	# Post-speech (Turn 21): Final Appeal redeems banked favors & limits faction engagements to 1 per turn
	CampaignManager.current_turn = 20
	CampaignManager.finish_action_phase() # -> Turn 21 (Accountability Speech)
	assert_eq(CampaignManager.current_turn, 21, "Turn 21 (Accountability Speech)")
	CampaignManager.choose_event_option(0)
	CampaignManager.pc = 100
	CampaignManager.factions["abri"]["favor"] = 2
	var abri_before := float(CampaignManager.factions["abri"]["affinity"])
	assert_false(bool(CampaignManager.can_engage_faction("abri", "tni_defense_budget").get("ok", true)), "non-final faction deal locked after Speech")
	var can_fa := CampaignManager.can_final_appeal("abri")
	assert_true(bool(can_fa.get("ok", false)), "can_final_appeal(abri) ok on Turn 21")
	var fa_res := CampaignManager.execute_final_appeal("abri")
	assert_true(bool(fa_res.get("ok", false)), "execute_final_appeal(abri) ok")
	assert_eq(int(CampaignManager.factions["abri"]["favor"]), 0, "banked favors redeemed and reset to 0")
	assert_true(float(CampaignManager.factions["abri"]["affinity"]) > abri_before + 15.0, "Final Appeal + 2 redeemed favors boosted ABRI affinity significantly")
	assert_false(bool(CampaignManager.can_final_appeal("pdip").get("ok", true)), "only 1 faction engagement allowed per turn from Turn 21 onward")

	# Horse-trading only unlocked on Turn 22 (ev_eve_of_vote)
	assert_false(bool(CampaignManager.execute_horse_trade("other_parties", 1).get("ok", true)), "horse trading blocked on Turn 21")
	CampaignManager.finish_action_phase() # -> Turn 22 (Night of the Long Knives)
	assert_eq(CampaignManager.current_turn, 22, "Turn 22 (Night of the Long Knives)")
	CampaignManager.choose_event_option(0)
	CampaignManager.pc = 20
	var oth_before := float(CampaignManager.factions["other_parties"]["affinity"])
	var ht1 := CampaignManager.execute_horse_trade("other_parties", 1)
	assert_true(bool(ht1.get("ok", false)), "single overture horse trade succeeded on Turn 22")
	assert_eq(CampaignManager.pc, 19, "1 overture costs 1 PC")
	var ht5 := CampaignManager.execute_horse_trade("other_parties", 5)
	assert_true(bool(ht5.get("ok", false)), "bloc 5-overture horse trade succeeded on Turn 22")
	assert_eq(CampaignManager.pc, 16, "5 overtures cost 3 PC")
	assert_true(float(CampaignManager.factions["other_parties"]["affinity"]) > oth_before, "horse trading increased faction affinity")

	# Gov stability tiers check
	CampaignManager.stats = {"pop": 90, "mil": 90, "ref": 90, "econ": 90, "intl": 90, "stab": 90, "cendana": 10}
	assert_eq(CampaignManager.get_gov_stability(), 90, "gov stability == 90")
	assert_eq(CampaignManager.get_gov_stability_tier_id(), "secure", "gov stability tier == secure")

	CampaignManager.press_alert_queued.disconnect(on_alert)


func _test_serialize_and_restore_roundtrip() -> void:
	CampaignManager.start_new_campaign("high", false)
	CampaignManager.choose_event_option(0)
	CampaignManager.pc = 90
	CampaignManager.stats["econ"] = 64
	var dec_res := CampaignManager.enact_decree("central_bank_independence")
	assert_true(bool(dec_res.get("ok", false)), "central_bank_independence enacted on high with 90 PC")
	assert_true(bool(CampaignManager.can_enact_decree("currency_board").get("is_mutex_locked", false)), "currency_board mutex-locked by central_bank_independence")
	assert_eq(CampaignManager.gazette_history.size(), 1, "gazette_history recorded enacted decree")
	var snap := CampaignManager.serialize_state()

	# Mutate campaign heavily (jump to Turn 18 merger, change stats/floors)
	CampaignManager.current_turn = 17
	CampaignManager.finish_action_phase()
	assert_eq(CampaignManager.active_faction_order.size(), 8, "mutated to 8 factions after Turn 18")

	# Restore Turn 1 snapshot -> must cleanly un-merge back to 10 factions and exact stats/decrees
	CampaignManager.restore_state(snap)
	assert_eq(CampaignManager.selected_difficulty, "high", "restored difficulty == high")
	assert_eq(CampaignManager.current_turn, 1, "restored current_turn == 1")
	assert_eq(CampaignManager.is_action_phase, true, "restored is_action_phase == true")
	assert_eq(CampaignManager.pc, int(snap["pc"]), "restored exact PC")
	assert_true(bool(CampaignManager.active_decrees.get("central_bank_independence", false)), "restored active decree")
	assert_eq(CampaignManager.active_faction_order.size(), 10, "restored 10 portrait factions")
	assert_eq(int(CampaignManager.factions["poros_tengah"]["seats"]), 34, "restored pre-merge poros_tengah seats == 34")
	assert_false(bool(CampaignManager.factions["poros_tengah"]["has_merged"]), "restored poros_tengah has_merged == false")


func _test_floor_ramping_turn_23_ucn_restore_and_task4_seams() -> void:
	# 1. Soft floor grant (+5 stat, +8 faction) and per-turn ramp (+4 stat, +5 faction)
	CampaignManager.start_new_campaign("easy", true)
	CampaignManager.stats["ref"] = 30
	CampaignManager.factions["other_parties"]["affinity"] = 30.0
	CampaignManager.pc = 100
	assert_true(bool(CampaignManager.enact_decree("civil_service_neutrality").get("ok", false)), "civil_service_neutrality enacted")
	assert_eq(int(CampaignManager.min_stats["ref"]), 35, "soft stat floor starts at ref(30) + 5 == 35 (target 55)")
	var oth_floor_start := float(CampaignManager.min_factions["other_parties"])
	assert_near(oth_floor_start, 38.0, 0.01, "soft faction floor starts at other_parties(30) + 8 == 38 (target 55)")
	CampaignManager.finish_action_phase()
	assert_eq(int(CampaignManager.min_stats["ref"]), 39, "stat floor ramped by +4 at end of turn (35 -> 39)")
	assert_near(float(CampaignManager.min_factions["other_parties"]), 43.0, 0.01, "faction floor ramped by +5 at end of turn (38 -> 43)")

	# 2. Turn 23 (ev_timtim_merdeka) final crisis event transitions directly to election_ready (Turn 24, is_action_phase=false)
	CampaignManager.current_turn = 22
	CampaignManager.finish_action_phase()
	assert_eq(CampaignManager.current_turn, 23, "Turn 23 reached")
	assert_false(CampaignManager.is_election_ready(), "not election_ready before Turn 23 event resolved")
	var t23 := CampaignManager.choose_event_option(0)
	assert_true(bool(t23.get("ok", false)), "Turn 23 option chosen")
	assert_true(bool(t23.get("election_ready", false)), "Turn 23 resolution marks election_ready")
	assert_true(CampaignManager.is_election_ready(), "CampaignManager.is_election_ready() == true")
	assert_false(CampaignManager.is_action_phase, "no action phase after Turn 23")
	assert_eq(CampaignManager.current_turn, 24, "current_turn == 24 ready for MPR roll call")

	# 3. UCN frozen run levels save & restore round-trip
	SSSController.apply_preset(10)
	SSSController.set_card_rank("pc", 5) # lerp(5, 50, 20, 8) = 35 PC
	SSSController.set_card_rank("s_mil", 20) # lerp(20, 5, -1, -7) = -7 -> abri = 43
	SSSController.hide_forecast = false
	CampaignManager.start_new_campaign("ucn", false)
	assert_eq(CampaignManager.pc, 35, "UCN rank 5 pc == 35")
	assert_eq(CampaignManager.stats["mil"], 43, "UCN s_mil=20 sets mil == 43 (50 - 7)")
	assert_true(CampaignManager.show_option_effects, "UCN hide_forecast=false preserved")
	var ucn_snap := CampaignManager.serialize_state()

	SSSController.apply_preset(20)
	SSSController.hide_forecast = true
	CampaignManager.start_new_campaign("easy", false)
	CampaignManager.restore_state(ucn_snap)
	assert_eq(CampaignManager.selected_difficulty, "ucn", "restored ucn difficulty")
	assert_eq(CampaignManager.pc, 35, "restored UCN pc == 35")
	assert_eq(int(SSSController.active_run_levels.get("pc", -1)), 5, "restored frozen SSS pc rank == 5")
	assert_eq(int(SSSController.active_run_levels.get("s_mil", -1)), 20, "restored frozen SSS s_mil rank == 20")
	assert_true(CampaignManager.show_option_effects, "restored UCN show_option_effects == true")

	# 4. SSSController.format_card_effect across all 24 cards in both locales
	for lang in ["id", "en"]:
		LocaleService.set_locale(lang)
		for card in ContentDB.catalog.sss_cards:
			var fx_txt := SSSController.format_card_effect(card.id, 10)
			assert_true(not fx_txt.is_empty(), "non-empty format_card_effect for " + card.id + " (" + lang + ")")
			assert_false(fx_txt.contains("$"), "no unresolved $ placeholder in " + card.id + " (" + lang + ")")
			assert_eq(fx_txt.count("[color="), fx_txt.count("[/color]"), "balanced color in SSS card " + card.id)
	LocaleService.set_locale("id")

	# 5. Seamless Task 4 seams: SSSController.is_unlocked() & combined 0.40 gain_factor floor
	assert_false(SSSController.is_unlocked(), "SSS locked when AchievementService absent")
	if tree != null and tree.root != null:
		var mock_ach := _MockAchievementService.new()
		mock_ach.name = "AchievementService"
		tree.root.add_child(mock_ach)
		assert_false(SSSController.is_unlocked(), "SSS locked before win_historical")
		mock_ach.unlocked_ids["win_historical"] = true
		assert_true(SSSController.is_unlocked(), "SSS unlocked when win_historical unlocked")

		var mock_opp := _MockOppositionManager.new()
		mock_opp.name = "OppositionManager"
		tree.root.add_child(mock_opp)
		CampaignManager.start_new_campaign("historical", false)
		# (1 - 0.50) * (1 - 0.40) * (1 - 0.20) = 0.24 -> clamped to 0.40 floor
		assert_near(CampaignManager.gain_factor("PC"), 0.40, 0.001, "combined gain_factor floor clamped at 0.40")

		tree.root.remove_child(mock_opp)
		mock_opp.free()
		tree.root.remove_child(mock_ach)
		mock_ach.free()

	SSSController.apply_preset(10)
	SSSController.hide_forecast = true


class _MockAchievementService:
	extends Node
	var unlocked_ids: Dictionary = {}

	func is_unlocked(id: String) -> bool:
		return bool(unlocked_ids.get(id, false))


class _MockOppositionManager:
	extends Node

	func get_military_resistance() -> float:
		return 0.50

	func get_pdip_cut() -> float:
		return 0.40

	func get_pdip_tier() -> int:
		return 4

	func get_pdip_gain_mult() -> float:
		return 0.60

