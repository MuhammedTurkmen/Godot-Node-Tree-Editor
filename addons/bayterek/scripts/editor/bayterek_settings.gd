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
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_label = Label.new()
	_label.text = "Settings — yakında (4.3)"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func init() -> void:
	pass

func load_tree(tree_data: BayterekTree) -> void:
	pass