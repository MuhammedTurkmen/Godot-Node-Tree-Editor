@tool
class_name BayterekNodeButton
extends BaseButton
## On-canvas visual representation of a node.
##
## Two-layer structure:
##   BayterekNodeButton (Control)     ← hitbox. position is STABLE.
##     ├── VisualRoot (Control)       ← animations move this, NOT the outer node.
##     │     ├── TextureLayerRoot     ← normal texture layers live here
##     │     ├── SelectBorder
##     │     └── Crown
##     └── AbsoluteLayerRoot (Node2D) ← ABSOLUTE layers live here, outside
##                                       VisualRoot, so they are NOT affected
##                                       by hover/animations.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const RENDER_MODE_VECTOR := 0
const RENDER_MODE_PIXEL := 1

## Below this distance (in pixels), a visual offset change is considered
## insignificant and does NOT emit `visual_offset_changed`.
const VISUAL_OFFSET_EMIT_THRESHOLD := 0.05

## Below this smoothed speed (pixels/frame), the node is considered
## "stopped" and current_visual_speed is FORCED to exactly 0.
const SPEED_IDLE_THRESHOLD := 0.02

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)
signal drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal drag_ended(node: BayterekNodeButton)
signal right_clicked(node: BayterekNodeButton, screen_pos: Vector2)
signal visual_offset_changed(node: BayterekNodeButton, offset: Vector2, distance: float)

var node_data: BayterekNode
var prefab: BayterekPrefab
var tree_data: BayterekTree

var is_mouse_over: bool = false
var is_clicked: bool = false
var selected: bool = false

var allocated: bool = false
var preallocated: bool = false
var refund: bool = false
var allocation_level: int = 0
var state: Bayterek.AllocationState = Bayterek.AllocationState.NORMAL

var is_allocatable: bool = false

var current_visual_distance: float = 0.0
var current_visual_speed: float = 0.0
var current_visual_velocity: Vector2 = Vector2.ZERO

var _previous_visual_offset: Vector2 = Vector2.ZERO
var _was_moving: bool = false

var node_rotation: float:
	get: return node_data.node_rotation if node_data else 0.0
	set(v):
		if node_data:
			node_data.node_rotation = v

var node_skew: Vector2:
	get: return node_data.node_skew if node_data else Vector2.ZERO
	set(v):
		if node_data:
			node_data.node_skew = v

# --- Two-layer UI ---
var _visual_root: Control             # animations target this
var _select_border: Panel
var _crown_label: Label
var _texture_layer_root: Node2D

## Absolute layer root — outside VisualRoot. Layers flagged `absolute` live
## here so they stay in place during hover/rotate animations.
var _absolute_layer_root: Node2D

## Normal layers (under VisualRoot).
var _layer_nodes: Dictionary = {}

## Absolute layers (under AbsoluteLayerRoot, outside VisualRoot).
var _absolute_layer_nodes: Dictionary = {}

var _animator: BayterekNodeAnimator = null

var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO

var _active_states: Dictionary = {}
var _design_applied: bool = false

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

var is_decoration: bool:
	get: return node_data.is_decoration if node_data else false
	set(v): if node_data: node_data.is_decoration = v

var position_data: Vector2:
	get: return node_data.position if node_data else Vector2.ZERO
	set(v): if node_data: node_data.position = v

var design_id: String:
	get: return node_data.design_id if node_data else ""
	set(v):
		if node_data:
			node_data.design_id = v
			rebuild_from_design()

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_children()
	_build_animator()

	set_process(true)


func _process(_delta: float) -> void:
	# ------------------------------------------------------------------
	# SPEED + VELOCITY TRACKING (with hard-zero snap)
	# ------------------------------------------------------------------
	var current_offset: Vector2 = _visual_root.position if _visual_root else Vector2.ZERO
	var frame_delta: Vector2 = current_offset - _previous_visual_offset
	_previous_visual_offset = current_offset

	var instant_speed: float = frame_delta.length()

	if instant_speed < SPEED_IDLE_THRESHOLD:
		current_visual_speed = 0.0
		current_visual_velocity = Vector2.ZERO
	else:
		current_visual_speed = lerpf(current_visual_speed, instant_speed, 0.5)
		current_visual_velocity = current_visual_velocity.lerp(frame_delta, 0.5)

		if current_visual_speed < SPEED_IDLE_THRESHOLD:
			current_visual_speed = 0.0
			current_visual_velocity = Vector2.ZERO

	current_visual_distance = current_offset.length()

	var is_moving_now: bool = current_visual_speed > 0.0

	if is_moving_now:
		visual_offset_changed.emit(self, current_offset, current_visual_distance)
		_was_moving = true
	elif _was_moving:
		visual_offset_changed.emit(self, current_offset, current_visual_distance)
		_was_moving = false


