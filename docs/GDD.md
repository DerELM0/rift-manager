# Rift Manager – Game Design Document

Stand: 20.11.2026

> Diese Datei (`docs/GDD.md` im Repo) ist die Hauptversion des GDD. Design-Änderungen werden hier eingetragen. Das frühere Claude-Doc ist nur noch Archiv.

## Vision & Rahmen

Rift Manager (Arbeitstitel) ist ein LoL-Esport-Managementspiel mit zwei Modi: General Manager und Spieler-Karriere. Der Kern ist, wirklich unterschiedliche Teams zu bauen: aus Spielerwerten, Traits, Champion Pools, Coaches und Chemistry.

**Ziel:** Ein kostenloses Fanprojekt. Es soll so etwas überhaupt geben. Verkauf ist vorerst kein Ziel.

**IP-Strategie:**

1. Phase 1 als nicht-kommerzielles LoL-Fanprojekt nach Riots "Legal Jibber Jabber". Keine Riot-API, weil Riots API-Regeln Spiele mit Riot-IP ausschließen.
2. Standarddatenbank mit fiktiven Teams, Spielern und Coaches. Reale Namen, Teams und Werte kommen nur per CSV-Import vom Nutzer.
3. Später optional ein eigenes MOBA-Universum mit eigenen Champions. Die Systeme bleiben gleich, nur die Daten werden getauscht.

**Design-Säulen:**

- **Teams fühlen sich verschieden an.** Zwei Teams mit gleichem Overall spielen anders, weil Traits, Pools und Chemistry anders sind.
- **Jedes Match erzählt eine Geschichte.** Gold-Graph, Event-Log und Spielerbewertungen statt nur Sieg oder Niederlage.
- **Durchschaubar, aber nicht trivial.** Formeln sind über Tooltips einsehbar. Varianz kommt aus Mental und Form, nicht aus purem Zufall.
- **Alles ist Daten.** Werte, Traits, Champions und Ligen liegen in CSV-Dateien. Nichts ist fest im Code.

**Plattform:** Zuerst ein Web-Prototyp nur für die Simulation, dann Godot 4. Der Simulationskern bleibt reine Logik ohne UI, mit festem Zufalls-Seed, damit Ergebnisse reproduzierbar und portierbar sind.

**Skala:** Alle Werte laufen von 0 bis 100. 50 ist ein solider Profi in einer Regionalliga, 75 ist Top-Liga-Stammspieler, 90+ ist Weltklasse.

## Spielmodi

Beide Modi laufen in derselben Welt, mit derselben Simulation und demselben Wochentakt. Sie unterscheiden sich nur darin, was der Spieler steuert.

|  | GM-Modus | Career-Modus |
| --- | --- | --- |
| Du bist | General Manager eines Teams | Ein einzelner Profi |
| Du steuerst | Kader, Verträge, Coach, Trainingsplan, optional Draft | Trainingsfokus, Champion Pool, Interviews, Vertragsangebote, Wechselwünsche |
| Start | Team wählen, Budget und Erwartung vom Vorstand | Eigenen Spieler erstellen: Rolle, Name, 17 Jahre, OVR 45–55, Start als Free Agent in der SoloQ oder in einem Tier-3-Team |
| Ziel | Titel, Dynastie, Budget halten | Stammplatz, Top-Liga, Worlds, Hall of Fame |
| Scheitern | Entlassung bei verfehlten Zielen | Bankplatz, kein Vertrag, Karriereende |

**Wochenloop (beide Modi):**

1. Ereignisse lesen: Mails, Angebote, Konflikte, Medienanfragen.
2. Woche planen: Training pro Spieler (GM) oder für dich selbst (Career).
3. Spieltag: Matches werden simuliert, mit Gold-Graph und Event-Log.
4. Auswertung: Form, Chemistry, Reputation und Werte werden aktualisiert.

**Career-Besonderheiten:**

- Du entscheidest pro Woche zwischen Solo Queue (MEC/LAN), VOD-Review (MAC), Scrims mit Team (TEA, Chemistry) und Pause (Mental).
- Interviews mit 2–3 Antwortoptionen verändern Reputation, Chemistry und Mental. Charisma bestimmt die Erfolgschance.
- Du kannst einen Wechsel fordern, Angebote ablehnen oder dich auf die Bank setzen lassen.
- Der GM deines Teams ist eine KI. Seine Entscheidungen folgen denselben Regeln wie im GM-Modus.

## Spielerwerte

Jeder Spieler hat fünf Leistungswerte, die in die Simulation eingehen, und einen Marktwert (Reputation). Dazu kommen drei verdeckte Werte und ein Champion Pool.

| Wert | Kürzel | Wirkt auf | Sichtbar |
| --- | --- | --- | --- |
| Mechanics | MEC | Teamfights, Solo-Kills, Outplays | ja |
| Laning | LAN | Gold- und CS-Differenz bis Minute 14 | ja |
| Macro | MAC | Objectives, Rotationen, Vision, Führung verwerten | ja |
| Teamwork | TEA | Wie viel der Teamstärke im Fight ankommt | ja |
| Mental | MEN | Leistungsschwankung, Druck, Throws, Comebacks | ja |
| Reputation | REP | Gehalt, Marktwert, Fans, Sponsoren. Nicht in der Simulation | ja |
| Charisma | CHA | Chemistry-Wachstum, Shotcaller, Interviews, Fan-Wert | verdeckt, per Scouting als Spanne |
| Potential | POT | Obergrenze der Entwicklung | verdeckt, per Scouting als Sterne |
| Rollenvertrautheit | FAM | Pro Rolle 0–100, Hauptrolle = 100 | ja |

### Overall pro Rolle

Der Overall ist eine rollengewichtete Summe der fünf Leistungswerte. Reputation zählt nicht mit.

```latex
OVR_{Rolle} = \sum_{s \in \{MEC,\,LAN,\,MAC,\,TEA,\,MEN\}} w_{Rolle,s} \cdot s
```

| Rolle | MEC | LAN | MAC | TEA | MEN |
| --- | --- | --- | --- | --- | --- |
| Top | 0,25 | 0,30 | 0,15 | 0,10 | 0,20 |
| Jungle | 0,20 | 0,05 | 0,40 | 0,20 | 0,15 |
| Mid | 0,30 | 0,25 | 0,25 | 0,10 | 0,10 |
| ADC | 0,35 | 0,30 | 0,10 | 0,15 | 0,10 |
| Support | 0,10 | 0,15 | 0,30 | 0,35 | 0,10 |

Auf einer fremden Rolle sinkt der Wert über die Rollenvertrautheit:

```latex
OVR_{eff} = OVR_{Rolle} \cdot \left(0{,}75 + 0{,}25 \cdot \frac{FAM_{Rolle}}{100}\right)
```

**Beispiel:** Ein Mid mit MEC 85, LAN 80, MAC 75, TEA 60, MEN 70 hat als Mid OVR 77. Als Jungler hätte er mit denselben Werten 73,5. Bei FAM 40 auf Jungle bleiben davon effektiv 62.

### Champion Pool

Jeder Spieler hat pro Champion eine Mastery von 0 bis 100. Erst der Pool macht Draft und Meta-Wechsel spannend. In einem Match gilt für alle Leistungswerte:

```latex
s_{Champ} = s \cdot \left(0{,}85 + 0{,}15 \cdot \frac{Mastery}{100}\right)
```

Auf einem unbekannten Champion verliert ein Spieler also bis zu 15 %.

- **Pool-Tiefe** ist die Zahl der Champions mit Mastery ≥ 70. Unter 3 macht den Spieler im Draft angreifbar.
- **Meta-Tier** pro Patch: S +8, A +4, B 0, C −4, D −8 auf den PickWert im Draft. Im Spiel wirkt die Hälfte davon (MetaMod, +4 bis −4) auf die effektiven Werte des Spielers. Ein neuer Patch erscheint einmal pro Monat.
- **Lernen und Verfall:** Gespielte Champions steigen um 1–3 pro Woche. Ungespielte verlieren 0,5 pro Woche bis zu einem Boden von 50.

### Charisma

Charisma ist kein Leistungswert. Es entscheidet, wie schnell ein Team zusammenwächst (Teamwerte), wer Shotcaller sein kann (Traits) und wie Interviews und Sponsoren laufen. Ein charismatischer Spieler mit OVR 72 kann für ein junges Team mehr wert sein als ein stiller mit OVR 76.

### Sprache

Sprache ist ein eigenes System: Wer die Teamsprache nicht spricht, spielt schlechter zusammen und wächst langsamer ins Team. Importe starten deshalb mit einem echten Nachteil, der sich über etwa eine Saison abbaut.

Jeder Spieler hat eine Muttersprache und einen Englischwert von 0 bis 100. Der Generator setzt ihn nach Herkunft: In EMEA haben 95 % der Spieler einen Wert von 70 oder mehr, Koreaner, Chinesen und Japaner liegen meist zwischen 10 und 50. Jedes Team hat eine Teamsprache. Daraus ergibt sich der Kommunikationswert K:

| Situation | K |
| --- | --- |
| Muttersprache = Teamsprache | 100 |
| Teamsprache ist Englisch | Englischwert |
| Andere Fremdsprache als Teamsprache | 10 (lernt wie Englisch) |

K wirkt im Match auf Teamwork und in der Woche auf Chemistry (siehe Teamwerte). Ein Spieler mit K = 10 verliert 18 % Teamwork, und seine Paare wachsen nur gut halb so schnell.

**Lernen:** In einem Team mit fremder Teamsprache steigt K um 1,5 pro Woche, bei Spielern ≤ 21 um 2,5. Der Trait Sprachtalent verdoppelt das. Ein 24-jähriger Import mit Englisch 20 braucht so rund 33 Wochen bis K 70.

