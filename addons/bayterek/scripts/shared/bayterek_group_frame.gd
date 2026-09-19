@tool
class_name BayterekGroupFrame
extends Control
## Canvas üzerinde bir node grubunun bounding box'ını gösteren çerçeve.
##
## Frame hiçbir event almaz (mouse_filter = IGNORE). Tıklama/drag tamamen
## BayterekGroupFramesService + BayterekTreeView tarafındaki manuel
## hit-test ile yönetilir. Bu sayede offset_transform'lı parent'larda
## Godot'un input picking bug'ına takılmıyoruz.

const PADDING := 20.0
const TITLE_HEIGHT := 22.0
const BORDER_WIDTH := 2.0

var group_id: String = ""
var group_name: String = "Group"
var group_color: Color = Color(0.4, 0.7, 1.0)

var selected: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Grubun üyelerine göre bounding box'ı hesaplayıp frame'in rect'ini günceller.
func fit_to_members(members: Array) -> void:
	if members.is_empty():
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

	visible = true
	queue_redraw()

func _draw() -> void:
	if not visible:
		return

	var border_color: Color = group_color
	border_color.a = 0.95 if selected else 0.65

	var fill_color: Color = group_color
	fill_color.a = 0.12 if selected else 0.06

	var title_bg: Color = group_color
	title_bg.a = 0.28 if selected else 0.18

	# Body background
	draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)

	# Title bar background
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, TITLE_HEIGHT)), title_bg, true)

	# Border
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, BORDER_WIDTH)

	# Title text
	var font: Font = get_theme_default_font()
	if font:
		draw_string(
			font,
			Vector2(10, TITLE_HEIGHT - 6),
			group_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			group_color
		)

	# Selected indicator strip
	if selected:
		var y: float = TITLE_HEIGHT
		var x: float = 0.0
		while x < size.x:
			var seg_end: float = min(x + 6.0, size.x)
			draw_line(Vector2(x, y), Vector2(seg_end, y), border_color, 2.0)
			x += 12.0