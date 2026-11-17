class_name FactionData
extends Resource

@export var id: String = ""
@export var name_key: String = ""
@export var portrait_name_key: String = ""
@export var short_key: String = ""
@export var summary_key: String = ""
@export var biography_key: String = ""
@export var initial_seats: int = 0
@export var initial_affinity: int = 50
@export var image_path: String = ""
@export var cover_image_path: String = ""
@export var leverage_metrics: PackedStringArray = PackedStringArray()
@export var moods: Array[StatTierData] = []
@export var deals: Array[FactionDealData] = []
@export var merged_state: FactionMergedData = null
