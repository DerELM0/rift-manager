class_name RosterRow
extends PanelContainer
## Eine Spielerzeile im Kader: Rolle, Name und Alter, OVR mit Veränderung,
## Form, Spiele, Ø-Note, K/D/A, MVPs. Klick meldet den Spieler über "selected".

signal selected(season_player: SeasonPlayer)

@onready var _role_label: Label = %RoleLabel
@onready var _name_label: Label = %NameLabel
@onready var _ovr_label: Label = %OvrLabel
@onready var _ovr_delta_label: Label = %OvrDeltaLabel
@onready var _form_label: Label = %FormLabel
@onready var _games_label: Label = %GamesLabel
@onready var _grade_label: Label = %GradeLabel
@onready var _kda_label: Label = %KdaLabel
@onready var _mvp_label: Label = %MvpLabel

var _season_player: SeasonPlayer = null


func setup(sp: SeasonPlayer, is_selected: bool) -> void:
	_season_player = sp
	var p: Player = sp.player
	theme_type_variation = &"TableRowSelected" if is_selected else &"TableRow"
	_role_label.text = p.role
	_name_label.text = "%s  %d J." % [p.display_name(), p.age]
	_ovr_label.text = "%.1f" % p.overall()
	SeasonFormat.apply_delta(_ovr_delta_label, sp.ovr_gain(), 1)
	_form_label.text = "%d" % roundi(p.form)
	_games_label.text = str(sp.games)
	_grade_label.text = ("%.1f" % sp.average_grade()) if sp.games > 0 else "–"
	_kda_label.text = "%d/%d/%d" % [sp.kills, sp.deaths, sp.assists]
	_mvp_label.text = str(sp.mvps)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_season_player)
