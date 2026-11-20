class_name SeasonScreen
extends PanelContainer
## Saison-Bildschirm: Liga und Format wählen, Woche für Woche spielen, Tabelle,
## Spieltage, Playoffs, Auszeichnungen, Kader und Spielerentwicklung.
## Vorlage ist der Saison-Bereich im Web-Simulator. Die Logik steckt in Season.
##
## Layout, Texte und Look werden im Editor in season_screen.tscn angepasst,
## Farben und Schriftgrößen zentral im Theme themes/rift_dark.tres.
## Per Code entstehen nur die wiederholten Zeilen (Komponenten in scenes/components/).
## Die Buttons und Dropdowns sind im Editor verbunden (Node-Dock > Signale).

## Klick auf ein Ergebnis (Spieltag oder Playoffs). main.gd wechselt daraufhin
## zum Match-Bildschirm. label z. B. "LCK · Woche 3 · Spieltag 5";
## ovr_a/ovr_b = Team-OVR zum Zeitpunkt des Spiels.
signal series_opened(series: SeriesResult, team_a: Team, team_b: Team, label: String, ovr_a: float, ovr_b: float)

const STANDINGS_ROW: PackedScene = preload("res://scenes/components/standings_row.tscn")
const TABLE_GROUP_HEADER: PackedScene = preload("res://scenes/components/table_group_header.tscn")
const WEEK_PANEL: PackedScene = preload("res://scenes/components/week_panel.tscn")
const ROSTER_ROW: PackedScene = preload("res://scenes/components/roster_row.tscn")
const STAT_BAR_ROW: PackedScene = preload("res://scenes/components/stat_bar_row.tscn")
const TRAIT_CHIP: PackedScene = preload("res://scenes/components/trait_chip.tscn")

## Ligen mit weniger Teams können keine Saison spielen (Top 6 in die Playoffs).
const MIN_TEAMS: int = 6
## Liga, die beim Start ausgewählt ist.
const DEFAULT_LEAGUE: String = "LCK"
const STAT_NAMES: Array[String] = ["Mechanics", "Laning", "Macro", "Teamwork", "Mental"]

@onready var _league_option: OptionButton = %LeagueOption
@onready var _format_option: OptionButton = %FormatOption
@onready var _seed_spin: SpinBox = %SeedSpin
@onready var _format_note_label: Label = %FormatNoteLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _preset_chip: Label = %PresetChip
@onready var _next_week_button: Button = %NextWeekButton
@onready var _finish_regular_button: Button = %FinishRegularButton
@onready var _table_rows: VBoxContainer = %TableRows
@onready var _weeks_list: VBoxContainer = %WeeksList
@onready var _playoff_note_label: Label = %PlayoffNoteLabel
@onready var _quarter_button: Button = %QuarterButton
@onready var _semi_button: Button = %SemiButton
@onready var _final_button: Button = %FinalButton
@onready var _all_playoffs_button: Button = %AllPlayoffsButton
@onready var _bracket_scroll: Control = %BracketScroll
@onready var _bracket_lines: BracketLines = %BracketLines
@onready var _quarter_match_1: BracketMatch = %QuarterMatch1
@onready var _quarter_match_2: BracketMatch = %QuarterMatch2
@onready var _semi_match_1: BracketMatch = %SemiMatch1
@onready var _semi_match_2: BracketMatch = %SemiMatch2
@onready var _final_match: BracketMatch = %FinalMatch
@onready var _champion_box: Control = %ChampionBox
@onready var _champion_name_label: Label = %ChampionNameLabel
@onready var _champion_info_label: Label = %ChampionInfoLabel
@onready var _awards_panel: Control = %AwardsPanel
@onready var _mvp_award_label: Label = %MvpAwardLabel
@onready var _all_pro_label: Label = %AllProLabel
@onready var _rookie_label: Label = %RookieLabel
@onready var _improved_label: Label = %ImprovedLabel
@onready var _roster_title_label: Label = %RosterTitleLabel
@onready var _roster_rows: VBoxContainer = %RosterRows
@onready var _coach_label: Label = %CoachLabel
@onready var _player_panel: Control = %PlayerPanel
@onready var _player_title_label: Label = %PlayerTitleLabel
@onready var _player_info_label: Label = %PlayerInfoLabel
@onready var _stat_bars: VBoxContainer = %StatBars
@onready var _languages_label: Label = %LanguagesLabel
@onready var _form_info_label: Label = %FormInfoLabel
@onready var _form_chart: SparkChart = %FormChart
@onready var _ovr_chart: SparkChart = %OvrChart
@onready var _grades_title_label: Label = %GradesTitleLabel
@onready var _grades_chart: SparkChart = %GradesChart
@onready var _games_value_label: Label = %GamesValueLabel
@onready var _kda_value_label: Label = %KdaValueLabel
@onready var _gold_value_label: Label = %GoldValueLabel
@onready var _mvp_value_label: Label = %MvpValueLabel
@onready var _traits_flow: HFlowContainer = %TraitsFlow

