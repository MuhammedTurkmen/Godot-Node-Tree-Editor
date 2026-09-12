@tool
class_name BayterekEditor
extends Control
## Graph editörü (Faz 3'te doldurulacak).

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)

var tree: BayterekTree
var tree_path: String
var dirty: bool = false

var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func load_tree(path: String) -> void:
	tree_path = path
	tree = Bayterek.get_editor_registry().get_tree_by_path(path)
	if tree:
		_label.text = "Tree: %s\n\n(Graph editörü Faz 3'te gelecek.)" % tree.name
	else:
		_label.text = "Tree yüklenemedi: %s" % path

func request_close() -> void:
	closed.emit()