class_name Coach
extends RefCounted
## Coach eines Teams. Werte 0–100, aus teams.csv (Spalten coach_*).
## Bedeutung laut Web-Simulator (web-sim/sim.js, season.js).

var name: String = ""
## coach_dra: Draft-Qualität und Chance, die gegnerische Comp zu kontern.
var drafting: int = 0
## coach_dev: Wie schnell sich die Spieler im Training verbessern.
var development: int = 0
## coach_mot: Motivation, beeinflusst die Form der Spieler.
var motivation: int = 0
## coach_tac: Taktik, beeinflusst Macro-Entscheidungen im Spiel.
var tactics: int = 0
## coach_man: Management, beeinflusst das Wachstum der Chemistry.
var management: int = 0


## Coach ohne Namen mit 30 in allen Werten. So rechnet der Web-Simulator,
## wenn ein Team keinen Coach hat.
static func fallback() -> Coach:
	var c := Coach.new()
	c.drafting = 30
	c.development = 30
	c.motivation = 30
	c.tactics = 30
	c.management = 30
	return c


func copy() -> Coach:
	var c := Coach.new()
	c.name = name
	c.drafting = drafting
	c.development = development
	c.motivation = motivation
	c.tactics = tactics
	c.management = management
	return c
