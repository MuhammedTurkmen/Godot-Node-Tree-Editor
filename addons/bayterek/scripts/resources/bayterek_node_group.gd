@tool
class_name BayterekNodeGroup
extends Resource
## Bir node grubu — görsel gruplama + mantıksal prerequisite için.

@export_storage var id: String = ""
@export_storage var name: String = "New Group"
@export_storage var color: Color = Color(0.4, 0.7, 1.0, 1.0)

## Bu gruba ait node ID'leri. Kaynak: BayterekNode.group_id ile senkron tutulur.
@export_storage var node_ids: Array[int] = []

# ============================================================
# ID GENERATION
# ============================================================

static func generate_id() -> String:
	return BayterekUUIDGenerator.v4()

# ============================================================
# MEMBERSHIP
# ============================================================

func add_node_id(node_id: int) -> void:
	if node_ids.has(node_id):
		return
	node_ids.append(node_id)

func remove_node_id(node_id: int) -> void:
	node_ids.erase(node_id)

func has_node_id(node_id: int) -> bool:
	return node_ids.has(node_id)

func clear() -> void:
	node_ids.clear()