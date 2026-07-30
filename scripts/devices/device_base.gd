extends Node2D
class_name DeviceBase

enum ShapeType { RECTANGLE, CIRCLE }
enum NamePosition { CENTER, TOP }

@export var icon_color: Color = Color(0.6, 0.6, 0.6)
@export var border_color: Color = Color(0.3, 0.3, 0.3)
@export var border_width: float = 2.0
@export var icon_size: Vector2 = Vector2(64, 64)
@export var shape_type: ShapeType = ShapeType.RECTANGLE
@export var name_position: NamePosition = NamePosition.CENTER
@export var show_separator: bool = false
@export var slot_count: int = 0
@export var slot_unit_height: float = 0.0
@export var slot_header_height: float = 32.0
@export var default_type: String = "device"

var data: DeviceData

@onready var name_label: Label = $NameLabel

var device_name: String:
	get:
		return data.device_name if data else ""
	set(value):
		if data:
			data.device_name = value
		if name_label:
			name_label.text = value

var device_scale: float:
	get:
		return data.device_scale if data else 1.0
	set(value):
		if data:
			data.device_scale = value
		scale = Vector2(value, value)

var device_slot_count: int:
	get:
		return data.slot_count if data else slot_count
	set(value):
		var clamped: int = max(value, 0)
		if data:
			data.slot_count = clamped
		_layout_label()
		queue_redraw()

func _ready() -> void:
	if data == null:
		data = DeviceData.new()
		data.id = str(get_instance_id())
		data.type = default_type
		data.device_name = default_type.capitalize()
		data.slot_count = slot_count

	_layout_label()
	name_label.text = data.device_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)

	position = data.position
	scale = Vector2(data.device_scale, data.device_scale)
	queue_redraw()

func get_effective_size() -> Vector2:
	var count: int = data.slot_count if data else slot_count
	if count > 0 and slot_unit_height > 0.0:
		return Vector2(icon_size.x, slot_header_height + slot_unit_height * float(count))
	return icon_size

func _layout_label() -> void:
	var effective_size: Vector2 = get_effective_size()
	var half: Vector2 = effective_size / 2
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match name_position:
		NamePosition.TOP:
			name_label.size = Vector2(effective_size.x - 12.0, 24.0)
			name_label.position = Vector2(-name_label.size.x / 2.0, -half.y + 6.0)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_:
			name_label.size = Vector2(effective_size.x - 8.0, effective_size.y - 8.0)
			name_label.position = -name_label.size / 2.0
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _draw() -> void:
	var effective_size: Vector2 = get_effective_size()
	var half: Vector2 = effective_size / 2
	var count: int = data.slot_count if data else slot_count
	match shape_type:
		ShapeType.CIRCLE:
			var radius: float = effective_size.x / 2.0
			draw_circle(Vector2.ZERO, radius, icon_color)
			if border_width > 0.0:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, border_color, border_width)
		_:
			var rect := Rect2(-half, effective_size)
			draw_rect(rect, icon_color, true)
			if border_width > 0.0:
				draw_rect(rect, border_color, false, border_width)
	if show_separator:
		var sep_y: float = -half.y + slot_header_height
		draw_line(Vector2(-half.x + 6.0, sep_y), Vector2(half.x - 6.0, sep_y), border_color, 1.0)
	if count > 0:
		var slot_height: float = (effective_size.y - slot_header_height) / float(count)
		for i in range(1, count):
			var y: float = -half.y + slot_header_height + slot_height * i
			draw_line(Vector2(-half.x + 6.0, y), Vector2(half.x - 6.0, y), border_color, 1.0)

func get_slot_local_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count: int = data.slot_count if data else slot_count
	if count <= 0:
		return result
	var effective_size: Vector2 = get_effective_size()
	var half: Vector2 = effective_size / 2
	var slot_height: float = (effective_size.y - slot_header_height) / float(count)
	for i in range(count):
		var center_y: float = -half.y + slot_header_height + slot_height * (i + 0.5)
		result.append(Vector2(0.0, center_y))
	return result

func set_position_data(new_pos: Vector2) -> void:
	data.position = new_pos
	position = new_pos

func get_world_rect() -> Rect2:
	var world_size: Vector2 = get_effective_size() * data.device_scale
	return Rect2(data.position - world_size / 2, world_size)
