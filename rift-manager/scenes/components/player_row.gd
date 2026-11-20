class_name PlayerRow
extends TableRow
## Eine Zeile der Spielerwerte in einem Spiel: Rolle, Name, K/D/A, KDA, Gold, Note.
## Spalten stehen in scenes/components/table/layouts/match_ratings_columns.tres
## und gelten auch für die Kopfzeilen in game_panel.tscn.


## Füllt die Zeile. index: Position ab 0 (Zebra). Der MVP wird mit der
## Theme-Variante "GoldLabel" hervorgehoben.
func setup(rating: MatchResult.PlayerRating, is_mvp: bool, index: int = 0) -> void:
	set_row_state(index)
	set_text(&"role", rating.role)
	set_text(&"name", rating.name + (" · MVP" if is_mvp else ""))
	if is_mvp:
		set_cell_variation(&"name", &"GoldLabel")
	set_text(&"kda_line", "%d / %d / %d" % [rating.kills, rating.deaths, rating.assists])
	set_text(&"kda", "%.1f" % rating.kda)
	set_text(&"gold", "%.1fk" % (rating.gold / 1000.0))
	set_text(&"grade", str(rating.grade))
