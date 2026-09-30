@tool
class_name BayterekLayerStateColors
extends VBoxContainer
## 8-row state color editor.
##
## Every checkbox toggle and color pick are routed through the parent
## Node Editor's UndoRedo instance so Ctrl+Z works on individual state
## changes.

signal changed

static var _copied_color: Color = Color.WHITE
static var _has_copied_color: bool = false

const CM_COPY := 1
const CM_PASTE := 2

var _configs: Dictionary = {}
var _updating: bool = false

var _rows: Dictionary = {}
var _owner_layer: BayterekLayer = null
var _config_key: String = ""
var _node_editor: BayterekNodeEditorScreen = null

var _ui_ready: bool = false
var _context_menu: PopupMenu
var _context_state: String = ""

## Design (for export) — set via `bind_export()`.
var _design: BayterekNodeDesign = null

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_ui()
	_build_context_menu()
	_ui_ready = true
	if _owner_layer:
		_refresh_from_data()

func _build_ui() -> void:
	for state in BayterekLayer.STATES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)

		var check := CheckBox.new()
		check.custom_minimum_size = Vector2(24, 0)
		check.toggled.connect(_on_check_toggled.bind(state))
		row.add_child(check)

		var label := Label.new()
		label.text = state.capitalize()
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)

		var picker := ColorPickerButton.new()
		picker.size_flags_horizontal = SIZE_EXPAND_FILL
		picker.custom_minimum_size = Vector2(0, 22)
		picker.color_changed.connect(_on_color_changed.bind(state))
		picker.gui_input.connect(_on_picker_gui_input.bind(state))
		row.add_child(picker)

		_rows[state] = {"check": check, "picker": picker, "row": row}

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Copy Color", CM_COPY)
	_context_menu.add_item("Paste Color", CM_PASTE)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(_context_menu)

# ============================================================
# STATIC RESET
# ============================================================

static func reset_copy_state() -> void:
	_has_copied_color = false
	_copied_color = Color.WHITE

# ============================================================
# PUBLIC
# ============================================================

func bind(layer: BayterekLayer, config_key: String) -> void:
	_owner_layer = layer
	_config_key = config_key
	if _ui_ready:
		_refresh_from_data()

## Provides access to the parent Node Editor for undoable operations.
func bind_editor(node_editor: BayterekNodeEditorScreen) -> void:
	_node_editor = node_editor

## Attaches export functionality to each state row.
func bind_export(design: BayterekNodeDesign, layer_id: String, sub_key: String, on_changed: Callable = Callable()) -> void:
	_design = design

	if not design or layer_id.is_empty() or sub_key.is_empty():
		return

	for state in BayterekLayer.STATES:
		if not _rows.has(state):
			continue
		var row: HBoxContainer = _rows[state].get("row", null)
		if not row:
			continue

		var fp_enabled: String = "layers.%s.%s.%s.enabled" % [layer_id, sub_key, state]
		var fp_color: String = "layers.%s.%s.%s.color" % [layer_id, sub_key, state]

		BayterekExportHelper.make_exportable(row, fp_enabled, design, on_changed)

		var picker: ColorPickerButton = _rows[state].get("picker", null)
		if picker:
			BayterekExportHelper.make_exportable(picker, fp_color, design, on_changed)

func _refresh_from_data() -> void:
	if not _owner_layer:
		return
	if not _ui_ready:
		return
	if _rows.size() < BayterekLayer.STATES.size():
		return

	_updating = true

	var configs = _owner_layer.get(_config_key)

	var normalized: Dictionary = {}
	if configs is Dictionary:
		for state in configs.keys():
			var entry = configs[state]
			if entry is Dictionary:
				normalized[state] = {
					"enabled": entry.get("enabled", false),
					"color": entry.get("color", Color.WHITE),
				}
			else:
				normalized[state] = {
					"enabled": false,
					"color": entry if entry is Color else Color.WHITE,
				}
	else:
		normalized = {}

	_configs = normalized

	for state in BayterekLayer.STATES:
		if not _rows.has(state):
			continue
		var row_data: Dictionary = _rows[state]
		var check: CheckBox = row_data.get("check")
		var picker: ColorPickerButton = row_data.get("picker")
		if not check or not picker:
			continue

		if normalized.has(state):
			var entry: Dictionary = normalized[state]
			check.button_pressed = entry.get("enabled", false)
			picker.color = entry.get("color", Color.WHITE)
		else:
			check.button_pressed = false
			picker.color = Color.WHITE

	_updating = false

# ============================================================
# UNDO-COMMIT HELPER
# ============================================================

func _commit(action_name: String, do_cb: Callable, undo_cb: Callable) -> void:
	if _node_editor and _node_editor.has_method("commit_undoable"):
		var ok: bool = _node_editor.commit_undoable(action_name, do_cb, undo_cb)
		if ok:
			return
	do_cb.call()

