class_name SeriesResultRow
extends HBoxContainer
## Eine Paarung: "Team A  2:1  Team B". Der Sieger nutzt die Theme-Variante
## "WinnerLabel", der Verlierer "MutedLabel". Ohne Ergebnis steht "–" in der Mitte.

@onready var _team_a_label: Label = %TeamALabel
@onready var _score_label: Label = %ScoreLabel
@onready var _team_b_label: Label = %TeamBLabel


## Gespielte Serie.
func setup_result(series: Season.Series, season: Season) -> void:
	_team_a_label.text = season.get_team(series.a).team.name
	_team_b_label.text = season.get_team(series.b).team.name
	_score_label.text = "%d:%d" % [series.wins_a, series.wins_b]
	var a_won: bool = series.winner == series.a
	_team_a_label.theme_type_variation = &"WinnerLabel" if a_won else &"MutedLabel"
	_team_b_label.theme_type_variation = &"MutedLabel" if a_won else &"WinnerLabel"


## Angesetzte, noch nicht gespielte Paarung.
func setup_pairing(team_a_name: String, team_b_name: String) -> void:
	_team_a_label.text = team_a_name
	_team_b_label.text = team_b_name
	_score_label.text = "–"
