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

var is_mouse_over: bool = false
var selected: bool = false

var _icon_rect: ColorRect
var _select_border: Panel

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

	# Seçim border'ı
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
			else:
				if _is_dragging:
					drag_ended.emit(self)
					_is_dragging = false
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