**Mehrere Sprachen:** Ein Spieler kann mehrere Sprachen sprechen. Für die Chemistry eines Paares zählt ihre beste gemeinsame Sprache: Zwei Koreaner in einem englischsprachigen Team verstehen sich untereinander voll, nur ihr K im Match hängt an der Teamsprache. Ein Spieler mit Englisch und Koreanisch wird so zur Brücke zwischen Imports und Team.

## Traits

Jeder Spieler hat 1 bis 5 Traits. Rookies starten mit 1–2, ein etablierter Profi hat 3, und 5 Traits haben nur Elite-Spieler. Traits verändern Werte nur in bestimmten Situationen und machen so aus Zahlen einen Charakter. Negative Traits sind gewollt: Ein Hot-Headed-Superstar ist eine Managemententscheidung.

| Trait | Art | Effekt | Bedingung |
| --- | --- | --- | --- |
| Shotcaller | positiv | Team-Macro + 4 × CHA/100 | Nur der beste Shotcaller im Team zählt. Zwei Shotcaller: Chemistry −1 pro Woche |
| Clutch Player | positiv | +5 MEC, Mental-Schwankung halbiert | Playoffs, Finals, entscheidendes Spiel einer Serie |
| Mentor | positiv | Spieler ≤ 21 im Team trainieren 15 % schneller | Alter ≥ 24 |
| Lane Bully | positiv | +5 LAN in der Laning-Phase | Immer |
| Weak-Side-Spezialist | positiv | Keine Laning-Strafe, wenn der eigene Jungler eine andere Lane fokussiert | Top oder ADC |
| Roamer | positiv | +3 L in einer Nachbarlane, −2 L in der eigenen | Mid oder Support |
| Late-Game-Monster | positiv | +4 MEC in Teamfights ab Minute 25 | Immer |
| Early-Game-Spezialist | positiv | +4 auf alle Werte bis Minute 14 | Immer |
| Carry | positiv | +4 MEC in Teamfights, wenn das eigene Team Gold vorn liegt | Mid oder ADC |
| Engage Caller | positiv | +3 Teamfight-Stärke für das Team | Support oder Jungle |
| Vision Master | positiv | +3 Team-Macro bei Objectives | Support oder Jungle |
| Teamplayer | positiv | Chemistry-Wachstum seiner Paare +30 % | Immer |
| Tilt-Proof | positiv | Mental-Schwankung −25 %, Form sinkt nach Niederlagen nur halb so stark | Immer |
| Champion Ocean | positiv | Neue Champions lernen doppelt so schnell, Mastery-Verfall halbiert | Immer |
| Meta-Chaser | positiv | S- und A-Tier-Champions lernt er doppelt so schnell | Immer |
| Late Bloomer | positiv | Trainingsfaktor sinkt erst ab 26 statt ab 23 | Immer |
| Ironman | positiv | Burnout steigt 50 % langsamer | Immer |
| Langlebig | positiv | Alterung setzt 3 Jahre später ein, Verluste bei MEC und LAN halbiert, Burnout-Zuschlag durch Alter halbiert | Immer, selten (rund 5 % der Spieler) |
| Sprachtalent | positiv | Sprachwert wächst doppelt so schnell | Immer |
| Fan Favorite | positiv | Reputation wächst 50 % schneller, Sponsoreinnahmen +5 % | Immer |
| Medienprofi | positiv | Interviews gelingen mit +20 % Chance | Immer |
| One-Trick | gemischt | Ein Champion Mastery 100, alle anderen höchstens 75 | Immer |
| Grinder | gemischt | Training +10 %, Burnout-Risiko +50 % | Immer |
| Egoist | gemischt | +3 MEC, −4 TEA | Immer |
| Arrogant | gemischt | +3 MEN, Chemistry-Wachstum seiner Paare −20 % | Immer |
| Hot-Headed | negativ | Mental-Schwankung +50 %, Chemistry −0,5 pro Woche bei Form < 45 | Immer |
| Choker | negativ | −5 MEN | Playoffs, Finals, entscheidendes Spiel einer Serie |
| Bühnenangst | negativ | −4 MEC | Internationale Turniere |
| Lone Wolf | negativ | Chemistry-Wachstum seiner Paare halbiert | Immer |
| Faul | negativ | Training −20 % | Immer |

**Neue Traits aus den Spielerprofilen der Standarddatenbank:**

| Trait | Art | Effekt | Bedingung |
| --- | --- | --- | --- |
| Risikoarm | gemischt | Stirbt in Teamfights 30 % seltener, −3 MEC bei Outplays | Immer |
| Invader | gemischt | +3 J in der Laning-Phase, aber Kills und Tode in Phase 2 doppelt so häufig | Nur Jungle |
| Bühnentier | positiv | +3 MEC | Playoffs, Finals, internationale Turniere |
| Perfektionist | gemischt | Training +15 %, nach jeder Niederlage zusätzlich −3 Form | Immer |
| Meta-Macher | positiv | Seine Top-3-Champions zählen im eigenen Team ein Meta-Tier höher | Immer, sehr selten |

**Woher Traits kommen:**

- **Start:** Rookies bekommen 1–2 Traits, passend zu ihren Werten. Shotcaller gibt es zum Beispiel nur bei MAC ≥ 70 und CHA ≥ 60.
- **Ereignisse:** Drei gewonnene Finals mit Spielbewertung ≥ 70 geben eine Chance auf Clutch Player. Drei verlorene Entscheidungsspiele mit schlechter Bewertung geben eine Chance auf Choker. Ein Jahr im Ausland gibt eine Chance auf Sprachtalent.
- **Entscheidungen:** Interviews, Trainingsschwerpunkte und Rollen im Team können Traits auslösen. Zehn Wochen VOD-Review-Fokus geben zum Beispiel eine Chance auf Vision Master, eine Saison als Shotcaller festigt den Trait.
- **Obergrenze 5:** Bei 5 Traits ersetzt ein neuer Trait einen alten. Im Career-Modus wählst du, im GM-Modus entscheidet der Zufall gewichtet nach Werten.
- **Mentor:** Ein Mentor kann einen negativen Trait eines jungen Spielers mit 10 % pro Saison entfernen.
- **Daten:** Die Trait-Liste liegt in einer eigenen CSV, damit neue Traits ohne Code dazukommen können.

## Coach

Der Head Coach ist eine eigene Person mit sechs Werten von 0 bis 100. Er wirkt nicht im Spiel selbst, sondern auf Draft, Entwicklung, Form und Chemistry.

| Wert | Kürzel | Effekt | Formel |
| --- | --- | --- | --- |
| Drafting | DRA | Wie gut Picks und Bans sind | Counter-Chance p = 0,30 + 0,50 × DRA/100 |
| Development | DEV | Trainingsfortschritt aller Spieler | Faktor m\_dev = 0,6 + 0,8 × DEV/100 |
| Motivation | MOT | Wie stark Niederlagen die Form drücken | Form-Verlust × (1 − 0,4 × MOT/100) |
| Tactics | TAC | Bonus auf Team-Macro | + (TAC − 50) / 10, also −5 bis +5 |
| Man-Management | MAN | Chemistry-Wachstum, Konflikte lösen | Faktor 0,8 + 0,4 × MAN/100 |
| Reputation | REP | Gehalt, welche Spieler kommen wollen | Nicht in der Simulation |

**Assistant Coach (optional):** Er wird einem Bereich zugeteilt, zum Beispiel Drafting. Dort zählt der bessere Wert voll und der schwächere zu 25 %, gedeckelt bei 100:

```latex
Wert_{Team} = \min\left(100,\; \max(H, A) + 0{,}25 \cdot \min(H, A)\right)
```

**Coach-Traits (Auswahl):**

- **Meta-Leser:** Nach einem Patch hat sein Team die neue Meta sofort drin, andere Teams nach zwei Wochen.
- **Talent-Schmied:** Spieler ≤ 20 bekommen zusätzlich +20 % Training.
- **Disziplinarisch:** Hot-Headed wirkt nur halb so stark. Chemistry wächst aber 10 % langsamer.
- **Spieler-Versteher:** Konflikte zwischen Spielern lösen sich doppelt so oft von selbst.

**Draft als Einstellung:** Ist sie aus, draftet der Coach mit seiner DRA-Qualität. Ist sie an, draftet der Spieler selbst und bekommt Notizen vom Coach, zum Beispiel "Gegner-Mid spielt nur drei Champions, bannt Azir". Wie viele Notizen kommen und wie treffend sie sind, hängt an DRA.

## Teamwerte

Das Team hat drei Werte: Form (kurzfristig), Chemistry (mittelfristig) und den Coach (langfristig). Form und Chemistry entstehen aus den Spielern und werden jede Woche neu berechnet.

### Form

Jeder Spieler hat eine Form von 0 bis 100, Start bei 50. Nach jedem Spiel fließt seine Spielbewertung G (siehe Match-Simulation) ein:

```latex
Form_{neu} = 0{,}8 \cdot Form_{alt} + 0{,}2 \cdot G
```

Bei einer Niederlage wird nur der Verlust unter 50 mit dem Motivation-Faktor des Coaches gemildert. Die Team-Form ist der Durchschnitt der fünf Starter. Im Match gilt pro Spieler ein Bonus auf alle Leistungswerte:

```latex
FormMod = \frac{Form - 50}{10} \quad (-5 \text{ bis } +5)
```

### Chemistry

Chemistry wird pro Spielerpaar gespeichert. Fünf Spieler ergeben zehn Paare. Die Duos Jungle–Mid und ADC–Support zählen doppelt, weil sie im Spiel am meisten zusammen machen.

```latex
Chem_{Team} = \frac{\sum_{Paare} g_p \cdot Chem_p}{\sum_{Paare} g_p}, \quad g_p = 2 \text{ für Duos, sonst } 1
```

Neue Paare starten bei 20, Paare mit gemeinsamer Vergangenheit bei 40. Wöchentliches Wachstum pro Paar:

```latex
\Delta Chem_p = 3 \cdot \left(0{,}5 + \frac{CHA_{\varnothing}}{100}\right) \cdot L \cdot \left(0{,}8 + 0{,}4 \cdot \frac{MAN}{100}\right) \cdot S
```

