class_name DecreeData
extends Resource

@export var id: String = ""
@export var category: String = ""
@export var text_key: String = ""
@export var desc_key: String = ""
@export var alert_msg_key: String = ""
@export var base_cost: int = 0
@export var mutex_decrees: PackedStringArray = PackedStringArray()
@export var req_decree: String = ""
@export var unlock_event: String = ""
@export var req_golkar_pillars: bool = false
@export var breaks_golkar_pillar: String = ""
@export var req_stats: Array[Dictionary] = []
@export var req_factions: Array[Dictionary] = []
@export var military_shock: int = 0
@export var locks: Dictionary = {}
@export var min_stats: Dictionary = {}
@export var max_cendana: int = -1
@export var min_factions: Dictionary = {}
@export var stat_effects: Dictionary = {}
@export var faction_effects: Dictionary = {}
@export var ban_factions: PackedStringArray = PackedStringArray()
@export var seat_recipients: Dictionary = {}
@export var seats_vacated: int = 0
