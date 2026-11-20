class_name StandingsRow
extends TableRow
## Eine Zeile der Saison-Tabelle. Spalten (Breite, Titel, Ausrichtung) stehen in
## scenes/components/table/layouts/standings_columns.tres und gelten auch für die
## Kopfzeile. Klick auf die Zeile meldet das Team über das Signal "selected".

signal selected(team_short: String)

var _short: String = ""


## index: Position in der Tabelle ab 0 (für Zebra-Streifen).
## cut_below: Linie unter der Zeile (letzter Playoff-Platz).
func setup(index: int, t: SeasonTeam, is_selected: bool, cut_below: bool) -> void:
	_short = t.short()
	if not clicked.is_connected(_on_clicked):
		clicked.connect(_on_clicked)
	set_row_state(index, is_selected, cut_below)

	set_text(&"place", str(index + 1))
	set_text(&"team", t.team.name)
	set_text(&"group", t.group)
	set_text(&"record", "%d-%d" % [t.wins, t.losses])
	set_text(&"maps", "%d:%d" % [t.maps_won, t.maps_lost])
	set_text(&"last", " ".join(PackedStringArray(t.last.slice(-5))))
	if t.streak > 0:
		set_text(&"streak", "%dS" % t.streak)
	elif t.streak < 0:
		set_text(&"streak", "%dN" % -t.streak)
	else:
		set_text(&"streak", "–")

	var form_sum: float = 0.0
	var start_ovr_sum: float = 0.0
	for sp: SeasonPlayer in t.players:
		form_sum += sp.player.form
		start_ovr_sum += sp.start_ovr
	set_text(&"form", "%d" % roundi(form_sum / 5.0))
	set_text(&"chem", "%d" % roundi(t.team.chemistry))
	set_delta(&"chem", t.team.chemistry - t.chem_start, 0)
	var ovr: float = t.team.overall()
	set_text(&"ovr", "%.1f" % ovr)
	set_delta(&"ovr", ovr - start_ovr_sum / 5.0, 1)


func _on_clicked() -> void:
	selected.emit(_short)
