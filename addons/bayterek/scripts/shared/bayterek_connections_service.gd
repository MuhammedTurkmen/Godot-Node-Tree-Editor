@tool
class_name BayterekConnectionsService
extends BayterekBaseService
## Connection creation / deletion / updates.

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
# QUERY
# ============================================================

func get_line(from_id: int, to_id: int) -> BayterekConnection:
	return _lines.get(_key(from_id, to_id), null)

func has_line(from_id: int, to_id: int) -> bool:
	return _lines.has(_key(from_id, to_id))

# ============================================================
# CREATION
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

	# Create line data
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
	line.texture_mode = BayterekLine2D.TextureMode.TILE
	line.round_joints = true
	line.round_caps = true

	# Get line data from source node
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
	_refresh_line_state(from_id, to_id)

	line_created.emit(line, from_id, to_id)
	return line

# ============================================================
# DELETION
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
# UPDATE
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

## Called when line data changes (curve, segments, etc.)
func refresh_line(from_id: int, to_id: int) -> void:
	var line: BayterekConnection = get_line(from_id, to_id)
	if line:
		_update_line_points(line)
		line_changed.emit(from_id, to_id)

# ============================================================
# ALLOCATION STATE VISUALS
# ============================================================

## Called when a node's allocation state changes.
## Updates texture on all lines touching this node.
func on_node_allocation_changed(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	if node.type == BayterekNode.NodeType.DECORATION:
		return

	# Outgoing lines
	for to_id in node.node_data.out_nodes:
		_refresh_line_state(node.id, to_id)

	# Incoming lines
	for from_id in node.node_data.in_nodes:
		_refresh_line_state(from_id, node.id)

## Picks the right texture based on endpoint allocation states.
func _refresh_line_state(from_id: int, to_id: int) -> void:
	var line: BayterekConnection = get_line(from_id, to_id)
	if not line:
		return

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(to_id)
	if not from_node or not to_node:
		return

	# Determine if each endpoint is "active" (allocated or preallocated)
	var from_active: bool = from_node.allocated or from_node.preallocated
	var to_active: bool = to_node.allocated or to_node.preallocated

	# Refund mode: treat node as active if it still has remaining levels
	if _tree_data.multiallocation:
		if from_node.refund:
			from_active = from_node.allocation_level > 1
		if to_node.refund:
			to_active = to_node.allocation_level > 1

	# Pick texture
	var texture: Texture2D = null
	if from_active and to_active:
		texture = _tree_data.line_texture_active
	elif from_active or to_active:
		texture = _tree_data.line_texture_intermediate
	else:
		texture = _tree_data.line_texture_normal

	line.texture = texture

	# Visibility rule: when tree is not revealed, hide normal lines
	if not _tree_data.revealed and not from_active and not to_active:
		line.visible = false
	else:
		line.visible = true

# ============================================================
# PRIVATE — shape calculation
# ============================================================

func _update_line_points(line: BayterekConnection) -> void:
	if not is_instance_valid(line):
		return

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.to_id)
	if not from_node or not to_node:
		return

	# Node centers
	var from_center: Vector2 = from_node.position + (from_node.size * 0.5)
	var to_center: Vector2 = to_node.position + (to_node.size * 0.5)

	# Node half-extents (for edge intersection when arrow is present)
	var from_half: Vector2 = from_node.size * 0.5
	var to_half: Vector2 = to_node.size * 0.5

	var data: BayterekLineData = line.line_data
	if not data:
		data = BayterekLineData.new()

	# Start point:
	#   - Arrow at start → line starts OUTSIDE the node so the arrow is visible.
	#   - No arrow       → line starts at the node CENTER (hidden behind the node).
	var p0: Vector2
	if data.start_arrow != BayterekLineData.ArrowStyle.NONE:
		var start_padding: float = data.arrow_size * 0.5 + 4.0
		p0 = _edge_point(from_center, to_center, from_half, start_padding)
	else:
		p0 = from_center

	# End point:
	#   - Arrow at end → line ends OUTSIDE the node.
	#   - No arrow     → line ends at the node CENTER.
	var p2: Vector2
	if data.end_arrow != BayterekLineData.ArrowStyle.NONE:
		var end_padding: float = data.arrow_size * 0.5 + 4.0
		p2 = _edge_point(to_center, from_center, to_half, end_padding)
	else:
		p2 = to_center

	# Shape
	match data.line_type:
		BayterekLineData.LineType.STRAIGHT:
			line.clear_points()
			line.add_point(p0)
			line.add_point(p2)
		BayterekLineData.LineType.BEZIER:
			line.points = _bezier_points(p0, p2, data)
		BayterekLineData.LineType.ARC:
			line.points = _arc_points(p0, p2, data)
		BayterekLineData.LineType.STEP:
			line.points = _step_points(p0, p2, data)

	# Apply line style (dash pattern) to the BayterekLine2D
	line.dash_style = data.line_style as BayterekLine2D.DashStyle
	line.dash_length = data.dash_length
	line.dash_gap = data.dash_gap

	# Apply arrow styles
	line.start_arrow = data.start_arrow as BayterekLine2D.ArrowStyle
	line.end_arrow = data.end_arrow as BayterekLine2D.ArrowStyle
	line.arrow_size = data.arrow_size

