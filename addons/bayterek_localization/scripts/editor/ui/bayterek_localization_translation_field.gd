@tool
class_name BayterekLocalizationTranslationField
extends Control
## A LineEdit with placeholder highlighting.
##
## Architecture:
##   - Bottom layer: RichTextLabel with BBCode → shows colored text.
##   - Top layer:    LineEdit with fully transparent font → handles typing.
##
## When the user types, the LineEdit.text changes and the RichTextLabel is
## updated with a BBCode version where "{placeholder}" segments are wrapped
## in [color=...].
##
## Note on signal names:
##   `Control` already declares `focus_entered` / `focus_exited`, so our
##   custom signals use `field_*` prefixes to avoid clashes.

signal text_changed(new_text: String)
signal field_focus_entered
signal field_focus_exited
signal text_submitted(text: String)

const PLACEHOLDER_COLOR := "8eb4ff"    # soft blue
const PLACEHOLDER_BOLD := true
const MIN_HEIGHT := 22

var _rt: RichTextLabel
var _le: LineEdit
var _updating_from_line: bool = false

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	custom_minimum_size.y = MIN_HEIGHT
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build()

func _build() -> void:
	if _rt:
		return

	# --- Bottom: RichTextLabel ---
	_rt = RichTextLabel.new()
	_rt.name = "RichLayer"
	_rt.bbcode_enabled = true
	_rt.scroll_active = false
	_rt.fit_content = false
	_rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rt.focus_mode = Control.FOCUS_NONE
	_rt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rt.add_theme_constant_override("line_separation", 0)
	add_child(_rt)

	# --- Top: transparent LineEdit ---
	_le = LineEdit.new()
	_le.name = "LineLayer"
	_le.size_flags_horizontal = SIZE_EXPAND_FILL
	_le.size_flags_vertical = SIZE_EXPAND_FILL
	_le.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_le.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	_le.add_theme_color_override("font_placeholder_color", Color(0, 0, 0, 0))
	_le.add_theme_color_override("font_selected_color", Color(0.3, 0.5, 0.8, 0.4))
	_le.add_theme_color_override("caret_color", Color(1, 1, 1, 0.9))
	_le.add_theme_color_override("selection_color", Color(0.3, 0.5, 0.8, 0.35))

	var empty_style := StyleBoxEmpty.new()
	_le.add_theme_stylebox_override("normal", empty_style)
	_le.add_theme_stylebox_override("focus", empty_style)
	_le.add_theme_stylebox_override("read_only", empty_style)

	_le.text_changed.connect(_on_line_text_changed)
	_le.focus_entered.connect(_on_inner_focus_entered)
	_le.focus_exited.connect(_on_inner_focus_exited)
	_le.text_submitted.connect(_on_inner_text_submitted)
	add_child(_le)

# ============================================================
# PUBLIC API
# ============================================================

func set_text(new_text: String) -> void:
	if not _le:
		return
	_updating_from_line = true
	_le.text = new_text
	_updating_from_line = false
	_refresh_rich()

func get_text() -> String:
	if not _le:
		return ""
	return _le.text

func set_placeholder(p: String) -> void:
	if _le:
		_le.placeholder_text = p

func grab_focus_field() -> void:
	if _le:
		_le.grab_focus()

func select_all() -> void:
	if _le:
		_le.select_all()

func set_editable(on: bool) -> void:
	if _le:
		_le.editable = on

func is_editable() -> bool:
	return _le != null and _le.editable

func has_field_focus() -> bool:
	return _le != null and _le.has_focus()

# ============================================================
# INTERNAL
# ============================================================

func _on_line_text_changed(new_text: String) -> void:
	if _updating_from_line:
		return
	_refresh_rich()
	text_changed.emit(new_text)

func _on_inner_focus_entered() -> void:
	field_focus_entered.emit()

func _on_inner_focus_exited() -> void:
	field_focus_exited.emit()

func _on_inner_text_submitted(text: String) -> void:
	text_submitted.emit(text)

## Rebuilds the RichTextLabel from the current LineEdit text,
## colouring {placeholder} segments.
func _refresh_rich() -> void:
	if not _rt or not _le:
		return

	var raw: String = _le.text
	_rt.clear()

	if raw.is_empty():
		return

	var i: int = 0
	var n: int = raw.length()

	while i < n:
		var c: String = raw[i]

		if c == "{":
			var close_idx: int = raw.find("}", i + 1)
			if close_idx == -1:
				_rt.append_text(_escape_bbcode(raw.substr(i)))
				return

			var name: String = raw.substr(i + 1, close_idx - i - 1).strip_edges()
			if name.is_empty():
				_rt.append_text(_escape_bbcode(raw.substr(i, close_idx - i + 1)))
			else:
				var seg: String = raw.substr(i, close_idx - i + 1)
				_rt.push_color(Color.html(PLACEHOLDER_COLOR))
				if PLACEHOLDER_BOLD:
					_rt.push_bold()
				_rt.append_text(_escape_bbcode(seg))
				if PLACEHOLDER_BOLD:
					_rt.pop()
				_rt.pop()

			i = close_idx + 1
		else:
			var next_open: int = raw.find("{", i)
			if next_open == -1:
				_rt.append_text(_escape_bbcode(raw.substr(i)))
				return
			_rt.append_text(_escape_bbcode(raw.substr(i, next_open - i)))
			i = next_open

func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[[")

# ============================================================
# NOTIFICATIONS
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _rt:
		_rt.queue_redraw()