@tool
class_name BayterekLayerNode
extends Node2D
## Renders a single BayterekTextureLayer as a child node.
##
## Structure:
##   BayterekLayerNode (Node2D)   <- transform (position, scale, rotation, skew, flip)
##     └── TextureRect/NinePatchRect   <- texture + filter + stretch mode
##
## This design lets each texture layer have:
##   - Its own transform (including skew and rotation)
##   - Its own texture_filter (per-layer filter works)
##   - Its own nine-patch margins
##   - Its own z_index (set by the parent, controls draw order)

const RENDER_MODE_VECTOR := 0
const RENDER_MODE_PIXEL := 1

var layer: BayterekTextureLayer = null
var _rect: Control = null  # TextureRect or NinePatchRect

var _last_state_key: String = ""
var _last_tex_hash: int = 0

# ============================================================
# PUBLIC API
# ============================================================

## Assigns (or changes) the layer this node renders.
func set_layer(new_layer: BayterekTextureLayer) -> void:
	if layer == new_layer and _rect and is_instance_valid(_rect):
		return
	layer = new_layer
	_rebuild_rect()

## Updates the state key (which texture + tint to use).
## Called whenever the design changes or hover/allocation state changes.
func set_state(state_key: String) -> void:
	if _last_state_key == state_key:
		# Still update (transform may have changed)
		pass
	_last_state_key = state_key

## Updates the layer's transform and texture based on the design.
## `design_size` — the design's fallback size (usually design.design_size).
## `pixel_mode` — whether the layer should snap to pixels.
func update(design_size: Vector2, pixel_mode: bool) -> void:
	if not layer or not _rect or not is_instance_valid(_rect):
		return

	# --- Texture ---
	var state_key: String = _last_state_key
	if state_key.is_empty():
		state_key = "normal"

	var tex: Texture2D = layer.get_icon_for_state(state_key)
	var tint: Color = layer.get_tint_for_state(state_key)

	_apply_texture(tex)
	_apply_tint(tint)
	_apply_filter()

	# --- Transform ---
	var layer_matrix: Transform2D = layer.get_matrix(design_size, pixel_mode)
	transform = layer_matrix

	# --- Layout ---
	var effective_size: Vector2 = layer.get_size(design_size)
	var half: Vector2 = effective_size * 0.5

	_rect.position = -half
	_rect.size = effective_size
	_rect.pivot_offset = half
	_rect.rotation = 0.0

	_rect.visible = (tex != null)

# ============================================================
# INTERNAL
# ============================================================

func _rebuild_rect() -> void:
	# Remove old rect
	if _rect and is_instance_valid(_rect):
		_rect.queue_free()
		_rect = null

	if not layer:
		return

	var use_nine_patch: bool = layer.stretch_mode == BayterekTextureLayer.StretchMode.NINE_PATCH

	if use_nine_patch:
		var npr := NinePatchRect.new()
		npr.name = "NinePatch"
		npr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(npr)
		_rect = npr
	else:
		var tr := TextureRect.new()
		tr.name = "TextureRect"
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(tr)
		_rect = tr

func _apply_texture(tex: Texture2D) -> void:
	if not _rect or not is_instance_valid(_rect):
		return

	if _rect is NinePatchRect:
		var npr: NinePatchRect = _rect
		npr.texture = tex
		npr.patch_margin_left = layer.nine_patch_margin_left
		npr.patch_margin_top = layer.nine_patch_margin_top
		npr.patch_margin_right = layer.nine_patch_margin_right
		npr.patch_margin_bottom = layer.nine_patch_margin_bottom
		npr.draw_center = layer.nine_patch_draw_center
	else:
		var tr: TextureRect = _rect
		tr.texture = tex
		match layer.stretch_mode:
			BayterekTextureLayer.StretchMode.KEEP_ASPECT:
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			BayterekTextureLayer.StretchMode.TILE:
				tr.stretch_mode = TextureRect.STRETCH_TILE
			_:
				tr.stretch_mode = TextureRect.STRETCH_SCALE

func _apply_tint(tint: Color) -> void:
	if _rect and is_instance_valid(_rect):
		_rect.modulate = tint

func _apply_filter() -> void:
	if not _rect or not is_instance_valid(_rect):
		return
	var eff: int = layer.get_effective_texture_filter()
	_rect.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if eff == 1
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)