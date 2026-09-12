@tool
class_name BayterekTreeView
extends Control
## Runtime tree görünümü.

signal node_created(node: BayterekNode)
signal node_allocated(node: BayterekNode)
signal node_deallocated(node: BayterekNode)
signal prefab_created(prefab: BayterekPrefab)
signal line_created(line: BayterekConnection, from_id: int, to_id: int)
signal tree_version_mismatch(tree: BayterekTree, saved_version: int)

var main_container: Control
var nodes_container: Control
var lines_container: Control
var decorations_container: Control
var background_container: Control

var camera: BayterekCamera
var nodes_service: BayterekNodesService
var connections_service: BayterekConnectionsService
var decorations_service: BayterekDecorationsService
var prefabs_service: BayterekPrefabsService
var allocation_service: BayterekAllocationService

var _tree_data: BayterekTree

func load_tree(tree_data: BayterekTree, decoration_scene: PackedScene, node_scene: PackedScene, line_scene: PackedScene, tooltip_scene: PackedScene) -> void:
	# TODO
	pass
