class_name RiftSim
extends RefCounted
## Simulationskern, portiert aus web-sim/sim.js. Nur Konstanten und statische
## Funktionen, nichts davon kennt Szenen oder Nodes.
##
## Hier stehen Konstanten, Formeln und der Zufallsgenerator.
## Die Match-Simulation selbst steht in match_sim.gd (MatchSim).

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

## Comp-Archetypen für den Draft. Die Reihenfolge ist wichtig für die Zufallsauswahl.
const ARCH: Array[String] = ["Engage", "Poke", "Pick", "Split", "Scaling", "Control", "Teamfight"]

## Zeitkurve je Archetyp: Bonus in Minute 14–24, 25–34 und ab 35.
const CURVE: Dictionary = {
	"Pick": [3, 1, -1], "Poke": [2, 2, 0], "Engage": [1, 3, 2], "Split": [1, 2, 3],
	"Control": [0, 2, 3], "Teamfight": [-1, 3, 4], "Scaling": [-3, 1, 6],
}

## Counter-Matrix als Liste [Gewinner, Verlierer, Wert]. Gilt in beide Richtungen:
## der Verlierer bekommt den Wert negativ (siehe counter()).
const BEATS: Array = [
	["Engage", "Poke", 3], ["Engage", "Split", 2], ["Scaling", "Engage", 2], ["Control", "Engage", 3],
	["Poke", "Scaling", 3], ["Poke", "Control", 2], ["Pick", "Poke", 2], ["Poke", "Teamfight", 2],
	["Pick", "Split", 3], ["Pick", "Scaling", 2], ["Control", "Pick", 2], ["Teamfight", "Pick", 3],
	["Split", "Teamfight", 3], ["Split", "Control", 2], ["Scaling", "Split", 2],
	["Teamfight", "Control", 2], ["Teamfight", "Scaling", 2],
]

## Stellschrauben der Simulation (DEFAULTS in sim.js). Über opt["consts"] einzeln
## überschreibbar. Namen wie im Original, damit Werte 1:1 übertragbar sind.
## Einzige Änderung: kdaBase ist nach den CSV-Rollen (TOP, JGL …) benannt.
const DEFAULTS: Dictionary = {
	"lane": 50, "jgl": 25, "kill": 400, "objDiv": 50, "objGold": 3500, "compDiv": 10,
	"fightDiv": 80, "fightGold": 3, "throwBase": 0.10, "shutdown": 0.35, "sigmaBase": 8,
	"mastery": 85, "killsPerLane": 2.5, "fightKills": 3.4, "skirmish": 0.6, "ratingBase": 60,
	"ratingCompress": 0.7, "formCenter": 71, "formDiv": 12, "formAmp": 1.8, "formWeight": 0.3,
	"morale": 2, "formDrift": 1.5, "chemLoss": 2, "chemWin": 1, "chemGrowth": 1.2,
	"trainBase": 0.3, "statNoise": 0.9, "gankShare": 0.2,
	"kdaBase": {"TOP": 4.5, "JGL": 6, "MID": 4.5, "ADC": 5, "SUP": 5.5},
}

## DEFAULTS plus Überschreibungen (Object.assign({}, DEFAULTS, consts) im Original).
## Ganze Zahlen werden zu float, damit Divisionen wie in JavaScript mit
## Nachkommastellen rechnen (in GDScript ergibt 7 / 2 sonst 3).
static func merge_consts(overrides: Dictionary) -> Dictionary:
	var c: Dictionary = DEFAULTS.duplicate(true)
	for key: Variant in overrides:
		c[key] = overrides[key]
	for key: Variant in c:
		if typeof(c[key]) == TYPE_INT:
			c[key] = float(c[key])
	return c


## Counter-Matrix M[a][b] (aus BEATS aufgebaut, einmal beim ersten Zugriff).
static var _counter_matrix: Dictionary = _build_counter_matrix()


static func _build_counter_matrix() -> Dictionary:
	var m: Dictionary = {}
	for a: String in ARCH:
		var row: Dictionary = {}
		for b: String in ARCH:
			row[b] = 0
		m[a] = row
	for entry: Array in BEATS:
		m[entry[0]][entry[1]] = entry[2]
		m[entry[1]][entry[0]] = -int(entry[2])
	return m


## Wie stark Archetyp a gegen Archetyp b ist (M[a][b] in sim.js). Positiv = a kontert b.
static func counter(a: String, b: String) -> int:
	return _counter_matrix[a][b]


## Bester Konter gegen einen Archetyp. Bei Gleichstand gewinnt der zuerst in ARCH
## genannte (wie die stabile Sortierung im Original).
static func best_counter(against: String) -> String:
	var best: String = ARCH[0]
	for arch: String in ARCH:
		if counter(arch, against) > counter(best, against):
			best = arch
	return best


## Kommunikationswert K (commK in sim.js): 100, wenn der Spieler die Teamsprache spricht,
## sonst sein Englisch bei englischer Teamsprache, sonst 10.
static func comm_k(player: Player, team_language: String) -> float:
	if player.languages.has(team_language):
		return 100.0
	if team_language == "en":
		return player.english
	return 10.0


## Sigmoid-Funktion (sig in sim.js): macht aus einer Differenz eine Wahrscheinlichkeit 0–1.
static func sig(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


## Runden wie Math.round in JavaScript: x.5 rundet immer nach oben (auch bei negativen
## Zahlen: -2.5 -> -2). Godots round() rundet -2.5 auf -3, das würde Ergebnisse verändern.
static func js_round(x: float) -> int:
	var lower: float = floorf(x)
	return int(lower) + (1 if x - lower >= 0.5 else 0)


## Stabile Sortierung: bei Gleichstand bleibt die ursprüngliche Reihenfolge erhalten,
## wie bei Array.sort in JavaScript. Godots sort_custom garantiert das nicht.
## before(a, b) gibt true zurück, wenn a vor b gehört. Gibt eine neue Liste zurück.
static func stable_sort(items: Array, before: Callable) -> Array:
	var result: Array = items.duplicate()
	for i: int in range(1, result.size()):
		var item: Variant = result[i]
		var j: int = i - 1
		while j >= 0 and before.call(item, result[j]):
			result[j + 1] = result[j]
			j -= 1
		result[j + 1] = item
	return result


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