- CHA⌀ ist das Charisma-Mittel der beiden Spieler.
- L ist der Sprachfaktor: L = 0,5 + 0,5 × min(K₁, K₂)/100, mit K als Sprachwert der beiden Spieler in ihrer besten gemeinsamen Sprache (siehe Sprache).
- MAN ist das Man-Management des Coaches.
- S ist der Scrim-Faktor aus dem Wochenplan: viele Scrims 1,3, normal 1,0, Pause 0,5.

Chemistry sinkt durch Konflikte (−5 bis −15 pro Ereignis) und durch negative Traits. Ein komplett neues Line-up startet also bei etwa 20 und wächst bei durchschnittlichem Charisma um etwa 3 pro Woche. Es braucht also Preseason plus ein halbes Split (rund 13 Wochen), um auf 60 zu kommen. Das ist das Gegengewicht zum Superteam-Kauf.

Im Match wirkt Chemistry auf Teamwork:

```latex
TEA_{eff} = TEA \cdot \left(0{,}85 + 0{,}30 \cdot \frac{Chem_{Team}}{100}\right) \cdot \left(0{,}80 + 0{,}20 \cdot \frac{K}{100}\right)
```

Bei Chemistry 0 kommen also nur 85 % des Teamworks an, bei 100 sind es 115 %. Ein Spieler ohne Teamsprache (K = 10) verliert zusätzlich 18 %.

## Konflikte

Konflikte sind einfache Ereignisse mit Typ, Schwere und Beteiligten. Sie verändern Chemistry, Form und Mental. Schwere Konflikte können dazu führen, dass ein Spieler auf die Bank muss oder das Team verlassen will.

### Typen

| Typ | Typischer Auslöser |
| --- | --- |
| Spielzeit | Spieler sitzt auf der Bank oder teilt sich die Rolle |
| Shotcalling | Zwei Spieler beanspruchen die Calls, oder Calls werden ignoriert |
| Öffentliche Kritik | Interview oder Stream mit Kritik an Mitspieler oder Coach |
| Disziplin | Verspätung, schwache Scrims, Burnout |
| Vertrag | Gehalt, Vertragsverlängerung, abgelehntes Wechselangebot |
| Persönlich | Privater Streit zwischen zwei Spielern, auch außerhalb des Spiels |

### Entstehung

Jede Woche hat jedes Spielerpaar eine Konfliktchance:

```latex
p_{Konflikt} = 0{,}01 \cdot M_{Traits} \cdot M_{Lage} \cdot \left(1{,}3 - 0{,}6 \cdot \frac{MAN}{100}\right)
```

- M\_Traits: Hot-Headed ×2, Arrogant ×1,5, Egoist ×1,5, Teamplayer ×0,5. Alle beteiligten Traits werden multipliziert.
- M\_Lage: Niederlagenserie ×(1 + Niederlagen/3), Burnout ≥ 70 ×2, Bankplatz ×1,5, laufender Vertragsstreit ×1,5.
- MAN ist das Man-Management des Coaches. Mit MAN 100 sinkt die Chance auf 70 %, mit MAN 0 steigt sie auf 130 %.

### Schwere und Folgen

| Schwere | Chance | Folgen | Dauer ohne Eingreifen |
| --- | --- | --- | --- |
| Leicht | 60 % | Chemistry des Paares −5 | 1–2 Wochen |
| Mittel | 30 % | Chemistry des Paares −10, Team-Chemistry −3, Form beider −5 | 2–4 Wochen |
| Schwer | 10 % | Chemistry des Paares −20, Form beider −10, MEN −5 solange offen. Spielen beide zusammen, sinkt ihr TEA\_eff um 10 %. Nach 2 Wochen ohne Lösung will einer der beiden wechseln | bleibt offen |

### Reaktionen

Der GM (oder im Career-Modus du als Beteiligter) reagiert mit einer von vier Optionen:

1. **Gespräch:** Lösungschance 30 % + MAN/2 % pro Woche. Kein Nachteil.
2. **Strafe:** Löst Disziplin-Konflikte sofort. Der bestrafte Spieler verliert 5 Form und mit 20 % Chance Chemistry zum Coach.
3. **Bank:** Einer der beiden setzt aus. Der Konflikt wirkt nicht mehr im Match, löst aber einen Spielzeit-Konflikt aus, wenn die Bank länger als 3 Wochen dauert.
4. **Ignorieren:** Der Konflikt läuft weiter. Leichte Konflikte verschwinden so oft von selbst, schwere werden schlimmer.

Will ein Spieler wechseln, sinkt seine Form um weitere 5 pro Woche, bis er verkauft wird oder ein Gespräch mit Erfolgsbedingung (MAN ≥ 60 oder hohe Chemistry mit dem Coach) ihn umstimmt.

## Match-Simulation

Ein Spiel läuft in vier Phasen. Jede Phase nutzt andere Werte und gibt einen Vorsprung an die nächste weiter. Mental und Form wirken in jeder Phase. Die Zielvorgabe: Bei 5 Punkten OVR-Unterschied gewinnt der Favorit etwa 65 % der Spiele.

Ablauf: Draft → Laning (0–14) → Midgame (14–25) → Teamfight-Schleife, bis ein Team 4 Nexus-Druck hat.

Draft, Laning und Midgame laufen je einmal. Danach wiederholen sich Teamfights, bis ein Team 4 Nexus-Druck erreicht.

In allen Formeln ist σ die logistische Funktion:

```latex
\sigma(x) = \frac{1}{1 + e^{-x}}
```

### Tagesform und effektive Werte

Vor jedem Spiel würfelt jeder Spieler eine Tagesform d. Wie stark sie schwankt, hängt an Mental:

```latex
d \sim \mathcal{N}(0,\ \sigma_d), \quad \sigma_d = 8 \cdot \left(1{,}5 - \frac{MEN}{100}\right)
```

MEN 100 ergibt eine Schwankung von 4, MEN 50 von 8, MEN 0 von 12. Hot-Headed multipliziert σ\_d mit 1,5, Clutch Player in Drucksituationen mit 0,5. Für jeden Leistungswert gilt dann im Spiel:

```latex
s_{eff} = s \cdot ChampMod + MetaMod + FormMod + d + Trait\text{-}Boni
```

Teamwork wird zusätzlich mit dem Chemistry-Faktor multipliziert (siehe Teamwerte).

### Phase 1: Draft

Beide Teams bannen 5 und picken 5 Champions im Turnier-Modus. Die KI pickt nach dieser Bewertung:

```latex
PickWert = Mastery_{Spieler} + MetaTier + Synergie + Counter
```

- Es gibt sieben Archetypen: Engage, Poke, Pick, Split, Scaling, Control und Teamfight.
- Ein Champion kann mehrere Archetypen erfüllen, jeweils mit einem Gewicht von 1 bis 3. Beispiel: Orianna ist Control 3, Teamfight 3, Scaling 2.
- Die Identität einer Komposition ist der Archetyp mit der höchsten Gewichtssumme über alle fünf Champions. Ein Champion zählt also je nach Team zu einer anderen Comp.
- Der Comp-Score (0 bis +5) wächst mit dem Abstand der stärksten Summe zur zweitstärksten. Eine klare Identität ist stärker als eine gemischte.
- Eine 7×7-Matrix der Archetypen gibt ±3 gegen die gegnerische Komposition. Beispiel: Engage schlägt Poke, Poke schlägt Scaling.
- Jeder Archetyp hat eine Zeitkurve, die den Comp-Score je nach Spielphase verändert (siehe Phase 4).
- Mit Wahrscheinlichkeit p aus dem DRA-Wert des Coaches wählt die KI den besten Counter, sonst den bequemsten Pick.

### Phase 2: Laning (Minute 0–14)

Jede Lane hat einen Laning-Wert. Bot ist ein Duo:

```latex
L = 0{,}6 \cdot LAN_{eff} + 0{,}4 \cdot MEC_{eff}, \qquad L_{Bot} = 0{,}6 \cdot L_{ADC} + 0{,}4 \cdot L_{Sup}
```

**Jungle-Plan:** Vor dem Spiel legt der Coach oder der Spieler fest, für welche Lane der Jungler spielt: Top, Mid, Bot oder Objectives. Die KI wählt nach Comp und Lane-Matchups, zum Beispiel die stärkste Carry-Lane oder die schwächste Lane zum Absichern.

Der Jungler hat den Wert J = 0,6 × MAC + 0,4 × MEC. Seine Jungle Proximity gibt einen Bonus P auf den Laning-Wert:

```latex
P_{Fokus} = 0{,}10 \cdot J, \qquad P_{andere} = \frac{P_{Fokus}}{4}
```

Ein Jungler mit J 80 gibt seiner Fokus-Lane also +8 L und den anderen Lanes je +2. Spielen beide Jungler für dieselbe Lane, heben sich die Boni größtenteils auf. Beim Plan Objectives gibt es keinen Lane-Bonus, dafür +0,05 × J auf Macro bei den ersten zwei Drachen und dem Herold.

Die Gold-Differenz nach 14 Minuten:

```latex
\Delta Gold_{14} = \sum_{Lanes} 60 \cdot \left((L_A + P_A) - (L_B + P_B)\right) + 50 \cdot (J_A - J_B) + Events
```

Events sind First Blood, Solo-Kills und Ganks. Pro Lane gibt es im Schnitt 1,5 Kill-Ereignisse. Wer sie gewinnt, entscheidet σ((L\_A − L\_B)/10). Ein Kill bringt 400 Gold (kalibriert). Kills in der Fokus-Lane des Junglers gehen zu 20 % an ihn. Traits verschieben den Anteil: Invader +8, Early-Game-Spezialist +5, Laner mit Teamplayer +5, Laner mit Lane Bully −8, Carry −5, Egoist −8 Prozentpunkte, insgesamt zwischen 5 und 45 %.

### Phase 3: Midgame (Minute 14–25)

