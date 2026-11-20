class_name BracketMatch
extends PanelContainer
## Eine Paarung im Turnierbaum: zwei Zeilen mit Setzplatz, Teamname und Serienstand.
## Sieger: Theme-Variante "WinnerLabel", Verlierer und Platzhalter: "MutedLabel".
## Box-Aussehen im Theme unter "BracketBox". Gespielte Paarungen sind klickbar
## und melden sich über das Signal "pressed".

signal pressed(series: Season.Series)

@onready var _seed_a_label: Label = %SeedALabel
@onready var _name_a_label: Label = %NameALabel
@onready var _score_a_label: Label = %ScoreALabel
@onready var _seed_b_label: Label = %SeedBLabel
@onready var _name_b_label: Label = %NameBLabel
@onready var _score_b_label: Label = %ScoreBLabel

var _series: Season.Series = null


## Eine Seite der Paarung. seed_number 0 = kein Setzplatz (Platzhalter).
## team == null: Platzhalter mit dem Text placeholder, z. B. "Sieger HF 1".
func set_slot(slot_b: bool, seed_number: int, team: Team, placeholder: String) -> void:
	var seed_label: Label = _seed_b_label if slot_b else _seed_a_label
	var name_label: Label = _name_b_label if slot_b else _name_a_label
	seed_label.text = ("#%d" % seed_number) if seed_number > 0 else ""
	if team != null:
		name_label.text = team.name
		name_label.tooltip_text = "%s (%s)" % [team.name, team.short]
		name_label.theme_type_variation = &""
	else:
		name_label.text = placeholder
		name_label.tooltip_text = ""
		name_label.theme_type_variation = &"MutedLabel"


## Ergebnis eintragen (oder null für noch nicht gespielt). Macht die Box klickbar.
func set_result(series: Season.Series) -> void:
	_series = series
	if series == null:
		_score_a_label.text = ""
		_score_b_label.text = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = ""
		return
	_score_a_label.text = str(series.wins_a)
	_score_b_label.text = str(series.wins_b)
	var a_won: bool = series.winner == series.a
	_name_a_label.theme_type_variation = &"WinnerLabel" if a_won else &"MutedLabel"
	_score_a_label.theme_type_variation = &"WinnerLabel" if a_won else &"MutedLabel"
	_name_b_label.theme_type_variation = &"MutedLabel" if a_won else &"WinnerLabel"
	_score_b_label.theme_type_variation = &"MutedLabel" if a_won else &"WinnerLabel"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Im Match ansehen"


func is_played() -> bool:
	return _series != null


func _gui_input(event: InputEvent) -> void:
	if _series == null:
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(_series)
