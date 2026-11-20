class_name Season
extends RefCounted
## Saison-Loop, 1:1 portiert aus web-sim/season.js.
## Kennt keine Szenen oder Nodes.
##
## Ablauf:
##   var season: Season = Season.create(Database.get_teams_in_league("LCK"),
##           {"seed": 1, "preset": "lck", "bestOf": 3})
##   while season.play_week():
##       pass
##   var table: Array[SeasonTeam] = season.standings()
##   season.start_playoffs()
##   var awards: Season.Awards = season.awards()
##
## Die Saison arbeitet auf Kopien der Teams und Spieler (SeasonTeam.team).
## Die Daten in der Database bleiben unverändert.
##
## Gleicher Seed ergibt exakt dieselbe Saison wie im Web-Simulator. Die Reihenfolge
## der Zufallszahlen, die stabile Sortierung und das Runden folgen dem Original.
## Wer hier etwas umstellt, ändert alle Ergebnisse.
##
## Optionen (opt), wie im Original:
##   "seed": int        Startwert für alle Zufallszahlen der Saison.
##   "preset": String   Format: "lck", "lpl", "single3", "single1" oder "double1"
##                      (siehe PRESETS). Unbekannt = einfache Runde.
##   "bestOf": int      Spiele pro Serie in der regulären Saison (1, 3, 5).
##   "consts": Dictionary  Überschreibt einzelne Werte aus RiftSim.DEFAULTS.

## Trainingsschwerpunkt je Rolle: Index des Stats, der voll trainiert wird
## (0 Mechanics, 1 Laning, 2 Macro, 3 Teamwork). Die anderen bekommen 30 %.
const FOCUS: Dictionary = {"TOP": 1, "JGL": 2, "MID": 0, "ADC": 0, "SUP": 3}

## Formate nach den echten Ligen 2026 (vereinfacht: Playoffs als Top-6-Bracket).
## Je Liga eine Liste möglicher Formate. bestOf ist nur ein Vorschlag für opt["bestOf"].
const PRESETS: Dictionary = {
	"LCK": [{"id": "lck", "name": "Saison, Runden 1–4 (Bo3)",
		"note": "Runden 1–2: doppelte Runde aller 10 Teams. Runden 3–4: Legend Group (Platz 1–5) und Rise Group (Platz 6–10) spielen getrennt eine doppelte Runde, die Bilanz läuft weiter. Alles Bo3.",
		"bestOf": 3}],  # im Original erst 1, direkt danach auf 3 gesetzt
	"LPL": [{"id": "lpl", "name": "Split mit Ascend und Nirvana (Bo3)",
		"note": "Die 8 stärksten Teams bilden die Ascend Group, die übrigen die Nirvana Group. Beide spielen eine doppelte Runde im Bo3. Die Top 6 der Ascend Group erreichen die Playoffs.",
		"bestOf": 3}],
	"LEC": [
		{"id": "single3", "name": "Spring/Summer: einfache Runde, Bo3", "note": "Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.", "bestOf": 3},
		{"id": "single1", "name": "Versus: einfache Runde, Bo1", "note": "Einfache Runde im Bo1, die Top 6 erreichen die Playoffs.", "bestOf": 1},
	],
	"LCS": [{"id": "single3", "name": "Spring/Summer: einfache Runde, Bo3", "note": "Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.", "bestOf": 3}],
	"CBLOL": [
		{"id": "single3", "name": "Split 1/2: einfache Runde, Bo3", "note": "Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.", "bestOf": 3},
		{"id": "single1", "name": "CBLOL Cup: einfache Runde, Bo1", "note": "Einfache Runde im Bo1, die Top 6 erreichen die Playoffs.", "bestOf": 1},
	],
	"LCP": [{"id": "single3", "name": "Split 1/2: einfache Runde, Bo3", "note": "Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.", "bestOf": 3}],
}


## Eine gespielte Serie (Rückgabe von playSeries im Original).
class Series extends RefCounted:
	## Kürzel der beiden Teams; a ist Team A in der Simulation.
	var a: String = ""
	var b: String = ""
	var best_of: int = 1
	## Gewonnene Maps von a und b.
	var wins_a: int = 0
	var wins_b: int = 0
	var games: Array[MatchResult] = []
	## Kürzel des Siegers.
	var winner: String = ""


