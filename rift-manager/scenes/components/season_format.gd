class_name SeasonFormat
extends RefCounted
## Kleine Formatierhilfen für die Saison-Anzeige.


## Veränderung als Text mit Vorzeichen, z. B. "+1.2", "-0.4" oder "0.0".
static func delta(value: float, decimals: int) -> String:
	var factor: float = pow(10.0, decimals)
	var rounded: float = roundf(value * factor) / factor
	if rounded == 0.0:
		return "%.*f" % [decimals, 0.0]
	return ("+" if rounded > 0.0 else "-") + "%.*f" % [decimals, absf(rounded)]


## Schreibt eine Veränderung in ein Label: grün bei Plus ("DeltaUpLabel"),
## rot bei Minus ("DeltaDownLabel"), gedämpft bei 0 ("MutedLabel").
static func apply_delta(label: Label, value: float, decimals: int) -> void:
	var text: String = delta(value, decimals)
	label.text = text
	if text.begins_with("+"):
		label.theme_type_variation = &"DeltaUpLabel"
	elif text.begins_with("-"):
		label.theme_type_variation = &"DeltaDownLabel"
	else:
		label.theme_type_variation = &"MutedLabel"
