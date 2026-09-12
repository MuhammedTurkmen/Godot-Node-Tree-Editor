@tool
class_name BayterekSettingsEditor
extends Control
## Tree Settings editörü.

signal changed
signal size_changed
signal border_scale_changed
signal background_changed
signal icon_size_changed
signal node_size_changed
signal line_texture_changed
signal revealed_changed
signal allocation_changed
signal preallocation_changed
signal multiallocation_changed

var editor: BayterekEditor

# UI referansları
var _content: VBoxContainer
var _updating_ui: bool = false

# Version
var _version_input: SpinBox

# Size
var _size_x_input: SpinBox
var _size_y_input: SpinBox

# Border Scale
var _border_scale_input: SpinBox

# Background
var _bg_color_picker: ColorPickerButton

# Icon Sizes
var _small_icon_x: SpinBox
var _small_icon_y: SpinBox
var _medium_icon_x: SpinBox
var _medium_icon_y: SpinBox
var _large_icon_x: SpinBox
var _large_icon_y: SpinBox

# Node Sizes
var _small_size_x: SpinBox
var _small_size_y: SpinBox
var _medium_size_x: SpinBox
var _medium_size_y: SpinBox
var _large_size_x: SpinBox
var _large_size_y: SpinBox

# Interaction
var _revealed_check: CheckBox
var _allocation_check: CheckBox
var _preallocation_check: CheckBox
var _multiallocation_check: CheckBox

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()

func init() -> void:
	# load_tree() öncesi gerekli bir şey yok
	pass

# ============================================================
# UI KURULUM
# ============================================================

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	# --- Version ---
	_version_input = _make_int_row(_content, "Version", "Tree versiyonu (runtime uyumluluk için)")
	_version_input.min_value = 1
	_version_input.value = 1
	_version_input.allow_greater = true
	_version_input.value_changed.connect(_on_version_changed)

	# --- Size ---
	_size_x_input = _make_int_row(_content, "Size X", "Tree alanı genişliği (px)")
	_size_x_input.min_value = 100
	_size_x_input.value = 5000
	_size_x_input.allow_greater = true
	_size_x_input.value_changed.connect(_on_size_changed)

	_size_y_input = _make_int_row(_content, "Size Y", "Tree alanı yüksekliği (px)")
	_size_y_input.min_value = 100
	_size_y_input.value = 5000
	_size_y_input.allow_greater = true
	_size_y_input.value_changed.connect(_on_size_changed)

	# --- Border Scale ---
	_border_scale_input = _make_float_row(_content, "Border Scale", "Node border ölçek çarpanı")
	_border_scale_input.min_value = 0.1
	_border_scale_input.max_value = 10.0
	_border_scale_input.step = 0.1
	_border_scale_input.value = 1.5
	_border_scale_input.allow_greater = true
	_border_scale_input.value_changed.connect(_on_border_scale_changed)

	# --- Background ---
	_bg_color_picker = _make_color_row(_content, "Background Color", "Tree arka plan rengi")
	_bg_color_picker.color = Color(0.1, 0.1, 0.1)
	_bg_color_picker.color_changed.connect(_on_bg_color_changed)

	# --- Icon Sizes ---
	_add_separator(_content)
	_add_section_label(_content, "Icon Sizes (S/M/L)")

	_small_icon_x = _make_int_pair_row(_content, "Small", "X")
	_small_icon_x.value_changed.connect(_on_small_icon_changed)
	_small_icon_y = _make_int_pair_row_end("Y")
	_small_icon_y.value_changed.connect(_on_small_icon_changed)

	_medium_icon_x = _make_int_pair_row(_content, "Medium", "X")
	_medium_icon_x.value_changed.connect(_on_medium_icon_changed)
	_medium_icon_y = _make_int_pair_row_end("Y")
	_medium_icon_y.value_changed.connect(_on_medium_icon_changed)

	_large_icon_x = _make_int_pair_row(_content, "Large", "X")
	_large_icon_x.value_changed.connect(_on_large_icon_changed)
	_large_icon_y = _make_int_pair_row_end("Y")
	_large_icon_y.value_changed.connect(_on_large_icon_changed)

	# --- Node Sizes ---
	_add_separator(_content)
	_add_section_label(_content, "Node Sizes (S/M/L)")

	_small_size_x = _make_int_pair_row(_content, "Small", "X")
	_small_size_x.value = 27
	_small_size_x.value_changed.connect(_on_small_size_changed)
	_small_size_y = _make_int_pair_row_end("Y")
	_small_size_y.value = 27
	_small_size_y.value_changed.connect(_on_small_size_changed)

	_medium_size_x = _make_int_pair_row(_content, "Medium", "X")
	_medium_size_x.value = 48
	_medium_size_x.value_changed.connect(_on_medium_size_changed)
	_medium_size_y = _make_int_pair_row_end("Y")
	_medium_size_y.value = 48
	_medium_size_y.value_changed.connect(_on_medium_size_changed)

	_large_size_x = _make_int_pair_row(_content, "Large", "X")
	_large_size_x.value = 64
	_large_size_x.value_changed.connect(_on_large_size_changed)
	_large_size_y = _make_int_pair_row_end("Y")
	_large_size_y.value = 64
	_large_size_y.value_changed.connect(_on_large_size_changed)

	# --- Interaction ---
	_add_separator(_content)
	_add_section_label(_content, "Interaction")

	_revealed_check = _make_check_row(_content, "Revealed", "Tüm ağaç görünür mü")
	_revealed_check.button_pressed = true
	_revealed_check.toggled.connect(_on_revealed_changed)

	_allocation_check = _make_check_row(_content, "Allocation", "Node'lara tıklanabilir mi")
	_allocation_check.button_pressed = true
	_allocation_check.toggled.connect(_on_allocation_changed)

	_preallocation_check = _make_check_row(_content, "Preallocation", "Ön onay akışı")
	_preallocation_check.button_pressed = true
	_preallocation_check.toggled.connect(_on_preallocation_changed)

	_multiallocation_check = _make_check_row(_content, "Multi-allocation", "Seviyeli allocation")
	_multiallocation_check.toggled.connect(_on_multiallocation_changed)

