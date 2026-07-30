extends Node2D
class_name UplinkArrow

const ARROW_SIZE := 16.0
const ARROW_WIDTH_RATIO := 0.65
const SELECT_THRESHOLD := 8.0
const OUTLINE_COLOR := Color(0.05, 0.05, 0.05, 0.9)
const OUTLINE_EXTRA_WIDTH := 3.0
const BYPASS_MARGIN := 14.0

const CABLE_COLORS := {
	UplinkData.CableType.COPPER: Color(0.85, 0.55, 0.15),
	UplinkData.CableType.FIBER_1G: Color(0.15, 0.75, 0.95),
	UplinkData.CableType.FIBER_10G: Color(0.15, 0.75, 0.25),
}
const CABLE_WIDTHS := {
	UplinkData.CableType.COPPER: 3.4,
	UplinkData.CableType.FIBER_1G: 3.4,
	UplinkData.CableType.FIBER_10G: 4.7,
}
const CABLE_LABELS := {
	UplinkData.CableType.COPPER: "CABLE_COPPER",
	UplinkData.CableType.FIBER_1G: "CABLE_FIBER_1G",
	UplinkData.CableType.FIBER_10G: "CABLE_FIBER_10G",
}

var data: UplinkData
var from_device: DeviceBase
var to_device: DeviceBase

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if from_device == null or to_device == null or data == null:
		return
	var path: PackedVector2Array = _compute_path()
	if path.size() < 2:
		return
	var color: Color = CABLE_COLORS.get(data.cable_type, Color.WHITE)
	var width: float = CABLE_WIDTHS.get(data.cable_type, 2.0)
	var last: int = path.size() - 1

	draw_polyline(path, OUTLINE_COLOR, width + OUTLINE_EXTRA_WIDTH, true)
	_draw_arrow_head(path[last], _segment_dir(path[last - 1], path[last]), OUTLINE_COLOR, OUTLINE_EXTRA_WIDTH)
	if data.bidirectional:
		_draw_arrow_head(path[0], _segment_dir(path[1], path[0]), OUTLINE_COLOR, OUTLINE_EXTRA_WIDTH)

	draw_polyline(path, color, width, true)
	_draw_arrow_head(path[last], _segment_dir(path[last - 1], path[last]), color, 0.0)
	if data.bidirectional:
		_draw_arrow_head(path[0], _segment_dir(path[1], path[0]), color, 0.0)

func _compute_path() -> PackedVector2Array:
	var from_center: Vector2 = from_device.data.position
	var to_center: Vector2 = to_device.data.position
	var dir: Vector2 = to_center - from_center
	if dir.length() < 0.001:
		return PackedVector2Array()
	dir = dir.normalized()
	var from_point: Vector2 = _edge_point(from_center, from_device.get_world_rect().size / 2, dir)
	var to_point: Vector2 = _edge_point(to_center, to_device.get_world_rect().size / 2, -dir)

	var obstacles: Array = _find_obstacles(from_point, to_point, dir)
	if obstacles.is_empty():
		return PackedVector2Array([from_point, to_point])
	return _build_bypass_path(from_center, to_center, dir, obstacles)

func _build_bypass_path(from_center: Vector2, to_center: Vector2, dir: Vector2, obstacles: Array) -> PackedVector2Array:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	if perp.x < 0.0 or (perp.x == 0.0 and perp.y < 0.0):
		perp = -perp

	var from_half: float = _half_extent(from_device.get_world_rect(), perp)
	var to_half: float = _half_extent(to_device.get_world_rect(), perp)

	# Odległość toru objazdu od osi połączenia: musi minąć każdą przeszkodę
	# oraz wystawać poza oba urządzenia końcowe.
	var lane: float = maxf(from_half, to_half) + BYPASS_MARGIN
	for obstacle in obstacles:
		var rect: Rect2 = obstacle["rect"]
		var center_offset: float = (rect.get_center() - from_center).dot(perp)
		lane = maxf(lane, center_offset + _half_extent(rect, perp) + BYPASS_MARGIN)

	return PackedVector2Array([
		from_center + perp * from_half,
		from_center + perp * lane,
		to_center + perp * lane,
		to_center + perp * to_half,
	])

func _find_obstacles(from_point: Vector2, to_point: Vector2, dir: Vector2) -> Array:
	var result: Array = []
	var parent: Node = from_device.get_parent()
	if parent == null:
		return result
	for child in parent.get_children():
		if not (child is DeviceBase):
			continue
		if child == from_device or child == to_device:
			continue
		if child.data.type == "rack":
			continue
		var rect: Rect2 = child.get_world_rect()
		if _segment_intersects_rect(from_point, to_point, rect):
			result.append({"rect": rect, "t": (rect.get_center() - from_point).dot(dir)})
	result.sort_custom(func(a, b): return a["t"] < b["t"])
	return result

func _segment_intersects_rect(p1: Vector2, p2: Vector2, rect: Rect2) -> bool:
	if rect.has_point(p1) or rect.has_point(p2):
		return true
	var corners: PackedVector2Array = PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	])
	for i in range(4):
		if Geometry2D.segment_intersects_segment(p1, p2, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false

func _half_extent(rect: Rect2, axis: Vector2) -> float:
	var half_size: Vector2 = rect.size / 2.0
	return absf(axis.x) * half_size.x + absf(axis.y) * half_size.y

func _segment_dir(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	if d.length() < 0.001:
		return Vector2.RIGHT
	return d.normalized()

func _draw_arrow_head(tip: Vector2, dir: Vector2, color: Color, extra: float) -> void:
	var size: float = ARROW_SIZE + extra
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var back: Vector2 = tip - dir * size
	var p1: Vector2 = back + perp * size * ARROW_WIDTH_RATIO
	var p2: Vector2 = back - perp * size * ARROW_WIDTH_RATIO
	draw_colored_polygon(PackedVector2Array([tip + dir * extra * 0.5, p1, p2]), color)

func _edge_point(center: Vector2, half_size: Vector2, dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return center
	var tx: float = INF if dir.x == 0.0 else half_size.x / absf(dir.x)
	var ty: float = INF if dir.y == 0.0 else half_size.y / absf(dir.y)
	var t: float = minf(tx, ty)
	return center + dir * t

func distance_to_point(p: Vector2) -> float:
	if from_device == null or to_device == null:
		return INF
	var path: PackedVector2Array = _compute_path()
	if path.size() < 2:
		return INF
	var best: float = INF
	for i in range(path.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
		best = minf(best, p.distance_to(closest))
	return best
