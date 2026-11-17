extends Node

const CATALOG_PATH := "res://godot/resources/catalog.tres"

var catalog: GameCatalogData = null

var _events_by_turn: Dictionary = {}
var _events_by_id: Dictionary = {}
var _decrees_by_id: Dictionary = {}
var _routines_by_id: Dictionary = {}
var _factions_by_id: Dictionary = {}
var _difficulties_by_id: Dictionary = {}
var _sss_by_id: Dictionary = {}
var _achievements_by_id: Dictionary = {}


func _init() -> void:
	reload_catalog()


func reload_catalog() -> void:
	_events_by_turn.clear()
	_events_by_id.clear()
	_decrees_by_id.clear()
	_routines_by_id.clear()
	_factions_by_id.clear()
	_difficulties_by_id.clear()
	_sss_by_id.clear()
	_achievements_by_id.clear()

	if not ResourceLoader.exists(CATALOG_PATH):
		catalog = null
		return

	catalog = ResourceLoader.load(CATALOG_PATH) as GameCatalogData
	if catalog == null:
		return

	for ev in catalog.events:
		_events_by_turn[ev.turn_number] = ev
		_events_by_id[ev.id] = ev
	for dec in catalog.decrees:
		_decrees_by_id[dec.id] = dec
	for rout in catalog.routines:
		_routines_by_id[rout.id] = rout
	for fac in catalog.factions:
		_factions_by_id[fac.id] = fac
	for diff in catalog.difficulties:
		_difficulties_by_id[diff.id] = diff
	for card in catalog.sss_cards:
		_sss_by_id[card.id] = card
	for ach in catalog.achievements:
		_achievements_by_id[ach.id] = ach


func get_event_by_turn(turn_one_based: int) -> CrisisEventData:
	return _events_by_turn.get(turn_one_based, null) as CrisisEventData


func get_event_by_id(id: String) -> CrisisEventData:
	return _events_by_id.get(id, null) as CrisisEventData


func get_decree(id: String) -> DecreeData:
	return _decrees_by_id.get(id, null) as DecreeData


func get_routine(id: String) -> RoutineActionData:
	return _routines_by_id.get(id, null) as RoutineActionData


func get_faction(id: String) -> FactionData:
	return _factions_by_id.get(id, null) as FactionData


func get_difficulty(id: String) -> DifficultyData:
	return _difficulties_by_id.get(id, null) as DifficultyData


func get_sss_card(id: String) -> SSSCardData:
	return _sss_by_id.get(id, null) as SSSCardData


func get_achievement(id: String) -> AchievementData:
	return _achievements_by_id.get(id, null) as AchievementData


func get_stat_tier(stat_key: String, value: float) -> StatTierData:
	if catalog == null:
		return null
	var tiers := catalog.get_stat_tiers(stat_key)
	for tier in tiers:
		if value >= float(tier.min_value):
			return tier
	return tiers[tiers.size() - 1] if not tiers.is_empty() else null
