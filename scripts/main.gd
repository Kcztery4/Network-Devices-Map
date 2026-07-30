extends Control

@onready var file_dialog: FileDialog = $FileDialog
@onready var map_path_label: Label = $Root/Toolbar/MapPathLabel
@onready var background: Sprite2D = $Root/Body/MapArea/MapRoot/Background
@onready var map_area = $Root/Body/MapArea

@onready var inspector: Control = $Root/Body/Inspector
@onready var device_fields: Control = $Root/Body/Inspector/InspectorBox/DeviceFields
@onready var name_edit: LineEdit = $Root/Body/Inspector/InspectorBox/DeviceFields/NameEdit
@onready var scale_spin: SpinBox = $Root/Body/Inspector/InspectorBox/DeviceFields/ScaleSpin
@onready var lock_check: CheckBox = $Root/Body/Inspector/InspectorBox/DeviceFields/LockCheck
@onready var slot_label: Label = $Root/Body/Inspector/InspectorBox/DeviceFields/SlotLabel
@onready var slot_spin: SpinBox = $Root/Body/Inspector/InspectorBox/DeviceFields/SlotSpin
@onready var uplink_fields: Control = $Root/Body/Inspector/InspectorBox/UplinkFields
@onready var cable_type_spin: OptionButton = $Root/Body/Inspector/InspectorBox/UplinkFields/CableTypeSpin
@onready var bidirectional_check: CheckBox = $Root/Body/Inspector/InspectorBox/UplinkFields/BidirectionalCheck
@onready var delete_button: Button = $Root/Body/Inspector/InspectorBox/DeleteButton
@onready var uplink_mode_button: Button = $Root/Toolbar/UplinkModeButton
@onready var cable_type_option: OptionButton = $Root/Toolbar/CableTypeOption
@onready var save_project_dialog: FileDialog = $SaveProjectDialog
@onready var load_project_dialog: FileDialog = $LoadProjectDialog
@onready var export_png_dialog: FileDialog = $ExportPngDialog
@onready var settings_panel: PopupPanel = $SettingsPanel

var selected_device: DeviceBase = null
var selected_uplink: UplinkArrow = null
var _updating_inspector := false

var saved_undo_version := 0
var _pending_load_path := ""
var _confirm_dialog: ConfirmationDialog

var clipboard_device_data: Dictionary = {}

var _name_edit_start_value := ""
var _scale_start_value := 1.0
var _slot_start_value := 0
var _last_cable_type_id := -1

const PASTE_OFFSET := Vector2(30, 30)

func _ready() -> void:
	$Root/Toolbar/SettingsButton.pressed.connect(func(): settings_panel.popup_centered())
	$Root/Toolbar/LoadMapButton.pressed.connect(_on_load_map_pressed)
	$Root/Toolbar/AddSwitchButton.pressed.connect(_on_add_switch_pressed)
	$Root/Toolbar/AddRackButton.pressed.connect(_on_add_rack_pressed)
	$Root/Toolbar/AddAPButton.pressed.connect(_on_add_ap_pressed)
	$Root/Toolbar/UplinkModeButton.toggled.connect(_on_uplink_mode_toggled)
	$Root/Toolbar/SaveProjectButton.pressed.connect(_on_save_project_pressed)
	$Root/Toolbar/LoadProjectButton.pressed.connect(_on_load_project_pressed)
	$Root/Toolbar/ExportPngButton.pressed.connect(_on_export_png_pressed)
	file_dialog.file_selected.connect(_on_map_file_selected)
	save_project_dialog.file_selected.connect(_on_save_project_file_selected)
	load_project_dialog.file_selected.connect(_on_load_project_file_selected)
	export_png_dialog.file_selected.connect(_on_export_png_file_selected)
	map_area.device_selected.connect(_on_device_selected)
	map_area.uplink_selected.connect(_on_uplink_selected)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.focus_entered.connect(_on_name_edit_focus_entered)
	name_edit.focus_exited.connect(_on_name_edit_focus_exited)
	scale_spin.value_changed.connect(_on_scale_changed)
	scale_spin.get_line_edit().focus_entered.connect(_on_scale_focus_entered)
	scale_spin.get_line_edit().focus_exited.connect(_on_scale_focus_exited)
	lock_check.toggled.connect(_on_lock_toggled)
	slot_spin.value_changed.connect(_on_slot_count_changed)
	slot_spin.get_line_edit().focus_entered.connect(_on_slot_focus_entered)
	slot_spin.get_line_edit().focus_exited.connect(_on_slot_focus_exited)
	cable_type_option.item_selected.connect(_on_pending_cable_type_selected)
	cable_type_spin.item_selected.connect(_on_uplink_cable_type_changed)
	bidirectional_check.toggled.connect(_on_bidirectional_toggled)
	delete_button.pressed.connect(_on_delete_pressed)
	Settings.settings_changed.connect(_on_settings_changed)

	_confirm_dialog = ConfirmationDialog.new()
	add_child(_confirm_dialog)
	_confirm_dialog.confirmed.connect(_on_discard_confirmed)

	_apply_dynamic_translations()
	map_area.set_pending_cable_type(cable_type_option.get_selected_id())
	inspector.visible = false
	device_fields.visible = false
	uplink_fields.visible = false
	slot_label.visible = false
	slot_spin.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event

	if not key_event.ctrl_pressed:
		match key_event.keycode:
			KEY_DELETE:
				_on_delete_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				map_area.handle_escape()
				get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_Z:
			if key_event.shift_pressed:
				map_area.redo()
			else:
				map_area.undo()
			get_viewport().set_input_as_handled()
		KEY_Y:
			map_area.redo()
			get_viewport().set_input_as_handled()
		KEY_C:
			_copy_selected_device()
			get_viewport().set_input_as_handled()
		KEY_X:
			_cut_selected_device()
			get_viewport().set_input_as_handled()
		KEY_V:
			_paste_device()
			get_viewport().set_input_as_handled()

