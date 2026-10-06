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

func get_pivot_px(effective_size: Vector2) -> Vector2:
	return effective_size * get_normalized_pivot()

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

## Returns the layer's effective size after applying `scale`.
##
## IMPORTANT: scale = 0 is preserved (NOT treated as "use 1.0"). This
## lets the user collapse a layer to nothing — which is used for
## progress-layer animations (0 → 1 growth).
##
## Values that are exactly 0 stay 0. Negative values are preserved
## (they flip the layer). A tiny epsilon is only used to guard against
## subnormal floats that would produce NaN in matrix math.
func get_effective_size(design_size: Vector2) -> Vector2:
	var base: Vector2 = design_size
	if size.x > 0.0 and size.y > 0.0:
		base = size

	# NOTE: we do NOT force 0 → 1.0 anymore. If the user set scale to
	# zero, the layer must collapse to a zero-sized rect.
	var sx: float = scale.x
	var sy: float = scale.y

	return Vector2(base.x * sx, base.y * sy)

func get_avg_scale() -> float:
	return (absf(scale.x) + absf(scale.y)) * 0.5

# ============================================================
# MATRIX
# ============================================================

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