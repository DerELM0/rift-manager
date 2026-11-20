class_name BracketLines
extends Control
## Zeichnet die Verbindungslinien im Turnierbaum: von der rechten Kante einer Box
## waagerecht zur Mitte zwischen den Spalten, senkrecht, dann zur linken Kante der
## nächsten Box. Liegt hinter den Boxen (erstes Kind im Bracket-Container).
##
## Farben und Stärke im Theme unter dem Typ "BracketLines":
##   line_color    offene Verbindung
##   active_color  entschiedene Verbindung (Sieger ist weitergekommen)
##   line_width    Linienstärke (Constant)

## Liste von [von: Control, nach: Control, aktiv: bool].
var _connections: Array = []


func set_connections(connections: Array) -> void:
	_connections = connections
	queue_redraw()


func _draw() -> void:
	var width: float = get_theme_constant("line_width", "BracketLines")
	var origin: Vector2 = get_global_rect().position
	# Erst offene, dann aktive Linien, damit aktive obenauf liegen
	for active_pass: bool in [false, true]:
		var color: Color = get_theme_color("active_color" if active_pass else "line_color", "BracketLines")
		for connection: Array in _connections:
			var from: Control = connection[0]
			var to: Control = connection[1]
			if bool(connection[2]) != active_pass or not is_instance_valid(from) or not is_instance_valid(to):
				continue
			if not from.is_visible_in_tree() or not to.is_visible_in_tree():
				continue
			var a: Rect2 = from.get_global_rect()
			var b: Rect2 = to.get_global_rect()
			var start := Vector2(a.end.x, a.get_center().y) - origin
			var end := Vector2(b.position.x, b.get_center().y) - origin
			var mid_x: float = (start.x + end.x) / 2.0
			var points := PackedVector2Array([start, Vector2(mid_x, start.y), Vector2(mid_x, end.y), end])
			draw_polyline(points, color, width)