func _copy_selected_device() -> void:
	if selected_device == null:
		return
	clipboard_device_data = {
		"type": selected_device.data.type,
		"device_name": selected_device.data.device_name,
		"device_scale": selected_device.data.device_scale,
		"slot_count": selected_device.data.slot_count,
		"base_position": selected_device.data.position,
	}

func _cut_selected_device() -> void:
	if selected_device == null:
		return
	_copy_selected_device()
	map_area.remove_device(selected_device)

func _paste_device() -> void:
	if clipboard_device_data.is_empty():
		return
	map_area.duplicate_device_from_data(
		clipboard_device_data["type"],
		clipboard_device_data["device_name"],
		clipboard_device_data["device_scale"],
		clipboard_device_data["slot_count"],
		clipboard_device_data["base_position"] + PASTE_OFFSET
	)
	clipboard_device_data["base_position"] += PASTE_OFFSET

func is_dirty() -> bool:
	return map_area.get_undo_version() != saved_undo_version

func _on_settings_changed() -> void:
	_apply_dynamic_translations()

func _apply_dynamic_translations() -> void:
	file_dialog.title = tr("LOAD_MAP_DIALOG_TITLE")
	save_project_dialog.title = tr("SAVE_PROJECT_DIALOG_TITLE")
	load_project_dialog.title = tr("LOAD_PROJECT_DIALOG_TITLE")
	export_png_dialog.title = tr("EXPORT_PNG_DIALOG_TITLE")
	_confirm_dialog.title = tr("CONFIRM_DISCARD_TITLE")
	_confirm_dialog.dialog_text = tr("CONFIRM_DISCARD_CHANGES")
	var pending_id: int = cable_type_option.get_selected_id()
	var uplink_id: int = cable_type_spin.get_selected_id() if selected_uplink != null else -1
	_populate_cable_type_options(cable_type_option)
	_populate_cable_type_options(cable_type_spin)
	cable_type_option.select(cable_type_option.get_item_index(pending_id))
	if uplink_id != -1:
		cable_type_spin.select(cable_type_spin.get_item_index(uplink_id))

func _populate_cable_type_options(option: OptionButton) -> void:
	option.clear()
	option.add_item(tr("CABLE_COPPER"), UplinkData.CableType.COPPER)
	option.add_item(tr("CABLE_FIBER_1G"), UplinkData.CableType.FIBER_1G)
	option.add_item(tr("CABLE_FIBER_10G"), UplinkData.CableType.FIBER_10G)

func _on_load_map_pressed() -> void:
	file_dialog.popup_centered_ratio(0.8)

