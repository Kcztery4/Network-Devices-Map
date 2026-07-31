extends Resource
class_name DeviceData

enum Location { HALL, OFFICE, OUTDOOR }

@export var id: String = ""
@export var type: String = ""
@export var device_name: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var device_scale: float = 1.0
@export var parent_rack_id: String = ""
@export var slot_index: int = -1
@export var slot_count: int = 0
@export var locked: bool = false
@export var location: Location = Location.HALL
@export var on_upper_floor: bool = false
@export var on_lower_floor: bool = false
@export var has_directional_antenna: bool = false
@export var antenna_direction_deg: float = 0.0
