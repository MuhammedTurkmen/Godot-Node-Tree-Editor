@tool
class_name BayterekRuntimeAnimator
extends Node
## Runtime animator for a BayterekNodeButton.
##
## Plays tween-based animations on the node's exported fields — e.g.
## animate `layers.{id}.transform.scale` from (1,1) to (1.2,1.2) over
## 0.3s with an ease-out curve.
##
## Usage:
##     var anim = BayterekRuntimeAnimator.new()
##     node.add_child(anim)
##     anim.bind(node)
##     anim.tween_field("layers.abc.transform.scale", Vector2(1,1), Vector2(1.2,1.2), 0.3)
##
## The animator writes to the *node's* exported overrides so it does not
## touch the shared prefab/design data.

signal animation_started(field_path: String)
signal animation_finished(field_path: String)

var node: BayterekNodeButton = null

## Active tweens, keyed by field_path so a second call cancels the first.
var _active_tweens: Dictionary = {}

func _ready() -> void:
	# Try to bind to the parent BayterekNodeButton automatically.
	if not node and get_parent() is BayterekNodeButton:
		node = get_parent()

func bind(target: BayterekNodeButton) -> void:
	node = target

# ============================================================
# PUBLIC API
# ============================================================

## Animates a single exported field from `from_value` to `to_value`.
## If `from_value` is null, uses the current effective value as the start.
func tween_field(
	field_path: String,
	from_value: Variant,
	to_value: Variant,
	duration: float = 0.3,
	trans: Tween.TransitionType = Tween.TRANS_QUAD,
	ease_type: Tween.EaseType = Tween.EASE_OUT,
	delay: float = 0.0
) -> Tween:
	if not node or field_path.is_empty():
		return null

	_kill_field_tween(field_path)

	var effective_from: Variant = from_value
	if effective_from == null:
		effective_from = _resolve_current_value(field_path)

	var tween: Tween = create_tween()
	_active_tweens[field_path] = tween

	tween.set_trans(trans).set_ease(ease_type)
	if delay > 0.0:
		tween.tween_interval(delay)

	tween.tween_method(
		func(v: Variant): _apply_field_value(field_path, v),
		effective_from,
		to_value,
		duration
	)

	tween.finished.connect(func():
		_active_tweens.erase(field_path)
		animation_finished.emit(field_path)
	)

	animation_started.emit(field_path)
	return tween

## Animates multiple fields in parallel using the same tween.
func tween_fields(
	entries: Array,
	duration: float = 0.3,
	trans: Tween.TransitionType = Tween.TRANS_QUAD,
	ease_type: Tween.EaseType = Tween.EASE_OUT
) -> Tween:
	if not node or entries.is_empty():
		return null

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(trans).set_ease(ease_type)

	for entry in entries:
		if not entry is Dictionary:
			continue
		var field_path: String = entry.get("path", "")
		var to_value: Variant = entry.get("to", null)
		var from_value: Variant = entry.get("from", null)

		if field_path.is_empty() or to_value == null:
			continue

		var effective_from: Variant = from_value
		if effective_from == null:
			effective_from = _resolve_current_value(field_path)

		tween.tween_method(
			func(v: Variant): _apply_field_value(field_path, v),
			effective_from,
			to_value,
			duration
		)
		animation_started.emit(field_path)

	tween.finished.connect(func():
		for entry in entries:
			if entry is Dictionary:
				animation_finished.emit(entry.get("path", ""))
	)

	return tween

## Kills any running tween for a field.
func cancel_field(field_path: String) -> void:
	_kill_field_tween(field_path)

## Kills every active tween.
func cancel_all() -> void:
	for field_path in _active_tweens.keys():
		_kill_field_tween(field_path)
	_active_tweens.clear()

# ============================================================
# CONVENIENCE: PRESET ANIMATIONS
# ============================================================

## Plays a "pop" animation: layer scale goes 1 → peak → 1.
func play_pop(layer_id: String, peak: float = 1.15, duration: float = 0.25) -> void:
	if layer_id.is_empty():
		return
	var scale_path: String = "layers.%s.transform.scale" % layer_id
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v: float): _apply_field_value(scale_path, Vector2(v, v)),
		1.0, peak, duration * 0.4
	)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(v: float): _apply_field_value(scale_path, Vector2(v, v)),
		peak, 1.0, duration * 0.6
	)