## Eine gespielte Woche (Eintrag in results).
class Week extends RefCounted:
	## Wochennummer, beginnt bei 1.
	var number: int = 0
	## Spieltage der Woche, jeder mit seinen Serien.
	var days: Array[Array] = []
	## 1 = reguläre Saison, 2 = LCK Runden 3–4.
	var phase: int = 1


## Eine Playoff-Runde.
class PlayoffRound extends RefCounted:
	## "Viertelfinale", "Halbfinale" oder "Finale".
	var name: String = ""
	var series: Array[Series] = []


## Die Playoffs (Top-6-Bracket).
## Namen der Playoff-Runden in Spielreihenfolge.
const PLAYOFF_ROUND_NAMES: Array[String] = ["Viertelfinale", "Halbfinale", "Finale"]


class Playoffs extends RefCounted:
	## Kürzel der 6 gesetzten Teams, Platz 1 zuerst.
	var seeds: Array[String] = []
	var rounds: Array[PlayoffRound] = []
	## Kürzel des Meisters.
	var champion: String = ""


## Saisonauszeichnungen. Jeder Eintrag ist ein SeasonPlayer (oder null, wenn
## es keinen passenden Spieler gibt). Das Team dazu: team_of(player).
class Awards extends RefCounted:
	## Meiste MVP-Auszeichnungen, bei Gleichstand beste Durchschnittsnote.
	var mvp: SeasonPlayer = null
	## Bester Spieler je Rolle (Durchschnittsnote), Reihenfolge TOP bis SUP.
	var all_pro: Array[SeasonPlayer] = []
	## Bester Spieler mit höchstens 19 Jahren.
	var rookie: SeasonPlayer = null
	## Größter Overall-Zuwachs seit Saisonbeginn.
	var improved: SeasonPlayer = null
	## Overall-Zuwachs von improved.
	var improved_gain: float = 0.0


var opt: Dictionary = {}
## Alle Teams der Saison (Kopien), in der Reihenfolge, in der sie übergeben wurden.
var teams: Array[SeasonTeam] = []
## Spielplan: je Woche eine Liste von Spieltagen, je Spieltag eine Liste von
## Paarungen [kürzel_a, kürzel_b].
var weeks: Array = []
## Anzahl gespielter Wochen (= Index der nächsten Woche).
var week: int = 0
var results: Array[Week] = []
var playoffs: Playoffs = null
## true, sobald die Playoffs gespielt sind.
var done: bool = false
## 1 = reguläre Saison, 2 = LCK Runden 3–4.
var phase: int = 1
## LCK: Phase 2 (Legend/Rise Group) wird nach Phase 1 noch angesetzt.
var phase2_pending: bool = false

var _c: Dictionary = {}
var _rng: RiftSim.Rng = null
## Zähler für die Seeds der Serien (seedCtr im Original).
var _seed_ctr: int = 0
var _by_short: Dictionary = {}


# --- Saison anlegen ---------------------------------------------------------

## Legt eine Saison an (create im Original). teams wird nur gelesen.
static func create(source_teams: Array[Team], options: Dictionary) -> Season:
	var st := Season.new()
	st.opt = options
	st._c = RiftSim.merge_consts(options.get("consts", {}))
	var seed_value: int = int(options.get("seed", 0)) & 0xFFFFFFFF
	st._rng = RiftSim.make_rng(seed_value)
	for source: Team in source_teams:
		var t := SeasonTeam.new(source, st._c["formCenter"])
		st.teams.append(t)
		st._by_short[t.short()] = t
	var shorts: Array[String] = []
	for t: SeasonTeam in st.teams:
		shorts.append(t.short())
	var ids: Array[String] = st._shuffle(shorts)
	st._seed_ctr = seed_value * 1000 + 1

	var preset: String = str(options.get("preset", ""))
	if preset == "lck":
		st.weeks = _to_weeks(_double(_round_robin(ids)))
		st.phase2_pending = true
	elif preset == "lpl":
		var by_ovr: Array = RiftSim.stable_sort(st.teams, func(x: SeasonTeam, y: SeasonTeam) -> bool:
			return x.team.overall() > y.team.overall())
		var ascend: Array[String] = []
		var nirvana: Array[String] = []
		for i: int in by_ovr.size():
			var t: SeasonTeam = by_ovr[i]
			t.group = "Ascend" if i < 8 else "Nirvana"
			if i < 8:
				ascend.append(t.short())
			else:
				nirvana.append(t.short())
		var rounds_ascend: Array = _double(_round_robin(st._shuffle(ascend)))
		var rounds_nirvana: Array = _double(_round_robin(st._shuffle(nirvana)))
		st.weeks = _to_weeks(_merge([rounds_ascend, rounds_nirvana]))
	elif preset == "double1":
		st.weeks = _to_weeks(_double(_round_robin(ids)))
	else:
		st.weeks = _to_weeks(_round_robin(ids))
	return st


