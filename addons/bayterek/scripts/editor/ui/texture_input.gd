@tool
class_name BayterekInspectorTextureInput
extends HBoxContainer
## Texture input widget'ı (thumbnail + browse + clear).

signal texture_dropped(path: String)
signal cleared

@export var title: String = "Texture":
	set(value):
		title = value
		if _label:
			_label.text = value

var _label: Label
var _texture_rect: TextureRect
var _load_button: Button
var _clear_button: Button
var _empty_label: Label

var _current_texture: Texture2D
var _ui_ready: bool = false

func _ready() -> void:
	_build_ui()
	_ui_ready = true
	# _ready öncesi set_texture çağrıldıysa uygula
	_apply_texture()

func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	_label = Label.new()
	_label.text = title
	_label.custom_minimum_size = Vector2(80, 0)
	_label.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_label)

	var thumb_container := Control.new()
	thumb_container.custom_minimum_size = Vector2(64, 64)
	thumb_container.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(thumb_container)

	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_container.add_child(_texture_rect)
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_empty_label = Label.new()
	_empty_label.text = "Empty"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	thumb_container.add_child(_empty_label)
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_load_button = Button.new()
	_load_button.text = "..."
	_load_button.tooltip_text = "Texture seç"
	_load_button.flat = false
	_load_button.custom_minimum_size = Vector2(24, 20)
	_load_button.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb_container.add_child(_load_button)
	_load_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_load_button.offset_left = -24
	_load_button.offset_top = -20
	_load_button.offset_right = 0
	_load_button.offset_bottom = 0

	_clear_button = Button.new()
	_clear_button.text = "X"
	_clear_button.tooltip_text = "Temizle"
	_clear_button.flat = false
	_clear_button.custom_minimum_size = Vector2(20, 20)
	_clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb_container.add_child(_clear_button)
	_clear_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clear_button.offset_left = -20
	_clear_button.offset_top = 0
	_clear_button.offset_right = 0
	_clear_button.offset_bottom = 20

	_load_button.pressed.connect(_on_load_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)

# ============================================================
# PUBLIC API
# ============================================================

func set_texture(texture: Texture2D) -> void:
	_current_texture = texture
	if not _ui_ready:
		# _ready henüz çağrılmadı — sakla, _ready'de uygulanacak.
		return
	_apply_texture()

func get_texture() -> Texture2D:
	return _current_texture

func _apply_texture() -> void:
	if not _texture_rect:
		return
	_texture_rect.texture = _current_texture

	if _current_texture:
		if _empty_label:
			_empty_label.visible = false
		if _clear_button:
			_clear_button.visible = true
		if _load_button:
			_load_button.visible = true
	else:
		if _empty_label:
			_empty_label.visible = true
		if _clear_button:
			_clear_button.visible = false
		if _load_button:
			_load_button.visible = true

# ============================================================
# HANDLER'LAR
# ============================================================

func _on_load_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	BayterekPicker.pick_texture(_on_file_selected, "texture_input")

func _on_clear_pressed() -> void:
	set_texture(null)
	cleared.emit()

func _on_file_selected(path: String) -> void:
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		set_texture(tex)
		texture_dropped.emit(path)