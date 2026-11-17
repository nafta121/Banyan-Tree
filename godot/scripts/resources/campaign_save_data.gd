class_name CampaignSaveData
extends Resource

@export var slot_id: String = "autosave"
@export var note: String = ""
@export var saved_at_unix: int = 0
@export var saved_at_iso: String = ""
@export var turn_number: int = 1
@export var date_str: String = ""
@export var is_action_phase: bool = false
@export var selected_difficulty: String = "historical"
@export var show_option_effects: bool = false
@export var pc: int = 20
@export var gov_stability_tier: String = "precarious"
@export var campaign_state: Dictionary = {}
@export var opposition_state: Dictionary = {}
@export var sss_state: Dictionary = {}
@export var achievement_flags: Dictionary = {}
