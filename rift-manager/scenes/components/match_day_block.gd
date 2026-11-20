class_name MatchDayBlock
extends VBoxContainer
## Ein Spieltag: Überschrift plus eine Zeile pro Paarung (series_result_row.tscn).

const SERIES_RESULT_ROW: PackedScene = preload("res://scenes/components/series_result_row.tscn")

## Klick auf ein Ergebnis; day_title ist die Überschrift, z. B. "Spieltag 5".
signal series_pressed(series: Season.Series, day_title: String)

@onready var _day_label: Label = %DayLabel
@onready var _results: VBoxContainer = %Results


## Gespielter Spieltag: series ist eine Liste von Season.Series.
func setup_results(title: String, series: Array, season: Season) -> void:
	_day_label.text = title
	for s: Season.Series in series:
		var row: SeriesResultRow = SERIES_RESULT_ROW.instantiate()
		_results.add_child(row)
		row.setup_result(s, season)
		row.pressed.connect(func(clicked: Season.Series) -> void: series_pressed.emit(clicked, title))


## Angesetzter Spieltag: pairs ist eine Liste von [kürzel_a, kürzel_b].
func setup_schedule(title: String, pairs: Array, season: Season) -> void:
	_day_label.text = title
	for pair: Array in pairs:
		var row: SeriesResultRow = SERIES_RESULT_ROW.instantiate()
		_results.add_child(row)
		row.setup_pairing(season.get_team(pair[0]).team.name, season.get_team(pair[1]).team.name)
