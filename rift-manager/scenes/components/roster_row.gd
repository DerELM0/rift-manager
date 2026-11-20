@tool
class_name RosterRow
extends TableRow
## Eine Spielerzeile im Kader. Spalten stehen in
## scenes/components/table/layouts/roster_columns.tres und gelten auch für die
## Kopfzeile. Klick meldet den Spieler über das Signal "selected".
## @tool, weil die gemeinsame Tabellenzeile (TableRow) im Editor läuft. Im Editor
## baut nur die Basisklasse die Zellen auf; setup() wird dort nie ausgeführt.

signal selected(season_player: SeasonPlayer)

var _season_player: SeasonPlayer = null


## index: Position im Kader ab 0 (für Zebra-Streifen).
func setup(index: int, sp: SeasonPlayer, is_selected: bool) -> void:
	# Läuft nur im Spiel: Im Editor (@tool) keine Daten aus Season/Database anfassen.
	if Engine.is_editor_hint():
		return
	_season_player = sp
	if not clicked.is_connected(_on_clicked):
		clicked.connect(_on_clicked)
	set_row_state(index, is_selected)

	var p: Player = sp.player
	set_text(&"role", p.role)
	set_text(&"name", "%s  %d J." % [p.display_name(), p.age])
	set_text(&"ovr", "%.1f" % p.overall())
	set_delta(&"ovr", sp.ovr_gain(), 1)
	set_text(&"form", "%d" % roundi(p.form))
	set_text(&"games", str(sp.games))
	set_text(&"grade", ("%.1f" % sp.average_grade()) if sp.games > 0 else "–")
	# KDA wie im Web-Simulator: (Kills + Assists) / max(1, Tode); Tooltip zeigt die Summen
	var kda: float = float(sp.kills + sp.assists) / maxi(1, sp.deaths)
	set_text(&"kda", "%.1f" % kda)
	set_tooltip(&"kda", "K/D/A gesamt: %d / %d / %d" % [sp.kills, sp.deaths, sp.assists])
	set_text(&"mvps", str(sp.mvps))


func _on_clicked() -> void:
	selected.emit(_season_player)
