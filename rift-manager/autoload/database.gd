extends Node
## Autoload "Database": liest beim Start die Standarddaten aus data/default/
## (teams.csv und players.csv) und stellt Teams und Spieler bereit.
##
## Probleme in den Daten werden mit push_warning gemeldet (im Godot-Debugger
## unter "Fehler"/"Errors"). Fehlerhafte Zeilen werden übersprungen, das Spiel läuft weiter.

const TEAMS_PATH: String = "res://data/default/teams.csv"
const PLAYERS_PATH: String = "res://data/default/players.csv"
const TRAITS_PATH: String = "res://data/default/traits.csv"
const TRAIT_COLUMNS: Array[String] = ["name", "art", "effekte", "tooltip"]

const TEAM_COLUMNS: Array[String] = [
	"short", "name", "league", "tier", "team_language", "chem",
	"coach_name", "coach_dra", "coach_dev", "coach_mot", "coach_tac", "coach_man",
]
const PLAYER_COLUMNS: Array[String] = [
	"team_short", "name", "nickname", "role", "age", "gender", "language", "english",
	"mechanics", "laning", "macro", "teamwork", "mental", "charisma", "potential", "ovr", "traits",
]

var _teams: Array[Team] = []
var _teams_by_short: Dictionary[String, Team] = {}
var _player_count: int = 0

## Erlaubte Abweichung zwischen berechnetem Overall und CSV-Spalte ovr.
## Die CSV speichert ovr auf 1 Nachkommastelle gerundet, deshalb liegen Werte
## wie 70.15 -> "70.1" genau 0.05 daneben. Das kleine Extra (1e-6) fängt den
## Rechenrest von Kommazahlen ab, damit diese Fälle nicht als Abweichung zählen.
const OVR_TOLERANCE: float = 0.05 + 1e-6
## Zähler für den OVR-Check beim Laden.
var _ovr_checked: int = 0
var _ovr_matching: int = 0


func _ready() -> void:
	load_traits(TRAITS_PATH)
	load_from_files(TEAMS_PATH, PLAYERS_PATH)


# --- Abfragen ---------------------------------------------------------------

## Alle geladenen Teams in der Reihenfolge der CSV.
func get_all_teams() -> Array[Team]:
	return _teams.duplicate()


## Team nach Kürzel (z. B. "C7"), oder null, wenn es das Kürzel nicht gibt.
func get_team(short: String) -> Team:
	return _teams_by_short.get(short, null)


## Alle Teams einer Liga (z. B. "LCK").
func get_teams_in_league(league: String) -> Array[Team]:
	var result: Array[Team] = []
	for team: Team in _teams:
		if team.league == league:
			result.append(team)
	return result


## Alle Ligennamen, sortiert nach Tier und dann alphabetisch.
func get_leagues() -> Array[String]:
	var tier_of: Dictionary[String, int] = {}
	for team: Team in _teams:
		if not tier_of.has(team.league):
			tier_of[team.league] = team.tier
	var leagues: Array[String] = []
	leagues.assign(tier_of.keys())
	leagues.sort_custom(func(a: String, b: String) -> bool:
		if tier_of[a] != tier_of[b]:
			return tier_of[a] < tier_of[b]
		return a < b)
	return leagues


func get_team_count() -> int:
	return _teams.size()


## Anzahl der Spieler, die einem Team zugeordnet wurden.
func get_player_count() -> int:
	return _player_count


# --- Laden ------------------------------------------------------------------

## Lädt die Traits aus traits.csv, prüft die Effekt-Bausteine und gibt sie an
## TraitRules weiter. Muss vor den Spielern geladen werden.
func load_traits(path: String) -> void:
	var traits: Array[TraitDef] = []
	var seen: Dictionary = {}
	for row: Dictionary in _read_csv(path, TRAIT_COLUMNS):
		var trait_name: String = row.get("name", "")
		if trait_name.is_empty():
			push_warning("Database: Trait ohne Namen in %s, übersprungen." % path)
			continue
		if seen.has(trait_name):
			push_warning("Database: Trait '%s' ist doppelt, zweiter Eintrag übersprungen." % trait_name)
			continue
		seen[trait_name] = true
		var t := TraitDef.new()
		t.name = trait_name
		t.art = row.get("art", "")
		if not TraitRules.is_valid_art(t.art):
			push_warning("Database: Trait '%s' hat unbekannte Art '%s' (erlaubt: %s)."
					% [trait_name, t.art, ", ".join(PackedStringArray(TraitRules.ARTS))])
		t.tooltip = row.get("tooltip", "")
		var errors: PackedStringArray = []
		t.effects = TraitRules.parse_effects(row.get("effekte", ""), trait_name, errors)
		for error: String in errors:
			push_warning("Database: Trait %s" % error)
		traits.append(t)
	TraitRules.register(traits)
	print("Database: %d Traits geladen." % traits.size())


