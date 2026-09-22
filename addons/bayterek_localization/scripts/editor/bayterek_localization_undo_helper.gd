@tool
class_name BayterekLocalizationUndoHelper
extends RefCounted
## Undo/Redo helper for the Localization editor.
##
## Kendi UndoRedo instance'ını kullanır (EditorUndoRedoManager değil),
## çünkü EditorUndoRedoManager'ın add_do_method() API'si Callable değil
## Object + method adı kabul ediyor. Basit tutmak için kendi stack'imizi
## yönetiyoruz; Editor `Ctrl+Z` / `Ctrl+Y` tuşlarını yakalayıp bize iletir.
##
## Batch: aynı key için BATCH_WINDOW_MS içinde gelen değişiklikler tek
## action'a birleşir. Böylece typing sırasında her karakter için ayrı undo
## olmaz.

const BATCH_WINDOW_MS := 800

var _undo_redo: UndoRedo
var _source: Object

## key -> {"value": String, "timestamp": int}
var _last_pushed: Dictionary = {}

func _init(source: Object) -> void:
	_source = source
	_undo_redo = UndoRedo.new()

# ============================================================
# PUBLIC — CONTROL
# ============================================================

func can_undo() -> bool:
	return _undo_redo.has_undo()

func can_redo() -> bool:
	return _undo_redo.has_redo()

func undo() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()

func redo() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()

# ============================================================
# VALUE CHANGE (translation field edit)
# ============================================================

## Translation field için undo action push eder.
##   key       — çeviri anahtarı
##   old_value — değişiklikten önceki değer
##   new_value — değişiklikten sonraki değer
##   locale    — hangi locale (kayıt için tutulur, callback'te kullanılmaz)
##   apply_cb  — Callable(key: String, value: String) -> void
func push_value_change(
	key: String,
	old_value: String,
	new_value: String,
	locale: String,
	apply_cb: Callable
) -> void:
	if old_value == new_value:
		return

	var now: int = Time.get_ticks_msec()
	var last = _last_pushed.get(key, null)

	# Aynı key + batch window içinde → merge.
	if last != null and (now - int(last["timestamp"])) <= BATCH_WINDOW_MS:
		var merged_old: String = String(last["value"])

		_undo_redo.create_action("Edit Translation: %s" % key, UndoRedo.MERGE_ENDS)
		_undo_redo.add_do_method(apply_cb.bind(key, new_value))
		_undo_redo.add_undo_method(apply_cb.bind(key, merged_old))
		_undo_redo.commit_action()

		_last_pushed[key] = {"value": merged_old, "timestamp": now}
		return

	# Yeni action.
	_undo_redo.create_action("Edit Translation: %s" % key, UndoRedo.MERGE_DISABLE)
	_undo_redo.add_do_method(apply_cb.bind(key, new_value))
	_undo_redo.add_undo_method(apply_cb.bind(key, old_value))
	_undo_redo.commit_action()

	_last_pushed[key] = {"value": old_value, "timestamp": now}

# ============================================================
# ADD KEY
# ============================================================

func push_add_key(
	key: String,
	apply_cb: Callable,
	undo_cb: Callable
) -> void:
	_undo_redo.create_action("Add Key: %s" % key, UndoRedo.MERGE_DISABLE)
	_undo_redo.add_do_method(apply_cb)
	_undo_redo.add_undo_method(undo_cb)
	_undo_redo.commit_action()

# ============================================================
# DELETE KEY
# ============================================================

func push_delete_key(
	key: String,
	deleted_values: Dictionary,
	apply_cb: Callable,
	undo_cb: Callable
) -> void:
	_undo_redo.create_action("Delete Key: %s" % key, UndoRedo.MERGE_DISABLE)
	_undo_redo.add_do_method(apply_cb.bind(key))
	_undo_redo.add_undo_method(undo_cb.bind(key, deleted_values))
	_undo_redo.commit_action()

# ============================================================
# RENAME KEY
# ============================================================

func push_rename_key(
	old_key: String,
	new_key: String,
	apply_cb: Callable,
	undo_cb: Callable
) -> void:
	_undo_redo.create_action(
		"Rename Key: %s -> %s" % [old_key, new_key],
		UndoRedo.MERGE_DISABLE
	)
	_undo_redo.add_do_method(apply_cb.bind(old_key, new_key))
	_undo_redo.add_undo_method(undo_cb.bind(old_key, new_key))
	_undo_redo.commit_action()

# ============================================================
# RESET
# ============================================================

## Locale değişince batch state'ini temizle.
func reset_batch() -> void:
	_last_pushed.clear()