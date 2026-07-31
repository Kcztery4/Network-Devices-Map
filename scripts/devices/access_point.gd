extends DeviceBase
class_name AccessPoint

const OFFICE_COLOR := Color(0.45, 0.78, 0.45, 1)
const OUTDOOR_COLOR := Color(0.85, 0.55, 0.25, 1)
const FLOOR_ARROW_COLOR := Color(0, 0, 0, 1)
const FLOOR_ARROW_SIZE := 14.0
const ANTENNA_CONE_COLOR := Color(1, 1, 1, 0.55)
const ANTENNA_CONE_LENGTH := 24.0
const ANTENNA_CONE_HALF_ANGLE_DEG := 30.0

func _draw() -> void:
	var saved_color: Color = icon_color
	if data:
		match data.location:
			DeviceData.Location.OFFICE:
				icon_color = OFFICE_COLOR
			DeviceData.Location.OUTDOOR:
				icon_color = OUTDOOR_COLOR
	super._draw()
	icon_color = saved_color

	if data and data.on_upper_floor:
		_draw_upper_floor_arrow()
	if data and data.on_lower_floor:
		_draw_lower_floor_arrow()
	if data and data.has_directional_antenna:
		_draw_antenna_cone()

func _draw_upper_floor_arrow() -> void:
	var radius: float = get_effective_size().x / 2.0
	var anchor: Vector2 = Vector2(-radius, -radius) * 0.70710678
	var tip: Vector2 = anchor + Vector2(0, -FLOOR_ARROW_SIZE)
	var p1: Vector2 = anchor + Vector2(-FLOOR_ARROW_SIZE * 0.5, 0)
	var p2: Vector2 = anchor + Vector2(FLOOR_ARROW_SIZE * 0.5, 0)
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), FLOOR_ARROW_COLOR)

func _draw_lower_floor_arrow() -> void:
	var radius: float = get_effective_size().x / 2.0
	var anchor: Vector2 = Vector2(-radius, radius) * 0.70710678
	var tip: Vector2 = anchor + Vector2(0, FLOOR_ARROW_SIZE)
	var p1: Vector2 = anchor + Vector2(-FLOOR_ARROW_SIZE * 0.5, 0)
	var p2: Vector2 = anchor + Vector2(FLOOR_ARROW_SIZE * 0.5, 0)
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), FLOOR_ARROW_COLOR)

func _draw_antenna_cone() -> void:
	var radius: float = get_effective_size().x / 2.0
	var dir_rad: float = deg_to_rad(data.antenna_direction_deg)
	var dir: Vector2 = Vector2(sin(dir_rad), -cos(dir_rad))
	var half_angle: float = deg_to_rad(ANTENNA_CONE_HALF_ANGLE_DEG)
	var tip: Vector2 = dir * (radius + ANTENNA_CONE_LENGTH)
	var p1: Vector2 = dir.rotated(-half_angle) * radius
	var p2: Vector2 = dir.rotated(half_angle) * radius
	draw_colored_polygon(PackedVector2Array([p1, tip, p2]), ANTENNA_CONE_COLOR)
