@tool
class_name BayterekLogger
extends RefCounted
## Centralized logging for the Bayterek plugin.
##
## All plugin output goes through here so verbosity can be controlled
## from one place, and so we can prefix every line with a consistent
## `[Bayterek]` tag.
##
## Usage:
##     BayterekLogger.info("tree loaded")
##     BayterekLogger.warn("orphan prefab detected", "prefabs")
##     BayterekLogger.error("save failed", "serializer")
##     BayterekLogger.debug("node created id=%d" % node.id, "nodes")
##
## Verbosity is controlled by `Bayterek.VERBOSE_SETTING` in project
## settings. Debug messages are suppressed unless verbose is true.

enum Level {
	DEBUG,
	INFO,
	WARN,
	ERROR,
}

## Minimum level that gets printed. Messages below this are discarded.
## DEBUG shows everything; ERROR shows only errors.
static var min_level: Level = Level.INFO

## Optional prefix shown after [Bayterek]. Useful for runtime builds.
static var prefix: String = ""

# ============================================================
# PUBLIC API
# ============================================================

static func debug(message: String, tag: String = "") -> void:
	_log(Level.DEBUG, message, tag)

static func info(message: String, tag: String = "") -> void:
	_log(Level.INFO, message, tag)

static func warn(message: String, tag: String = "") -> void:
	_log(Level.WARN, message, tag)

static func error(message: String, tag: String = "") -> void:
	_log(Level.ERROR, message, tag)

# ============================================================
# CONFIGURATION
# ============================================================

## Called by BayterekPlugin._enter_tree() to sync verbosity with
## project settings.
static func sync_with_project_settings() -> void:
	# Project setting: addons/bayterek/verbose (bool)
	if ProjectSettings.has_setting("addons/bayterek/verbose"):
		var verbose: bool = ProjectSettings.get_setting("addons/bayterek/verbose", false)
		min_level = Level.DEBUG if verbose else Level.INFO
	else:
		min_level = Level.INFO

## Manual override for testing.
static func set_level(level: Level) -> void:
	min_level = level

static func set_prefix(p: String) -> void:
	prefix = p

# ============================================================
# INTERNAL
# ============================================================

static func _log(level: Level, message: String, tag: String) -> void:
	if level < min_level:
		return

	var level_str: String = _level_to_string(level)
	var tag_str: String = "" if tag.is_empty() else " [%s]" % tag
	var prefix_str: String = "" if prefix.is_empty() else " %s" % prefix
	var line: String = "[Bayterek]%s [%s]%s %s" % [prefix_str, level_str, tag_str, message]

	match level:
		Level.DEBUG:
			print(line)
		Level.INFO:
			print(line)
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)

static func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO:  return "INFO"
		Level.WARN:  return "WARN"
		Level.ERROR: return "ERROR"
		_: return "?"