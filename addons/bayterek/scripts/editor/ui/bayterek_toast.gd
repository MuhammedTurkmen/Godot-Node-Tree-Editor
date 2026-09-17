@tool
class_name BayterekToast
extends RefCounted
## Toast / notification utility.
##
## Renders a small horizontal badge at the bottom-left of a host Control.
## Auto-fades out after a short delay.
##
## Usage:
##     BayterekToast.info(tree_view, "Chain Mode: ON")
##     BayterekToast.success(tree_view, "Tree saved")
##     BayterekToast.warning(tree_view, "No root node set")
##     BayterekToast.error(tree_view, "Failed to save")
##
## The toast is added as a child of the host control and removes itself
## automatically when the fade-out animation completes.

const FadeOutScript = preload("res://addons/bayterek/scripts/editor/ui/fade_out.gd")

const COLOR_INFO := Color(0.85, 0.90, 1.00)
const COLOR_SUCCESS := Color(0.36, 1.00, 0.54)
const COLOR_WARNING := Color(1.00, 0.85, 0.40)
const COLOR_ERROR := Color(1.00, 0.40, 0.40)

const BOTTOM_MARGIN := 50.0
const LEFT_MARGIN := 16.0
const MIN_WIDTH := 220.0
const PADDING_X := 12
const PADDING_Y := 5

# ------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------

## Show an informational toast (blue-ish white).
static func info(host: Control, message: String) -> void:
	_show(host, message, COLOR_INFO)

## Show a success toast (green).
static func success(host: Control, message: String) -> void:
	_show(host, message, COLOR_SUCCESS)

## Show a warning toast (yellow).
static func warning(host: Control, message: String) -> void:
	_show(host, message, COLOR_WARNING)

## Show an error toast (red).
static func error(host: Control, message: String) -> void:
	_show(host, message, COLOR_ERROR)

## Show a toast with a custom color.
## `message` supports BBCode: [b], [i], [color=...], etc.
static func custom(host: Control, message: String, color: Color) -> void:
	_show(host, message, color)

# ------------------------------------------------------------
# INTERNAL
# ------------------------------------------------------------

static func _show(host: Control, message: String, color: Color) -> void:
	if not host or not is_instance_valid(host):
		push_warning("BayterekToast: host is null or invalid.")
		return
	if not host.is_inside_tree():
		push_warning("BayterekToast: host is not inside the scene tree yet.")
		return

	# --- Panel with rounded background ---
	var panel := FadeOutScript.new()
	panel.interactable = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = PADDING_X
	style.content_margin_right = PADDING_X
	style.content_margin_top = PADDING_Y
	style.content_margin_bottom = PADDING_Y
	panel.add_theme_stylebox_override("panel", style)

	# --- RichTextLabel with BBCode ---
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(MIN_WIDTH, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Color the whole text using BBCode so [b], [i] etc. still work.
	label.push_color(color)
	label.append_text(message)
	label.pop()

	panel.add_child(label)

	# --- Attach to host ---
	host.add_child(panel)
	panel.reset_size()

	# --- Position: bottom-left of host ---
	# Wait one frame so panel.size is computed after layout.
	if host.is_inside_tree():
		_reposition_next_frame(host, panel)


static func _reposition_next_frame(host: Control, panel: Control) -> void:
	# Defer positioning until the next idle frame so size is valid.
	await host.get_tree().process_frame
	if not is_instance_valid(host) or not is_instance_valid(panel):
		return

	var host_size: Vector2 = host.size
	panel.position = Vector2(
		LEFT_MARGIN,
		host_size.y - BOTTOM_MARGIN
	)