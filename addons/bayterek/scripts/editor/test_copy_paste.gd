@tool
extends RefCounted
## Copy/paste round-trip test.
## Validates that node dict serialization is lossless for key fields.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

static func run() -> bool:
	print("=== Bayterek Copy/Paste Test ===")
	var ok: bool = true

	ok = _test_line_data_roundtrip() and ok
	ok = _test_layer_roundtrip() and ok

	if ok:
		print("=== ALL COPY/PASTE TESTS PASSED ===")
	else:
		push_error("=== SOME COPY/PASTE TESTS FAILED ===")

	return ok

static func _test_line_data_roundtrip() -> bool:
	print("--- Line data ---")

	var ld := BayterekLineData.new()
	ld.line_type = BayterekLineData.LineType.BEZIER
	ld.line_style = BayterekLineData.LineStyle.DASHED
	ld.curve_height = 60.0
	ld.segments = 24
	ld.reversed = true
	ld.dash_length = 10.0
	ld.dash_gap = 4.0
	ld.start_arrow = BayterekLineData.ArrowStyle.CIRCLE
	ld.end_arrow = BayterekLineData.ArrowStyle.ARROW
	ld.arrow_size = 16.0

	var d: Dictionary = {
		"line_type": int(ld.line_type),
		"line_style": int(ld.line_style),
		"curve_height": ld.curve_height,
		"segments": ld.segments,
		"reversed": ld.reversed,
		"dash_length": ld.dash_length,
		"dash_gap": ld.dash_gap,
		"start_arrow": int(ld.start_arrow),
		"end_arrow": int(ld.end_arrow),
		"arrow_size": ld.arrow_size,
	}

	var ld2 := BayterekLineData.new()
	ld2.line_type = int(d.get("line_type", 0)) as BayterekLineData.LineType
	ld2.line_style = int(d.get("line_style", 0)) as BayterekLineData.LineStyle
	ld2.curve_height = float(d.get("curve_height", 48.0))
	ld2.segments = int(d.get("segments", 16))
	ld2.reversed = bool(d.get("reversed", false))
	ld2.dash_length = float(d.get("dash_length", 12.0))
	ld2.dash_gap = float(d.get("dash_gap", 6.0))
	ld2.start_arrow = int(d.get("start_arrow", 0)) as BayterekLineData.ArrowStyle
	ld2.end_arrow = int(d.get("end_arrow", 0)) as BayterekLineData.ArrowStyle
	ld2.arrow_size = float(d.get("arrow_size", 12.0))

	assert(ld2.line_type == ld.line_type)
	assert(ld2.line_style == ld.line_style)
	assert(ld2.curve_height == ld.curve_height)
	assert(ld2.segments == ld.segments)
	assert(ld2.reversed == ld.reversed)
	assert(ld2.dash_length == ld.dash_length)
	assert(ld2.start_arrow == ld.start_arrow)
	assert(ld2.end_arrow == ld.end_arrow)
	assert(ld2.arrow_size == ld.arrow_size)

	print("  line data OK")
	return true

static func _test_layer_roundtrip() -> bool:
	print("--- Layer round-trip ---")

	var layer := BayterekShapeLayer.new()
	layer.layer_id = "layer-abc"
	layer.layer_name = "Background"
	layer.shape_type = BayterekShapeLayer.ShapeType.HEXAGON
	layer.corner_radius = 8.0
	layer.fill_configs["hover"] = {"enabled": true, "color": Color.RED}
	layer.border_enabled = true
	layer.border_width = 3.0
	layer.transform.position = Vector2(10, 20)
	layer.transform.rotation = 45.0

	var dup = layer.duplicate_layer()
	assert(dup is BayterekShapeLayer)
	assert(dup.layer_id == layer.layer_id)
	assert(dup.layer_name == "Background")
	assert(dup.shape_type == BayterekShapeLayer.ShapeType.HEXAGON)
	assert(dup.corner_radius == 8.0)
	assert(dup.fill_configs["hover"]["enabled"] == true)
	assert(dup.fill_configs["hover"]["color"] == Color.RED)
	assert(dup.border_width == 3.0)
	assert(dup.transform.rotation == 45.0)

	dup.fill_configs["hover"]["color"] = Color.BLUE
	assert(layer.fill_configs["hover"]["color"] == Color.RED)

	print("  layer OK")
	return true