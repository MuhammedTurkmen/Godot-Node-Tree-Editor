@tool
class_name BayterekConnectionsService
extends BayterekBaseService
## Connection creation / deletion / updates.

signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal line_removed(from_id: int, to_id: int)
signal line_changed(from_id: int, to_id: int)

var _lines: Dictionary = {}

func load_tree(tree_data: BayterekTree) -> void:
	_tree_data = tree_data

	for node_data in _tree_data.nodes:
		for to_id in node_data.out_nodes:
			_create_line_from_data(node_data.id, to_id)

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

	var line_data := BayterekLineData.new()

	if _tree_data:
		_tree_data.apply_connection_defaults(line_data)

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
	line.smooth_antialiasing = true
	line.texture_mode = BayterekLine2D.TextureMode.NONE
	line.round_joints = true
	line.cap_start = BayterekLine2D.CapStyle.BUTT
	line.cap_end = BayterekLine2D.CapStyle.BUTT

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(from_id)
	if from_node and from_node.node_data:
		if from_node.node_data.line_data.has(to_id):
			line.line_data = from_node.node_data.line_data[to_id]
		else:
			line.line_data = BayterekLineData.new()
			if _tree_data:
				_tree_data.apply_connection_defaults(line.line_data)
			from_node.node_data.line_data[to_id] = line.line_data
	else:
		line.line_data = BayterekLineData.new()
		if _tree_data:
			_tree_data.apply_connection_defaults(line.line_data)

	_apply_auto_phase_offset(line.line_data, from_id, to_id)

	_tree_view.lines_container.add_child(line)
	_lines[_key(from_id, to_id)] = line

	_update_line_points(line)
	_refresh_line_state(from_id, to_id)

	line_created.emit(line, from_id, to_id)
	return line


func _apply_auto_phase_offset(data: BayterekLineData, from_id: int, to_id: int) -> void:
	if not data:
		return
	if data.is_overridden("wiggle_phase_offset"):
		return

	var h: int = (from_id * 73856093) ^ (to_id * 19349663)
	h = h ^ (h >> 13)
	h = h * 1274126177
	h = h ^ (h >> 16)

	var frac: float = float(h & 0xFFFF) / 65536.0
	data.wiggle_phase_offset = frac * TAU

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

func refresh_line(from_id: int, to_id: int) -> void:
	var line: BayterekConnection = get_line(from_id, to_id)
	if line:
		_update_line_points(line)
		line_changed.emit(from_id, to_id)

# ============================================================
# ALLOCATION STATE VISUALS
# ============================================================

func on_node_allocation_changed(node: BayterekNodeButton) -> void:
	if not node or not node.node_data:
		return
	if node.node_data.is_decoration:
		return

	for to_id in node.node_data.out_nodes:
		_refresh_line_state(node.id, to_id)
		var line_out: BayterekConnection = get_line(node.id, to_id)
		if line_out:
			_update_wiggle_intensity(line_out)

	for from_id in node.node_data.in_nodes:
		_refresh_line_state(from_id, node.id)
		var line_in: BayterekConnection = get_line(from_id, node.id)
		if line_in:
			_update_wiggle_intensity(line_in)


func on_node_visual_offset_changed(node: BayterekNodeButton) -> void:
	if not is_instance_valid(node) or not node.node_data:
		return

	for to_id in node.node_data.out_nodes:
		var line: BayterekConnection = get_line(node.id, to_id)
		if line:
			_update_wiggle_intensity(line)
			_update_line_points(line)

	for from_id in node.node_data.in_nodes:
		var line: BayterekConnection = get_line(from_id, node.id)
		if line:
			_update_wiggle_intensity(line)
			_update_line_points(line)


## Refreshes the state-driven visuals of a single connection.
##
## IMPORTANT: When `state_color_enabled` is FALSE we do NOT touch
## `line.default_color`. The color always comes from the LineData via
## `_apply_line_data_visuals()`. When it's TRUE we write the state color
## AND `_apply_line_data_visuals()` skips the color assignment so it
## can't overwrite us on the next wiggle / motion tick.
func _refresh_line_state(from_id: int, to_id: int) -> void:
	var line: BayterekConnection = get_line(from_id, to_id)
	if not line:
		return

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(to_id)
	if not from_node or not to_node:
		return

	var from_active: bool = from_node.allocated or from_node.preallocated
	var to_active: bool = to_node.allocated or to_node.preallocated

	if _tree_data.multiallocation:
		if from_node.refund:
			from_active = from_node.allocation_level > 1
		if to_node.refund:
			to_active = to_node.allocation_level > 1

	var texture: Texture2D = null
	if from_active and to_active:
		texture = _tree_data.line_texture_active
	elif from_active or to_active:
		texture = _tree_data.line_texture_intermediate
	else:
		texture = _tree_data.line_texture_normal

	line.texture = texture

	# ------------------------------------------------------------------
	# STATE COLOR
	# ------------------------------------------------------------------
	# Only touch the color when the master toggle is explicitly ON.
	# When it's off, we NEVER write `line.default_color` here — the
	# color is always whatever `_apply_line_data_visuals()` set from
	# the LineData.
	if _tree_data.state_color_enabled:
		var is_alloc: bool = to_node.is_allocatable
		if to_active:
			line.default_color = _tree_data.default_line_color
		elif is_alloc:
			line.default_color = _tree_data.line_alloc_color
		else:
			line.default_color = _tree_data.line_non_alloc_color

	if not _tree_data.revealed and not from_active and not to_active:
		line.visible = false
	else:
		line.visible = true

