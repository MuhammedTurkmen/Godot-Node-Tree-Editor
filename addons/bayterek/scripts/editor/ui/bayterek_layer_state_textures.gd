@tool
class_name BayterekLayerStateTextures
extends VBoxContainer
## 8-row state texture editor.

signal changed

var _configs: Dictionary = {}
var _updating: bool = false

var _rows: Dictionary = {}
var _owner_layer: BayterekLayer = null

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
# HANDLERS
# ============================================================

func _on_check_toggled(pressed: bool, state: String) -> void:
	if _updating or not _owner_layer:
		return
	_ensure_config(state)
	_configs[state]["enabled"] = pressed
	_push_configs_to_layer()
	changed.emit()

func _on_texture_dropped(path: String, state: String) -> void:
	if _updating or not _owner_layer:
		return
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	_ensure_config(state)
	_configs[state]["texture"] = tex
	_push_configs_to_layer()
	changed.emit()

func _on_texture_cleared(state: String) -> void:
	if _updating or not _owner_layer:
		return
	_ensure_config(state)
	_configs[state]["texture"] = null
	_push_configs_to_layer()
	changed.emit()

func _ensure_config(state: String) -> void:
	if not _configs.has(state):
		_configs[state] = {"enabled": false, "texture": null}
	elif not _configs[state] is Dictionary:
		_configs[state] = {"enabled": false, "texture": null}

func _push_configs_to_layer() -> void:
	if not _owner_layer:
		return
	if _owner_layer is BayterekTextureLayer:
		_owner_layer.icon_configs = _configs