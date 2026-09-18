@tool
class_name BayterekGroupFrame
extends Control
## Canvas üzerinde bir node grubunun bounding box'ını gösteren çerçeve.
##
## Frame'in kendisi mouse_filter = IGNORE. Sadece TitleBar adındaki child
## Panel tıklamayı yakalar. Panel kullanıyoruz çünkü Control.new() ile
## yaratılan boş Control bazen input picking'e dahil olmuyor.

signal frame_pressed(frame: BayterekGroupFrame, additive: bool)
signal frame_drag_started(frame: BayterekGroupFrame, screen_pos: Vector2)
signal frame_dragged(frame: BayterekGroupFrame, screen_pos: Vector2)
signal frame_drag_ended(frame: BayterekGroupFrame)

const PADDING := 20.0
const TITLE_HEIGHT := 22.0
const BORDER_WIDTH := 2.0
const CORNER_RADIUS := 6.0

var group_id: String = ""
var group_name: String = "Group"
var group_color: Color = Color(0.4, 0.7, 1.0)

var selected: bool = false

var _title_bar: Panel

var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Frame itself does NOT receive input. Only the title bar does.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Title bar overlays the top part of the frame.
	# Using Panel instead of a bare Control because Panel reliably
	# participates in input picking with MOUSE_FILTER_STOP.
	_title_bar = Panel.new()
	_title_bar.name = "TitleBar"
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE

	var empty_style := StyleBoxEmpty.new()
	_title_bar.add_theme_stylebox_override("panel", empty_style)

	_title_bar.anchor_left = 0.0
	_title_bar.anchor_top = 0.0
	_title_bar.anchor_right = 1.0
	_title_bar.anchor_bottom = 0.0
	_title_bar.offset_left = 0.0
	_title_bar.offset_top = 0.0
	_title_bar.offset_right = 0.0
	_title_bar.offset_bottom = TITLE_HEIGHT

	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_title_bar.mouse_entered.connect(_on_title_bar_mouse_entered)
	_title_bar.mouse_exited.connect(_on_title_bar_mouse_exited)

	add_child(_title_bar)

	print("[Frame] _ready called for group: ", group_id)
	print("[Frame] title_bar added, visible=", visible, " size=", size)

func _on_title_bar_mouse_entered() -> void:
	print("[Frame] MOUSE ENTERED title_bar")

func _on_title_bar_mouse_exited() -> void:
	print("[Frame] MOUSE EXITED title_bar")

## Grubun üyelerine göre bounding box'ı hesaplayıp frame'in rect'ini günceller.
func fit_to_members(members: Array) -> void:
	print("[Frame.fit] called with ", members.size(), " members")

	if members.is_empty():
		print("[Frame.fit] members empty — hiding")
		visible = false
		return

	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	var count: int = 0
	for node in members:
		if not is_instance_valid(node):
			continue
		var pos: Vector2 = node.position
		var sz: Vector2 = node.size
		min_x = minf(min_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_x = maxf(max_x, pos.x + sz.x)
		max_y = maxf(max_y, pos.y + sz.y)
		count += 1

	if count == 0:
		visible = false
		return

	position = Vector2(min_x - PADDING, min_y - PADDING - TITLE_HEIGHT)
	size = Vector2(
		(max_x - min_x) + PADDING * 2,
		(max_y - min_y) + PADDING * 2 + TITLE_HEIGHT
	)

	print("[Frame.fit] new size: ", size, " at pos: ", position)
	visible = true
	queue_redraw()

func _debug_report() -> void:
	print("[Frame.debug] group=", group_name, " visible=", visible, " pos=", position, " size=", size, " global_rect=", get_global_rect())
	if _title_bar:
		print("[Frame.debug] title_bar: visible=", _title_bar.visible, " pos=", _title_bar.position, " size=", _title_bar.size, " filter=", _title_bar.mouse_filter, " global_rect=", _title_bar.get_global_rect())

func _on_title_bar_gui_input(event: InputEvent) -> void:
	print("[Frame] title_bar received event: ", event)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_is_dragging = false
				_title_bar.accept_event()
			else:
				if _is_dragging:
					frame_drag_ended.emit(self)
					_is_dragging = false
				else:
					var additive: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
					frame_pressed.emit(self, additive)
				_title_bar.accept_event()

	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _is_dragging:
			if event.position.distance_to(_press_pos) > 4.0:
				_is_dragging = true
				var screen_pos: Vector2 = _title_bar.get_global_transform() * event.position
				frame_drag_started.emit(self, screen_pos)
		if _is_dragging:
			var screen_pos: Vector2 = _title_bar.get_global_transform() * event.position
			frame_dragged.emit(self, screen_pos)
			_title_bar.accept_event()

func _on_mouse_entered() -> void:
	queue_redraw()

func _on_mouse_exited() -> void:
	queue_redraw()

func _draw() -> void:
	if not visible:
		return

	var border_color: Color = group_color
	border_color.a = 0.85 if selected else 0.55

	var fill_color: Color = group_color
	fill_color.a = 0.10 if selected else 0.05

	var title_bg: Color = group_color
	title_bg.a = 0.22 if selected else 0.14

	var title_text_color: Color = group_color
	title_text_color.a = 1.0

	# --- Body background ---
	draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)

	# --- Title bar background ---
	var title_rect := Rect2(Vector2.ZERO, Vector2(size.x, TITLE_HEIGHT))
	draw_rect(title_rect, title_bg, true)

	# --- Border ---
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, BORDER_WIDTH)

	# --- Title text ---
	var font: Font = get_theme_default_font()
	if font:
		var font_size: int = 13
		var text_pos := Vector2(10, TITLE_HEIGHT - 6)
		draw_string(font, text_pos, group_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, title_text_color)

	# --- Selected indicator ---
	if selected:
		var y: float = TITLE_HEIGHT
		var x: float = 0.0
		while x < size.x:
			var seg_end: float = min(x + 6.0, size.x)
			draw_line(Vector2(x, y), Vector2(seg_end, y), border_color, 2.0)
			x += 12.0