Der Macro-Wert des Teams ist ein gewichteter Schnitt. Jungle zählt 1,5-fach, Support 1,25-fach, alle anderen einfach:

```latex
M = \frac{\sum g_r \cdot MAC_{eff,r}}{\sum g_r} + Shotcaller + \frac{TAC - 50}{10}
```

Um jedes Objective (Drachen, Herold, Türme) wird einzeln gewürfelt. Ein Gold-Vorsprung hilft, Macro hilft mehr:

```latex
P_A(Objective) = \sigma\!\left(\frac{M_A - M_B}{10} + \frac{\Delta Gold}{3000} + \frac{\Delta Comp(t)}{10}\right)
```

Goldwerte: Turm 550, Drache 300 plus Buff-Stack, Herold 600.

### Phase 4: Teamfights (ab Minute 25)

Jetzt läuft eine Serie von Teamfights, etwa alle 3 Minuten einer. Die Fight-Stärke eines Teams:

```latex
F = \sum_{5\ Spieler} \left(0{,}5 \cdot MEC_{eff} + 0{,}3 \cdot TEA_{eff} + 0{,}2 \cdot MAC_{eff}\right) + Comp(t) + 2 \cdot \frac{\Delta Gold}{1000}
```

```latex
P_A(Fight) = \sigma\!\left(\frac{F_A - F_B}{15}\right)
```

**Comp-Kurve:** Comp(t) ist der Comp-Score plus ein Zeitbonus des Archetyps. So entscheidet die Komposition mit darüber, ob ein Comeback möglich ist: Eine Scaling- oder Teamfight-Comp kann einen frühen Rückstand im Late Game drehen, eine Pick-Comp muss früh gewinnen.

| Archetyp | Minute 14–25 | Minute 25–35 | ab Minute 35 |
| --- | --- | --- | --- |
| Pick | +3 | +1 | −1 |
| Poke | +2 | +2 | 0 |
| Engage | +1 | +3 | +2 |
| Split | +1 | +2 | +3 |
| Control | 0 | +2 | +3 |
| Teamfight | −1 | +3 | +4 |
| Scaling | −3 | +1 | +6 |

Im Midgame fließt die Differenz ΔComp(t) auch in die Objective-Chance ein.

- **Gold:** Der Sieger eines Fights bekommt 800 bis 1500 Gold.
- **Shutdown:** Gewinnt das zurückliegende Team, bekommt es zusätzlich 15 % der aktuellen Gold-Differenz. Das ist der natürliche Comeback-Mechanismus.
- **Throw:** Liegt ein Team mehr als 5000 Gold vorn, verliert es den Fight mit der Chance 0,10 × (1 − MEN⌀/100) automatisch. Bei MEN⌀ 80 sind das 2 %, bei 50 schon 5 %.
- **Nexus-Druck:** Jeder gewonnene Fight gibt +1 Druck, mit Baron +2, mit Elder +3. Jeder gewonnene Fight senkt den gegnerischen Druck um 1. Bei 4 fällt der Nexus.
- **Zeitlimit:** Ab Minute 45 entscheidet der nächste Fight um den Elder Drake das Spiel.

### Spielbewertung und Ausgabe

Jeder Spieler bekommt eine Bewertung G von 0 bis 100. Sie setzt sich aus Ergebnis, Duell mit dem Gegenspieler derselben Rolle und KDA zusammen.

**KDA:** Kills, Tode und Assists entstehen aus den Events. Lane-Kills gehen an den Gewinner des Duells. In Teamfights verteilt das Siegerteam 1 bis 4 Kills, gewichtet nach MEC\_eff. Die anderen Beteiligten bekommen mit der Chance TEA/100 einen Assist. Tode treffen eher Spieler mit niedrigem MEN.

```latex
KDA = \frac{K + A}{\max(1,\ D)}
```

W ist +1 bei Sieg und −1 bei Niederlage. Das Ergebnis zählt damit ±5, die KDA bis ±8:

```latex
G = \mathrm{clamp}\!\left(60 + 5W + 0{,}4 \cdot (OVR_{eff} - OVR_{eff,Gegner}) + 2 \cdot \mathrm{clamp}(KDA - KDA_{Rolle},\ -4,\ 4) + d,\ 0,\ 100\right)
```

KDA\_Rolle ist die typische KDA der Rolle: Top und Mid 4, ADC 4,5, Support 5, Jungle 5,5. So werden Jungler und Supports mit ihren vielen Assists nicht automatisch MVP. Im Schnitt erreichen Sieger damit 68, Verlierer 50 und der MVP 82 Punkte, die besten 10 % der MVPs liegen über 90.

MVP ist der Spieler mit dem höchsten G im Siegerteam. Ausgegeben werden ein Gold-Graph pro Minute, ein Event-Log, K/D/A pro Spieler, die Objectives und die Bewertungen. KDA und Bewertung werden über die Saison gesammelt und fließen in Auszeichnungen und den Marktwert ein.

### Kalibrierung

Die Konstanten (60, 50, 10, 15, 3000) sind Startwerte. Sie werden mit 10.000 simulierten Spielen eingestellt, bis diese Ziele stimmen:

| OVR-Differenz der Teams | Siegchance Favorit (Bo1) | Siegchance Favorit (Bo5) |
| --- | --- | --- |
| 0 | 50 % | 50 % |
| 3 | ca. 58 % | ca. 65 % |
| 5 | ca. 65 % | ca. 77 % |
| 10 | ca. 80 % | ca. 94 % |
| 15 | ca. 90 % | ca. 99 % |

Dazu kommen Ziele für die Spieldauer (Schnitt 30–34 Minuten) und für Comebacks (etwa 20 % der Spiele gewinnt das Team, das bei Minute 14 hinten lag).

