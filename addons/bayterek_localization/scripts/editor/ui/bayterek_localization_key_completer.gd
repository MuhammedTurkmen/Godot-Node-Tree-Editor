@tool
class_name BayterekLocalizationKeyCompleter
extends PopupPanel
## Auto-complete popup for placeholder keys in a TextEdit.
##
## Usage:
##   var completer := BayterekLocalizationKeyCompleter.new()
##   completer.set_target(text_edit)
##   completer.set_key_provider(func() -> PackedStringArray: return all_keys)

signal key_selected(key: String, as_reference: bool)

const POPUP_W := 300
const POPUP_H := 220
const MAX_VISIBLE := 12

var _target: TextEdit = null
var _key_provider: Callable = Callable()
var _list: ItemList = null
var _filtered: PackedStringArray = PackedStringArray()

## Index of `{` (or `{@`) inside the target text — where replacement starts.
var _replace_start: int = -1
## True if completing a key reference ({@key}).
var _as_reference: bool = false
## Query typed by the user (after `{` or `{@`).
var _query: String = ""

func _init() -> void:
	name = "KeyCompleter"
	transparent_bg = false
	unresizable = false
	size = Vector2i(POPUP_W, POPUP_H)
	exclusive = false
	popup_window = false
	wrap_controls = false

	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.custom_minimum_size = Vector2(POPUP_W, POPUP_H)
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var header := Label.new()
	header.name = "Header"
	header.text = "Keys"
	header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_theme_font_size_override("font_size", 11)
	root.add_child(header)

	_list = ItemList.new()
	_list.name = "SuggestionList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.allow_reselect = true
	_list.item_activated.connect(_on_item_activated)
	root.add_child(_list)

# ============================================================
# PUBLIC API
# ============================================================

func set_target(text_edit: TextEdit) -> void:
	_target = text_edit

func set_key_provider(provider: Callable) -> void:
	_key_provider = provider

## Called by the TextEdit whenever text changes.
## Detects `{` or `{@` and shows the popup accordingly.
func check_for_trigger() -> void:
	if not _target:
		return

	var caret: int = _target.get_caret_column()
	var line: int = _target.get_caret_line()
	if line != 0:
		hide_popup()
		return

	var text: String = _target.get_line(0)
	var before: String = text.substr(0, caret)

	# Find the last unmatched `{`.
	var open_idx: int = before.rfind("{")
	if open_idx == -1:
		hide_popup()
		return

	# If there's a `}` after `{`, it's already closed — do nothing.
	var after_open: String = before.substr(open_idx + 1)
	if after_open.find("}") != -1:
		hide_popup()
		return

	var inner: String = after_open

	# Key reference mode ({@key})?
	var is_ref: bool = false
	var query: String = inner
	if inner.begins_with("@"):
		is_ref = true
		query = inner.substr(1)

	# Abort if query contains invalid characters.
	if query.find(" ") != -1 or query.find("{") != -1:
		hide_popup()
		return

	_replace_start = open_idx
	_as_reference = is_ref
	_query = query

	_refresh_suggestions()

func hide_popup() -> void:
	if visible:
		hide()
	_replace_start = -1
	_query = ""

# ============================================================
# SUGGESTIONS
# ============================================================

func _refresh_suggestions() -> void:
	if not _key_provider.is_valid():
		hide_popup()
		return

	var keys: PackedStringArray = _key_provider.call()
	if keys.is_empty():
		hide_popup()
		return

	# Filter by query.
	var q_lower: String = _query.to_lower()
	_filtered = PackedStringArray()
	for k in keys:
		if q_lower.is_empty() or k.to_lower().find(q_lower) != -1:
			_filtered.append(k)

	if _filtered.is_empty():
		hide_popup()
		return

	# Populate list.
	_list.clear()
	var count: int = mini(_filtered.size(), MAX_VISIBLE)
	for i in range(count):
		var key: String = _filtered[i]
		var label: String
		if _as_reference:
			label = "{@%s}" % key
		else:
			label = "{%s}" % key
		_list.add_item(label)
		_list.set_item_metadata(i, key)

	if _list.item_count > 0:
		_list.select(0)

	# Update header.
	var header: Label = get_node_or_null("RootVBox/Header")
	if header:
		var mode: String = "Key Reference" if _as_reference else "Argument / Key"
		header.text = "%s — %d match(es)" % [mode, _filtered.size()]

	_popup_below_caret()

func _popup_below_caret() -> void:
	if not _target:
		return

	# Position below the caret.
	var caret_pos: Vector2 = _target.get_caret_draw_pos()
	var local_pos: Vector2 = caret_pos + Vector2(0, 20)
	var global_pos: Vector2 = _target.get_global_position() + local_pos

	# Re-parent to target if needed (so global position is correct).
	if get_parent() != _target:
		if get_parent():
			get_parent().remove_child(self)
		_target.add_child(self)

	popup(Rect2i(Vector2i(global_pos), Vector2i(POPUP_W, POPUP_H)))

# ============================================================
# SELECTION
# ============================================================

func _on_item_activated(index: int) -> void:
	_apply_selection(index)

func _apply_selection(index: int) -> void:
	if not _target or _replace_start < 0:
		hide_popup()
		return

	var key: String = ""
	var meta = _list.get_item_metadata(index)
	if meta is String:
		key = meta
	if key.is_empty():
		hide_popup()
		return

	var caret: int = _target.get_caret_column()
	var line_text: String = _target.get_line(0)

	# Build new text: everything before `{` + placeholder + everything after caret.
	var prefix: String = line_text.substr(0, _replace_start)
	var suffix: String = line_text.substr(caret)

	var placeholder: String
	if _as_reference:
		placeholder = "{@%s}" % key
	else:
		placeholder = "{%s}" % key

	var new_text: String = prefix + placeholder + suffix
	var new_caret: int = prefix.length() + placeholder.length()

	_target.text = new_text
	_target.set_caret_line(0)
	_target.set_caret_column(new_caret)

	hide_popup()
	key_selected.emit(key, _as_reference)

# ============================================================
# INPUT HANDLING
# ============================================================

## Called by the TextEdit when the popup is open. Returns true if the
## key event was consumed.
func handle_key(event: InputEventKey) -> bool:
	if not visible:
		return false

	var key: int = event.keycode

	if key == KEY_ESCAPE:
		hide_popup()
		return true

	if key == KEY_UP:
		var idx: PackedInt32Array = _list.get_selected_items()
		var next: int
		if idx.is_empty():
			next = _list.item_count - 1
		else:
			next = (idx[0] - 1 + _list.item_count) % _list.item_count
		_list.select(next)
		_list.ensure_current_is_visible()
		return true

	if key == KEY_DOWN:
		var idx2: PackedInt32Array = _list.get_selected_items()
		var next2: int
		if idx2.is_empty():
			next2 = 0
		else:
			next2 = (idx2[0] + 1) % _list.item_count
		_list.select(next2)
		_list.ensure_current_is_visible()
		return true

	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_TAB:
		var sel: PackedInt32Array = _list.get_selected_items()
		if sel.is_empty():
			hide_popup()
			return false
		_apply_selection(sel[0])
		return true

	return false