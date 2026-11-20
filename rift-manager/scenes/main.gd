extends PanelContainer
## Hauptszene: Navigationsleiste oben, darunter der gewählte Bildschirm.
## Die Bildschirme sind im Editor unter ScreenArea eingehängt und bleiben die
## ganze Zeit bestehen; umgeschaltet wird nur die Sichtbarkeit. So bleibt z. B.
## eine laufende Saison erhalten, wenn man kurz zum Match wechselt.
##
## Neuer Bildschirm: Szene unter ScreenArea einhängen (Layout auf "Full Rect"),
## Button in NavRow mit derselben ButtonGroup anlegen und hier in _screens()
## und einer _on_..._pressed-Funktion ergänzen.

@onready var _match_screen: Control = %MatchScreen
@onready var _season_screen: Control = %SeasonScreen
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


func _show_screen(screen: Control, nav_button: Button) -> void:
	for s: Control in _screens():
		s.visible = s == screen
	nav_button.set_pressed_no_signal(true)