func _build_children() -> void:
	# --- VisualRoot (animation target) ---
	_visual_root = Control.new()
	_visual_root.name = "VisualRoot"
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visual_root)

	# --- Normal texture layers (under VisualRoot) ---
	_texture_layer_root = Node2D.new()
	_texture_layer_root.name = "TextureLayerRoot"
	_visual_root.add_child(_texture_layer_root)

	# --- Absolute layer root (OUTSIDE VisualRoot) ---
	# Absolute layers go here so they don't get moved by hover/rotate
	# animations applied to VisualRoot.
	_absolute_layer_root = Node2D.new()
	_absolute_layer_root.name = "AbsoluteLayerRoot"
	add_child(_absolute_layer_root)

	# --- Selection border ---
	_select_border = Panel.new()
	_select_border.name = "SelectBorder"
	_select_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_border.offset_left = -Bayterek.SELECTION_BORDER_OFFSET
	_select_border.offset_top = -Bayterek.SELECTION_BORDER_OFFSET
	_select_border.offset_right = Bayterek.SELECTION_BORDER_OFFSET
	_select_border.offset_bottom = Bayterek.SELECTION_BORDER_OFFSET

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Bayterek.SELECTION_BORDER_COLOR
	style.set_border_width_all(Bayterek.SELECTION_BORDER_WIDTH)
	style.set_corner_radius_all(Bayterek.SELECTION_BORDER_RADIUS)
	_select_border.add_theme_stylebox_override("panel", style)
	_select_border.visible = false
	_visual_root.add_child(_select_border)

	# --- Crown label ---
	_crown_label = Label.new()
	_crown_label.name = "Crown"
	_crown_label.text = "👑"
	_crown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crown_label.add_theme_color_override("font_color", Bayterek.CROWN_COLOR)
	_crown_label.add_theme_color_override("font_outline_color", Bayterek.CROWN_OUTLINE_COLOR)
	_crown_label.add_theme_constant_override("outline_size", Bayterek.CROWN_OUTLINE_SIZE)
	_crown_label.add_theme_font_size_override("font_size", Bayterek.CROWN_FONT_SIZE)
	_crown_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_crown_label.offset_left = -20
	_crown_label.offset_top = -30
	_crown_label.offset_right = 20
	_crown_label.offset_bottom = -6
	_crown_label.visible = false
	_visual_root.add_child(_crown_label)

func _build_animator() -> void:
	if _animator and is_instance_valid(_animator):
		return
	_animator = BayterekNodeAnimator.new()
	_animator.name = "Animator"
	add_child(_animator)
	_animator.bind(self)

# ============================================================
# ANIMATION API
# ============================================================

func play_animation(preset_name: String, opts: Dictionary = {}) -> Tween:
	if not _animator:
		return null
	return _animator.play(preset_name, opts)

func stop_animation() -> void:
	if _animator:
		_animator.cancel()

func is_animating() -> bool:
	return _animator != null and _animator.is_playing()

func get_animator() -> BayterekNodeAnimator:
	return _animator

# ============================================================
# VISUAL TRANSFORM API
# ============================================================

func set_visual_offset(offset: Vector2) -> void:
	if not _visual_root:
		return
	_visual_root.position = offset

func get_visual_offset() -> Vector2:
	return _visual_root.position if _visual_root else Vector2.ZERO

func set_visual_rotation(deg: float) -> void:
	if not _visual_root:
		return
	_visual_root.pivot_offset = _visual_root.size * 0.5
	_visual_root.rotation = deg_to_rad(deg)

func get_visual_rotation() -> float:
	return rad_to_deg(_visual_root.rotation) if _visual_root else 0.0

func set_visual_scale(v: Vector2) -> void:
	if v.x <= 0.0:
		v.x = 0.01
	if v.y <= 0.0:
		v.y = 0.01

	if node_data:
		node_data.scale = v

	if _visual_root:
		_visual_root.pivot_offset = _visual_root.size * 0.5
		_visual_root.scale = v

func get_visual_scale() -> Vector2:
	return _visual_root.scale if _visual_root else Vector2.ONE

func reset_visual_transform() -> void:
	if not _visual_root:
		return
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation = 0.0
	_visual_root.scale = node_data.scale if node_data else Vector2.ONE

