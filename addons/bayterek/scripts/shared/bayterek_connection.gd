@tool
class_name BayterekConnection
extends Line2D
## İki node arasındaki bağlantı çizgisi.

var from_id: int = -1
var to_id: int = -1

## Bu bağlantıya ait görsel veri (straight/bezier/arc)
var line_data: BayterekLineData = null