**Erste Kalibrierung im [Simulator](https://claude.ai/artifact/XvmGdYHrTw5KKyvjQdMkFw) (15.11.2026):** Mit den Startwerten war die Simulation viel zu deterministisch: Bei 5 OVR Differenz gewann der Favorit 82 % statt 65 %. Diese Werte treffen die Ziele jetzt auf etwa 2 Prozentpunkte genau:

| Konstante | Startwert | Kalibriert |
| --- | --- | --- |
| Lane-Gold je Punkt Laning-Differenz | 60 | 50 |
| Gold je Punkt Jungle-Differenz | 50 | 25 |
| Gold pro Kill | 300 | 400 |
| Kill-Events pro Lane bis Minute 14 | 1,5 | 2,5 |
| Teiler Macro-Differenz bei Objectives | 10 | 50 |
| Teiler Golddifferenz bei Objectives | 3000 | 3500 |
| Teiler Fight-Stärke | 15 | 80 |
| Fight-Bonus je 1000 Gold | 2 | 3 |
| Shutdown-Anteil | 0,15 | 0,35 |
| Anteil Lane-Kills für den Jungler | 0,3 | 0,2 |

Ergebnis: 61 / 68 / 78 / 89 % Siegchance bei 3 / 5 / 10 / 15 OVR Differenz, Spieldauer 34 Minuten. Gold entscheidet Teamfights weniger, Shutdowns wiegen mehr. Dadurch sind Comebacks zwischen gleich starken Teams so häufig wie gewünscht:

| Rückstand nach Minute 14 | Comeback-Ziel | Simuliert |
| --- | --- | --- |
| 0–1000 | – | 47 % |
| 2000–3000 | – | 38 % |
| 4000–5000 | 30 % | 31 % |
| 5000–6000 | 25 % | 22 % |
| 6000–7000 | 20 % | 22 % (wenige Spiele) |

Zwischen ungleich starken Teams sind Comebacks seltener, weil der Rückstand dann meist vom schwächeren Team kommt.

**Gold und Kills (15.11.2026):** Der Simulator führt jetzt Gold pro Spieler. Grundeinkommen pro Minute: Top 320, Jungle 290, Mid 340, ADC 360, Support 210, dazu 500 Startgold. Lane-Vorsprung geht als Farm an die Laner (Bot 70/30 auf ADC und Support), Kill-Gold zu 70 % an den Killer und zu 30 % an die Assists, Objectives und Teamfight-Gold zu gleichen Teilen ans Team. Vorher gab es nur 23 Kills pro Spiel, die LCK lag 2025 bei rund 30 ([gol.gg](https://gol.gg/tournament/tournament-stats/LCK%202025%20Rounds%203-5/)). Mit durchschnittlich 3,4 Kills des Siegers pro Teamfight, etwa einem Drittel davon für den Verlierer und Scharmützeln bei 60 % der Objectives sind es jetzt 30 Kills pro Spiel. Ein Team holt dabei etwa 2000 Gold pro Minute. Die typische KDA pro Rolle ist dadurch leicht gestiegen: Top und Mid 4,5, ADC 5, Support 5,5, Jungle 6.

## Entwicklung & Saisonstruktur

Junge Spieler wachsen schnell über Mechanics, Veteranen verlieren Mechanics und gewinnen Macro und Mental. So entsteht ein Kader-Kreislauf, der ohne feste Skripte funktioniert.

### Training

Jeder Spieler hat pro Woche einen Trainingsfokus auf einen Wert. Der Fokuswert steigt um:

```latex
\Delta s = 0{,}3 \cdot A(Alter) \cdot m_{dev} \cdot B \cdot \max\!\left(0,\ \frac{POT - OVR}{20}\right)
```

Die anderen vier Leistungswerte steigen um 30 % davon. B sammelt die Boni: Mentor im Team +15 %, Grinder +10 %, Talent-Schmied-Coach +20 %. Nahe am Potential bremst das Wachstum von selbst.

| Alter | A (Trainingsfaktor) | Veränderung pro Saison ohne Training |
| --- | --- | --- |
| 16–19 | 1,3 | keine |
| 20–22 | 1,0 | keine |
| 23–25 | 0,6 | keine |
| 26–27 | 0,2 | MAC, TEA und MEN +0,5 |
| 28–30 | 0,15 | MEC −1 bis −2, LAN −0,3 bis −0,8, MAC, TEA und MEN +0,5 bis +1 |
| 31+ | 0,1 | MEC −2 bis −3,5, LAN −0,8 bis −1,5, MAC, TEA und MEN +0,5 |

**Alterung (Stand 20.11.2026):** Ende 20 ist für die meisten Spieler die Grenze. Zuerst sinkt Mechanics, Laning folgt ab 28 schwächer. Macro, Teamwork und Mental wachsen mit Reife weiter, aber nie über das Potential. So bleibt ein Old Man's Game möglich: Ein 32-jähriger Support oder Mid mit MAC 95 und MEN 92 kann trotz MEC 70 Weltklasse sein. Mit dem Trait Langlebig setzt die Alterung 3 Jahre später ein und kostet nur halb so viel.

**Wochenplan des Teams:** Scrims (Chemistry ×1,3), Solo Queue (Fokus MEC/LAN), VOD-Review (Fokus MAC), Pause (Burnout sinkt, Chemistry ×0,5).

**Burnout (0–100):** Einstellung, standardmäßig an. Steigt pro Woche ohne Pause um 3 bis 5. Ab 70 gibt es −5 auf Form und mehr Konflikte. Grinder steigt 50 % schneller. Ältere Spieler brennen schneller aus: +10 % Burnout-Zuwachs pro Lebensjahr über 27 (Ironman und Langlebig halbieren den Zuschlag).

### Jahresablauf (Stand 2026)

Ein Spieljahr folgt dem echten LoL-Esport-Kalender 2026: drei Splits pro Region, nach Split 1 First Stand, nach Split 2 MSI, nach Split 3 Worlds, danach die Offseason. Alle Ligen aller Stufen laufen parallel im selben Wochentakt. Jede Region spielt ihre Splits im eigenen Format. Die Formate liegen als Presets in den Daten.

| Phase | Zeitraum (ca.) | Wochen | Inhalt |
| --- | --- | --- | --- |
| Split 1 | Januar bis Anfang März | 8 | Regionale Cups (LCK Cup, LEC Versus, LCS Lock-In, CBLOL Cup …) |
| First Stand | März | 1 | 8 Teams: Sieger jeder Region, dazu LCK 2 und LPL 2 |
| Split 2 | Ende März bis Mitte Juni | 11 | Reguläre Saison und Playoffs, qualifiziert für MSI |
| MSI | Ende Juni bis Mitte Juli | 2 | 11 Teams |
| Split 3 | Juli bis September | 10 | Reguläre Saison und Playoffs, qualifiziert für Worlds |
| Worlds | Mitte Oktober bis Mitte November | 5 | 19 Teams |
| Offseason | Mitte November bis Dezember | 6 | Promotion-Turniere, Alterung, Verträge, Rücktritte, Rookies, Transferfenster |

Tier-2- und Tier-3-Ligen spielen in der Regel zwei Splits parallel zu Split 2 und 3. Ihre Auf- und Abstiegsspiele liegen in der Offseason.

#### Internationale Turniere

| Turnier | Teams | Format | Belohnung |
| --- | --- | --- | --- |
| First Stand | 8: je 1 aus LEC, LCS, CBLOL, LCP; je 2 aus LCK und LPL | Zwei Vierergruppen im Double Elimination (Bo5), dann K.-o. im Bo5 | Siegerregion: ihr Zweiter bei MSI direkt in die Bracket Stage |
| MSI | 11: je 2 aus LCK, LPL, LEC, LCS, LCP; 1 aus CBLOL | Play-In mit 4 Teams (Double Elimination, Bo5, 1 kommt weiter), Bracket Stage mit 8 Teams (Double Elimination, Bo5). Direkt in der Bracket Stage: alle Erstplatzierten und der Zweite der First-Stand-Siegerregion | Sieger fährt fest zu Worlds; die Region des Zweiten bekommt einen zusätzlichen Worlds-Platz |
| Worlds | 19: je 3 aus LCK, LPL, LEC, LCS, LCP; 2 aus CBLOL; MSI-Sieger; Zusatzplatz der MSI-Zweitregion | Play-In mit 4 Teams (CBLOL 2, LCS 3, LEC 3, LCP 3; Double Elimination, Bo5, 1 kommt weiter); Swiss Stage mit 16 Teams über 5 Runden (3 Siege weiter, 3 Niederlagen raus, Bo1 bis 2 Siege oder Niederlagen, dann Bo3, keine Duelle derselben Region); K.-o. mit 8 Teams im Bo5 | Weltmeister |

#### Formate der Tier-1-Ligen (Preset „Originalgetreu“)

| Liga | Teams | Split 1 → First Stand | Split 2 → MSI | Split 3 → Worlds |
| --- | --- | --- | --- | --- |
| LCK | 10 | LCK Cup: Gruppen, Play-In, Bo5-Playoffs; beide Finalisten | Runden 1–2: doppelte Runde im Bo3; Top 6 spielen „Road to MSI“; 2 Plätze | Runden 3–4: Legend Group (Top 5) und Rise Group getrennt, Bilanz läuft weiter; Play-In (Legend 5 und Rise 1–3); Playoffs; Plätze 1–3 (+4. bei MSI-Bonus) |
| LPL | 14 | Drei Gruppen: Ascend (6), Perseverance (4), Nirvana (4); Play-In „Knight's Road“; Playoffs; beide Finalisten | Zwei Gruppen nach Split-1-Leistung; Playoffs; 2 Plätze | Ascend und Nirvana; Playoffs (Sieger fährt zu Worlds); restliche Plätze per Regional Finals der Top 4 nach Championship Points |
| LEC | 10 (+2 Gäste aus Tier 2 in Split 1) | LEC Versus: einfache Runde im Bo1 mit 12 Teams, Top 8 in Double-Elimination-Playoffs; Sieger | Einfache Runde im Bo3, Top 6 in Bo5-Playoffs; beide Finalisten | Wie Split 2; Plätze 1–3 |
| LCS | 8 | Lock-In: Swiss Stage im Bo3, Top 6 in Double Elimination im Bo5; Sieger | Einfache Runde im Bo3, Top-6-Playoffs; Plätze 1–2 | Wie Split 2; Plätze 1–3 |
| CBLOL | 8 (7 Partner + 1 Gast) | CBLOL Cup im Bo1; Sieger | Bo3-Saison und Playoffs; Sieger | Bo3-Saison und Playoffs; Plätze 1–2 |
| LCP | 8 (6 Partner + 2 Gäste) | Einfache Runde im Bo3, Top 6 in K.-o.-Phase im Bo5; Sieger | Wie Split 1; Plätze 1–2 | Swiss Stage, dann Playoffs mit 4 Teams; Plätze 1–3 |

**Championship Points:** LPL und LCP vergeben Punkte für Platzierungen in allen drei Splits. Sie entscheiden über Worlds-Plätze (LPL) und darüber, welche Gastteams ihren Platz verteidigen müssen (LCP). Die Punktetabellen liegen in den Daten.

**Preset „Einheitlich“ (Einstellung):** Alle Tier-1-Ligen spielen dasselbe Format. Split 1 als einfache Runde im Bo1, Split 2 und 3 als einfache Runde im Bo3, jeweils Top 6 in Bo5-Playoffs. Keine Championship Points. Die Plätze bei First Stand, MSI und Worlds bleiben wie oben.

#### Tier-1-Modell (Einstellung mit drei Stufen)

| Stufe | Bedeutung |
| --- | --- |
| Geschlossen | Kein Team verlässt Tier 1. Gastteams gelten als feste Partner. |
| Wie 2026 (Standard) | LCK, LPL und LEC sind geschlossene Franchise-Ligen. LCS, CBLOL und LCP haben Gastplätze, die in der Offseason in einem Promotion-Turnier verteidigt werden: LCS gegen den Sieger der Tier-2-Liga (Vorbild NACL); CBLOL gegen die Top 2 der brasilianischen und die Top 2 der südamerikanischen Tier-2-Liga (Vorbild Circuito Desafiante und LRS); LCP mit den 2 schwächsten Gastteams nach Championship Points gegen die besten Teams aus PCS, VCS, LJL und Ozeanien. |
| Offen | In jeder Region steigt der Letzte der Tier-1-Liga ab, der Sieger des regionalen Tier-2-Turniers steigt auf. |

#### Auf- und Abstieg zwischen Tier 2 und Tier 3

Immer aktiv, aber je Region verschieden geregelt. Die Regeln liegen in `leagues.csv`.

| Region | Regel (Standard) |
| --- | --- |
| EMEA | Jede Tier-2-Liga (Vorbild ERLs) hat eine zweite Division. Der Letzte steigt ab, der Erste der zweiten Division steigt auf. Die besten Tier-2-Teams treffen sich nach jedem Split beim regionalen Turnier (Vorbild EMEA Masters). |
| Nordamerika | Die zwei Letzten der Tier-2-Liga spielen gegen die besten Amateurteams um ihren Platz (Vorbild NACL mit Open Qualifier). |
| Brasilien und Lateinamerika | Promo/Relegation zwischen Tier 2 und den Amateurligen nach jedem Jahr (Vorbild Circuito Desafiante). |
| APAC | Die Letzten aus PCS, VCS und LJL spielen gegen die besten Amateurteams. |
| Korea und China | Tier 2 sind Academy-Ligen der Franchise-Teams, daher kein Abstieg. Tier 3 ist Talentpool, aus dem Academy-Teams Spieler holen. |
| Ozeanien | Keine Tier-1-Liga. Die regionale Liga (Vorbild FLASH Oceania) ist der höchste Wettbewerb; ihr Sieger spielt im LCP-Promotion-Turnier um einen Gastplatz. Darunter Auf- und Abstieg mit der Amateurliga. |

#### Offseason

1. Promotion- und Relegationsturniere (siehe oben).
2. Alterung und Saisonentwicklung (siehe Training).
3. Verträge laufen aus, Rücktritte (siehe Weltentwicklung).
4. Rookies: Jede Region erzeugt neue 16- bis 17-jährige Talente in der SoloQ. Dazu steigen starke SoloQ-Spieler über Tryouts in Tier-3-Teams auf.
5. Hauptfenster für Transfers. Kleinere Fenster liegen vor Split 2 und vor Split 3.

Quellen (Stand November 2026): [LoL Esports Handbook 2026](https://lolesports.com/en-US/season/115547545029543948/handbook) · [MSI und Worlds 2026](https://lolesports.com/en-GB/news/msi-and-worlds-updates) · [First Stand 2026](https://lolesports.com/en-GB/season/115547545029543948/handbook/115548016979679444) · [Worlds 2026 Format](https://rft.gg/news/league-of-legends-worlds-2026-the-complete-guide) · [LCK 2026](https://www.esports.net/wiki/tournaments/lck/) · [LPL Split 1 2026](https://www.sheepesports.com/de/lol/articles/everything-to-know-about-the-lpl-split-1/en) · [LEC 2026](https://lolesports.com/en-GB/news/lec-2026-format-update) · [LCS 2026](https://lolesports.com/en-US/news/lcs-2026-updates) · [LCP 2026](https://lolesports.com/en-AU/news/lcp-2026-season-primer) · [CBLOL Promotion 2027](https://www.sheepesports.com/de/articles/cblol-2027-promotion-tournament-five-team-introduction/en) · [NACL 2025 Split 2](https://lolesports.com/news/2025-nacl-split-2-primer) · [FLASH Oceania](https://www.strafe.com/event/flash-oceania-4bf990/)

### Regionen und Ligen

Die Welt hat sieben Regionen mit bis zu drei Ligastufen. Erst diese Tiefe macht Scouting, Talentaufstieg und Importe interessant. Die Standarddatenbank nutzt fiktive Liga- und Teamnamen nach diesen Vorbildern. Echte Namen kommen per leagues.csv.

| Region | Tier 1 (Vorbild) | Tier 2 (Vorbild) | Tier 3 | Teams (Standard-DB) |
| --- | --- | --- | --- | --- |
| EMEA | LEC | Prime League, LFL, TCL, LES; dazu EMEA Masters als Turnier | Je eine zweite Division unter jeder Tier-2-Liga | 10 + 32 + 32 = 74 |
| Nordamerika | LCS | Academy-Liga | Amateurliga | 8 + 8 + 8 = 24 |
| Brasilien und Lateinamerika | CBLOL | CBLOL Academy (CD), LRS | Je eine Amateurliga | 8 + 16 + 16 = 40 |
| China | LPL | Academy-Liga | Amateurliga | 16 + 16 + 16 = 48 |
| APAC | LCP | PCS, VCS, LJL | Je eine Amateurliga | 8 + 22 + 24 = 54 |
| Korea | LCK | LCK CL | LCK Academy | 10 + 10 + 10 = 30 |
| Ozeanien | – (Weg über die LCP-Promotion) | Regionale Liga (Vorbild FLASH Oceania) | Amateurliga | 8 + 8 = 16 |

Das ergibt rund 290 Teams mit etwa 2.000 Spielern und 290 Coaches. Dazu kommen rund 150 vereinslose Spieler pro Region in der SoloQ, insgesamt also etwa 3.000 Spieler im System.

### Simulationstiefe

Eine volle Match-Simulation kostet nur ein paar hundert Zufallszahlen. Bei rund 290 Teams fallen pro Woche etwa 300 bis 600 Spiele an, in Playoff-Wochen etwas mehr. Das schafft auch ein Browser in unter einer Sekunde. Ziel ist daher: alle Ligen bis Tier 3 voll simulieren, damit jede Statistik echt ist.

**Statistiken und Speicher:** Ein Match erzeugt 10 Picks, 10 Bans und pro Spieler K, D, A, CS, Gold und Bewertung. Das sind rund 100 Zahlen, weniger als 1 KB. Eine Saison hat etwa 20.000 Matches, also rund 15–20 MB, wenn man alles einzeln speichert. Deshalb gilt:

- **Laufende Saison:** Jedes Match bleibt vollständig gespeichert.
- **Laufende Zähler:** Pick-, Ban- und Winrate pro Champion, Patch und Liga sowie die Saisonwerte pro Spieler werden nach jedem Match hochgezählt. Das kostet praktisch nichts.
- **Nach der Saison:** Einzelne Matches werden zu Schnappschüssen pro Spieler, Team und Champion zusammengefasst (siehe Historie). Vollständig bleiben nur Finals, internationale Turniere und die Spiele des eigenen Teams.

So bleibt ein Spielstand auch nach zehn Saisons bei wenigen MB.

Der Schnellmodus ist nur eine Reserve, falls es auf schwächeren Geräten zu langsam wird. Dann wird ein Spiel ohne Phasen mit einer einzigen Formel entschieden:

```latex
P_A = \sigma\!\left(\frac{Power_A - Power_B}{6}\right), \quad Power = OVR_{\varnothing,eff} + FormMod + \frac{Chem - 50}{10} + \frac{TAC - 50}{10}
```

KDA und Bewertungen werden im Schnellmodus aus den OVR-Werten geschätzt. Ob er gebraucht wird, zeigt die Zeitmessung im Prototyp.

### SoloQ-Ladder und Scouting

Jede Region hat eine eigene SoloQ-Ladder. Alle Spieler im System spielen dort: Profis, Academy-Spieler und vereinslose Talente. So wird die Ladder zur Scouting-Quelle und zum Einstieg für den Career-Modus.

**Spiele pro Woche:** Solo-Queue-Fokus 30, normaler Wochenplan 15, Pause 0. Grinder spielen 25 % mehr. Die Spiele zählen für Champion-Mastery und für das MEC/LAN-Training.

**Rechenweg:** SoloQ-Spiele werden nicht voll simuliert, sondern als Serie von Münzwürfen. Jeder Spieler hat eine SoloQ-Stärke, in der Teamwork kaum zählt:

```latex
Skill_{SQ} = 0{,}40 \cdot MEC + 0{,}35 \cdot LAN + 0{,}15 \cdot MAC + 0{,}10 \cdot MEN
```

```latex
MMR_{Ziel} = 1000 + 30 \cdot Skill_{SQ}, \qquad P(Sieg) = \sigma\!\left(\frac{MMR_{Ziel} - MMR}{200}\right)
```

Nach jedem Spiel ändert sich der MMR um ±20. Ein Spieler pendelt sich also mit der Zeit bei seinem Zielwert ein. Hot-Headed bekommt nach zwei Niederlagen in Folge Tilt: −10 % Siegchance für den Rest der Woche. Etwa 3.000 Spieler × 20 Spiele sind rund 60.000 Münzwürfe pro Woche, das ist vernachlässigbar.

**Anzeige:** Aus dem MMR werden Rang und LP. Die besten 300 einer Region sind Challenger.

**Scouting:**

- Auf der Ladder sieht jeder Rang, LP, Winrate und die meistgespielten Champions.
- Die Werte eines ungescouteten Spielers sind nur als Spanne sichtbar, zum Beispiel MEC 60–80. Ein Scout oder der Coach engt sie über einige Wochen ein. Potential und Charisma bleiben bis zum Ende ungenau.
- Vereinslose Spieler aus den Top 100 der Ladder können zu Tryouts eingeladen werden. So entdeckt man ein SoloQ-Wunderkind.

**Career-Start:** Dein Spieler beginnt vereinslos auf der Ladder seiner Region. Unter den Top 200 kommen Tryout-Angebote von Tier-3-Teams, später auch von höheren Ligen.

### Markt und Geld

Marktwert und Gehaltsforderung eines Spielers:

```latex
Wert = 10\,000\ \text{€} \cdot 1{,}12^{\,OVR - 50} \cdot AltersMult \cdot \left(0{,}8 + 0{,}4 \cdot \frac{REP}{100}\right)
```

```latex
Gehalt_{Forderung} = 0{,}25 \cdot Wert \ \text{pro Jahr}
```

Ein Spieler mit OVR 80 liegt damit bei rund 300.000 €, mit OVR 90 bei rund 930.000 € (vor Alters- und Reputationsfaktor). Der AltersMult ist 1,3 bis 21 Jahre, 1,0 bis 25, danach sinkt er um 0,1 pro Jahr.

Das Teambudget kommt aus Sponsoren und Preisgeld. Sponsoreinnahmen wachsen mit Team-Reputation, Fans und Fan-Favorite-Spielern.

### Mitarbeitermarkt

Neben Spielern gibt es einen kleinen Markt für Staff. Mitarbeiter haben Alter, Vertrag, Gehalt und Werte von 0 bis 100. Sie altern, wechseln Teams und gehen in Rente wie Spieler.

| Rolle | Werte | Effekt |
| --- | --- | --- |
| Head Coach | DRA, DEV, MOT, TAC, MAN, REP | Siehe Coach |
| Assistant Coach | wie Head Coach | Verstärkt einen Bereich (siehe Coach) |
| Analyst | Analyse (ANA), Daten (DAT) | Counter-Chance im Draft + 0,10 × ANA/100. Erkennt mit Chance 0,5 × DAT/100 den gegnerischen Jungle-Plan vor dem Spiel |
| Scout | Urteil (URT), Netzwerk (NET), Heimatregion | Engt Wertespannen ein, findet vereinslose Talente (siehe unten) |
| Sportpsychologe | Psychologie (PSY), Gesprächsführung (GES) | Mental-Schwankung × (1 − 0,25 × PSY/100), Burnout sinkt schneller, Lösungschance bei Konflikten + GES/4 % |

**Scouting-Formel:** Ein ungescouteter Spieler zeigt jeden Wert als Spanne von ±15. Pro Woche Beobachtung schrumpft sie:

```latex
Spanne_{neu} = Spanne \cdot \left(1 - 0{,}25 \cdot \frac{URT}{100}\right), \quad \text{minimal } \pm 2
```

Ein Scout mit URT 80 braucht so rund 9 Wochen von ±15 auf ±2. Außerhalb seiner Heimatregion arbeitet er halb so schnell. NET bestimmt, wie viele unbekannte Talente pro Woche in seinen Berichten auftauchen (1 + NET/25).

**Gehalt:** Staff fordert 20.000 € × 1,08^(Schnitt − 50) pro Jahr. Ein Mitarbeiter mit Schnitt 80 kostet so rund 200.000 €. Wie viele Mitarbeiter ein Team halten kann, hängt nur am Budget.

### Weltentwicklung und KI-Manager

Die Welt verändert sich für alle Teams nach denselben Regeln wie für dein eigenes. Training, Alterung, Traits, Verträge, Konflikte und SoloQ laufen jede Woche für alle rund 3.000 Spieler. Das kostet kaum Rechenzeit, weil es derselbe Code ist. Der eigentliche Designaufwand liegt bei den KI-Managern, die Transfers machen.

**Vorstandsprofil:** Jedes KI-Team hat ein Profil, das seine Entscheidungen färbt: Titeljagd (kauft fertige Stars), Talentschmiede (setzt auf junge Spieler mit hohem POT), Sparkurs (hält das Budget, verkauft Stars) oder Heimatverein (bevorzugt Spieler der eigenen Sprache).

**Transferfenster:** Das Hauptfenster liegt in der Offseason, ein kleines vor Spring und vor Summer.

**Bedarf pro Rolle:** Die KI prüft jede Rolle:

```latex
Bedarf_r = \max(0,\ OVR_{Ziel} - OVR_{eff,r}) + 5 \cdot [Alter \geq 28] + 5 \cdot [Vertrag\ endet]
```

OVR\_Ziel hängt an Liga und Vorstandsprofil. Die KI bietet für den Kandidaten mit dem besten Verhältnis aus OVR-Gewinn und Preis, wenn er die Rolle um mindestens 3 OVR verbessert und ins Budget passt. Import-Regeln (zum Beispiel höchstens 2 Nicht-Residenten im Line-up) stehen pro Liga in den Daten. Nach 4 Jahren in einer Region gilt ein Spieler dort als Resident.

**Entscheidung des Spielers:** Jeder Spieler bewertet ein Angebot mit einem Nutzen:

```latex
U = 0{,}35 \cdot Gehalt + 0{,}30 \cdot Teamst\ddot{a}rke + 0{,}20 \cdot Spielzeit + 0{,}15 \cdot Heimat
```

Alle Teile laufen von 0 bis 1. Junge Spieler gewichten Spielzeit doppelt, Spieler ab 28 gewichten Heimat und Gehalt stärker. Er nimmt das Angebot mit dem höchsten U, wenn es über seinem aktuellen Team liegt.

**Rücktritte und Rookies:** Ab 27 Jahren hat jeder Spieler pro Offseason eine Rücktrittschance von 4 % pro Jahr über 26, plus 20 %, wenn kein Team ihm einen Vertrag anbietet. Jede Region erzeugt pro Jahr so viele neue 16- bis 17-jährige SoloQ-Talente, wie Spieler zurückgetreten sind, plus 5 %.

**Prüfung im Prototyp:** Zehn Saisons laufen ohne menschlichen Spieler durch. Ziele sind: Der Liga-Schnitt bleibt innerhalb von ±2 OVR stabil. Jedes Team wechselt pro Jahr 1–2 Starter. Rund 8 % der Spieler treten pro Jahr zurück. Kein Team gewinnt mehr als 3 Titel in Folge häufiger als in 1 von 10 Durchläufen.

### Historie

Am Ende jedes Splits, Turniers und jeder Saison speichert das Spiel einen Schnappschuss. Die echten Werte zu speichern ist billiger und genauer, als sie später aus Teamergebnissen abzuleiten.

| Ebene | Was gespeichert wird |
| --- | --- |
| Spieler | Team, Rolle, OVR, alle Werte, Traits, Form, Spiele, K/D/A, Bewertung im Schnitt, MVPs, Top-3-Champions, Auszeichnungen |
| Team | Line-up, OVR im Schnitt, Chemistry, Coach, Platzierung, Siege und Niederlagen, Titel |
| Liga und Turnier | Tabelle, Bracket, Finals, Pick- und Banraten pro Champion, Meta-Tiers des Patches |

Das sind rund 7 Schnappschüsse pro Saison mit je etwa 30 Werten pro Spieler, zusammen 1–3 MB pro Saison. Daraus entstehen Karriereverläufe, All-Time-Statistiken, eine Hall of Fame und Auszeichnungen wie Split-MVP, All-Pro-Teams und Rookie des Splits.

## Standarddatenbank: erste Teams und Spieler

Die Standarddatenbank (Teams, Kader, Werte, Traits, Coaches) lebt im [Simulator](https://claude.ai/artifact/XvmGdYHrTw5KKyvjQdMkFw), nicht in diesem Dokument. Unter **Daten** lässt sie sich je Liga oder komplett als zwei CSV-Dateien exportieren (Teams mit Coach und Start-Chemistry, Spieler mit allen Rohwerten inklusive Charisma und Potential) und nach dem Bearbeiten wieder importieren. Hier stehen nur die Regeln, nach denen die Datenbank aufgebaut ist.

**Aufbau der Welt:**

- Alle Teams und Spieler sind fiktiv. Realnamen sind optional und können per CSV ergänzt werden.
- Tier-1-Ligen: LEC, LCS, CBLOL (mit argentinischen Teams und einzelnen Venezolanern), LPL, LCP und LCK. Spieler und Teamnamen folgen der Kultur der Region; koreanische Importspieler gibt es in allen Ligen, in der LEC nur wenige.
- In Korea tragen Teams Namen fiktiver Konzerne mit augenzwinkernden Firmennamen. Byeol Nebula und DT Signal sind die großen Rivalen.
- Spanische und französische Spieler sitzen vor allem in Tier 2 (LES, LFL).
- Tier 3 enthält die Community-Teams aus dem Discord und das Seniorenteam Silberrücken.
- Rund 95 % der Spieler in EMEA sprechen Englisch.
- Spielerinnen sind über eine Einstellung optional, auch ein komplettes Frauenteam ist möglich.

**Doppelrolle:** Eine Person kann zugleich Spieler und Staff sein. caedral hat Coaching-Erfahrung in Tier 1 und 2 und steht deshalb auch auf dem Mitarbeitermarkt: DRA 74, DEV 70, MOT 72, TAC 80, MAN 68, REP 82, Trait Spieler-Versteher. Wird er als Coach angeheuert, beendet er seine aktive Karriere. Das gilt allgemein für ältere Spieler mit hohem Macro und Charisma.

**Spielerinnen:** Geschlecht ist ein Datenfeld ohne Einfluss auf die Werte. Der Generator macht rund 8 % der neuen Spieler zu Spielerinnen. Zusätzlich sorgt er dafür, dass es in jeder Region pro Rolle mindestens 3 Spielerinnen gibt, in Teams oder vereinslos in der SoloQ. So lässt sich in jeder Region ein komplettes Frauenteam zusammenstellen. Spielerinnen sind eine Einstellung, standardmäßig an. Ist sie aus, erzeugt der Generator keine Spielerinnen und Trainerinnen. Die Spielerinnen der Standarddatenbank werden dann mit gleichen Werten und Gamertags als Spieler geführt, ihre Realnamen werden neu erzeugt.

### Coaches und Staff

Nicht jedes Team hat einen vollen Staff. Titeljäger leisten sich bis zu fünf Mitarbeiter, Sparkurs-Teams nur einen Head Coach. Marshmallowfunk hat in Tier 3 gar keinen. Ohne Head Coach gelten alle Coachwerte als 30. Die naheliegende Verstärkung wäre caedral.

### Namenspool

| Art | Noch freie Namen |
| --- | --- |
| Koreanische Kultur | Mugunghwa |
| Aus dem Chinesischen | Longjing |
| Vom Realnamen abgeleitet | TaeTae, MinJ, Haobro, KaiKai, Yutongg, Dohyunn |
| Aus dem Englischen | Ashfall, Lowtide, Sundial, Overcast |

Die übrigen Pool-Namen sind in den Tier-1-Kadern vergeben.

Der Generator nutzt dieselben vier Muster für neue Spieler: Kulturbegriffe der Herkunftsregion, Lehnwörter, Spielereien mit dem Realnamen (Verdopplung, Kürzel, angehängte Buchstaben) und englische Wörter.

Vor einer Veröffentlichung werden alle Namen mit Leaguepedia abgeglichen, damit kein fiktiver Spieler oder Coach wie ein echter heißt. Kurze englische Wörter wie Apex oder Echo sind dabei am anfälligsten.

### Namensabgleich mit Leaguepedia

Alle Gamertags, Staff-Namen, Teamnamen und der Namenspool wurden am 15.11.2026 mit den Tabellen Players und PlayerRedirects von [Leaguepedia](https://lol.fandom.com) abgeglichen. Amateure ohne Leaguepedia-Seite sind darin nicht erfasst.

**Ersetzt (generierte Namen und Pool):** 48 Treffer: 31 Spieler, 8 Staff-Namen und 9 Pool-Namen. Tatu und Crown waren schon vorher ersetzt. Alle Ersatznamen wurden erneut geprüft und sind frei. Die Teamnamen hatten keine Treffer.

**Offen (deine eigenen Spieler):** Diese Namen gibt es schon. Die Entscheidung, ob sie bleiben, liegt bei dir.

| Name | Team | Treffer auf Leaguepedia |
| --- | --- | --- |
| Joker | Cloud 7 | Coach aus Korea, Top aus Vietnam |
| Lotus | Longteng Dragonforge | 5 Treffer in Europa, Asien und Kanada |
| Tempest | Longteng Dragonforge | Mid aus den USA, Bot aus Mexiko |
| Thanos | Cloud 7 | Bot aus den USA |
| Cipher | DT Signal | Mid aus dem Libanon |
| Reign | Byeol Nebula | Coach aus Chile (ReigN) |
| Zeph | Byeol Nebula | Coach aus Frankreich |
| Crest | Byeol Nebula | Coach aus Italien |

Vier Namen mit Treffern in derselben Region oder bei bekannten Spielern sind umbenannt: hype heißt jetzt HypeTrain, Eclipse Yueshi („Mondfinsternis“), Raven Wuya („Rabe“) und Titan Taishan (der heilige Berg Tai). Die übrigen acht bleiben, weil die Treffer unbekannte Amateure aus anderen Regionen sind.

Ohne Treffer: yawn, CrownGG, Gumigo, Shyraa, caedral, Drift, Onyx. Die Namen von Marshmallowfunk sind eure eigenen Handles und bleiben unabhängig von Treffern.

## CSV-Import

Die gesamte Welt wird aus sieben CSV-Dateien geladen. Die Standarddatenbank mit fiktiven Teams nutzt dasselbe Format. Wer echte Teams will, ersetzt oder ergänzt die Dateien.

**Regeln:**

- Trennzeichen ist das Komma, Listen innerhalb eines Feldes werden mit Semikolon getrennt.
- Die `id` verknüpft die Dateien. Gleiche `id` wie in der Standarddatenbank überschreibt, neue `id` fügt hinzu.
- Fehlende Werte werden generiert. Fehlen zum Beispiel `charisma` oder `potential`, würfelt das Spiel passend zu Alter und OVR.
- Rollen sind `TOP`, `JGL`, `MID`, `ADC`, `SUP`. Jedes Team braucht mindestens einen Spieler pro Rolle und höchstens 8 Spieler.
- Beim Import prüft das Spiel alles und zeigt eine Fehlerliste mit Zeilennummern, statt abzustürzen.

**teams.csv**

```csv
id,name,short,league_id,language,budget,reputation,fans,coach_id
T01,Nordlicht Esports,NLE,L01,en,2500000,72,180000,C01
T02,Iron Wolves,IWV,L02,de,600000,61,45000,C02
```

**players.csv** (champ\_pool als Champion:Mastery, traits als Liste)

```csv
id,name,nickname,team_id,role,age,gender,language,english,mechanics,laning,macro,teamwork,mental,reputation,charisma,potential,traits,champ_pool
P001,Jonas Berg,Frostbite,T01,MID,22,m,de,85,85,80,75,60,70,68,55,88,Clutch Player;Lane Bully;Carry,Azir:92;Orianna:88;Sylas:80
P002,,Shyraa,,MID,23,f,de,85,72,70,60,62,66,70,90,78,Fan Favorite;Medienprofi,Akali:85;LeBlanc:82;Qiyana:78
```

`name` (Realname) und `team_id` dürfen leer sein. Leere `team_id` bedeutet vereinslos in der SoloQ der Region, die aus der Sprache abgeleitet wird.

**staff.csv** (Coaches, Analysts, Scouts und Psychologen; Werte, die eine Rolle nicht hat, bleiben leer; language als Liste)

```csv
id,name,team_id,role,age,language,drafting,development,motivation,tactics,man_management,analysis,data,judgement,network,psychology,talk,reputation,traits
C01,Elena Haas,T01,head_coach,34,en,82,64,70,77,68,,,,,,,71,Meta-Leser
S01,Mateo Ruiz,T01,scout,41,es;en,,,,,,,,78,65,,,52,
```

**champions.csv** (role\_tags als Liste, archetypes als Archetyp:Gewicht)

```csv
id,name,role_tags,archetypes,meta_tier
CH01,Orianna,MID,Control:3;Teamfight:3;Scaling:2,A
CH02,Sejuani,JGL;TOP,Engage:3;Teamfight:2,S
```

**traits.csv** (Effekte als Schlüssel=Wert-Paare, damit neue Traits ohne Code entstehen)

```csv
id,name,type,condition,effects
TR01,Clutch Player,positive,high_pressure,mec=+5;mental_variance=x0.5
TR02,Lane Bully,positive,phase_laning,lan=+5
```

**leagues.csv** (parent = Liga, in die Talente aufsteigen; slots = Plätze bei First Stand, MSI, Worlds)

```csv
id,name,region,tier,parent_id,format,slots
L01,Nordic Champions League,EMEA,1,,double_rr_bo1,1;2;4
L02,Bundesliga Esports,EMEA,2,L01,double_rr_bo1,0;0;0
```

**chemistry.csv** (optional; Start-Chemistry einzelner Paare, alle anderen starten nach den normalen Regeln)

```csv
player_a,player_b,chemistry
P101,P102,80
P102,P103,80
```

In players.csv darf `language` eine Liste sein, zum Beispiel `en;ko`.

Im LoL-Fanprojekt liefert die Standarddatenbank echte Champion-Namen. In der späteren eigenen Version wird nur champions.csv ausgetauscht.

## Prototyp-Plan & offene Fragen

Der erste Meilenstein ist kein Spiel, sondern ein Simulator: Zwei Teams aus CSV laden, ein Match simulieren und 10.000 Matches für die Kalibrierung laufen lassen. Erst wenn die Zahlen stimmen, lohnen sich Menüs.

1. **Sim-Kern im Web:** Eine HTML-Seite mit JavaScript. Sie lädt die CSV-Dateien, simuliert ein Match und zeigt Gold-Graph, Event-Log und Bewertungen. Ein Batch-Knopf rechnet die Kalibrierungstabelle. Erledigt am 15.11.2026.
2. **Saison-Loop:** Liga mit 10 Teams, Wochentakt, Form, Chemistry, Training und Playoffs. Noch ohne Transfers. Erster Stand am 15.11.2026 im Simulator: alle Tier-1-Ligen spielbar, Formate nach den echten Ligen 2026: LCK mit Runden 1–2 (doppelte Runde aller Teams) und Runden 3–4 in Legend und Rise Group, LPL mit Ascend und Nirvana Group, LEC, LCS, CBLOL und LCP mit einfacher Runde im Bo3 (LEC Versus und CBLOL Cup im Bo1). Top 6 in Bo5-Playoffs, Auszeichnungen für Split-MVP, All-Pro-Team, Rookie und größte Steigerung. Form reagiert verstärkt auf Bewertungen, Siege und Serien (Spanne zwischen Teams rund 30 Punkte), wirkt aber nur mit 1 Wertepunkt je 12 Formpunkte. Chemistry sinkt nach verlorenen Serien (Man-Management dämpft das, unter 50 bröckelt sie langsamer). Werte schwanken wöchentlich leicht. Bewertungen sind nach oben gestaucht (Sieger rund 77, Verlierer 65). Spieleransicht mit Werteverlauf und Trait-Tooltips. Noch nicht enthalten: Burnout, Konflikte, Meta-Patches, Wochenplan pro Spieler.
3. **GM-Modus:** Kader, Verträge, Coach, Transfermarkt und Vorstandsziele.
4. **Career-Modus:** Eigener Spieler, Wochenentscheidungen, Interviews, Vertragsangebote.
5. **Port nach Godot 4:** Der Sim-Kern wird 1:1 in GDScript übertragen. Die CSV-Dateien bleiben unverändert. Danach kommen UI, Speicherstände und Feinschliff. Erledigt am 20.11.2026: Match-Simulation, Saison-Loop und Playoffs 1:1 portiert und gegen Referenz-Seeds geprüft, dazu Match- und Saison-Bildschirm mit Turnierbaum.
6. **Welt und Jahresablauf:** Alle Ligen parallel im Wochenkalender, drei Splits, First Stand, MSI, Worlds, Offseason mit Alterung, Rücktritten und Rookies, Auf- und Abstieg, Speicherstände.

**Entscheidungen:**

| Thema | Entscheidung |
| --- | --- |
| Name | Rift Manager bleibt |
| Draft | Einstellung: selbst draften mit Coach-Notizen oder der Coach draftet |
| Match-Darstellung | Zuerst Gold-Graph und Event-Log, später eine einfache 2D-Minimap |
| Meta-Patches | Ein Patch pro Monat |
| Burnout | Einstellung, standardmäßig an |
| Tier-1-Modell | Einstellung mit drei Stufen: Geschlossen, Wie 2026 (Standard), Offen. Tier 2 und 3 haben immer Auf- und Abstieg, je nach Region geregelt (siehe Jahresablauf) |
| Formate | Einstellung: Originalgetreu wie 2026 (Standard) oder Einheitlich, als Presets in den Daten |
| Alterung | Ab Ende 20 sinkt zuerst MEC, LAN schwächer; MAC, TEA, MEN wachsen; Trait Langlebig für Ausnahmekarrieren |
| Nachwuchs | Rookies regelmäßig generiert, zusätzlich Aufstieg aus der SoloQ |
| Spielerinnen | Einstellung, standardmäßig an |
| Regionen | Sieben Regionen mit bis zu drei Stufen, rund 290 Teams (siehe Regionen und Ligen) |
| Konflikte | Einfache Ereignisse mit Folgen für Werte, im schlimmsten Fall Bank oder Wechselwunsch (siehe Konflikte) |
| Career-Start | Vereinslos in der SoloQ, Tryouts bei Tier-3-Teams |
| SoloQ | Eigene Ladder pro Region mit allen Spielern, Grundlage fürs Scouting |
| Scouting | Ungescoutete Werte als Spanne, eigener Scout im Staff |
| Staff | Markt für Head Coach, Assistant Coach, Analyst, Scout und Sportpsychologe; nicht jedes Team hat vollen Staff |
| Weltentwicklung | Alle Teams entwickeln sich nach denselben Regeln, KI-Manager machen Transfers |
| Historie | Schnappschüsse nach jedem Split, Turnier und jeder Saison |

**Noch offen:**

- [x] Teams für LPL, LEC und die anderen Regionen: welche du selbst gestalten willst und welche der Generator übernimmt.
- [x] Namensabgleich mit Leaguepedia vor der ersten öffentlichen Version.