## Meldet Traits eines Spielers, die es in traits.csv nicht gibt (sie wirken nicht).
func _check_player_traits(player: Player) -> void:
	for trait_name: String in player.traits:
		if TraitRules.get_trait(trait_name) == null:
			push_warning("Database: Spieler %s (%s) hat unbekannten Trait '%s', der Trait wirkt nicht."
					% [player.display_name(), player.team_short, trait_name])


## Lädt die Datenbank neu aus zwei CSV-Dateien. Vorherige Daten werden verworfen.
## Die Traits (load_traits) sollten vorher geladen sein.
func load_from_files(teams_path: String, players_path: String) -> void:
	_teams.clear()
	_teams_by_short.clear()
	_player_count = 0
	_ovr_checked = 0
	_ovr_matching = 0

	for row: Dictionary in _read_csv(teams_path, TEAM_COLUMNS):
		var team: Team = _team_from_row(row)
		if team != null:
			_teams.append(team)
			_teams_by_short[team.short] = team

	for row: Dictionary in _read_csv(players_path, PLAYER_COLUMNS):
		var player: Player = _player_from_row(row)
		if player == null:
			continue
		var team: Team = get_team(player.team_short)
		if team == null:
			push_warning("Database: Spieler '%s' gehört zu unbekanntem Team '%s', übersprungen."
					% [player.display_name(), player.team_short])
			continue
		team.players.append(player)
		_player_count += 1
		_check_player_traits(player)

	for team: Team in _teams:
		team.players.sort_custom(func(a: Player, b: Player) -> bool:
			return RiftSim.ROLES.find(a.role) < RiftSim.ROLES.find(b.role))
		_check_roster(team)

	print("Database: %d Teams, %d Spieler geladen." % [_teams.size(), _player_count])
	print("OVR-Check: %d/%d stimmen überein" % [_ovr_matching, _ovr_checked])


func _team_from_row(row: Dictionary) -> Team:
	var short: String = row.get("short", "")
	if short.is_empty():
		push_warning("Database: Team ohne Kürzel (Spalte short), übersprungen.")
		return null
	if _teams_by_short.has(short):
		push_warning("Database: Team-Kürzel '%s' ist doppelt, zweiter Eintrag übersprungen." % short)
		return null

	var team := Team.new()
	team.short = short
	team.name = row.get("name", short)
	team.league = row.get("league", "")
	team.tier = _to_int(row, "tier", short, 1)
	team.language = row.get("team_language", "en")
	team.chemistry = _to_float(row, "chem", short)

	var coach_name: String = row.get("coach_name", "")
	if not coach_name.is_empty():
		var coach := Coach.new()
		coach.name = coach_name
		coach.drafting = _to_int(row, "coach_dra", short)
		coach.development = _to_int(row, "coach_dev", short)
		coach.motivation = _to_int(row, "coach_mot", short)
		coach.tactics = _to_int(row, "coach_tac", short)
		coach.management = _to_int(row, "coach_man", short)
		team.coach = coach
	return team


func _player_from_row(row: Dictionary) -> Player:
	var player := Player.new()
	player.team_short = row.get("team_short", "")
	player.real_name = row.get("name", "")
	player.nickname = row.get("nickname", "")
	var label: String = "%s (%s)" % [player.display_name(), player.team_short]

	player.role = row.get("role", "").to_upper()
	if not RiftSim.ROLES.has(player.role):
		push_warning("Database: Spieler %s hat unbekannte Rolle '%s', übersprungen. Erlaubt: %s"
				% [label, player.role, ", ".join(PackedStringArray(RiftSim.ROLES))])
		return null

	player.age = _to_int(row, "age", label)
	player.gender = row.get("gender", "")
	player.languages = _split_list(row.get("language", ""))
	player.english = _to_float(row, "english", label)
	player.mechanics = _to_float(row, "mechanics", label)
	player.laning = _to_float(row, "laning", label)
	player.macro = _to_float(row, "macro", label)
	player.teamwork = _to_float(row, "teamwork", label)
	player.mental = _to_float(row, "mental", label)
	player.charisma = _to_int(row, "charisma", label)
	player.potential = _to_int(row, "potential", label)
	player.traits = _split_list(row.get("traits", ""))
	_check_overall(player, row, label)
	return player