var _season: Season = null
var _league: String = ""
## Das gewählte Format (Eintrag aus Season.PRESETS).
var _preset: Dictionary = {}
var _selected_team: String = ""
var _selected_player: SeasonPlayer = null


func _ready() -> void:
	for box: BracketMatch in [_quarter_match_1, _quarter_match_2, _semi_match_1, _semi_match_2, _final_match]:
		box.pressed.connect(_open_playoff_series)
	_fill_leagues()
	_fill_formats()
	_new_season()


# --- Auswahl oben -----------------------------------------------------------

func _fill_leagues() -> void:
	_league_option.clear()
	for league: String in Database.get_leagues():
		if Database.get_teams_in_league(league).size() >= MIN_TEAMS:
			_league_option.add_item(league)
			if league == DEFAULT_LEAGUE:
				_league_option.select(_league_option.item_count - 1)


func _selected_league() -> String:
	if _league_option.selected < 0:
		return ""
	return _league_option.get_item_text(_league_option.selected)


## Formate der Liga aus Season.PRESETS; unbekannte Ligen bekommen das LEC-Standardformat.
func _fill_formats() -> void:
	_format_option.clear()
	var presets: Array = Season.PRESETS.get(_selected_league(), [Season.PRESETS["LEC"][0]])
	for preset: Dictionary in presets:
		_format_option.add_item(preset["name"])
		_format_option.set_item_metadata(_format_option.item_count - 1, preset)
	_format_option.select(0)
	_update_format_note()


func _selected_preset() -> Dictionary:
	if _format_option.selected < 0:
		return {}
	return _format_option.get_item_metadata(_format_option.selected)


func _update_format_note() -> void:
	_format_note_label.text = str(_selected_preset().get("note", ""))


func _on_league_option_item_selected(_index: int) -> void:
	_fill_formats()


func _on_format_option_item_selected(_index: int) -> void:
	_update_format_note()


func _on_random_seed_button_pressed() -> void:
	_seed_spin.value = randi()


func _on_new_season_button_pressed() -> void:
	_new_season()


func _new_season() -> void:
	_league = _selected_league()
	_preset = _selected_preset()
	if _league.is_empty() or _preset.is_empty():
		return
	_season = Season.create(Database.get_teams_in_league(_league), {
		"seed": int(_seed_spin.value), "preset": _preset["id"], "bestOf": _preset["bestOf"]})
	_selected_team = _season.standings()[0].short()
	_selected_player = null
	_refresh()


# --- Saison spielen ---------------------------------------------------------

func _on_next_week_button_pressed() -> void:
	_season.play_week()
	_refresh()


func _on_finish_regular_button_pressed() -> void:
	while _season.play_week():
		pass
	_refresh()


func _on_quarter_button_pressed() -> void:
	_play_playoff_round()


func _on_semi_button_pressed() -> void:
	_play_playoff_round()


func _on_final_button_pressed() -> void:
	_play_playoff_round()


func _play_playoff_round() -> void:
	_season.play_playoff_round()
	_refresh()


func _on_all_playoffs_button_pressed() -> void:
	_season.play_remaining_playoffs()
	_refresh()