# ============================================================
# TREE YÜKLEME
# ============================================================

func load_tree(tree_data: BayterekTree) -> void:
	if not tree_data:
		return
	if not _content:
		return

	_updating_ui = true

	_version_input.set_value_no_signal(tree_data.version)
	_size_x_input.set_value_no_signal(tree_data.size.x)
	_size_y_input.set_value_no_signal(tree_data.size.y)
	_border_scale_input.set_value_no_signal(tree_data.border_scale)
	_bg_color_picker.color = tree_data.bg_color

	# Icon Sizes
	var small_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.SMALL, Vector2.ZERO)
	var medium_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.MEDIUM, Vector2.ZERO)
	var large_icon: Vector2 = tree_data.icon_sizes.get(BayterekNode.NodeType.LARGE, Vector2.ZERO)
	_small_icon_x.set_value_no_signal(small_icon.x)
	_small_icon_y.set_value_no_signal(small_icon.y)
	_medium_icon_x.set_value_no_signal(medium_icon.x)
	_medium_icon_y.set_value_no_signal(medium_icon.y)
	_large_icon_x.set_value_no_signal(large_icon.x)
	_large_icon_y.set_value_no_signal(large_icon.y)

	# Node Sizes
	var small_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.SMALL, Vector2(27, 27))
	var medium_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.MEDIUM, Vector2(48, 48))
	var large_size: Vector2 = tree_data.node_size.get(BayterekNode.NodeType.LARGE, Vector2(64, 64))
	_small_size_x.set_value_no_signal(small_size.x)
	_small_size_y.set_value_no_signal(small_size.y)
	_medium_size_x.set_value_no_signal(medium_size.x)
	_medium_size_y.set_value_no_signal(medium_size.y)
	_large_size_x.set_value_no_signal(large_size.x)
	_large_size_y.set_value_no_signal(large_size.y)

	# Interaction
	_revealed_check.button_pressed = tree_data.revealed
	_allocation_check.button_pressed = tree_data.allocation
	_preallocation_check.button_pressed = tree_data.preallocation
	_multiallocation_check.button_pressed = tree_data.multiallocation

	_updating_ui = false

