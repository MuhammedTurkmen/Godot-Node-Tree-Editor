@tool
class_name BayterekPrefabsBar
extends TabBar
## Prefab bottom bar — Small/Medium/Large/Decoration tabs.

signal changed

var editor: BayterekEditor

var _panel_scene: PackedScene
var _container: Control
var _prefabs_panel: Control

func init(p_panel_scene: PackedScene, p_container: Control, p_prefabs_panel: Control) -> void:
	_panel_scene = p_panel_scene
	_container = p_container
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
		return

	var panel: Control = _prefabs_panel.get_child(tab_index)
	panel.visible = true

	if panel.has_method("refresh"):
		panel.refresh()