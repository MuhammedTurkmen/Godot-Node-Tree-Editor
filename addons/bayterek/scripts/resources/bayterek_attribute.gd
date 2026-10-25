@tool
class_name BayterekAttribute
extends Resource
## Attribute definition.
##
## Currency attributes (is_currency = true) represent a purchase cost.
## By default, refund = purchase. If the user checks `refund_differs`,
## the attribute stores two separate values per level: [purchase, refund].
##
## Non-currency attributes behave as before (value_count = 0..4) and
## use `operation` to decide HOW they combine into the player's total:
##   ADD      → total += value       (cumulative, most common)
##   SUBTRACT → total -= value       (negative effect)
##   SET      → total  = value       (overrides everything)
##   MULTIPLY → total *= value       (multiplier)
##   MIN      → total  = min(total, value)
##   MAX      → total  = max(total, value)
##
## Currency attributes IGNORE `operation` — their purchase/refund is
## handled by the wallet callbacks (wallet_spend / wallet_refund).
##
## LOCALIZATION:
##   `name_key` is an optional localization key for the attribute's
##   display name. `effect_key` is an optional localization key for
##   the attribute's effect text. Both are resolved via GameLocalization
##   at render time; `name` and `effect` are the fallbacks.
##
## CUMULATIVE MODE:
##   When `cumulative` is true, multi-allocation levels are summed:
##     level 2 contributes level1 + level2 values.
##   When false (default), only the current level's value applies.
##   Tooltip and runtime accumulation both respect this flag.
##
##   Cumulative only makes sense for ADD and SUBTRACT operations.
##   For SET / MULTIPLY / MIN / MAX it produces nonsensical results,
##   so the editor auto-disables it and the runtime falls back to
##   absolute mode.
##
## ID RULE:
##   `id` is derived from `name` via snake_case. The editor updates it
##   as you type. If the derived id collides with another attribute,
##   the editor keeps the previous id and shows a red warning — the
##   user can rename to resolve the collision, or save (which will
##   prompt to auto-suffix the colliding ids).

enum Operation {
	ADD,        ## total += value       (cumulative, most common)
	SUBTRACT,   ## total -= value       (negative effect)
	SET,        ## total  = value       (overrides all others)
	MULTIPLY,   ## total *= value       (multiplier)
	MIN,        ## total  = min(total, value)  (ceiling)
	MAX,        ## total  = max(total, value)  (floor)
}

@export_storage var is_currency: bool = false
@export_storage var refund_differs: bool = false

## When true, multi-allocation levels are treated as CUMULATIVE:
##   level 2 contributes level1 + level2 values.
## When false (default), only the current level's value applies.
##
## Tooltip and runtime accumulation both respect this flag.
## Has no effect on single-allocation trees or currency attributes.
## Only meaningful for ADD and SUBTRACT operations.
@export_storage var cumulative: bool = false

@export_storage var id: String
@export_storage var name: String

## Optional localization key for the attribute's display name.
## When set, the editor list, tooltip, and runtime UI use the
## translated text. `name` remains the fallback when the key is
## missing or resolves to "".
@export_storage var name_key: String = ""

@export_storage var effect: String
@export_storage var value_count: int = 0

## Optional localization key for the attribute's effect text.
## When set, the tooltip looks up this key in GameLocalization and
## uses the translated text as the base for `{P}` / `{C}` / `{N}`
## placeholder substitution.
##
## `effect` remains the fallback (used when localization is unavailable
## or the key resolves to an empty string).
@export_storage var effect_key: String = ""

## How this attribute is applied to the total when a node is
## purchased. Only meaningful for non-currency attributes.
@export_storage var operation: Operation = Operation.ADD

## Optional custom icon shown in the tooltip's currency row.
## Falls back to the built-in gold-pouch emoji when empty.
@export_storage var icon: Texture2D = null

const SLOT_PURCHASE := 0
const SLOT_REFUND := 1

func get_effective_value_count() -> int:
	if not is_currency:
		return value_count
	if refund_differs:
		return 2
	return 1

func sync_value_count() -> void:
	if is_currency:
		value_count = 2 if refund_differs else 1

# ============================================================
# DISPLAY NAME
# ============================================================

## Returns the localized display name for this attribute.
##
## Priority:
##   1. GameLocalization.get_raw_text(name_key) — if name_key is set
##   2. `name`                                  — user-authored fallback
##   3. `id`                                    — last resort
func get_display_name() -> String:
	if not name_key.is_empty():
		var main_loop := Engine.get_main_loop()
		if main_loop is SceneTree:
			var root := (main_loop as SceneTree).root
			if root:
				var loc = root.get_node_or_null("GameLocalization")
				if loc and loc.has_method("get_raw_text"):
					var translated: String = String(loc.call("get_raw_text", name_key))
					if not translated.is_empty():
						return translated

	var fallback: String = name.strip_edges()
	if fallback.is_empty():
		fallback = id
	return fallback

# ============================================================
# OPERATION HELPERS
# ============================================================

## Human-readable label for an operation, used by the Inspector dropdown.
static func operation_label(op: Operation) -> String:
	match op:
		Operation.ADD:      return "Add (+)"
		Operation.SUBTRACT: return "Subtract (-)"
		Operation.SET:      return "Set (=)"
		Operation.MULTIPLY: return "Multiply (×)"
		Operation.MIN:      return "Min (≤)"
		Operation.MAX:      return "Max (≥)"
		_: return "?"

## All operation enum values in display order (used to fill the dropdown).
static func all_operations() -> Array:
	return [
		Operation.ADD,
		Operation.SUBTRACT,
		Operation.SET,
		Operation.MULTIPLY,
		Operation.MIN,
		Operation.MAX,
	]

## Returns true if `cumulative` produces meaningful results for the
## given operation. Only ADD and SUBTRACT support it.
static func is_cumulative_supported(op: Operation) -> bool:
	return op == Operation.ADD or op == Operation.SUBTRACT