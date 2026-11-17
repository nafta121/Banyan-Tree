extends Node

const DISCIPLINED_BLOCS := {
	"pdip": true,
	"poros_tengah": true,
	"abri": true,
}

var last_election_summary: Dictionary = {}


static func _js_round(x: float) -> int:
	return int(floor(x + 0.5))


static func _rand_int_below(r: RandomNumberGenerator, upper_exclusive: int) -> int:
	if upper_exclusive <= 1:
		return 0
	return mini(upper_exclusive - 1, int(floor(r.randf() * float(upper_exclusive))))


func compute_election_roll_call(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()

	var drama := {
		"moodSwing": 12,
		"wildcardChance": 1.0,
		"wildcardMin": 25,
		"wildcardMax": 50,
		"crossoverRate": 0.55,
		"surgeBias": 15,
		"blocBias": 10,
	}
	if OppositionManager != null:
		drama = OppositionManager.get_election_drama()

	var gov_stability := CampaignManager.get_gov_stability() if CampaignManager != null else 50
	var cendana_v := int(CampaignManager.stats.get("cendana", 50)) if CampaignManager != null else 50
	var cendana_sabotage := _js_round(float(cendana_v - 50) / 10.0)
	var stability_floor_mod := _js_round(float(gov_stability - 50) / 10.0)
	var chamber_mood := _js_round((r.randf() + r.randf() - 1.0) * float(drama.get("moodSwing", 7)))

	var faction_rows: Array[Dictionary] = []
	var total_for := 0
	var total_against := 0
	var total_blank := 0

	var order := CampaignManager.active_faction_order if CampaignManager != null else PackedStringArray()
	for key in order:
		if CampaignManager == null or not CampaignManager.factions.has(key):
			continue
		if bool(CampaignManager.banned_factions.get(key, false)):
			continue
		var f: Dictionary = CampaignManager.factions[key]
		var seats := int(f.get("seats", 0))
		if seats <= 0:
			continue

		# Stage 1: Floor abstentions / blank ballots (capped at 0..2 if > 2)
		var blank_votes := int(floor(r.randf() * (float(seats) * 0.015 + 1.0)))
		if blank_votes > 2:
			blank_votes = _rand_int_below(r, 3)
		var active_seats := seats - blank_votes

		# Stage 2: Unspent favor bonus (+8 affinity per unspent favor)
		var unspent_favor := int(f.get("favor", 0))
		var favor_bonus := unspent_favor * 8

		# Stage 3: Wildcard caucus shock & favor negative-variance cushion
		var wildcard := 0
		var wc_chance := minf(1.0, float(drama.get("wildcardChance", 0.5)))
		if r.randf() < wc_chance:
			var wc_min := int(drama.get("wildcardMin", 20))
			var wc_max := int(drama.get("wildcardMax", 50))
			var span := maxi(1, wc_max - wc_min + 1)
			var sign_v := 1 if r.randf() < 0.5 else -1
			wildcard = (wc_min + _rand_int_below(r, span)) * sign_v

		var raw_variance := (_rand_int_below(r, 17) - 9) + stability_floor_mod - cendana_sabotage + chamber_mood + wildcard
		var cushioned_variance := (
			_js_round(float(raw_variance) / (1.0 + float(unspent_favor) * 0.5))
			if (raw_variance < 0 and unspent_favor > 0)
			else raw_variance
		)

		# Stage 4: Opposition affinity adjustment & final clamped affinity
		var adv_adj := OppositionManager.affinity_adjust(key) if OppositionManager != null else 0
		var final_aff := CampaignManager.clamp_faction(
			key,
			float(f.get("affinity", 50.0)) + float(favor_bonus + cushioned_variance + adv_adj)
		)

		# Stage 5: Base delegate vote conversion (stepped for disciplined blocs, linear for fluid blocs)
		var votes_for := 0
		if DISCIPLINED_BLOCS.has(key):
			if final_aff >= 80.0:
				votes_for = _js_round(float(active_seats) * 0.96)
			elif final_aff >= 65.0:
				votes_for = _js_round(float(active_seats) * 0.72)
			elif final_aff >= 50.0:
				votes_for = _js_round(float(active_seats) * 0.42)
			elif final_aff >= 35.0:
				votes_for = _js_round(float(active_seats) * 0.15)
			else:
				votes_for = 0
		else:
			votes_for = _js_round(float(active_seats) * (final_aff / 100.0))

		votes_for = clampi(votes_for, 0, active_seats)
		var votes_against := active_seats - votes_for

		# Stage 6: Floor crossovers toward the minority side (halved if unspent favors > 0)
		var crossovers := int(floor(r.randf() * (float(active_seats) * float(drama.get("crossoverRate", 0.35)) + 1.0)))
		if unspent_favor > 0:
			crossovers = int(floor(float(crossovers) / 2.0))
		if votes_for >= votes_against:
			crossovers = mini(crossovers, votes_for)
			votes_for -= crossovers
			votes_against += crossovers
		else:
			crossovers = mini(crossovers, votes_against)
			votes_for += crossovers
			votes_against -= crossovers

		# Stage 7: Secret-ballot betrayal defection, tainted seat walkouts, & PDI-P 100% street lock
		var vote_locked := false
		if OppositionManager != null:
			var adj := OppositionManager.election_seat_adjust(key, final_aff, votes_for, votes_against, blank_votes)
			votes_for = int(adj["votes_for"])
			votes_against = int(adj["votes_against"])
			blank_votes = int(adj["blank_votes"])
			vote_locked = bool(adj.get("locked", false)) or OppositionManager.is_vote_locked(key)

		var rebel := ""
		if not vote_locked:
			if wildcard > 0:
				rebel = "surge"
			elif wildcard < 0:
				rebel = "revolt"
			elif crossovers >= 4:
				rebel = "crossvote"

		total_for += votes_for
		total_against += votes_against
		total_blank += blank_votes

		faction_rows.append({
			"id": key,
			"key": key,
			"name_key": String(f.get("name_key", "")),
			"short_key": String(f.get("short_key", "")),
			"seats": seats,
			"votes_for": votes_for,
			"votes_against": votes_against,
			"blank_votes": blank_votes,
			"final_affinity": final_aff,
			"rebel": rebel,
			"locked": vote_locked,
		})

	var original_chamber_seats := OppositionManager.original_chamber_size() if OppositionManager != null else 700
	var chamber_seats := total_for + total_against + total_blank
	var quorum_ok := OppositionManager.meets_quorum(total_for) if OppositionManager != null else (total_for >= 351)
	var accepted := (total_for > total_against) and quorum_ok
	var quorum_failed := (total_for > total_against) and (not accepted)

	var summary := {
		"accepted": accepted,
		"quorum_failed": quorum_failed,
		"total_for": total_for,
		"total_against": total_against,
		"total_blank": total_blank,
		"chamber_seats": chamber_seats,
		"original_chamber_seats": original_chamber_seats,
		"factions": faction_rows,
	}
	last_election_summary = summary.duplicate(true)
	return summary


func generate_hemicycle_layout(total_seats: int) -> Array[Dictionary]:
	var seats: Array[Dictionary] = []
	if total_seats <= 0:
		return seats

	var num_rows := 13
	var num_sectors := 5
	var radii_x: Array[float] = []
	var weight_sum := 0.0

	for row_idx in range(num_rows):
		var rx := 21.0 + (float(row_idx) / float(num_rows - 1)) * 26.5
		radii_x.append(rx)
		weight_sum += rx

	var row_counts: Array[int] = []
	var remainders: Array[Dictionary] = []
	var allocated := 0

	for row_idx in range(num_rows):
		var exact := (radii_x[row_idx] / weight_sum) * float(total_seats)
		var flo := int(floor(exact))
		row_counts.append(flo)
		remainders.append({"r": row_idx, "rem": exact - float(flo)})
		allocated += flo

	remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["rem"]), float(b["rem"])):
			return float(a["rem"]) > float(b["rem"])
		return int(a["r"]) < int(b["r"])
	)
	for i in range(total_seats - allocated):
		var target_r := int(remainders[i]["r"])
		row_counts[target_r] += 1

	var rem_patterns := [
		[0, 0, 0, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 1, 0, 1, 0],
		[0, 1, 1, 1, 0],
		[1, 1, 0, 1, 1],
	]

	var aisle_gap := 0.042
	var total_aisle_angle := float(num_sectors - 1) * aisle_gap
	var start_margin := 0.045
	var usable_span := PI - (2.0 * start_margin) - total_aisle_angle
	var sector_span := usable_span / float(num_sectors)

	for row_idx in range(num_rows):
		var cnt := row_counts[row_idx]
		if cnt <= 0:
			continue
		var rx := radii_x[row_idx]
		var ry := rx * 1.90
		var base_per_sector := int(floor(float(cnt) / float(num_sectors)))
		var rem_pat: Array = rem_patterns[cnt % num_sectors]

		for s in range(num_sectors):
			var sec_count := base_per_sector + int(rem_pat[s])
			if sec_count <= 0:
				continue
			var sector_start_theta := (PI - start_margin) - float(s) * (sector_span + aisle_gap)
			for k in range(sec_count):
				var u := (float(k) + 0.5) / float(sec_count)
				var theta := sector_start_theta - (u * sector_span)
				var x_pct := 50.0 + rx * cos(theta)
				var y_pct := 92.0 - ry * sin(theta)
				seats.append({
					"x": x_pct,
					"y": y_pct,
					"theta": theta,
					"row": row_idx,
					"sector": s,
				})

	seats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sector"]) != int(b["sector"]):
			return int(a["sector"]) < int(b["sector"])
		if not is_equal_approx(float(a["theta"]), float(b["theta"])):
			return float(b["theta"]) < float(a["theta"])
		return int(a["row"]) < int(b["row"])
	)
	return seats
