extends Control
## Testscreen: zeigt, was das Autoload "Database" geladen hat.
## Alle Ligen (nach Tier sortiert) mit ihren Teams, absteigend nach Overall.

@onready var _summary_label: Label = %SummaryLabel
@onready var _league_tree: Tree = %LeagueTree


func _ready() -> void:
	_print_rng_check()
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
