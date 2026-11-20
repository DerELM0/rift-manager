class_name SeasonPlayer
extends RefCounted
## Ein Spieler in einer Saison: seine Saison-Kopie plus Saisonstatistik.
##
## player ist eine Kopie aus der Database. Training, Form und Englisch
## verändern nur diese Kopie, nie das Original.

## Die Saison-Kopie des Spielers (aktuelle Werte, Form, Englisch).
var player: Player = null

## Werte zu Saisonbeginn (start im Original).
var start_stats: Array[float] = []
var start_ovr: float = 0.0
var start_form: float = 0.0

## Gespielte Spiele (Maps, nicht Serien).
var games: int = 0
## Summe aller Spielnoten (sumG). Durchschnitt: average_grade().
var grade_sum: int = 0
## Wie oft MVP eines Spiels.
var mvps: int = 0
var kills: int = 0
var deaths: int = 0
var assists: int = 0
var gold: int = 0
## Spielnote jedes Spiels in Reihenfolge (gr).
var grades: Array[int] = []
## Verlauf je Woche (hist): {"week": int, "form": float, "ovr": float}.
## Eintrag 0 ist der Saisonbeginn, danach einer pro gespielter Woche.
var history: Array[Dictionary] = []


func _init(p_player: Player) -> void:
	player = p_player
	start_stats = p_player.stats()
	start_ovr = p_player.overall()
	start_form = p_player.form
	history.append({"week": 0, "form": p_player.form, "ovr": start_ovr})


## Durchschnittliche Spielnote (0, wenn noch kein Spiel).
func average_grade() -> float:
	if games == 0:
		return 0.0
	return float(grade_sum) / games


## Overall-Veränderung seit Saisonbeginn.
func ovr_gain() -> float:
	return player.overall() - start_ovr
