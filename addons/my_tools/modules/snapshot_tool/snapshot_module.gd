@tool
extends Node

var plugin: EditorPlugin
var snapshot_button: Button
var file_dialog: FileDialog
var target_node: CanvasItem

func setup(editor_plugin: EditorPlugin):
	plugin = editor_plugin
	
	snapshot_button = Button.new()
	snapshot_button.text = "📸"
	snapshot_button.tooltip_text = "Seçili CanvasItem'i PNG olarak kaydet"
	snapshot_button.flat = false
	snapshot_button.pressed.connect(_on_snapshot_pressed)
	
	_apply_button_style()
	
	plugin.add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, snapshot_button)
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png ; PNG Görselleri"])
	file_dialog.title = "Görüntüyü Kaydet"
	file_dialog.current_file = "snapshot.png"
	file_dialog.file_selected.connect(_on_file_selected)
	
	plugin.add_child(file_dialog)
	
	print("📸 Snapshot modülü yüklendi!")

func teardown():
	if snapshot_button:
		plugin.remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, snapshot_button)
		snapshot_button.queue_free()
	
	if file_dialog:
		file_dialog.queue_free()
	
	print("📸 Snapshot modülü kaldırıldı!")

func trigger_snapshot():
	_on_snapshot_pressed()

func _apply_button_style():
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#101113")
	normal_style.corner_radius_top_left = 3
	normal_style.corner_radius_top_right = 3
	normal_style.corner_radius_bottom_left = 3
	normal_style.corner_radius_bottom_right = 3
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#27282a")
	hover_style.corner_radius_top_left = 3
	hover_style.corner_radius_top_right = 3
	hover_style.corner_radius_bottom_left = 3
	hover_style.corner_radius_bottom_right = 3
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.5, 0.5, 0.5, 1.0)
	pressed_style.corner_radius_top_left = 3
	pressed_style.corner_radius_top_right = 3
	pressed_style.corner_radius_bottom_left = 3
	pressed_style.corner_radius_bottom_right = 3
	
	snapshot_button.add_theme_stylebox_override("normal", normal_style)
	snapshot_button.add_theme_stylebox_override("hover", hover_style)
	snapshot_button.add_theme_stylebox_override("pressed", pressed_style)
	snapshot_button.add_theme_stylebox_override("focus", hover_style)

func _on_snapshot_pressed():
	var selected_nodes = plugin.get_editor_interface().get_selection().get_selected_nodes()
	
	if selected_nodes.is_empty():
		push_warning("Lütfen bir CanvasItem node'u seçin!")
		return
	
	target_node = null
	for node in selected_nodes:
		if node is CanvasItem:
			target_node = node
			break
	
	if not target_node:
		push_warning("Seçili node bir CanvasItem değil!")
		return
	
	file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String):
	if not target_node:
		return
	await _capture_node(path)

func _capture_node(path: String):
	var node_rect = _get_node_rect(target_node)
	
	if node_rect.size == Vector2.ZERO:
		push_warning("Node'un boyutu sıfır, yakalanamadı!")
		return
	
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(node_rect.size)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.disable_3d = true
	
	var duplicate_node = target_node.duplicate()
	
	if duplicate_node is Control:
		duplicate_node.position = Vector2.ZERO
		duplicate_node.size = target_node.size
	elif duplicate_node is Node2D:
		duplicate_node.position = Vector2.ZERO
	
	sub_viewport.add_child(duplicate_node)
	
	var editor_base = plugin.get_editor_interface().get_base_control()
	editor_base.add_child(sub_viewport)
	
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	
	var img = sub_viewport.get_texture().get_image()
	sub_viewport.queue_free()
	
	var err = img.save_png(path)
	if err == OK:
		print("Görsel başarıyla kaydedildi: ", path)
	else:
		push_error("Görsel kaydedilemedi, hata kodu: ", err)

func _get_node_rect(node: CanvasItem) -> Rect2:
	var default_rect = Rect2(Vector2.ZERO, Vector2(256, 256))
	
	if node is Control:
		var control = node as Control
		if control.size != Vector2.ZERO:
			return Rect2(Vector2.ZERO, control.size)
		return default_rect
		
	elif node is Sprite2D:
		var sprite = node as Sprite2D
		if sprite.texture:
			var texture_size = sprite.texture.get_size()
			if texture_size != Vector2.ZERO:
				return Rect2(Vector2.ZERO, texture_size)
		return default_rect
		
	elif node is AnimatedSprite2D:
		var animated_sprite = node as AnimatedSprite2D
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
			var frame_texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
			if frame_texture and frame_texture.get_size() != Vector2.ZERO:
				return Rect2(Vector2.ZERO, frame_texture.get_size())
		return default_rect
		
	elif node is Node2D:
		var node2d = node as Node2D
		var rect = node2d.get_rect()
		if rect.size != Vector2.ZERO:
			return rect
		
		for child in node2d.get_children():
			if child is CanvasItem:
				var child_rect = _get_node_rect(child)
				if child_rect.size != Vector2.ZERO:
					return child_rect
		
		return default_rect
	
	return default_rect