## Vergleicht den berechneten Overall mit der CSV-Spalte ovr und zählt Treffer.
func _check_overall(player: Player, row: Dictionary, label: String) -> void:
	_ovr_checked += 1
	var csv_ovr: float = _to_float(row, "ovr", label)
	var calc_ovr: float = player.overall()
	if absf(calc_ovr - csv_ovr) > OVR_TOLERANCE:
		push_warning("Database: OVR von %s weicht ab: berechnet %.2f, CSV %.2f."
				% [label, calc_ovr, csv_ovr])
	else:
		_ovr_matching += 1


## Meldet, wenn ein Team nicht genau einen Spieler pro Rolle hat.
func _check_roster(team: Team) -> void:
	if team.players.size() != 5:
		push_warning("Database: Team %s hat %d statt 5 Spieler." % [team.short, team.players.size()])
	for role: String in RiftSim.ROLES:
		var count: int = 0
		for player: Player in team.players:
			if player.role == role:
				count += 1
		if count == 0:
			push_warning("Database: Team %s hat keinen Spieler auf %s." % [team.short, role])
		elif count > 1:
			push_warning("Database: Team %s hat %d Spieler auf %s." % [team.short, count, role])


# --- Hilfsfunktionen für Werte ----------------------------------------------

func _to_int(row: Dictionary, key: String, context: String, fallback: int = 0) -> int:
	var raw: String = row.get(key, "")
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return roundi(raw.to_float())
	push_warning("Database: %s: Wert '%s' in Spalte %s ist keine Zahl, nehme %d." % [context, raw, key, fallback])
	return fallback


func _to_float(row: Dictionary, key: String, context: String, fallback: float = 0.0) -> float:
	var raw: String = row.get(key, "")
	if raw.is_valid_float():
		return raw.to_float()
	push_warning("Database: %s: Wert '%s' in Spalte %s ist keine Zahl, nehme %s." % [context, raw, key, fallback])
	return fallback


## Teilt "Shotcaller;Mentor" in ["Shotcaller", "Mentor"]. Leere Einträge fallen weg.
func _split_list(raw: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for part: String in raw.split(";", false):
		var value: String = part.strip_edges()
		if not value.is_empty():
			result.append(value)
	return result


# --- CSV lesen --------------------------------------------------------------

## Liest eine CSV-Datei mit Kopfzeile. Jede Zeile wird ein Dictionary
## Spaltenname -> Text (Leerzeichen am Rand entfernt).
## Gibt bei Fehlern eine leere Liste zurück und meldet sie per push_warning.
func _read_csv(path: String, required_columns: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("Database: Datei fehlt: %s" % path)
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Database: Datei %s kann nicht geöffnet werden (Fehler %d)." % [path, FileAccess.get_open_error()])
		return result

	var text: String = file.get_as_text()
	if text.begins_with(char(0xFEFF)):  # BOM am Dateianfang entfernen
		text = text.substr(1)

	var rows: Array[PackedStringArray] = parse_csv_text(text)
	if rows.is_empty():
		push_warning("Database: Datei %s ist leer." % path)
		return result

	var header: PackedStringArray = []
	for column: String in rows[0]:
		header.append(column.strip_edges().to_lower())
	for column: String in required_columns:
		if not header.has(column):
			push_warning("Database: In %s fehlt die Spalte '%s'." % [path, column])

	for i: int in range(1, rows.size()):
		var cells: PackedStringArray = rows[i]
		if cells.size() == 1 and cells[0].strip_edges().is_empty():
			continue  # Leerzeile
		if cells.size() != header.size():
			push_warning("Database: %s, Zeile %d hat %d statt %d Felder, übersprungen."
					% [path, i + 1, cells.size(), header.size()])
			continue
		var row: Dictionary = {}
		for c: int in header.size():
			row[header[c]] = cells[c].strip_edges()
		result.append(row)
	return result


## Zerlegt CSV-Text in Zeilen und Felder. Unterstützt Felder in Anführungszeichen
## (mit Komma, Zeilenumbruch oder "" darin) und Zeilenenden \n oder \r\n.
static func parse_csv_text(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var row: PackedStringArray = []
	var field: String = ""
	var in_quotes: bool = false
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var c: String = text[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += c
		elif c == "\"":
			in_quotes = true
		elif c == ",":
			row.append(field)
			field = ""
		elif c == "\n" or c == "\r":
			if c == "\r" and i + 1 < n and text[i + 1] == "\n":
				i += 1
			row.append(field)
			rows.append(row)
			row = PackedStringArray()
			field = ""
		else:
			field += c
		i += 1
	if not field.is_empty() or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows
