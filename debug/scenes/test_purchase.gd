extends Control

const GROUP_NAME := "Group 1"
const TREE_NAME := "Tree 1"

const DEFAULT_CURRENCY := 100
const GIVE_AMOUNT := 50

var _wallet: Dictionary = {}
var _granted: Dictionary = {}
var _tree_view: BayterekTreeView = null
var _tree_data: BayterekTree = null
var _wallet_label: Label = null
var _state_label: Label = null

## Holds the toolbar HBox so we can add currency buttons after the tree loads.
var _toolbar: HBoxContainer = null

func _ready() -> void:
	print("========================================")
	print("[READY] test_purchase.gd starting")
	print("  viewport size: ", get_viewport_rect().size)
	print("  self size: ", size)
	print("========================================")

	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 1) ALWAYS build the UI first, regardless of whether the tree loads.
	_build_ui()

	# 2) Then try to load the tree.
	var loader = get_node_or_null("/root/BayterekLoader")
	print("[READY] BayterekLoader: ", loader)
	if not loader:
		push_error("BayterekLoader autoload missing — enable the Bayterek plugin.")
		return

	var path: String = "%s/%s" % [GROUP_NAME, TREE_NAME]
	print("[READY] loading tree: ", path)
	_tree_data = loader.call("load_tree", path)
	print("[READY] tree loaded: ", _tree_data)
	if not _tree_data:
		push_error("Tree not found: %s" % path)
		return

	# 3) Initialize the wallet with DEFAULT_CURRENCY for every currency attribute.
	_initialize_wallet()

	# 4) Build the tree view.
	_build_tree_view()

	# 5) Add a "+X <name>" button for every currency attribute.
	_build_currency_buttons()

	# 6) Refresh HUD (deferred so labels have real size).
	call_deferred("_refresh_hud")

	print("[READY] done.")

# ============================================================
# WALLET INIT
# ============================================================

func _initialize_wallet() -> void:
	_wallet.clear()
	if not _tree_data:
		return
	for attr_id in _tree_data.attributes.keys():
		var attr: BayterekAttribute = _tree_data.attributes[attr_id]
		if not attr or not attr.is_currency:
			continue
		_wallet[attr_id] = DEFAULT_CURRENCY
	print("[WALLET] initialized: ", _wallet)

# ============================================================
# UI
# ============================================================

func _build_ui() -> void:
	print("[UI] building...")

	# --- Toolbar (top) ---
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.position = Vector2(10, 8)
	_toolbar.z_index = 100
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)

	var center_btn := Button.new()
	center_btn.text = "Center"
	center_btn.pressed.connect(func():
		if _tree_view: _tree_view.center_camera_on_content()
	)
	_toolbar.add_child(center_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_on_reset_pressed)
	_toolbar.add_child(reset_btn)

	var dump_btn := Button.new()
	dump_btn.text = "Dump Wallet"
	dump_btn.pressed.connect(func():
		print("[DUMP] _wallet=", _wallet)
		print("[DUMP] _granted=", _granted)
		if _tree_data:
			print("[DUMP] attributes=", _tree_data.attributes.keys())
			print("[DUMP] allocated=", _tree_data.tree_state.allocated_nodes if _tree_data.tree_state else [])
	)
	_toolbar.add_child(dump_btn)

	print("[UI] toolbar added (base buttons). children=", _toolbar.get_child_count())

	# --- Wallet HUD (top-left, overlay on top of canvas) ---
	var wallet_panel := Panel.new()
	wallet_panel.name = "WalletHUD"
	wallet_panel.position = Vector2(10, 50)
	wallet_panel.size = Vector2(260, 200)
	wallet_panel.z_index = 90
	wallet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wallet_style := StyleBoxFlat.new()
	wallet_style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	wallet_style.border_color = Color(0.4, 0.7, 1.0, 1.0)
	wallet_style.set_border_width_all(2)
	wallet_style.set_corner_radius_all(6)
	wallet_panel.add_theme_stylebox_override("panel", wallet_style)
	add_child(wallet_panel)

	_wallet_label = Label.new()
	_wallet_label.position = Vector2(12, 10)
	_wallet_label.size = Vector2(236, 180)
	_wallet_label.text = "WALLET\n(loading...)"
	_wallet_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_wallet_label.add_theme_font_size_override("font_size", 13)
	_wallet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_panel.add_child(_wallet_label)

	print("[UI] wallet panel added")

	# --- State HUD (bottom-left, overlay) ---
	var state_panel := Panel.new()
	state_panel.name = "StateHUD"
	state_panel.z_index = 90
	state_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	state_panel.anchor_left = 0.0
	state_panel.anchor_top = 1.0
	state_panel.anchor_right = 0.0
	state_panel.anchor_bottom = 1.0
	state_panel.offset_left = 10
	state_panel.offset_top = -160
	state_panel.offset_right = 370
	state_panel.offset_bottom = -10

	var state_style := StyleBoxFlat.new()
	state_style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	state_style.border_color = Color(0.4, 0.9, 0.5, 1.0)
	state_style.set_border_width_all(2)
	state_style.set_corner_radius_all(6)
	state_panel.add_theme_stylebox_override("panel", state_style)
	add_child(state_panel)

	_state_label = Label.new()
	_state_label.position = Vector2(12, 10)
	_state_label.size = Vector2(336, 140)
	_state_label.text = "STATE\n(loading...)"
	_state_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_state_label.add_theme_font_size_override("font_size", 13)
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_panel.add_child(_state_label)

	print("[UI] build complete.")

# ============================================================
# CURRENCY BUTTONS (dynamic, added after tree loads)
# ============================================================

func _build_currency_buttons() -> void:
	if not _toolbar or not _tree_data:
		return

	var added: int = 0
	for attr_id in _tree_data.attributes.keys():
		var attr: BayterekAttribute = _tree_data.attributes[attr_id]
		if not attr or not attr.is_currency:
			continue

		var btn := Button.new()
		btn.name = "AddCurrency_%s" % attr_id
		btn.text = "+%d %s" % [GIVE_AMOUNT, attr.name]
		btn.tooltip_text = "Add %d %s to the wallet." % [GIVE_AMOUNT, attr.name]
		var captured_id: String = attr_id
		btn.pressed.connect(func(): _add_currency(captured_id, GIVE_AMOUNT))
		_toolbar.add_child(btn)
		added += 1

	print("[UI] currency buttons added: ", added, " (toolbar children now=", _toolbar.get_child_count(), ")")

# ============================================================
# TREE VIEW
# ============================================================

func _build_tree_view() -> void:
	print("[TREE] building tree view...")

	var tree_container := Control.new()
	tree_container.name = "TreeContainer"
	tree_container.z_index = 0
	tree_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(tree_container)

	# In Godot 4, input priority follows scene-tree child order.
	# Move the fullscreen tree container to index 0 so the toolbar
	# (added earlier) stays on top for mouse input.
	move_child(tree_container, 0)

	print("[TREE] tree_container size=", tree_container.size)

	_tree_view = BayterekBuilder.new(_tree_data) \
		.set_parent(tree_container) \
		.node_allocated_callback(_on_node_allocated) \
		.node_deallocated_callback(_on_node_deallocated) \
		.wallet_can_afford_callback(_wallet_can_afford) \
		.wallet_spend_callback(_wallet_spend) \
		.wallet_refund_callback(_wallet_refund) \
		.build()

	print("[TREE] tree_view=", _tree_view)
	if not _tree_view:
		push_error("Failed to build tree view.")
		return

	_tree_view.set_tooltip_near_node_right()

	var svc = _tree_view.allocation_service
	if svc:
		svc.node_allocated.connect(func(_n): _recompute())
		svc.node_deallocated.connect(func(_n): _recompute())
		svc.node_preallocated.connect(func(_n): _recompute())
		svc.node_unpreallocated.connect(func(_n): _recompute())

	print("[TREE] tree view ready.")

# ============================================================
# WALLET CALLBACKS
# ============================================================

func _wallet_can_afford(attr_id: String, amount: int) -> bool:
	var current: int = int(_wallet.get(attr_id, 0))
	var ok: bool = current >= amount
	print("[WALLET] can_afford %s: %d >= %d → %s" % [attr_id, current, amount, str(ok)])
	return ok

func _wallet_spend(attr_id: String, amount: int) -> void:
	var current: int = int(_wallet.get(attr_id, 0))
	_wallet[attr_id] = current - amount
	print("[WALLET] spend %s: %d - %d = %d" % [attr_id, current, amount, _wallet[attr_id]])
	_refresh_hud()

func _wallet_refund(attr_id: String, amount: int) -> void:
	var current: int = int(_wallet.get(attr_id, 0))
	_wallet[attr_id] = current + amount
	print("[WALLET] refund %s: %d + %d = %d" % [attr_id, current, amount, _wallet[attr_id]])
	_refresh_hud()

# ============================================================
# ALLOC CALLBACKS
# ============================================================

func _on_node_allocated(node: BayterekNode) -> void:
	print("[ALLOC] allocated: ", node.name)
	_recompute()

func _on_node_deallocated(node: BayterekNode) -> void:
	print("[ALLOC] deallocated: ", node.name)
	_recompute()

# ============================================================
# ATTRIBUTE ACCUMULATION
# ============================================================

func _recompute() -> void:
	if not _tree_data:
		return

	var allocated_ids: Array = _tree_data.tree_state.allocated_nodes if _tree_data.tree_state else []
	print("[RECOMPUTE] allocated_ids=", allocated_ids)

	var contributions: Dictionary = {}

	for node_data in _tree_data.nodes:
		if not node_data or not allocated_ids.has(node_data.id):
			continue
		var level: int = 1
		if _tree_data.tree_state and _tree_data.tree_state.allocation_level.has(node_data.id):
			level = int(_tree_data.tree_state.allocation_level[node_data.id])
		for attr_id in node_data.attributes.keys():
			var attr: BayterekAttribute = _tree_data.attributes.get(attr_id, null)
			if not attr or attr.is_currency:
				continue
			var raw = node_data.attributes[attr_id]
			var values: Array = []
			if raw is Array and raw.size() > 0 and raw[0] is Array:
				var lvl: int = clampi(level - 1, 0, raw.size() - 1)
				values = raw[lvl]
			elif raw is Array:
				values = raw
			if not contributions.has(attr_id):
				contributions[attr_id] = []
			var v: float = 0.0
			if values.size() > 0:
				v = float(values[0])
			contributions[attr_id].append(v)

	var granted: Dictionary = {}
	for attr_id in contributions.keys():
		var attr: BayterekAttribute = _tree_data.attributes.get(attr_id, null)
		if not attr:
			continue
		var values: Array = contributions[attr_id]
		var total: float = 0.0
		match attr.operation:
			BayterekAttribute.Operation.ADD:
				total = 0.0
				for v in values: total += v
			BayterekAttribute.Operation.SUBTRACT:
				total = 0.0
				for v in values: total -= v
			BayterekAttribute.Operation.SET:
				if not values.is_empty(): total = float(values[values.size() - 1])
			BayterekAttribute.Operation.MULTIPLY:
				total = 1.0
				for v in values: total *= v
			BayterekAttribute.Operation.MIN:
				total = INF
				for v in values: total = minf(total, v)
				if is_inf(total): total = 0.0
			BayterekAttribute.Operation.MAX:
				total = -INF
				for v in values: total = maxf(total, v)
				if is_inf(total): total = 0.0
			_:
				total = 0.0
				for v in values: total += v
		granted[attr_id] = int(round(total))

	_granted = granted
	print("[RECOMPUTE] granted=", granted)
	_refresh_hud()

# ============================================================
# HUD
# ============================================================

func _refresh_hud() -> void:
	if not _wallet_label or not _state_label:
		print("[HUD] labels missing! wallet=", _wallet_label, " state=", _state_label)
		return

	if not _tree_data:
		_wallet_label.text = "WALLET\n(no tree)"
		_state_label.text = "STATE\n(no tree)"
		return

	# Wallet lines
	var lines: Array[String] = ["WALLET"]
	var any_currency: bool = false
	for attr_id in _tree_data.attributes.keys():
		var attr: BayterekAttribute = _tree_data.attributes[attr_id]
		if not attr or not attr.is_currency:
			continue
		lines.append("  %s: %d" % [attr.name, int(_wallet.get(attr_id, 0))])
		any_currency = true
	if not any_currency:
		lines.append("  (no currencies)")

	lines.append("")
	lines.append("STATS")
	var any: bool = false
	for attr_id in _tree_data.attributes.keys():
		var attr: BayterekAttribute = _tree_data.attributes[attr_id]
		if not attr or attr.is_currency:
			continue
		var v: int = int(_granted.get(attr_id, 0))
		lines.append("  %s: %d" % [attr.name, v])
		any = true
	if not any:
		lines.append("  (none)")

	_wallet_label.text = "\n".join(lines)

	# State
	var allocated_ids: Array = _tree_data.tree_state.allocated_nodes if _tree_data.tree_state else []
	var names: Array[String] = []
	for node_data in _tree_data.nodes:
		if node_data and allocated_ids.has(node_data.id):
			names.append(node_data.name)

	_state_label.text = "STATE\nAllocated: %d\n%s" % [
		names.size(),
		", ".join(names) if not names.is_empty() else "(none)"
	]

# ============================================================
# BUTTONS
# ============================================================

func _on_reset_pressed() -> void:
	if _tree_data:
		if _tree_data.tree_state:
			_tree_data.tree_state.allocated_nodes.clear()
			_tree_data.tree_state.allocation_level.clear()
		if _tree_view and _tree_view.allocation_service:
			_tree_view.allocation_service.reload_from_state()
		_initialize_wallet()
		_granted.clear()
		_recompute()
		print("[RESET] done")

func _add_currency(attr_id: String, amount: int) -> void:
	_wallet[attr_id] = int(_wallet.get(attr_id, 0)) + amount
	print("[WALLET] added %d to %s → %d" % [amount, attr_id, _wallet[attr_id]])
	_refresh_hud()