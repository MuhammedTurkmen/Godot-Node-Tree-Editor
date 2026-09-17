@tool
class_name BayterekConnection
extends BayterekLine2D
## İki node arasındaki bağlantı çizgisi.
##
## Extends BayterekLine2D — a custom Control-based line drawer that supports
## texture tiling and dash patterns (Godot's Line2D does not).

var from_id: int = -1
var to_id: int = -1

## Bu bağlantıya ait görsel veri (straight/bezier/arc/step)
var line_data: BayterekLineData = null