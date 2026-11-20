@tool
class_name TableColumn
extends Resource
## Eine Spalte einer Tabelle. Wird in einer TableLayout-Ressource (.tres) gesammelt
## und von Kopfzeile und allen Zeilen gemeinsam benutzt.

## Schlüssel, über den der Code die Zelle füllt (z. B. "ovr"). Nicht umbenennen,
## ohne das zugehörige Zeilen-Skript anzupassen.
@export var key: StringName = &"":
	set(value):
		key = value
		emit_changed()
## Überschrift in der Kopfzeile.
@export var title: String = "":
	set(value):
		title = value
		emit_changed()
## Feste Breite der ganzen Spalte in Pixeln, inklusive Veränderung
## (bei expand: Mindestbreite).
@export var width: int = 60:
	set(value):
		width = value
		emit_changed()
## Ausrichtung des Textes. Zahlen: rechtsbündig.
@export var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		align = value
		emit_changed()
## Spalte nimmt den restlichen Platz (z. B. Team- oder Spielername).
@export var expand: bool = false:
	set(value):
		expand = value
		emit_changed()
## Breite der Unterspalte für Veränderungen wie "+1.5". 0 = keine Unterspalte.
## Bei zentrierten Spalten bekommt der Wert dieselbe Breite links von der Mitte,
## die Veränderung rechts davon; beide stoßen in der Zellmitte aneinander.
@export var delta_width: int = 0:
	set(value):
		delta_width = value
		emit_changed()
## Gedämpfte Schrift (Theme-Variante "MutedLabel"), z. B. für Rolle oder Gruppe.
@export var muted: bool = false:
	set(value):
		muted = value
		emit_changed()
