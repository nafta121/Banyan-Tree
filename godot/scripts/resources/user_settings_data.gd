class_name UserSettingsData
extends Resource

@export var locale: String = "id"
@export var theme_id: String = "midnight_slate"
@export var text_scale: float = 1.0
@export var show_exact_numbers: bool = false
@export var show_option_effects_override: bool = false
@export var music_enabled: bool = true
@export var music_volume: float = 0.3
@export var sfx_enabled: bool = true
@export var sfx_volume: float = 0.8
@export var active_genre: String = "all"
@export var weighted_shuffle: bool = false
@export var auto_advance_turn: bool = false
@export var default_tally_speed: int = 1
@export var reduce_motion: bool = false
@export var sss_levels: Dictionary = {}
@export var sss_hide_forecast: bool = true
@export var unlocked_achievements: PackedStringArray = PackedStringArray()
@export var difficulty_wins: PackedStringArray = PackedStringArray()
