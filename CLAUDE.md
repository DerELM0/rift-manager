# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Rift Manager

LoL-Esport-General-Manager / Career-Mode-Spiel. Fanprojekt, nicht kommerziell.
Godot 4.7, GDScript, Renderer: Compatibility (`gl_compatibility` für Desktop und Mobile).

Das Godot-Projekt liegt im Unterordner `rift-manager/` (dort ist `project.godot`), nicht im Repo-Root.
Alle Ordnerangaben unten und alle `res://`-Pfade beziehen sich auf `rift-manager/`.

Stand: Projekt ist frisch angelegt, noch ohne Code, Szenen, Tests oder Build-Skripte.

## Zusammenarbeit

Der User ist Game Designer mit begrenzter Programmiererfahrung:
Änderungen kurz erklären, keine großen Umbauten ohne Rückfrage.

## Kernprinzipien

- Simulationstiefe ist wichtiger als Grafik: viele Regionen, Tier-1- bis Tier-3-Ligen,
  SoloQ-Ladder, lebendige Welt (alle Teams entwickeln sich, nicht nur das eigene).
- Fiktive Spielernamen. Teams/Spieler/Stats kommen per CSV-Import aus `data/default/`.
- Zwei Modi: GM-Modus und Career-Modus.

## Design-Dokument

- `docs/GDD.md` (Repo-Root) ist die verbindliche Design-Grundlage. Vor größeren Features
  den passenden Abschnitt lesen.
- Wird eine Design-Entscheidung getroffen oder geändert, wird das GDD im selben Schritt
  angepasst, inklusive der Entscheidungstabelle am Ende.
- Weicht Code vom GDD ab: nicht stillschweigend anpassen, sondern den User darauf hinweisen.
- Hinweise „Prototyp-Stand“ im GDD beschreiben bewusste Vereinfachungen im Code; die offenen
  Punkte stehen als Checkliste in `docs/BACKLOG.md`. Wird ein Punkt gebaut: Backlog abhaken
  und den Prototyp-Hinweis im GDD anpassen.

## Daten und Web-Simulator

- Die Standarddaten werden ab jetzt in `data/default/*.csv` gepflegt (Quelle der Wahrheit).
- `web-sim/` (Repo-Root) ist nur noch Referenz für Formeln und wird nur gelesen.
  `web-sim/data.js` wird nicht mehr angepasst; Abweichungen zu den CSVs sind gewollt.
- Prüfwerte: Bis zum Trait-Abgleich mit dem GDD stammen die Referenzwerte in der Debug-Szene
  aus dem Web-Simulator. Ab dem Trait-Abgleich ist der Godot-Stand die Referenz: Die
  Prüfwerte werden dann einmal mit Godot neu erzeugt und gelten danach als Sollwerte.

## Datenmodell

- Spielerwerte 0–100: Mechanics, Macro, Mental, Teamwork, Laning, Reputation + Overall.
- Traits à la Football Manager (Shotcaller, Clutch Player, Mentor …).
- Teamwerte: Form, Chemistry, Coach (Coach hat eigene Stats).
- 5 Spieler pro Team auf Top/Jungle/Mid/ADC/Support.

## Architektur

Strikte Trennung von Daten, Simulation und Darstellung, damit Modelle und Simulation ohne Szenen (headless) laufen und testbar bleiben:

- `scripts/models/` – reine Datenklassen (`extends RefCounted` oder `Resource`), keine UI-Logik.
- `scripts/sim/` – Simulationslogik (Matches, Saison, Entwicklung); darf nichts von Szenen/Nodes wissen.
- `scenes/` – nur Darstellung, holt Daten über Autoloads. `scenes/screens/` für Vollbild-Screens, `scenes/components/` für wiederverwendbare UI-Bausteine.
- `autoload/` – globale Singletons: `GameState`, `Database` (CSV-Laden), `SimClock` (Zeitfortschritt). Im Editor als Autoload registrieren.
- `data/default/` – Standard-Spieldaten als CSV.
- `themes/` – Godot-Themes für die UI; `assets/` – Grafiken, Fonts, Sounds.

## Befehle

Godot ist nicht im PATH. Es gibt noch kein Test-Framework (z. B. GUT/gdUnit4) und keine Export-Presets.
Mit einer Godot-4.7-Binary sind diese Befehle möglich:

```bash
godot --path rift-manager                                # Spiel starten
godot --path rift-manager --editor                       # Editor öffnen
godot --path rift-manager --headless --import            # Projekt importieren / Ressourcen prüfen
godot --path rift-manager --headless --script res://<pfad>.gd   # einzelnes Skript ausführen (Skript muss SceneTree/MainLoop erweitern)
```

## Konventionen

- Statische Typisierung in GDScript (`var x: int`, `func f() -> void`).
- snake_case für Dateien/Variablen, PascalCase für `class_name`.
- CSVs im Godot-Import auf „Keep File“ stellen (sonst macht Godot daraus Übersetzungsdateien), Laden per `FileAccess`.
- `project.godot` nicht von Hand ändern; Einstellungen (Autoloads, Main Scene) über den Godot-Editor setzen.
- Fenster-Stretch `canvas_items`/`expand`; das Spiel ist UI-lastig (Control-Nodes).
- Zeilenenden LF (`.gitattributes`), Kodierung UTF-8 (`.editorconfig`).
- `.godot/` ist Cache und wird nicht eingecheckt; `*.import`-Dateien gehören ins Repo.