## Returns the point where a line from `source_center` towards
## `target_center` exits a node whose bounding box has the given
## `half_extents`, offset outward by `padding` pixels.
##
## Used so connection lines, arrowheads and dash patterns don't hide
## behind nodes.
func _edge_point(source_center: Vector2, target_center: Vector2, half_extents: Vector2, padding: float = 0.0) -> Vector2:
	var dir: Vector2 = target_center - source_center
	if dir.length_squared() < 0.0001:
		return source_center

	# Expand the bounding box by `padding` in every direction.
	var expanded_half: Vector2 = half_extents + Vector2(padding, padding)

	# Slab method: for each axis, find t where the ray hits the box.
	var t_x: float = INF
	var t_y: float = INF

	if absf(dir.x) > 0.0001:
		t_x = expanded_half.x / absf(dir.x)

	if absf(dir.y) > 0.0001:
		t_y = expanded_half.y / absf(dir.y)

	# The exit point is at the smaller t (the axis the ray hits first).
	var t: float = min(t_x, t_y)

	return source_center + dir * t

## Quadratic Bezier curve
func _bezier_points(p0: Vector2, p2: Vector2, data: BayterekLineData) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments: int = max(2, data.segments)

	var center: Vector2 = (p0 + p2) * 0.5
	var dir: Vector2 = p2 - p0
	var length: float = dir.length()

	if length < 0.1:
		return PackedVector2Array([p0, p2])

	var normal: Vector2 = Vector2(-dir.y, dir.x) / length
	var p1: Vector2
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

## Arc — half circle around midpoint
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

## Step / square (orthogonal) line: exits the source node, makes one 90°
## turn at `step_distance`, then goes straight into the target node.
##
## If the nodes are horizontally further apart than they are vertically,
## the line exits horizontally first. Otherwise it exits vertically first.
func _step_points(p0: Vector2, p2: Vector2, data: BayterekLineData) -> PackedVector2Array:
	var pts := PackedVector2Array()

	var dx: float = p2.x - p0.x
	var dy: float = p2.y - p0.y

	# Dead-zone: if nodes overlap on one axis, collapse that axis.
	var step: float = max(8.0, data.step_distance)

	# Choose orientation: primary axis is the one with the larger delta.
	if absf(dx) >= absf(dy):
		# Exit horizontally, then turn vertically, then enter horizontally.
		var mid_x: float = p0.x + signf(dx) * min(step, absf(dx) * 0.5)

		pts.push_back(p0)
		pts.push_back(Vector2(mid_x, p0.y))
		pts.push_back(Vector2(mid_x, p2.y))
		pts.push_back(p2)
	else:
		# Exit vertically, then turn horizontally, then enter vertically.
		var mid_y: float = p0.y + signf(dy) * min(step, absf(dy) * 0.5)

		pts.push_back(p0)
		pts.push_back(Vector2(p0.x, mid_y))
		pts.push_back(Vector2(p2.x, mid_y))
		pts.push_back(p2)

	return pts

func _key(from_id: int, to_id: int) -> String:
	return "%d_%d" % [from_id, to_id]