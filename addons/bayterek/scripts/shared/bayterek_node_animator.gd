@tool
class_name BayterekNodeAnimator
extends Node
## Modular, tween-based animator for BayterekNodeButton.
##
## Usage:
##     var anim := BayterekNodeAnimator.new()
##     node.add_child(anim)
##     anim.bind(node)
##     anim.play("hover_enter")
##
## Presets are stored in a static registry so they can be extended
## from anywhere without touching this file.

signal animation_started(name: String)
signal animation_finished(name: String)

var node: BayterekNodeButton = null

var _active_tween: Tween = null
var _active_name: String = ""
var _snapshot: Dictionary = {}

## When true, cancel() does NOT restore the pre-play snapshot.
## Used for "enter" animations that are meant to be persistent
## (e.g. hover lift that stays lifted until an exit animation plays).
var _persist_state: bool = false

# ============================================================
# PRESET REGISTRY
# ============================================================

static var _presets: Dictionary = {}

static func _static_init() -> void:
	_register_builtin_presets()

static func _register_builtin_presets() -> void:
	_presets["hover_enter"] = _preset_hover_enter
	_presets["hover_exit"] = _preset_hover_exit
	_presets["lift_rotate"] = _preset_lift_rotate
	_presets["pop"] = _preset_pop
	_presets["shake"] = _preset_shake
	_presets["hover_lift"] = _preset_hover_lift

# ------------------------------------------------------------
# BUILT-IN PRESETS
# ------------------------------------------------------------

## Hover ENTER: lift + rotate, ends in the lifted position.
## The exit animation (hover_exit) is expected to bring it back down.
static func _preset_hover_enter(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -8.0)
	var rot_peak: float = opts.get("rot_peak", 5.0)
	var duration: float = opts.get("duration", 0.45)
	var trans: Tween.TransitionType = opts.get("trans", Tween.TRANS_SINE)
	var ease_type: Tween.EaseType = opts.get("ease", Tween.EASE_IN_OUT)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var base_pos: Vector2 = n.node_data.position
	var base_rot: float = n.node_data.node_rotation
	var target_pos: Vector2 = base_pos + Vector2(0.0, lift)

	var t := n.create_tween()
	t.set_trans(trans).set_ease(ease_type)

	var driver := func(progress: float) -> void:
		var p: float = progress

		# Position: lift up in FIRST half, stay there.
		var pos_offset: float
		if p <= 0.5:
			pos_offset = lerpf(0.0, lift, p / 0.5)
		else:
			pos_offset = lift
		anim._apply_position(base_pos + Vector2(0.0, pos_offset))

		# Rotation: -peak at 25%, +peak at 75%, 0 at 100%.
		var rot_offset: float
		if p <= 0.25:
			rot_offset = lerpf(0.0, -rot_peak, p / 0.25)
		elif p <= 0.75:
			rot_offset = lerpf(-rot_peak, rot_peak, (p - 0.25) / 0.5)
		else:
			rot_offset = lerpf(rot_peak, 0.0, (p - 0.75) / 0.25)
		anim._apply_rotation(base_rot + rot_offset)

	t.tween_method(driver, 0.0, 1.0, duration)

	t.finished.connect(func() -> void:
		anim._apply_position(target_pos)
		anim._apply_rotation(base_rot)
	)

	anim._persist_state = true
	return t


