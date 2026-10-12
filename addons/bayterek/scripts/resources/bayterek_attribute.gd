@tool
class_name BayterekAttribute
extends Resource
## Attribute definition.
##
## Currency attributes (is_currency = true) represent a purchase cost.
## By default, refund = purchase. If the user checks `refund_differs`,
## the attribute stores two separate values per level: [purchase, refund].
##
## Non-currency attributes behave as before (value_count = 0..4).
##
## ID RULE:
##   `id` is derived from `name` via snake_case. The editor updates it
##   as you type. If the derived id collides with another attribute,
##   the editor keeps the previous id and shows a red warning — the
##   user can rename to resolve the collision, or save (which will
##   prompt to auto-suffix the colliding ids).

@export_storage var is_currency: bool = false
@export_storage var refund_differs: bool = false

@export_storage var id: String
@export_storage var name: String
@export_storage var effect: String
@export_storage var value_count: int = 0

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