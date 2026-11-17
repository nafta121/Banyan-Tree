class_name DifficultyData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var image_path: String = ""
@export var pc: int = 20
@export var stat_mod: int = 0
@export var affinity_mod: int = 0
@export var start_mods: Dictionary = {}
@export var cendana: int = 95
@export var malus_cap: float = 3.25
@export var passive_pc_mod: int = 0
@export var action_cost_mod: int = 0
@export var cost_pct: int = 0
@export var decree_cost_pct: int = 0
@export var event_neg_mult: float = 1.0
@export var event_pos_mult: float = 1.0
@export var gain_mult: float = 1.0
@export var max_favor: int = 2
@export var faction_drift: float = 0.0
@export var cendana_regen: float = 0.0
@export var cooldown_bonus: int = 0
@export var opposition: Dictionary = {}
