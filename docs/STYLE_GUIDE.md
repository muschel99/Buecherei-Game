# Stil-Leitfaden (seit Etappe 4g)

Grundlage: die Bildersammlung in `Game design/` (Ordner *Stilrichtung* = Konzeptbilder einzelner
Häuser und der Straße, Ordner *Inspiration* = Fotos typischer englischer Straßen). Die Figuren
(Bild „Charakter stil“) bleiben vorerst außen vor.

## Die Richtung in einem Satz
**Stilisierter Realismus:** echte Proportionen, echte Materialien und viele kleine, glaubwürdige
Details – aber ruhige, leicht vereinfachte Formen und weiche, warme Farben. Gemütlich, nicht
niedlich: keine Kulleraugen-Häuser, keine schiefen Comic-Wände, keine knalligen Bonbonfarben.

## Was die Bilder gemeinsam haben
- Englische Ladenstraße des 19. Jahrhunderts: Reihenhäuser aus **rotem Backstein**, hellem
  **Sandstein** und **Putz in warmen Cremetönen**, dazwischen **Fachwerk** (Torhaus, Gasse).
- **Ladenfronten aus lackiertem Holz** in tiefen Farben (Marineblau, Flaschengrün, Pflaume,
  Schwarz) mit Pilastern, Konsolen, Schild mit **goldener Schrift**, Sprossen-Oberlichtern,
  Brüstungen mit Füllungen und oft **gestreiften Markisen**.
- Obergeschosse mit **Schiebefenstern** (weiße Rahmen, Sprossen, helle Vorhänge),
  Fensterbänken und Verdachungen aus Stein.
- **Schieferdächer** (blaugrau) oder **Tonziegel** (rotbraun) mit **Gauben**,
  **Schornsteinen** mit Tonaufsätzen, Regenrinnen und Fallrohren.
- Straßenraum: **Kopfsteinpflaster**, große Gehwegplatten, Bordsteine, gusseiserne Laternen,
  Blumenkübel, Hängekörbe, Kreidetafeln. (Laternen und Blumen sind neue Objekte – kommen
  später, wenn wir sie einplanen.)
- Licht: **warmes, tief stehendes Sonnenlicht** (goldene Stunde), warme Schaufenster.

## Regeln für alle Modelle
1. **Der Grundriss im Spiel bleibt.** Breite, Tiefe und Traufhöhe jedes Haustyps (und die
   Lage im Plan) ändern sich nicht. Passt ein Konzeptbild nicht dazu, wird das Design
   angepasst, nicht der Plan (Beispiel Modegeschäft: Konzept etwa 7 m breit, im Spiel 5,4 m –
   der Ziergiebel ist schmaler, die Gauben kleiner, die Tür mittig in einer flachen Nische).
2. **Echte Maße:** Ziegel 21,5 × 6,5 cm, Stockwerke gut 3 m, Türen 2,1–2,3 m, Fenster etwa
   0,9 × 1,6 m, Dachneigung etwa 35°.
3. **Tiefe statt Fläche:** Fenster sitzen in Laibungen (12–15 cm tief), Rahmen und Gesimse
   stehen vor, Ladenfronten sind ein eigenes Bauteil vor der Wand. Das macht den Unterschied
   zwischen „Kulisse“ und „Haus“.
4. **Wenige, gemeinsame Materialien:** alles aus den Stil-Texturen
   (`assets/textures/style/`, 20 Ebenen). Kein Modell bringt eigene Bilder mit.
5. **Farben je Haus** kommen weiter aus Godot (Wandfarbe, Türfarbe, Akzentfarbe): Die Wand
   eines Hauses ist z. B. Sandstein, die Farbe sagt, welcher Ton. Ladenfront und Haustür =
   Türfarbe, Markise und Schild-Akzente = Akzentfarbe.
6. **Leistung:** ein Haus = ein Zeichenaufruf (+1 für Schaufensterglas). Etwa 5.000–15.000
   Dreiecke je Haus. Was man nie sieht (Rückseite), bleibt schlicht.
7. **Kleine Unregelmäßigkeiten** gehören dazu (Steine leicht verschieden, etwas Flechte auf
   dem Dach), aber nichts ist schief oder krumm gebaut.

## Läden von innen
- Wer durch Tür oder Schaufenster schaut, sieht einen ganzen Raum – nie ins Leere.
- **Dezent vintage:** wenige, gut gewählte Dinge statt Fülle; warme Hölzer, Messing, gedeckte
  Farben (Salbei, Altrosa, Senf, Petrol, Creme), ein Samt-Akzent.
- Innenräume leuchten leicht von selbst (Material-Leuchten statt Lampen-Licht), damit sie
  von der Straße warm wirken und nichts durch Wände strahlt.
- Ware (Kleidung …) ist austauschbar: eigene kleine Szenen, Farbe je Stück.

## Farbpalette (Richtwerte, sRGB)
| Was | Farbe |
|-----|-------|
| Backstein rot / braun | (0.6, 0.33, 0.25) / (0.5, 0.3, 0.24) |
| Sandstein, Putz creme | (0.9, 0.86, 0.8) / (0.86, 0.8, 0.68) |
| Stein-Zierteile | (0.81, 0.77, 0.67) |
| Ladenfront Marineblau | (0.1, 0.13, 0.21) |
| Ladenfront Flaschengrün | (0.12, 0.24, 0.18) |
| Weiße Fensterrahmen | (0.93, 0.92, 0.88) |
| Schiefer | (0.25, 0.27, 0.31) |
| Gold (Schrift, Beschläge) | (0.85, 0.66, 0.3) |

## Pläne für die einzelnen Häuser
| Haustyp | Vorbild | Umsetzung |
|---------|---------|-----------|
| `fashion_shop` | Konzept „fashionshop“ | **fertig (4g, Teil 1/1b):** „Zwirn und Zwirbel“, leicht vintage: marineblaue Ladenfront, verspielte Goldschrift mit Faden-Kringel, Markisen, Ausleger-Schild, Hängekorb, Blumenkästen, verschiedene Deko links/rechts, ganzer Ladenraum, Puppen und Kleidung als Platzhalter |
| `pub` | Inspiration „Westminster Arms“, „O'Brian's“ | dunkelgrüne Pub-Front mit großen Sprossenfenstern, Laternen, Hängekörbe, Ziegel darüber |
| `gatehouse` | Konzepte Torhaus (Ziegelbogen + Fachwerk) | Ziegel-Rundbogen mit hellen Bogensteinen, Fachwerk-Obergeschoss, Gaube |
| `terrace_*` | Inspiration Straßenfotos | Mischung aus Backstein, Putz und Rauputz; Schiebefenster, Haustür mit Oberlicht, teils Ladenfront |
| `residential` | – | Wohnhaus mit Vordach und Säulchen, Backstein |
| `corner_*` | Konzept „flowershop“ | Eckladen mit Ladenfront in der Schräge |
| Bücherei | Konzept „Bookstore“, „The Book Nook“ | Ladenfront in der Schräge, Schild, Sprossenfenster |
