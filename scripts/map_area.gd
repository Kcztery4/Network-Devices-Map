extends Control

signal device_selected(device: DeviceBase)
signal uplink_selected(uplink: UplinkArrow)

const SWITCH_SCENE: PackedScene = preload("res://scenes/devices/Switch.tscn")
const RACK_SCENE: PackedScene = preload("res://scenes/devices/Rack.tscn")
const AP_SCENE: PackedScene = preload("res://scenes/devices/AccessPoint.tscn")
const UPLINK_ARROW_SCENE: PackedScene = preload("res://scenes/uplink/UplinkArrow.tscn")

const ZOOM_MIN := 0.1
const ZOOM_MAX := 8.0
const ZOOM_STEP := 1.1

const PENDING_HIGHLIGHT := Color(1.0, 0.9, 0.3)
const NORMAL_MODULATE := Color(1, 1, 1)

@onready var map_root: Node2D = $MapRoot
@onready var devices_layer: Node2D = $MapRoot/Devices
@onready var uplinks_layer: Node2D = $MapRoot/Uplinks

var devices: Array[DeviceBase] = []
var selected_device: DeviceBase = null

var uplinks: Array[UplinkArrow] = []
var selected_uplink: UplinkArrow = null

var uplink_mode := false
var pending_from_device: DeviceBase = null
var pending_cable_type: int = UplinkData.CableType.COPPER

var dragging_device := false
var drag_offset := Vector2.ZERO
var drag_start_positions: Dictionary = {}
var drag_start_docks: Dictionary = {}

var dragging_map := false
var last_mouse_pos := Vector2.ZERO

var remembered_scale_by_type: Dictionary = {}
var remembered_rack_slot_count := -1

