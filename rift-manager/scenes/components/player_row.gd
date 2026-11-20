class_name PlayerRow
extends HBoxContainer
## Eine Zeile der Spielerwerte in einem Spiel: Rolle, Name, K/D/A, KDA, Gold, Note.
## Spaltenbreiten im Editor über "Custom Minimum Size" der Labels einstellen;
## die Kopfzeile in game_panel.tscn sollte dieselben Breiten haben.

@onready var _role_label: Label = %RoleLabel
@onready var _name_label: Label = %NameLabel
@onready var _kda_line_label: Label = %KdaLineLabel
@onready var _kda_label: Label = %KdaLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _grade_label: Label = %GradeLabel


## Füllt die Zeile. Der MVP wird mit der Theme-Variante "GoldLabel" hervorgehoben.
func setup(rating: MatchResult.PlayerRating, is_mvp: bool) -> void:
	_role_label.text = rating.role
	_name_label.text = rating.name + (" · MVP" if is_mvp else "")
	if is_mvp:
		_name_label.theme_type_variation = &"GoldLabel"
	_kda_line_label.text = "%d/%d/%d" % [rating.kills, rating.deaths, rating.assists]
	_kda_label.text = "%.1f" % rating.kda
	_gold_label.text = "%.1fk" % (rating.gold / 1000.0)
	_grade_label.text = str(rating.grade)
