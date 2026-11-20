extends PanelContainer
## Hauptszene: Navigationsleiste oben, darunter der gewählte Bildschirm.
## Die Bildschirme sind im Editor unter ScreenArea eingehängt und bleiben die
## ganze Zeit bestehen; umgeschaltet wird nur die Sichtbarkeit. So bleibt z. B.
## eine laufende Saison erhalten, wenn man kurz zum Match wechselt.
##
## Neuer Bildschirm: Szene unter ScreenArea einhängen (Layout auf "Full Rect"),
## Button in NavRow mit derselben ButtonGroup anlegen und hier in _screens()
## und einer _on_..._pressed-Funktion ergänzen.

@onready var _match_screen: MatchScreen = %MatchScreen
@onready var _season_screen: SeasonScreen = %SeasonScreen
@onready var _match_nav_button: Button = %MatchNavButton
@onready var _season_nav_button: Button = %SeasonNavButton


func _ready() -> void:
	_show_screen(_match_screen, _match_nav_button)


func _screens() -> Array[Control]:
	return [_match_screen, _season_screen]


func _on_match_nav_button_pressed() -> void:
	_show_screen(_match_screen, _match_nav_button)


func _on_season_nav_button_pressed() -> void:
	_show_screen(_season_screen, _season_nav_button)


## Klick auf ein Saisonergebnis: zum Match-Bildschirm wechseln und die Serie zeigen.
## Die Saison bleibt dabei unverändert im (unsichtbaren) Saison-Bildschirm.
func _on_season_screen_series_opened(series: SeriesResult, team_a: Team, team_b: Team, label: String,
		ovr_a: float, ovr_b: float) -> void:
	_match_screen.show_series(series, team_a, team_b, label, ovr_a, ovr_b)
	_show_screen(_match_screen, _match_nav_button)


func _on_match_screen_back_to_season_requested() -> void:
	_show_screen(_season_screen, _season_nav_button)


func _show_screen(screen: Control, nav_button: Button) -> void:
	for s: Control in _screens():
		s.visible = s == screen
	nav_button.set_pressed_no_signal(true)