# ============================================================
# WIGGLE INTENSITY (SPEED-BASED) + VELOCITY FORWARDING
# ============================================================

func _update_wiggle_intensity(line: BayterekConnection) -> void:
	if not is_instance_valid(line):
		return

	var data: BayterekLineData = line.line_data
	if not data or not data.wiggle_enabled:
		line.set_wiggle_intensity(0.0, false)
		return

	if _tree_data and not _tree_data.wiggle_enabled:
		line.set_wiggle_intensity(0.0, false)
		return

	const REFERENCE_SPEED := 0.30

	var from_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.from_id)
	var to_node: BayterekNodeButton = _tree_view.nodes_service.get_node(line.to_id)

	var from_speed: float = 0.0
	var to_speed: float = 0.0

	if from_node and is_instance_valid(from_node):
		from_speed = from_node.current_visual_speed
	if to_node and is_instance_valid(to_node):
		to_speed = to_node.current_visual_speed

	var peak_speed: float = maxf(from_speed, to_speed)

	var raw_intensity: float = 0.0
	if data.wiggle_use_hover_intensity:
		raw_intensity = peak_speed / REFERENCE_SPEED
	else:
		raw_intensity = 1.0 if peak_speed > 0.05 else 0.0

	raw_intensity = clampf(raw_intensity, 0.0, 2.0)

	var any_active: bool = false
	if from_node and (from_node.allocated or from_node.preallocated):
		any_active = true
	if to_node and (to_node.allocated or to_node.preallocated):
		any_active = true

	line.set_wiggle_intensity(raw_intensity, any_active)

	# --- Directional wiggle: send motion vector ---
	var motion_velocity: Vector2 = Vector2.ZERO
	if from_node and is_instance_valid(from_node):
		motion_velocity = from_node.current_visual_velocity
	if motion_velocity.length_squared() < 0.0001 and to_node and is_instance_valid(to_node):
		motion_velocity = to_node.current_visual_velocity

	line.set_wiggle_source_velocity(motion_velocity)

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

	var follow: bool = true
	if _tree_data:
		follow = _tree_data.wiggle_follow_node_animation

	var from_visual_offset: Vector2 = Vector2.ZERO
	if follow and from_node.has_method("get_visual_offset"):
		from_visual_offset = from_node.get_visual_offset()

	var to_visual_offset: Vector2 = Vector2.ZERO
	if follow and to_node.has_method("get_visual_offset"):
		to_visual_offset = to_node.get_visual_offset()

	var from_center: Vector2 = from_node.position + from_visual_offset + (from_node.size * 0.5)
	var to_center: Vector2 = to_node.position + to_visual_offset + (to_node.size * 0.5)

	var from_half: Vector2 = from_node.size * 0.5
	var to_half: Vector2 = to_node.size * 0.5

	var data: BayterekLineData = line.line_data
	if not data:
		data = BayterekLineData.new()

	var to_from_dir: Vector2 = to_center - from_center
	var dir_len: float = to_from_dir.length()
	var dir_norm: Vector2 = to_from_dir / dir_len if dir_len > 0.0001 else Vector2.RIGHT

	var has_start_arrow: bool = (data.start_arrow != BayterekLineData.ArrowStyle.NONE
		or data.arrow_texture_start != null)
	var has_end_arrow: bool = (data.end_arrow != BayterekLineData.ArrowStyle.NONE
		or data.arrow_texture_end != null)

	# Total offsets include the arrow backoff so the line stops BEFORE
	# the arrow tip.
	var start_total_offset: float = data.start_offset
	if has_start_arrow:
		start_total_offset += data.get_effective_start_backoff()

	var end_total_offset: float = data.end_offset
	if has_end_arrow:
		end_total_offset += data.get_effective_end_backoff()

	var p0: Vector2
	if has_start_arrow:
		p0 = _edge_point(from_center, to_center, from_half, start_total_offset)
	else:
		p0 = from_center + dir_norm * start_total_offset

	var p2: Vector2
	if has_end_arrow:
		p2 = _edge_point(to_center, from_center, to_half, end_total_offset)
	else:
		p2 = to_center - dir_norm * end_total_offset

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

	_apply_line_data_visuals(line, data)