func _get_current_configs_snapshot() -> Dictionary:
	if not _owner_layer:
		return {}
	var raw = _owner_layer.get(_config_key)
	if raw is Dictionary:
		return raw.duplicate(true)
	return {}

# ============================================================
# HANDLERS
# ============================================================

func _on_check_toggled(pressed: bool, state: String) -> void:
	if _updating or not _owner_layer:
		return

	var old_configs: Dictionary = _get_current_configs_snapshot()
	var new_configs: Dictionary = old_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["enabled"] = pressed

	var layer_ref: BayterekLayer = _owner_layer
	var config_key: String = _config_key

	var do_cb := func():
		layer_ref.set(config_key, new_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()
	var undo_cb := func():
		layer_ref.set(config_key, old_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()

	_commit("Toggle Color State", do_cb, undo_cb)
	changed.emit()

func _on_color_changed(color: Color, state: String) -> void:
	if _updating or not _owner_layer:
		return

	var old_configs: Dictionary = _get_current_configs_snapshot()
	var new_configs: Dictionary = old_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["color"] = color

	var layer_ref: BayterekLayer = _owner_layer
	var config_key: String = _config_key

	var do_cb := func():
		layer_ref.set(config_key, new_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()
	var undo_cb := func():
		layer_ref.set(config_key, old_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()

	_commit("Change State Color", do_cb, undo_cb)
	changed.emit()

func _ensure_config_in(configs: Dictionary, state: String) -> void:
	if not configs.has(state):
		configs[state] = {"enabled": false, "color": Color.WHITE}
	elif not configs[state] is Dictionary:
		configs[state] = {"enabled": false, "color": Color.WHITE}

# ============================================================
# LEGACY HELPERS (kept for compatibility)
# ============================================================

func _ensure_config(state: String) -> void:
	if not _configs.has(state):
		_configs[state] = {"enabled": false, "color": Color.WHITE}
	elif not _configs[state] is Dictionary:
		_configs[state] = {"enabled": false, "color": Color.WHITE}

func _push_configs_to_layer() -> void:
	if not _owner_layer:
		return
	_owner_layer.set(_config_key, _configs)
	if _owner_layer.has_method("notify_modified"):
		_owner_layer.notify_modified()

# ============================================================
# CONTEXT MENU
# ============================================================

func _on_picker_gui_input(event: InputEvent, state: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_context_state = state
			var picker: ColorPickerButton = _rows[state].get("picker")
			if not picker:
				return

			var copy_idx: int = _context_menu.get_item_index(CM_COPY)
			var paste_idx: int = _context_menu.get_item_index(CM_PASTE)
			_context_menu.set_item_disabled(copy_idx, false)
			_context_menu.set_item_disabled(paste_idx, not _has_copied_color)

			var global_pos: Vector2 = picker.get_screen_position() + Vector2(0, picker.size.y)
			_context_menu.position = Vector2i(global_pos)
			_context_menu.popup()

			picker.accept_event()

func _on_context_menu_pressed(id: int) -> void:
	match id:
		CM_COPY: _copy_color(_context_state)
		CM_PASTE: _paste_color(_context_state)

func _copy_color(state: String) -> void:
	if not _configs.has(state):
		return
	var entry = _configs[state]
	if not entry is Dictionary:
		return
	_copied_color = entry.get("color", Color.WHITE)
	_has_copied_color = true

func _paste_color(state: String) -> void:
	if not _owner_layer or not _has_copied_color:
		return

	var old_configs: Dictionary = _get_current_configs_snapshot()
	var new_configs: Dictionary = old_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["color"] = _copied_color

	var layer_ref: BayterekLayer = _owner_layer
	var config_key: String = _config_key
	var pasted_color: Color = _copied_color
	var captured_state: String = state

	var do_cb := func():
		layer_ref.set(config_key, new_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()
		# Refresh the UI to show the new color.
		if _rows.has(captured_state):
			_updating = true
			var picker: ColorPickerButton = _rows[captured_state].get("picker")
			if picker:
				picker.color = pasted_color
			_updating = false
	var undo_cb := func():
		layer_ref.set(config_key, old_configs.duplicate(true))
		if layer_ref.has_method("notify_modified"):
			layer_ref.notify_modified()
		if _rows.has(captured_state):
			_updating = true
			var picker: ColorPickerButton = _rows[captured_state].get("picker")
			if picker:
				var old_entry = old_configs.get(captured_state, {})
				var old_color = old_entry.get("color", Color.WHITE) if old_entry is Dictionary else Color.WHITE
				picker.color = old_color
			_updating = false

	_commit("Paste State Color", do_cb, undo_cb)
	changed.emit()