func _on_map_file_selected(path: String) -> void:
	_load_background(path)

func _load_background(path: String) -> bool:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error(tr("ERR_LOAD_MAP") % [path, err])
		return false
	var tex := ImageTexture.create_from_image(img)
	background.texture = tex
	background.centered = true
	map_path_label.text = path
	map_area.center_on_texture(tex.get_size())
	return true

func _on_save_project_pressed() -> void:
	save_project_dialog.popup_centered_ratio(0.8)

func _on_save_project_file_selected(path: String) -> void:
	if not path.ends_with(".tres"):
		path += ".tres"
	var project: MapProject = map_area.build_project(map_path_label.text)
	var err := ResourceSaver.save(project, path)
	if err != OK:
		push_error(tr("ERR_SAVE_PROJECT") % [path, err])
		return
	saved_undo_version = map_area.get_undo_version()

func _on_load_project_pressed() -> void:
	load_project_dialog.popup_centered_ratio(0.8)

func _on_load_project_file_selected(path: String) -> void:
	if is_dirty():
		_pending_load_path = path
		_confirm_dialog.popup_centered()
		return
	_load_project_from_path(path)

func _on_discard_confirmed() -> void:
	if _pending_load_path == "":
		return
	_load_project_from_path(_pending_load_path)
	_pending_load_path = ""

func _load_project_from_path(path: String) -> void:
	var project := ResourceLoader.load(path, "MapProject", ResourceLoader.CACHE_MODE_IGNORE) as MapProject
	if project == null:
		push_error(tr("ERR_LOAD_PROJECT") % path)
		return
	selected_device = null
	selected_uplink = null
	_refresh_inspector_visibility()
	if project.background_path != "":
		_load_background(project.background_path)
	else:
		background.texture = null
		map_path_label.text = ""
	map_area.load_project(project)
	saved_undo_version = map_area.get_undo_version()

func _on_export_png_pressed() -> void:
	if background.texture == null:
		push_error(tr("ERR_NO_MAP_EXPORT"))
		return
	export_png_dialog.popup_centered_ratio(0.8)

func _on_export_png_file_selected(path: String) -> void:
	if not path.ends_with(".png"):
		path += ".png"
	_export_map_to_png(path)

const LEGEND_HEIGHT := 40.0
const LEGEND_TOP_PADDING := 16.0
const LEGEND_SWATCH_WIDTH := 36.0
const LEGEND_LABEL_GAP := 8.0
const LEGEND_ITEM_GAP := 28.0
const LEGEND_BG_COLOR := Color(0.12, 0.12, 0.12)
const LEGEND_TEXT_COLOR := Color(1, 1, 1)
const LEGEND_FONT_SIZE := 16

