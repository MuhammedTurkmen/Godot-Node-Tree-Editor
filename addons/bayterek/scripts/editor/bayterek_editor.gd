@tool
class_name BayterekEditor
extends Control
## Graph editörü.

signal closed
signal dirty_changed(editor: BayterekEditor, dirty: bool)

var tree: BayterekTree
var tree_path: String
var dirty: bool = false

var tree_view: BayterekTreeView

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func load_tree(path: String) -> void:
	tree_path = path
	tree = Bayterek.get_editor_registry().get_tree_by_path(path)

	if not tree:
		push_error("Bayterek: Tree yüklenemedi: %s" % path)
		return

	_create_tree_view()

func _create_tree_view() -> void:
	tree_view = BayterekTreeView.new()
	tree_view.name = "TreeView"
	add_child(tree_view)
	tree_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_view.load_tree(tree)

func request_close() -> void:
	closed.emit()