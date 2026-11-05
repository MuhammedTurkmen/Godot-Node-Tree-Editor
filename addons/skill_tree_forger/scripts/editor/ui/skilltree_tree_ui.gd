@tool
class_name SkillTreeUI
extends Tree
## Yeniden adlandırma destekli Tree.

signal edit_started(item: TreeItem)
signal edit_canceled(item: TreeItem)

@export var rename_shortcut: Shortcut

func init() -> void:
	create_item()
