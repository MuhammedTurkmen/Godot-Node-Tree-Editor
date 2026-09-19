@tool
class_name BayterekNodeButton
extends BaseButton
## Tek bir node'un sahnedeki görsel temsili.

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

# === Allocation runtime vars ===
var allocated: bool = false
var preallocated: bool = false
var refund: bool = false
var allocation_level: int = 0
var state: Bayterek.AllocationState = Bayterek.AllocationState.NORMAL

## Global "can this node be allocated right now" flag, computed by the
## tree view after each allocation/preallocation/refund change.
## Used by `_apply_visuals()` to pick allocatable/not_allocatable color.
var is_allocatable: bool = false

var _icon_rect: TextureRect
var _icon_fallback: ColorRect
var _border_rect: TextureRect
var _select_border: Panel
var _crown_label: Label

var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO

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

func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_build_visuals()

func _build_visuals() -> void:
	# 1) Fallback (colored box — visible when no texture)
	_icon_fallback = ColorRect.new()
	_icon_fallback.name = "IconFallback"
	_icon_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_fallback.visible = false
	add_child(_icon_fallback)

	# 2) Icon texture
	_icon_rect = TextureRect.new()
	_icon_rect.name = "Icon"
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_icon_rect)

	# 3) Border
	_border_rect = TextureRect.new()
	_border_rect.name = "Border"
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_border_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_border_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_border_rect)

	# 4) Selection frame
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

	# 5) Crown icon (visible only for root nodes)
	_crown_label = Label.new()
	_crown_label.name = "Crown"
	_crown_label.text = "👑"
	_crown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
# VISUAL STATE RESOLUTION
# ============================================================

## Returns which visual "state key" this node should use right now.
## Priority:
##   1. LOCKED
##   2. REFUND
##   3. ALLOCATE (preallocated — preallocation mode only)
##   4. MAX_LEVEL
##   5. HOVER
##   6. ALLOCATABLE
##   7. NOT_ALLOCATABLE
##   8. NORMAL
func _resolve_visual_state() -> String:
	if node_data == null:
		return "normal"

	# 1) Locked takes top priority.
	if node_data.locked:
		return "locked"

	# 2) Refund: this node is currently staged for refund.
	if refund:
		return "refund"

	# 3) Allocate: preallocation mode, node is staged for allocation.
	if preallocated:
		return "allocate"

	# 4) Max level: allocated and at maximum level.
	if allocated and node_data.max_allocations > 0 and allocation_level >= node_data.max_allocations:
		return "max_level"

	# 5) Hover: mouse is over the node.
	if is_mouse_over:
		return "hover"

	# 6) Allocatable: node is not yet allocated but CAN be allocated right now.
	if tree_data and tree_data.allocation and not allocated:
		if is_allocatable:
			return "allocatable"
		else:
			return "not_allocatable"

	# 7) Fallback.
	return "normal"

## Resolves the border texture for the current visual state.
## Falls back gracefully: if the state has no dedicated texture, uses
## `normal`, then `hover`, then any other populated one, then null.
func _resolve_border_texture(state_key: String) -> Texture2D:
	if node_data == null:
		return null

	# 1. Direct match for the state
	match state_key:
		"locked":
			if node_data.border_texture_locked:
				return node_data.border_texture_locked
		"normal":
			if node_data.border_texture_normal:
				return node_data.border_texture_normal
		"hover":
			if node_data.border_texture_hover:
				return node_data.border_texture_hover
		"max_level":
			if node_data.border_texture_max_level:
				return node_data.border_texture_max_level

	# 2. Fallback chain: normal → hover → locked → max_level
	if node_data.border_texture_normal:
		return node_data.border_texture_normal
	if node_data.border_texture_hover:
		return node_data.border_texture_hover
	if node_data.border_texture_locked:
		return node_data.border_texture_locked
	if node_data.border_texture_max_level:
		return node_data.border_texture_max_level

	# 3. Nothing set
	return null

## Resolves the icon texture for the current visual state.
## Falls back to `icon_texture_normal` (base icon) when nothing set.
func _resolve_icon_texture(state_key: String) -> Texture2D:
	if node_data == null:
		return null

	match state_key:
		"locked":
			if node_data.icon_texture_locked:
				return node_data.icon_texture_locked
		"normal":
			if node_data.icon_texture_normal:
				return node_data.icon_texture_normal
		"hover":
			if node_data.icon_texture_hover:
				return node_data.icon_texture_hover
		"max_level":
			if node_data.icon_texture_max_level:
				return node_data.icon_texture_max_level

	# Fallback to base icon
	if node_data.icon_texture_normal:
		return node_data.icon_texture_normal
	if node_data.icon_texture_hover:
		return node_data.icon_texture_hover
	if node_data.icon_texture_locked:
		return node_data.icon_texture_locked
	if node_data.icon_texture_max_level:
		return node_data.icon_texture_max_level

	return null

