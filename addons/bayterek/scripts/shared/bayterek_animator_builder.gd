@tool
class_name BayterekAnimatorBuilder
extends RefCounted
## Fluent builder — every animation is composed from .move/.rotate/.scale.
##
## Usage:
##     animator.chain() \
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
##
## Each step becomes its OWN Godot Tween, delayed by a tween_interval.
## This sidesteps Godot's buggy set_parallel() + tween_method combos.

enum Mode { SEQUENTIAL, PARALLEL }

var _animator: BayterekNodeAnimator
var _steps: Array = []           # top-level steps (sequential by default)
var _stack: Array = []           # nested groups (parallel / sequence)

## Cursor: current state. Relative calls advance from here.
var _cursor_off: Vector2 = Vector2.ZERO
var _cursor_rot: float = 0.0
var _cursor_scl: Vector2 = Vector2.ONE

var _def_dur: float = 0.3
var _def_trans: Tween.TransitionType = Tween.TRANS_SINE
var _def_ease: Tween.EaseType = Tween.EASE_IN_OUT
var _reset_on_end: bool = true

func _init(animator: BayterekNodeAnimator) -> void:
	_animator = animator
	if animator and animator.node:
		_cursor_off = animator.node.get_visual_offset()
		_cursor_rot = animator.node.get_visual_rotation()
		_cursor_scl = animator.node.get_visual_scale()

# ============================================================
# GROUPING
# ============================================================

func chain() -> BayterekAnimatorBuilder:
	_stack.clear()
	return self

func parallel() -> BayterekAnimatorBuilder:
	var g: Dictionary = {}
	g["kind"] = "group"
	g["mode"] = Mode.PARALLEL
	g["children"] = []
	_push_step(g)
	_stack.append(g)
	return self

func sequence() -> BayterekAnimatorBuilder:
	var g: Dictionary = {}
	g["kind"] = "group"
	g["mode"] = Mode.SEQUENTIAL
	g["children"] = []
	_push_step(g)
	_stack.append(g)
	return self

func end_parallel() -> BayterekAnimatorBuilder:
	if not _stack.is_empty():
		_stack.pop_back()
	return self

func end_sequence() -> BayterekAnimatorBuilder:
	if not _stack.is_empty():
		_stack.pop_back()
	return self

# ============================================================
# STEPS
# ============================================================

