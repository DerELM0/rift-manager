class_name SparkChart
extends Control
## Kleine Verlaufslinie (Form, OVR, Noten). Gestrichelte Linie = Referenzwert.
## Farben im Theme unter dem Typ "SparkChart": line_color und ref_color.
## Höhe im Editor über "Custom Minimum Size".

@onready var _empty_label: Label = %EmptyLabel

var _values: Array[float] = []
var _low: float = 0.0
var _high: float = 100.0
var _ref: float = 50.0


## values: Verlauf; low/high: Wertebereich der Höhe; ref: gestrichelte Linie.
func setup(values: Array[float], low: float, high: float, ref: float) -> void:
	_values = values
	_low = low
	_high = high if high > low else low + 1.0
	_ref = ref
	_empty_label.visible = values.size() < 2
	queue_redraw()


func _draw() -> void:
	if _values.size() < 2:
		return
	var ref_y: float = _y(_ref)
	draw_dashed_line(Vector2(0, ref_y), Vector2(size.x, ref_y), get_theme_color("ref_color", "SparkChart"), 1.0, 4.0)
	var points := PackedVector2Array()
	for i: int in _values.size():
		var x: float = 4.0 + i * (size.x - 8.0) / (_values.size() - 1)
		points.append(Vector2(x, _y(_values[i])))
	draw_polyline(points, get_theme_color("line_color", "SparkChart"), 2.0, true)


func _y(value: float) -> float:
	var v: float = clampf(value, _low, _high)
	return size.y - 4.0 - (v - _low) / (_high - _low) * (size.y - 8.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