func _export_map_to_png(path: String) -> void:
	var tex_size: Vector2 = background.texture.get_size()
	var used_cable_types: Array = _get_used_cable_types()
	var legend_height: float = LEGEND_TOP_PADDING + LEGEND_HEIGHT if not used_cable_types.is_empty() else 0.0
	var full_size: Vector2 = Vector2(tex_size.x, tex_size.y + legend_height)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(full_size.x), int(full_size.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	var bg_fill := ColorRect.new()
	bg_fill.color = LEGEND_BG_COLOR
	bg_fill.size = full_size
	viewport.add_child(bg_fill)

	var bg_sprite := Sprite2D.new()
	bg_sprite.texture = background.texture
	bg_sprite.centered = true
	bg_sprite.position = tex_size / 2.0
	viewport.add_child(bg_sprite)

	var content_root: Node2D = map_area.build_export_root()
	content_root.position = tex_size / 2.0
	viewport.add_child(content_root)

	if not used_cable_types.is_empty():
		var legend: Node2D = _build_legend(used_cable_types, tex_size.x)
		legend.position = Vector2(0, tex_size.y + LEGEND_TOP_PADDING)
		viewport.add_child(legend)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img: Image = viewport.get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error(tr("ERR_SAVE_PNG") % [path, err])

	viewport.queue_free()

func _get_used_cable_types() -> Array:
	var seen: Dictionary = {}
	for u in map_area.uplinks:
		seen[u.data.cable_type] = true
	var result: Array = seen.keys()
	result.sort()
	return result

func _build_legend(cable_types: Array, available_width: float) -> Node2D:
	var legend := Node2D.new()
	var font: Font = ThemeDB.fallback_font

	var items: Array = []
	for cable_type in cable_types:
		var label_text: String = tr(UplinkArrow.CABLE_LABELS.get(cable_type, "?"))
		var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
		var item_width: float = LEGEND_SWATCH_WIDTH + LEGEND_LABEL_GAP + text_width
		items.append({"type": cable_type, "text": label_text, "width": item_width})

	var total_width: float = 0.0
	for item in items:
		total_width += item["width"]
	total_width += LEGEND_ITEM_GAP * maxi(items.size() - 1, 0)

	var x: float = (available_width - total_width) / 2.0
	var mid_y: float = LEGEND_HEIGHT / 2.0
	for item in items:
		var color: Color = UplinkArrow.CABLE_COLORS.get(item["type"], Color.WHITE)
		var line := Line2D.new()
		line.add_point(Vector2(x, mid_y))
		line.add_point(Vector2(x + LEGEND_SWATCH_WIDTH, mid_y))
		line.width = 4.0
		line.default_color = color
		legend.add_child(line)

		var label := Label.new()
		label.text = item["text"]
		label.add_theme_font_size_override("font_size", LEGEND_FONT_SIZE)
		label.add_theme_color_override("font_color", LEGEND_TEXT_COLOR)
		label.position = Vector2(x + LEGEND_SWATCH_WIDTH + LEGEND_LABEL_GAP, mid_y - LEGEND_FONT_SIZE * 0.7)
		legend.add_child(label)

		x += item["width"] + LEGEND_ITEM_GAP
	return legend

func _on_add_switch_pressed() -> void:
	map_area.add_switch_at_center()

func _on_add_rack_pressed() -> void:
	map_area.add_rack_at_center()

func _on_add_ap_pressed() -> void:
	map_area.add_access_point_at_center()

func _on_device_selected(device: DeviceBase) -> void:
	selected_device = device
	if device != null:
		selected_uplink = null
	_refresh_inspector_visibility()
	if device == null:
		return
	var is_rack: bool = device.data.type == "rack"
	slot_label.visible = is_rack
	slot_spin.visible = is_rack

	_updating_inspector = true
	name_edit.text = device.device_name
	scale_spin.value = device.device_scale
	lock_check.button_pressed = device.data.locked
	if is_rack:
		slot_spin.value = device.device_slot_count
	_updating_inspector = false

func _on_uplink_selected(uplink: UplinkArrow) -> void:
	selected_uplink = uplink
	if uplink != null:
		selected_device = null
	_refresh_inspector_visibility()
	if uplink == null:
		return
	_updating_inspector = true
	cable_type_spin.select(cable_type_spin.get_item_index(uplink.data.cable_type))
	_last_cable_type_id = uplink.data.cable_type
	bidirectional_check.button_pressed = uplink.data.bidirectional
	_updating_inspector = false

func _refresh_inspector_visibility() -> void:
	var has_device: bool = selected_device != null
	var has_uplink: bool = selected_uplink != null
	inspector.visible = has_device or has_uplink
	device_fields.visible = has_device
	uplink_fields.visible = has_uplink
	delete_button.visible = has_device or has_uplink

func _on_uplink_mode_toggled(pressed: bool) -> void:
	map_area.set_uplink_mode(pressed)

func _on_pending_cable_type_selected(_index: int) -> void:
	map_area.set_pending_cable_type(cable_type_option.get_selected_id())

func _on_uplink_cable_type_changed(_index: int) -> void:
	if _updating_inspector or selected_uplink == null:
		return
	var uplink := selected_uplink
	var old_value: int = _last_cable_type_id
	var new_value: int = cable_type_spin.get_selected_id()
	if old_value == new_value:
		return
	_last_cable_type_id = new_value
	map_area.push_undoable_action(
		"Change cable type",
		func(): _apply_cable_type(uplink, new_value),
		func(): _apply_cable_type(uplink, old_value)
	)

func _apply_cable_type(uplink: UplinkArrow, value: int) -> void:
	uplink.data.cable_type = value as UplinkData.CableType
	if uplink == selected_uplink:
		_updating_inspector = true
		cable_type_spin.select(cable_type_spin.get_item_index(value))
		_last_cable_type_id = value
		_updating_inspector = false

func _on_bidirectional_toggled(pressed: bool) -> void:
	if _updating_inspector or selected_uplink == null:
		return
	var uplink := selected_uplink
	var old_value: bool = not pressed
	map_area.push_undoable_action(
		"Toggle bidirectional",
		func(): _apply_bidirectional(uplink, pressed),
		func(): _apply_bidirectional(uplink, old_value)
	)

func _apply_bidirectional(uplink: UplinkArrow, value: bool) -> void:
	uplink.data.bidirectional = value
	if uplink == selected_uplink:
		_updating_inspector = true
		bidirectional_check.button_pressed = value
		_updating_inspector = false

func _on_delete_pressed() -> void:
	if selected_device != null:
		map_area.remove_device(selected_device)
	elif selected_uplink != null:
		map_area.remove_uplink(selected_uplink)

func _on_name_changed(text: String) -> void:
	if _updating_inspector or selected_device == null:
		return
	selected_device.device_name = text

func _on_name_edit_focus_entered() -> void:
	if selected_device != null:
		_name_edit_start_value = selected_device.device_name

func _on_name_edit_focus_exited() -> void:
	if selected_device == null:
		return
	var device := selected_device
	var new_value: String = device.device_name
	var old_value: String = _name_edit_start_value
	if new_value == old_value:
		return
	map_area.push_undoable_action(
		"Rename device",
		func(): _apply_device_name(device, new_value),
		func(): _apply_device_name(device, old_value)
	)

func _apply_device_name(device: DeviceBase, value: String) -> void:
	device.device_name = value
	if device == selected_device:
		_updating_inspector = true
		name_edit.text = value
		_updating_inspector = false

func _on_scale_changed(value: float) -> void:
	if _updating_inspector or selected_device == null:
		return
	selected_device.device_scale = value
	map_area.remember_scale(selected_device.data.type, value)

func _on_scale_focus_entered() -> void:
	if selected_device != null:
		_scale_start_value = selected_device.device_scale

func _on_scale_focus_exited() -> void:
	if selected_device == null:
		return
	var device := selected_device
	var new_value: float = device.device_scale
	var old_value: float = _scale_start_value
	if is_equal_approx(new_value, old_value):
		return
	map_area.push_undoable_action(
		"Change scale",
		func(): _apply_device_scale(device, new_value),
		func(): _apply_device_scale(device, old_value)
	)

func _apply_device_scale(device: DeviceBase, value: float) -> void:
	device.device_scale = value
	map_area.remember_scale(device.data.type, value)
	if device == selected_device:
		_updating_inspector = true
		scale_spin.value = value
		_updating_inspector = false

func _on_lock_toggled(pressed: bool) -> void:
	if _updating_inspector or selected_device == null:
		return
	var device := selected_device
	var old_value: bool = not pressed
	map_area.push_undoable_action(
		"Toggle lock",
		func(): _apply_lock(device, pressed),
		func(): _apply_lock(device, old_value)
	)

func _apply_lock(device: DeviceBase, value: bool) -> void:
	device.data.locked = value
	if device == selected_device:
		_updating_inspector = true
		lock_check.button_pressed = value
		_updating_inspector = false

func _on_slot_count_changed(value: float) -> void:
	if _updating_inspector or selected_device == null:
		return
	selected_device.device_slot_count = int(value)
	map_area.reflow_rack_slots(selected_device)
	map_area.remember_rack_slot_count(int(value))

func _on_slot_focus_entered() -> void:
	if selected_device != null:
		_slot_start_value = selected_device.device_slot_count

func _on_slot_focus_exited() -> void:
	if selected_device == null:
		return
	var device := selected_device
	var new_value: int = device.device_slot_count
	var old_value: int = _slot_start_value
	if new_value == old_value:
		return
	map_area.push_undoable_action(
		"Change slot count",
		func(): _apply_slot_count(device, new_value),
		func(): _apply_slot_count(device, old_value)
	)

func _apply_slot_count(device: DeviceBase, value: int) -> void:
	device.device_slot_count = value
	map_area.reflow_rack_slots(device)
	map_area.remember_rack_slot_count(value)
	if device == selected_device:
		_updating_inspector = true
		slot_spin.value = value
		_updating_inspector = false
