class_name Team
extends RefCounted
## Ein Team, eine Zeile aus teams.csv, plus seine Spieler aus players.csv.

## Kürzel (Spalte short), eindeutig. Darüber werden Spieler zugeordnet.
var short: String = ""
var name: String = ""
## Liga, z. B. "LCK" oder "EMEA T3".
var league: String = ""
## 1 = Top-Liga, 3 = unterste Stufe.
var tier: int = 1
## Teamsprache (Spalte team_language), z. B. "ko".
var language: String = ""
## Chemistry 0–100 (Spalte chem).
var chemistry: int = 0
## null, wenn das Team keinen Coach hat (Spalte coach_name leer).
var coach: Coach = null
## Spieler des Teams, nach Rolle sortiert (TOP, JGL, MID, ADC, SUP).
var players: Array[Player] = []


## Spieler auf einer Rolle (z. B. "MID"), oder null.
func get_player(role: String) -> Player:
	for player: Player in players:
		if player.role == role:
			return player
	return null


## Team-Overall: Durchschnitt der 5 Spieler (RiftSim.team_ovr).
func overall() -> float:
	return RiftSim.team_ovr(self)
