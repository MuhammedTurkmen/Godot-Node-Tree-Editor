@tool
class_name AudioStreamInput
extends HBoxContainer
## A simple audio stream picker: [stream name] [Load] [X]
##
## Used by the Settings panel to pick the purchase SFX slots.

signal changed(stream: AudioStream)

var _label: Label
var _load_btn: Button
var _clear_btn: Button

var _current_stream: AudioStream = null

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_ui()
	_refresh_label()

func _build_ui() -> void:
	_label = Label.new()
	_label.text = "(empty)"
	_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_label)

	_load_btn = Button.new()
	_load_btn.text = "..."
	_load_btn.tooltip_text = "Pick an audio stream"
	_load_btn.custom_minimum_size = Vector2(30, 22)
	_load_btn.pressed.connect(_on_load_pressed)
	add_child(_load_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "X"
	_clear_btn.tooltip_text = "Clear"
	_clear_btn.custom_minimum_size = Vector2(24, 22)
	_clear_btn.pressed.connect(_on_clear_pressed)
	add_child(_clear_btn)

func set_stream(stream: AudioStream) -> void:
	_current_stream = stream
	_refresh_label()

func get_stream() -> AudioStream:
	return _current_stream

func _refresh_label() -> void:
	if not _label:
		return
	if _current_stream:
		var path: String = _current_stream.resource_path
		if path.is_empty():
			_label.text = _current_stream.get_class()
		else:
			_label.text = path.get_file()
		_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	else:
		_label.text = "(empty)"
		_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))

func _on_load_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	BayterekPicker.pick(_on_file_selected, ["AudioStream"], "audio_stream")

func _on_file_selected(path: String) -> void:
	if path.is_empty():
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		set_stream(stream)
		changed.emit(stream)

func _on_clear_pressed() -> void:
	set_stream(null)
	changed.emit(null)