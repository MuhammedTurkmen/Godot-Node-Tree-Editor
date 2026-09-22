@tool
class_name BayterekLocalizationPreviewPanel
extends MarginContainer
## Right-hand preview panel for the Editor tab.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")
const Service = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_service.gd")
const Format = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization_format_string.gd")

var _root: VBoxContainer
var _key_label: Label
var _original_label: RichTextLabel
var _current_label: RichTextLabel
var _resolved_label: RichTextLabel
var _args_container: VBoxContainer
var _issues_container: VBoxContainer
var _empty_label: Label

var _arg_inputs: Dictionary = {}

var _row_key: String = ""
var _original_value: String = ""
var _current_value: String = ""
var _lookup: Callable = Callable()
var _active_lookup: Callable = Callable()
var _current_locale: String = ""

var _external_broken: bool = false
var _external_cyclic: bool = false
var _external_cycle_path: Array[String] = []

const SAMPLE_PREFIX := "‹"
const SAMPLE_SUFFIX := "›"

var _refreshing: bool = false

func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	clip_contents = true

	_build()

func _build() -> void:
	_root = VBoxContainer.new()
	_root.name = "PreviewRoot"
	_root.add_theme_constant_override("separation", 8)
	_root.size_flags_horizontal = SIZE_EXPAND_FILL
	_root.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_root)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 6)
	_root.add_child(key_row)

	var key_lbl := Label.new()
	key_lbl.text = "Key:"
	key_lbl.custom_minimum_size.x = 60
	key_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	key_row.add_child(key_lbl)

	_key_label = Label.new()
	_key_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_key_label.clip_text = true
	_key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	key_row.add_child(_key_label)

	_root.add_child(_section_label("Original"))
	_original_label = _make_rtl()
	_root.add_child(_original_label)

	_root.add_child(_section_label("Current"))
	_current_label = _make_rtl()
	_root.add_child(_current_label)

	_root.add_child(_section_label("Resolved"))
	_resolved_label = _make_rtl()
	_root.add_child(_resolved_label)

	_root.add_child(_section_label("Test Arguments"))
	_args_container = VBoxContainer.new()
	_args_container.add_theme_constant_override("separation", 3)
	_root.add_child(_args_container)

	_root.add_child(_section_label("Issues"))
	_issues_container = VBoxContainer.new()
	_issues_container.add_theme_constant_override("separation", 3)
	_root.add_child(_issues_container)

	_empty_label = Label.new()
	_empty_label.text = "Select a row to preview."
	_empty_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_empty_label)

	_show_empty()

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl

func _make_rtl() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(0, 22)
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rtl

# ============================================================
# PUBLIC API
# ============================================================

func set_lookup(callback: Callable) -> void:
	_lookup = callback
	_active_lookup = callback

func show_row(
	key: String,
	original: String,
	current: String,
	current_locale: String,
	broken_ref: bool = false,
	cyclic: bool = false,
	cycle_path: Array[String] = [],
	lookup_override: Callable = Callable()
) -> void:
	_row_key = key
	_original_value = original
	_current_value = current
	_current_locale = current_locale
	_external_broken = broken_ref
	_external_cyclic = cyclic
	_external_cycle_path = cycle_path
	_active_lookup = lookup_override if lookup_override.is_valid() else _lookup

	_show_content()
	_refresh()

func clear() -> void:
	_row_key = ""
	_original_value = ""
	_current_value = ""
	_external_broken = false
	_external_cyclic = false
	_external_cycle_path = []
	_active_lookup = _lookup
	_clear_arg_inputs()
	_show_empty()

# ============================================================
# INTERNAL
# ============================================================

func _show_empty() -> void:
	if _empty_label:
		_empty_label.visible = true
	if _key_label:
		_key_label.visible = false
	if _original_label:
		_original_label.visible = false
	if _current_label:
		_current_label.visible = false
	if _resolved_label:
		_resolved_label.visible = false
	if _args_container:
		_args_container.visible = false
	if _issues_container:
		_issues_container.visible = false

func _show_content() -> void:
	if _empty_label:
		_empty_label.visible = false
	if _key_label:
		_key_label.visible = true
	if _original_label:
		_original_label.visible = true
	if _current_label:
		_current_label.visible = true
	if _resolved_label:
		_resolved_label.visible = true
	if _args_container:
		_args_container.visible = true
	if _issues_container:
		_issues_container.visible = true

func _refresh() -> void:
	if _refreshing:
		return
	_refreshing = true

	_key_label.text = _row_key
	_original_label.text = _to_bbcode(_original_value)
	_current_label.text = _to_bbcode(_current_value)

	_rebuild_args_inputs()
	_rebuild_resolved()
	_rebuild_issues()

	_root.queue_sort()
	queue_sort()

	_refreshing = false

func _clear_arg_inputs() -> void:
	_arg_inputs.clear()

# ============================================================
# ARGS
# ============================================================

