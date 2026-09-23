@tool
class_name BayterekLayerTransform
extends Resource
## 2D transform data for a layer.
##
## Holds position, size, scale, rotation, skew, flip, and pivot. Pivot is
## stored as a normalized (0..1) coordinate plus a pivot mode enum, so the
## pivot stays proportionally placed when the effective size changes.
##
## NOTE: Shape vertices are generated centered at (0,0) — i.e. the shape's
## bounding box spans [-size/2, +size/2]. Pivot is expressed in top-left
## normalized coordinates (0..1), but internally converted to the same
## centered coordinate system so rotation happens around the correct point.

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

## Layer's local position relative to the design center.
## When `scale_from_pivot` is false, this is the layer's CENTER.
## When `scale_from_pivot` is true, this is the layer's PIVOT point.
@export_storage var position: Vector2 = Vector2.ZERO

## Layer size in pixels. Zero means "use design_size".
@export_storage var size: Vector2 = Vector2.ZERO

## Multiplicative scale applied on top of `size`. Default (1,1) means no
## change. Use this for reveal / grow / shrink animations.
## Effective size = base_size * scale (base_size = `size` or `design_size`).
@export_storage var scale: Vector2 = Vector2.ONE

## Mirror the layer on the X axis. Applied after scale.
@export_storage var flip_x: bool = false

## Mirror the layer on the Y axis. Applied after scale.
@export_storage var flip_y: bool = false

## Rotation in degrees.
@export_storage var rotation: float = 0.0

## 2D shear, in degrees per axis.
@export_storage var skew: Vector2 = Vector2.ZERO

## Normalized pivot (0..1, top-left based), used only for CUSTOM.
@export_storage var pivot: Vector2 = Vector2(0.5, 0.5)

@export_storage var pivot_mode: PivotMode = PivotMode.CENTER

## When false (default), `position` is the layer's center and size/scale
## grow symmetrically around it. When true, `position` is the pivot point
## and size/scale grow away from the pivot — useful for reveal effects.
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

## Pivot in the shape's LOCAL centered coordinate system,
## i.e. relative to the shape's center (which is (0,0)).
func get_pivot_local(effective_size: Vector2) -> Vector2:
	return get_pivot_px(effective_size) - effective_size * 0.5

# ============================================================
# EFFECTIVE SIZE / SCALE
# ============================================================

## Returns the layer's real size, before flip. Falls back to `design_size`
## when this transform's size is zero on either axis.
##   effective_size = base_size * scale
func get_effective_size(design_size: Vector2) -> Vector2:
	var base: Vector2 = design_size
	if size.x > 0.0 and size.y > 0.0:
		base = size

	var sx: float = scale.x if absf(scale.x) > 0.0001 else 1.0
	var sy: float = scale.y if absf(scale.y) > 0.0001 else 1.0
	return Vector2(base.x * sx, base.y * sy)

## Average absolute scale of the X and Y axes. Useful for scaling line
## widths, corner radii, and other 1-D quantities that must remain
## proportional to the layer.
func get_avg_scale() -> float:
	return (absf(scale.x) + absf(scale.y)) * 0.5

# ============================================================
# MATRIX
# ============================================================

## Builds the layer's transform matrix.
##
## Math:
##   Let p = pivot in the LOCAL centered coordinate system
##   Let M = combined basis (flip * rotate * skew)
##   Local-to-world mapping: M * (v - p) + p + base_origin
##   Expanded:               M * v + (base_origin + p - M * p)
##
## Where `base_origin` is the layer's center:
##   - scale_from_pivot = false → base_origin = position
##   - scale_from_pivot = true  → base_origin = position - p
##     (so `position` acts as the pivot's world-space location)
func get_matrix(design_size: Vector2) -> Transform2D:
	var effective_size: Vector2 = get_effective_size(design_size)
	var pivot_local: Vector2 = get_pivot_local(effective_size)

	# 1) Rotation basis
	var angle_rad: float = deg_to_rad(rotation)
	var rot := Transform2D(angle_rad, Vector2.ZERO)

	# 2) Skew basis
	var sx_skew: float = tan(deg_to_rad(skew.x))
	var sy_skew: float = tan(deg_to_rad(skew.y))
	var skew_mat := Transform2D(
		Vector2(1.0, sy_skew),
		Vector2(sx_skew, 1.0),
		Vector2.ZERO
	)

	# 3) Flip basis (mirror on selected axes)
	var flip_sx: float = -1.0 if flip_x else 1.0
	var flip_sy: float = -1.0 if flip_y else 1.0
	var flip_mat := Transform2D(
		Vector2(flip_sx, 0.0),
		Vector2(0.0, flip_sy),
		Vector2.ZERO
	)

	# 4) Combined basis (apply flip, then skew, then rotation)
	var combined_basis: Transform2D = rot * skew_mat * flip_mat

	# 5) Determine the layer's center in design space.
	var base_origin: Vector2
	if scale_from_pivot:
		base_origin = position - pivot_local
	else:
		base_origin = position

	# 6) Full matrix: origin = base_origin + pivot_local - M * pivot_local
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