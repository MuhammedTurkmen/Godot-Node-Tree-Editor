@tool
class_name BayterekConnectionsService
extends BayterekBaseService
## Bağlantı oluşturma / silme / güncelleme.

signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal line_removed(from_id: int, to_id: int)
signal line_changed(from_id: int, to_id: int)

var _lines: Dictionary = {}   # "from_id_to_id" -> BayterekConnection

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	for node_data in _tree_data.nodes:
		for to_id in node_data.out_nodes:
			_create_line_from_data(node_data.id, to_id)

# ============================================================
# SORGU
# ============================================================

func get_line(from_id: int, to_id: int) -> BayterekConnection:
	return _lines.get(_key(from_id, to_id), null)

func has_line(from_id: int, to_id: int) -> bool:
	return _lines.has(_key(from_id, to_id))

# ============================================================
# OLUŞTURMA
# ============================================================

func create_connection(from_node: BayterekNodeButton, to_node: BayterekNodeButton) -> BayterekConnection:
	if not from_node or not to_node:
		return null
	if from_node.id == to_node.id:
		return null

	if has_line(from_node.id, to_node.id):
		return null

	var from_data: BayterekNode = from_node.node_data
	var to_data: BayterekNode = to_node.node_data

	from_data.out_nodes.append(to_data.id)
	to_data.in_nodes.append(from_data.id)

	# Line data oluştur
	var line_data := BayterekLineData.new()
	from_data.line_data[to_data.id] = line_data

	var line := _create_line_from_data(from_data.id, to_data.id)

	return line

func _create_line_from_data(from_id: int, to_id: int) -> BayterekConnection:
	var line := BayterekConnection.new()
	line.name = "Line_%d_%d" % [from_id, to_id]
	line.from_id = from_id
	line.to_id = to_id

	line.width = 4.0
	line.default_color = Color(0.7, 0.7, 0.7, 0.9)
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	line.antialiased = true

	# LineData al
	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(from_id)
	if from_node and from_node.node_data:
		if from_node.node_data.line_data.has(to_id):
			line.line_data = from_node.node_data.line_data[to_id]
		else:
			line.line_data = BayterekLineData.new()
			from_node.node_data.line_data[to_id] = line.line_data
	else:
		line.line_data = BayterekLineData.new()

	_tree_view.lines_container.add_child(line)
	_lines[_key(from_id, to_id)] = line

	_update_line_points(line)

	line_created.emit(line, from_id, to_id)
	return line

# ============================================================
# SİLME
# ============================================================

func remove_connection(from_id: int, to_id: int) -> void:
	var key: String = _key(from_id, to_id)
	if not _lines.has(key):
		return

	var line: BayterekConnection = _lines[key]
	_lines.erase(key)

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(to_id)
	if from_node and from_node.node_data:
		from_node.node_data.out_nodes.erase(to_id)
		from_node.node_data.line_data.erase(to_id)
	if to_node and to_node.node_data:
		to_node.node_data.in_nodes.erase(from_id)

	if is_instance_valid(line):
		_tree_view.lines_container.remove_child(line)
		line.queue_free()

	line_removed.emit(from_id, to_id)

func remove_all_connections_of(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return

	var out_ids: Array = node.node_data.out_nodes.duplicate()
	var in_ids: Array = node.node_data.in_nodes.duplicate()

	for to_id in out_ids:
		remove_connection(node.id, to_id)

	for from_id in in_ids:
		remove_connection(from_id, node.id)

# ============================================================
# GÜNCELLEME
# ============================================================

func update_lines_of(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return

	for to_id in node.node_data.out_nodes:
		var line: BayterekConnection = get_line(node.id, to_id)
		if line:
			_update_line_points(line)

	for from_id in node.node_data.in_nodes:
		var line: BayterekConnection = get_line(from_id, node.id)
		if line:
			_update_line_points(line)

func update_all_lines() -> void:
	for line in _lines.values():
		if is_instance_valid(line):
			_update_line_points(line)

## Line data değişince çağrılır — çizgiyi yeniden şekillendirir
func refresh_line(from_id: int, to_id: int) -> void:
	var line: BayterekConnection = get_line(from_id, to_id)
	if line:
		_update_line_points(line)
		line_changed.emit(from_id, to_id)

# ============================================================
# PRIVATE — şekil hesaplama
# ============================================================

func _update_line_points(line: BayterekConnection) -> void:
	if not is_instance_valid(line):
		return

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.to_id)

	if not from_node or not to_node:
		return

	var p0: Vector2 = from_node.position + (from_node.size * 0.5)
	var p2: Vector2 = to_node.position + (to_node.size * 0.5)

	var data: BayterekLineData = line.line_data
	if not data:
		data = BayterekLineData.new()

	match data.line_type:
		BayterekLineData.LineType.STRAIGHT:
			line.clear_points()
			line.add_point(p0)
			line.add_point(p2)
		BayterekLineData.LineType.BEZIER:
			line.points = _bezier_points(p0, p2, data)
		BayterekLineData.LineType.ARC:
			line.points = _arc_points(p0, p2, data)

## Quadratic Bezier eğrisi
func _bezier_points(p0: Vector2, p2: Vector2, data: BayterekLineData) -> PackedVector2Array:
	var pts := PackedVector2Array()

	var segments: int = max(2, data.segments)
	var p1: Vector2

	var center: Vector2 = (p0 + p2) * 0.5
	var dir: Vector2 = p2 - p0
	var length: float = dir.length()

	if length < 0.1:
		return PackedVector2Array([p0, p2])

	var normal: Vector2 = Vector2(-dir.y, dir.x) / length
	if data.reversed:
		p1 = center - normal * data.curve_height
	else:
		p1 = center + normal * data.curve_height

	pts.resize(segments + 1)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: Vector2 = p0.lerp(p1, t)
		var b: Vector2 = p1.lerp(p2, t)
		pts[i] = a.lerp(b, t)

	return pts

## Yay — merkez etrafında dönen yarım daire
func _arc_points(p0: Vector2, p2: Vector2, data: BayterekLineData) -> PackedVector2Array:
	var pts := PackedVector2Array()

	var segments: int = max(2, data.segments)
	var chord: Vector2 = p2 - p0
	var diameter: float = chord.length()

	if diameter < 0.001:
		return PackedVector2Array([p0, p2])

	var center: Vector2 = (p0 + p2) * 0.5
	var sign: float = -1.0 if data.reversed else 1.0

	pts.resize(segments + 1)
	var step: float = PI / float(segments)

	for i in range(segments + 1):
		var angle: float = sign * step * float(i)
		pts[i] = center + (p0 - center).rotated(angle)

	return pts

func _key(from_id: int, to_id: int) -> String:
	return "%d_%d" % [from_id, to_id]