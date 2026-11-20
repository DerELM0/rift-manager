class_name TraitRules
extends RefCounted
## Trait-Effekte als Bausteine. Die Traits selbst stehen als Daten in
## data/default/traits.csv (geladen vom Autoload Database), hier ist jeder
## Baustein-Typ genau einmal programmiert. MatchSim und Season fragen nur
## diese Funktionen ab und kennen keine Trait-Namen.
##
## Reihenfolge: Effekte werden in der Reihenfolge der Zeilen in traits.csv
## angewendet. Das ist wichtig, weil Kommazahlen je nach Reihenfolge minimal
## anders gerundet werden. Zeilen nicht umsortieren, ohne die Prüfwerte in der
## Debug-Szene neu zu erzeugen.
##
## Bausteine (Parameter in Klammern, [optional]):
##   stat_bonus       (stat, wert, [phase], [kontext], [rolle], [ab_minute])
##                    Wert +wert auf einen Spielwert. phase: spiel (ganzes Spiel,
##                    Standard), laning (Lane- und Jungle-Wert bis Minute 14),
##                    teamfight (Fight-Stärke). ab_minute nur bei teamfight.
##   schwankung       (faktor, [kontext], [rolle])   Tagesform-Schwankung × faktor
##   jungle_druck     (wert)            Jungle-Wert J + wert
##   fokus_lane_kills (wert)            + wert Kill-Ereignisse in der Lane, die der
##                                      Jungler fokussiert (einmal je Lane)
##   gank_anteil      (wer, wert)       Anteil der Lane-Kills für den Jungler + wert;
##                                      wer: jungler (Trait beim Jungler) oder
##                                      killer (Trait beim Laner, der den Kill macht)
##   todes_gewicht    (faktor)          Chance, als Opfer eines Kills gewählt zu werden × faktor
##   roam             (bonus, eigene, [rolle])  + bonus Laning auf der schwächsten
##                                      anderen Lane, + eigene auf der eigenen Lane
##   weak_side        (faktor, [rolle]) Jungle-Hilfe, wenn der Jungler eine andere
##                                      Lane fokussiert: faktor × J statt 0,025 × J
##   shotcaller       (wert)            Team-Macro + wert × CHA/100, nur der Shotcaller
##                                      mit dem höchsten Charisma zählt
##   team_macro       (wert)            Team-Macro bei Objectives + wert (einmal je Team)
##   team_fight       (wert)            Fight-Stärke des Teams + wert (einmal je Team)
##   training         (wert)            Trainingsfaktor B + wert (z. B. 0.10 = +10 %)
##   mentor           (wert, min_alter, schueler_bis)  Spieler bis schueler_bis
##                                      Jahre im Team trainieren + wert, wenn der
##                                      Mentor mindestens min_alter ist
##   spaetstarter     (bis_alter, wie_alter)  Bis bis_alter Jahre trainiert der
##                                      Spieler wie ein wie_alter-Jähriger
##   chemie           (faktor)          Chemistry-Wachstum seiner Paare × faktor
##   sprache_lernen   (faktor)          Englisch-Lernen × faktor
##
## Kontexte: druck (Playoffs und Entscheidungsspiel einer Serie),
## gold_vorne (eigenes Team liegt in Gold vorn, nur bei teamfight).
## Rollen: TOP, JGL, MID, ADC, SUP, mehrere mit "/" getrennt, z. B. rolle=MID/SUP.

const BLOCKS: Dictionary = {
	"stat_bonus": {"pflicht": ["stat", "wert"], "optional": ["phase", "kontext", "rolle", "ab_minute"]},
	"schwankung": {"pflicht": ["faktor"], "optional": ["kontext", "rolle"]},
	"jungle_druck": {"pflicht": ["wert"], "optional": []},
	"fokus_lane_kills": {"pflicht": ["wert"], "optional": []},
	"gank_anteil": {"pflicht": ["wer", "wert"], "optional": []},
	"todes_gewicht": {"pflicht": ["faktor"], "optional": []},
	"roam": {"pflicht": ["bonus", "eigene"], "optional": ["rolle"]},
	"weak_side": {"pflicht": ["faktor"], "optional": ["rolle"]},
	"shotcaller": {"pflicht": ["wert"], "optional": []},
	"team_macro": {"pflicht": ["wert"], "optional": []},
	"team_fight": {"pflicht": ["wert"], "optional": []},
	"training": {"pflicht": ["wert"], "optional": []},
	"mentor": {"pflicht": ["wert", "min_alter", "schueler_bis"], "optional": []},
	"spaetstarter": {"pflicht": ["bis_alter", "wie_alter"], "optional": []},
	"chemie": {"pflicht": ["faktor"], "optional": []},
	"sprache_lernen": {"pflicht": ["faktor"], "optional": []},
}

