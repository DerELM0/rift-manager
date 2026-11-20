class_name StatBarRow
extends HBoxContainer
## Ein Spielwert als Balken: Name, Balken (0–100) mit Strich beim Saisonstart,
## Wert und Veränderung. Balkenfarben im Theme unter ProgressBar.

@onready var _name_label: Label = %NameLabel
@onready var _bar: ProgressBar = %Bar
@onready var _start_marker: ColorRect = %StartMarker
@onready var _value_label: Label = %ValueLabel
@onready var _delta_label: Label = %DeltaLabel


## important = Wert zählt für die Rolle besonders (wird mit ★ markiert).
func setup(stat_name: String, value: float, start_value: float, important: bool) -> void:
	_name_label.text = stat_name + (" ★" if important else "")
	_bar.value = value
	var x: float = clampf(start_value / 100.0, 0.0, 1.0)
	_start_marker.anchor_left = x
	_start_marker.anchor_right = x
	_value_label.text = "%.1f" % value
	SeasonFormat.apply_delta(_delta_label, value - start_value, 1)