func _rebuild_args_inputs() -> void:
	var preserved: Dictionary = {}
	for name in _arg_inputs.keys():
		var prev = _arg_inputs[name]
		if is_instance_valid(prev) and prev is LineEdit:
			preserved[name] = (prev as LineEdit).text

	for child in _args_container.get_children():
		child.queue_free()
	_arg_inputs.clear()

	var args: PackedStringArray = Format.extract_args(_current_value)
	if args.is_empty():
		var none := Label.new()
		none.text = "(no arguments needed)"
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		none.add_theme_font_size_override("font_size", 11)
		_args_container.add_child(none)
		return

	for name in args:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl := Label.new()
		lbl.text = name
		lbl.custom_minimum_size.x = 80
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

		var edit := LineEdit.new()
		edit.size_flags_horizontal = SIZE_EXPAND_FILL
		edit.placeholder_text = "sample value"
		if preserved.has(name):
			edit.text = preserved[name]
		edit.text_changed.connect(_on_arg_changed)
		row.add_child(edit)

		_args_container.add_child(row)
		_arg_inputs[name] = edit

# ============================================================
# RESOLVED PREVIEW
# ============================================================

func _rebuild_resolved() -> void:
	var args := _collect_args()
	var out: String = Format.resolve_visible(_current_value, args, _active_lookup)
	_resolved_label.text = _to_bbcode(out)

func _collect_args() -> Dictionary:
	var args: Dictionary = {}
	for name in _arg_inputs.keys():
		var edit = _arg_inputs[name]
		if not is_instance_valid(edit) or not (edit is LineEdit):
			continue
		var le: LineEdit = edit
		if not le.text.strip_edges().is_empty():
			args[name] = le.text
		else:
			args[name] = "%s%s%s" % [SAMPLE_PREFIX, name, SAMPLE_SUFFIX]
	return args

func _on_arg_changed(_text: String) -> void:
	if _refreshing:
		return
	_refreshing = true
	_rebuild_resolved()
	_rebuild_issues()
	_refreshing = false

# ============================================================
# ISSUES
# ============================================================

func _rebuild_issues() -> void:
	for child in _issues_container.get_children():
		child.queue_free()

	var issues: Array = []

	# 1) Cycle (highest priority).
	if _external_cyclic:
		var text: String = "Cycle detected"
		if _external_cycle_path.size() > 0:
			text += ": " + " → ".join(_external_cycle_path)
		issues.append({"text": text, "color": Color(0.85, 0.6, 1.0)})

	# 2) Broken references.
	if _external_broken and not _external_cyclic:
		var refs: PackedStringArray = Format.extract_key_references(_current_value)
		for ref in refs:
			var res = _active_lookup.call(ref) if _active_lookup.is_valid() else ""
			if res == null or String(res).is_empty():
				issues.append({
					"text": "Reference not found: {@%s}" % ref,
					"color": Color(1.0, 0.4, 0.4),
				})

	# 3) Placeholder mismatch (only compares {arg} placeholders).
	if not _original_value.is_empty() and not _current_value.is_empty():
		var cmp: Dictionary = Format.compare_placeholders(_original_value, _current_value)
		var missing: PackedStringArray = cmp.get("missing", [])
		var extra: PackedStringArray = cmp.get("extra", [])
		for m in missing:
			issues.append({
				"text": "Missing placeholder: {%s}" % m,
				"color": Color(1.0, 0.75, 0.4),
			})
		for e in extra:
			issues.append({
				"text": "Extra placeholder: {%s}" % e,
				"color": Color(1.0, 0.75, 0.4),
			})

	if issues.is_empty():
		var ok := Label.new()
		ok.text = "✓ No issues"
		ok.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		ok.add_theme_font_size_override("font_size", 11)
		_issues_container.add_child(ok)
		return

	for issue in issues:
		var lbl := Label.new()
		lbl.text = "⚠ " + issue["text"]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", issue["color"])
		lbl.add_theme_font_size_override("font_size", 11)
		_issues_container.add_child(lbl)

# ============================================================
# HELPERS
# ============================================================

func _to_bbcode(text: String) -> String:
	if text.is_empty():
		return "[color=#888888](empty)[/color]"

	var out: String = ""
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]

		if c == "{":
			var close_idx: int = text.find("}", i + 1)
			if close_idx == -1:
				out += _escape(text.substr(i))
				break

			var inner: String = text.substr(i + 1, close_idx - i - 1).strip_edges()
			if inner.is_empty():
				out += _escape(text.substr(i, close_idx - i + 1))
			else:
				var seg: String = text.substr(i, close_idx - i + 1)
				var color: String = "#c68eff" if inner.begins_with("@") else "#8eb4ff"
				out += "[color=%s][b]%s[/b][/color]" % [color, _escape(seg)]

			i = close_idx + 1
		else:
			var next_open: int = text.find("{", i)
			if next_open == -1:
				out += _escape(text.substr(i))
				break
			out += _escape(text.substr(i, next_open - i))
			i = next_open

	return out

func _escape(s: String) -> String:
	return s.replace("[", "[[")