func _on_team_selected(team_short: String) -> void:
	_selected_team = team_short
	_selected_player = null
	_refresh.call_deferred()  # erst nach dem Klick neu aufbauen


func _on_player_selected(season_player: SeasonPlayer) -> void:
	_selected_player = season_player
	_refresh.call_deferred()


func _on_close_player_button_pressed() -> void:
	_selected_player = null
	_refresh()


# --- Anzeige ----------------------------------------------------------------

func _refresh() -> void:
	if _season == null:
		return
	_refresh_progress()
	_refresh_table()
	_refresh_weeks()
	_refresh_playoffs()
	_refresh_roster()
	_refresh_player()


func _refresh_progress() -> void:
	var phase: String = ""
	if _preset["id"] == "lck":
		phase = " · Runden 3–4" if _season.phase == 2 else " · Runden 1–2"
	var status: String = ""
	if _season.done:
		status = " · abgeschlossen"
	elif _season.playoffs != null:
		status = " · Playoffs laufen"
	elif _season.regular_done():
		status = " · Playoffs stehen an"
	_progress_label.text = "%s · Woche %d von %d%s%s" % [_league, _season.week, _season.total_weeks(), phase, status]
	_preset_chip.text = "%s · Bo%d" % [_preset["name"], _preset["bestOf"]]
	_next_week_button.disabled = _season.regular_done()
	_finish_regular_button.disabled = _season.regular_done()


func _refresh_table() -> void:
	_clear(_table_rows)
	var table: Array[SeasonTeam] = _season.standings()
	for i: int in table.size():
		var t: SeasonTeam = table[i]
		if not t.group.is_empty() and (i == 0 or table[i - 1].group != t.group):
			var group_header: Label = TABLE_GROUP_HEADER.instantiate()
			group_header.text = "%s Group" % t.group
			_table_rows.add_child(group_header)
		var cut_below: bool = i == 5 and table.size() > 6  # Linie unter dem letzten Playoff-Platz
		var row: StandingsRow = STANDINGS_ROW.instantiate()
		_table_rows.add_child(row)
		row.setup(i, t, t.short() == _selected_team, cut_below)
		row.selected.connect(_on_team_selected)


## Spieltage: oben der Spielplan der nächsten Woche (zugeklappt), darunter alle
## gespielten Wochen, die neueste zuerst und aufgeklappt.
func _refresh_weeks() -> void:
	_clear(_weeks_list)
	if not _season.regular_done() and _season.week < _season.weeks.size():
		var upcoming: WeekPanel = WEEK_PANEL.instantiate()
		_weeks_list.add_child(upcoming)
		upcoming.setup_schedule(_season.week + 1, _season.weeks[_season.week], _season, _season.results.is_empty())
	for i: int in range(_season.results.size() - 1, -1, -1):
		var panel: WeekPanel = WEEK_PANEL.instantiate()
		_weeks_list.add_child(panel)
		panel.setup_week(_season.results[i], _season, i == _season.results.size() - 1)
		panel.series_pressed.connect(_on_week_series_pressed)


func _on_week_series_pressed(series: Season.Series, week_number: int, label: String) -> void:
	_open_series(series, label, week_number)


## Meldet eine gespielte Serie zum Ansehen im Match-Bildschirm.
## week_number: Woche der regulären Saison, -1 für Playoffs.
func _open_series(series: Season.Series, label: String, week_number: int) -> void:
	var result := SeriesResult.new()
	result.games = series.games
	result.wins_a = series.wins_a
	result.wins_b = series.wins_b
	var team_a: SeasonTeam = _season.get_team(series.a)
	var team_b: SeasonTeam = _season.get_team(series.b)
	series_opened.emit(result, team_a.team, team_b.team, "%s · %s" % [_league, label],
			_ovr_at(team_a, week_number), _ovr_at(team_b, week_number))


