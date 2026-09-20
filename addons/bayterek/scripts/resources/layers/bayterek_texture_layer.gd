@tool
class_name BayterekTextureLayer
extends BayterekLayer
## Texture (icon) layer. State-driven texture + tint.

# --- Icon ---
@export_storage var icon_enabled: bool = true
## state -> {"enabled": bool, "texture": Texture2D}
@export_storage var icon_configs: Dictionary = {}

# --- Tint ---
@export_storage var tint_enabled: bool = false
## state -> {"enabled": bool, "color": Color}
@export_storage var tint_configs: Dictionary = {}

func _init() -> void:
	super._init()
	layer_name = "Texture"
	icon_configs = {
		"normal": {"enabled": true, "texture": null},
	}
	tint_configs = _make_default_tint_configs()

## Default tint colors — same palette as shape fill.
## All disabled by default — user enables the states they want.
static func _make_default_tint_configs() -> Dictionary:
	return {
		"normal":           {"enabled": false, "color": Color("7FB8FF")},
		"hover":            {"enabled": false, "color": Color("FFD966")},
		"locked":           {"enabled": false, "color": Color("666666")},
		"preallocated":     {"enabled": false, "color": Color("FFA640")},
		"prerefund":        {"enabled": false, "color": Color("FF8080")},
		"max_level":        {"enabled": false, "color": Color("FFE066")},
		"allocateable":     {"enabled": false, "color": Color("8EF58E")},
		"not_allocateable": {"enabled": false, "color": Color("FF6666")},
	}

# ============================================================
# STATE CHECKBOX
# ============================================================

func _is_state_checkbox_on(state: String) -> bool:
	if icon_enabled and _is_config_enabled(icon_configs, state):
		return true
	if tint_enabled and _is_config_enabled(tint_configs, state):
		return true
	return false

func _is_config_enabled(configs: Dictionary, state: String) -> bool:
	if not configs.has(state):
		return false
	var entry = configs[state]
	if not entry is Dictionary:
		return false
	return entry.get("enabled", false)

# ============================================================
# RESOLUTION
# ============================================================

func get_icon_for_state(state_key: String) -> Texture2D:
	if not icon_enabled:
		return null
	if _is_config_enabled(icon_configs, state_key):
		var tex = icon_configs[state_key].get("texture", null)
		if tex:
			return tex
	if _is_config_enabled(icon_configs, "normal"):
		return icon_configs["normal"].get("texture", null)
	return null

func get_tint_for_state(state_key: String) -> Color:
	if not tint_enabled:
		return Color.WHITE
	if _is_config_enabled(tint_configs, state_key):
		return tint_configs[state_key].get("color", Color.WHITE)
	if _is_config_enabled(tint_configs, "normal"):
		return tint_configs["normal"].get("color", Color.WHITE)
	return Color.WHITE

func should_draw_icon(state_key: String) -> bool:
	if not icon_enabled:
		return false
	if _is_config_enabled(icon_configs, state_key) and icon_configs[state_key].get("texture", null) != null:
		return true
	if _is_config_enabled(icon_configs, "normal") and icon_configs["normal"].get("texture", null) != null:
		return true
	return false

# ============================================================
# CONFIG SETTERS
# ============================================================

func set_icon_config(state: String, enabled: bool, texture: Texture2D) -> void:
	icon_configs[state] = {"enabled": enabled, "texture": texture}

func set_tint_config(state: String, enabled: bool, color: Color) -> void:
	tint_configs[state] = {"enabled": enabled, "color": color}

func ensure_icon_config(state: String) -> void:
	if not icon_configs.has(state):
		icon_configs[state] = {"enabled": false, "texture": null}

func ensure_tint_config(state: String) -> void:
	if not tint_configs.has(state):
		tint_configs[state] = {"enabled": false, "color": Color.WHITE}

# ============================================================
# DUPLICATE
# ============================================================

func duplicate_layer() -> BayterekLayer:
	var copy := BayterekTextureLayer.new()
	_copy_base_to(copy)
	copy.icon_enabled = icon_enabled
	copy.icon_configs = icon_configs.duplicate(true)
	copy.tint_enabled = tint_enabled
	copy.tint_configs = tint_configs.duplicate(true)
	return copy

func _to_string() -> String:
	return "BayterekTextureLayer(name='%s')" % layer_name