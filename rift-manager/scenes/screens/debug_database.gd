extends Control
## Testscreen: zeigt, was das Autoload "Database" geladen hat.
## Alle Ligen (nach Tier sortiert) mit ihren Teams, absteigend nach Overall.

@onready var _summary_label: Label = %SummaryLabel
@onready var _league_tree: Tree = %LeagueTree


func _ready() -> void:
	_print_rng_check()
	_print_match_check()
	_print_season_check()
	_summary_label.text = "%d Teams, %d Spieler geladen" % [
		Database.get_team_count(), Database.get_player_count()]

	_league_tree.set_column_title(0, "Team")
	_league_tree.set_column_title(1, "Overall")
	_league_tree.set_column_expand(1, false)
	_league_tree.set_column_custom_minimum_width(1, 100)

	var root: TreeItem = _league_tree.create_item()
	for league: String in Database.get_leagues():
		var teams: Array[Team] = Database.get_teams_in_league(league)
		teams.sort_custom(func(a: Team, b: Team) -> bool: return a.overall() > b.overall())

		var league_item: TreeItem = _league_tree.create_item(root)
		league_item.set_text(0, "%s  (Tier %d, %d Teams)" % [league, teams[0].tier, teams.size()])
		league_item.set_selectable(0, false)
		league_item.set_selectable(1, false)

		for team: Team in teams:
			var team_item: TreeItem = _league_tree.create_item(league_item)
			team_item.set_text(0, "%s – %s" % [team.short, team.name])
			team_item.set_text(1, "%.1f" % team.overall())
			team_item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)


## Gibt die ersten 5 Zufallszahlen für Seed 12345 aus, zum Vergleich mit
## RiftSim.makeRng(12345) im Web-Simulator.
func _print_rng_check() -> void:
	var rng: RiftSim.Rng = RiftSim.make_rng(12345)
	var numbers: PackedStringArray = []
	for _i: int in 5:
		numbers.append("%.17f" % rng.next_float())
	print("RNG Seed 12345: ", ", ".join(numbers))


## Vergleich der Match-Simulation mit Referenzwerten aus dem Web-Simulator
## (Node, consts = DEFAULTS). Jede Zeile zeigt Godot-Ergebnis und Erwartung.
func _print_match_check() -> void:
	var cases: Array = [
		["C7", "BYN", 1, "Sieger BYN, Dauer 35, Kills 12:17, MVP Zeph, Gold@14 2333"],
		["C7", "BYN", 42, "Sieger BYN, Dauer 34, Kills 19:19, MVP Crest, Gold@14 198"],
		["TAI", "DTS", 12345, "Sieger DTS, Dauer 34, Kills 7:14, MVP Gasi, Gold@14 -4077"],
	]
	for check: Array in cases:
		var team_a: Team = Database.get_team(check[0])
		var team_b: Team = Database.get_team(check[1])
		var result: MatchResult = MatchSim.simulate_game(team_a, team_b, {}, check[2])
		var got: String = result.summary() if result != null else "(nicht simuliert)"
		print("Match %s vs %s, Seed %d: %s  [%s]" % [check[0], check[1], check[2], got,
				"OK" if got == check[3] else "ABWEICHUNG, erwartet: " + check[3]])

	var c7: Team = Database.get_team("C7")
	var byn: Team = Database.get_team("BYN")
	var wins: int = 0
	for seed_value: int in 1000:
		if MatchSim.simulate_game(c7, byn, {}, seed_value).winner == "A":
			wins += 1
	print("Match C7 vs BYN, Seeds 0-999: C7 gewinnt %d/1000  [%s]" % [wins,
			"OK" if wins == 310 else "ABWEICHUNG, erwartet: 310/1000"])


## Vergleich des Saison-Loops mit Referenzwerten aus dem Web-Simulator
## (Node, consts = DEFAULTS). Kontrollspieler: Top-Laner des Tabellenersten,
## OVR und Form nach den Playoffs. Prüft danach, dass die Database unverändert ist.
func _print_season_check() -> void:
	var gasi: Player = Database.get_team("DTS").get_player("TOP")
	var gasi_ovr_before: float = gasi.overall()
	var gasi_form_before: float = gasi.form
	var dts_chem_before: float = Database.get_team("DTS").chemistry

	var checks: Array = [
		["LCK", "lck", 1, "Tabelle DTS 22-4, BYN 21-5, GSS 20-6 | Meister DTS | MVP Onyx | Wochen 14 | Gasi OVR 80.88, Form 87.82"],
		["LEC", "single3", 7, "Tabelle NRD 7-2, FJH 7-2, BOS 7-2 | Meister BOS | MVP Hailstorm | Wochen 5 | Kettle OVR 80.55, Form 69.77"],
		["LPL", "lpl", 42, "Tabelle HPT 11-3, TQP 10-4, LTD 8-6 | Meister LTD | MVP Lotus | Wochen 7 | Windmill OVR 82.17, Form 71.02"],
	]
	for check: Array in checks:
		var season: Season = Season.create(Database.get_teams_in_league(check[0]),
				{"seed": check[2], "preset": check[1], "bestOf": 3})
		while season.play_week():
			pass
		var table: Array[SeasonTeam] = season.standings()
		var top3: PackedStringArray = []
		for i: int in 3:
			top3.append("%s %d-%d" % [table[i].short(), table[i].wins, table[i].losses])
		season.start_playoffs()
		var awards: Season.Awards = season.awards()
		var top: Player = table[0].team.get_player("TOP")
		var got: String = "Tabelle %s | Meister %s | MVP %s | Wochen %d | %s OVR %.2f, Form %.2f" % [
			", ".join(top3), season.playoffs.champion, awards.mvp.player.display_name(),
			season.week, top.display_name(), top.overall(), top.form]
		print("Saison %s, preset %s, Seed %d: %s  [%s]" % [check[0], check[1], check[2], got,
				"OK" if got == check[3] else "ABWEICHUNG, erwartet: " + check[3]])

	var unchanged: bool = gasi.overall() == gasi_ovr_before and gasi.form == gasi_form_before \
			and Database.get_team("DTS").chemistry == dts_chem_before
	print("Database nach den Saisons: Gasi OVR %.2f (vorher %.2f), Form %.1f, DTS Chemistry %.1f  [%s]" % [
		gasi.overall(), gasi_ovr_before, gasi.form, Database.get_team("DTS").chemistry,
		"OK" if unchanged else "ABWEICHUNG, Database wurde verändert"])
