@tool
class_name BayterekTooltip
extends Control
## Node hover tooltip.

@export var label: RichTextLabel

func inspect(node: BayterekNodeButton) -> void:
	# TODO
	pass

func reset() -> void:
	if label:
		label.text = ""
