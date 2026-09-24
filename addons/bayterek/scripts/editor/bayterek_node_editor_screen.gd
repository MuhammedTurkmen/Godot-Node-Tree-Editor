@tool
class_name BayterekNodeEditorScreen
extends MarginContainer
## Top-level "Node Editor" tab.

const DEFAULT_MAIN_SPLIT := 220
const DEFAULT_RIGHT_SPLIT := -280
const COLLAPSED_MAIN_SPLIT := 0

signal design_category_changed

var _main_split: HSplitContainer
var _right_split: HSplitContainer
var _design_list: BayterekDesignListPanel
var _layer_editor: BayterekLayerEditor
var _preview_panel: BayterekLayerPreviewPanel
var _empty_label: Label
var _current_design: BayterekNodeDesign = null

var _last_expanded_offset: int = DEFAULT_MAIN_SPLIT

func _ready() -> void:
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_bottom", 4)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	_main_split = HSplitContainer.new()
	_main_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_main_split)

	_design_list = BayterekDesignListPanel.new()
	_design_list.custom_minimum_size = Vector2(220, 0)
	_design_list.size_flags_vertical = SIZE_EXPAND_FILL
	_design_list.design_selected.connect(_on_design_selected)
	_design_list.collapsed_changed.connect(_on_design_list_collapsed_changed)
	_design_list.design_category_changed.connect(_on_design_category_changed)
	_main_split.add_child(_design_list)

	_right_split = HSplitContainer.new()
	_right_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_right_split.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.split_offset = DEFAULT_RIGHT_SPLIT
	_main_split.add_child(_right_split)

	var middle_stack := Control.new()
	middle_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	middle_stack.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.add_child(middle_stack)

	_layer_editor = BayterekLayerEditor.new()
	_layer_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	_layer_editor.size_flags_vertical = SIZE_EXPAND_FILL
	_layer_editor.visible = false
	middle_stack.add_child(_layer_editor)
	_layer_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer_editor.changed.connect(func(): _preview_panel.refresh())

	_empty_label = Label.new()
	_empty_label.text = "Select a design from the left, or create a new one."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	middle_stack.add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_preview_panel = BayterekLayerPreviewPanel.new()
	_preview_panel.custom_minimum_size = Vector2(220, 0)
	_preview_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_right_split.add_child(_preview_panel)

	_main_split.split_offset = DEFAULT_MAIN_SPLIT

func refresh() -> void:
	if _design_list:
		_design_list.refresh()

# ============================================================
# CALLBACKS
# ============================================================

func _on_design_selected(design: BayterekNodeDesign) -> void:
	_current_design = design
	if design:
		_layer_editor.visible = true
		_empty_label.visible = false
		_layer_editor.set_design(design)
		_preview_panel.set_design(design)
	else:
		_layer_editor.visible = false
		_empty_label.visible = true
		_layer_editor.set_design(null)
		_preview_panel.set_design(null)

func _on_design_list_collapsed_changed(collapsed: bool) -> void:
	if not _main_split:
		return

	if collapsed:
		if _main_split.split_offset > 0:
			_last_expanded_offset = _main_split.split_offset
		_main_split.split_offset = COLLAPSED_MAIN_SPLIT
	else:
		_main_split.split_offset = max(_last_expanded_offset, DEFAULT_MAIN_SPLIT)

	_main_split.queue_sort()

func _on_design_category_changed() -> void:
	design_category_changed.emit()