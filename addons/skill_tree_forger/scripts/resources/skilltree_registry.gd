@tool
class_name SkillTreeRegistry
extends Resource
## Tüm grupları tutan kök resource.

@export_storage var groups: Array[SkillTreeGroup] = []

func find_group_by_path(path: String) -> SkillTreeGroup:
	for g in groups:
		if g.resource_path == path:
			return g
	return null

func get_tree_by_path(path: String) -> SkillTree:
	for g in groups:
		for t in g.trees:
			if t.resource_path == path:
				return t
	return null