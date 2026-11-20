@tool
class_name TableLayout
extends Resource
## Spalten einer Tabelle an genau einer Stelle: Kopfzeile und Zeilen lesen
## dieselbe TableLayout-Ressource. Breiten, Titel und Ausrichtung im Inspector
## ändern (Doppelklick auf die .tres-Datei), alles bleibt automatisch bündig.

@export var columns: Array[TableColumn] = []:
	set(value):
		for column: TableColumn in columns:
			if column != null and column.changed.is_connected(emit_changed):
				column.changed.disconnect(emit_changed)
		columns = value
		for column: TableColumn in columns:
			if column != null and not column.changed.is_connected(emit_changed):
				column.changed.connect(emit_changed)
		emit_changed()
