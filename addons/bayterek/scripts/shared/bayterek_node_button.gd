@tool
class_name BayterekNodeButton
extends BaseButton
## On-canvas visual representation of a node.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const RENDER_MODE_VECTOR := 0
const RENDER_MODE_PIXEL := 1

const VISUAL_OFFSET_EMIT_THRESHOLD := 0.05
const SPEED_IDLE_THRESHOLD := 0.02

const CURRENCY_MAX_PER_ROW := 3
const CURRENCY_FALLBACK_ICON := "💰"

const LOC_KEY_LEVEL := "bayterek_node_level"
const LOC_KEY_LEVEL_MAXED := "bayterek_node_level_maxed"

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)
signal drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal drag_ended(node: BayterekNodeButton)
signal right_clicked(node: BayterekNodeButton, screen_pos: Vector2)
signal visual_offset_changed(node: BayterekNodeButton, offset: Vector2, distance: float)

signal press_started(node: BayterekNodeButton, screen_pos: Vector2)
signal press_ended(node: BayterekNodeButton, screen_pos: Vector2)

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
var _visual_root: Control
var _select_border: Panel
var _crown_label: Label
var _texture_layer_root: Node2D

var _absolute_layer_root: Node2D

var _layer_nodes: Dictionary = {}
var _absolute_layer_nodes: Dictionary = {}

var _animator: BayterekNodeAnimator = null

var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO

var _active_states: Dictionary = {}
var _design_applied: bool = false

# --- Purchase progress (HOLD mode, NODE_PROGRESS visual) ---
var _progress_active: bool = false
var _progress_finished: bool = false
var _progress_cancelled: bool = false
var _progress_t: float = 0.0

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
	_visual_root = Control.new()
	_visual_root.name = "VisualRoot"
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visual_root)

	_texture_layer_root = Node2D.new()
	_texture_layer_root.name = "TextureLayerRoot"
	_visual_root.add_child(_texture_layer_root)

	_absolute_layer_root = Node2D.new()
	_absolute_layer_root.name = "AbsoluteLayerRoot"
	add_child(_absolute_layer_root)

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

	_remove_stale_layer_nodes(_layer_nodes, desired_normal_ids)
	_remove_stale_layer_nodes(_absolute_layer_nodes, desired_absolute_ids)

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


func _is_progress_layer(layer: BayterekTextureLayer) -> bool:
	if not layer or not node_data or not tree_data:
		return false
	if tree_data.purchase_visual_mode != 2:
		return false
	if node_data.node_progress_layer_id.is_empty():
		return false
	return layer.layer_id == node_data.node_progress_layer_id

func _is_progress_layer_visible_now() -> bool:
	if Engine.is_editor_hint():
		return false

	if _progress_active:
		return true
	if not tree_data:
		return false

	if _progress_finished:
		if _progress_cancelled:
			return tree_data.purchase_progress_direction == 1
		return false

	return tree_data.purchase_progress_direction == 1


func _render_layer_node(ln: BayterekLayerNode, base_xform: Transform2D) -> void:
	if not ln or not is_instance_valid(ln):
		return
	var layer: BayterekTextureLayer = ln.layer
	if not layer:
		return

	var design_size: Vector2 = node_data.design_size
	var effective_mode: int = layer.get_effective_render_mode()
	var pixel_mode: bool = effective_mode == RENDER_MODE_PIXEL

	var is_progress: bool = _is_progress_layer(layer)

	if is_progress:
		ln.visible = _is_progress_layer_visible_now()
	else:
		ln.visible = true

	var state_key: String = layer.get_visual_state(_active_states)
	ln.set_state(state_key)

	if is_progress and _progress_active:
		var live_xform: BayterekLayerTransform = layer.transform.duplicate_transform()
		var factor: float = _progress_t
		if tree_data.purchase_progress_direction == 1:
			factor = 1.0 - _progress_t

		var mode: int = 2
		if not node_data.design_id.is_empty():
			var design: BayterekNodeDesign = Bayterek.get_designs_registry().get_design_by_id(node_data.design_id)
			if design:
				mode = design.progress_layer_mode

		match mode:
			0:
				live_xform.scale.x = factor
			1:
				live_xform.scale.y = factor
			2:
				live_xform.scale = Vector2(factor, factor)
			3:
				live_xform.rotation += factor * 360.0
			4:
				live_xform.scale.y = factor

		ln.update_with_override(design_size, pixel_mode, live_xform)
		ln.transform = base_xform * live_xform.get_matrix(design_size, pixel_mode)
	else:
		ln.update(design_size, pixel_mode)
		ln.transform = base_xform * layer.get_matrix(design_size, pixel_mode)

	var layer_index: int = node_data.layers.find(layer)
	if layer_index < 0:
		layer_index = 0
	ln.z_index = layer_index


