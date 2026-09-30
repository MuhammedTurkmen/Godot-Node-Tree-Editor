@tool
class_name BayterekLayerStateTextures
extends VBoxContainer
## 8-row state texture editor.
##
## Every checkbox toggle, texture assignment, and texture clear is
## routed through the parent Node Editor's UndoRedo instance so Ctrl+Z
## works on individual state changes.

signal changed

var _configs: Dictionary = {}
var _updating: bool = false

var _rows: Dictionary = {}
var _owner_layer: BayterekLayer = null
var _node_editor: BayterekNodeEditorScreen = null

var _ui_ready: bool = false

var _design: BayterekNodeDesign = null

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_ui()
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
		label.custom_minimum_size = Vector2(80, 0)
		row.add_child(label)

		var input := BayterekInspectorTextureInput.new()
		input.title = ""
		input.size_flags_horizontal = SIZE_EXPAND_FILL
		input.texture_dropped.connect(_on_texture_dropped.bind(state))
		input.cleared.connect(_on_texture_cleared.bind(state))
		row.add_child(input)

		_rows[state] = {"check": check, "input": input, "row": row}

# ============================================================
# PUBLIC
# ============================================================

func bind(layer: BayterekLayer) -> void:
	_owner_layer = layer
	if _ui_ready:
		_refresh_from_data()

## Provides access to the parent Node Editor for undoable operations.
## Called by the layer editor after it's built.
func bind_editor(node_editor: BayterekNodeEditorScreen) -> void:
	_node_editor = node_editor

## Attaches export functionality to each state row.
func bind_export(design: BayterekNodeDesign, layer_id: String, on_changed: Callable = Callable()) -> void:
	_design = design

	if not design or layer_id.is_empty():
		return

	for state in BayterekLayer.STATES:
		if not _rows.has(state):
			continue
		var row: HBoxContainer = _rows[state].get("row", null)
		if not row:
			continue

		var fp_enabled: String = "layers.%s.icon_configs.%s.enabled" % [layer_id, state]
		var fp_texture: String = "layers.%s.icon_configs.%s.texture" % [layer_id, state]

		BayterekExportHelper.make_exportable(row, fp_enabled, design, on_changed)

		var tex_input: BayterekInspectorTextureInput = _rows[state].get("input", null)
		if tex_input:
			BayterekExportHelper.make_exportable(tex_input, fp_texture, design, on_changed)

func _refresh_from_data() -> void:
	if not _owner_layer:
		return
	if not _ui_ready:
		return
	if _rows.size() < BayterekLayer.STATES.size():
		return

	_updating = true

	var source: Dictionary = {}
	if _owner_layer is BayterekTextureLayer:
		var raw = _owner_layer.icon_configs
		if raw is Dictionary:
			for state in raw.keys():
				var entry = raw[state]
				if entry is Dictionary:
					source[state] = {
						"enabled": entry.get("enabled", false),
						"texture": entry.get("texture", null),
					}
				else:
					source[state] = {"enabled": false, "texture": null}

	_configs = source

	for state in BayterekLayer.STATES:
		if not _rows.has(state):
			continue
		var row_data: Dictionary = _rows[state]
		var check: CheckBox = row_data.get("check")
		var input: BayterekInspectorTextureInput = row_data.get("input")
		if not check or not input:
			continue

		if source.has(state):
			var entry: Dictionary = source[state]
			check.button_pressed = entry.get("enabled", false)
			input.set_texture(entry.get("texture", null))
		else:
			check.button_pressed = false
			input.set_texture(null)

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

# ============================================================
# HANDLERS
# ============================================================

func _on_check_toggled(pressed: bool, state: String) -> void:
	if _updating or not _owner_layer:
		return
	if not (_owner_layer is BayterekTextureLayer):
		return

	var old_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	var new_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["enabled"] = pressed

	var layer_ref: BayterekTextureLayer = _owner_layer

	var do_cb := func():
		layer_ref.icon_configs = new_configs.duplicate(true)
	var undo_cb := func():
		layer_ref.icon_configs = old_configs.duplicate(true)

	_commit("Toggle Texture State", do_cb, undo_cb)
	changed.emit()

func _on_texture_dropped(path: String, state: String) -> void:
	if _updating or not _owner_layer:
		return
	if path.is_empty():
		return
	if not (_owner_layer is BayterekTextureLayer):
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return

	var old_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	var new_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["texture"] = tex

	var layer_ref: BayterekTextureLayer = _owner_layer

	var do_cb := func():
		layer_ref.icon_configs = new_configs.duplicate(true)
	var undo_cb := func():
		layer_ref.icon_configs = old_configs.duplicate(true)

	_commit("Assign Texture", do_cb, undo_cb)
	changed.emit()

func _on_texture_cleared(state: String) -> void:
	if _updating or not _owner_layer:
		return
	if not (_owner_layer is BayterekTextureLayer):
		return

	var old_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	var new_configs: Dictionary = _owner_layer.icon_configs.duplicate(true)
	_ensure_config_in(new_configs, state)
	new_configs[state]["texture"] = null

	var layer_ref: BayterekTextureLayer = _owner_layer

	var do_cb := func():
		layer_ref.icon_configs = new_configs.duplicate(true)
	var undo_cb := func():
		layer_ref.icon_configs = old_configs.duplicate(true)

	_commit("Clear Texture", do_cb, undo_cb)
	changed.emit()

func _ensure_config_in(configs: Dictionary, state: String) -> void:
	if not configs.has(state):
		configs[state] = {"enabled": false, "texture": null}
	elif not configs[state] is Dictionary:
		configs[state] = {"enabled": false, "texture": null}

## Legacy helper kept for compatibility. The public API now goes through
## _commit() so this is no longer called from the UI, but external code
## may still rely on it.
func _ensure_config(state: String) -> void:
	if not _configs.has(state):
		_configs[state] = {"enabled": false, "texture": null}
	elif not _configs[state] is Dictionary:
		_configs[state] = {"enabled": false, "texture": null}

## Legacy helper kept for compatibility.
func _push_configs_to_layer() -> void:
	if not _owner_layer:
		return
	if _owner_layer is BayterekTextureLayer:
		_owner_layer.icon_configs = _configs