## Plays a "shake" animation: layer position wiggles ±`amplitude`.
func play_shake(layer_id: String, amplitude: float = 6.0, duration: float = 0.35) -> void:
	if layer_id.is_empty():
		return
	var pos_path: String = "layers.%s.transform.position" % layer_id
	var base: Variant = _resolve_current_value(pos_path)
	var base_v: Vector2 = base if base is Vector2 else Vector2.ZERO

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var steps: int = 6
	var step_time: float = duration / float(steps)
	for i in steps:
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var falloff: float = 1.0 - (float(i) / float(steps))
		var target: Vector2 = base_v + Vector2(amplitude * dir * falloff, 0.0)
		var start_v: Vector2 = base_v if i == 0 else base_v + Vector2(amplitude * -dir * falloff, 0.0)
		tween.tween_method(
			func(v: Vector2): _apply_field_value(pos_path, v),
			start_v,
			target,
			step_time
		)

	tween.tween_method(
		func(v: Vector2): _apply_field_value(pos_path, v),
		base_v + Vector2(amplitude * -1.0 * 0.1, 0.0),
		base_v,
		step_time
	)

## Plays a "flash" animation: tint color pulses to `color` and back.
func play_flash(layer_id: String, color: Color = Color.WHITE, duration: float = 0.3) -> void:
	if layer_id.is_empty():
		return
	var tint_path: String = "layers.%s.tint_configs.normal.color" % layer_id
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(c: Color): _apply_field_value(tint_path, c),
		Color.WHITE, color, duration * 0.3
	)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(c: Color): _apply_field_value(tint_path, c),
		color, Color.WHITE, duration * 0.7
	)

# ============================================================
# INTERNAL
# ============================================================

## Resolves the current effective value of a field path.
## Priority: node override → prefab → design.
func _resolve_current_value(field_path: String) -> Variant:
	if not node or not node.node_data:
		return null

	var node_data: BayterekNode = node.node_data
	if node_data.exported_overrides.has(field_path):
		return node_data.exported_overrides[field_path]

	# Layer lookup
	var parsed: Dictionary = _parse_layer_path(field_path)
	if parsed.is_empty():
		return null

	var layer_id: String = parsed.get("layer_id", "")
	var segments: Array = parsed.get("segments", [])

	var layer: BayterekLayer = node_data.get_layer_by_id(layer_id)
	if not layer:
		return null

	# Walk the property path.
	var current: Variant = layer
	for seg in segments:
		if current == null:
			return null
		var key: String = String(seg)
		if current is Object:
			if key in current:
				current = current.get(key)
			else:
				var found: bool = false
				for prop in current.get_property_list():
					if prop.get("name", "") == key:
						current = current.get(key)
						found = true
						break
				if not found:
					return null
		elif current is Dictionary:
			if not current.has(key):
				return null
			current = current[key]
		else:
			return null

	return current

## Applies a value to a field path, writing to the node's override dict.
func _apply_field_value(field_path: String, value: Variant) -> void:
	if not node or not node.node_data:
		return

	var node_data: BayterekNode = node.node_data
	node_data.set_exported_override(field_path, value)

	# Apply the change to the actual layer for immediate visual update.
	_apply_override_to_layer(node_data, field_path, value)

	if node.has_method("refresh_visuals"):
		node.refresh_visuals()

func _apply_override_to_layer(node_data: BayterekNode, field_path: String, value: Variant) -> void:
	var parsed: Dictionary = _parse_layer_path(field_path)
	if parsed.is_empty():
		return

	var layer_id: String = parsed.get("layer_id", "")
	var segments: Array = parsed.get("segments", [])
	if layer_id.is_empty() or segments.is_empty():
		return

	var layer: BayterekLayer = node_data.get_layer_by_id(layer_id)
	if not layer:
		return

	var current: Variant = layer
	for i in range(segments.size() - 1):
		var key: String = String(segments[i])
		if current is Object:
			current = current.get(key)
		elif current is Dictionary:
			if not current.has(key):
				return
			current = current[key]
		else:
			return

	var last: String = String(segments[segments.size() - 1])
	if current is Object:
		current.set(last, value)
	elif current is Dictionary:
		current[last] = value

func _parse_layer_path(field_path: String) -> Dictionary:
	var parts: Array = field_path.split(".")
	if parts.size() < 3:
		return {}
	if parts[0] != "layers":
		return {}
	var layer_id: String = parts[1]
	var segments: Array = []
	for i in range(2, parts.size()):
		segments.append(parts[i])
	return {"layer_id": layer_id, "segments": segments}

func _kill_field_tween(field_path: String) -> void:
	if not _active_tweens.has(field_path):
		return
	var tween: Tween = _active_tweens[field_path]
	if tween and tween.is_valid():
		tween.kill()
	_active_tweens.erase(field_path)