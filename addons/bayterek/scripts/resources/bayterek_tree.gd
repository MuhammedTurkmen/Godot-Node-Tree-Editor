@tool
class_name BayterekTree
extends Resource
## Main tree data.

@export_storage var version: int = 1
@export_storage var id: String
@export_storage var name: String
@export_storage var revealed: bool = true
@export_storage var allocation: bool = true
@export_storage var preallocation: bool = true
@export_storage var multiallocation: bool = false
@export_storage var chain_connection_mode: bool = true

@export_storage var allocation_confirm: bool = false
@export_storage var refund_confirm: bool = false

@export_storage var show_group_frames: bool = true
@export_storage var group_frame_title_align: int = 0

@export_storage var hover_animations_enabled: bool = true

@export_storage var tooltip_header_align: int = 0
@export_storage var tooltip_body_align: int = 0
@export_storage var tooltip_footer_align: int = 1

@export_storage var size: Vector2 = Vector2(5000, 5000)
@export_storage var bg_color: Color = Color(0.1, 0.1, 0.1)
@export_storage var bg_texture: Texture2D

@export_storage var texture_filter: int = 0

@export_storage var id_counter: int = 0
@export_storage var border_scale: float = 1.5

@export_storage var nodes: Array[BayterekNode] = []
@export_storage var decorations: Array[BayterekNode] = []
@export_storage var prefabs: Array[BayterekPrefab] = []
@export_storage var attributes: Dictionary = {}
@export_storage var node_groups: Array[BayterekNodeGroup] = []

@export_storage var hierarchy_split_offset: int = 200
@export_storage var prefabs_split_offset: int = -180
@export_storage var inspector_split_offset: int = -320

@export_storage var prefabs_bar_visible: bool = true

@export_storage var default_design_id: String = ""

# ============================================================
# CONNECTION DEFAULTS
# ============================================================

@export_storage var default_line_color: Color = Color(0.7, 0.7, 0.7, 0.9)
@export_storage var default_line_thickness: float = 4.0
@export_storage var state_color_enabled: bool = false
@export_storage var line_alloc_color: Color = Color(0.56, 0.96, 0.56)
@export_storage var line_non_alloc_color: Color = Color(1.0, 0.4, 0.4)
@export_storage var default_start_offset: float = 8.0
@export_storage var default_end_offset: float = 12.0
@export_storage var default_arrow_scale: Vector2 = Vector2.ONE
@export_storage var line_antialiasing: bool = true

## Default line texture applied to freshly-created connections.
## This is the ONLY line-texture slot on the tree now — the old
## `line_texture_normal / _intermediate / _active` state-based
## textures were removed.
@export_storage var default_line_texture: Texture2D = null
## Texture mode (matches BayterekLineData.TextureMode):
##   0 = NONE, 1 = TILE, 2 = STRETCH, 3 = TILE_FIT_HEIGHT
@export_storage var default_line_texture_mode: int = 1
## Texture filter (matches BayterekLineData.TEXTURE_FILTER_*):
##   0 = INHERIT, 1 = LINEAR, 2 = NEAREST
@export_storage var default_line_texture_filter: int = 0
@export_storage var default_line_texture_scale: Vector2 = Vector2.ONE
@export_storage var default_line_texture_tint: Color = Color.WHITE

# ============================================================
# WIGGLE DEFAULTS
# ============================================================

@export_storage var wiggle_enabled: bool = false
@export_storage var wiggle_base_amplitude: float = 2.0
@export_storage var wiggle_frequency: float = 2.0
@export_storage var wiggle_speed: float = 1.0
@export_storage var wiggle_pattern: int = 0
@export_storage var wiggle_active_boost: float = 1.5
@export_storage var wiggle_use_hover_intensity: bool = true
@export_storage var wiggle_follow_node_animation: bool = true
@export_storage var wiggle_direction_mode: int = 0

var tree_state: BayterekTreeState

func _init() -> void:
	nodes = []
	decorations = []
	prefabs = []
	attributes = {}
	node_groups = []
	tree_state = BayterekTreeState.new()

	hierarchy_split_offset = 200
	prefabs_split_offset = -180
	inspector_split_offset = -320

func get_next_id() -> int:
	id_counter += 1
	return id_counter

func get_godot_texture_filter() -> int:
	match texture_filter:
		1: return CanvasItem.TEXTURE_FILTER_NEAREST
		_: return CanvasItem.TEXTURE_FILTER_LINEAR

# ============================================================
# PREFAB HELPERS
# ============================================================

func get_prefab_by_reference_id(reference_id: String) -> BayterekPrefab:
	if reference_id.is_empty():
		return null
	for p in prefabs:
		if p and p.reference_id == reference_id:
			return p
	return null

