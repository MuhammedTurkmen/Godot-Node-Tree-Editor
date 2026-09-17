@tool
class_name BayterekNodeButton
extends BaseButton
## Tek bir node'un sahnedeki görsel temsili.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

signal node_hovered(node: BayterekNodeButton, is_hovered: bool)
signal drag_started(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal dragged(node: BayterekNodeButton, mouse_screen_pos: Vector2)
signal drag_ended(node: BayterekNodeButton)

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
	set(v): if node_data: node_data.is_root = v

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
	# Positioned ABOVE the node, slightly outside its bounds, centered
	# horizontally. Uses full-rect anchoring + Y offset for stable centering.
	# NEAREST filter keeps the glyph crisp when the canvas is zoomed.
	_crown_label = Label.new()
	_crown_label.name = "Crown"
	_crown_label.text = "♛"
	# _crown_label.text = "☼"
	_crown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crown_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_crown_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_crown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_crown_label.add_theme_constant_override("outline_size", 2)
	_crown_label.add_theme_font_size_override("font_size", 18)
	_crown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_crown_label.offset_left = -20
	_crown_label.offset_top = -28
	_crown_label.offset_right = 20
	_crown_label.offset_bottom = -2
	_crown_label.visible = false
	add_child(_crown_label)

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

	# Icon
	if node_data.icon:
		_icon_rect.texture = node_data.icon
		_icon_rect.visible = true
		_icon_fallback.visible = false
	else:
		_icon_rect.texture = null
		_icon_rect.visible = false
		_icon_fallback.visible = true
		_icon_fallback.color = _get_type_color(node_data.type)

	# Crown — visible only for root nodes
	if _crown_label:
		_crown_label.visible = node_data.is_root

	# Border — based on allocation state
	_apply_state_border()

	# Locked → semi transparent
	if node_data.locked:
		modulate = Color(1, 1, 1, 0.5)
	else:
		modulate = Color.WHITE

func _apply_state_border() -> void:
	if not node_data:
		return

	match state:
		Bayterek.AllocationState.NORMAL:
			_update_border(node_data.border_normal, Color.WHITE)
		Bayterek.AllocationState.INTERMEDIATE:
			_update_border(node_data.border_intermediate, Color.WHITE)
		Bayterek.AllocationState.ACTIVE:
			_update_border(node_data.border_active, Color.WHITE)
		Bayterek.AllocationState.PREALLOCATED_INTERMEDIATE:
			_update_border(node_data.border_intermediate, Color(1, 0.8, 0))
		Bayterek.AllocationState.PREALLOCATED_ACTIVE:
			_update_border(node_data.border_active, Color(1, 0.8, 0))
		Bayterek.AllocationState.REFUND:
			_update_border(node_data.border_active, Color(1, 0, 0))
		_:
			_update_border(node_data.border_normal, Color.WHITE)

	# Fallback: if no border texture, use icon modulate to show state
	if not _border_rect or not _border_rect.texture:
		_apply_state_fallback()

## Fallback visual when no border textures are assigned.
func _apply_state_fallback() -> void:
	var tint: Color = Color.WHITE

	match state:
		Bayterek.AllocationState.NORMAL:
			tint = Color(0.5, 0.5, 0.5)
		Bayterek.AllocationState.INTERMEDIATE:
			tint = Color(0.7, 0.7, 0.7)
		Bayterek.AllocationState.ACTIVE:
			tint = Color(1, 1, 1)
		Bayterek.AllocationState.PREALLOCATED_INTERMEDIATE:
			tint = Color(1, 0.9, 0.5)
		Bayterek.AllocationState.PREALLOCATED_ACTIVE:
			tint = Color(1, 0.8, 0.2)
		Bayterek.AllocationState.REFUND:
			tint = Color(1, 0.4, 0.4)

	if _icon_rect:
		_icon_rect.modulate = tint
	if _icon_fallback:
		_icon_fallback.modulate = tint

func _update_border(texture: Texture2D, color: Color = Color.WHITE) -> void:
	if not _border_rect:
		return

	_border_rect.texture = texture
	_border_rect.modulate = color
	_border_rect.visible = texture != null

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
	_apply_state_border()

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
	node_hovered.emit(self, true)

func _on_mouse_exited() -> void:
	is_mouse_over = false
	node_hovered.emit(self, false)

# ============================================================
# TOOLTIP FORMATTING
# ============================================================

func format_tooltip() -> String:
	if not node_data:
		return ""

	var text: String = ""

	var display_name: String = node_name
	if display_name.is_empty():
		display_name = "Node %d" % id

	if _is_multiallocation():
		text += "[b][color=#f9e6ca]%s[/color][/b] [color=#a0a0a0](%d/%d)[/color]\n\n" % [
			display_name, allocation_level, node_data.max_allocations
		]
	else:
		text += "[b][color=#f9e6ca]%s[/color][/b]\n\n" % display_name

	text += _format_attributes()

	if not node_data.description.is_empty():
		text += "\n[color=orange]%s[/color]" % node_data.description

	return text.strip_edges()

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