var undo_redo := UndoRedo.new()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos: Vector2 = _to_map_local(event.position)
				if uplink_mode:
					_handle_uplink_click(local_pos)
					return
				var hit: DeviceBase = _find_device_at(local_pos)
				if hit:
					_select_device(hit)
					_bring_to_front(hit)
					if not hit.data.locked:
						dragging_device = true
						drag_offset = hit.data.position - local_pos
						_capture_drag_start(hit)
				else:
					var uplink_hit: UplinkArrow = _find_uplink_at(local_pos)
					if uplink_hit:
						_select_uplink(uplink_hit)
					else:
						_select_device(null)
			else:
				if dragging_device and selected_device:
					if selected_device.data.type != "rack":
						_update_docking(selected_device)
					_commit_drag()
				dragging_device = false
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_map = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(event.position, 1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion:
		if dragging_device and selected_device:
			var local_pos: Vector2 = _to_map_local(event.position)
			var new_pos: Vector2 = local_pos + drag_offset
			var delta: Vector2 = new_pos - selected_device.data.position
			selected_device.set_position_data(new_pos)
			if selected_device.data.type == "rack":
				for d in devices:
					if d.data.parent_rack_id == selected_device.data.id:
						d.set_position_data(d.data.position + delta)
		elif dragging_map:
			var delta: Vector2 = event.position - last_mouse_pos
			map_root.position += delta
			last_mouse_pos = event.position

func undo() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()

func redo() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()

func get_undo_version() -> int:
	return undo_redo.get_version()

func _capture_drag_start(device: DeviceBase) -> void:
	drag_start_positions.clear()
	drag_start_docks.clear()
	drag_start_positions[device] = device.data.position
	drag_start_docks[device] = [device.data.parent_rack_id, device.data.slot_index]
	if device.data.type == "rack":
		for d in devices:
			if d.data.parent_rack_id == device.data.id:
				drag_start_positions[d] = d.data.position
				drag_start_docks[d] = [d.data.parent_rack_id, d.data.slot_index]

func _commit_drag() -> void:
	var changed := false
	var end_positions: Dictionary = {}
	var end_docks: Dictionary = {}
	for d in drag_start_positions.keys():
		end_positions[d] = d.data.position
		end_docks[d] = [d.data.parent_rack_id, d.data.slot_index]
		if d.data.position != drag_start_positions[d]:
			changed = true

	if changed:
		undo_redo.create_action("Move device")
		for d in drag_start_positions.keys():
			undo_redo.add_do_method(_do_set_position_and_dock.bind(d, end_positions[d], end_docks[d][0], end_docks[d][1]))
		for d in drag_start_positions.keys():
			undo_redo.add_undo_method(_do_set_position_and_dock.bind(d, drag_start_positions[d], drag_start_docks[d][0], drag_start_docks[d][1]))
		undo_redo.commit_action()

	drag_start_positions.clear()
	drag_start_docks.clear()

func _do_set_position_and_dock(device: DeviceBase, pos: Vector2, parent_rack_id: String, slot_index: int) -> void:
	device.set_position_data(pos)
	device.data.parent_rack_id = parent_rack_id
	device.data.slot_index = slot_index

func add_switch_at_center() -> DeviceBase:
	return _add_device_undoable(SWITCH_SCENE, _to_map_local(size / 2))

func add_rack_at_center() -> DeviceBase:
	return _add_device_undoable(RACK_SCENE, _to_map_local(size / 2))

func add_access_point_at_center() -> DeviceBase:
	return _add_device_undoable(AP_SCENE, _to_map_local(size / 2))

func _instantiate_device(scene: PackedScene, spawn_pos: Vector2) -> DeviceBase:
	var device: DeviceBase = scene.instantiate()
	devices_layer.add_child(device)
	device.data.position = spawn_pos
	device.position = spawn_pos
	if remembered_scale_by_type.has(device.data.type):
		device.device_scale = remembered_scale_by_type[device.data.type]
	if device.data.type == "rack" and remembered_rack_slot_count > 0:
		device.device_slot_count = remembered_rack_slot_count
	devices_layer.remove_child(device)
	return device

func _add_device_undoable(scene: PackedScene, spawn_pos: Vector2) -> DeviceBase:
	var device: DeviceBase = _instantiate_device(scene, spawn_pos)
	undo_redo.create_action("Add device")
	undo_redo.add_do_method(_do_add_device.bind(device))
	undo_redo.add_undo_method(_do_remove_device_node.bind(device))
	undo_redo.commit_action()
	return device

func duplicate_device_from_data(type: String, device_name: String, device_scale: float, slot_count: int, spawn_pos: Vector2) -> DeviceBase:
	var scene: PackedScene = _scene_for_type(type)
	var device: DeviceBase = _instantiate_device(scene, spawn_pos)
	device.device_name = device_name
	device.device_scale = device_scale
	if type == "rack":
		device.device_slot_count = slot_count

	undo_redo.create_action("Paste device")
	undo_redo.add_do_method(_do_add_device.bind(device))
	undo_redo.add_undo_method(_do_remove_device_node.bind(device))
	undo_redo.commit_action()
	return device

func remember_scale(type: String, value: float) -> void:
	remembered_scale_by_type[type] = value

func remember_rack_slot_count(value: int) -> void:
	remembered_rack_slot_count = value

func _scene_for_type(type: String) -> PackedScene:
	match type:
		"rack":
			return RACK_SCENE
		"access_point":
			return AP_SCENE
		_:
			return SWITCH_SCENE

func clear_all() -> void:
	_select_device(null)
	_clear_pending_from()
	for u in uplinks.duplicate():
		_do_remove_uplink_node(u)
		u.queue_free()
	for d in devices.duplicate():
		devices.erase(d)
		d.queue_free()
	undo_redo.clear_history()

func build_project(background_path: String) -> MapProject:
	var project := MapProject.new()
	project.background_path = background_path
	var device_datas: Array[DeviceData] = []
	for d in devices:
		device_datas.append(d.data)
	project.devices = device_datas
	var uplink_datas: Array[UplinkData] = []
	for u in uplinks:
		uplink_datas.append(u.data)
	project.uplinks = uplink_datas
	return project

func load_project(project: MapProject) -> void:
	clear_all()
	for device_data in project.devices:
		var scene: PackedScene = _scene_for_type(device_data.type)
		var device: DeviceBase = scene.instantiate()
		device.data = device_data
		devices_layer.add_child(device)
		devices.append(device)
	for uplink_data in project.uplinks:
		var from_device: DeviceBase = _find_device_by_id(uplink_data.from_id)
		var to_device: DeviceBase = _find_device_by_id(uplink_data.to_id)
		if from_device == null or to_device == null:
			continue
		var arrow: UplinkArrow = UPLINK_ARROW_SCENE.instantiate()
		uplinks_layer.add_child(arrow)
		arrow.data = uplink_data
		arrow.from_device = from_device
		arrow.to_device = to_device
		uplinks.append(arrow)
	undo_redo.clear_history()

func _find_device_by_id(id: String) -> DeviceBase:
	for d in devices:
		if d.data.id == id:
			return d
	return null

func build_export_root() -> Node2D:
	var root := Node2D.new()
	var clone_by_id: Dictionary = {}
	for d in devices:
		var scene: PackedScene = _scene_for_type(d.data.type)
		var clone: DeviceBase = scene.instantiate()
		clone.data = d.data.duplicate()
		root.add_child(clone)
		clone_by_id[d.data.id] = clone
	for u in uplinks:
		var from_clone: DeviceBase = clone_by_id.get(u.data.from_id)
		var to_clone: DeviceBase = clone_by_id.get(u.data.to_id)
		if from_clone == null or to_clone == null:
			continue
		var arrow: UplinkArrow = UPLINK_ARROW_SCENE.instantiate()
		arrow.data = u.data.duplicate()
		arrow.from_device = from_clone
		arrow.to_device = to_clone
		root.add_child(arrow)
	return root

func _do_add_device(device: DeviceBase) -> void:
	if not devices_layer.is_ancestor_of(device):
		devices_layer.add_child(device)
	if not devices.has(device):
		devices.append(device)
	_select_device(device)

func _do_remove_device_node(device: DeviceBase) -> void:
	devices.erase(device)
	if selected_device == device:
		_select_device(null)
	if devices_layer.is_ancestor_of(device):
		devices_layer.remove_child(device)

func _do_add_uplink(uplink: UplinkArrow) -> void:
	if not uplinks_layer.is_ancestor_of(uplink):
		uplinks_layer.add_child(uplink)
	if not uplinks.has(uplink):
		uplinks.append(uplink)

func _do_remove_uplink_node(uplink: UplinkArrow) -> void:
	uplinks.erase(uplink)
	if selected_uplink == uplink:
		_select_uplink(null)
	if uplinks_layer.is_ancestor_of(uplink):
		uplinks_layer.remove_child(uplink)

func _do_set_dock(device: DeviceBase, parent_rack_id: String, slot_index: int) -> void:
	device.data.parent_rack_id = parent_rack_id
	device.data.slot_index = slot_index

func remove_device(device: DeviceBase) -> void:
	var affected_children: Array = []
	for d in devices:
		if d.data.parent_rack_id == device.data.id:
			affected_children.append({"device": d, "parent_rack_id": d.data.parent_rack_id, "slot_index": d.data.slot_index})
	var affected_uplinks: Array = []
	for u in uplinks:
		if u.data.from_id == device.data.id or u.data.to_id == device.data.id:
			affected_uplinks.append(u)

	undo_redo.create_action("Remove device")
	for u in affected_uplinks:
		undo_redo.add_do_method(_do_remove_uplink_node.bind(u))
	for entry in affected_children:
		undo_redo.add_do_method(_do_set_dock.bind(entry["device"], "", -1))
	undo_redo.add_do_method(_do_remove_device_node.bind(device))

	undo_redo.add_undo_method(_do_add_device.bind(device))
	for entry in affected_children:
		undo_redo.add_undo_method(_do_set_dock.bind(entry["device"], entry["parent_rack_id"], entry["slot_index"]))
	for u in affected_uplinks:
		undo_redo.add_undo_method(_do_add_uplink.bind(u))
	undo_redo.commit_action()

func center_on_texture(_texture_size: Vector2) -> void:
	map_root.scale = Vector2.ONE
	map_root.position = size / 2

func _to_map_local(p: Vector2) -> Vector2:
	return (p - map_root.position) / map_root.scale.x

func _find_device_at(local_pos: Vector2) -> DeviceBase:
	for i in range(devices.size() - 1, -1, -1):
		var d: DeviceBase = devices[i]
		if d.get_world_rect().has_point(local_pos):
			return d
	return null

func _find_rack_at(pos: Vector2, exclude: DeviceBase) -> DeviceBase:
	for d in devices:
		if d == exclude:
			continue
		if d.data.type == "rack" and d.get_world_rect().has_point(pos):
			return d
	return null

func _bring_to_front(device: DeviceBase) -> void:
	devices_layer.move_child(device, devices_layer.get_child_count() - 1)
	if device.data.type == "rack":
		for d in devices:
			if d.data.parent_rack_id == device.data.id:
				devices_layer.move_child(d, devices_layer.get_child_count() - 1)

func _update_docking(device: DeviceBase) -> void:
	var rack: DeviceBase = _find_rack_at(device.data.position, device)
	if rack == null:
		device.data.parent_rack_id = ""
		device.data.slot_index = -1
		return

	var slot_positions: Array[Vector2] = rack.get_slot_local_positions()
	if slot_positions.is_empty():
		device.data.parent_rack_id = rack.data.id
		device.data.slot_index = -1
		return

	var occupied: Dictionary = {}
	for d in devices:
		if d != device and d.data.parent_rack_id == rack.data.id and d.data.slot_index >= 0:
			occupied[d.data.slot_index] = true

	var best_index := -1
	var best_dist := INF
	for i in range(slot_positions.size()):
		if occupied.has(i):
			continue
		var world_pos: Vector2 = rack.data.position + slot_positions[i] * rack.data.device_scale
		var dist: float = world_pos.distance_to(device.data.position)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	if best_index == -1:
		device.data.parent_rack_id = ""
		device.data.slot_index = -1
		return

	device.data.parent_rack_id = rack.data.id
	device.data.slot_index = best_index
	var snapped_pos: Vector2 = rack.data.position + slot_positions[best_index] * rack.data.device_scale
	device.set_position_data(snapped_pos)

func reflow_rack_slots(rack: DeviceBase) -> void:
	var slot_positions: Array[Vector2] = rack.get_slot_local_positions()
	for d in devices:
		if d.data.parent_rack_id != rack.data.id:
			continue
		if d.data.slot_index >= 0 and d.data.slot_index < slot_positions.size():
			var new_pos: Vector2 = rack.data.position + slot_positions[d.data.slot_index] * rack.data.device_scale
			d.set_position_data(new_pos)
		else:
			d.data.parent_rack_id = ""
			d.data.slot_index = -1

func _select_device(device: DeviceBase) -> void:
	selected_device = device
	if device != null:
		selected_uplink = null
	device_selected.emit(device)

func _select_uplink(uplink: UplinkArrow) -> void:
	selected_uplink = uplink
	if uplink != null:
		selected_device = null
	device_selected.emit(null)
	uplink_selected.emit(uplink)

func handle_escape() -> void:
	if pending_from_device != null:
		_clear_pending_from()
	else:
		_select_device(null)
		_select_uplink(null)

func set_uplink_mode(active: bool) -> void:
	uplink_mode = active
	_clear_pending_from()

func set_pending_cable_type(cable_type: int) -> void:
	pending_cable_type = cable_type

func _handle_uplink_click(local_pos: Vector2) -> void:
	var hit_device: DeviceBase = _find_device_at(local_pos)
	if hit_device == null:
		_clear_pending_from()
		return
	if pending_from_device == null:
		pending_from_device = hit_device
		hit_device.modulate = PENDING_HIGHLIGHT
	elif pending_from_device == hit_device:
		_clear_pending_from()
	else:
		add_uplink(pending_from_device, hit_device, pending_cable_type)
		_clear_pending_from()

func _clear_pending_from() -> void:
	if pending_from_device:
		pending_from_device.modulate = NORMAL_MODULATE
	pending_from_device = null

func _has_uplink_between(a_id: String, b_id: String) -> bool:
	for u in uplinks:
		if (u.data.from_id == a_id and u.data.to_id == b_id) or (u.data.from_id == b_id and u.data.to_id == a_id):
			return true
	return false

func add_uplink(from_device: DeviceBase, to_device: DeviceBase, cable_type: int) -> UplinkArrow:
	if _has_uplink_between(from_device.data.id, to_device.data.id):
		push_error(tr("ERR_UPLINK_EXISTS"))
		return null

	var uplink_data := UplinkData.new()
	uplink_data.id = "uplink_%d_%d" % [Time.get_ticks_usec(), uplinks.size()]
	uplink_data.from_id = from_device.data.id
	uplink_data.to_id = to_device.data.id
	uplink_data.cable_type = cable_type as UplinkData.CableType

	var arrow: UplinkArrow = UPLINK_ARROW_SCENE.instantiate()
	arrow.data = uplink_data
	arrow.from_device = from_device
	arrow.to_device = to_device

	undo_redo.create_action("Add uplink")
	undo_redo.add_do_method(_do_add_uplink.bind(arrow))
	undo_redo.add_undo_method(_do_remove_uplink_node.bind(arrow))
	undo_redo.commit_action()
	return arrow

func remove_uplink(uplink: UplinkArrow) -> void:
	undo_redo.create_action("Remove uplink")
	undo_redo.add_do_method(_do_remove_uplink_node.bind(uplink))
	undo_redo.add_undo_method(_do_add_uplink.bind(uplink))
	undo_redo.commit_action()

func _find_uplink_at(local_pos: Vector2) -> UplinkArrow:
	var threshold: float = 6.0 / map_root.scale.x
	for i in range(uplinks.size() - 1, -1, -1):
		var u: UplinkArrow = uplinks[i]
		if u.distance_to_point(local_pos) <= threshold:
			return u
	return null

func _zoom(mouse_pos: Vector2, factor: float) -> void:
	var old_scale: float = map_root.scale.x
	var new_scale: float = clamp(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	var applied_factor: float = new_scale / old_scale
	map_root.position = mouse_pos - (mouse_pos - map_root.position) * applied_factor
	map_root.scale = Vector2(new_scale, new_scale)

func push_undoable_action(action_name: String, do_call: Callable, undo_call: Callable) -> void:
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(do_call)
	undo_redo.add_undo_method(undo_call)
	undo_redo.commit_action()