# ============================================================
# HANDLER'LAR
# ============================================================

func _on_version_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.version = int(value)
	changed.emit()
	_notify_dirty()

func _on_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.size = Vector2(_size_x_input.value, _size_y_input.value)
	size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_border_scale_changed(value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.border_scale = value
	border_scale_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_bg_color_changed(color: Color) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.bg_color = color
	background_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_small_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.SMALL] = Vector2(_small_icon_x.value, _small_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_medium_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.MEDIUM] = Vector2(_medium_icon_x.value, _medium_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_large_icon_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.icon_sizes[BayterekNode.NodeType.LARGE] = Vector2(_large_icon_x.value, _large_icon_y.value)
	icon_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_small_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.SMALL] = Vector2(_small_size_x.value, _small_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_medium_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.MEDIUM] = Vector2(_medium_size_x.value, _medium_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_large_size_changed(_value: float) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.node_size[BayterekNode.NodeType.LARGE] = Vector2(_large_size_x.value, _large_size_y.value)
	node_size_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_revealed_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.revealed = pressed
	revealed_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_allocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.allocation = pressed
	allocation_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_preallocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.preallocation = pressed
	preallocation_changed.emit()
	changed.emit()
	_notify_dirty()

func _on_multiallocation_changed(pressed: bool) -> void:
	if _updating_ui or not editor or not editor.tree:
		return
	editor.tree.multiallocation = pressed
	multiallocation_changed.emit()
	changed.emit()
	_notify_dirty()

# ============================================================
# YARDIMCI
# ============================================================

func _notify_dirty() -> void:
	if editor and editor.has_method("set_dirty"):
		editor.set_dirty(true)

func _make_int_row(parent: Control, label_text: String, tooltip: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin

func _make_float_row(parent: Control, label_text: String, tooltip: String = "") -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = false
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = 0.01
	row.add_child(spin)

	return spin

func _make_color_row(parent: Control, label_text: String, tooltip: String = "") -> ColorPickerButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.size_flags_horizontal = SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 24)
	row.add_child(picker)

	return picker

func _make_check_row(parent: Control, label_text: String, tooltip: String = "") -> CheckBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var check := CheckBox.new()
	check.text = "On"
	check.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(check)

	return check

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	parent.add_child(label)

# ============================================================
# ICON/NODE SIZE ÇİFT SATIRLARI
# ============================================================
# Bu iki fonksiyon, "Small Node" satırı ile X/Y satırlarını
# ayrı ayrı oluşturmak yerine tek satırlık bir HBox içine
# iki spinbox (X ve Y) yerleştirir.

func _make_int_pair_row(parent: Control, label_text: String, axis: String) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(70, 0)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	var x_label := Label.new()
	x_label.text = "X"
	x_label.custom_minimum_size = Vector2(20, 0)
	x_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	row.add_child(x_label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin

func _make_int_pair_row_end(axis: String) -> SpinBox:
	# Bu fonksiyon, bir önceki satıra Y spinbox'ı eklemek için
	# aslında parent'ı kullanır. Basitlik için ayrı bir satıra
	# yerleştiriyoruz.
	var parent := _content
	var row := HBoxContainer.new()
	parent.add_child(row)

	var spacer := Label.new()
	spacer.text = ""
	spacer.custom_minimum_size = Vector2(70, 0)
	row.add_child(spacer)

	var y_label := Label.new()
	y_label.text = "Y"
	y_label.custom_minimum_size = Vector2(20, 0)
	y_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	row.add_child(y_label)

	var spin := SpinBox.new()
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.rounded = true
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.min_value = 0
	spin.max_value = 999999
	row.add_child(spin)

	return spin