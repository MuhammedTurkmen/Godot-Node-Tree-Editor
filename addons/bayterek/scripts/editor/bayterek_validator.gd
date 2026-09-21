@tool
class_name BayterekValidator
extends Control
## Validates tree configuration and shows warnings/errors.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")
const FadeOut = preload("res://addons/bayterek/scripts/editor/ui/fade_out.gd")

signal validation_finished(warning_count: int, error_count: int)

@export var editor: BayterekEditor

const VALIDATION_DELAY := 500

enum WarningType {
	TREE_WIDTH_TOO_SMALL,
	TREE_HEIGHT_TOO_SMALL,
	BORDER_SCALE_INVALID,
	NORMAL_LINE_TEXTURE_NOT_SET,
	INTERMEDIATE_LINE_TEXTURE_NOT_SET,
	ACTIVE_LINE_TEXTURE_NOT_SET,
	PREALLOCATION_WITHOUT_ALLOCATION,
	MULTIALLOCATION_WITHOUT_ALLOCATION,
}

enum ErrorType {
	NO_ROOT_NODE,
}

const WARNING_MESSAGES := {
	WarningType.TREE_WIDTH_TOO_SMALL: "Tree width is too small. Recommended at least 100 pixels.",
	WarningType.TREE_HEIGHT_TOO_SMALL: "Tree height is too small. Recommended at least 100 pixels.",
	WarningType.BORDER_SCALE_INVALID: "Border scale is invalid. Recommended at least 0.1.",
	WarningType.NORMAL_LINE_TEXTURE_NOT_SET: "Normal line texture is not set.",
	WarningType.INTERMEDIATE_LINE_TEXTURE_NOT_SET: "Intermediate line texture is not set.",
	WarningType.ACTIVE_LINE_TEXTURE_NOT_SET: "Active line texture is not set.",
	WarningType.PREALLOCATION_WITHOUT_ALLOCATION: "Pre-allocation is enabled without allocation.",
	WarningType.MULTIALLOCATION_WITHOUT_ALLOCATION: "Multi-allocation is enabled without allocation.",
}

const ERROR_MESSAGES := {
	ErrorType.NO_ROOT_NODE: "No root node is set. Select at least one node as root.",
}

var _warning_btn: Button
var _error_btn: Button
var _prints_container: VBoxContainer

var _warnings: Array[int] = []
var _errors: Array[int] = []

var _validation_start: float = 0.0
var _validation_scheduled: bool = false

func init() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "ButtonsRow"
	buttons_row.anchor_left = 1.0
	buttons_row.anchor_top = 1.0
	buttons_row.anchor_right = 1.0
	buttons_row.anchor_bottom = 1.0
	buttons_row.offset_left = -140
	buttons_row.offset_top = -32
	buttons_row.offset_right = -10
	buttons_row.offset_bottom = -8
	buttons_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	buttons_row.add_theme_constant_override("separation", 4)
	buttons_row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(buttons_row)

	_warning_btn = Button.new()
	_warning_btn.name = "WarningButton"
	_warning_btn.text = "0"
	_warning_btn.tooltip_text = "Warnings"
	_warning_btn.visible = false
	_warning_btn.flat = false
	_warning_btn.pressed.connect(_on_warning_btn_pressed)
	buttons_row.add_child(_warning_btn)

	_error_btn = Button.new()
	_error_btn.name = "ErrorButton"
	_error_btn.text = "0"
	_error_btn.tooltip_text = "Errors"
	_error_btn.visible = false
	_error_btn.flat = false
	_error_btn.pressed.connect(_on_error_btn_pressed)
	buttons_row.add_child(_error_btn)

	_prints_container = VBoxContainer.new()
	_prints_container.name = "PrintsContainer"
	_prints_container.anchor_left = 1.0
	_prints_container.anchor_top = 1.0
	_prints_container.anchor_right = 1.0
	_prints_container.anchor_bottom = 1.0
	_prints_container.offset_left = -400
	_prints_container.offset_top = -300
	_prints_container.offset_right = -10
	_prints_container.offset_bottom = -40
	_prints_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prints_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prints_container.alignment = BoxContainer.ALIGNMENT_END
	_prints_container.add_theme_constant_override("separation", 4)
	_prints_container.visible = false
	_prints_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_prints_container)

