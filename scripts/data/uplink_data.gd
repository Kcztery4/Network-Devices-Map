extends Resource
class_name UplinkData

enum CableType { COPPER, FIBER_1G, FIBER_10G }

@export var id: String = ""
@export var from_id: String = ""
@export var to_id: String = ""
@export var cable_type: CableType = CableType.COPPER
@export var bidirectional: bool = true