## Team-OVR zum Zeitpunkt eines Spiels. Die Werte ändern sich nur am Wochenende
## (Training); history[n - 1] sind also genau die Werte, mit denen in Woche n
## gespielt wurde. Playoffs (week_number -1): Werte nach der letzten Woche.
func _ovr_at(t: SeasonTeam, week_number: int) -> float:
	var total: float = 0.0
	for sp: SeasonPlayer in t.players:
		var index: int = week_number - 1 if week_number > 0 else sp.history.size() - 1
		total += float(sp.history[clampi(index, 0, sp.history.size() - 1)]["ovr"])
	return total / 5.0


## Turnierbaum: sichtbar, sobald die reguläre Saison vorbei ist. Vor dem Viertelfinale
## stehen die Setzplätze aus der Tabelle drin, offene Plätze als Platzhalter.
func _refresh_playoffs() -> void:
	var next_round: int = _season.next_playoff_round()
	_quarter_button.disabled = next_round != 0
	_semi_button.disabled = next_round != 1
	_final_button.disabled = next_round != 2
	_all_playoffs_button.disabled = next_round < 0
	_awards_panel.visible = _season.done

	var show_tree: bool = _season.regular_done()
	_bracket_scroll.visible = show_tree
	_playoff_note_label.text = _playoff_note(show_tree)
	if not show_tree:
		return

	var seeds: Array[String] = _season.playoff_seeds()
	var playoffs: Season.Playoffs = _season.playoffs
	var rounds_played: int = 0 if playoffs == null else playoffs.rounds.size()
	var qf_winners: Array[String] = _season.semifinal_opponents()

	# Viertelfinale: Platz 3 gegen 6, Platz 4 gegen 5
	_fill_match(_quarter_match_1, seeds, seeds[2], seeds[5], "", "", _played(0, 0))
	_fill_match(_quarter_match_2, seeds, seeds[3], seeds[4], "", "", _played(0, 1))
	# Halbfinale: Platz 1 gegen den schwächer gesetzten VF-Sieger, Platz 2 gegen den anderen
	_fill_match(_semi_match_1, seeds, seeds[0], qf_winners[1] if qf_winners.size() == 2 else "",
			"", "Schwächerer VF-Sieger", _played(1, 0))
	_fill_match(_semi_match_2, seeds, seeds[1], qf_winners[0] if qf_winners.size() == 2 else "",
			"", "Stärkerer VF-Sieger", _played(1, 1))
	# Finale: Sieger HF 1 gegen Sieger HF 2
	var sf_1: Season.Series = _played(1, 0)
	var sf_2: Season.Series = _played(1, 1)
	_fill_match(_final_match, seeds, sf_1.winner if sf_1 != null else "", sf_2.winner if sf_2 != null else "",
			"Sieger HF 1", "Sieger HF 2", _played(2, 0))

	if _season.done:
		var champion: Team = _season.get_team(playoffs.champion).team
		_champion_name_label.text = champion.name
		_champion_info_label.text = "#%d der Tabelle" % (seeds.find(playoffs.champion) + 1)
		_champion_box.tooltip_text = "%s (%s)" % [champion.name, champion.short]
	else:
		_champion_name_label.text = "?"
		_champion_info_label.text = "Noch offen"
		_champion_box.tooltip_text = ""

	_update_bracket_lines(rounds_played, qf_winners)
	if _season.done:
		_refresh_awards()


func _playoff_note(show_tree: bool) -> String:
	if show_tree:
		return "Top 6 im Bo5. Platz 1 und 2 haben ein Freilos und steigen im Halbfinale ein: Platz 1 gegen den schwächer gesetzten Viertelfinal-Sieger. Klick auf eine gespielte Paarung öffnet die Serie."
	var note: String = "Nach der regulären Saison spielen die Top 6 im Bo5: Platz 3 gegen 6 und 4 gegen 5 im Viertelfinale, Platz 1 und 2 steigen im Halbfinale ein."
	if _preset["id"] == "lck":
		note += " In der LCK sind das die Legend Group und der Erste der Rise Group."
	elif _preset["id"] == "lpl":
		note += " In der LPL kommen alle sechs aus der Ascend Group."
	return note