# --- Öffentliche Funktionen -------------------------------------------------

## Spielt die nächste Woche (playWeek). Gibt false zurück, wenn die reguläre
## Saison vorbei ist. Bei der LCK wird nach Phase 1 automatisch Phase 2 angesetzt.
func play_week() -> bool:
	if week >= weeks.size():
		if phase2_pending:
			_start_phase2()
		else:
			return false
	var best_of: int = int(opt.get("bestOf", 1))
	var result := Week.new()
	result.number = week + 1
	result.phase = phase
	for round_pairs: Array in weeks[week]:
		var day: Array[Series] = []
		for pair: Array in round_pairs:
			var a: String = pair[0]
			var b: String = pair[1]
			var r: Series = _play_series(a, b, best_of, false)
			var w_team: SeasonTeam = get_team(r.winner)
			var l_team: SeasonTeam = get_team(b if r.winner == a else a)
			w_team.wins += 1
			l_team.losses += 1
			w_team.last.append("S")
			l_team.last.append("N")
			var team_a: SeasonTeam = get_team(a)
			var team_b: SeasonTeam = get_team(b)
			team_a.maps_won += r.wins_a
			team_a.maps_lost += r.wins_b
			team_b.maps_won += r.wins_b
			team_b.maps_lost += r.wins_a
			day.append(r)
		result.days.append(day)
	_weekly_development()
	results.append(result)
	week += 1
	return true


## Tabelle (standings): erst Gruppe (obere vor unterer), dann Siege,
## dann Map-Differenz, dann Team-Overall. Bei Gleichstand bleibt die Reihenfolge.
func standings() -> Array[SeasonTeam]:
	var sorted: Array = RiftSim.stable_sort(teams, func(x: SeasonTeam, y: SeasonTeam) -> bool:
		return _standings_compare(x, y) < 0)
	var result: Array[SeasonTeam] = []
	result.assign(sorted)
	return result


## Spielt die Playoffs komplett (startPlayoffs im Original): Top 6 der Tabelle, Bo5.
## Viertelfinale 3–6 und 4–5, Halbfinale gegen 1 und 2, dann Finale.
## Wurden schon Runden gespielt, werden nur die restlichen gespielt.
func start_playoffs() -> void:
	play_remaining_playoffs()


## Spielt alle noch offenen Playoff-Runden.
func play_remaining_playoffs() -> void:
	while play_playoff_round():
		pass


