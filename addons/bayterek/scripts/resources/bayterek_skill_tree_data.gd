@tool
class_name BayterekSkillTreeData
extends Resource
## JSON-backed skill tree dataset.
##
## This resource is a TRANSIENT in-memory view of the JSON file at
## `<tree_path>.json`. It is NOT saved to disk as .tres — the JSON
## remains the source of truth.
##
## Structure (new schema v2):
##   - currency_attributes → currency attribute DEFINITIONS (gold, gems, ...)
##   - skill_attributes    → non-currency attribute definitions
##   - nodes               → node structure + per-node values
##   - wallet_defaults     → starting wallet VALUES (gold=100, gems=10)
##   - initial_allocated / initial_levels → starting allocation state

@export_storage var tree_id: String = ""
@export_storage var tree_name: String = ""

## Currency attribute DEFINITIONS. Key = attribute id, value = BayterekAttribute.
## These describe "what is gold" — name, icon, refund behavior.
@export_storage var currency_attributes: Dictionary = {}

## Non-currency attribute definitions. Key = attribute id, value = BayterekAttribute.
@export_storage var skill_attributes: Dictionary = {}

## Node definitions (structure only; values are in `node.attributes`).
@export_storage var nodes: Array[BayterekNode] = []

## Flat list of connections derived from `node.out_nodes`.
## Each entry: {"from": int, "to": int}
@export_storage var connections: Array = []

## Initial allocation state.
@export_storage var initial_allocated: Array[int] = []
@export_storage var initial_levels: Dictionary = {}

## Initial wallet VALUES (not definitions). Key = attribute id, value = int.
## Example: {"gold": 100, "gems": 10}
@export_storage var wallet_defaults: Dictionary = {}

# ============================================================
# QUERY
# ============================================================

func get_all_attributes() -> Dictionary:
	var merged: Dictionary = {}
	for attr_id in currency_attributes.keys():
		merged[attr_id] = currency_attributes[attr_id]
	for attr_id in skill_attributes.keys():
		merged[attr_id] = skill_attributes[attr_id]
	return merged

func get_currency_attribute(attr_id: String) -> BayterekAttribute:
	return currency_attributes.get(attr_id, null)

func get_skill_attribute(attr_id: String) -> BayterekAttribute:
	return skill_attributes.get(attr_id, null)

func get_attribute(attr_id: String) -> BayterekAttribute:
	var a = currency_attributes.get(attr_id, null)
	if a:
		return a
	return skill_attributes.get(attr_id, null)

func get_node_by_id(node_id: int) -> BayterekNode:
	for n in nodes:
		if n and n.id == node_id:
			return n
	return null