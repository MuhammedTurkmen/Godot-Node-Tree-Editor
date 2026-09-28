@tool
class_name BayterekNodeAnimator
extends Node
## Presets — all built from the fluent builder DSL.
##
## Example:
##     anim.chain() \
##         .parallel() \
##             .move(Vector2(0, -8), 0.45) \
##             .sequence() \
##                 .rotate(-5, 0.1125) \
##                 .rotate(10, 0.225) \
##                 .rotate(-5, 0.1125) \
##             .end_sequence() \
##         .end_parallel() \
##         .persist(true) \
##         .play()

signal animation_started(name: String)
signal animation_finished(name: String)

var node: BayterekNodeButton = null

var _active_tween: Tween = null
var _active_name: String = ""
var _snapshot: Dictionary = {}
var _persist_state: bool = false

## Child tweens spawned by the builder (one per step). Killed on cancel.
var _child_tweens: Array = []

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

# ============================================================
# BUILT-IN PRESETS
# ============================================================

## Hover ENTER.
##
## Timeline (D = duration):
##   Both move and rotate finish at the SAME time (D).
##   Move:   0 → lift over D.
##   Rotate: 0 → -peak → +peak → 0 over D (three sequential sub-steps).
##   Both run in parallel.
##
## persist = true → node stays lifted after the tween ends.
static func _preset_hover_enter(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -2.5)
	var rot_peak: float = opts.get("rot_peak", 5.0)
	var duration: float = opts.get("duration", 0.45)

	var step: float = duration / 3
	var quarter: float = duration * 0.25
	var half: float = duration * 0.5

	var b: BayterekAnimatorBuilder = anim.chain()
	b.parallel()
	b.move(Vector2(0, lift), duration)
	b.sequence()
	b.rotate(-rot_peak, step)
	b.rotate(rot_peak * 2.0, step)
	b.rotate(-rot_peak, step)
	b.end_sequence()
	b.end_parallel()
	b.persist(true)
	return b.play()


## Hover EXIT — descend, no rotation.
static func _preset_hover_exit(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var duration: float = opts.get("duration", 0.3)
	var n = anim.node
	if not n:
		return null

	var cur_off: Vector2 = n.get_visual_offset()
	var cur_rot: float = n.get_visual_rotation()

	if cur_off.length_squared() <= 0.0001 and is_equal_approx(cur_rot, 0.0):
		n.set_visual_offset(Vector2.ZERO)
		n.set_visual_rotation(0.0)
		return null

	var b: BayterekAnimatorBuilder = anim.chain()
	b.parallel()
	if cur_off.length_squared() > 0.0001:
		b.move_to(cur_off, Vector2.ZERO, duration)
	if not is_equal_approx(cur_rot, 0.0):
		b.rotate_to(cur_rot, 0.0, duration)
	b.end_parallel()
	b.persist(false)
	return b.play()


## Lift + rotate that returns to base.
static func _preset_lift_rotate(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -8.0)
	var rot_peak: float = opts.get("rot_peak", 5.0)
	var duration: float = opts.get("duration", 0.45)

	var quarter: float = duration * 0.25
	var half: float = duration * 0.5

	var b: BayterekAnimatorBuilder = anim.chain()

	# Up + full rotation swing.
	b.parallel()
	b.move(Vector2(0, lift), duration)
	b.sequence()
	b.rotate(-rot_peak, quarter)
	b.rotate(rot_peak * 2.0, half)
	b.rotate(-rot_peak, quarter)
	b.end_sequence()
	b.end_parallel()

	# Down + full rotation swing back.
	b.parallel()
	b.move(Vector2(0, -lift), duration)
	b.sequence()
	b.rotate(-rot_peak, quarter)
	b.rotate(rot_peak * 2.0, half)
	b.rotate(-rot_peak, quarter)
	b.end_sequence()
	b.end_parallel()

	b.persist(false)
	return b.play()


## POP — scale up and back.
static func _preset_pop(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var peak: float = opts.get("peak", 1.15)
	var duration: float = opts.get("duration", 0.25)

	var b: BayterekAnimatorBuilder = anim.chain()
	b.scale(peak, duration * 0.4)
	b.scale(1.0 / peak, duration * 0.6)
	b.persist(false)
	return b.play()


## SHAKE — alternating rotation, decays to base.
static func _preset_shake(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var amplitude: float = opts.get("amplitude", 5.0)
	var duration: float = opts.get("duration", 0.35)
	var bounces: int = int(opts.get("steps", 4))
	if bounces < 1:
		bounces = 1

	var step_t: float = duration / float(bounces + 1)

	var b: BayterekAnimatorBuilder = anim.chain()

	for i in bounces:
		var falloff: float = 1.0 - float(i) / float(bounces + 1)
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		b.rotate(amplitude * dir * falloff, step_t)

	# Settle back to 0.
	b.rotate_to(b._cursor_rot, 0.0, step_t)

	b.persist(false)
	return b.play()


## HOVER LIFT — lift only, stays lifted.
static func _preset_hover_lift(anim: BayterekNodeAnimator, opts: Dictionary) -> Tween:
	var lift: float = opts.get("lift", -6.0)
	var duration: float = opts.get("duration", 0.18)

	var b: BayterekAnimatorBuilder = anim.chain()
	b.move(Vector2(0, lift), duration)
	b.persist(true)
	return b.play()

# ============================================================
# PUBLIC PRESET API
# ============================================================

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

	_hard_cancel()
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
		if _active_tween != tween:
			return
		_active_tween = null
		_active_name = ""
		animation_finished.emit(preset_name)
	)

	return tween

## Kills the running animation and all its child tweens.
func _hard_cancel() -> void:
	for tw in _child_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_child_tweens.clear()

	var master: Tween = _active_tween
	_active_tween = null
	if master and master.is_valid():
		master.kill()

	_active_name = ""
	_persist_state = false

func cancel() -> void:
	_hard_cancel()
	if not _persist_state and not _snapshot.is_empty():
		_restore_snapshot()
		_snapshot.clear()

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
		"offset": node.get_visual_offset(),
		"rotation": node.get_visual_rotation(),
		"scale": node.get_visual_scale(),
	}

func _restore_snapshot() -> void:
	if not node or not node.node_data:
		return
	if _snapshot.has("offset"):
		_apply_visual_offset(_snapshot["offset"])
	if _snapshot.has("rotation"):
		_apply_visual_rotation(_snapshot["rotation"])
	if _snapshot.has("scale"):
		_apply_visual_scale(_snapshot["scale"])

# ============================================================
# FLUENT BUILDER FACTORY
# ============================================================

func chain() -> BayterekAnimatorBuilder:
	var b: BayterekAnimatorBuilder = BayterekAnimatorBuilder.new(self)
	return b.chain()

func parallel() -> BayterekAnimatorBuilder:
	var b: BayterekAnimatorBuilder = BayterekAnimatorBuilder.new(self)
	return b.parallel()

func sequence() -> BayterekAnimatorBuilder:
	var b: BayterekAnimatorBuilder = BayterekAnimatorBuilder.new(self)
	return b.sequence()

# ============================================================
# APPLY HELPERS
# ============================================================

func _apply_visual_offset(offset: Vector2) -> void:
	if not node:
		return
	node.set_visual_offset(offset)

func _apply_visual_rotation(deg: float) -> void:
	if not node:
		return
	node.set_visual_rotation(deg)

func _apply_visual_scale(s: Vector2) -> void:
	if not node:
		return
	node.set_visual_scale(s)