class_name Player
extends RefCounted
## Ein Spieler, eine Zeile aus players.csv. Spielwerte 0–100.

## Kürzel des Teams (team_short), über das der Spieler seinem Team zugeordnet wird.
var team_short: String = ""
## Echter Name (Spalte name), oft leer.
var real_name: String = ""
## Ingame-Name (Spalte nickname).
var nickname: String = ""
## Eins von RiftSim.ROLES (TOP, JGL, MID, ADC, SUP).
var role: String = ""
var age: int = 0
## "m" oder "f".
var gender: String = ""
## Sprachen als Kürzel, z. B. ["en", "ko"].
var languages: PackedStringArray = []
## Englischkenntnisse 0–100, wichtig für die Kommunikation im Team.
## Kommazahl, weil sie in der Saison in kleinen Schritten wächst.
var english: float = 0.0

## Spielwerte 0–100. Kommazahlen, weil das Training in der Saison sie in
## kleinen Schritten verändert (wie im Web-Simulator).
var mechanics: float = 0.0
var laning: float = 0.0
var macro: float = 0.0
var teamwork: float = 0.0
var mental: float = 0.0

## Charisma: hilft beim Aufbau von Chemistry und bei Fans.
var charisma: int = 0
## Höchster Wert, den der Spieler erreichen kann.
var potential: int = 0
## Aktuelle Form (um 71 herum). Wird später von der Saison gesetzt.
## Negativ heißt: noch keine Form, die Match-Simulation ignoriert sie dann
## (wie "form == null" im Web-Simulator).
var form: float = -1.0

## Eigenschaften à la Football Manager, z. B. ["Shotcaller", "Mentor"].
var traits: PackedStringArray = []


## Name für die Anzeige: Nickname, sonst echter Name.
func display_name() -> String:
	return nickname if not nickname.is_empty() else real_name


## Die fünf Spielwerte in der Reihenfolge, die RiftSim erwartet:
## [Mechanics, Laning, Macro, Teamwork, Mental].
func stats() -> Array[float]:
	return [mechanics, laning, macro, teamwork, mental]


## Gesamtwert, berechnet aus Rolle und Stats (RiftSim.ovr_of).
func overall() -> float:
	return RiftSim.ovr_of(role, stats())


func has_form() -> bool:
	return form >= 0.0


func has_trait(trait_name: String) -> bool:
	return traits.has(trait_name)


## Unabhängige Kopie (z. B. für eine Saison). Änderungen an der Kopie
## wirken nicht auf das Original.
func copy() -> Player:
	var c := Player.new()
	c.team_short = team_short
	c.real_name = real_name
	c.nickname = nickname
	c.role = role
	c.age = age
	c.gender = gender
	c.languages = languages.duplicate()
	c.english = english
	c.mechanics = mechanics
	c.laning = laning
	c.macro = macro
	c.teamwork = teamwork
	c.mental = mental
	c.charisma = charisma
	c.potential = potential
	c.form = form
	c.traits = traits.duplicate()
	return c
