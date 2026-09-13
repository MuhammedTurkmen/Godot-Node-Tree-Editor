@tool
class_name BayterekSelectionBox
extends Panel
## Alan seçim kutusu.

signal selected(rect: Rect2)   # tree koordinatlarında

var selecting: bool = false

var _view: BayterekTreeView
var _start_tree: Vector2
var _current_tree: Vector2

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 1.0, 0.15)
	style.border_color = Color(0.3, 0.7, 1.0, 0.9)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)

func set_view(view: BayterekTreeView) -> void:
	_view = view

# ============================================================
# INPUT
# ============================================================

func handle_input(event: InputEvent) -> void:
	if not _view:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		elif selecting:
			_end()

	elif event is InputEventMouseMotion and selecting:
		_update(event.position)

# ============================================================
# BAŞLANGIÇ / BİTİŞ
# ============================================================

func _begin(screen_pos: Vector2) -> void:
	selecting = true
	_start_tree = _view.screen_to_tree(screen_pos)
	_current_tree = _start_tree

	position = screen_pos
	size = Vector2.ZERO
	visible = true

func _end() -> void:
	selecting = false
	visible = false

	var top_left := Vector2(min(_start_tree.x, _current_tree.x), min(_start_tree.y, _current_tree.y))
	var bottom_right := Vector2(max(_start_tree.x, _current_tree.x), max(_start_tree.y, _current_tree.y))
	var rect := Rect2(top_left, bottom_right - top_left)

	selected.emit(rect)

func _update(screen_pos: Vector2) -> void:
	_current_tree = _view.screen_to_tree(screen_pos)

	# Görsel geri bildirim
	var start_screen: Vector2 = _view.tree_to_view_local(_start_tree)
	var current_screen: Vector2 = _view.tree_to_view_local(_current_tree)
	var top_left := Vector2(min(start_screen.x, current_screen.x), min(start_screen.y, current_screen.y))
	var sz := Vector2(abs(current_screen.x - start_screen.x), abs(current_screen.y - start_screen.y))

	position = top_left
	size = sz