## Looks up the current border color for the given state key.
func _border_color_for(state_key: String) -> Color:
	if node_data == null:
		return Color.WHITE
	match state_key:
		"locked":          return node_data.border_color_locked
		"normal":          return node_data.border_color_normal
		"hover":           return node_data.border_color_hover
		"allocate":        return node_data.border_color_allocate
		"refund":          return node_data.border_color_refund
		"max_level":       return node_data.border_color_max_level
		"allocatable":     return node_data.border_color_allocatable
		"not_allocatable": return node_data.border_color_not_allocatable
	return Color.WHITE

## Looks up the current icon color for the given state key.
func _icon_color_for(state_key: String) -> Color:
	if node_data == null:
		return Color.WHITE
	match state_key:
		"locked":          return node_data.icon_color_locked
		"normal":          return node_data.icon_color_normal
		"hover":           return node_data.icon_color_hover
		"allocate":        return node_data.icon_color_allocate
		"refund":          return node_data.icon_color_refund
		"max_level":       return node_data.icon_color_max_level
		"allocatable":     return node_data.icon_color_allocatable
		"not_allocatable": return node_data.icon_color_not_allocatable
	return Color.WHITE

# ============================================================
# VISUAL UPDATE
# ============================================================

func refresh_visuals() -> void:
	if not node_data:
		return

	# Apply texture filter from tree
	if tree_data:
		var filter: int = tree_data.get_godot_texture_filter()
		if _icon_rect:
			_icon_rect.texture_filter = filter
		if _border_rect:
			_border_rect.texture_filter = filter

	var state_key: String = _resolve_visual_state()

	# --- Icon layer ---
	var icon_tex: Texture2D = _resolve_icon_texture(state_key)

	if icon_tex:
		_icon_rect.texture = icon_tex
		_icon_rect.visible = true
		_icon_fallback.visible = false
		_icon_rect.modulate = _icon_color_for(state_key)
	else:
		_icon_rect.texture = null
		_icon_rect.visible = false
		_icon_fallback.visible = true
		_icon_fallback.color = _get_type_color(node_data.type)
		_icon_fallback.modulate = _icon_color_for(state_key)

	# --- Border layer ---
	var border_tex: Texture2D = _resolve_border_texture(state_key)
	var border_color: Color = _border_color_for(state_key)

	if border_tex:
		_border_rect.texture = border_tex
		_border_rect.modulate = border_color
		_border_rect.visible = true
		modulate = Color.WHITE  # don't double-tint the whole node
	else:
		_border_rect.texture = null
		_border_rect.visible = false
		# If there's no border texture, tint the whole node so state is
		# still visible. This is the "color only" fallback.
		modulate = border_color

	# Crown — visible only for root nodes
	if _crown_label:
		_crown_label.visible = node_data.is_root

func _get_type_color(t: BayterekNode.NodeType) -> Color:
	match t:
		BayterekNode.NodeType.SMALL:  return Color(0.4, 0.7, 1.0, 0.8)
		BayterekNode.NodeType.MEDIUM: return Color(0.4, 1.0, 0.5, 0.8)
		BayterekNode.NodeType.LARGE:  return Color(1.0, 0.7, 0.4, 0.8)
		BayterekNode.NodeType.DECORATION: return Color(0.7, 0.5, 1.0, 0.8)
	return Color.WHITE

# ============================================================
# ALLOCATION STATE
# ============================================================

func set_state(new_state: Bayterek.AllocationState) -> void:
	state = new_state
	refresh_visuals()

func set_selected(value: bool) -> void:
	selected = value
	if _select_border:
		_select_border.visible = value

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
			# Forward right-click to editor via signal so the context menu
			# can be shown. We consume the event here since we stop mouse
			# propagation at this node.
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

## Returns three BBCode strings: header, body, footer.
## The tooltip renders them as separate aligned sections.
func format_tooltip_sections() -> Dictionary:
	var header: String = ""
	var body: String = ""
	var footer: String = ""

	if not node_data:
		return {"header": "", "body": "", "footer": ""}

	# --- HEADER: node name ---
	var display_name: String = node_name
	if display_name.is_empty():
		display_name = "Node %d" % id
	header = "[b][color=#f9e6ca]%s[/color][/b]" % display_name

	# --- BODY: prerequisite info, attributes, description ---
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

	# --- FOOTER: level ---
	footer = _format_level_footer()

	return {"header": header, "body": body, "footer": footer}

## Returns a BBCode string for the level footer.
##   - multi-allocation OFF → "Level: 0 / 1"  (or 1 / 1 when allocated)
##   - multi-allocation ON  → "Level: X / Y"
func _format_level_footer() -> String:
	if not node_data:
		return ""

	var current: int = allocation_level
	var maximum: int = 1

	if _is_multiallocation():
		maximum = node_data.max_allocations
		current = allocation_level
	else:
		# Single allocation: "0 / 1" when not allocated, "1 / 1" when allocated.
		maximum = 1
		current = 1 if allocated else 0

	# Color-code: yellow when at max, green when allocated but not max,
	# grey when not allocated.
	var color: String = "#a0a0a0"
	if maximum > 0 and current >= maximum:
		color = "#ffd766"
	elif current > 0:
		color = "#8ef58e"

	return "[center][color=%s]Level: %d / %d[/color][/center]" % [color, current, maximum]

## Kept for backward compatibility — flattens the three sections into
## a single BBCode string. Prefer format_tooltip_sections().
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