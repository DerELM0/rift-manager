class_name StandingsRow
extends VBoxContainer
## Eine Zeile der Tabelle. Optional mit Gruppen-Überschrift darüber
## (z. B. "Legend Group") und einer Linie darunter (letzter Playoff-Platz).
## Klick auf die Zeile meldet das Team über das Signal "selected".
## Spaltenbreiten: "Custom Minimum Size" der Labels; die Kopfzeile in
## season_screen.tscn (TableHeader) sollte dieselben Breiten haben.

signal selected(team_short: String)

@onready var _group_label: Label = %GroupLabel
@onready var _row_panel: PanelContainer = %RowPanel
@onready var _place_label: Label = %PlaceLabel
@onready var _team_label: Label = %TeamLabel
@onready var _group_column_label: Label = %GroupColumnLabel
@onready var _record_label: Label = %RecordLabel
@onready var _maps_label: Label = %MapsLabel
@onready var _last_label: Label = %LastLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _form_label: Label = %FormLabel
@onready var _chem_label: Label = %ChemLabel
@onready var _ovr_label: Label = %OvrLabel
@onready var _cut_line: HSeparator = %CutLine

var _short: String = ""


func setup(place: int, t: SeasonTeam, is_selected: bool, group_header: bool, cut_below: bool) -> void:
	_short = t.short()
	_group_label.visible = group_header
	_group_label.text = "%s Group" % t.group
	_cut_line.visible = cut_below
	_row_panel.theme_type_variation = &"TableRowSelected" if is_selected else &"TableRow"

	_place_label.text = str(place)
	_team_label.text = t.team.name
	_group_column_label.text = t.group
	_record_label.text = "%d-%d" % [t.wins, t.losses]
	_maps_label.text = "%d:%d" % [t.maps_won, t.maps_lost]
	_last_label.text = " ".join(PackedStringArray(t.last.slice(-5)))
	if t.streak > 0:
		_streak_label.text = "%dS" % t.streak
	elif t.streak < 0:
		_streak_label.text = "%dN" % -t.streak
	else:
		_streak_label.text = "–"

	var form_sum: float = 0.0
	var start_ovr_sum: float = 0.0
	for sp: SeasonPlayer in t.players:
		form_sum += sp.player.form
		start_ovr_sum += sp.start_ovr
	_form_label.text = "%d" % roundi(form_sum / 5.0)
	_chem_label.text = "%d (%s)" % [roundi(t.team.chemistry), SeasonFormat.delta(t.team.chemistry - t.chem_start, 0)]
	var ovr: float = t.team.overall()
	_ovr_label.text = "%.1f (%s)" % [ovr, SeasonFormat.delta(ovr - start_ovr_sum / 5.0, 1)]


func _on_row_panel_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_short)
