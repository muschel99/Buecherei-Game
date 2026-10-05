# Eigene Grafik und Sounds einbauen

Alle Objekte im Spiel bestehen im Moment aus einfachen Platzhaltern (Kisten, Zylinder, Farben).
Sie sind so gebaut, dass du sie später leicht durch eigene Dateien ersetzen kannst.

## Wohin mit meinen Dateien?
| Art             | Ordner                  | Formate             |
|-----------------|-------------------------|---------------------|
| 3D-Modelle      | `assets/models/`        | `.glb` (empfohlen)  |
| Texturen        | `assets/textures/`      | `.png`, `.jpg`      |
| Materialien     | `assets/materials/`     | `.tres` (Godot)     |
| Musik           | `assets/audio/music/`   | `.ogg`              |
| Geräusche       | `assets/audio/sfx/`     | `.ogg`, `.wav`      |

Dateien einfach in den passenden Ordner kopieren. Godot erkennt sie automatisch.

## Ein neues Möbelstück anlegen (ohne Code)
Jedes Möbelstück im Katalog besteht aus zwei Teilen:
- einer **Szene** oder einem **3D-Modell** (wie es aussieht), z. B. `scenes/furniture/table_bistro.tscn`
  oder direkt eine `.glb`-Datei aus `assets/models/`,
- einem **Datenblatt** in `data/furniture/` (Name, Preis, Stil usw.), z. B. `table_bistro.tres`.

Der Katalog liest den Ordner `data/furniture/` beim Spielstart automatisch ein.
Ein neues Datenblatt dort = ein neues Möbelstück im Katalog.

**Am einfachsten: ein vorhandenes Datenblatt kopieren**
1. Im **Dateisystem**-Fenster (unten links) den Ordner `data/furniture/` öffnen.
2. Rechtsklick auf ein ähnliches Datenblatt (z. B. `table_bistro.tres`) → **Duplizieren…**
   → neuen Dateinamen eingeben, z. B. `table_marble.tres` (klein, englisch, Unterstriche statt Leerzeichen).
3. Das neue Datenblatt anklicken. Rechts im **Inspektor** erscheinen die Felder:

| Feld                  | Bedeutung                                                                 |
|-----------------------|---------------------------------------------------------------------------|
| Id                    | Eindeutiger Name, z. B. `table_marble`. Später nicht mehr ändern (Spielstand!) |
| Display Name          | Name im Katalog, z. B. „Marmortisch“                                       |
| Description           | Kurzer Text, erscheint, wenn die Maus über der Karte steht                |
| Category              | Reiter im Katalog (Regale, Sitzmöbel, Tische, Theke, Beleuchtung …)       |
| Price                 | Preis in Talern (wird ab Etappe 5 abgezogen)                              |
| Styles                | Häkchen bei Botanisch, Modern und/oder Dark Academia                      |
| Scene Path            | Die Szene (`.tscn`) oder das Modell (`.glb`) – mit dem Ordner-Symbol auswählen |
| Footprint             | Grundfläche in Rasterfeldern: x = Breite, y = Tiefe. 1 Feld = 0,25 m, 4 Felder = 1 m |
| Is Unlocked           | Häkchen = erscheint im Katalog                                            |
| Can Stand On Surfaces | Häkchen = darf auch auf Tischen und Regalbrettern stehen (für Deko)       |
| Has Surface           | Häkchen = andere Deko darf darauf gestellt werden (Tische, Regale)        |

4. Mit **Strg+S** speichern und das Spiel starten (F5). Das Möbelstück ist im Katalog.

**Eine neue Möbel-Szene bauen:** Am einfachsten eine vorhandene Szene in `scenes/furniture/`
duplizieren und die Optik unter `Model` austauschen (siehe nächster Abschnitt).
Wichtig: Der Fußpunkt (Höhe 0) ist der Boden, die Vorderseite zeigt in Richtung **+Z**
(im Editor: die blaue Pfeilrichtung).

**Nur eine .glb-Datei?** Geht auch: Bei „Scene Path“ direkt die `.glb`-Datei auswählen.
Das Spiel legt dann automatisch eine Kollisions-Kiste in Größe des Modells an.
Für Regale ist eine eigene Szene besser, damit jedes Regalbrett eine eigene Kollision bekommt
(sonst kann man keine Deko hineinstellen).

## Eigene Wandfarben und Böden
Wandfarben und Böden funktionieren genauso – ihre Datenblätter liegen in `data/surfaces/`.
Felder: Id, Display Name, **Kind** (Wall = Wandfarbe, Floor = Boden), Price, Styles,
**Material** (das Aussehen) und **Preview Color** (Farbe des Feldes im Katalog).

So nutzt du eine eigene Textur:
1. Bild (z. B. `oak_planks.png`) nach `assets/textures/` kopieren.
2. Im Dateisystem Rechtsklick auf `assets/materials/surfaces/` → **Neu erstellen → Ressource…**
   (je nach Version heißt der Menüpunkt auch nur „Neu“) →
   `StandardMaterial3D` wählen → speichern, z. B. als `floor_my_planks.tres`.
3. Das Material anklicken. Im Inspektor bei **Albedo → Texture** dein Bild hineinziehen.
   Unter **UV1** das Häkchen **Triplanar** setzen und bei **Scale** die Kachelgröße einstellen
   (z. B. 0,5 = Textur wiederholt sich alle 2 Meter).
4. Ein vorhandenes Datenblatt in `data/surfaces/` duplizieren, Id und Namen ändern und
   bei **Material** dein neues Material hineinziehen. Fertig.

Die Platzhalter-Muster (Dielen, Schachbrett, Streifen) kommen aus dem Shader
`assets/shaders/surface_pattern.gdshader`. Bei diesen Materialien kannst du im Inspektor unter
**Shader Parameters** Farben, Muster und Größe verändern.

## Ein Möbelstück durch ein eigenes Modell ersetzen
Jede Möbel-Szene (z. B. `scenes/furniture/armchair.tscn`) hat diesen Aufbau:
```
Armchair        (Wurzel-Knoten)
├── Model       ← nur die Optik: hier kommt dein Modell hin
└── Body        ← die Kollision (damit man nicht durchlaufen kann)
```
1. Doppelklicke die Möbel-Szene im **Dateisystem**-Fenster (unten links), um sie zu öffnen.
2. Lösche alle Kinder des Knotens `Model` (die grauen Platzhalter-Kisten).
3. Ziehe deine `.glb`-Datei aus dem Dateisystem auf den Knoten `Model`.
4. Passe bei Bedarf Größe und Position an. Der Boden ist bei Höhe 0.
5. Passe im Knoten `Body > CollisionShape3D` die Kiste grob an die neue Form an.
6. Speichern mit **Strg+S**. Alle Exemplare im Raum ändern sich automatisch.

## Farben und Texturen von Wänden und Böden
Die Materialien liegen in `assets/materials/` (z. B. `wall_plaster.tres`, `floor_wood.tres`).
Doppelklicke ein Material, dann siehst du rechts im **Inspektor** die Eigenschaften:
- **Albedo > Color**: die Grundfarbe
- **Albedo > Texture**: hier eine Textur aus `assets/textures/` hineinziehen

Wände und Boden nutzen „Triplanar“-Mapping: Texturen werden automatisch gleichmäßig
über die Fläche gelegt. Die Kachelgröße stellst du unter **UV1 > Scale** ein.
