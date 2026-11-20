extends Control
## Testscreen: zeigt, was das Autoload "Database" geladen hat.
## Alle Ligen (nach Tier sortiert) mit ihren Teams, absteigend nach Overall.

@onready var _summary_label: Label = %SummaryLabel
@onready var _league_tree: Tree = %LeagueTree


func _ready() -> void:
	_print_rng_check()
	_print_match_check()
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