## Spielt die nächste Playoff-Runde (Viertelfinale, Halbfinale, Finale).
## Gibt false zurück, wenn nichts mehr zu spielen ist (reguläre Saison läuft noch
## oder Playoffs fertig).
##
## Rundenweise oder am Stück: Die Serien werden in genau derselben Reihenfolge
## gespielt wie im Original (VF 3–6, VF 4–5, HF 1, HF 2, Finale), und die
## Playoffs verbrauchen nur die Serien-Seeds (_seed_ctr), keine anderen
## Zufallszahlen. Dazwischen ändert sich nichts an Teams oder Seeds. Deshalb ist
## das Ergebnis bei gleichem Seed exakt gleich.
func play_playoff_round() -> bool:
	if done or not regular_done():
		return false
	if playoffs == null:
		# Seeds erst aus der Tabelle holen, DANN das Playoffs-Objekt anlegen:
		# playoff_seeds() liefert die gespeicherten Seeds, sobald playoffs existiert.
		var table_seeds: Array[String] = playoff_seeds()
		playoffs = Playoffs.new()
		playoffs.seeds = table_seeds
	var seeds: Array[String] = playoffs.seeds
	match playoffs.rounds.size():
		0:
			var qf: Array[Series] = [
				_play_series(seeds[2], seeds[5], 5, true),
				_play_series(seeds[3], seeds[4], 5, true),
			]
			playoffs.rounds.append(_playoff_round(PLAYOFF_ROUND_NAMES[0], qf))
		1:
			var qf_winners: Array[String] = semifinal_opponents()
			var sf: Array[Series] = [
				_play_series(seeds[0], qf_winners[1], 5, true),
				_play_series(seeds[1], qf_winners[0], 5, true),
			]
			playoffs.rounds.append(_playoff_round(PLAYOFF_ROUND_NAMES[1], sf))
		2:
			var sf: Array[Series] = playoffs.rounds[1].series
			var final_series: Series = _play_series(sf[0].winner, sf[1].winner, 5, true)
			var finals: Array[Series] = [final_series]
			playoffs.rounds.append(_playoff_round(PLAYOFF_ROUND_NAMES[2], finals))
			playoffs.champion = final_series.winner
			done = true
	return true


## Die 6 Playoff-Teams (Kürzel), Platz 1 zuerst. Vor dem ersten Playoff-Spiel aus
## der Tabelle, danach die festgelegten Seeds.
func playoff_seeds() -> Array[String]:
	if playoffs != null:
		return playoffs.seeds
	var seeds: Array[String] = []
	var table: Array[SeasonTeam] = standings()
	for i: int in mini(6, table.size()):
		seeds.append(table[i].short())
	return seeds


## Index der nächsten Playoff-Runde (0 Viertelfinale, 1 Halbfinale, 2 Finale)
## oder -1, wenn keine Runde ansteht.
func next_playoff_round() -> int:
	if done or not regular_done():
		return -1
	return 0 if playoffs == null else playoffs.rounds.size()


## Viertelfinal-Sieger nach Setzplatz sortiert (besser gesetzter zuerst).
## Der schwächer gesetzte spielt im Halbfinale gegen Platz 1, der andere gegen
## Platz 2. Leer, solange das Viertelfinale nicht gespielt ist.
func semifinal_opponents() -> Array[String]:
	var result: Array[String] = []
	if playoffs == null or playoffs.rounds.is_empty():
		return result
	var seeds: Array[String] = playoffs.seeds
	var qf: Array[Series] = playoffs.rounds[0].series
	var sorted: Array = RiftSim.stable_sort([qf[0].winner, qf[1].winner], func(x: String, y: String) -> bool:
		return seeds.find(x) < seeds.find(y))
	result.assign(sorted)
	return result


## Saisonauszeichnungen (awards). Berücksichtigt werden Spieler mit mindestens
## halb so vielen Spielen wie der Spieler mit den meisten Spielen.
func awards() -> Awards:
	var all: Array[SeasonPlayer] = []
	for t: SeasonTeam in teams:
		all.append_array(t.players)
	var max_games: int = 0
	for sp: SeasonPlayer in all:
		max_games = maxi(max_games, sp.games)
	var min_games: int = maxi(1, floori(max_games * 0.5))
	var eligible: Array[SeasonPlayer] = []
	for sp: SeasonPlayer in all:
		if sp.games >= min_games:
			eligible.append(sp)

	var result := Awards.new()
	var by_mvps: Array = RiftSim.stable_sort(eligible, func(x: SeasonPlayer, y: SeasonPlayer) -> bool:
		if x.mvps != y.mvps:
			return x.mvps > y.mvps
		return x.average_grade() > y.average_grade())
	result.mvp = by_mvps[0] if not by_mvps.is_empty() else null
	for role: String in RiftSim.ROLES:
		result.all_pro.append(_best_average(eligible.filter(func(sp: SeasonPlayer) -> bool:
			return sp.player.role == role)))
	result.rookie = _best_average(eligible.filter(func(sp: SeasonPlayer) -> bool:
		return sp.player.age <= 19))
	var by_gain: Array = RiftSim.stable_sort(all, func(x: SeasonPlayer, y: SeasonPlayer) -> bool:
		return x.ovr_gain() > y.ovr_gain())
	if not by_gain.is_empty():
		result.improved = by_gain[0]
		result.improved_gain = result.improved.ovr_gain()
	return result


