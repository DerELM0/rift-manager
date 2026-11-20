class_name SeasonTeam
extends RefCounted
## Ein Team in einer Saison: Saison-Kopie des Teams plus Bilanz.
##
## team ist eine Kopie aus der Database (mit kopierten Spielern). Chemistry,
## Form und Werte ändern sich nur in dieser Kopie.

## Die Saison-Kopie des Teams. Wird direkt an MatchSim übergeben.
var team: Team = null
## Saisonstatistik je Spieler, in derselben Reihenfolge wie team.players.
var players: Array[SeasonPlayer] = []
## Chemistry zu Saisonbeginn (chemStart).
var chem_start: float = 0.0

## Bilanz in der regulären Saison (rec im Original). Playoffs zählen hier nicht,
## nur die Serie (streak) läuft dort weiter.
## Gewonnene und verlorene Serien:
var wins: int = 0
var losses: int = 0
## Gewonnene und verlorene Maps (mw, ml):
var maps_won: int = 0
var maps_lost: int = 0
## Ergebnisse in Reihenfolge: "S" = Sieg, "N" = Niederlage.
var last: Array[String] = []
## Aktuelle Serie: positiv = Siege in Folge, negativ = Niederlagen in Folge.
var streak: int = 0
## Gruppe: "" (keine), "Legend"/"Rise" (LCK Phase 2) oder "Ascend"/"Nirvana" (LPL).
var group: String = ""

var _by_player: Dictionary = {}


## Kopiert das Team und setzt bei allen Spielern die Startform.
func _init(original: Team, start_form: float) -> void:
	team = original.copy()
	chem_start = team.chemistry
	for player: Player in team.players:
		player.form = start_form
		var sp := SeasonPlayer.new(player)
		players.append(sp)
		_by_player[player] = sp


## Kürzel des Teams.
func short() -> String:
	return team.short


## Saisonstatistik zu einem Spieler dieses Teams (der Saison-Kopie).
func record_of(player: Player) -> SeasonPlayer:
	return _by_player.get(player, null)


## Rang der Gruppe für die Tabelle: obere Gruppe 0, untere 1 (groupRank im Original).
func group_rank() -> int:
	if group == "Rise" or group == "Nirvana":
		return 1
	return 0
