@tool
class_name BayterekLayerStateColors
extends VBoxContainer
## 8-row state color editor.
## Each row: [CheckBox] [Label] [ColorPicker]

signal changed

var _configs: Dictionary = {}
var _updating: bool = false

var _rows: Dictionary = {}  # state -> {check: CheckBox, picker: ColorPickerButton}
var _owner_layer: BayterekLayer = null
var _config_key: String = ""  # "fill_configs" or "border_configs" or "tint_configs"

var _ui_ready: bool = false

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
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)

		var picker := ColorPickerButton.new()
		picker.size_flags_horizontal = SIZE_EXPAND_FILL
		picker.custom_minimum_size = Vector2(0, 22)
		picker.color_changed.connect(_on_color_changed.bind(state))
		row.add_child(picker)

		_rows[state] = {"check": check, "picker": picker}

# ============================================================
# PUBLIC
# ============================================================

## Binds to a layer and a config key ("fill_configs", "border_configs", "tint_configs").
func bind(layer: BayterekLayer, config_key: String) -> void:
	_owner_layer = layer
	_config_key = config_key
	if _ui_ready:
		_refresh_from_data()

func _refresh_from_data() -> void:
	if not _owner_layer:
		return

	# Guard: UI not built
	if not _ui_ready:
		return
	if _rows.size() < BayterekLayer.STATES.size():
		return

	_updating = true

	# Read source dictionary
	var configs = _owner_layer.get(_config_key)

	# Normalize into a clean dictionary — this also repairs malformed data
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
				# Malformed entry (e.g. bare Color) — treat as disabled with default color
				normalized[state] = {
					"enabled": false,
					"color": entry if entry is Color else Color.WHITE,
				}
	else:
		normalized = {}

	_configs = normalized

	# Apply to UI rows
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
# HANDLERS
# ============================================================

func _on_check_toggled(pressed: bool, state: String) -> void:
	if _updating or not _owner_layer:
		return
	_ensure_config(state)
	_configs[state]["enabled"] = pressed
	_push_configs_to_layer()
	changed.emit()

func _on_color_changed(color: Color, state: String) -> void:
	if _updating or not _owner_layer:
		return
	_ensure_config(state)
	_configs[state]["color"] = color
	_push_configs_to_layer()
	changed.emit()

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