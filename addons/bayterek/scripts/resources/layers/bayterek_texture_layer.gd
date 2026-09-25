@tool
class_name BayterekTextureLayer
extends BayterekLayer
## Texture (icon) layer. State-driven texture + tint + nine-patch support.

## How the texture is drawn inside the layer's bounding box.
enum StretchMode {
	STRETCH,        ## Scale texture to fill the box (distorts aspect).
	KEEP_ASPECT,    ## Fit inside the box, preserve aspect (letterbox).
	TILE,           ## Tile the texture at native size.
	NINE_PATCH,     ## 9-slice using texture_margin_* values.
}

# --- Icon ---
@export_storage var icon_enabled: bool = true
## state -> {"enabled": bool, "texture": Texture2D}
@export_storage var icon_configs: Dictionary = {}

# --- Tint ---
@export_storage var tint_enabled: bool = false
## state -> {"enabled": bool, "color": Color}
@export_storage var tint_configs: Dictionary = {}

# --- Stretch / Nine-Patch ---
## How the texture is placed inside the layer's box.
@export_storage var stretch_mode: StretchMode = StretchMode.STRETCH

## Nine-patch margins (left, top, right, bottom) in texture pixels.
## Only used when stretch_mode == NINE_PATCH.
@export_storage var nine_patch_margin_left: int = 8
@export_storage var nine_patch_margin_top: int = 8
@export_storage var nine_patch_margin_right: int = 8
@export_storage var nine_patch_margin_bottom: int = 8

## Skip drawing the center region of the nine-patch (transparent center).
@export_storage var nine_patch_draw_center: bool = true

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
		"clicked":          {"enabled": false, "color": Color("B38A00")},
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
# NINE PATCH HELPERS
# ============================================================

## Returns the nine-patch margins as a Vector4 for the given texture.
## (left, top, right, bottom) in texture pixels.
func get_nine_patch_margins() -> Vector4:
	return Vector4(
		float(nine_patch_margin_left),
		float(nine_patch_margin_top),
		float(nine_patch_margin_right),
		float(nine_patch_margin_bottom)
	)

## Whether the layer should use nine-patch rendering.
func uses_nine_patch() -> bool:
	return stretch_mode == StretchMode.NINE_PATCH

## Whether the layer should tile the texture.
func uses_tile() -> bool:
	return stretch_mode == StretchMode.TILE

## Whether the layer should preserve aspect ratio.
func keeps_aspect() -> bool:
	return stretch_mode == StretchMode.KEEP_ASPECT

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
	copy.stretch_mode = stretch_mode
	copy.nine_patch_margin_left = nine_patch_margin_left
	copy.nine_patch_margin_top = nine_patch_margin_top
	copy.nine_patch_margin_right = nine_patch_margin_right
	copy.nine_patch_margin_bottom = nine_patch_margin_bottom
	copy.nine_patch_draw_center = nine_patch_draw_center
	return copy

func _to_string() -> String:
	return "BayterekTextureLayer(name='%s', stretch=%s)" % [layer_name, StretchMode.keys()[stretch_mode]]