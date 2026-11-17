class_name GameCatalogData
extends Resource

@export var events: Array[CrisisEventData] = []
@export var routines: Array[RoutineActionData] = []
@export var decrees: Array[DecreeData] = []
@export var factions: Array[FactionData] = []
@export var difficulties: Array[DifficultyData] = []
@export var sss_cards: Array[SSSCardData] = []
@export var library_entries: Array[LibraryEntryData] = []
@export var achievements: Array[AchievementData] = []
@export var music_tracks: Array[MusicTrackData] = []
@export var all_stat_tiers: Array[StatTierData] = []
@export var system_modifiers: Dictionary = {}
@export var golkar_pillars: Array[Dictionary] = []
@export var golkar_pillar_effects: Dictionary = {}
@export var sfx_paths: Dictionary = {}
@export var image_paths: Dictionary = {}
@export var tutorial_count: int = 6
@export var changelog_entries: Array[Dictionary] = []


func get_stat_tiers(stat_key: String) -> Array[StatTierData]:
	var out: Array[StatTierData] = []
	for tier in all_stat_tiers:
		if tier.stat_key == stat_key:
			out.append(tier)
	return out
