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

var _icon_rect: TextureRect
var _icon_fallback: ColorRect
var _border_rect: TextureRect
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

	_build_visuals()

func _build_visuals() -> void:
	# 1) Fallback (renkli kutu — texture yoksa görünür)
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
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_icon_rect)

	# 3) Border
	_border_rect = TextureRect.new()
	_border_rect.name = "Border"
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_border_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_border_rect)

	# 4) Seçim çerçevesi
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

# ============================================================
# GÖRSEL GÜNCELLEME
# ============================================================

func refresh_visuals() -> void:
	if not node_data:
		return

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

	# Border (state'e göre ileride değişecek, şu an normal)
	_update_border()

func _update_border() -> void:
	if not node_data:
		return

	# Şimdilik normal border kullanılıyor (state yönetimi 5+'ta)
	var tex: Texture2D = node_data.border_normal

	if tex:
		_border_rect.texture = tex
		_border_rect.visible = true
	else:
		_border_rect.texture = null
		_border_rect.visible = false

func _get_type_color(t: BayterekNode.NodeType) -> Color:
	match t:
		BayterekNode.NodeType.SMALL:  return Color(0.4, 0.7, 1.0, 0.8)
		BayterekNode.NodeType.MEDIUM: return Color(0.4, 1.0, 0.5, 0.8)
		BayterekNode.NodeType.LARGE:  return Color(1.0, 0.7, 0.4, 0.8)
		BayterekNode.NodeType.DECORATION: return Color(0.7, 0.5, 1.0, 0.8)
	return Color.WHITE

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