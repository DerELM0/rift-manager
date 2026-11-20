class_name RiftSim
extends RefCounted
## Simulationskern, portiert aus web-sim/sim.js. Nur Konstanten und statische
## Funktionen, nichts davon kennt Szenen oder Nodes.
##
## Teil 1: Rollen, Rollengewichte, Overall-Formeln und Zufallsgenerator.

## Rollen in Aufstellungsreihenfolge. Im Web-Simulator heißen sie
## Top, Jungle, Mid, ADC, Support; hier die Kürzel aus der CSV.
const ROLES: Array[String] = ["TOP", "JGL", "MID", "ADC", "SUP"]

## Rollengewichte W für den Overall, in der Reihenfolge der Stats:
## Mechanics, Laning, Macro, Teamwork, Mental. Jede Zeile ergibt zusammen 1.0.
const W: Dictionary = {
	"TOP": [0.25, 0.30, 0.15, 0.10, 0.20],
	"JGL": [0.20, 0.05, 0.40, 0.20, 0.15],
	"MID": [0.30, 0.25, 0.25, 0.10, 0.10],
	"ADC": [0.35, 0.30, 0.10, 0.15, 0.10],
	"SUP": [0.10, 0.15, 0.30, 0.35, 0.10],
}


## Overall aus Rolle und Stats [Mechanics, Laning, Macro, Teamwork, Mental]
## (ovrOf in sim.js): gewichtete Summe mit den Rollengewichten.
static func ovr_of(role: String, stats: Array) -> float:
	var weights: Array = W.get(role, [])
	if weights.is_empty():
		push_warning("RiftSim.ovr_of: unbekannte Rolle '%s'." % role)
		return 0.0
	var total: float = 0.0
	for i: int in weights.size():
		total += float(weights[i]) * float(stats[i])
	return total


## Team-Overall (teamOvr in sim.js): Summe der Spieler-Overalls geteilt durch 5.
## Wie im Original wird immer durch 5 geteilt, auch wenn Spieler fehlen.
static func team_ovr(team: Team) -> float:
	var total: float = 0.0
	for player: Player in team.players:
		total += ovr_of(player.role, player.stats())
	return total / 5.0


## Neuer Zufallsgenerator (makeRng in sim.js). Gleicher Seed ergibt exakt
## dieselbe Zahlenfolge wie im Web-Simulator.
static func make_rng(seed_value: int) -> Rng:
	return Rng.new(seed_value)


## Zufallsgenerator nach Mulberry32, bitgenau wie in JavaScript.
## JavaScript rechnet bei Bit-Operationen mit 32 Bit, GDScript-ints haben 64 Bit.
## Deshalb wird nach jedem Schritt auf 32 Bit maskiert (& MASK).
class Rng extends RefCounted:
	const MASK: int = 0xFFFFFFFF

	## Interner Zustand, immer im Bereich 0 .. 2^32-1.
	var _state: int = 0

	func _init(seed_value: int) -> void:
		_state = seed_value & MASK  # entspricht "seed >>> 0" in JS

	## Gleichverteilte Zahl in [0, 1) (r() bzw. u() in sim.js).
	func next_float() -> float:
		_state = (_state + 0x6D2B79F5) & MASK
		var t: int = _imul(_state ^ (_state >> 15), 1 | _state)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
		return float(t ^ (t >> 14)) / 4294967296.0

	## Ganze Zahl von a bis b, beide inklusive (int in sim.js).
	func int_range(a: int, b: int) -> int:
		return a + floori(next_float() * (b - a + 1))

	## Normalverteilt mit Mittelwert 0 und Standardabweichung 1 (gauss, Box-Muller).
	func gauss() -> float:
		var u: float = 0.0
		var v: float = 0.0
		while u == 0.0:
			u = next_float()
		while v == 0.0:
			v = next_float()
		return sqrt(-2.0 * log(u)) * cos(2.0 * PI * v)

	## Zufälliges Element einer Liste (pick).
	func pick(items: Array) -> Variant:
		return items[floori(next_float() * items.size())]

	## Poisson-verteilte Anzahl mit Erwartungswert lam (poisson).
	func poisson(lam: float) -> int:
		var limit: float = exp(-lam)
		var k: int = 0
		var p: float = 1.0
		while true:
			k += 1
			p *= next_float()
			if p <= limit:
				break
		return k - 1

	## Zufälliges Element, gewichtet (weighted). weights gehört Element für Element zu items.
	func weighted(items: Array, weights: Array) -> Variant:
		var total: float = 0.0
		for w: Variant in weights:
			total += float(w)
		var x: float = next_float() * total
		for i: int in items.size():
			x -= float(weights[i])
			if x <= 0.0:
				return items[i]
		return items[items.size() - 1]

	## Math.imul aus JS: 32-Bit-Multiplikation, Ergebnis als 32-Bit-Muster.
	## In zwei 16-Bit-Hälften gerechnet, damit kein Zwischenwert die 64 Bit sprengt.
	static func _imul(x: int, y: int) -> int:
		var low: int = (x & 0xFFFF) * y
		var high: int = ((x >> 16) * y) & 0xFFFF
		return (low + (high << 16)) & MASK
