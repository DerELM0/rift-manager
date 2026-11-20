class_name TraitEffect
extends RefCounted
## Ein Effekt-Baustein eines Traits, eine Zeile wie "stat_bonus|stat=mec|wert=4"
## aus der Spalte effekte in traits.csv. Welche Bausteine es gibt und was sie
## tun, steht in TraitRules.

## Name des Traits, zu dem der Effekt gehört (z. B. "Carry").
var trait_name: String = ""
## Baustein-Typ, z. B. "stat_bonus".
var type: String = ""
## Text-Parameter (z. B. stat, phase, kontext, rolle, wer).
var texts: Dictionary = {}
## Zahl-Parameter (z. B. wert, faktor), schon als Kommazahl.
var numbers: Dictionary = {}


func num(key: String, fallback: float = 0.0) -> float:
	return numbers.get(key, fallback)


func text(key: String, fallback: String = "") -> String:
	return texts.get(key, fallback)


func has(key: String) -> bool:
	return texts.has(key) or numbers.has(key)


## Rollen aus dem Parameter rolle, z. B. "MID/SUP" -> ["MID", "SUP"]. Leer = alle Rollen.
func roles() -> PackedStringArray:
	return text("rolle").split("/", false)