## Hover EXIT: descend back to the original position, NO rotation.
static func _preset_hover_exit(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var duration: float = opts.get("duration", 0.3)
	var trans: Tween.TransitionType = opts.get("trans", Tween.TRANS_SINE)
	var ease_type: Tween.EaseType = opts.get("ease", Tween.EASE_OUT)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var current_pos: Vector2 = n.node_data.position
	var current_rot: float = n.node_data.node_rotation

	var target_pos: Vector2 = current_pos
	if anim._snapshot.has("position"):
		target_pos = anim._snapshot["position"]
	else:
		var lift: float = opts.get("lift", -8.0)
		target_pos = current_pos - Vector2(0.0, lift)

	var target_rot: float = 0.0
	if anim._snapshot.has("rotation"):
		target_rot = anim._snapshot["rotation"]

	var t := n.create_tween()
	t.set_trans(trans).set_ease(ease_type)

	t.tween_method(
		func(v: Vector2) -> void: anim._apply_position(v),
		current_pos,
		target_pos,
		duration
	)

	if not is_equal_approx(current_rot, target_rot):
		var rt := n.create_tween()
		rt.set_trans(trans).set_ease(ease_type)
		rt.tween_method(
			func(v: float) -> void: anim._apply_rotation(v),
			current_rot,
			target_rot,
			duration
		)

	t.finished.connect(func() -> void:
		anim._apply_position(target_pos)
		anim._apply_rotation(target_rot)
		anim._snapshot.clear()
		anim._persist_state = false
	)

	return t


## One-shot lift + rotate that returns to base when done.
static func _preset_lift_rotate(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -8.0)
	var rot_peak: float = opts.get("rot_peak", 5.0)
	var duration: float = opts.get("duration", 0.45)
	var trans: Tween.TransitionType = opts.get("trans", Tween.TRANS_SINE)
	var ease_type: Tween.EaseType = opts.get("ease", Tween.EASE_IN_OUT)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var base_pos: Vector2 = n.node_data.position
	var base_rot: float = n.node_data.node_rotation

	var t := n.create_tween()
	t.set_trans(trans).set_ease(ease_type)

	var driver := func(progress: float) -> void:
		var p: float = progress

		var pos_offset: float
		if p <= 0.5:
			pos_offset = lerpf(0.0, lift, p / 0.5)
		else:
			pos_offset = lerpf(lift, 0.0, (p - 0.5) / 0.5)
		anim._apply_position(base_pos + Vector2(0.0, pos_offset))

		var rot_offset: float
		if p <= 0.25:
			rot_offset = lerpf(0.0, -rot_peak, p / 0.25)
		elif p <= 0.75:
			rot_offset = lerpf(-rot_peak, rot_peak, (p - 0.25) / 0.5)
		else:
			rot_offset = lerpf(rot_peak, 0.0, (p - 0.75) / 0.25)
		anim._apply_rotation(base_rot + rot_offset)

	t.tween_method(driver, 0.0, 1.0, duration)

	t.finished.connect(func() -> void:
		anim._apply_position(base_pos)
		anim._apply_rotation(base_rot)
	)
	return t


## POP: center-anchored scale in/out via Control.scale (pivot is centered).
static func _preset_pop(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var peak: float = opts.get("peak", 1.15)
	var duration: float = opts.get("duration", 0.25)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var base_scale: Vector2 = n.node_data.scale

	var t := n.create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(
		func(v: float) -> void: anim._apply_scale(Vector2(base_scale.x * v, base_scale.y * v)),
		1.0,
		peak,
		duration * 0.4
	)
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_method(
		func(v: float) -> void: anim._apply_scale(Vector2(base_scale.x * v, base_scale.y * v)),
		peak,
		1.0,
		duration * 0.6
	)
	t.finished.connect(func() -> void: anim._apply_scale(base_scale))
	return t


static func _preset_shake(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var amplitude: float = opts.get("amplitude", 6.0)
	var duration: float = opts.get("duration", 0.35)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var base_pos: Vector2 = n.node_data.position

	var t := n.create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var steps: int = 6
	var step_time: float = duration / float(steps)

	for i in steps:
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var falloff: float = 1.0 - (float(i) / float(steps))
		var target: Vector2 = base_pos + Vector2(amplitude * dir * falloff, 0.0)
		var start_v: Vector2 = base_pos if i == 0 else base_pos + Vector2(amplitude * -dir * falloff, 0.0)
		t.tween_method(
			func(v: Vector2) -> void: anim._apply_position(v),
			start_v,
			target,
			step_time
		)

	t.tween_method(
		func(v: Vector2) -> void: anim._apply_position(v),
		base_pos + Vector2(amplitude * -1.0 * 0.1, 0.0),
		base_pos,
		step_time
	)

	t.finished.connect(func() -> void: anim._apply_position(base_pos))
	return t


static func _preset_hover_lift(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -6.0)
	var duration: float = opts.get("duration", 0.18)

	var n = anim.node
	if not n or not n.node_data:
		return null

	var base_pos: Vector2 = n.node_data.position

	var t := n.create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(
		func(v: Vector2) -> void: anim._apply_position(v),
		base_pos,
		base_pos + Vector2(0, lift),
		duration
	)
	t.finished.connect(func() -> void: anim._apply_position(base_pos + Vector2(0, lift)))
	return t

# ------------------------------------------------------------
# PUBLIC PRESET API
# ------------------------------------------------------------

static func register_preset(preset_name: String, fn: Callable) -> void:
	_presets[preset_name] = fn

static func has_preset(preset_name: String) -> bool:
	return _presets.has(preset_name)

static func get_preset_names() -> Array:
	return _presets.keys()

# ============================================================
# PUBLIC API
# ============================================================

func bind(p: BayterekNodeButton) -> void:
	node = p

func play(preset_name: String, opts: Dictionary = {}) -> Tween:
	if not node:
		push_warning("BayterekNodeAnimator: not bound to a node.")
		return null
	if not _presets.has(preset_name):
		push_warning("BayterekNodeAnimator: unknown preset '%s'." % preset_name)
		return null

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		if not _persist_state and not _snapshot.is_empty():
			_restore_snapshot()
			_snapshot.clear()

	if not _persist_state or _snapshot.is_empty():
		_snapshot = _capture_snapshot()

	_active_name = preset_name

	var fn: Callable = _presets[preset_name]
	var tween: Tween = fn.call(self, opts)
	if not tween or not tween.is_valid():
		_snapshot.clear()
		_active_name = ""
		_persist_state = false
		return null

	_active_tween = tween
	animation_started.emit(preset_name)

	tween.finished.connect(func() -> void:
		if _active_tween == tween:
			_active_tween = null
			_active_name = ""
		animation_finished.emit(preset_name)
	)

	return tween

func cancel() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

	if not _persist_state and not _snapshot.is_empty():
		_restore_snapshot()
		_snapshot.clear()

	_active_name = ""

func is_playing() -> bool:
	return _active_tween != null and _active_tween.is_valid()

func get_active_name() -> String:
	return _active_name

# ============================================================
# SNAPSHOT / RESTORE
# ============================================================

func _capture_snapshot() -> Dictionary:
	if not node or not node.node_data:
		return {}
	return {
		"position": node.node_data.position,
		"rotation": node.node_data.node_rotation,
		"skew": node.node_data.node_skew,
		"scale": node.node_data.scale,
	}

func _restore_snapshot() -> void:
	if not node or not node.node_data:
		return
	if _snapshot.has("position"):
		_apply_position(_snapshot["position"])
	if _snapshot.has("rotation"):
		_apply_rotation(_snapshot["rotation"])
	if _snapshot.has("skew"):
		node.node_data.node_skew = _snapshot["skew"]
	if _snapshot.has("scale"):
		_apply_scale(_snapshot["scale"])

# ============================================================
# APPLY HELPERS
# ============================================================

func _apply_position(pos: Vector2) -> void:
	if not node or not node.node_data:
		return
	node.node_data.position = pos
	var tv := _find_tree_view()
	if tv and tv.nodes_service:
		tv.nodes_service.update_position(node, pos)
		if tv.connections_service:
			tv.connections_service.update_lines_of(node)
	elif node.has_method("refresh_transform"):
		node.refresh_transform()

func _apply_rotation(rot: float) -> void:
	if not node or not node.node_data:
		return
	node.node_data.node_rotation = rot
	if node.has_method("refresh_transform"):
		node.refresh_transform()

## Scale via Control.scale (pivot is centered). No position shifts.
func _apply_scale(s: Vector2) -> void:
	if not node or not node.node_data:
		return

	if node.has_method("set_visual_scale"):
		node.set_visual_scale(s)
	else:
		node.node_data.scale = s
		if node is Control:
			node.scale = s

func _find_tree_view() -> BayterekTreeView:
	var p: Node = node
	while p:
		if p is BayterekTreeView:
			return p
		p = p.get_parent()
	return null