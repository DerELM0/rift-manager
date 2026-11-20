class_name Player
extends RefCounted
## Ein Spieler, eine Zeile aus players.csv. Spielwerte 0–100.

## Rollen-Kürzel wie in der CSV-Spalte role, in Aufstellungsreihenfolge.
const ROLES: Array[String] = ["TOP", "JGL", "MID", "ADC", "SUP"]

## Kürzel des Teams (team_short), über das der Spieler seinem Team zugeordnet wird.
var team_short: String = ""
## Echter Name (Spalte name), oft leer.
var real_name: String = ""
## Ingame-Name (Spalte nickname).
var nickname: String = ""
## Eins von ROLES.
var role: String = ""
var age: int = 0
## "m" oder "f".
var gender: String = ""
## Sprachen als Kürzel, z. B. ["en", "ko"].
var languages: PackedStringArray = []
## Englischkenntnisse 0–100, wichtig für die Kommunikation im Team.
var english: int = 0

var mechanics: int = 0
var laning: int = 0
var macro: int = 0
var teamwork: int = 0
var mental: int = 0

## Charisma: hilft beim Aufbau von Chemistry und bei Fans.
var charisma: int = 0
## Höchster Wert, den der Spieler erreichen kann.
var potential: int = 0
## Gesamtwert. Vorerst aus der CSV-Spalte ovr übernommen;
## die rollenabhängige Formel (web-sim/sim.js, ovrOf) wird später portiert.
var overall: float = 0.0

## Eigenschaften à la Football Manager, z. B. ["Shotcaller", "Mentor"].
var traits: PackedStringArray = []


## Name für die Anzeige: Nickname, sonst echter Name.
func display_name() -> String:
	return nickname if not nickname.is_empty() else real_name


func has_trait(trait_name: String) -> bool:
	return traits.has(trait_name)
