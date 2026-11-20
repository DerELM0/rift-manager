class_name TraitInfo
extends RefCounted
## Beschreibungen der Traits für die Anzeige (Tooltip), übernommen aus dem
## Web-Simulator (app.js, TRAITS). Wirkung je Trait steht in MatchSim und Season.
##
## Art: "+" positiv, "-" negativ, "±" gemischt, "·" noch ohne Wirkung im Prototyp.

const INFO: Dictionary = {
	"Lane Bully": ["+", "+5 Laning in der Lane-Phase. Holt seine Lane-Kills lieber selbst, der Jungler bekommt seltener den Kill."],
	"Early-Game-Spezialist": ["+", "+4 Mechanics und Laning bis Minute 14. Als Jungler hilft er häufiger bei Kills."],
	"Late-Game-Monster": ["+", "+4 Mechanics in Teamfights ab Minute 35."],
	"Carry": ["+", "+4 Mechanics in Teamfights, solange das Team vorne liegt. Nimmt Lane-Kills lieber selbst."],
	"Teamplayer": ["+", "Chemistry wächst mit ihm 30 % schneller. Überlässt dem Jungler öfter den Kill."],
	"Shotcaller": ["+", "Hebt die Macro-Entscheidungen des Teams bei Objectives."],
	"Engage Caller": ["+", "+3 Teamfight-Stärke für das ganze Team."],
	"Vision Master": ["+", "+3 auf die Objective-Kontrolle des Teams."],
	"Clutch Player": ["+", "In Playoffs und Entscheidungsspielen +5 Mechanics und nur halb so große Schwankung."],
	"Bühnentier": ["+", "Unter Druck (Playoffs) +3 Mechanics."],
	"Tilt-Proof": ["+", "Schwankt von Spiel zu Spiel 25 % weniger."],
	"Risikoarm": ["+", "Wird 30 % seltener erwischt, wenn ein Kill fällt."],
	"Invader": ["+", "Jungler: +3 Jungle-Druck, stärker auf der Fokus-Lane, holt mehr Kills selbst."],
	"Roamer": ["+", "Mid oder Support hilft zusätzlich auf der schwächsten anderen Lane."],
	"Weak-Side-Spezialist": ["+", "Leidet weniger, wenn der Jungler die andere Seite spielt."],
	"Mentor": ["+", "Ab 24 Jahren: Spieler bis 21 im Team trainieren 15 % schneller."],
	"Grinder": ["+", "Trainiert 10 % schneller."],
	"Perfektionist": ["+", "Trainiert 15 % schneller."],
	"Late Bloomer": ["+", "Entwickelt sich bis 25 so schnell wie ein 22-Jähriger."],
	"Sprachtalent": ["+", "Lernt Englisch doppelt so schnell."],
	"Fan Favorite": ["·", "Beliebt bei den Fans. Wirkt später auf Sponsoren und Reputation, im Prototyp noch ohne Wirkung."],
	"Medienprofi": ["·", "Souverän vor Kamera und Presse. Im Prototyp noch ohne Wirkung."],
	"Champion Ocean": ["·", "Riesiger Champion-Pool. Wirkt mit Champion-Daten auf den Draft, im Prototyp noch ohne Wirkung."],
	"Meta-Chaser": ["·", "Passt sich schnell an Patches an. Wirkt mit Patches, im Prototyp noch ohne Wirkung."],
	"Meta-Macher": ["·", "Erfindet eigene Picks und Strategien. Im Prototyp noch ohne Wirkung."],
	"Ironman": ["·", "Kaum Burnout-Gefahr. Wirkt mit Burnout, im Prototyp noch ohne Wirkung."],
	"Arrogant": ["±", "+3 Mental, aber Chemistry wächst 20 % langsamer."],
	"Egoist": ["±", "+3 Mechanics, −4 Teamwork. Nimmt Lane-Kills lieber selbst."],
	"Hot-Headed": ["-", "Schwankt von Spiel zu Spiel 50 % stärker."],
	"Choker": ["-", "In Playoffs und Entscheidungsspielen −5 Mental."],
	"Bühnenangst": ["-", "Unter Druck (Playoffs) −4 Mechanics."],
	"Lone Wolf": ["-", "Chemistry wächst mit ihm nur halb so schnell."],
	"Faul": ["-", "Trainiert 20 % langsamer."],
	"One-Trick": ["-", "Kleiner Champion-Pool. Wirkt mit Champion-Daten im Draft, im Prototyp noch ohne Wirkung."],
}


## Art des Traits: "+", "-", "±" oder "·" (unbekannte Traits: "·").
static func kind(trait_name: String) -> String:
	return INFO.get(trait_name, ["·", ""])[0]


## Beschreibung für den Tooltip.
static func description(trait_name: String) -> String:
	var text: String = INFO.get(trait_name, ["·", ""])[1]
	return text if not text.is_empty() else "Noch keine Beschreibung."
