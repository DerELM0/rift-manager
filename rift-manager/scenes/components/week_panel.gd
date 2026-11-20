class_name WeekPanel
extends VBoxContainer
## Eine Woche als aufklappbarer Bereich: Kopfzeile zum Auf- und Zuklappen,
## darin die Spieltage (match_day_block.tscn).

const MATCH_DAY_BLOCK: PackedScene = preload("res://scenes/components/match_day_block.tscn")

## Klick auf ein Ergebnis dieser Woche; label z. B. "Woche 3 · Spieltag 5".
signal series_pressed(series: Season.Series, week_number: int, label: String)

@onready var _header_button: Button = %HeaderButton
@onready var _details: Control = %Details
@onready var _days: VBoxContainer = %Days

var _title: String = ""


## Gespielte Woche. Spieltage werden fortlaufend nummeriert (2 pro Woche).
func setup_week(week: Season.Week, season: Season, expanded: bool) -> void:
	_title = "Woche %d" % week.number
	if week.phase == 2:
		_title += " · Legend und Rise Group"
	for i: int in week.days.size():
		var block: MatchDayBlock = MATCH_DAY_BLOCK.instantiate()
		_days.add_child(block)
		block.setup_results("Spieltag %d" % ((week.number - 1) * 2 + i + 1), week.days[i], season)
		block.series_pressed.connect(func(series: Season.Series, day_title: String) -> void:
			series_pressed.emit(series, week.number, "Woche %d · %s" % [week.number, day_title]))
	_set_expanded(expanded)


## Noch nicht gespielte Woche als Spielplan. rounds ist season.weeks[index].
func setup_schedule(week_number: int, rounds: Array, season: Season, expanded: bool) -> void:
	_title = "Woche %d: Spielplan" % week_number
	for i: int in rounds.size():
		var block: MatchDayBlock = MATCH_DAY_BLOCK.instantiate()
		_days.add_child(block)
		block.setup_schedule("Spieltag %d" % ((week_number - 1) * 2 + i + 1), rounds[i], season)
	_set_expanded(expanded)


func _set_expanded(expanded: bool) -> void:
	_header_button.set_pressed_no_signal(expanded)
	_apply_expanded(expanded)


func _on_header_button_toggled(toggled_on: bool) -> void:
	_apply_expanded(toggled_on)


func _apply_expanded(expanded: bool) -> void:
	_details.visible = expanded
	_header_button.text = "%s  %s" % ["[-]" if expanded else "[+]", _title]