func rotate(degrees: float, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	var from_r: float = _cursor_rot
	var to_r: float = _cursor_rot + degrees
	_cursor_rot = to_r
	var s: Dictionary = {}
	s["kind"] = "rotate"
	s["from"] = from_r
	s["to"] = to_r
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func rotate_to(from_deg: float, to_deg: float, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	_cursor_rot = to_deg
	var s: Dictionary = {}
	s["kind"] = "rotate"
	s["from"] = from_deg
	s["to"] = to_deg
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func move(offset: Vector2, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	var from_o: Vector2 = _cursor_off
	var to_o: Vector2 = _cursor_off + offset
	_cursor_off = to_o
	var s: Dictionary = {}
	s["kind"] = "move"
	s["from"] = from_o
	s["to"] = to_o
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func move_to(from_offset: Vector2, to_offset: Vector2, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	_cursor_off = to_offset
	var s: Dictionary = {}
	s["kind"] = "move"
	s["from"] = from_offset
	s["to"] = to_offset
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func scale(factor: float, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	var from_s: Vector2 = _cursor_scl
	var to_s: Vector2 = _cursor_scl * factor
	_cursor_scl = to_s
	var s: Dictionary = {}
	s["kind"] = "scale"
	s["from"] = from_s
	s["to"] = to_s
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func scale_to(from_scale: Vector2, to_scale: Vector2, duration: float = -1.0) -> BayterekAnimatorBuilder:
	var d: float = duration if duration >= 0.0 else _def_dur
	_cursor_scl = to_scale
	var s: Dictionary = {}
	s["kind"] = "scale"
	s["from"] = from_scale
	s["to"] = to_scale
	s["duration"] = d
	s["trans"] = _def_trans
	s["ease"] = _def_ease
	_push_step(s)
	return self

func wait(duration: float) -> BayterekAnimatorBuilder:
	var s: Dictionary = {}
	s["kind"] = "wait"
	s["duration"] = duration
	_push_step(s)
	return self

# ============================================================
# TUNING
# ============================================================

func tune(duration: float = -1.0,
		trans: Tween.TransitionType = Tween.TRANS_SINE,
		ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> BayterekAnimatorBuilder:
	if duration >= 0.0:
		_def_dur = duration
	_def_trans = trans
	_def_ease = ease_type
	return self

func persist(persist_state: bool = true) -> BayterekAnimatorBuilder:
	_reset_on_end = not persist_state
	return self

# ============================================================
# PLAY
# ============================================================

func play() -> Tween:
	# Close any dangling groups.
	while not _stack.is_empty():
		_stack.pop_back()

	if not _animator or not _animator.node:
		push_warning("Builder: animator or node is null.")
		return null
	if _steps.is_empty():
		push_warning("Builder: no steps.")
		return null

	_animator._persist_state = not _reset_on_end
	_animator._snapshot = _animator._capture_snapshot()

	# Flatten the tree into a timeline of absolute (start, duration) entries.
	var timeline: Array = []
	_flatten(_steps, 0.0, timeline)

	# Compute total duration.
	var total_dur: float = 0.0
	for e in timeline:
		var e_end: float = float(e["abs_start"]) + float(e["duration"])
		if e_end > total_dur:
			total_dur = e_end

	if total_dur <= 0.0:
		total_dur = 0.001

	# Spawn one tween per step.
	_animator._child_tweens.clear()
	for e in timeline:
		_spawn_step_tween(e)

	# Master tween waits for the total duration and fires finished.
	var master: Tween = _animator.node.create_tween()
	master.tween_interval(total_dur)

	_animator._active_tween = master
	_animator._active_name = "composed"
	_animator.animation_started.emit("composed")

	var reset: bool = _reset_on_end
	var a: BayterekNodeAnimator = _animator
	var base_off: Vector2 = _cursor_off
	var base_rot: float = _cursor_rot
	var base_scl: Vector2 = _cursor_scl

	master.finished.connect(func() -> void:
		if a._active_tween != master:
			return
		a._active_tween = null
		a._active_name = ""
		if reset:
			a._apply_visual_offset(base_off)
			a._apply_visual_rotation(base_rot)
			a._apply_visual_scale(base_scl)
			a._snapshot.clear()
		a.animation_finished.emit("composed")
	)

	return master

# ============================================================
# FLATTEN (build absolute timeline)
# ============================================================

func _flatten(steps: Array, start: float, out: Array) -> void:
	var t: float = start
	for s in steps:
		# Check BOTH "kind" (leaf) and "type" (group) keys.
		var kind: String = String(s.get("kind", ""))
		if kind.is_empty():
			kind = String(s.get("type", ""))

		if kind == "group":
			var mode: int = s.get("mode", Mode.SEQUENTIAL)
			var children: Array = s.get("children", [])
			var group_dur: float = _duration_of(s)
			if mode == Mode.PARALLEL:
				for c in children:
					_flatten([c], t, out)
			else:
				_flatten(children, t, out)
			t += group_dur
		else:
			var entry: Dictionary = s.duplicate()
			entry["abs_start"] = t
			out.append(entry)
			t += float(s.get("duration", 0.0))

func _duration_of(s: Dictionary) -> float:
	var kind: String = String(s.get("kind", ""))
	if kind.is_empty():
		kind = String(s.get("type", ""))

	if kind != "group":
		return float(s.get("duration", 0.0))

	var mode: int = s.get("mode", Mode.SEQUENTIAL)
	var children: Array = s.get("children", [])
	if mode == Mode.PARALLEL:
		var maxd: float = 0.0
		for c in children:
			var cd: float = _duration_of(c)
			if cd > maxd:
				maxd = cd
		return maxd

	var total: float = 0.0
	for c in children:
		total += _duration_of(c)
	return total

# ============================================================
# SPAWN ONE STEP AS ITS OWN TWEEN
# ============================================================

func _spawn_step_tween(entry: Dictionary) -> void:
	var abs_start: float = float(entry.get("abs_start", 0.0))
	var dur: float = float(entry.get("duration", 0.1))
	var trans: Tween.TransitionType = entry.get("trans", Tween.TRANS_SINE)
	var ease_t: Tween.EaseType = entry.get("ease", Tween.EASE_IN_OUT)
	var kind: String = String(entry.get("kind", ""))

	var tw: Tween = _animator.node.create_tween()
	if abs_start > 0.0:
		tw.tween_interval(abs_start)
	tw.set_trans(trans).set_ease(ease_t)

	match kind:
		"rotate":
			tw.tween_method(_cb_rot, float(entry["from"]), float(entry["to"]), dur)
		"move":
			tw.tween_method(_cb_off, entry["from"], entry["to"], dur)
		"scale":
			tw.tween_method(_cb_scl, entry["from"], entry["to"], dur)
		"wait":
			tw.tween_interval(dur)

	_animator._child_tweens.append(tw)
	tw.finished.connect(func() -> void:
		if _animator:
			_animator._child_tweens.erase(tw)
	)

# ============================================================
# HELPERS
# ============================================================

func _push_step(s: Dictionary) -> void:
	if _stack.is_empty():
		_steps.append(s)
	else:
		var top: Dictionary = _stack[_stack.size() - 1]
		var children: Array = top.get("children", [])
		children.append(s)
		top["children"] = children

# ============================================================
# CALLBACKS
# ============================================================

func _cb_off(v: Vector2) -> void:
	if _animator:
		_animator._apply_visual_offset(v)

func _cb_rot(v: float) -> void:
	if _animator:
		_animator._apply_visual_rotation(v)

func _cb_scl(v: Vector2) -> void:
	if _animator:
		_animator._apply_visual_scale(v)