func _update_layer_nodes() -> void:
	if not node_data:
		return

	var visual_bounds: Rect2 = node_data.get_visual_bounds()
	var bounds_center: Vector2 = visual_bounds.position + visual_bounds.size * 0.5

	var root_size: Vector2 = _visual_root.size if _visual_root else size
	var root_center: Vector2 = root_size * 0.5

	var base_xform := Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		root_center - bounds_center
	)

	var node_transform: Transform2D = _build_node_transform()
	var transform_with_center := _transform_around(node_transform, root_center)
	var base_xform_with_node = transform_with_center * base_xform

	var absolute_xform := Transform2D(
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		root_center - bounds_center
	)

	for layer_id in _layer_nodes.keys():
		var ln: BayterekLayerNode = _layer_nodes[layer_id]
		if not is_instance_valid(ln):
			continue
		_render_layer_node(ln, base_xform_with_node)

	for layer_id in _absolute_layer_nodes.keys():
		var ln: BayterekLayerNode = _absolute_layer_nodes[layer_id]
		if not is_instance_valid(ln):
			continue
		_render_layer_node(ln, absolute_xform)

# ============================================================
# PURCHASE PROGRESS (HOLD mode)
# ============================================================

func set_purchase_progress(t: float) -> void:
	if not node_data or not tree_data:
		return
	if tree_data.purchase_visual_mode != 2:
		return
	if node_data.node_progress_layer_id.is_empty():
		return

	_progress_active = true
	_progress_finished = false
	_progress_cancelled = false
	_progress_t = clampf(t, 0.0, 1.0)
	_update_layer_nodes()

func clear_purchase_progress(completed: bool = false) -> void:
	_progress_active = false
	_progress_finished = true
	_progress_cancelled = not completed
	_progress_t = 0.0
	_update_layer_nodes()

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

	# RUNTIME: sol tık bas/bırak tamamen TreeView._input tarafından
	# yönetilir. Node kendi sinyallerini emit etmesin.
	# `_input` zaten `set_input_as_handled()` çağırdığı için bu blok
	# normalde çalışmaz, ama güvenlik için burada da koruyoruz.
	if not Engine.is_editor_hint():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_is_dragging = false
				if not is_clicked:
					is_clicked = true
					refresh_hover_only()
				var sp: Vector2 = get_global_transform() * event.position
				press_started.emit(self, sp)
				accept_event()
			else:
				if is_clicked:
					is_clicked = false
					refresh_hover_only()
				var sp2: Vector2 = get_global_transform() * event.position
				press_ended.emit(self, sp2)
				if _is_dragging:
					drag_ended.emit(self)
					_is_dragging = false
				else:
					pressed.emit()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Node üzerinde sağ tık: TreeView'ın menüyü açabilmesi için
			# RELEASE'te sinyal emit ediyoruz. Press/release'i accept
			# ETMİYORUZ ki event TreeView'a da ulaşsın (pan ve menü
			# filtresi için gerekli).
			if not event.pressed:
				var global_pos: Vector2 = get_global_transform() * event.position
				right_clicked.emit(self, global_pos)

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

	header = "[b][color=#f9e6ca]%s[/color][/b]" % get_display_name()

	var level_text: String = _format_level_text()
	var level_in_header: bool = tree_data != null and tree_data.level_in_header

	if level_in_header and not level_text.is_empty():
		header += "\n" + level_text

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

	# === ATTRIBUTE DESCRIPTIONS ===
	# node_data.description artık burada EKLENMİYOR. Sadece attribute
	# description'ları üretiliyor; node description fallback olarak
	# _format_attribute_descriptions() içinde kullanılıyor.
	var attrs_text: String = _format_attribute_descriptions()
	if not attrs_text.is_empty():
		body_parts.append(attrs_text)

	body = "\n\n".join(body_parts)

	if not level_in_header:
		footer = level_text

	return {
		"header": header,
		"body": body,
		"footer": footer,
	}

func get_display_name() -> String:
	if not node_data:
		return "Node ?"

	if not node_data.name_key.is_empty() and is_inside_tree():
		var loc = get_node_or_null("/root/GameLocalization")
		if loc and loc.has_method("get_raw_text"):
			var translated: String = String(loc.call("get_raw_text", node_data.name_key))
			if not translated.is_empty():
				return translated

	var fallback: String = node_data.name.strip_edges()
	if fallback.is_empty():
		fallback = "Node %d" % id
	return fallback