## Applies the LineData visuals to the line.
##
## CRITICAL: When `tree.state_color_enabled` is true, this function does
## NOT touch `line.default_color`. The state color is owned entirely by
## `_refresh_line_state()`, and if we overwrote it here, every wiggle /
## motion tick would wipe the state color and the lines would revert to
## the neutral LineData color.
func _apply_line_data_visuals(line: BayterekConnection, data: BayterekLineData) -> void:
	if not is_instance_valid(line) or not data:
		return

	line.width = data.thickness

	# ------------------------------------------------------------------
	# COLOR — skip when state colors own the color.
	# ------------------------------------------------------------------
	if _tree_data and _tree_data.state_color_enabled:
		# State color is authoritative. Don't touch default_color here.
		pass
	else:
		line.default_color = data.color

	line.smooth_antialiasing = data.smooth_antialiasing
	line.flat_mode = data.flat_mode

	line.dash_style = data.line_style as BayterekLine2D.DashStyle
	line.dash_length = data.dash_length
	line.dash_gap = data.dash_gap
	line.dash_offset = data.dash_offset

	line.cap_start = data.cap_start as BayterekLine2D.CapStyle
	line.cap_end = data.cap_end as BayterekLine2D.CapStyle

	if data.texture_mode != BayterekLineData.TextureMode.NONE and data.line_texture != null:
		line.texture = data.line_texture
		line.texture_mode = data.texture_mode as BayterekLine2D.TextureMode
		line.texture_scale = data.texture_scale
		line.texture_tint = data.texture_tint
	else:
		line.texture = null
		line.texture_mode = BayterekLine2D.TextureMode.NONE

	line.start_arrow = data.start_arrow as BayterekLine2D.ArrowStyle
	line.end_arrow = data.end_arrow as BayterekLine2D.ArrowStyle
	line.arrow_size = data.arrow_size
	line.arrow_texture_start = data.arrow_texture_start
	line.arrow_texture_end = data.arrow_texture_end
	line.arrow_scale = data.arrow_scale
	line.arrow_tint = data.arrow_tint
	line.arrow_offset_x = data.arrow_offset_x

	line.wiggle_base_amplitude = data.wiggle_base_amplitude
	line.wiggle_frequency = data.wiggle_frequency
	line.wiggle_speed = data.wiggle_speed
	line.wiggle_phase_offset = data.wiggle_phase_offset
	line.wiggle_pattern = data.wiggle_pattern as BayterekLine2D.WigglePattern
	line.wiggle_random_seed = data.wiggle_random_seed
	line.wiggle_active_boost = data.wiggle_active_boost
	line.wiggle_direction_mode = data.wiggle_direction_mode as BayterekLine2D.WiggleDirectionMode

	var should_wiggle: bool = data.wiggle_enabled
	line.set_wiggle_enabled(should_wiggle)

	if should_wiggle:
		_update_wiggle_intensity(line)


func _edge_point(source_center: Vector2, target_center: Vector2, half_extents: Vector2, padding: float = 0.0) -> Vector2:
	var dir: Vector2 = target_center - source_center
	if dir.length_squared() < 0.0001:
		return source_center

	var expanded_half: Vector2 = half_extents + Vector2(padding, padding)

	var t_x: float = INF
	var t_y: float = INF

	if absf(dir.x) > 0.0001:
		t_x = expanded_half.x / absf(dir.x)

	if absf(dir.y) > 0.0001:
		t_y = expanded_half.y / absf(dir.y)

	var t: float = min(t_x, t_y)

	return source_center + dir * t

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

func _step_points(p0: Vector2, p2: Vector2, data: BayterekLineData) -> PackedVector2Array:
	var pts := PackedVector2Array()

	var dx: float = p2.x - p0.x
	var dy: float = p2.y - p0.y

	var step: float = max(8.0, data.step_distance)

	if absf(dx) >= absf(dy):
		var mid_x: float = p0.x + signf(dx) * min(step, absf(dx) * 0.5)

		pts.push_back(p0)
		pts.push_back(Vector2(mid_x, p0.y))
		pts.push_back(Vector2(mid_x, p2.y))
		pts.push_back(p2)
	else:
		var mid_y: float = p0.y + signf(dy) * min(step, absf(dy) * 0.5)

		pts.push_back(p0)
		pts.push_back(Vector2(p0.x, mid_y))
		pts.push_back(Vector2(p2.x, mid_y))
		pts.push_back(p2)

	return pts

func _key(from_id: int, to_id: int) -> String:
	return "%d_%d" % [from_id, to_id]