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
##   `effect_key` is an optional localization key. When set, the tooltip
##   looks up this key in GameLocalization and uses the translated text
##   as the base for `{P}` / `{C}` / `{N}` substitution. `effect` is
##   the fallback used when the key is missing or resolves to "".
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

@export_storage var id: String
@export_storage var name: String
@export_storage var effect: String
@export_storage var value_count: int = 0

## Optional localization key. When set, the tooltip will look up this
## key in GameLocalization and use the translated text as the base for
## `{P}` / `{C}` / `{N}` placeholder substitution.
##
## `effect` remains the fallback (used when localization is unavailable
## or the key resolves to an empty string).
@export_storage var effect_key: String = ""

## How this attribute is applied to the total when a node is
## purchased. Only meaningful for non-currency attributes.
@export_storage var operation: Operation = Operation.ADD

## Optional custom icon shown in the tooltip's currency row.
## Falls back to the built-in gold-pouch emoji when empty.
## (Custom Texture2D rendering in RichTextLabel is not yet supported —
## a future version will embed this via a generated atlas.)
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