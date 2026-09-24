@tool
class_name BayterekLayerTransform
extends Resource
## 2D transform data for a layer.

enum PivotMode {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MID_LEFT,
	CENTER,
	MID_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
	CUSTOM,
}

@export_storage var position: Vector2 = Vector2.ZERO
@export_storage var size: Vector2 = Vector2.ZERO
@export_storage var scale: Vector2 = Vector2.ONE
@export_storage var flip_x: bool = false
@export_storage var flip_y: bool = false
@export_storage var rotation: float = 0.0
@export_storage var skew: Vector2 = Vector2.ZERO
@export_storage var pivot: Vector2 = Vector2(0.5, 0.5)
@export_storage var pivot_mode: PivotMode = PivotMode.CENTER
@export_storage var scale_from_pivot: bool = false

# ============================================================
# PIVOT RESOLUTION
# ============================================================

## Normalized (0..1, top-left) pivot vector for the current pivot mode.
func get_normalized_pivot() -> Vector2:
	match pivot_mode:
		PivotMode.TOP_LEFT:      return Vector2(0.0, 0.0)
		PivotMode.TOP_CENTER:    return Vector2(0.5, 0.0)
		PivotMode.TOP_RIGHT:     return Vector2(1.0, 0.0)
		PivotMode.MID_LEFT:      return Vector2(0.0, 0.5)
		PivotMode.CENTER:        return Vector2(0.5, 0.5)
		PivotMode.MID_RIGHT:     return Vector2(1.0, 0.5)
		PivotMode.BOTTOM_LEFT:   return Vector2(0.0, 1.0)
		PivotMode.BOTTOM_CENTER: return Vector2(0.5, 1.0)
		PivotMode.BOTTOM_RIGHT:  return Vector2(1.0, 1.0)
		PivotMode.CUSTOM:        return pivot
	return Vector2(0.5, 0.5)

## Pivot in top-left-pixel coordinates (0..effective_size).
func get_pivot_px(effective_size: Vector2) -> Vector2:
	return effective_size * get_normalized_pivot()

## Pivot in the shape's LOCAL centered coordinate system.
##
## pixel_mode = false (default): classic vector-space pivot, centered at
## the shape's geometric center. This is what rotation/skew/scale uses in
## vector mode.
##
## pixel_mode = true: pivot is snapped to the same integer grid that
## `get_pixel_spans()` uses. `get_pixel_spans` lays pixels out over the
## range `[x_off, x_off + W)` where `x_off = -W / 2` (integer division)
## and `W = round(effective_size.x)`. Therefore the pivot's local
## coordinate in the same grid is `x_off + norm.x * W` for X, and the
## analogous formula for Y. This keeps rotation/scale anchored to the
## pixel-perfect layer outline.
func get_pivot_local(effective_size: Vector2, pixel_mode: bool = false) -> Vector2:
	if pixel_mode:
		var W: int = int(round(effective_size.x))
		var H: int = int(round(effective_size.y))
		if W <= 0 or H <= 0:
			return Vector2.ZERO
		var x_off: int = -W / 2
		var y_off: int = -H / 2
		var norm: Vector2 = get_normalized_pivot()
		var px: float = float(x_off) + norm.x * float(W)
		var py: float = float(y_off) + norm.y * float(H)
		return Vector2(px, py)

	return get_pivot_px(effective_size) - effective_size * 0.5

# ============================================================
# EFFECTIVE SIZE / SCALE
# ============================================================

func get_effective_size(design_size: Vector2) -> Vector2:
	var base: Vector2 = design_size
	if size.x > 0.0 and size.y > 0.0:
		base = size

	var sx: float = scale.x if absf(scale.x) > 0.0001 else 1.0
	var sy: float = scale.y if absf(scale.y) > 0.0001 else 1.0
	return Vector2(base.x * sx, base.y * sy)

func get_avg_scale() -> float:
	return (absf(scale.x) + absf(scale.y)) * 0.5

# ============================================================
# MATRIX
# ============================================================

## Builds the layer's transform matrix.
##
## pixel_mode = true snaps the pivot to the integer pixel grid so
## rotation / scale anchors on a real pixel edge (matching what
## `BayterekShapeLayer.get_pixel_spans()` draws).
func get_matrix(design_size: Vector2, pixel_mode: bool = false) -> Transform2D:
	var effective_size: Vector2 = get_effective_size(design_size)
	var pivot_local: Vector2 = get_pivot_local(effective_size, pixel_mode)

	var angle_rad: float = deg_to_rad(rotation)
	var rot := Transform2D(angle_rad, Vector2.ZERO)

	var sx_skew: float = tan(deg_to_rad(skew.x))
	var sy_skew: float = tan(deg_to_rad(skew.y))
	var skew_mat := Transform2D(
		Vector2(1.0, sy_skew),
		Vector2(sx_skew, 1.0),
		Vector2.ZERO
	)

	var flip_sx: float = -1.0 if flip_x else 1.0
	var flip_sy: float = -1.0 if flip_y else 1.0
	var flip_mat := Transform2D(
		Vector2(flip_sx, 0.0),
		Vector2(0.0, flip_sy),
		Vector2.ZERO
	)

	var combined_basis: Transform2D = rot * skew_mat * flip_mat

	var base_origin: Vector2
	if scale_from_pivot:
		base_origin = position - pivot_local
	else:
		base_origin = position

	var origin: Vector2 = base_origin + pivot_local - (combined_basis * pivot_local)

	return Transform2D(combined_basis.x, combined_basis.y, origin)

# ============================================================
# DUPLICATE
# ============================================================

func duplicate_transform() -> BayterekLayerTransform:
	var copy := BayterekLayerTransform.new()
	copy.position = position
	copy.size = size
	copy.scale = scale
	copy.flip_x = flip_x
	copy.flip_y = flip_y
	copy.rotation = rotation
	copy.skew = skew
	copy.pivot = pivot
	copy.pivot_mode = pivot_mode
	copy.scale_from_pivot = scale_from_pivot
	return copy

func _to_string() -> String:
	return "BayterekLayerTransform(pos=%s, size=%s, scale=%s, flip=(%s,%s), rot=%.1f°, from_pivot=%s)" % [
		position, size, scale, flip_x, flip_y, rotation, scale_from_pivot
	]