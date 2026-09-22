@tool
class_name BayterekLocalizationMainScreen
extends MarginContainer
## Main screen — hosts the Browser and Editor tabs.

const Localization = preload("res://addons/bayterek_localization/scripts/shared/bayterek_localization.gd")

signal region_opened(locale: String)

var initialized: bool = false

var tab_container: TabContainer
var browser: BayterekLocalizationBrowser
var editor: BayterekLocalizationEditor

var _open_locale: String = ""

func _ready() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 0)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_force_layout_refresh")

func _force_layout_refresh() -> void:
	if not is_inside_tree():
		return
	if tab_container:
		tab_container.queue_sort()
	if browser:
		browser.queue_sort()

func init() -> void:
	if initialized:
		return
	initialized = true

	_build_ui()

	if browser:
		browser.main_screen = self
		browser.init()
	if editor:
		editor.init()

	_force_layout_refresh()
	print("[BayterekLocalizationMainScreen] ready.")

func _build_ui() -> void:
	if tab_container:
		return

	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size_flags_horizontal = SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(_on_tab_changed)
	add_child(tab_container)

	browser = BayterekLocalizationBrowser.new()
	browser.name = "Browser"
	browser.size_flags_horizontal = SIZE_EXPAND_FILL
	browser.size_flags_vertical = SIZE_EXPAND_FILL
	browser.region_activated.connect(_on_browser_region_activated)
	tab_container.add_child(browser)
	tab_container.set_tab_title(0, "Browser")

	editor = BayterekLocalizationEditor.new()
	editor.name = "Editor"
	editor.size_flags_horizontal = SIZE_EXPAND_FILL
	editor.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.add_child(editor)
	tab_container.set_tab_title(1, "Editor")

# ============================================================
# TAB CHANGE
# ============================================================

func _on_tab_changed(tab_idx: int) -> void:
	# When the user switches back to the Browser tab, reload the registry
	# from disk so any external changes (scripts, editor, hand edits) show
	# up immediately.
	if tab_container and browser:
		var browser_idx: int = tab_container.get_tab_idx_from_control(browser)
		if tab_idx == browser_idx:
			if browser.has_method("on_tab_shown"):
				browser.call("on_tab_shown")

# ============================================================
# OPEN REGION IN EDITOR TAB
# ============================================================

func _on_browser_region_activated(locale: String) -> void:
	open_region(locale)

func open_region(locale: String) -> void:
	if locale.is_empty():
		return

	_open_locale = locale

	if tab_container and editor:
		var idx: int = tab_container.get_tab_idx_from_control(editor)
		if idx >= 0:
			tab_container.current_tab = idx

	if editor:
		editor.open_locale(locale)

	print("[BayterekLocalizationMainScreen] open_region: %s" % locale)