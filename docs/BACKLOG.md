# Rift Manager – Backlog

Stand: 20.11.2026

Offene Punkte zwischen dem aktuellen Godot-Stand und dem Design in `docs/GDD.md`, gruppiert nach System. Das GDD ist maßgeblich; die Hinweise „Prototyp-Stand“ dort beschreiben, was davon heute im Code steckt. Erledigte Punkte abhaken und im GDD den jeweiligen Prototyp-Hinweis anpassen oder entfernen.

## Traits

- [ ] `traits.csv` einführen: Traits als Daten aus programmierten Effekt-Bausteinen (Wertebonus je Phase, Mental-Schwankung, Training, Chemistry, Bedingungen Rolle/Druck/international). Neue Traits ohne Code.
- [ ] Trait-Abgleich mit der GDD-Tabelle (danach ist der Godot-Stand Referenz für Prüfwerte, Debug-Szene neu kalibrieren):
  - [ ] Rollenbedingungen: Carry nur Mid/ADC, Engage Caller und Vision Master nur Support/Jungle
  - [ ] Bühnenangst nur bei internationalen Turnieren
  - [ ] Early-Game-Spezialist: +4 auf alle Werte bis Minute 14
  - [ ] Invader: Kills und Tode in Phase 2 doppelt so häufig
  - [ ] Weak-Side-Spezialist: keine Strafe statt halber Strafe
  - [ ] Late-Game-Monster ab Minute 30, inklusive Tooltip-Text (`scripts/models/trait_info.gd` sagt noch „ab Minute 35“)
  - [ ] Tilt-Proof: Form sinkt nach Niederlagen nur halb so stark
  - [ ] Perfektionist: nach jeder Niederlage −3 Form
  - [ ] Hot-Headed: Chemistry −0,5 pro Woche bei Form < 45
  - [ ] Shotcaller: zwei Shotcaller kosten Chemistry −1 pro Woche
  - [ ] Risikoarm: −3 MEC bei Outplays
  - [ ] Tooltip-Texte aus dem GDD statt aus dem Web-Simulator
- [ ] Traits mit Abhängigkeit zu fehlenden Systemen: Grinder (Burnout), Ironman, Langlebig, Champion Ocean, Meta-Chaser, Meta-Macher, One-Trick, Fan Favorite, Medienprofi
- [ ] Herkunft von Traits: Start-Traits passend zu Werten, Traits durch Ereignisse und Entscheidungen, Obergrenze 5, Mentor entfernt negative Traits

## Spielerwerte

- [ ] Reputation (REP) für Spieler in Daten und Modell
- [ ] Rollenvertrautheit (FAM) pro Rolle, OVR_eff auf fremder Rolle
- [ ] Charisma und Potential verdeckt, per Scouting als Spanne bzw. Sterne

## Champions, Meta und Draft

- [ ] Champion Pool mit Mastery pro Spieler und Champion (ChampMod statt fester Mastery 85)
- [ ] `champions.csv` mit Rollen, Archetypen und Gewichten
- [ ] Meta-Tiers pro Patch, ein Patch pro Monat, MetaMod im Spiel
- [ ] Lernen und Verfall der Mastery
- [ ] Draft mit 5 Bans und 5 Picks, PickWert, Comp-Identität und Comp-Score aus Archetyp-Summen
- [ ] Draft-Einstellung: selbst draften mit Coach-Notizen oder Coach draftet

## Teamwerte und Konflikte

- [ ] Chemistry pro Spielerpaar, Duos Jungle–Mid und ADC–Support doppelt gewichtet
- [ ] Startwerte neuer Paare 20, mit gemeinsamer Vergangenheit 40; `chemistry.csv`
- [ ] Scrim-Faktor S aus dem Wochenplan
- [ ] Konflikte: Typen, Entstehung, Schwere, Folgen, Reaktionen (Gespräch, Strafe, Bank, Ignorieren), Wechselwunsch

## Training und Entwicklung

- [ ] Wochenplan des Teams (Scrims, Solo Queue, VOD-Review, Pause) und Trainingsfokus pro Spieler statt fest pro Rolle
- [ ] Altersfaktor A wie im GDD (26–27: 0,2; 28–30: 0,15; 31+: 0,1)
- [ ] Alterung pro Saison (MEC und LAN sinken, MAC, TEA, MEN wachsen)
- [ ] Burnout als Einstellung (Zuwachs, Wirkung ab 70, Alterszuschlag)
- [ ] Sprachen lernen für jede fremde Teamsprache, nicht nur Englisch; Sprachwert je Sprache

## Coach und Staff

