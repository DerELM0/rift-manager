extends PanelContainer
## Match-Bildschirm: zwei Teams wählen, Format und Seed setzen, Serie simulieren.
## Vorlage ist die Match-Ansicht im Web-Simulator. Simuliert wird mit MatchSim.
##
## Layout, Texte und Look werden im Editor in match_screen.tscn angepasst,
## Farben und Schriftgrößen zentral im Theme themes/rift_dark.tres.
## Per Code entsteht nur die Liste der Spiele (je Spiel eine GamePanel-Karte).
## Die Buttons sind im Editor verbunden (Node-Dock > Signale).

const GAME_PANEL: PackedScene = preload("res://scenes/components/game_panel.tscn")
## Vorauswahl beim Start (wie im Web-Simulator).
const DEFAULT_TEAM_A: String = "DTS"
const DEFAULT_TEAM_B: String = "BYN"

@onready var _team_a_option: OptionButton = %TeamAOption
@onready var _team_b_option: OptionButton = %TeamBOption
@onready var _format_option: OptionButton = %FormatOption
@onready var _seed_spin: SpinBox = %SeedSpin
@onready var _team_a_name_label: Label = %TeamANameLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _team_b_name_label: Label = %TeamBNameLabel
@onready var _series_info_label: Label = %SeriesInfoLabel
@onready var _games_list: VBoxContainer = %GamesList


func _ready() -> void:
	if _format_option.selected < 0:
		_format_option.select(1)  # Bo3
	_fill_team_option(_team_a_option, DEFAULT_TEAM_A)
	_fill_team_option(_team_b_option, DEFAULT_TEAM_B)


## Füllt ein Team-Dropdown: je Liga eine Überschrift, darunter die Teams
## nach Overall sortiert, z. B. "DT Signal (85)".
func _fill_team_option(option: OptionButton, selected_short: String) -> void:
	option.clear()
	for league: String in Database.get_leagues():
		option.add_separator(league)
		var teams: Array[Team] = Database.get_teams_in_league(league)
		teams.sort_custom(func(x: Team, y: Team) -> bool: return x.overall() > y.overall())
		for team: Team in teams:
			option.add_item("%s (%d)" % [team.name, roundi(team.overall())])
			var index: int = option.item_count - 1
			option.set_item_metadata(index, team.short)
			if team.short == selected_short:
				option.select(index)


func _selected_team(option: OptionButton) -> Team:
	if option.selected < 0:
		return null
	return Database.get_team(str(option.get_item_metadata(option.selected)))


func _on_random_seed_button_pressed() -> void:
	_seed_spin.value = randi()


func _on_simulate_button_pressed() -> void:
	var team_a: Team = _selected_team(_team_a_option)
	var team_b: Team = _selected_team(_team_b_option)
	if team_a == null or team_b == null:
		_series_info_label.text = "Bitte zwei Teams wählen."
		return
	var best_of: int = _format_option.get_selected_id()
	var seed_value: int = int(_seed_spin.value)
	var series: SeriesResult = MatchSim.simulate_series(team_a, team_b, best_of, {}, seed_value)
	_show_series(team_a, team_b, best_of, seed_value, series)


func _show_series(team_a: Team, team_b: Team, best_of: int, seed_value: int, series: SeriesResult) -> void:
	_team_a_name_label.text = team_a.name
	_team_b_name_label.text = team_b.name
	_score_label.text = "%d : %d" % [series.wins_a, series.wins_b]
	if series.games.is_empty():
		_series_info_label.text = "Nicht simuliert: Einem Team fehlt ein Spieler (siehe Warnungen im Debugger)."
	else:
		var winner: Team = team_a if series.winner() == "A" else team_b
		_series_info_label.text = "Bo%d · Seed %d · Sieger %s" % [best_of, seed_value, winner.name]

	for child: Node in _games_list.get_children():
		child.queue_free()
	for i: int in series.games.size():
		var panel: GamePanel = GAME_PANEL.instantiate()
		_games_list.add_child(panel)
		panel.setup(series.games[i], i + 1, i == 0)  # erstes Spiel aufgeklappt