func add_prefab(prefab: BayterekPrefab) -> void:
	if not prefab:
		return
	if prefabs.has(prefab):
		return
	prefabs.append(prefab)

func remove_prefab(prefab: BayterekPrefab) -> void:
	prefabs.erase(prefab)

# ============================================================
# GROUP HELPERS
# ============================================================

func get_group_by_id(group_id: String) -> BayterekNodeGroup:
	if group_id.is_empty():
		return null
	for g in node_groups:
		if g and g.id == group_id:
			return g
	return null

func add_group(group: BayterekNodeGroup) -> void:
	if not group:
		return
	if group.id.is_empty():
		group.id = BayterekNodeGroup.generate_id()
	node_groups.append(group)

func remove_group(group: BayterekNodeGroup) -> void:
	node_groups.erase(group)

func get_group_of_node(node_id: int) -> BayterekNodeGroup:
	for node_data in nodes:
		if node_data.id == node_id:
			if node_data.group_id.is_empty():
				return null
			return get_group_by_id(node_data.group_id)
	return null

# ============================================================
# CONNECTION DEFAULTS APPLICATION
# ============================================================

## Applies the tree's connection defaults to a BayterekLineData.
##
## RESPECTS PER-FIELD OVERRIDES:
##   If a field was marked as overridden (via `set_overridden(true)`),
##   this function will NOT touch it.
##
## If `force` is true, all overrides are cleared and every field is
## reset — useful for a "reset to defaults" action.
func apply_connection_defaults(line_data: BayterekLineData, force: bool = false) -> void:
	if not line_data:
		return

	if force:
		line_data.clear_all_overrides()

	# --- Base style ---
	if force or not line_data.is_overridden("color"):
		line_data.color = default_line_color
	if force or not line_data.is_overridden("thickness"):
		line_data.thickness = default_line_thickness
	if force or not line_data.is_overridden("smooth_antialiasing"):
		line_data.smooth_antialiasing = line_antialiasing

	# --- Default line texture (single slot) ---
	if force or not line_data.is_overridden("line_texture"):
		line_data.line_texture = default_line_texture
	if force or not line_data.is_overridden("texture_mode"):
		line_data.texture_mode = default_line_texture_mode as BayterekLineData.TextureMode
	if force or not line_data.is_overridden("texture_filter_override"):
		line_data.texture_filter_override = default_line_texture_filter
	if force or not line_data.is_overridden("texture_scale"):
		line_data.texture_scale = default_line_texture_scale
	if force or not line_data.is_overridden("texture_tint"):
		line_data.texture_tint = default_line_texture_tint

	# --- Offsets ---
	if force or not line_data.is_overridden("start_offset"):
		line_data.start_offset = default_start_offset
	if force or not line_data.is_overridden("end_offset"):
		line_data.end_offset = default_end_offset

	# --- Arrow ---
	if force or not line_data.is_overridden("arrow_scale"):
		line_data.arrow_scale = default_arrow_scale

	# --- Wiggle ---
	if force or not line_data.is_overridden("wiggle_enabled"):
		line_data.wiggle_enabled = wiggle_enabled
	if force or not line_data.is_overridden("wiggle_base_amplitude"):
		line_data.wiggle_base_amplitude = wiggle_base_amplitude
	if force or not line_data.is_overridden("wiggle_frequency"):
		line_data.wiggle_frequency = wiggle_frequency
	if force or not line_data.is_overridden("wiggle_speed"):
		line_data.wiggle_speed = wiggle_speed
	if force or not line_data.is_overridden("wiggle_pattern"):
		line_data.wiggle_pattern = wiggle_pattern as BayterekLineData.WigglePattern
	if force or not line_data.is_overridden("wiggle_active_boost"):
		line_data.wiggle_active_boost = wiggle_active_boost
	if force or not line_data.is_overridden("wiggle_use_hover_intensity"):
		line_data.wiggle_use_hover_intensity = wiggle_use_hover_intensity
	if force or not line_data.is_overridden("wiggle_direction_mode"):
		line_data.wiggle_direction_mode = wiggle_direction_mode as BayterekLineData.WiggleDirectionMode

# ============================================================
# BULK DEFAULTS APPLICATION
# ============================================================

func apply_defaults_to_all_lines(force: bool = false) -> int:
	var count: int = 0

	for node_data in nodes:
		if not node_data:
			continue
		if not node_data.line_data:
			continue

		for to_id in node_data.line_data.keys():
			var line_data = node_data.line_data[to_id]
			if line_data is BayterekLineData:
				apply_connection_defaults(line_data, force)
				count += 1

	return count