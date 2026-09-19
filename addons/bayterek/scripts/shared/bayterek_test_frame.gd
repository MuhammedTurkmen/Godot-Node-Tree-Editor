@tool
class_name BayterekTestFrame
extends Control
## Basit test frame'i — sadece görsel, hiç event yakalamaz.
## Tıklama/drag tamamen BayterekTreeView._gui_input içindeki manuel
## hit-test ile yönetilir.

const PADDING := 20.0
const TITLE_HEIGHT := 22.0
const BORDER_WIDTH := 2.0

var frame_name: String = "Test Frame"
var frame_color: Color = Color(1.0, 0.6, 0.2, 1.0)

var selected: bool = false

func _ready() -> void:
	print("[TEST] BayterekTestFrame._ready()")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	print("[TEST] BayterekTestFrame._draw() visible=", visible, " size=", size)
	if not visible:
		return

	var border_color: Color = frame_color
	border_color.a = 0.95 if selected else 0.65

	var fill_color: Color = frame_color
	fill_color.a = 0.12 if selected else 0.06

	var title_bg: Color = frame_color
	title_bg.a = 0.28 if selected else 0.18

	# Body
	draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)

	# Title bar
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, TITLE_HEIGHT)), title_bg, true)

	# Border
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, BORDER_WIDTH)

	# Title text
	var font: Font = get_theme_default_font()
	if font:
		draw_string(
			font,
			Vector2(10, TITLE_HEIGHT - 6),
			frame_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			frame_color
		)

	# Selected indicator
	if selected:
		var y: float = TITLE_HEIGHT
		var x: float = 0.0
		while x < size.x:
			var seg_end: float = min(x + 6.0, size.x)
			draw_line(Vector2(x, y), Vector2(seg_end, y), border_color, 2.0)
			x += 12.0