# ============================================================
# NODE TRANSFORM HELPERS
# ============================================================

func _build_node_transform() -> Transform2D:
	var t := Transform2D.IDENTITY

	var sx_skew: float = tan(deg_to_rad(node_skew.x))
	var sy_skew: float = tan(deg_to_rad(node_skew.y))
	if absf(sx_skew) > 0.0001 or absf(sy_skew) > 0.0001:
		var skew_matrix := Transform2D(
			Vector2(1.0, sy_skew),
			Vector2(sx_skew, 1.0),
			Vector2.ZERO
		)
		t = t * skew_matrix

	if absf(node_rotation) > 0.0001:
		t = t.rotated(deg_to_rad(node_rotation))

	return t

func _transform_around(node_transform: Transform2D, pivot: Vector2) -> Transform2D:
	return Transform2D(
		node_transform.x,
		node_transform.y,
		pivot - (node_transform * pivot) + node_transform.origin
	)

func refresh_transform() -> void:
	_update_layer_nodes()
	queue_redraw()

# ============================================================
# STATE RESOLUTION
# ============================================================

func _recompute_active_states() -> void:
	if not node_data:
		_active_states = {}
		return

	var flags: Dictionary = {
		"is_hovered": is_mouse_over,
		"is_clicked": is_clicked,
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

	if not _design_applied:
		_design_applied = true
		if not node_data.design_id.is_empty():
			var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(node_data.design_id)
			if design:
				node_data.apply_exported_overrides(design, prefab)

	_sync_size_with_design()
	_recompute_active_states()
	_apply_texture_filter()

	if _crown_label:
		_crown_label.visible = node_data.is_root

	if _select_border:
		_select_border.visible = selected

	_rebuild_layer_nodes()
	queue_redraw()

func rebuild_from_design() -> void:
	_design_applied = false
	refresh_visuals()

func refresh_hover_only() -> void:
	if not node_data:
		return
	_recompute_active_states()
	_update_layer_nodes()
	queue_redraw()

func refresh_selection_only() -> void:
	if _select_border:
		_select_border.visible = selected

func refresh_state_only() -> void:
	if not node_data:
		return
	_recompute_active_states()
	_update_layer_nodes()
	queue_redraw()

func _apply_texture_filter() -> void:
	if not node_data:
		return

	if tree_data:
		texture_filter = tree_data.get_godot_texture_filter()
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _sync_size_with_design() -> void:
	if not node_data:
		return

	var visual_bounds: Rect2 = node_data.get_visual_bounds()
	var target: Vector2 = visual_bounds.size

	if target.x <= 0.0 or target.y <= 0.0:
		target = node_data.design_size
	if target.x <= 0.0 or target.y <= 0.0:
		target = Vector2(100, 100)

	if size != target:
		size = target
	if custom_minimum_size != target:
		custom_minimum_size = target

	if _visual_root:
		_visual_root.position = Vector2.ZERO
		_visual_root.size = target
		_visual_root.custom_minimum_size = target
		_visual_root.pivot_offset = target * 0.5
		_visual_root.scale = node_data.scale

func set_state(new_state: Bayterek.AllocationState) -> void:
	state = new_state
	refresh_state_only()

func set_selected(value: bool) -> void:
	selected = value
	refresh_selection_only()

# ============================================================
# LAYER NODES
# ============================================================

func _rebuild_layer_nodes() -> void:
	if not node_data:
		_clear_all_layer_nodes()
		return

	# --- Step 1: figure out which layers should exist in each bucket. ---
	var desired_normal_ids: Dictionary = {}
	var desired_absolute_ids: Dictionary = {}

	for layer in node_data.layers:
		if not layer or not layer.visible:
			continue
		if not (layer is BayterekTextureLayer):
			continue
		if layer.absolute:
			desired_absolute_ids[layer.layer_id] = true
		else:
			desired_normal_ids[layer.layer_id] = true

	# --- Step 2: remove stale layer nodes. ---
	_remove_stale_layer_nodes(_layer_nodes, desired_normal_ids)
	_remove_stale_layer_nodes(_absolute_layer_nodes, desired_absolute_ids)

	# --- Step 3: (re)create layer nodes as needed. ---
	for layer in node_data.layers:
		if not layer or not layer.visible:
			continue
		if not (layer is BayterekTextureLayer):
			continue

		var bucket: Dictionary = _absolute_layer_nodes if layer.absolute else _layer_nodes
		var parent: Node2D = _absolute_layer_root if layer.absolute else _texture_layer_root

		var ln: BayterekLayerNode = bucket.get(layer.layer_id, null)
		if not ln or not is_instance_valid(ln):
			ln = BayterekLayerNode.new()
			ln.name = "LayerNode_%s" % layer.layer_id
			parent.add_child(ln)
			bucket[layer.layer_id] = ln

		ln.set_layer(layer)

	_update_layer_nodes()


func _remove_stale_layer_nodes(bucket: Dictionary, desired: Dictionary) -> void:
	var to_remove: Array = []
	for layer_id in bucket.keys():
		if desired.has(layer_id):
			continue
		var ln: BayterekLayerNode = bucket[layer_id]
		if is_instance_valid(ln):
			ln.queue_free()
		to_remove.append(layer_id)
	for layer_id in to_remove:
		bucket.erase(layer_id)


func _clear_all_layer_nodes() -> void:
	for ln in _layer_nodes.values():
		if is_instance_valid(ln):
			ln.queue_free()
	_layer_nodes.clear()

	for ln in _absolute_layer_nodes.values():
		if is_instance_valid(ln):
			ln.queue_free()
	_absolute_layer_nodes.clear()


func _update_layer_nodes() -> void:
	if not node_data:
		return

	var design_size: Vector2 = node_data.design_size

	var visual_bounds: Rect2 = node_data.get_visual_bounds()
	var bounds_center: Vector2 = visual_bounds.position + visual_bounds.size * 0.5

	var root_size: Vector2 = _visual_root.size if _visual_root else size
	var root_center: Vector2 = root_size * 0.5

	# --- Base transform for NORMAL layers ---
	# Normal layers live under VisualRoot, so the parent's animation offset
	# is already applied on top of this transform.
	var base_xform := Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		root_center - bounds_center
	)

	var node_transform: Transform2D = _build_node_transform()
	var transform_with_center := _transform_around(node_transform, root_center)
	var base_xform_with_node = transform_with_center * base_xform

	# --- Base transform for ABSOLUTE layers ---
	# Absolute layers live OUTSIDE VisualRoot, so they see NONE of the
	# animation (no offset, no rotation, no scale). We intentionally
	# skip the node transform too so they truly stay put.
	var absolute_xform := Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		root_center - bounds_center
	)

	# --- Normal layers ---
	for layer_id in _layer_nodes.keys():
		var ln: BayterekLayerNode = _layer_nodes[layer_id]
		if not is_instance_valid(ln):
			continue
		var layer: BayterekTextureLayer = ln.layer
		if not layer:
			continue

		var state_key: String = layer.get_visual_state(_active_states)
		ln.set_state(state_key)

		var effective_mode: int = layer.get_effective_render_mode()
		var pixel_mode: bool = effective_mode == RENDER_MODE_PIXEL

		ln.update(design_size, pixel_mode)
		ln.transform = base_xform_with_node * layer.get_matrix(design_size, pixel_mode)

		var layer_index: int = node_data.layers.find(layer)
		if layer_index < 0:
			layer_index = 0
		ln.z_index = layer_index

	# --- Absolute layers ---
	for layer_id in _absolute_layer_nodes.keys():
		var ln: BayterekLayerNode = _absolute_layer_nodes[layer_id]
		if not is_instance_valid(ln):
			continue
		var layer: BayterekTextureLayer = ln.layer
		if not layer:
			continue

		var state_key: String = layer.get_visual_state(_active_states)
		ln.set_state(state_key)

		var effective_mode: int = layer.get_effective_render_mode()
		var pixel_mode: bool = effective_mode == RENDER_MODE_PIXEL

		ln.update(design_size, pixel_mode)
		ln.transform = absolute_xform * layer.get_matrix(design_size, pixel_mode)

		var layer_index: int = node_data.layers.find(layer)
		if layer_index < 0:
			layer_index = 0
		ln.z_index = layer_index

# ============================================================
# DRAW
# ============================================================

func _draw() -> void:
	pass

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
				if not is_clicked:
					is_clicked = true
					refresh_hover_only()
				accept_event()
			else:
				if is_clicked:
					is_clicked = false
					refresh_hover_only()
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
	refresh_hover_only()
	node_hovered.emit(self, true)

func _on_mouse_exited() -> void:
	is_mouse_over = false
	if is_clicked:
		is_clicked = false
	refresh_hover_only()
	node_hovered.emit(self, false)

# ============================================================
# TOOLTIP
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