## Parameter, die Zahlen sind. Alle anderen sind Text.
const NUMBER_PARAMS: Array[String] = ["wert", "faktor", "bonus", "eigene", "min_alter", "schueler_bis",
	"bis_alter", "wie_alter", "ab_minute"]
## Erlaubte Werte für Text-Parameter (rolle wird gegen RiftSim.ROLES geprüft).
const TEXT_VALUES: Dictionary = {
	"stat": ["mec", "lan", "mac", "tea", "men"],
	"phase": ["spiel", "laning", "teamfight"],
	"kontext": ["druck", "gold_vorne"],
	"wer": ["jungler", "killer"],
}
const ARTS: Array[String] = ["positiv", "gemischt", "negativ"]
## Index des Spielwerts in Player.stats().
const STAT_INDEX: Dictionary = {"mec": 0, "lan": 1, "mac": 2, "tea": 3, "men": 4}

static var _traits: Array[TraitDef] = []
static var _by_name: Dictionary = {}
## Baustein-Typ -> alle Effekte dieses Typs in CSV-Reihenfolge.
static var _by_type: Dictionary = {}
static var _loaded: bool = false
static var _warned_not_loaded: bool = false


# --- Registrierung und Abfrage ----------------------------------------------

## Setzt die geladenen Traits (macht das Autoload Database beim Start).
static func register(traits: Array[TraitDef]) -> void:
	_traits = traits
	_by_name.clear()
	_by_type.clear()
	for t: TraitDef in traits:
		_by_name[t.name] = t
		for e: TraitEffect in t.effects:
			if not _by_type.has(e.type):
				_by_type[e.type] = []
			_by_type[e.type].append(e)
	_loaded = true


static func is_loaded() -> bool:
	return _loaded


## Trait nach Name oder null.
static func get_trait(trait_name: String) -> TraitDef:
	return _by_name.get(trait_name, null)


static func all_traits() -> Array[TraitDef]:
	return _traits


# --- Einlesen ---------------------------------------------------------------

## Zerlegt die Spalte effekte, z. B. "stat_bonus|stat=mec|wert=4;chemie|faktor=1.3".
## Probleme landen in errors (als lesbarer Text), fehlerhafte Effekte werden übersprungen.
static func parse_effects(source: String, trait_name: String, errors: PackedStringArray) -> Array[TraitEffect]:
	var result: Array[TraitEffect] = []
	for raw: String in source.split(";", false):
		var parts: PackedStringArray = raw.strip_edges().split("|")
		var type: String = parts[0].strip_edges()
		if type.is_empty():
			continue
		if not BLOCKS.has(type):
			errors.append("%s: unbekannter Baustein '%s'" % [trait_name, type])
			continue
		var spec: Dictionary = BLOCKS[type]
		var effect := TraitEffect.new()
		effect.trait_name = trait_name
		effect.type = type
		var ok: bool = true
		for i: int in range(1, parts.size()):
			var pair: PackedStringArray = parts[i].split("=", true, 1)
			var key: String = pair[0].strip_edges()
			var value: String = pair[1].strip_edges() if pair.size() == 2 else ""
			if not spec["pflicht"].has(key) and not spec["optional"].has(key):
				errors.append("%s: Baustein %s kennt den Parameter '%s' nicht" % [trait_name, type, key])
				ok = false
				continue
			if NUMBER_PARAMS.has(key):
				var number: Variant = parse_number(value)
				if number == null:
					errors.append("%s: %s=%s ist keine Zahl" % [trait_name, key, value])
					ok = false
					continue
				effect.numbers[key] = number
			else:
				if not _text_value_ok(key, value):
					errors.append("%s: %s=%s ist nicht erlaubt" % [trait_name, key, value])
					ok = false
					continue
				effect.texts[key] = value
		for key: String in spec["pflicht"]:
			if not effect.has(key):
				errors.append("%s: Baustein %s braucht den Parameter '%s'" % [trait_name, type, key])
				ok = false
		if effect.has("ab_minute") and effect.text("phase", "spiel") != "teamfight":
			errors.append("%s: ab_minute geht nur mit phase=teamfight" % trait_name)
			ok = false
		if ok:
			result.append(effect)
	return result