## Gespielte Serie einer Playoff-Runde oder null.
func _played(round_index: int, series_index: int) -> Season.Series:
	var playoffs: Season.Playoffs = _season.playoffs
	if playoffs == null or round_index >= playoffs.rounds.size():
		return null
	var series: Array[Season.Series] = playoffs.rounds[round_index].series
	return series[series_index] if series_index < series.size() else null


## Füllt eine Paarung im Baum. Leeres Kürzel = Platzhalter-Text.
func _fill_match(box: BracketMatch, seeds: Array[String], short_a: String, short_b: String,
		placeholder_a: String, placeholder_b: String, series: Season.Series) -> void:
	box.set_slot(false, seeds.find(short_a) + 1, _team_or_null(short_a), placeholder_a)
	box.set_slot(true, seeds.find(short_b) + 1, _team_or_null(short_b), placeholder_b)
	box.set_result(series)


func _team_or_null(short: String) -> Team:
	if short.is_empty():
		return null
	var t: SeasonTeam = _season.get_team(short)
	return t.team if t != null else null


## Verbindungslinien: Viertelfinale -> Halbfinale. Solange das Viertelfinale offen
## ist, führt jede VF-Box zu beiden HF-Boxen (wer gegen wen spielt, hängt vom
## Setzplatz der Sieger ab). Danach nur die tatsächlichen Wege, hervorgehoben.
func _update_bracket_lines(rounds_played: int, qf_winners: Array[String]) -> void:
	var connections: Array = []
	var quarters: Array[BracketMatch] = [_quarter_match_1, _quarter_match_2]
	var semis: Array[BracketMatch] = [_semi_match_1, _semi_match_2]
	if rounds_played >= 1 and qf_winners.size() == 2:
		for i: int in 2:
			var winner: String = _played(0, i).winner
			# Schwächer gesetzter Sieger (qf_winners[1]) spielt in HF 1
			var semi: BracketMatch = _semi_match_1 if winner == qf_winners[1] else _semi_match_2
			connections.append([quarters[i], semi, true])
	else:
		for quarter: BracketMatch in quarters:
			for semi: BracketMatch in semis:
				connections.append([quarter, semi, false])
	for i: int in 2:
		connections.append([semis[i], _final_match, rounds_played >= 2])
	connections.append([_final_match, _champion_box, rounds_played >= 3])
	_bracket_lines.set_connections(connections)


## Nach jedem Layout-Durchlauf der Spalten neu zeichnen (Positionen ändern sich).
func _on_bracket_columns_sort_children() -> void:
	_bracket_lines.queue_redraw()


func _open_playoff_series(series: Season.Series) -> void:
	var playoffs: Season.Playoffs = _season.playoffs
	for r: Season.PlayoffRound in playoffs.rounds:
		if r.series.has(series):
			_open_series(series, "Playoffs · %s" % r.name, -1)
			return


func _refresh_awards() -> void:
	var awards: Season.Awards = _season.awards()
	if awards.mvp != null:
		_mvp_award_label.text = "%s · %d MVP-Titel" % [_award_text(awards.mvp), awards.mvp.mvps]
	else:
		_mvp_award_label.text = "–"
	var lines: PackedStringArray = []
	for i: int in awards.all_pro.size():
		lines.append("%s: %s" % [RiftSim.ROLES[i], _award_text(awards.all_pro[i])])
	_all_pro_label.text = "\n".join(lines)
	_rookie_label.text = _award_text(awards.rookie)
	if awards.improved != null:
		_improved_label.text = "%s (%s, OVR %s)" % [awards.improved.player.display_name(),
			_season.team_of(awards.improved).short(), SeasonFormat.delta(awards.improved_gain, 1)]
	else:
		_improved_label.text = "–"


func _award_text(sp: SeasonPlayer) -> String:
	if sp == null:
		return "–"
	return "%s (%s, Ø %.1f)" % [sp.player.display_name(), _season.team_of(sp).short(), sp.average_grade()]


