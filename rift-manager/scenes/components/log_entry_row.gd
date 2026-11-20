class_name LogEntryRow
extends HBoxContainer
## Eine Zeile im Spielverlauf: farbiger Balken (Seite), Minute, Text.
## Farben kommen aus dem Theme: Balken = Schriftfarbe von "TeamALabel" bzw.
## "TeamBLabel", wichtige Ereignisse (Baron, Elder, Nexus) nutzen "LogEmphasisLabel".

@onready var _side_bar: ColorRect = %SideBar
@onready var _minute_label: Label = %MinuteLabel
@onready var _text_label: Label = %TextLabel


func setup(entry: MatchResult.LogEntry) -> void:
	_minute_label.text = "%d'" % entry.minute
	_text_label.text = entry.text
	if entry.side == "A":
		_side_bar.color = get_theme_color("font_color", "TeamALabel")
	elif entry.side == "B":
		_side_bar.color = get_theme_color("font_color", "TeamBLabel")
	if entry.kind == "big" or entry.kind == "end":
		_text_label.theme_type_variation = &"LogEmphasisLabel"