static func is_valid_art(art: String) -> bool:
	return ARTS.has(art)


static func _text_value_ok(key: String, value: String) -> bool:
	if key == "rolle":
		var roles: PackedStringArray = value.split("/", false)
		if roles.is_empty():
			return false
		for role: String in roles:
			if not RiftSim.ROLES.has(role):
				return false
		return true
	return TEXT_VALUES.has(key) and TEXT_VALUES[key].has(value)


## Liest eine Dezimalzahl wie "0.08", "-4" oder "+1.5" (Punkt als Dezimaltrenner).
## Gibt null zurück, wenn es keine Zahl ist. Gerechnet wird als ganze Zahl geteilt
## durch eine Zehnerpotenz; das ergibt exakt den nächstliegenden Kommawert, wie
## ein Zahl-Literal im Code oder im Web-Simulator.
static func parse_number(source: String) -> Variant:
	var s: String = source.strip_edges()
	var negative: bool = false
	if s.begins_with("+") or s.begins_with("-"):
		negative = s.begins_with("-")
		s = s.substr(1)
	var parts: PackedStringArray = s.split(".")
	if parts.size() > 2:
		return null
	var digits: String = parts[0] + (parts[1] if parts.size() == 2 else "")
	if digits.is_empty() or digits.length() > 15:
		return null
	for c: String in digits:
		if not "0123456789".contains(c):
			return null
	var scale: float = 1.0
	if parts.size() == 2:
		for _i: int in parts[1].length():
			scale *= 10.0
	var value: float = float(digits.to_int()) / scale
	return -value if negative else value


# --- Bausteine ----------------------------------------------------------------

## stat_bonus: Boni der Phase auf stats [MEC, LAN, MAC, TEA, MEN] addieren.
## ctx: "druck" (bool), bei teamfight zusätzlich "gold_vorne" (bool) und "minute" (int).
static func apply_stat_bonuses(p: Player, stats: Array[float], phase: String, ctx: Dictionary) -> void:
	for e: TraitEffect in _effects(p, "stat_bonus"):
		if e.text("phase", "spiel") == phase and _matches(e, p, ctx):
			stats[STAT_INDEX[e.text("stat")]] += e.num("wert")


## schwankung: Standardabweichung der Tagesform × faktor.
static func variance_factor(p: Player, sd: float, ctx: Dictionary) -> float:
	for e: TraitEffect in _effects(p, "schwankung"):
		if _matches(e, p, ctx):
			sd *= e.num("faktor")
	return sd


## jungle_druck: Zuschlag auf den Jungle-Wert J.
static func jungle_pressure(p: Player) -> float:
	var bonus: float = 0.0
	for e: TraitEffect in _effects(p, "jungle_druck"):
		bonus += e.num("wert")
	return bonus


## fokus_lane_kills: zusätzliche Kill-Ereignisse in der fokussierten Lane (größter Wert).
static func focus_lane_kills(p: Player) -> int:
	var extra: int = 0
	for e: TraitEffect in _effects(p, "fokus_lane_kills"):
		extra = maxi(extra, int(e.num("wert")))
	return extra


## gank_anteil: Anteil der Lane-Kills für den Jungler, Effekte von Jungler und
## Killer in CSV-Reihenfolge.
static func gank_share(share: float, jungler: Player, killer: Player) -> float:
	for e: TraitEffect in _all_of("gank_anteil"):
		var holder: Player = jungler if e.text("wer") == "jungler" else killer
		if holder.has_trait(e.trait_name):
			share += e.num("wert")
	return share