func _refresh_roster() -> void:
	_clear(_roster_rows)
	var t: SeasonTeam = _season.get_team(_selected_team)
	if t == null:
		return
	_roster_title_label.text = "%s: Kader" % t.team.name
	for i: int in t.players.size():
		var sp: SeasonPlayer = t.players[i]
		var row: RosterRow = ROSTER_ROW.instantiate()
		_roster_rows.add_child(row)
		row.setup(i, sp, sp == _selected_player)
		row.selected.connect(_on_player_selected)
	var coach: Coach = t.team.coach
	if coach != null:
		_coach_label.text = "Coach: %s (DEV %d, MAN %d, MOT %d)" % [coach.name, coach.development, coach.management, coach.motivation]
	else:
		_coach_label.text = "Coach: keiner (Werte 30)"


## Spielerdetails: Werte mit Veränderung, Sprachen, Form und deren Wirkung,
## Verläufe (Form, OVR, Noten), Saisonstatistik und Traits.
func _refresh_player() -> void:
	var t: SeasonTeam = _season.get_team(_selected_team)
	var sp: SeasonPlayer = _selected_player
	_player_panel.visible = sp != null and t != null and t.players.has(sp)
	if not _player_panel.visible:
		return
	var p: Player = sp.player

	_player_title_label.text = p.display_name()
	var info: PackedStringArray = []
	if not p.real_name.is_empty():
		info.append(p.real_name)
	info.append(p.role)
	info.append("%d J." % p.age)
	info.append(t.team.name)
	_player_info_label.text = " · ".join(info)

	_clear(_stat_bars)
	var stats: Array[float] = p.stats()
	var weights: Array = RiftSim.W[p.role]
	for i: int in stats.size():
		_add_stat_bar(STAT_NAMES[i], stats[i], sp.start_stats[i], float(weights[i]) >= 0.25)
	_add_stat_bar("OVR", p.overall(), sp.start_ovr, false)
	_languages_label.text = "Sprachen: %s · Englisch %d" % [", ".join(p.languages), roundi(p.english)]

	var consts: Dictionary = RiftSim.merge_consts(_season.opt.get("consts", {}))
	var form_effect: float = clampf((p.form - consts["formCenter"]) / consts["formDiv"], -4.0, 4.0)
	_form_info_label.text = "Form %d · wirkt mit %s auf alle Werte im Spiel" % [roundi(p.form), SeasonFormat.delta(form_effect, 1)]

	var form_line: Array[float] = []
	var ovr_line: Array[float] = []
	for entry: Dictionary in sp.history:
		form_line.append(entry["form"])
		ovr_line.append(entry["ovr"])
	_form_chart.setup(form_line, 25.0, 99.0, consts["formCenter"])
	_ovr_chart.setup(ovr_line, ovr_line.min() - 1.0, ovr_line.max() + 1.0, sp.start_ovr)
	var grades: Array[float] = []
	for g: int in sp.grades:
		grades.append(float(g))
	_grades_title_label.text = "Bewertung je Spiel · Ø %s" % (("%.1f" % sp.average_grade()) if sp.games > 0 else "–")
	_grades_chart.setup(grades, 30.0, 100.0, 70.0)

	_games_value_label.text = str(sp.games)
	var kda: float = float(sp.kills + sp.assists) / maxi(1, sp.deaths)
	_kda_value_label.text = "%d/%d/%d · KDA %.1f" % [sp.kills, sp.deaths, sp.assists, kda]
	_gold_value_label.text = str(roundi(float(sp.gold) / sp.games)) if sp.games > 0 else "–"
	_mvp_value_label.text = str(sp.mvps)

	_clear(_traits_flow)
	for trait_name: String in p.traits:
		var chip: TraitChip = TRAIT_CHIP.instantiate()
		_traits_flow.add_child(chip)
		chip.setup(trait_name)


func _add_stat_bar(stat_name: String, value: float, start_value: float, important: bool) -> void:
	var row: StatBarRow = STAT_BAR_ROW.instantiate()
	_stat_bars.add_child(row)
	row.setup(stat_name, value, start_value, important)


## Entfernt alle per Code erzeugten Zeilen aus einem Container.
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
