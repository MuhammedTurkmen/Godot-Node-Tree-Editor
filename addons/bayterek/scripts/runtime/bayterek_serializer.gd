@tool
extends Node
## Autoload: BayterekSerializer. Runtime tree state kaydetme / yükleme.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

const OLD_SAVE_PATH := "user://bayterek"
const SAVE_PATH := "user://bayterek_v2"

func save_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	# TODO
	pass

func load_tree_state(tree: BayterekTree, custom_path: String = "") -> void:
	# TODO
	pass
