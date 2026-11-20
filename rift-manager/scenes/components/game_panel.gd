class_name GamePanel
extends PanelContainer
## Ein Spiel einer Serie als aufklappbare Karte.
## Kopfzeile (HeaderButton) klappt die Details auf und zu. Die Details zeigen
## Kennzahlen als "Chips", den Spielverlauf und die Spielerwerte beider Teams.
## Layout und Texte der festen Teile im Editor in game_panel.tscn anpassen;
## per Code entstehen nur die Zeilen (player_row.tscn, log_entry_row.tscn).

const PLAYER_ROW: PackedScene = preload("res://scenes/components/player_row.tscn")
const LOG_ENTRY_ROW: PackedScene = preload("res://scenes/components/log_entry_row.tscn")

@onready var _header_button: Button = %HeaderButton
@onready var _details: Control = %Details
@onready var _winner_chip: Label = %WinnerChip
@onready var _kills_chip: Label = %KillsChip
@onready var _gold14_chip: Label = %Gold14Chip
@onready var _mvp_chip: Label = %MvpChip
@onready var _draft_chip: Label = %DraftChip
@onready var _plans_chip: Label = %PlansChip
@onready var _drakes_chip: Label = %DrakesChip
@onready var _team_gold_chip: Label = %TeamGoldChip
@onready var _log_list: VBoxContainer = %LogList
@onready var _team_a_title: Label = %TeamATitle
@onready var _team_b_title: Label = %TeamBTitle
@onready var _ratings_list_a: VBoxContainer = %RatingsListA
@onready var _ratings_list_b: VBoxContainer = %RatingsListB

var _number: int = 0
var _game: MatchResult = null


## Füllt die Karte mit einem Spiel. number beginnt bei 1. Erst aufrufen,
## nachdem die Karte mit add_child in den Szenenbaum gehängt wurde.
func setup(game: MatchResult, number: int, expanded: bool) -> void:
	_game = game
	_number = number
	var a: Team = game.team_a
	var b: Team = game.team_b

	_winner_chip.text = "Sieg %s nach %d Minuten" % [game.winner_team().short, game.duration]
	_kills_chip.text = "Kills %s %d : %d %s" % [a.short, game.kills["A"], game.kills["B"], b.short]
	_gold14_chip.text = "Gold @14: %d Vorsprung %s" % [absi(game.gold14), (a if game.gold14 >= 0 else b).short]
	_mvp_chip.text = "MVP %s" % game.mvp
	_draft_chip.text = "Comps: %s %s (%d) · %s %s (%d)" % [
		a.short, game.draft["A"]["arch"], game.draft["A"]["score"],
		b.short, game.draft["B"]["arch"], game.draft["B"]["score"]]
	_plans_chip.text = "Jungle: %s %s · %s %s" % [a.short, game.plans["A"], b.short, game.plans["B"]]
	_drakes_chip.text = "Drachen %d : %d" % [game.drakes["A"], game.drakes["B"]]
	_team_gold_chip.text = "Gold %.1fk : %.1fk" % [game.team_gold["A"] / 1000.0, game.team_gold["B"] / 1000.0]

	_team_a_title.text = a.name
	_team_b_title.text = b.name
	_fill_ratings(_ratings_list_a, game.ratings["A"])
	_fill_ratings(_ratings_list_b, game.ratings["B"])

	for entry: MatchResult.LogEntry in game.game_log:
		var row: LogEntryRow = LOG_ENTRY_ROW.instantiate()
		_log_list.add_child(row)
		row.setup(entry)

	_header_button.set_pressed_no_signal(expanded)
	_apply_expanded(expanded)


func _fill_ratings(list: VBoxContainer, ratings: Array) -> void:
	for rating: MatchResult.PlayerRating in ratings:
		var row: PlayerRow = PLAYER_ROW.instantiate()
		list.add_child(row)
		row.setup(rating, rating.name == _game.mvp)


func _on_header_button_toggled(toggled_on: bool) -> void:
	_apply_expanded(toggled_on)


func _apply_expanded(expanded: bool) -> void:
	_details.visible = expanded
	if _game == null:
		return
	_header_button.text = "%s  Spiel %d · Sieger %s · %d Min. · Kills %d : %d" % [
		"[-]" if expanded else "[+]", _number, _game.winner_team().short, _game.duration,
		_game.kills["A"], _game.kills["B"]]