## todes_gewicht: Gewicht, als Opfer gewählt zu werden.
static func death_weight(p: Player, weight: float) -> float:
	for e: TraitEffect in _effects(p, "todes_gewicht"):
		weight *= e.num("faktor")
	return weight


## roam: erster passender Roam-Effekt des Spielers oder null.
static func roam_effect(p: Player) -> TraitEffect:
	for e: TraitEffect in _effects(p, "roam"):
		if _matches(e, p, {}):
			return e
	return null


## weak_side: Faktor der Jungle-Hilfe, wenn der Jungler eine andere Lane fokussiert.
static func weak_side_factor(p: Player, default_factor: float) -> float:
	var factor: float = default_factor
	for e: TraitEffect in _effects(p, "weak_side"):
		if _matches(e, p, {}):
			factor = e.num("faktor")
	return factor


## shotcaller: Wert des Shotcaller-Effekts oder -1, wenn der Spieler keinen hat.
static func shotcaller_value(p: Player) -> float:
	var value: float = -1.0
	for e: TraitEffect in _effects(p, "shotcaller"):
		value = e.num("wert")
	return value


## team_macro / team_fight: Teambonus, zählt einmal je Team (größter Wert).
static func team_bonus(players: Array[Player], type: String) -> float:
	var bonus: float = 0.0
	for p: Player in players:
		for e: TraitEffect in _effects(p, type):
			bonus = maxf(bonus, e.num("wert"))
	return bonus


## training: Zuschläge auf den Trainingsfaktor B.
static func training_bonus(p: Player, b: float) -> float:
	for e: TraitEffect in _effects(p, "training"):
		b += e.num("wert")
	return b


## mentor: Zuschlag für einen Schüler durch Mentoren im Team (größter Wert, 0 = keiner).
static func mentor_bonus(players: Array[Player], student: Player) -> float:
	var bonus: float = 0.0
	for p: Player in players:
		for e: TraitEffect in _effects(p, "mentor"):
			if p.age >= e.num("min_alter") and student.age <= e.num("schueler_bis"):
				bonus = maxf(bonus, e.num("wert"))
	return bonus


## spaetstarter: Alter, mit dem der Altersfaktor im Training berechnet wird.
static func training_age(p: Player) -> int:
	var age: int = p.age
	for e: TraitEffect in _effects(p, "spaetstarter"):
		if age <= e.num("bis_alter"):
			age = mini(age, int(e.num("wie_alter")))
	return age


## chemie: Faktor auf das Chemistry-Wachstum eines Paares (für einen Spieler).
static func chemistry_factor(p: Player, factor: float) -> float:
	for e: TraitEffect in _effects(p, "chemie"):
		factor *= e.num("faktor")
	return factor


## sprache_lernen: Faktor auf das Englisch-Lernen.
static func language_factor(p: Player) -> float:
	var factor: float = 1.0
	for e: TraitEffect in _effects(p, "sprache_lernen"):
		factor *= e.num("faktor")
	return factor


# --- intern -------------------------------------------------------------------

## Effekte eines Typs, die der Spieler über seine Traits hat, in CSV-Reihenfolge.
static func _effects(p: Player, type: String) -> Array[TraitEffect]:
	var result: Array[TraitEffect] = []
	for e: TraitEffect in _all_of(type):
		if p.has_trait(e.trait_name):
			result.append(e)
	return result


static func _all_of(type: String) -> Array:
	if not _loaded and not _warned_not_loaded:
		_warned_not_loaded = true
		push_warning("TraitRules: Traits sind nicht geladen, Trait-Effekte fehlen (Autoload Database?).")
	return _by_type.get(type, [])


## Bedingungen rolle, kontext und ab_minute.
static func _matches(e: TraitEffect, p: Player, ctx: Dictionary) -> bool:
	if e.has("rolle") and not e.roles().has(p.role):
		return false
	var context: String = e.text("kontext")
	if not context.is_empty() and not bool(ctx.get(context, false)):
		return false
	if e.has("ab_minute") and int(ctx.get("minute", 0)) < e.num("ab_minute"):
		return false
	return true
