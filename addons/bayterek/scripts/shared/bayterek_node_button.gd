@tool
class_name BayterekNodeButton
extends BaseButton
## On-canvas visual representation of a node.
## Renders all layers via custom _draw(). Crown and selection frame
## are kept as child controls.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)
signal drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal drag_ended(node: BayterekNodeButton)
signal right_clicked(node: BayterekNodeButton, screen_pos: Vector2)

var node_data: BayterekNode
var prefab: BayterekPrefab
var tree_data: BayterekTree

var is_mouse_over: bool = false
var selected: bool = false

var allocated: bool = false
var preallocated: bool = false
var refund: bool = false
var allocation_level: int = 0
var state: Bayterek.AllocationState = Bayterek.AllocationState.NORMAL

var is_allocatable: bool = false

# --- Child controls ---
var _select_border: Panel
var _crown_label: Label

var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO

var _active_states: Dictionary = {}

var id: int:
	get: return node_data.id if node_data else -1
	set(v): if node_data: node_data.id = v

var is_root: bool:
	get: return node_data.is_root if node_data else false
	set(v):
		if node_data:
			node_data.is_root = v
			refresh_visuals()

var node_name: String:
	get: return node_data.name if node_data else ""
	set(v): if node_data: node_data.name = v

var description: String:
	get: return node_data.description if node_data else ""
	set(v): if node_data: node_data.description = v

var type: BayterekNode.NodeType:
	get: return node_data.type if node_data else BayterekNode.NodeType.SMALL
	set(v): if node_data: node_data.type = v

var position_data: Vector2:
	get: return node_data.position if node_data else Vector2.ZERO
	set(v): if node_data: node_data.position = v

var design_id: String:
	get: return node_data.design_id if node_data else ""
	set(v):
		if node_data:
			node_data.design_id = v
			refresh_visuals()

func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_children()

func _build_children() -> void:
	_select_border = Panel.new()
	_select_border.name = "SelectBorder"
	_select_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_border.offset_left = -3
	_select_border.offset_top = -3
	_select_border.offset_right = 3
	_select_border.offset_bottom = 3

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1, 0.6, 0.1, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	_select_border.add_theme_stylebox_override("panel", style)
	_select_border.visible = false
	add_child(_select_border)

	_crown_label = Label.new()
	_crown_label.name = "Crown"
	_crown_label.text = "👑"
	_crown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_crown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_crown_label.add_theme_constant_override("outline_size", 2)
	_crown_label.add_theme_font_size_override("font_size", 18)
	_crown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_crown_label.offset_left = -20
	_crown_label.offset_top = -30
	_crown_label.offset_right = 20
	_crown_label.offset_bottom = -6
	_crown_label.visible = false
	add_child(_crown_label)

# ============================================================
# STATE RESOLUTION
# ============================================================

func _recompute_active_states() -> void:
	if not node_data:
		_active_states = {}
		return

	var flags: Dictionary = {
		"is_hovered": is_mouse_over,
		"allocated": allocated,
		"preallocated": preallocated,
		"refund": refund,
		"allocation_level": allocation_level,
		"is_allocatable": is_allocatable,
	}
	_active_states = node_data.resolve_active_states(flags)

# ============================================================
# VISUAL REFRESH
# ============================================================

func refresh_visuals() -> void:
	if not node_data:
		return

	_recompute_active_states()

	if _crown_label:
		_crown_label.visible = node_data.is_root

	if _select_border:
		_select_border.visible = selected

	queue_redraw()

func set_state(new_state: Bayterek.AllocationState) -> void:
	state = new_state
	refresh_visuals()

func set_selected(value: bool) -> void:
	selected = value
	if _select_border:
		_select_border.visible = value

# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	if not node_data:
		return

	var design_size: Vector2 = node_data.design_size
	var node_scale: Vector2 = node_data.scale

	var scale_transform := Transform2D(
		Vector2(node_scale.x, 0.0),
		Vector2(0.0, node_scale.y),
		design_size * 0.5 * node_scale
	)

	for layer in node_data.layers:
		if not layer or not layer.visible:
			continue
		_draw_layer(layer, design_size, scale_transform)

func _draw_layer(layer: BayterekLayer, design_size: Vector2, base_xform: Transform2D) -> void:
	var state_key: String = layer.get_visual_state(_active_states)
	var layer_matrix: Transform2D = layer.get_matrix(design_size)
	var effective_size: Vector2 = layer.get_size(design_size)

	if layer is BayterekShapeLayer:
		_draw_shape_layer(layer, state_key, effective_size, layer_matrix, base_xform)
	elif layer is BayterekTextureLayer:
		_draw_texture_layer(layer, state_key, effective_size, layer_matrix, base_xform)

# ============================================================
# SHAPE DRAWING
# ============================================================

