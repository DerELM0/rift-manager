class_name TraitDef
extends RefCounted
## Ein Trait aus data/default/traits.csv: Name, Art, Effekte und Tooltip.

## Name wie in players.csv, Spalte traits (z. B. "Clutch Player").
var name: String = ""
## "positiv", "gemischt" oder "negativ".
var art: String = ""
## Effekt-Bausteine in der Reihenfolge der CSV. Leer = Trait ohne Wirkung.
var effects: Array[TraitEffect] = []
## Text für den Tooltip im Spiel.
var tooltip: String = ""
