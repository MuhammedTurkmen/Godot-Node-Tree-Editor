@tool
class_name BayterekPicker
extends RefCounted
## Central helper for all asset pickers used across the plugin.
##
## Godot's Quick Open dialog is a singleton resource. Calling
## `EditorInterface.popup_quick_open` twice in the same frame throws:
##     ERROR: Signal 'canceled' is already connected to given callable
##     'EditorInterface::_quick_open' in that object.
##
## This helper debounces the calls so a second picker request is ignored
## while one is already open. It also gives every picker a `kind` label
## so warnings in the console indicate which code path triggered them.
##
## Usage:
##     BayterekPicker.pick_texture(_on_icon_changed, "icon")
##     BayterekPicker.pick(callback, ["PackedScene"], "scene")

static var _active: bool = false
static var _active_kind: String = ""


## Opens Godot's Quick Open dialog filtered to textures.
## `callback` is called with the selected path, or with "" if cancelled.
static func pick_texture(callback: Callable, kind: String = "texture") -> void:
	pick(callback, ["Texture2D"], kind)


## Opens Godot's Quick Open dialog with the given asset type filter.
static func pick(callback: Callable, types: Array, kind: String = "asset") -> void:
	if _active:
		push_warning("BayterekPicker: picker already active (%s), ignoring request (%s)" % [_active_kind, kind])
		return

	_active = true
	_active_kind = kind

	var wrapped := func(path: String) -> void:
		_active = false
		_active_kind = ""
		callback.call(path)

	EditorInterface.popup_quick_open(wrapped, types)