func _draw_shape_layer(
	layer: BayterekShapeLayer,
	state_key: String,
	effective_size: Vector2,
	layer_matrix: Transform2D,
	base_xform: Transform2D
) -> void:
	var combined: Transform2D = base_xform * layer_matrix

	# --- Shadow (based on full outline) ---
	if layer.shadow_enabled and layer.shadow_color.a > 0.0:
		var full_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size)
		if not full_verts.is_empty():
			_draw_shape_shadow(layer, full_verts, combined)

	var draw_border: bool = layer.should_draw_border(state_key)
	var draw_fill: bool = layer.should_draw_fill(state_key)

	# --- Border ---
	if draw_border:
		var border_color: Color = layer.get_border_color_for_state(state_key)
		if border_color.a > 0.0 and layer.border_width > 0.0:
			var outer_verts: PackedVector2Array = layer.get_polygon_vertices(effective_size)
			if not outer_verts.is_empty():
				_draw_shape_border(outer_verts, combined, border_color, layer.border_width)

	# --- Fill on top (covers the inner half of the border) ---
	if draw_fill:
		var fill_color: Color = layer.get_fill_color_for_state(state_key)
		if fill_color.a > 0.0:
			var verts: PackedVector2Array = layer.get_fill_vertices(effective_size)
			if verts.is_empty():
				verts = layer.get_polygon_vertices(effective_size)
			if not verts.is_empty():
				_draw_shape_fill(verts, combined, fill_color)

func _draw_shape_fill(verts: PackedVector2Array, xform: Transform2D, color: Color) -> void:
	var transformed := PackedVector2Array()
	transformed.resize(verts.size())
	for i in verts.size():
		transformed[i] = xform * verts[i]
	draw_colored_polygon(transformed, color)

## Draws the border as a thick polyline centered on the outline.
## Line width stays constant along the whole path, including on rounded
## corners — unlike a quad-strip ring, which doubles up at arc joins.
## The inner half of the stroke will be covered by the fill drawn on top.
func _draw_shape_border(verts: PackedVector2Array, xform: Transform2D, color: Color, width: float) -> void:
	if verts.size() < 2:
		return

	var pts := PackedVector2Array()
	pts.resize(verts.size() + 1)
	for i in verts.size():
		pts[i] = xform * verts[i]
	pts[verts.size()] = pts[0]

	# Double the width because polyline is centered: outer half visible,
	# inner half is hidden under the fill.
	draw_polyline(pts, color, width * 2.0, true)

## Draws the shadow with optional multi-pass blur.
func _draw_shape_shadow(layer: BayterekShapeLayer, verts: PackedVector2Array, xform: Transform2D) -> void:
	var offset: Vector2 = layer.shadow_size
	var blur: float = layer.shadow_blur
	var base_color: Color = layer.shadow_color

	if blur <= 0.01:
		var shadow_xform := Transform2D(xform.x, xform.y, xform.origin + offset)
		_draw_shape_fill(verts, shadow_xform, base_color)
		return

	var passes: int = 4
	var alpha_per_pass: float = base_color.a / float(passes)
	var color_per_pass := Color(base_color.r, base_color.g, base_color.b, alpha_per_pass)

	var dir: Vector2 = offset
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
	else:
		dir = Vector2.ZERO

	for i in passes:
		var spread: float = blur * (float(i) / float(passes - 1))
		var pass_offset: Vector2 = offset - dir * spread * 0.5
		var expanded: PackedVector2Array = _expand_verts(verts, spread)

		var shadow_xform := Transform2D(xform.x, xform.y, xform.origin + pass_offset)
		_draw_shape_fill(expanded, shadow_xform, color_per_pass)

