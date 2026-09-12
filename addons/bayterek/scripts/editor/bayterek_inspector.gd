@tool
class_name BayterekTreeEditorInspector
extends Control
## Node Inspector.

signal changed

var editor: BayterekEditor

var _current_node: BayterekNodeButton
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_label = Label.new()
	_label.text = "Select a node to inspect"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func init(tree_view: BayterekTreeView) -> void:
	# TODO: 4.2'de detaylandırılacak
	pass

func inspect(node: BayterekNodeButton) -> void:
	_current_node = node
	if not _label:
		return
	if not node:
		_label.text = "Select a node to inspect"
	else:
		_label.text = "Node: %s (id=%d)" % [node.node_name, node.id]