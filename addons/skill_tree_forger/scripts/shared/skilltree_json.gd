@tool
class_name SkillTreeJson
extends RefCounted
## Static helpers to read/write the skill tree JSON file.
##
## Schema v2:
##   {
##     "meta": { version, tree_id, tree_name, format },
##     "currencies": { "<id>": { name, name_key, icon, default, refund_differs } },
##     "attributes": {
##       "skills": { "<id>": { name, name_key, effect_key, effect, operation, cumulative, value_count } }
##     },
##     "nodes": [ ... ],
##     "wallet": { "<id>": int },
##     "allocated": { "nodes": [int], "levels": { "id": int } }
##   }
##
## For backwards compatibility, `dict_to_data()` also accepts the v1
## schema where currency definitions lived under `attributes.wallet`
## and wallet values lived under `defaults.wallet`.

const FORMAT_ID := "bayterek-skill-tree"
const FORMAT_VERSION := 2

# ============================================================
# LOAD / SAVE
# ============================================================

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("SkillTreeJson: file not found: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("SkillTreeJson: cannot open %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("SkillTreeJson: parse error at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return {}

	if not (json.data is Dictionary):
		push_error("SkillTreeJson: root must be an object")
		return {}
	return json.data

static func save_file(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return FileAccess.get_open_error()

	var text := JSON.stringify(data, "  ")
	f.store_string(text)
	f.close()
	return OK

# ============================================================
# DICT <-> DATA
# ============================================================

## Builds a `SkillTreeData` from the raw JSON dictionary.
##
## Supports BOTH the old schema (v1: attributes.wallet) and the new
## schema (v2: currencies + wallet).
##
## Currency values are CLAMPED to >= 0. If a manually edited JSON
## contains negative values, they are silently converted to 0.
static func dict_to_data(raw: Dictionary) -> SkillTreeData:
	var data := SkillTreeData.new()

	var meta: Dictionary = raw.get("meta", {})
	data.tree_id = String(meta.get("tree_id", ""))
	data.tree_name = String(meta.get("tree_name", ""))

	var format_version: int = int(meta.get("version", 1))

	# --- Currencies ---
	var currencies_raw: Dictionary = {}
	if raw.has("currencies"):
		currencies_raw = raw.get("currencies", {})
	else:
		var attrs_legacy: Dictionary = raw.get("attributes", {})
		currencies_raw = attrs_legacy.get("wallet", {})

	data.currency_attributes = _build_attributes(currencies_raw, true)

	# --- Skill attributes ---
	var attrs: Dictionary = raw.get("attributes", {})
	data.skill_attributes = _build_attributes(attrs.get("skills", {}), false)

	# --- Nodes ---
	var nodes_arr: Array = raw.get("nodes", [])
	for n in nodes_arr:
		if not (n is Dictionary):
			continue
		var node := _dict_to_node(n)
		if node:
			data.nodes.append(node)
			for out_id in node.out_nodes:
				data.connections.append({"from": node.id, "to": out_id})

	# --- Wallet values ---
	if raw.has("wallet"):
		data.wallet_defaults = _to_int_dict(raw.get("wallet", {}))
	else:
		var defaults_legacy: Dictionary = raw.get("defaults", {})
		data.wallet_defaults = _to_int_dict(defaults_legacy.get("wallet", {}))

	# --- Initial allocation ---
	var alloc: Dictionary = raw.get("allocated", {})
	data.initial_allocated = _to_int_array(alloc.get("nodes", []))
	data.initial_levels = _to_int_dict(alloc.get("levels", {}))

	# --- Sanitize: clamp negative currency values to 0 ---
	# We check each node's attributes against the currency list.
	for node in data.nodes:
		if not node:
			continue
		for attr_id in node.attributes.keys():
			var attr: SkillTreeAttribute = null
			if data.currency_attributes.has(attr_id):
				attr = data.currency_attributes[attr_id]
			elif data.skill_attributes.has(attr_id):
				attr = data.skill_attributes[attr_id]

			if not attr or not attr.is_currency:
				continue

			var raw_vals = node.attributes[attr_id]
			if not raw_vals is Array:
				continue

			if raw_vals.size() > 0 and raw_vals[0] is Array:
				for lvl in raw_vals:
					if not lvl is Array:
						continue
					for i in lvl.size():
						if typeof(lvl[i]) == TYPE_INT or typeof(lvl[i]) == TYPE_FLOAT:
							if lvl[i] < 0:
								lvl[i] = 0
			else:
				for i in raw_vals.size():
					if typeof(raw_vals[i]) == TYPE_INT or typeof(raw_vals[i]) == TYPE_FLOAT:
						if raw_vals[i] < 0:
							raw_vals[i] = 0

	return data

## Serializes a `SkillTreeData` back to a JSON dictionary
## using the v2 schema.
static func data_to_dict(data: SkillTreeData) -> Dictionary:
	if not data:
		return {}

	var out: Dictionary = {
		"meta": {
			"version": FORMAT_VERSION,
			"tree_id": data.tree_id,
			"tree_name": data.tree_name,
			"format": FORMAT_ID,
		},
		"currencies": _serialize_attributes(data.currency_attributes, true),
		"attributes": {
			"skills": _serialize_attributes(data.skill_attributes, false),
		},
		"nodes": [],
		"wallet": data.wallet_defaults.duplicate(),
		"allocated": {
			"nodes": data.initial_allocated.duplicate(),
			"levels": data.initial_levels.duplicate(),
		},
	}

	for node in data.nodes:
		if not node:
			continue
		out["nodes"].append(_node_to_dict(node))

	return out

# ============================================================
# ATTRIBUTE BUILD
# ============================================================

static func _build_attributes(raw: Dictionary, is_currency: bool) -> Dictionary:
	var result: Dictionary = {}
	for attr_id in raw.keys():
		var spec = raw[attr_id]
		if not (spec is Dictionary):
			continue
		var attr := SkillTreeAttribute.new()
		attr.id = String(attr_id)
		attr.name = String(spec.get("name", attr_id))
		attr.name_key = String(spec.get("name_key", ""))
		attr.effect_key = String(spec.get("effect_key", ""))
		attr.effect = String(spec.get("effect", ""))
		attr.is_currency = is_currency
		attr.refund_differs = bool(spec.get("refund_differs", false))
		attr.cumulative = bool(spec.get("cumulative", false))
		attr.value_count = int(spec.get("value_count", 1))
		attr.operation = _parse_operation(String(spec.get("operation", "add")))
		attr.icon = _load_texture(String(spec.get("icon", "")))
		attr.icon_atlas_path = String(spec.get("icon_atlas_path", ""))

		var region_raw = spec.get("icon_region", null)
		if region_raw is Dictionary:
			attr.icon_region = Rect2(
				float(region_raw.get("x", 0.0)),
				float(region_raw.get("y", 0.0)),
				float(region_raw.get("w", 0.0)),
				float(region_raw.get("h", 0.0))
			)
			if attr.icon is AtlasTexture:
				var atlas: AtlasTexture = attr.icon
				atlas.region = attr.icon_region
		elif attr.icon is AtlasTexture:
			# JSON'da region yoksa mevcut atlas region'ını al
			var atlas2: AtlasTexture = attr.icon
			attr.icon_region = atlas2.region

		attr.sync_value_count()
		result[attr_id] = attr
	return result


static func _serialize_attributes(attrs: Dictionary, is_currency: bool) -> Dictionary:
	var out: Dictionary = {}
	for attr_id in attrs.keys():
		var attr: SkillTreeAttribute = attrs[attr_id]
		if not attr:
			continue
		var spec: Dictionary = {
			"name": attr.name,
			"name_key": attr.name_key,
			"effect_key": attr.effect_key,
			"effect": attr.effect,
		}
		if is_currency:
			spec["refund_differs"] = attr.refund_differs
			if attr.icon:
				spec["icon"] = attr.icon.resource_path
				if attr.icon is AtlasTexture:
					var atlas: AtlasTexture = attr.icon
					var r: Rect2 = atlas.region
					spec["icon_region"] = {
						"x": r.position.x,
						"y": r.position.y,
						"w": r.size.x,
						"h": r.size.y,
					}
					spec["icon_atlas_path"] = attr.icon_atlas_path
		else:
			spec["operation"] = _operation_to_string(attr.operation)
			spec["cumulative"] = attr.cumulative
			spec["value_count"] = attr.value_count
		out[attr_id] = spec
	return out

# ============================================================
# NODE BUILD
# ============================================================

static func _dict_to_node(raw: Dictionary) -> SkillTreeNode:
	var node := SkillTreeNode.new()
	node.id = int(raw.get("id", 0))
	node.name = String(raw.get("name", ""))
	node.name_key = String(raw.get("name_key", ""))
	node.description = String(raw.get("description", ""))   # ← FIX: read description
	node.design_id = String(raw.get("design_id", ""))
	node.is_root = bool(raw.get("is_root", false))
	node.max_allocations = int(raw.get("max_allocations", 1))
	node.group_id = String(raw.get("group_id", ""))

	var pos: Dictionary = raw.get("position", {})
	node.position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))

	var prereq: Dictionary = raw.get("prerequisite", {})
	node.prerequisite_mode = _parse_prereq_mode(String(prereq.get("mode", "any")))
	node.prerequisite_count = int(prereq.get("count", 1))
	node.prerequisite_group_id = String(prereq.get("group_id", ""))

	var conn: Dictionary = raw.get("connections", {})
	var out_list: Array = conn.get("out", [])
	var in_list: Array = conn.get("in", [])
	var out_typed: Array[int] = []
	for v in out_list:
		out_typed.append(int(v))
	var in_typed: Array[int] = []
	for v in in_list:
		in_typed.append(int(v))
	node.out_nodes = out_typed
	node.in_nodes = in_typed

	# --- Values ---
	var values: Dictionary = raw.get("values", {})
	for attr_id in values.keys():
		var v = values[attr_id]
		if not (v is Dictionary):
			continue
		var levels: Array = v.get("levels", [])
		var levels_typed: Array = []
		for lvl in levels:
			if lvl is Array:
				var inner: Array = []
				for n in lvl:
					inner.append(int(n))
				levels_typed.append(inner)
			elif lvl is int or lvl is float:
				levels_typed.append([int(lvl)])
		node.attributes[String(attr_id)] = levels_typed

	return node

static func _node_to_dict(node: SkillTreeNode) -> Dictionary:
	var out: Dictionary = {
		"id": node.id,
		"name": node.name,
		"name_key": node.name_key,
		"description": node.description,   # ← FIX: write description
		"design_id": node.design_id,
		"is_root": node.is_root,
		"max_allocations": node.max_allocations,
		"group_id": node.group_id,
		"position": {"x": node.position.x, "y": node.position.y},
		"prerequisite": {
			"mode": _prereq_mode_to_string(node.prerequisite_mode),
			"count": node.prerequisite_count,
			"group_id": node.prerequisite_group_id,
		},
		"connections": {
			"out": node.out_nodes.duplicate(),
			"in": node.in_nodes.duplicate(),
		},
		"values": {},
	}

	for attr_id in node.attributes.keys():
		var levels = node.attributes[attr_id]
		if levels is Array:
			out["values"][attr_id] = {"levels": levels.duplicate(true)}

	return out

# ============================================================
# ENUM HELPERS
# ============================================================

static func _parse_operation(s: String) -> SkillTreeAttribute.Operation:
	match s.to_lower():
		"add":      return SkillTreeAttribute.Operation.ADD
		"subtract": return SkillTreeAttribute.Operation.SUBTRACT
		"set":      return SkillTreeAttribute.Operation.SET
		"multiply": return SkillTreeAttribute.Operation.MULTIPLY
		"min":      return SkillTreeAttribute.Operation.MIN
		"max":      return SkillTreeAttribute.Operation.MAX
		_: return SkillTreeAttribute.Operation.ADD

static func _operation_to_string(op: SkillTreeAttribute.Operation) -> String:
	match op:
		SkillTreeAttribute.Operation.ADD:      return "add"
		SkillTreeAttribute.Operation.SUBTRACT: return "subtract"
		SkillTreeAttribute.Operation.SET:      return "set"
		SkillTreeAttribute.Operation.MULTIPLY: return "multiply"
		SkillTreeAttribute.Operation.MIN:      return "min"
		SkillTreeAttribute.Operation.MAX:      return "max"
		_: return "add"

static func _parse_prereq_mode(s: String) -> SkillTreeNode.PrerequisiteMode:
	match s.to_lower():
		"any":             return SkillTreeNode.PrerequisiteMode.ANY
		"count":           return SkillTreeNode.PrerequisiteMode.COUNT
		"all":             return SkillTreeNode.PrerequisiteMode.ALL
		"group_complete":  return SkillTreeNode.PrerequisiteMode.GROUP_COMPLETE
		_: return SkillTreeNode.PrerequisiteMode.ANY

static func _prereq_mode_to_string(m: SkillTreeNode.PrerequisiteMode) -> String:
	match m:
		SkillTreeNode.PrerequisiteMode.ANY:            return "any"
		SkillTreeNode.PrerequisiteMode.COUNT:          return "count"
		SkillTreeNode.PrerequisiteMode.ALL:            return "all"
		SkillTreeNode.PrerequisiteMode.GROUP_COMPLETE: return "group_complete"
		_: return "any"

# ============================================================
# SMALL HELPERS
# ============================================================

static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func _to_int_array(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out

static func _to_int_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v.keys():
			out[String(k)] = int(v[k])
	return out