- [ ] Coach-Reputation (REP)
- [ ] Assistant Coach mit Bereichszuteilung
- [ ] Coach-Traits (Meta-Leser, Talent-Schmied, Disziplinarisch, Spieler-Versteher)
- [ ] Analyst, Scout, Sportpsychologe mit ihren Effekten
- [ ] Mitarbeitermarkt mit Verträgen und Gehältern; `staff.csv`
- [ ] Doppelrolle Spieler/Staff (z. B. caedral)

## Saison, Formate und Jahresablauf

Die Formatpunkte werden mit dem Jahresablauf gebaut. Heute: einfache Runden plus Top-6-K.-o.-Playoffs im Bo5.

- [ ] Jahresablauf mit drei Splits, First Stand, MSI, Worlds, Offseason; Split-Längen in Wochen wie im GDD (heute z. B. LCK 14 Wochen)
- [ ] Alle Ligen aller Stufen parallel im selben Wochentakt
- [ ] LCK: LCK Cup (Split 1), Road to MSI (Split 2), Runden 3–4 mit Play-In (Legend 5 und Rise 1–3)
- [ ] LPL: Standard 14 Teams mit Ascend/Perseverance/Nirvana 6/4/4 und Knight's Road; überzählige Teams in die LPL-Academy-Liga; Einstellung „LPL mit 16 Teams“ (heute nur dieser Modus)
- [ ] LEC Versus: 12 Teams (2 Gäste aus Tier 2), einfache Runde im Bo1, Top 8 in Double Elimination
- [ ] LCS Lock-In: Swiss Stage im Bo3, Top 6 in Double Elimination
- [ ] CBLOL Cup, LCP-Formate inklusive Swiss Stage in Split 3
- [ ] Double-Elimination-Playoffs, wo das Format es vorsieht
- [ ] Championship Points (LPL, LCP)
- [ ] Preset „Einheitlich“ als Einstellung
- [ ] Internationale Turniere: First Stand, MSI, Worlds mit ihren Formaten und Plätzen
- [ ] Tier-1-Modell als Einstellung (Geschlossen, Wie 2026, Offen)
- [ ] Auf- und Abstieg zwischen Tier 2 und Tier 3 je Region; `leagues.csv`
- [ ] Offseason: Promotion-Turniere, Alterung, Verträge, Rücktritte, Rookies, Transferfenster

## Welt

- [ ] Sieben Regionen mit bis zu drei Ligastufen (rund 290 Teams, etwa 3.000 Spieler)
- [ ] Generator für neue Spieler (Namensmuster, Sprache nach Herkunft, Spielerinnen als Einstellung)
- [ ] KI-Manager mit Vorstandsprofil, Bedarf pro Rolle, Transfers, Import-Regeln
- [ ] Spielerentscheidung bei Angeboten (Nutzen U)
- [ ] Rücktritte und Rookies pro Jahr
- [ ] Prüfung: zehn Saisons ohne menschlichen Spieler, Ziele aus dem GDD

## SoloQ und Scouting

- [ ] SoloQ-Ladder pro Region mit MMR, Rang und LP
- [ ] Scouting mit Wertespannen, Scout-Berichte, Tryouts

## Markt und Geld

- [ ] Marktwert und Gehaltsforderung
- [ ] Verträge, Budget, Sponsoren, Preisgeld

## Spielmodi

- [ ] Wochenloop mit Ereignissen (Mails, Angebote, Konflikte, Medien)
- [ ] GM-Modus: Kader, Verträge, Coach, Trainingsplan, Vorstandsziele, Entlassung
- [ ] Career-Modus: eigener Spieler, Wochenentscheidungen, Interviews, Vertragsangebote, Wechselwünsche

## Daten und Import

- [ ] CSV-Format wie im GDD: sieben Dateien mit `id`-Verknüpfung (teams, players, staff, champions, traits, leagues, chemistry); Standarddatenbank umstellen
- [ ] Import-Regeln: fehlende Werte generieren statt 0, bis zu 8 Spieler pro Team (mindestens einer pro Rolle), Fehlerliste mit Zeilennummern in der Oberfläche
- [ ] Gleiche `id` überschreibt, neue `id` ergänzt

## Historie und Statistik

- [ ] Schnappschüsse nach jedem Split, Turnier und jeder Saison; Hall of Fame, All-Time-Statistiken
- [ ] Speicherregeln für Matches (laufende Saison voll, danach zusammengefasst)
- [ ] Speicherstände
- [ ] Schnellmodus nur, falls die Zeitmessung ihn nötig macht

## Darstellung

- [ ] Gold-Graph pro Spiel im Match-Bildschirm (Design-Säule „Jedes Match erzählt eine Geschichte“)
- [ ] Formeln über Tooltips einsehbar (Design-Säule „Durchschaubar“)
- [ ] Form und Chemistry zum Zeitpunkt eines Saisonspiels anzeigen (dafür pro Serie mitschreiben)
- [ ] Später: einfache 2D-Minimap
