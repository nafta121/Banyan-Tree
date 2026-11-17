class_name RoutineActionData
extends Resource

@export var id: String = ""
@export var category: String = ""
@export var text_key: String = ""
@export var short_name_key: String = ""
@export var desc_key: String = ""
@export var alert_msg_key: String = ""
@export var success_alert_key: String = ""
@export var failure_alert_key: String = ""
@export var base_cost: int = 0
@export var cooldown: int = 2
@export var effects: Dictionary = {}
@export var conditional_branches: Array[Dictionary] = []
@export var dynamic_pc: Dictionary = {}
@export var dynamic_scaling: Dictionary = {}
@export var is_military_interaction: bool = false
