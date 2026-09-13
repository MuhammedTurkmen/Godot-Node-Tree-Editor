@tool
class_name BayterekPrefabsBar
extends TabBar
## Prefab alt bar — Small/Medium/Large/Decoration sekmeleri.

signal changed

var editor: BayterekEditor

var _panel_scene: PackedScene
var _splitter: SplitContainer
var _prefabs_panel: Control

func init(p_panel_scene: PackedScene, p_splitter: SplitContainer, p_prefabs_panel: Control) -> void:
	_panel_scene = p_panel_scene
	_splitter = p_splitter
	_prefabs_panel = p_prefabs_panel

	deselect_enabled = true

	add_tab("Small Nodes")
	add_tab("Medium Nodes")
	add_tab("Large Nodes")
	add_tab("Decorations")

	if _prefabs_panel:
		for i in 4:
			var panel: BayterekPrefabPanelEditor = BayterekPrefabPanelEditor.new()
			panel.name = "Panel_%d" % i
			panel.visible = false
			panel.editor = editor
			_prefabs_panel.add_child(panel)
			panel.init()

	current_tab = -1

	tab_changed.connect(_on_tab_changed)

func _on_tab_changed(tab_index: int) -> void:
	for i in _prefabs_panel.get_child_count():
		var p: Control = _prefabs_panel.get_child(i)
		p.visible = false

	if tab_index < 0:
		if _splitter:
			_splitter.collapsed = true
		return

	var panel: Control = _prefabs_panel.get_child(tab_index)
	panel.visible = true
	if _splitter:
		_splitter.collapsed = false