# ============================================================
# PUBLIC API
# ============================================================

func validate() -> void:
	_validation_start = Time.get_ticks_msec()
	_validation_scheduled = true

func validate_now() -> void:
	_run_validation()

# ============================================================
# PROCESS — debounce
# ============================================================

func _process(_delta: float) -> void:
	if _validation_scheduled:
		if Time.get_ticks_msec() - _validation_start >= VALIDATION_DELAY:
			_run_validation()
			_validation_scheduled = false

# ============================================================
# VALIDATION
# ============================================================

func _run_validation() -> void:
	if not editor or not editor.tree:
		_warnings.clear()
		_errors.clear()
		_update_ui()
		return

	var tree: BayterekTree = editor.tree

	_warnings = _check_warnings(tree)
	_errors = _check_errors(tree)

	_update_ui()
	validation_finished.emit(_warnings.size(), _errors.size())

func _check_warnings(tree: BayterekTree) -> Array[int]:
	var result: Array[int] = []

	if tree.size.x < 100:
		result.append(WarningType.TREE_WIDTH_TOO_SMALL)
	if tree.size.y < 100:
		result.append(WarningType.TREE_HEIGHT_TOO_SMALL)
	if tree.border_scale < 0.1:
		result.append(WarningType.BORDER_SCALE_INVALID)
	if not tree.line_texture_normal:
		result.append(WarningType.NORMAL_LINE_TEXTURE_NOT_SET)
	if not tree.line_texture_intermediate:
		result.append(WarningType.INTERMEDIATE_LINE_TEXTURE_NOT_SET)
	if not tree.line_texture_active:
		result.append(WarningType.ACTIVE_LINE_TEXTURE_NOT_SET)
	if tree.preallocation and not tree.allocation:
		result.append(WarningType.PREALLOCATION_WITHOUT_ALLOCATION)
	if tree.multiallocation and not tree.allocation:
		result.append(WarningType.MULTIALLOCATION_WITHOUT_ALLOCATION)

	return result

func _check_errors(tree: BayterekTree) -> Array[int]:
	var result: Array[int] = []

	if tree.allocation:
		var root_found: bool = false
		for node_data in tree.nodes:
			if node_data.is_root:
				root_found = true
				break
		if not root_found:
			result.append(ErrorType.NO_ROOT_NODE)

	return result

# ============================================================
# UI UPDATE
# ============================================================

func _update_ui() -> void:
	var has_warnings: bool = _warnings.size() > 0
	var has_errors: bool = _errors.size() > 0

	_warning_btn.visible = has_warnings
	_error_btn.visible = has_errors
	_warning_btn.text = str(_warnings.size())
	_error_btn.text = str(_errors.size())

	visible = has_warnings or has_errors

	if has_warnings:
		_warning_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	if has_errors:
		_error_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_warning_btn_pressed() -> void:
	_clear_prints()
	for warning in _warnings:
		var message: String = WARNING_MESSAGES.get(warning, "Unknown warning")
		_create_message_panel(message, Color(1, 0.85, 0.4))
	_prints_container.visible = true

func _on_error_btn_pressed() -> void:
	_clear_prints()
	for error in _errors:
		var message: String = ERROR_MESSAGES.get(error, "Unknown error")
		_create_message_panel(message, Color(1, 0.4, 0.4))
	_prints_container.visible = true

# ============================================================
# MESSAGE PANELS
# ============================================================

func _clear_prints() -> void:
	for child in _prints_container.get_children():
		child.queue_free()

func _create_message_panel(message: String, color: Color) -> void:
	var panel := FadeOut.new()
	panel.interactable = false

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.fit_content = true
	label.custom_minimum_size = Vector2(350, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.push_color(color)
	label.append_text(message)
	label.pop()

	panel.add_child(label)
	_prints_container.add_child(panel)