## Team nach Kürzel, oder null.
func get_team(short: String) -> SeasonTeam:
	return _by_short.get(short, null)


## Das Team, zu dem ein Saisonspieler gehört.
func team_of(season_player: SeasonPlayer) -> SeasonTeam:
	for t: SeasonTeam in teams:
		if t.players.has(season_player):
			return t
	return null


## Gesamtzahl der Wochen; bei der LCK vor Phase 2 inklusive der 4 noch kommenden.
func total_weeks() -> int:
	return weeks.size() + (4 if phase2_pending else 0)


## true, wenn die reguläre Saison vorbei ist.
func regular_done() -> bool:
	return week >= weeks.size() and not phase2_pending


# --- Spielplan --------------------------------------------------------------

## Mischt eine Liste mit dem Saison-Zufall (shuffle im Original).
func _shuffle(items: Array[String]) -> Array[String]:
	var keyed: Array = []
	for item: String in items:
		keyed.append([_rng.next_float(), item])
	keyed = RiftSim.stable_sort(keyed, func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var result: Array[String] = []
	for entry: Array in keyed:
		result.append(entry[1])
	return result


## Jeder gegen jeden, eine Runde pro Spieltag (Rundenturnier, roundRobin).
## Bei ungerader Teamzahl hat pro Spieltag ein Team frei.
static func _round_robin(ids: Array[String]) -> Array:
	var t: Array[String] = ids.duplicate()
	if t.size() % 2 == 1:
		t.append("")  # "" = spielfrei
	var n: int = t.size()
	var rounds: Array = []
	for r: int in n - 1:
		var pairs: Array = []
		for i: int in n >> 1:  # n ist gerade, also n / 2
			var a: String = t[i]
			var b: String = t[n - 1 - i]
			if not a.is_empty() and not b.is_empty():
				pairs.append([b, a] if r % 2 == 1 else [a, b])
		rounds.append(pairs)
		t.insert(1, t.pop_back())
	return rounds


## Hin- und Rückrunde: alle Spieltage noch einmal mit getauschten Seiten (dbl).
static func _double(rounds: Array) -> Array:
	var result: Array = rounds.duplicate()
	for pairs: Array in rounds:
		var swapped: Array = []
		for pair: Array in pairs:
			swapped.append([pair[1], pair[0]])
		result.append(swapped)
	return result


## Mehrere Gruppen parallel: Spieltag i aller Gruppen zu einem Spieltag (merge).
static func _merge(lists: Array) -> Array:
	var n: int = 0
	for list: Array in lists:
		n = maxi(n, list.size())
	var out: Array = []
	for i: int in n:
		var day: Array = []
		for list: Array in lists:
			if i < list.size():
				day.append_array(list[i])
		out.append(day)
	return out


## Fasst je 2 Spieltage zu einer Woche zusammen (toWeeks).
static func _to_weeks(rounds: Array, per_week: int = 2) -> Array:
	var result: Array = []
	for i: int in range(0, rounds.size(), per_week):
		result.append(rounds.slice(i, i + per_week))
	return result


## LCK Runden 3–4: Platz 1–5 bilden die Legend Group, der Rest die Rise Group.
func _start_phase2() -> void:
	var table: Array[SeasonTeam] = standings()
	var legend: Array[String] = []
	var rise: Array[String] = []
	for i: int in table.size():
		table[i].group = "Legend" if i < 5 else "Rise"
		if i < 5:
			legend.append(table[i].short())
		else:
			rise.append(table[i].short())
	var rounds: Array = _merge([_double(_round_robin(legend)), _double(_round_robin(rise))])
	weeks.append_array(_to_weeks(rounds))
	phase = 2
	phase2_pending = false


func _playoff_round(round_name: String, series: Array[Series]) -> PlayoffRound:
	var r := PlayoffRound.new()
	r.name = round_name
	r.series = series
	return r


# --- Serien, Form und Moral -------------------------------------------------

## Spielt eine Serie und wendet Form, Statistik und Moral an (playSeries).
func _play_series(a: String, b: String, best_of: int, pressure: bool) -> Series:
	var team_a: SeasonTeam = get_team(a)
	var team_b: SeasonTeam = get_team(b)
	_seed_ctr += 7919
	var res: SeriesResult = MatchSim.simulate_series(team_a.team, team_b.team, best_of,
			{"pressure": pressure, "consts": opt.get("consts", {})}, _seed_ctr & 0xFFFFFFFF)
	for game: MatchResult in res.games:
		_apply_game(team_a, team_b, game)
	var winner: String = a if res.wins_a > res.wins_b else b
	_series_morale(get_team(winner), get_team(b if winner == a else a))
	var s := Series.new()
	s.a = a
	s.b = b
	s.best_of = best_of
	s.wins_a = res.wins_a
	s.wins_b = res.wins_b
	s.games = res.games
	s.winner = winner
	return s


## Wirkung eines Spiels auf Form und Statistik der Spieler (applyGame).
## Die Spielnote zieht die Form mit; ein motivierender Coach dämpft Einbrüche.
func _apply_game(team_a: SeasonTeam, team_b: SeasonTeam, game: MatchResult) -> void:
	for side: String in ["A", "B"]:
		var t: SeasonTeam = team_a if side == "A" else team_b
		var mot: int = t.team.coach.motivation if t.team.coach != null else 30
		for r: MatchResult.PlayerRating in game.ratings[side]:
			var sp: SeasonPlayer = t.record_of(r.player)
			var p: Player = sp.player
			var target: float = _c["formCenter"] + _c["formAmp"] * (r.grade - _c["formCenter"])
			if target < p.form:
				target = p.form - (p.form - target) * (1 - 0.4 * mot / 100.0)
			p.form = clampf((1 - _c["formWeight"]) * p.form + _c["formWeight"] * target, 25.0, 99.0)
			sp.games += 1
			sp.grade_sum += r.grade
			sp.kills += r.kills
			sp.deaths += r.deaths
			sp.assists += r.assists
			sp.gold += r.gold
			sp.grades.append(r.grade)
			if r.name == game.mvp:
				sp.mvps += 1


## Moral nach einer Serie (seriesMorale): Sieg hebt die Form, Niederlage drückt sie,
## Serien verstärken das. Niederlagen kosten Chemistry, Man-Management fängt das ab.
func _series_morale(w_team: SeasonTeam, l_team: SeasonTeam) -> void:
	w_team.streak = w_team.streak + 1 if w_team.streak > 0 else 1
	l_team.streak = l_team.streak - 1 if l_team.streak < 0 else -1
	for p: Player in w_team.team.players:
		p.form = clampf(p.form + _c["morale"] + (1 if w_team.streak >= 3 else 0), 25.0, 99.0)
	for p: Player in l_team.team.players:
		p.form = clampf(p.form - _c["morale"] - (1 if l_team.streak <= -3 else 0), 25.0, 99.0)
	var man_l: int = l_team.team.coach.management if l_team.team.coach != null else 30
	var chem_l: float = l_team.team.chemistry
	# unter 50 Chemistry bröckelt es langsamer
	l_team.team.chemistry = clampf(chem_l - _c["chemLoss"] * (1 - 0.4 * man_l / 100.0)
			* (1.3 if l_team.streak <= -3 else 1.0) * minf(1.0, chem_l / 50.0), 15.0, 100.0)
	w_team.team.chemistry = clampf(w_team.team.chemistry + _c["chemWin"], 0.0, 100.0)


# --- Training und Entwicklung -----------------------------------------------

## Altersfaktor fürs Training (AGEF): junge Spieler entwickeln sich schneller.
static func _age_factor(age: int) -> float:
	if age <= 19:
		return 1.3
	if age <= 22:
		return 1.0
	if age <= 25:
		return 0.6
	if age <= 28:
		return 0.2
	return 0.1


## Wöchentliche Entwicklung aller Teams (weeklyDevelopment): Training,
## zufällige Formschwankung, Chemistry-Wachstum und Englisch-Lernen.
func _weekly_development() -> void:
	for t: SeasonTeam in teams:
		var coach: Coach = t.team.coach if t.team.coach != null else Coach.fallback()
		var mdev: float = 0.6 + 0.8 * coach.development / 100.0
		var mentor: bool = false
		for p: Player in t.team.players:
			if p.has_trait("Mentor") and p.age >= 24:
				mentor = true
		for sp: SeasonPlayer in t.players:
			var p: Player = sp.player
			var ovr: float = p.overall()
			var boost: float = 1.0
			if mentor and p.age <= 21:
				boost += 0.15
			if p.has_trait("Grinder"):
				boost += 0.10
			if p.has_trait("Faul"):
				boost -= 0.20
			if p.has_trait("Perfektionist"):
				boost += 0.15
			boost *= 1 + (p.form - _c["formCenter"]) / 60.0  # gute Form trainiert besser
			var age: int = p.age
			if p.has_trait("Late Bloomer") and age <= 25:
				age = mini(age, 22)
			var d: float = _c["trainBase"] * _age_factor(age) * mdev * boost * maxf(0.0, (p.potential - ovr) / 20.0)
			# Wochenschwankung: Tagesform im Training, Selbstvertrauen, kleine Rückschläge
			var old: Array[float] = p.stats()
			var new_stats: Array[float] = []
			for i: int in old.size():
				var gain: float = d if i == FOCUS[p.role] else 0.3 * d
				new_stats.append(clampf(old[i] + gain + _rng.gauss() * _c["statNoise"], 20.0, 99.0))
			p.mechanics = new_stats[0]
			p.laning = new_stats[1]
			p.macro = new_stats[2]
			p.teamwork = new_stats[3]
			p.mental = new_stats[4]
			# Form driftet zufällig: kleine Krisen und Höhenflüge
			p.form = clampf(p.form + _rng.gauss() * _c["formDrift"], 25.0, 99.0)
			sp.history.append({"week": week + 1, "form": p.form, "ovr": p.overall()})

		# Chemistry wächst über alle Spielerpaare
		var ps: Array[Player] = t.team.players
		var total: float = 0.0
		var n: int = 0
		for i: int in 5:
			for j: int in range(i + 1, 5):
				var a: Player = ps[i]
				var b: Player = ps[j]
				var shared: bool = false
				for lang: String in a.languages:
					if b.languages.has(lang):
						shared = true
						break
				var kmin: float = 100.0 if shared else minf(RiftSim.comm_k(a, t.team.language), RiftSim.comm_k(b, t.team.language))
				var l: float = 0.5 + 0.5 * kmin / 100.0
				var f: float = 1.0
				for p: Player in [a, b]:
					if p.has_trait("Teamplayer"):
						f *= 1.3
					if p.has_trait("Lone Wolf"):
						f *= 0.5
					if p.has_trait("Arrogant"):
						f *= 0.8
				total += _c["chemGrowth"] * (0.5 + (a.charisma + b.charisma) / 200.0) * l \
						* (0.8 + 0.4 * coach.management / 100.0) * f
				n += 1
		var chem: float = t.team.chemistry
		t.team.chemistry = clampf(chem + total / n * (1 - chem / 110.0), 0.0, 100.0)

		# Englisch lernen, wenn die Teamsprache Englisch ist
		for p: Player in t.team.players:
			if not p.languages.has(t.team.language) and t.team.language == "en":
				p.english = minf(100.0, p.english + (2.5 if p.age <= 21 else 1.5) * (2 if p.has_trait("Sprachtalent") else 1))


# --- Hilfsfunktionen --------------------------------------------------------

## Vergleich für die Tabelle wie im Original: negativ = x steht vor y.
func _standings_compare(x: SeasonTeam, y: SeasonTeam) -> float:
	var by_group: int = x.group_rank() - y.group_rank()
	if by_group != 0:
		return by_group
	var by_wins: int = y.wins - x.wins
	if by_wins != 0:
		return by_wins
	var by_maps: int = (y.maps_won - y.maps_lost) - (x.maps_won - x.maps_lost)
	if by_maps != 0:
		return by_maps
	return y.team.overall() - x.team.overall()


## Spieler mit der besten Durchschnittsnote; bei Gleichstand der erste.
static func _best_average(candidates: Array) -> SeasonPlayer:
	var best: SeasonPlayer = null
	for sp: SeasonPlayer in candidates:
		if best == null or sp.average_grade() > best.average_grade():
			best = sp
	return best
