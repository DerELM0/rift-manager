extends PanelContainer
## Saison-Bildschirm: Liga und Format wählen, Woche für Woche spielen, Tabelle,
## Spieltage, Playoffs, Auszeichnungen, Kader und Spielerentwicklung.
## Vorlage ist der Saison-Bereich im Web-Simulator. Die Logik steckt in Season.
##
## Layout, Texte und Look werden im Editor in season_screen.tscn angepasst,
## Farben und Schriftgrößen zentral im Theme themes/rift_dark.tres.
## Per Code entstehen nur die wiederholten Zeilen (Komponenten in scenes/components/).
## Die Buttons und Dropdowns sind im Editor verbunden (Node-Dock > Signale).

const STANDINGS_ROW: PackedScene = preload("res://scenes/components/standings_row.tscn")
const WEEK_PANEL: PackedScene = preload("res://scenes/components/week_panel.tscn")
const SERIES_RESULT_ROW: PackedScene = preload("res://scenes/components/series_result_row.tscn")
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
@onready var _playoffs_button: Button = %PlayoffsButton
@onready var _table_rows: VBoxContainer = %TableRows
@onready var _weeks_list: VBoxContainer = %WeeksList
@onready var _champion_label: Label = %ChampionLabel
@onready var _playoff_note_label: Label = %PlayoffNoteLabel
@onready var _bracket: Control = %Bracket
@onready var _quarter_list: VBoxContainer = %QuarterList
@onready var _semi_list: VBoxContainer = %SemiList
@onready var _final_list: VBoxContainer = %FinalList
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


func _on_playoffs_button_pressed() -> void:
	_season.start_playoffs()
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
	elif _season.regular_done():
		status = " · Playoffs stehen an"
	_progress_label.text = "%s · Woche %d von %d%s%s" % [_league, _season.week, _season.total_weeks(), phase, status]
	_preset_chip.text = "%s · Bo%d" % [_preset["name"], _preset["bestOf"]]
	_next_week_button.disabled = _season.regular_done()
	_finish_regular_button.disabled = _season.regular_done()
	_playoffs_button.disabled = not _season.regular_done() or _season.done


func _refresh_table() -> void:
	_clear(_table_rows)
	var table: Array[SeasonTeam] = _season.standings()
	for i: int in table.size():
		var t: SeasonTeam = table[i]
		var group_header: bool = not t.group.is_empty() and (i == 0 or table[i - 1].group != t.group)
		var cut_below: bool = i == 5 and table.size() > 6
		var row: StandingsRow = STANDINGS_ROW.instantiate()
		_table_rows.add_child(row)
		row.setup(i + 1, t, t.short() == _selected_team, group_header, cut_below)
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


func _refresh_playoffs() -> void:
	_clear(_quarter_list)
	_clear(_semi_list)
	_clear(_final_list)
	var playoffs: Season.Playoffs = _season.playoffs
	_bracket.visible = playoffs != null
	_playoff_note_label.visible = playoffs == null
	_awards_panel.visible = playoffs != null
	if playoffs == null:
		_champion_label.text = ""
		var note: String = "Nach der regulären Saison spielen die Top 6 im Bo5: Platz 3 gegen 6 und 4 gegen 5 im Viertelfinale, Platz 1 und 2 steigen im Halbfinale ein."
		if _preset["id"] == "lck":
			note += " In der LCK sind das die Legend Group und der Erste der Rise Group."
		elif _preset["id"] == "lpl":
			note += " In der LPL kommen alle sechs aus der Ascend Group."
		_playoff_note_label.text = note
		return

	_champion_label.text = "Meister: %s" % _season.get_team(playoffs.champion).team.name
	var lists: Array[VBoxContainer] = [_quarter_list, _semi_list, _final_list]
	for r: int in mini(playoffs.rounds.size(), lists.size()):
		for series: Season.Series in playoffs.rounds[r].series:
			var row: SeriesResultRow = SERIES_RESULT_ROW.instantiate()
			lists[r].add_child(row)
			row.setup_result(series, _season)
	_refresh_awards()


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
	for sp: SeasonPlayer in t.players:
		var row: RosterRow = ROSTER_ROW.instantiate()
		_roster_rows.add_child(row)
		row.setup(sp, sp == _selected_player)
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
