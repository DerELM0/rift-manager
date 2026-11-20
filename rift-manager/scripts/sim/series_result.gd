class_name SeriesResult
extends RefCounted
## Ergebnis einer Serie (Bo1, Bo3, Bo5), Rückgabe von MatchSim.simulate_series.
## Entspricht { games, wa, wb } aus simulateSeries in web-sim/sim.js.

## Alle gespielten Spiele in Reihenfolge.
var games: Array[MatchResult] = []
## Gewonnene Spiele von Team A (wa) und Team B (wb).
var wins_a: int = 0
var wins_b: int = 0


## Siegerseite der Serie: "A" oder "B".
func winner() -> String:
	return "A" if wins_a > wins_b else "B"
