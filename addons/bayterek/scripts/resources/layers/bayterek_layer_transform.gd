@tool
class_name BayterekLayerTransform
extends Resource
## 2D transform data for a layer.
##
## Holds position, size, rotation, skew, and pivot. Pivot is stored as a
## normalized (0..1) coordinate plus a pivot mode enum, so the pivot stays
## proportionally placed when the effective size changes.
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
@export_storage var position: Vector2 = Vector2.ZERO

## Layer size in pixels. Zero means "use design_size".
@export_storage var size: Vector2 = Vector2.ZERO

## Rotation in degrees.
@export_storage var rotation: float = 0.0

## 2D shear, in degrees per axis.
@export_storage var skew: Vector2 = Vector2.ZERO

## Normalized pivot (0..1, top-left based), used only for CUSTOM.
@export_storage var pivot: Vector2 = Vector2(0.5, 0.5)

@export_storage var pivot_mode: PivotMode = PivotMode.CENTER

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
## Useful for UI display / debug.
func get_pivot_px(effective_size: Vector2) -> Vector2:
	return effective_size * get_normalized_pivot()

## Pivot in the shape's LOCAL centered coordinate system,
## i.e. relative to the shape's center (which is (0,0)).
##
##   top-left      -> (-size/2, -size/2)
##   center        -> (0, 0)
##   bottom-right  -> (size/2, size/2)
func get_pivot_local(effective_size: Vector2) -> Vector2:
	return get_pivot_px(effective_size) - effective_size * 0.5

# ============================================================
# EFFECTIVE SIZE
# ============================================================

## Returns the layer's real size. Falls back to `design_size` when this
## transform's size is zero on either axis.
func get_effective_size(design_size: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return design_size
	return size

# ============================================================
# MATRIX
# ============================================================

## Builds the layer's transform matrix.
##
## Math:
##   Let p = pivot in the LOCAL centered coordinate system
##   Let M = combined basis (rotate * skew)
##   Local-to-world mapping: M * (v - p) + p + position
##   Expanded:               M * v + (position + p - M * p)
##
## So basis = M and origin = position + p - M * p.
func get_matrix(design_size: Vector2) -> Transform2D:
	var effective_size: Vector2 = get_effective_size(design_size)
	var pivot_local: Vector2 = get_pivot_local(effective_size)

	# 1) Rotation basis
	var angle_rad: float = deg_to_rad(rotation)
	var rot := Transform2D(angle_rad, Vector2.ZERO)

	# 2) Skew basis
	#    [ 1       tan(skew.x) ]
	#    [ tan(skew.y)   1     ]
	var sx: float = tan(deg_to_rad(skew.x))
	var sy: float = tan(deg_to_rad(skew.y))
	var skew_mat := Transform2D(
		Vector2(1.0, sy),
		Vector2(sx, 1.0),
		Vector2.ZERO
	)

	# 3) Combined basis (apply skew first, then rotate)
	var combined_basis: Transform2D = rot * skew_mat

	# 4) Full matrix: origin = position + pivot_local - M * pivot_local
	var origin: Vector2 = position + pivot_local - (combined_basis * pivot_local)

	return Transform2D(combined_basis.x, combined_basis.y, origin)

# ============================================================
# DUPLICATE
# ============================================================

func duplicate_transform() -> BayterekLayerTransform:
	var copy := BayterekLayerTransform.new()
	copy.position = position
	copy.size = size
	copy.rotation = rotation
	copy.skew = skew
	copy.pivot = pivot
	copy.pivot_mode = pivot_mode
	return copy

func _to_string() -> String:
	return "BayterekLayerTransform(pos=%s, size=%s, rot=%.1f°, skew=%s, pivot=%s/%s)" % [
		position, size, rotation, skew, PivotMode.keys()[pivot_mode], pivot
	]