class_name MatchScreen
extends PanelContainer
## Match-Bildschirm: zwei Teams wählen, Format und Seed setzen, Serie simulieren.
## Vorlage ist die Match-Ansicht im Web-Simulator. Simuliert wird mit MatchSim.
##
## Layout, Texte und Look werden im Editor in match_screen.tscn angepasst,
## Farben und Schriftgrößen zentral im Theme themes/rift_dark.tres.
## Per Code entsteht nur die Liste der Spiele (je Spiel eine GamePanel-Karte).
## Die Buttons sind im Editor verbunden (Node-Dock > Signale).
##
## Saisonspiele: show_series() zeigt eine bereits gespielte Serie, ohne neu zu
## simulieren. Dann ist statt der Eingabeleiste (ControlsPanel) die SeasonBar
## sichtbar, mit Spielkontext und "Zurück zur Saison".

## "Zurück zur Saison" gedrückt; main.gd wechselt zum Saison-Bildschirm.
signal back_to_season_requested

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
@onready var _controls_panel: Control = %ControlsPanel
@onready var _season_bar: Control = %SeasonBar
@onready var _season_context_label: Label = %SeasonContextLabel
@onready var _season_ovr_label: Label = %SeasonOvrLabel


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
	_show_result(team_a, team_b, series, "Bo%d · Seed %d" % [best_of, seed_value])


## Zeigt eine bereits gespielte Serie an, ohne neu zu simulieren (z. B. aus der Saison).
## season_label: Spielkontext, z. B. "LCK · Woche 3 · Spieltag 5". Ist er gesetzt,
## wird statt der Eingabeleiste die SeasonBar mit "Zurück zur Saison" gezeigt.
## ovr_a/ovr_b: Team-OVR zum Zeitpunkt des Spiels (negativ = nicht anzeigen).
func show_series(series: SeriesResult, team_a: Team, team_b: Team, season_label: String = "",
		ovr_a: float = -1.0, ovr_b: float = -1.0) -> void:
	var from_season: bool = not season_label.is_empty()
	_set_season_mode(from_season)
	if from_season:
		_season_context_label.text = season_label
		if ovr_a >= 0.0 and ovr_b >= 0.0:
			_season_ovr_label.text = "Team-OVR zum Spielzeitpunkt: %s %.1f · %s %.1f" % [
				team_a.short, ovr_a, team_b.short, ovr_b]
		else:
			_season_ovr_label.text = ""
	_show_result(team_a, team_b, series, "Saisonspiel" if from_season else "")


func _set_season_mode(enabled: bool) -> void:
	_season_bar.visible = enabled
	_controls_panel.visible = not enabled


func _on_back_to_season_button_pressed() -> void:
	back_to_season_requested.emit()


## Blendet die Eingabeleiste wieder ein; das angezeigte Ergebnis bleibt stehen,
## bis neu simuliert wird.
func _on_own_match_button_pressed() -> void:
	_set_season_mode(false)


## Ergebnisbereich und Spielkarten füllen. info steht vor dem Sieger, z. B. "Bo3 · Seed 1".
func _show_result(team_a: Team, team_b: Team, series: SeriesResult, info: String) -> void:
	_team_a_name_label.text = team_a.name
	_team_b_name_label.text = team_b.name
	_score_label.text = "%d : %d" % [series.wins_a, series.wins_b]
	if series.games.is_empty():
		_series_info_label.text = "Nicht simuliert: Einem Team fehlt ein Spieler (siehe Warnungen im Debugger)."
	else:
		var winner: Team = team_a if series.winner() == "A" else team_b
		var parts: PackedStringArray = []
		if not info.is_empty():
			parts.append(info)
		parts.append("Sieger %s" % winner.name)
		_series_info_label.text = " · ".join(parts)

	for child: Node in _games_list.get_children():
		child.queue_free()
	for i: int in series.games.size():
		var panel: GamePanel = GAME_PANEL.instantiate()
		_games_list.add_child(panel)
		panel.setup(series.games[i], i + 1, i == 0)  # erstes Spiel aufgeklappt
