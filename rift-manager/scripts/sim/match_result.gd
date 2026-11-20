class_name MatchResult
extends RefCounted
## Ergebnis eines simulierten Spiels (Rückgabe von MatchSim.simulate_game).
## Entspricht dem Rückgabeobjekt von simulateGame in web-sim/sim.js.
##
## "A" ist immer das erste, "B" das zweite übergebene Team.
## Dictionaries mit den Schlüsseln "A" und "B" enthalten den Wert je Team.


## Ein Eintrag im Spielverlauf (log).
class LogEntry extends RefCounted:
	## Spielminute.
	var minute: int = 0
	## Text für die Anzeige, z. B. "First Blood! Thanos tötet Crest (Top)".
	var text: String = ""
	## "A", "B" oder "" (betrifft beide Teams, z. B. Draft).
	var side: String = ""
	## Art des Ereignisses: "draft", "plan", "kill", "phase", "obj", "fight", "big", "end".
	var kind: String = ""

	func _init(p_minute: int, p_text: String, p_side: String, p_kind: String) -> void:
		minute = p_minute
		text = p_text
		side = p_side
		kind = p_kind


## Statistik und Bewertung eines Spielers für dieses Spiel (ratings).
class PlayerRating extends RefCounted:
	var player: Player = null
	## Anzeigename (tag im Original).
	var name: String = ""
	var role: String = ""
	var kills: int = 0
	var deaths: int = 0
	var assists: int = 0
	## (Kills + Assists) / Tode, mindestens durch 1 geteilt.
	var kda: float = 0.0
	## Spielnote 0–100 (g im Original).
	var grade: int = 0
	## Kommunikationswert K mit der Teamsprache (100, Englischwert oder 10).
	var comm: float = 0.0
	## Gold am Spielende.
	var gold: int = 0


## Siegerseite: "A" oder "B".
var winner: String = ""
## Spieldauer in Minuten (dur).
var duration: int = 0
## Golddifferenz A − B pro Minute, Index = Minute (0 bis Dauer, höchstens 60).
var gold: Array[int] = []
## Golddifferenz A − B nach dem Laning (Minute 14).
var gold14: int = 0
## Wer nach Minute 14 vorne lag: "A", "B" oder "" bei Gleichstand.
var leader14: String = ""
## Spielverlauf, zeitlich sortiert (log im Original; "log" ist in GDScript
## schon der Name der Logarithmus-Funktion).
var game_log: Array[LogEntry] = []
## Draft je Seite: {"A": {"arch": "Engage", "score": 3}, "B": {...}}.
## arch = gewählter Comp-Archetyp, score = Comp-Qualität 0–5.
var draft: Dictionary = {}
## Jungle-Plan je Seite: "Top", "Mid", "Bot" oder "Objectives".
var plans: Dictionary = {}
## Spielerbewertungen je Seite, in Rollenreihenfolge TOP bis SUP.
var ratings: Dictionary = {}
## Name des besten Spielers im Siegerteam.
var mvp: String = ""
## Geholte Drachen je Seite.
var drakes: Dictionary = {}
## Anzahl Teamfights.
var fights: int = 0
## Gesamtgold je Seite am Spielende.
var team_gold: Dictionary = {}
## Kills je Seite.
var kills: Dictionary = {}

## Die beiden Teams (nicht im Original, aber praktisch für die Anzeige).
var team_a: Team = null
var team_b: Team = null


## Das Siegerteam als Team-Objekt.
func winner_team() -> Team:
	return team_a if winner == "A" else team_b


## Kurze Zusammenfassung, z. B. "Sieger BYN, Dauer 35, Kills 12:17, MVP Zeph, Gold@14 2333".
func summary() -> String:
	return "Sieger %s, Dauer %d, Kills %d:%d, MVP %s, Gold@14 %d" % [
		winner_team().short, duration, kills["A"], kills["B"], mvp, gold14]