func _localize(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	if not is_inside_tree():
		return fallback

	var loc = get_node_or_null("/root/GameLocalization")
	if not loc or not loc.has_method("get_raw_text"):
		return fallback

	var translated: String = String(loc.call("get_raw_text", key))
	if translated.is_empty():
		return fallback
	return translated

func is_maxed() -> bool:
	if not node_data:
		return false
	if not _is_multiallocation():
		return allocated
	if node_data.max_allocations <= 0:
		return false
	return allocation_level >= node_data.max_allocations

func get_currency_entries() -> Array:
	if not node_data or not tree_data:
		return []

	if is_maxed():
		return []

	var result: Array = []
	for attr_id in node_data.attributes.keys():
		if not tree_data.attributes.has(attr_id):
			continue
		var attr: BayterekAttribute = tree_data.attributes[attr_id]
		if not attr or not attr.is_currency:
			continue

		var amount: int = node_data.get_currency_slot(
			attr_id,
			BayterekAttribute.SLOT_PURCHASE,
			allocation_level
		)
		result.append({
			"icon": attr.icon,
			"amount": amount,
			"affordable": _is_currency_affordable(attr_id, amount),
		})
	return result


func _is_currency_affordable(attr_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if not is_inside_tree():
		return true
	var tv = get_parent()
	while tv and not (tv is BayterekTreeView):
		tv = tv.get_parent()
	if not tv:
		return true
	var svc = (tv as BayterekTreeView).allocation_service
	if not svc:
		return true
	if not svc.wallet_can_afford.is_valid():
		return true
	return bool(svc.wallet_can_afford.call(attr_id, amount))

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

static func _is_cumulative_op(op: BayterekAttribute.Operation) -> bool:
	return op == BayterekAttribute.Operation.ADD \
		or op == BayterekAttribute.Operation.SUBTRACT

# ============================================================
# ATTRIBUTE DESCRIPTION FORMATTING (yeni)
# ============================================================

## Her non-currency attribute için ayrı description satırı üretir.
##
## Öncelik sırası (attribute başına):
##   1. attribute.effect_key varsa → GameLocalization.get_raw_text(effect_key)
##   2. attribute.effect doluysa → onu kullan
##   3. node_data.description doluysa → onu kullan (ortak fallback)
##   4. Hiçbiri yoksa → "{attr_name} next: {N0}" otomatik format
##
## Placeholder formatları:
##   {P}, {C}, {N}        → 0. slot
##   {P0}, {C0}, {N0}     → belirli slot index
##   {P1}, {C1}, {N1}     → 1. slot
##   {<attr_id>_p0}, ...  → belirli attribute + slot (örn: {max_health_c0})
##   {attr_name}          → attribute görünen adı
func _format_attribute_descriptions() -> String:
	if not node_data or not tree_data:
		return ""

	var lines: Array[String] = []

	# Aktif non-currency attribute id'leri (alfabetik — deterministik sıra)
	var active_attr_ids: Array[String] = []
	for attr_id in node_data.attributes.keys():
		if not tree_data.attributes.has(attr_id):
			continue
		var attr: BayterekAttribute = tree_data.attributes[attr_id]
		if not attr or attr.is_currency:
			continue
		active_attr_ids.append(attr_id)
	active_attr_ids.sort()

	# Node description fallback (tüm attribute'lar için ortak)
	var node_desc_fallback: String = node_data.description.strip_edges()

	for attr_id in active_attr_ids:
		var attribute: BayterekAttribute = tree_data.attributes[attr_id]
		if not attribute:
			continue

		# Description kaynağını belirle
		var raw_effect: String = _get_effect_text(attribute)

		if raw_effect.strip_edges().is_empty():
			if not node_desc_fallback.is_empty():
				raw_effect = node_desc_fallback
			else:
				# Son çare: otomatik format
				raw_effect = "{attr_name} next: {N0}"

		# {attr_name} → attribute görünen adı
		raw_effect = raw_effect.replace("{attr_name}", attribute.get_display_name())

		# Placeholder'ları doldur
		var formatted: String = _substitute_attribute_placeholders(raw_effect, attr_id, attribute)

		if formatted.strip_edges().is_empty():
			continue

		lines.append("[color=#8a8aff]%s[/color]" % formatted)

	return "\n".join(lines)


## Belirli bir attribute için {P}/{C}/{N} ve {P0}/{C0}/{N0} placeholder'larını
## o attribute'un kendi değerleriyle doldurur.
##
## Satın alınmamış node'larda {P} ve {C} otomatik olarak {N}'e dönüşür
## (yani tooltip "satın alırsan şu kadar" der).
func _substitute_attribute_placeholders(
	effect: String,
	attr_id: String,
	attribute: BayterekAttribute
) -> String:
	if effect.is_empty() or not attribute:
		return ""

	var normalized: String = effect.replace("\\n", "\n")

	var is_purchased: bool = allocated or allocation_level > 0

	# Level değerleri
	var previous_values: Array = _get_values_at_level(attr_id, allocation_level - 1)
	var current_values: Array = _get_values_at_level(attr_id, allocation_level)

	var next_level: int = allocation_level + 1
	if _is_multiallocation():
		var max_lvl: int = node_data.max_allocations if node_data else 0
		if max_lvl > 0 and next_level > max_lvl:
			next_level = max_lvl
	else:
		if next_level > 1:
			next_level = 1

	var next_values: Array = _get_values_at_level(attr_id, next_level)

	# Cumulative mode
	if attribute.cumulative and _is_multiallocation() and _is_cumulative_op(attribute.operation):
		previous_values = _get_cumulative_values_at_level(attr_id, allocation_level - 1)
		current_values  = _get_cumulative_values_at_level(attr_id, allocation_level)
		next_values     = _get_cumulative_values_at_level(attr_id, next_level)

	# Satın alınmamışsa {C}/{P} → {N}
	if not is_purchased:
		normalized = normalized.replace("{C}", "{N}")
		normalized = normalized.replace("{P}", "{N}")

	# --- {P0}, {C1}, {N2} gibi slot-index'li placeholder'lar ---
	var regex_slot := RegEx.new()
	regex_slot.compile("\\{([PCN])(\\d+)\\}")
	var matches_slot: Array = regex_slot.search_all(normalized)
	var replacements: Array = []
	for m in matches_slot:
		var letter: String = m.get_string(1)
		var slot: int = int(m.get_string(2))
		var values: Array = []
		match letter:
			"P": values = previous_values
			"C": values = current_values
			"N": values = next_values
		var value: int = 0
		if slot >= 0 and slot < values.size():
			value = int(values[slot])
		replacements.append({
			"start": m.get_start(),
			"end": m.get_end(),
			"replacement": str(value),
		})
	replacements.reverse()
	var result: String = normalized
	for r in replacements:
		result = result.substr(0, r["start"]) + r["replacement"] + result.substr(r["end"])

	# --- Basit {P}, {C}, {N} → 0. slot ---
	var regex_plain := RegEx.new()
	regex_plain.compile("\\{([PCN])\\}")
	var matches_plain: Array = regex_plain.search_all(result)
	replacements.clear()
	for m in matches_plain:
		var letter: String = m.get_string(1)
		var values: Array = []
		match letter:
			"P": values = previous_values
			"C": values = current_values
			"N": values = next_values
		var value: int = 0
		if values.size() > 0:
			value = int(values[0])
		replacements.append({
			"start": m.get_start(),
			"end": m.get_end(),
			"replacement": str(value),
		})
	replacements.reverse()
	for r in replacements:
		result = result.substr(0, r["start"]) + r["replacement"] + result.substr(r["end"])

	# --- {<attr_id>_p}, {<attr_id>_c0}, {<attr_id>_n2} gibi attribute bazlı ---
	result = _substitute_attribute_specific_placeholders(result, attr_id)

	return result


## {<attr_id>_p}, {<attr_id>_c0}, {<attr_id>_n2} gibi attribute'a özel
## placeholder'ları doldurur. Sadece mevcut attribute'un değerlerini kullanır
## (cross-attribute referans gerekirse tree_data.attributes üzerinden
## genişletilebilir).
func _substitute_attribute_specific_placeholders(text: String, attr_id: String) -> String:
	var attribute: BayterekAttribute = tree_data.attributes.get(attr_id, null)
	if not attribute:
		return text

	var is_purchased: bool = allocated or allocation_level > 0

	var prev_vals: Array = _get_values_at_level(attr_id, allocation_level - 1)
	var curr_vals: Array = _get_values_at_level(attr_id, allocation_level)

	var next_level: int = allocation_level + 1
	if _is_multiallocation():
		var max_lvl: int = node_data.max_allocations if node_data else 0
		if max_lvl > 0 and next_level > max_lvl:
			next_level = max_lvl
	else:
		if next_level > 1:
			next_level = 1

	var next_vals: Array = _get_values_at_level(attr_id, next_level)

	if attribute.cumulative and _is_multiallocation() and _is_cumulative_op(attribute.operation):
		prev_vals = _get_cumulative_values_at_level(attr_id, allocation_level - 1)
		curr_vals = _get_cumulative_values_at_level(attr_id, allocation_level)
		next_vals = _get_cumulative_values_at_level(attr_id, next_level)

	# --- {<attr_id>_p}, {<attr_id>_c}, {<attr_id>_n} — slot yok, 0. slot ---
	var regex_no_slot := RegEx.new()
	regex_no_slot.compile("\\{%s_([pcn])\\}" % attr_id)
	var matches: Array = regex_no_slot.search_all(text)
	var replacements: Array = []
	for m in matches:
		var letter: String = m.get_string(1).to_lower()
		var vals: Array = []
		match letter:
			"p": vals = prev_vals
			"c": vals = curr_vals
			"n": vals = next_vals
		if not is_purchased and (letter == "p" or letter == "c"):
			vals = next_vals
		var value: int = 0
		if vals.size() > 0:
			value = int(vals[0])
		replacements.append({
			"start": m.get_start(),
			"end": m.get_end(),
			"replacement": str(value),
		})
	replacements.reverse()
	for r in replacements:
		text = text.substr(0, r["start"]) + r["replacement"] + text.substr(r["end"])

	# --- {<attr_id>_p0}, {<attr_id>_c1}, {<attr_id>_n2} — slot index'li ---
	var regex_slot := RegEx.new()
	regex_slot.compile("\\{%s_([pcn])(\\d+)\\}" % attr_id)
	var matches2: Array = regex_slot.search_all(text)
	replacements.clear()
	for m in matches2:
		var letter: String = m.get_string(1).to_lower()
		var slot: int = int(m.get_string(2))
		var vals: Array = []
		match letter:
			"p": vals = prev_vals
			"c": vals = curr_vals
			"n": vals = next_vals
		if not is_purchased and (letter == "p" or letter == "c"):
			vals = next_vals
		var value: int = 0
		if slot >= 0 and slot < vals.size():
			value = int(vals[slot])
		replacements.append({
			"start": m.get_start(),
			"end": m.get_end(),
			"replacement": str(value),
		})
	replacements.reverse()
	for r in replacements:
		text = text.substr(0, r["start"]) + r["replacement"] + text.substr(r["end"])

	return text

func _get_effect_text(attribute: BayterekAttribute) -> String:
	if not attribute:
		return ""

	if attribute.effect_key.is_empty():
		return attribute.effect

	if not is_inside_tree():
		return attribute.effect

	var loc = get_node_or_null("/root/GameLocalization")
	if not loc or not loc.has_method("get_raw_text"):
		return attribute.effect

	var translated: String = String(loc.call("get_raw_text", attribute.effect_key))
	if translated.is_empty():
		return attribute.effect

	return translated


func _get_values_at_level(attr_id: String, level: int) -> Array:
	if not node_data or not node_data.attributes.has(attr_id):
		return []

	var raw = node_data.attributes[attr_id]
	if not raw is Array:
		return []

	if raw.size() > 0 and raw[0] is Array:
		var slot_count: int = raw[0].size()
		if level <= 0 or level > raw.size():
			var z: Array = []
			for i in slot_count:
				z.append(0)
			return z
		return raw[level - 1]

	var slot_count2: int = raw.size()
	if level == 1:
		return raw
	var z2: Array = []
	for i in slot_count2:
		z2.append(0)
	return z2


func _get_cumulative_values_at_level(attr_id: String, level: int) -> Array:
	if not node_data or not node_data.attributes.has(attr_id):
		return []

	var raw = node_data.attributes[attr_id]
	if not raw is Array or raw.size() == 0:
		return []

	if not (raw[0] is Array):
		return raw if level >= 1 else []

	var slot_count: int = raw[0].size()
	var result: Array = []
	for i in slot_count:
		result.append(0)

	if level <= 0:
		return result

	var lvl: int = mini(level, raw.size())
	for l in lvl:
		var lvl_vals: Array = raw[l]
		for i in mini(slot_count, lvl_vals.size()):
			result[i] += int(lvl_vals[i])
	return result

# ------------------------------------------------------------
# LEVEL TEXT
# ------------------------------------------------------------

func _format_level_text() -> String:
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

	var level_word: String = _localize(LOC_KEY_LEVEL, "Level")

	return "[color=%s]%s: %d / %d[/color]" % [
		color, level_word, current, maximum
	]