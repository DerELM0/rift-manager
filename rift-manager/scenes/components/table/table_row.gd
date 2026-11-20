@tool
class_name TableRow
extends PanelContainer
## Eine Tabellenzeile oder Kopfzeile. Baut ihre Zellen aus einer TableLayout-Ressource,
## damit Kopfzeile und Zeilen immer dieselben Breiten haben.
##
## Jede Zelle hat eine feste Breite; zu lange Texte werden mit "…" gekürzt.
## Spalten mit delta_width bekommen eine feste Unterspalte für Veränderungen.
## Zwischen den Spalten steht ein Trennstrich (Theme-Variante "TableDivider").
##
## Aussehen im Theme:
##   TableHeaderRow     Kopfzeile
##   TableRow           gerade Zeilen
##   TableRowOdd        ungerade Zeilen (Zebra)
##   TableRowSelected   gewählte Zeile
##   TableRow > Colors "cut_color", Constants "cut_width": Linie unter einer Zeile
##                      (z. B. letzter Playoff-Platz), gezeichnet ohne Höhe zu ändern
##   TableRow > Constants "cell_separation": Abstand zwischen Zelle und Trennstrich
##
## Wird im Editor live angezeigt (@tool), damit man Kopfzeilen beim Anpassen sieht.

## Wird bei Linksklick auf eine (Nicht-Kopf-)Zeile ausgelöst.
signal clicked

## Die Spalten dieser Tabelle (eine .tres-Datei, z. B. standings_columns.tres).
@export var layout: TableLayout = null:
	set(value):
		if layout != null and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = value
		if layout != null:
			layout.changed.connect(_on_layout_changed)
		_on_layout_changed()
## Kopfzeile: zeigt die Spaltentitel statt Werte.
@export var header: bool = false:
	set(value):
		header = value
		_on_layout_changed()

## Abstand zwischen Wert und Veränderung in einer Zelle.
const DELTA_GAP: int = 4

var _value_labels: Dictionary = {}
var _columns: Dictionary = {}
var _delta_labels: Dictionary = {}
var _cut_below: bool = false
var _index: int = 0
var _selected: bool = false
var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild()


## Text einer Zelle setzen. Bei Namensspalten (expand) zeigt der Tooltip den
## vollen Text, falls er mit "…" gekürzt wurde.
func set_text(key: StringName, text: String) -> void:
	var label: Label = _value_labels.get(key)
	if label != null:
		label.text = text
		var column: TableColumn = _columns.get(key)
		if column != null and column.expand:
			set_tooltip(key, text)


## Tooltip für eine Zelle (beim Drüberfahren). Klicks gehen weiter an die Zeile.
func set_tooltip(key: StringName, text: String) -> void:
	var label: Label = _value_labels.get(key)
	if label != null:
		label.tooltip_text = text
		label.mouse_filter = Control.MOUSE_FILTER_PASS


## Veränderung in die Unterspalte schreiben (grün/rot über das Theme).
func set_delta(key: StringName, value: float, decimals: int) -> void:
	var label: Label = _delta_labels.get(key)
	if label != null:
		SeasonFormat.apply_delta(label, value, decimals)


## Theme-Variante einer Zelle ändern, z. B. "GoldLabel" für den MVP.
func set_cell_variation(key: StringName, variation: StringName) -> void:
	var label: Label = _value_labels.get(key)
	if label != null:
		label.theme_type_variation = variation


## Zebra (index), Auswahl und Linie unter der Zeile setzen.
func set_row_state(index: int, selected: bool = false, cut_below: bool = false) -> void:
	_index = index
	_selected = selected
	_cut_below = cut_below
	_apply_style()
	queue_redraw()


func _on_layout_changed() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_value_labels.clear()
	_delta_labels.clear()
	_columns.clear()
	_apply_style()
	if layout == null:
		return

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", get_theme_constant("cell_separation", "TableRow"))
	add_child(row)
	for i: int in layout.columns.size():
		var column: TableColumn = layout.columns[i]
		if column == null:
			continue
		if i > 0:
			var divider := VSeparator.new()
			divider.theme_type_variation = &"TableDivider"
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(divider)
		row.add_child(_make_cell(column))


## Eine Zelle hat immer genau column.width Pixel (bei expand: mindestens).
## Kopfzeile: ein Label über die ganze Breite.
## Mit Veränderung (delta_width > 0):
##   zentriert: Wert und Veränderung bekommen je delta_width Pixel und stoßen in der
##     Zellmitte aneinander (Wert rechtsbündig links davon, Veränderung linksbündig
##     rechts davon). So wirkt "85.6 +0.3" zentriert und verrutscht nie.
##   links/rechts: Wert füllt den Rest, Veränderung steht in einer festen Unterspalte rechts.
func _make_cell(column: TableColumn) -> Control:
	var has_delta: bool = column.delta_width > 0 and not header
	var cell := HBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", DELTA_GAP)
	cell.custom_minimum_size = Vector2(_cell_width(column), 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if column.expand else Control.SIZE_FILL
	var centered_pair: bool = has_delta and column.align == HORIZONTAL_ALIGNMENT_CENTER
	if centered_pair:
		cell.alignment = BoxContainer.ALIGNMENT_CENTER

	var value_width: int = _cell_width(column)
	var value_align: HorizontalAlignment = column.align
	if centered_pair:
		value_width = column.delta_width
		value_align = HORIZONTAL_ALIGNMENT_RIGHT
	elif has_delta:
		value_width = maxi(0, _cell_width(column) - DELTA_GAP - column.delta_width)
	var value := _make_label(value_width, value_align)
	if column.expand or (has_delta and not centered_pair):
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if header:
		value.text = column.title
		value.theme_type_variation = &"MutedLabel"
	elif column.muted:
		value.theme_type_variation = &"MutedLabel"
	cell.add_child(value)
	_value_labels[column.key] = value
	_columns[column.key] = column

	if has_delta:
		var delta := _make_label(column.delta_width, HORIZONTAL_ALIGNMENT_LEFT)
		delta.theme_type_variation = &"DeltaUpLabel"
		cell.add_child(delta)
		_delta_labels[column.key] = delta
	return cell


## Gesamtbreite einer Zelle. Zentrierte Spalten mit Veränderung brauchen
## mindestens Platz für Wert und Veränderung nebeneinander.
func _cell_width(column: TableColumn) -> int:
	if column.delta_width > 0 and column.align == HORIZONTAL_ALIGNMENT_CENTER:
		return maxi(column.width, column.delta_width * 2 + DELTA_GAP)
	return column.width


func _make_label(width: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(width, 0)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_style() -> void:
	if header:
		theme_type_variation = &"TableHeaderRow"
	elif _selected:
		theme_type_variation = &"TableRowSelected"
	elif _index % 2 == 1:
		theme_type_variation = &"TableRowOdd"
	else:
		theme_type_variation = &"TableRow"


func _draw() -> void:
	if not _cut_below:
		return
	var width: float = get_theme_constant("cut_width", "TableRow")
	var y: float = size.y - width / 2.0
	draw_line(Vector2(0, y), Vector2(size.x, y), get_theme_color("cut_color", "TableRow"), width)


func _gui_input(event: InputEvent) -> void:
	if header or Engine.is_editor_hint():
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
