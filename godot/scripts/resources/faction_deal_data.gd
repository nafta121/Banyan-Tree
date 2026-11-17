class_name FactionDealData
extends Resource

@export var id: String = ""
@export var text_key: String = ""
@export var desc_key: String = ""
@export var alert_msg_key: String = ""
@export var cost: int = 0
@export var repeatable: bool = false
@export var is_final_appeal: bool = false
@export var min_turn: int = 0
@export var max_turn: int = 22
@export var min_affinity: int = -1
@export var min_stat_key: String = ""
@export var min_stat_val: int = -1
@export var req_decree: String = ""
@export var mutex_group: String = ""
@export var locks_group: bool = false
@export var effects: Dictionary = {}