## Offsets each vertex outward from center by `offset`. Used for shadow blur.
func _expand_verts(verts: PackedVector2Array, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(verts.size())
	for i in verts.size():
		var v: Vector2 = verts[i]
		var dir: Vector2 = v
		if dir.length_squared() > 0.0001:
			dir = dir.normalized()
		out[i] = v + dir * offset
	return out

# ============================================================
# TEXTURE DRAWING
# ============================================================

func _draw_texture_layer(
	layer: BayterekTextureLayer,
	state_key: String,
	effective_size: Vector2,
	layer_matrix: Transform2D,
	base_xform: Transform2D
) -> void:
	if not layer.should_draw_icon(state_key):
		return

	var tex: Texture2D = layer.get_icon_for_state(state_key)
	if not tex:
		return

	var tint: Color = layer.get_tint_for_state(state_key)
	var combined: Transform2D = base_xform * layer_matrix

	draw_set_transform_matrix(combined)
	draw_texture_rect(tex, Rect2(-effective_size * 0.5, effective_size), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# ============================================================
# INPUT / DRAG
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_is_dragging = false
				accept_event()
			else:
				if _is_dragging:
					drag_ended.emit(self)
					_is_dragging = false
				else:
					pressed.emit()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var global_pos: Vector2 = get_global_transform() * event.position
			right_clicked.emit(self, global_pos)
			accept_event()

	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _is_dragging:
			if event.position.distance_to(_press_pos) > 4.0:
				_is_dragging = true
				var screen_pos: Vector2 = get_global_transform() * event.position
				drag_started.emit(self, screen_pos)
		if _is_dragging:
			var screen_pos: Vector2 = get_global_transform() * event.position
			dragged.emit(self, screen_pos)
			accept_event()

func _on_mouse_entered() -> void:
	is_mouse_over = true
	refresh_visuals()
	node_hovered.emit(self, true)

func _on_mouse_exited() -> void:
	is_mouse_over = false
	refresh_visuals()
	node_hovered.emit(self, false)

# ============================================================
# TOOLTIP FORMATTING
# ============================================================

func format_tooltip_sections() -> Dictionary:
	var header: String = ""
	var body: String = ""
	var footer: String = ""

	if not node_data:
		return {"header": "", "body": "", "footer": ""}

	var display_name: String = node_name
	if display_name.is_empty():
		display_name = "Node %d" % id
	header = "[b][color=#f9e6ca]%s[/color][/b]" % display_name

	var body_parts: Array[String] = []

	if not node_data.is_root and node_data.prerequisite_mode != BayterekNode.PrerequisiteMode.ANY:
		var mode_text: String = ""
		match node_data.prerequisite_mode:
			BayterekNode.PrerequisiteMode.COUNT:
				mode_text = "Requires: %d incoming active" % node_data.prerequisite_count
			BayterekNode.PrerequisiteMode.ALL:
				mode_text = "Requires: all incoming active"
		if not mode_text.is_empty():
			body_parts.append("[color=#c9a227]%s[/color]" % mode_text)

	var attrs_text: String = _format_attributes()
	if not attrs_text.is_empty():
		body_parts.append(attrs_text)

	if not node_data.description.is_empty():
		body_parts.append("[color=orange]%s[/color]" % node_data.description)

	body = "\n\n".join(body_parts)
	footer = _format_level_footer()

	return {"header": header, "body": body, "footer": footer}

func _format_level_footer() -> String:
	if not node_data:
		return ""

	var current: int = allocation_level
	var maximum: int = 1

	if _is_multiallocation():
		maximum = node_data.max_allocations
		current = allocation_level
	else:
		maximum = 1
		current = 1 if allocated else 0

	var color: String = "#a0a0a0"
	if maximum > 0 and current >= maximum:
		color = "#ffd766"
	elif current > 0:
		color = "#8ef58e"

	return "[center][color=%s]Level: %d / %d[/color][/center]" % [color, current, maximum]

func format_tooltip() -> String:
	var sections: Dictionary = format_tooltip_sections()
	var parts: Array[String] = []
	if not sections["header"].is_empty():
		parts.append(sections["header"])
	if not sections["body"].is_empty():
		parts.append(sections["body"])
	if not sections["footer"].is_empty():
		parts.append(sections["footer"])
	return "\n\n".join(parts)

func _is_multiallocation() -> bool:
	if not tree_data:
		return false
	return tree_data.multiallocation

func _format_attributes() -> String:
	if not node_data or not tree_data:
		return ""

	var result: String = ""
	var regex := RegEx.new()
	regex.compile("#")

	for attr_id in node_data.attributes.keys():
		if not tree_data.attributes.has(attr_id):
			continue
		var attribute: BayterekAttribute = tree_data.attributes[attr_id]
		result += _format_single_attribute(regex, attribute, attr_id)
		result += "\n"

	return result.strip_edges()

func _format_single_attribute(regex: RegEx, attribute: BayterekAttribute, attr_id: String) -> String:
	var formatted: String = ""

	if _is_multiallocation():
		if allocation_level > 0:
			formatted = attribute.effect
			var level_index: int = max(0, allocation_level - 1)
			var raw = node_data.attributes[attr_id]
			if raw is Array and level_index < raw.size():
				var values = raw[level_index]
				if values is Array:
					for i in attribute.value_count:
						if i < values.size():
							formatted = regex.sub(formatted, str(values[i]))

		if allocation_level < node_data.max_allocations:
			var next_level: int = allocation_level
			var next_text: String = attribute.effect
			var raw2 = node_data.attributes[attr_id]
			if raw2 is Array and next_level < raw2.size():
				var next_values = raw2[next_level]
				if next_values is Array:
					for i in attribute.value_count:
						if i < next_values.size():
							next_text = regex.sub(next_text, str(next_values[i]))
			formatted += "\n[color=orange]Next Level: %s[/color]" % next_text.strip_edges()

		if allocation_level == 0:
			var first_text: String = attribute.effect
			var raw3 = node_data.attributes[attr_id]
			if raw3 is Array and raw3.size() > 0:
				var first_values = raw3[0]
				if first_values is Array:
					for i in attribute.value_count:
						if i < first_values.size():
							first_text = regex.sub(first_text, str(first_values[i]))
			formatted = "[color=orange]Next Level: %s[/color]" % first_text.strip_edges()
	else:
		formatted = attribute.effect
		var values = node_data.attributes[attr_id]
		if values is Array:
			for i in attribute.value_count:
				if i < values.size() and not values[i] is Array:
					formatted = regex.sub(formatted, str(values[i]))

	return "[color=#8a8aff]%s[/color]" % formatted