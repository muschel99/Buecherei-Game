# Eigene Grafik und Sounds einbauen

Alle Objekte im Spiel bestehen im Moment aus einfachen Platzhaltern (Kisten, Zylinder, Farben).
Sie sind so gebaut, dass du sie später leicht durch eigene Dateien ersetzen kannst.

## Wohin mit meinen Dateien?
| Art             | Ordner                  | Formate             |
|-----------------|-------------------------|---------------------|
| 3D-Modelle      | `assets/models/`        | `.glb` (empfohlen)  |
| Vorlagen        | `assets/models/templates/` | `.glb` (nur zum Modellieren, siehe unten) |
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
Ein neues Datenblatt dort = ein neues Möbelstück im Shop (kaufen, dann liegt es im Inventar).

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
| Subcategory           | Unterkategorie für die Filter, z. B. `armchair` (Sessel) – Auswahlliste passend zur Kategorie |
| Price                 | Preis in Talern im Shop (beim Verkaufen gibt es die Hälfte zurück)        |
| Styles                | Häkchen bei Botanisch, Modern und/oder Dark Academia – ohne Häkchen = stilneutral |
| Scene Path            | Die Szene (`.tscn`) oder das Modell (`.glb`) – mit dem Ordner-Symbol auswählen |
| Footprint             | Grundfläche in Rasterfeldern: x = Breite, y = Tiefe. 1 Feld = 1/9 m (≈ 11,1 cm), 9 Felder = 1 m |
| Icon                  | Eigenes Vorschaubild für den Shop (freiwillig) – leer = das Spiel fotografiert das Modell selbst |
| Is Unlocked           | Häkchen = erscheint im Shop                                               |
| Is Essential          | Gehört fest zur Bücherei (wie das Tablet): nicht im Shop, nicht verkaufbar |
| Placement             | Wo darf es hin? Häkchen bei Boden, Ablagefläche, Wand, Tür und/oder Decke |

4. Mit **Strg+S** speichern und das Spiel starten (F5). Das Möbelstück steht im Shop.

**Eine neue Unterkategorie anlegen** (z. B. „Leselampen“): In `scripts/data/furniture_data.gd`
ganz oben bei `SUBCATEGORIES` in der Zeile der Kategorie ein Paar ergänzen, z. B.
`["reading_lamp", "Leselampen"]` (erst eine kurze englische id, dann der Name im Spiel).
Danach steht sie im Datenblatt bei **Subcategory** zur Auswahl und erscheint als Filter.

**Ablageflächen festlegen:** Ob man Deko auf ein Möbelstück stellen kann, bestimmt seine Szene.
Jede Ablagefläche ist ein Knoten vom Typ **PlacementSurface** (z. B. unter dem Knoten `Surfaces`):
1. Szene öffnen, Rechtsklick auf den obersten Knoten → **Kind-Knoten hinzufügen** → `PlacementSurface`.
2. Den Knoten genau auf die Oberkante der Fläche schieben (z. B. die Tischplatte).
3. Ihm eine **CollisionShape3D** mit einer flachen **BoxShape3D** geben, so groß wie die Fläche
   (Höhe ca. 0,03 m).
Ein Möbelstück darf beliebig viele Ablageflächen haben (Sitzfläche, beide Armlehnen …).
Am einfachsten schaust du dir eine fertige Szene an, z. B. `scenes/furniture/armchair.tscn`.

**Dinge zum Aufhängen** (Wandbild, Türkranz, Lichtschalter): Hier liegt der Ursprung der Szene
hinten in der Mitte (dort, wo es die Wand berührt), die Vorderseite zeigt nach +Z.

**Eine neue Möbel-Szene bauen:** Am einfachsten eine vorhandene Szene in `scenes/furniture/`
duplizieren und die Optik unter `Model` austauschen (siehe nächster Abschnitt).
Wichtig: Der Fußpunkt (Höhe 0) ist der Boden, die Vorderseite zeigt in Richtung **+Z**
(im Editor: die blaue Pfeilrichtung).

**Lampen und Kerzen:** Damit sich etwas mit E an- und ausschalten lässt, an den obersten Knoten
der Szene das Script `scripts/objects/light_source.gd` hängen und einen `Interactable`-Knoten mit
Kollisionsform hinzufügen. Im Inspektor bei **Kind** „Electric“ (Lampe) oder „Flame“ (Kerze,
Laterne) wählen. Lichter und leuchtende Teile (Materialien mit „Emission“) findet das Script
selbst. Deckenlampen: Ursprung oben am Aufhängepunkt, die Lampe hängt nach unten; beim
Interactable das Häkchen **Long Reach** setzen.

**Sitzmöbel:** Einen Knoten `Seating` (Script `scripts/objects/seating.gd`) hinzufügen. Darunter für
jeden Sitzplatz einen `Marker3D` mit dem Script `scripts/objects/seat_point.gd` mitten auf die
Sitzfläche setzen (blaue Pfeilrichtung = nach vorn) und einen `Interactable` über der Sitzfläche.
Beispiel: `scenes/furniture/sofa_chesterfield.tscn` (drei Sitzplätze).

**Nur eine .glb-Datei?** Geht auch: Bei „Scene Path“ direkt die `.glb`-Datei auswählen.
Das Spiel legt dann automatisch eine Kollisions-Kiste in Größe des Modells an.
Für Regale ist eine eigene Szene besser, damit jedes Regalbrett eine eigene Kollision bekommt
(sonst kann man keine Deko hineinstellen).

## Eigene Wandfarben, Böden und Decken
Wandfarben, Böden und Decken funktionieren genauso – ihre Datenblätter liegen in `data/surfaces/`.
Felder: Id, Display Name, **Kind** (Wall = Wandfarbe, Floor = Boden, Ceiling = Decke), Price,
**Styles** (freiwillig – ohne Häkchen stilneutral), **Material** (das Aussehen) und
**Preview Color** (Farbe des Feldes im Shop und im Inventar) und **Owned At Start**
(Häkchen = von Anfang an vorhanden, muss nicht gekauft werden).
Die bisherigen Oberflächen sind alle stilneutral. Für ein besonderes Design (z. B. eine
Dark-Academia-Holzvertäfelung) einfach die passenden Stil-Häkchen setzen – dann zählt es mit.

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

Die Platzhalter-Muster (Dielen, Schachbrett, Streifen, Kassetten) kommen aus dem Shader
`assets/shaders/surface_pattern.gdshader`. Bei diesen Materialien kannst du im Inspektor unter
**Shader Parameters** Farben, Muster und Größe verändern.

## Bücher und Genres

### Ein Genre ändern oder ein neues anlegen (ohne Code)
Jedes Genre ist ein Datenblatt in `data/genres/` (z. B. `crime.tres` für Krimi).
1. Im **Dateisystem**-Fenster den Ordner `data/genres/` öffnen und ein Datenblatt anklicken
   (für ein neues Genre: Rechtsklick → **Duplizieren…**, z. B. `poetry_modern.tres`).
2. Rechts im **Inspektor** stehen die Felder:

| Feld              | Bedeutung                                                                    |
|-------------------|------------------------------------------------------------------------------|
| Id                | Eindeutiger Name, z. B. `crime`. Später nicht mehr ändern (Spielstand!)      |
| Display Name      | Name im Spiel, z. B. „Krimi“ – **hier umbenennen**                           |
| Description       | Kurzer Text im Shop                                                          |
| Spine Colors      | Farben der Buchrücken (mehrere; jedes Buch nimmt eine, leicht abgewandelt)   |
| Styles            | Passender Stil (freiwillig)                                                  |
| Price             | Preis eines Bücherpakets in Talern                                           |
| Is Unlocked       | Häkchen = freigeschaltet (im Shop und im Regal-Menü)                         |
| Sort Order        | Reihenfolge in Listen (kleiner = weiter vorn)                                |
| Books Path        | Bücherliste des Genres – leer = `data/books/<Id>.txt`                        |
| Cover Font        | Schriftart der Titel: Serif (klassisch), Sans (modern), Playful (verspielt)  |
| Cover Styles      | Passende Gestaltungen, z. B. `classic`, `picture` (mehrfach = häufiger)      |

3. **Strg+S** speichern. Wie viele Bücher in einem Paket stecken und wie viele Bücher es zum
   Start gibt, steht in `scripts/autoload/game_config.gd` (`books_per_package`,
   `start_books_per_genre`).

### Bücher ergänzen
Jedes Genre hat eine Bücherliste in `data/books/` (z. B. `crime.txt` für Krimi). Öffnen kannst
du sie in Godot mit Doppelklick oder in jedem Texteditor. Eine Zeile pro Buch:

```
Das Rätsel der verschwundenen Teekanne | teapot
```

- Vor dem Strich steht der Titel, dahinter das **Motiv** (das kleine Bild auf Cover und Rücken).
- Optional dahinter: `| Gestaltung | Autor`, z. B. `Mein Buch | moon | classic | Ada Wren`.
  Gestaltungen: `classic`, `picture`, `minimal`, `pattern`, `band`, `comic`.
  Leer = passend zum Genre (Feld **Cover Styles** im Genre-Datenblatt). Ohne Autor wird ein
  erfundener Name gewählt.
- Neues Buch = neue Zeile. **Titel bitte nachträglich nicht ändern** – der Titel ist der Name
  des Buchs im Spielstand (wird er doch geändert, bleibt das alte Buch mit altem Titel erhalten).
- Bitte nur erfundene, gemütliche Titel verwenden (deutsch oder englisch).
- Größe und Farben entstehen automatisch aus dem Titel (Spannweiten in `game_config.gd`:
  `book_height_range`, `book_thickness_range`, `book_depth_range`, `book_color_variation`).
- Hinweis für später: Beim Exportieren des fertigen Spiels müssen `.txt`-Dateien im
  Export-Dialog unter „Ressourcen → Filter“ mit `*.txt` eingeschlossen werden.

**Alle Motive** (Name so in die Liste schreiben):
`anchor`, `apple`, `balloon`, `bee`, `bicycle`, `bird`, `boat`, `book`, `bowl`, `bread`, `brush`, `butterfly`, `cactus`, `cake`, `candle`, `castle`, `cat`, `clock`, `cloud`, `compass`, `crown`, `dog`, `dragon`, `feather`, `fish`, `flower`, `fox`, `glasses`, `heart`, `hedgehog`, `hourglass`, `house`, `island`, `key`, `kite`, `lantern`, `leaf`, `lemon`, `letter`, `lighthouse`, `magnifier`, `map`, `moon`, `mountain`, `mushroom`, `music`, `owl`, `palette`, `pine`, `planet`, `plant`, `rabbit`, `rainbow`, `rocket`, `scroll`, `shell`, `snail`, `snowflake`, `sparkle`, `star`, `stars`, `sun`, `teacup`, `teapot`, `telescope`, `train`, `tree`, `tulip`, `umbrella`, `wave`, `whale`

Ein neues Motiv zeichnen: In `scripts/ui/book_motifs.gd` eine Funktion `_motif_<name>`
nach dem Vorbild der anderen ergänzen (Koordinaten von 0 bis 1). Danach kann der Name in
den Bücherlisten benutzt werden.

**Schriften:** Die Titel nutzen Schriften, die auf dem PC installiert sind (z. B. Noto Serif,
DejaVu Serif; ohne Serifen: Noto Sans, Cantarell; verspielt: Nunito, Comfortaa – fehlt eine,
nimmt Godot eine ähnliche). Welche Art ein Genre benutzt, steht im Genre-Datenblatt bei
**Cover Font** (Serif, Sans, Playful). Die Listen der Schriftnamen stehen oben in
`scripts/autoload/book_art.gd`.

### Ein Bücherregal bauen
Ein Regal bekommt Bücher, wenn seine Szene einen Knoten `BookShelf`
(Script `scripts/objects/book_shelf.gd`) hat. Vorlage: `scenes/furniture/bookshelf.tscn`.
- Darunter je Fach ein `Marker3D` mit dem Script `scripts/objects/book_row.gd`. Der Marker liegt
  **mitten auf dem Regalbrett** (Mitte der Breite und Tiefe, genau auf der Oberkante). Im
  Inspektor: **Width** (nutzbare Breite), **Height** (lichte Höhe bis zum nächsten Brett),
  **Depth** (Tiefe des Bretts). Befüllt wird in der Reihenfolge im Szenenbaum.
- Ein `Interactable` **ohne** Kollisionsform: Man trifft das Regal über seinen festen Körper
  (`Body`). So bleibt Deko im Regal (z. B. eine Kerze) mit E erreichbar.
- Bretter mit Büchern brauchen keine eigene Ablagefläche: Das Regal legt für jedes Fach
  automatisch eine an (so hoch, wie **Height** angibt) – darauf passt kleine Deko neben die
  Bücher. Das obere Brett (über allen Fächern) darf eine normale `PlacementSurface` haben.
- Ein Genre-Schild gibt es nicht mehr: Das Genre erscheint als Schriftzug, wenn man das Regal
  anschaut.
- Eigene Buch-Modelle sind nicht nötig: Bücher sind gestreckte Würfel mit dem Shader
  `assets/shaders/book_spine.gdshader` (Rücken aus dem Atlas, den `BookArt` beim Start
  zeichnet). Die Farbe der Seiten kann man dort ändern.
- Flächen zweier Teile nie genau in derselben Ebene enden lassen (sonst flimmert die Kante,
  „Z-Fighting“) – die kleinere Fläche lieber 2 mm nach innen setzen.

### Kleine Deko für Regale
Jede Deko mit Häkchen bei **Ablagefläche** passt auf Regalbretter, wenn sie niedriger ist als das
Fach (z. B. unter 0,42 m). Breite und Tiefe bestimmt der umgebende Quader des Modells – danach
richten sich die Bücher. Beispiele zum Abschauen: `bookend_wood.tscn`, `bookend_concrete.tscn`
(Unterkategorie „Buchstützen“), `succulent_mini.tscn`, `photo_frame.tscn`, `globe_small.tscn`,
`candle_jar.tscn` (Kerze mit `LightSource`, ohne Schatten), `vase_lavender.tscn`.

### Rückgabekasten (fest in der Hauswand)
Szene `scenes/objects/return_box.tscn` (Ursprung = Mitte der Wand am Boden, +Z zeigt in den
Raum, die Wand ist 20 cm dick):
- `Inside` = die Klappe innen (nur Optik, darf durch ein eigenes Modell ersetzt werden).
- `SlotPoint` = wo außen der Einwurf sitzt (die gewählte Variante kommt dort hinein).
- `Body` (Kollision der Klappe), `Interactable` (E/Rechtsklick), `KeepClear` (Bereich davor,
  der frei bleibt) und `DropPoint` (wo später Besucher davor stehen) müssen bleiben.

**Neuer Einwurf (ohne Code):**
1. Eine kleine Szene in `scenes/objects/return_slots/` bauen (Beispiele: `slot_plain.tscn`,
   `slot_flap.tscn`, `slot_plaque.tscn`): Vorderseite zeigt nach +Z (zur Straße), Ursprung
   hinten in der Mitte (dort, wo es an der Hauswand anliegt). Nur Optik, keine Kollision.
2. Ein Datenblatt in `data/return_slots/` anlegen (am einfachsten eines kopieren): `id`,
   `display_name` (Name in der App „Fassade“), `scene_path`, `order` (Reihenfolge), freiwillig
   `icon` (eigenes Vorschaubild, sonst wird das Modell fotografiert).
3. Fertig – die App „Fassade“ zeigt die neue Variante von selbst.

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

## Vorlagen zum Modellieren
Für jedes Möbelstück, jeden Haustyp, das Gassenende, die Eingangstreppe und (seit Etappe 5a)
den Lieferwagen, das Auto, das Fahrrad und einen Passanten gibt es eine
schlichte **Vorlage** als `.glb`-Datei – in echter Größe (1 Einheit = 1 Meter) und genau so
gelegen wie im Spiel. Darauf (oder daneben) modellierst du dein eigenes Modell; dann passt es
später ohne Verschieben oder Skalieren.

| Was            | Ordner                                   | Dateiname                     |
|----------------|------------------------------------------|-------------------------------|
| Möbel und Deko | `assets/models/templates/furniture/`     | Id des Möbelstücks, z. B. `armchair_velvet.glb` |
| Häuser         | `assets/models/templates/houses/`        | Haustyp, z. B. `pub.glb`      |
| Gassenende, Treppe | `assets/models/templates/world/`     | `alley_end.glb`, `entrance_steps.glb` |
| Straßenleben   | `assets/models/templates/street_life/`   | `delivery_van.glb`, `car.glb`, `cyclist.glb`, `passerby.glb` |

Der Ordner `templates` enthält eine leere Datei `.gdignore`: Godot zeigt ihn darum im
Dateisystem-Fenster nicht an und lädt die Vorlagen nicht ins Spiel. Du öffnest sie über den
Dateimanager: `~/Buecherei-Game/assets/models/templates/`.

**In Blender:**
1. **Datei → Importieren → glTF 2.0 (.glb/.gltf)** und die Vorlage wählen.
2. Nicht verschieben, drehen oder skalieren: Der Ursprung (Nullpunkt) ist derselbe wie im Spiel.
   Die Vorderseite zeigt in Blender nach **-Y** – das ist die Seite, die du in der
   **Vorderansicht** (Ziffernblock **1**) siehst. Der Boden liegt auf Höhe 0.
3. Dein Modell darüber bauen. Danach die Vorlage löschen (oder ausblenden und beim Export
   nur dein Modell auswählen).
4. **Datei → Exportieren → glTF 2.0**, Format **glTF Binary (.glb)**, Einstellung „+Y Up“ an
   lassen (Standard). Speichern in `~/Buecherei-Game/assets/models/` (nicht in `templates`).

**In Nomad Sculpt:** Über das Datei-Menü die `.glb` importieren, darauf modellieren, die
Vorlage löschen und als `.glb` exportieren. Danach die Datei nach `assets/models/` kopieren.

Die Vorlagen neu erzeugen (z. B. nach neuen Möbeln oder geänderten Haus-Maßen): In Godot die
Szene `scenes/world/tools/export_templates.tscn` öffnen und mit **F6** starten. Das Fenster
schließt sich nach ein paar Sekunden von selbst.

**Für Möbel:** Vorlage `templates/furniture/<id>.glb` nehmen, Modell bauen, dann wie im
Abschnitt „Ein Möbelstück durch ein eigenes Modell ersetzen“ unter `Model` einsetzen. Weil die
Vorlage genau so liegt wie die Szene, muss am Knoten `Model` nichts verschoben werden.

## Außenwelt: Häuser, Gassenende und Eingangstreppe
Draußen besteht alles aus Platzhaltern, die du einzeln durch eigene Modelle ersetzen kannst.
Für alle gilt: Man legt in der Szene einen Kind-Knoten **„Model“** an (genau so geschrieben)
und zieht dein `.glb` hinein. Sobald es „Model“ gibt, verschwindet der Platzhalter; die
unsichtbare Kollision (damit man nicht hindurchläuft) bleibt.

### Wo steht was?
- `scenes/world/houses.tscn` – **alle Häuser**, jedes als eigener Knoten. Öffne die Szene mit
  Doppelklick: Du siehst alle Häuser und kannst jedes anklicken und verschieben. Sie sind in
  Gruppen sortiert: `LibraryRow` (Nachbarn der Bücherei), `Opposite` (gegenüber),
  `StraightEnd` (am geraden Straßenende: bis zur Grenze, das Eckhaus in der runden Kurve,
  die Häuser um die Kurve und in der Seitenstraße), `GateStreet` (am anderen Ende: die Häuser
  durch die sanfte Kurve, das Eckhaus innen in der Kurve, das Torhaus und die Häuser dahinter).
- `scenes/world/houses/` – die **Haustypen**. Jedes Haus in `houses.tscn` ist ein Exemplar
  eines dieser Typen. Gleiche Häuser nutzen dieselbe Szene (das spart Rechenleistung).
- `scenes/world/alley_end.tscn` – Mauer mit Tor am Ende der Gasse (mit Haus dahinter); auch am
  Ende der kleinen Gasse gegenüber (`scenes/world/opposite_alley.tscn`).
- `scenes/world/entrance_steps.tscn` – Podest mit Stufen vor der Ladentür.
- **Schatten draußen heller oder dunkler:** Ein sanftes Himmelslicht (Knoten `SkyFill` in
  `main.tscn`) hellt nur die Außenwelt auf, innen bleibt alles wie es ist. Stärke und Farbe
  stehen in `scripts/autoload/game_config.gd`: `outdoor_fill_energy` (0 = aus, 0,55 = jetzt,
  höher = hellere Schatten) und `outdoor_fill_color`.

### Die Haustypen und ihre Maße
Alle Häuser: **Ursprung unten in der Mitte der Vorderseite** (auf Gehweg-Höhe), die
**Vorderseite zeigt nach +Z** (im Editor die blaue Pfeilrichtung), das Haus reicht 8 m nach
hinten (-Z). Die Traufe ist die Unterkante des Dachs; darüber steigt das Dach 2 m bis zum
First, vorn und hinten steht es 20 cm über.

| Haustyp (Datei)      | Rolle                                        | Breite | Traufhöhe | Tiefe |
|----------------------|----------------------------------------------|--------|-----------|-------|
| `terrace_45.tscn`    | Reihenhaus, schmal                           | 4,5 m  | 6,4 m     | 8 m   |
| `terrace_50.tscn`    | Reihenhaus                                   | 5,0 m  | 6,9 m     | 8 m   |
| `terrace_55.tscn`    | Reihenhaus, breit                            | 5,5 m  | 7,2 m     | 8 m   |
| `terrace_60.tscn`    | Reihenhaus, sehr breit                       | 6,0 m  | 6,6 m     | 8 m   |
| `residential.tscn`   | Wohnhaus (gegenüber der Ladentür)            | 5,4 m  | 7,0 m     | 8 m   |
| `pub.tscn`           | Restaurant / Pub (erstes Haus hinter der Gasse, am Platz) | 5,6 m | 7,2 m | 8 m |
| `fashion_shop.tscn`  | Modegeschäft (direkt neben der Bücherei)     | 5,4 m  | 6,8 m     | 8 m   |
| `gatehouse.tscn`     | Torhaus mit Durchfahrt (am abbiegenden Ende, siehe unten) | 9,8 m | 9,4 m | 6 m |
| `corner_90.tscn`     | Eckhaus mit abgeschrägter Ecke in der runden 90°-Kurve (siehe unten) | 6,0 m | 6,8 m | 7 m |
| `corner_30.tscn`     | Eckhaus mit abgeschrägter Ecke in der sanften 30°-Kurve (siehe unten) | 6,0 m | 7,0 m | 8 m |

Die Kollision ist ein Kasten so groß wie Breite × Traufhöhe × Tiefe (bei den Eckhäusern ihr
Grundriss, beim Torhaus nur die beiden Pfeiler). Dein Modell darf darüber hinausragen (Dach,
Schornstein, Markise); unten sollte es die Grundfläche ausfüllen.

### Das Torhaus durch ein eigenes Modell ersetzen
Am abbiegenden Straßenende macht die Straße eine sanfte Kurve und läuft auf ein **Torhaus**
zu (man sieht es schon von der Ladentür aus): unten ein gemauerter Rundbogen über der
Fahrbahn, darüber ein Band für ein Schild, ein Obergeschoss in Fachwerk und eine Gaube mit
Sprossenfenster. Die Straße läuft durch den Bogen hindurch und biegt dahinter in einer Kurve
ab. Szene: `scenes/world/houses/gatehouse.tscn`,
Vorlage: `templates/houses/gatehouse.glb`.

**Wichtig: Dein Modell muss die Öffnung des Bogens frei lassen.** Die Straße darunter
(Fahrbahn, Bordsteine, schmale Gehwege) baut das Spiel selbst – dein Modell besteht nur aus
dem Haus um die Durchfahrt herum (Pfeiler, Bogen, Gewölbe innen, Obergeschoss, Dach).
Modelliere also keinen Boden in die Durchfahrt und nichts, was in die Öffnung hineinragt.

Maße (Ursprung unten in der Mitte der Vorderseite, Vorderseite +Z, wie bei allen Häusern):
- Gesamt: 9,8 m breit (genau so breit wie die Straße zwischen den Hausfronten), 6 m tief (von
  0 bis -6 m), Traufe 9,4 m, First 11,8 m.
- **Öffnung:** 6,5 m breit (von x = -3,25 bis +3,25), senkrecht bis 2,6 m hoch, darüber ein
  Halbkreis – der Scheitel liegt bei 5,85 m. Sie geht ganz durch (von vorn bis hinten).
  In der Vorlage siehst du die Öffnung genau so; lass die Wände der Durchfahrt (innen) an
  derselben Stelle, dann passt die Straße.
- Die beiden Pfeiler links und rechts (je 1,65 m breit) sind fest: Dort kann man nicht
  hindurchlaufen. Die Durchfahrt selbst ist frei; eine unsichtbare Grenze im Bogen hält die
  Spielfigur auf (sie bleibt knapp unter dem Bogen stehen).
- Das Torhaus steht mittig zwischen den Hausfronten, darum sind beide Pfeiler gleich breit
  zu sehen. Die Fahrbahn läuft darunter 25 cm aus der Mitte (die Gehwege sind verschieden
  breit) – das passt schon. Die Rückseite sieht man im Spiel nicht – dort darf dein Modell
  schlicht sein.

So geht's:
1. `scenes/world/houses/gatehouse.tscn` doppelklicken.
2. Dein `.glb` aus `assets/models/` auf den obersten Knoten `Gatehouse` ziehen und den neuen
   Knoten in **Model** umbenennen (**F2**). Nichts verschieben.
3. **Strg+S**. Der Platzhalter verschwindet, die Straße läuft durch deinen Bogen.
Ist dein Bogen breiter oder schmaler: Im Inspektor unter **Durchfahrt** die **Passage Width**
(lichte Breite) anpassen – die schmalen Gehwege unter dem Bogen und die Grenze passen sich
beim nächsten Start von selbst an. Änderst du Breite oder Tiefe des ganzen Torhauses (unter
**Maße**), stelle danach die Häuser neu auf (siehe „Häuser neu aufstellen“). Die Straße vor
dem Bogen (sanfte Kurve, Abstand zum Torhaus) und hinter dem Bogen (Kurve, Länge, Breite der
Gehwege) stellst du in `game_config.gd` ein (`gate_bend_offset`, `gate_bend_angle`,
`gate_bend_radius`, `gate_approach_length`, `gate_curve_radius`, `gate_curve_angle`,
`gate_road_before_curve`, `gate_road_after_curve`, `gate_sidewalk_width`).

### Die Eckhäuser (abgeschrägte Ecke) durch eigene Modelle ersetzen
Innen in beiden Straßenkurven steht ein **Eckhaus mit abgeschrägter Ecke**, wie die Bücherei –
gut geeignet für kleine Läden: In der Abschrägung sitzt eine Ladentür mit einem Schild
darüber. Jedes Eckhaus ist ein eigener Haustyp mit eigener Vorlage:

| Haustyp (Datei)   | Wo                                      | Vorlage                         |
|-------------------|-----------------------------------------|---------------------------------|
| `corner_90.tscn`  | runde 90°-Kurve am geraden Straßenende  | `templates/houses/corner_90.glb` |
| `corner_30.tscn`  | sanfte 30°-Kurve vor dem Torhaus        | `templates/houses/corner_30.glb` |

Grundriss (Ursprung unten in der Mitte der **Vorderseite**, Vorderseite +Z, die Ecke liegt
**rechts**, wenn du von vorn auf das Haus schaust):
- **corner_90:** Vorderseite 6,0 m (von x = -3 bis zur gedachten Ecke bei x = +3), dann
  rechtwinklig die Seitenfassade 7,0 m nach hinten. Die Ecke ist 2,2 m breit schräg
  abgeschnitten (sie beginnt 1,56 m vor der gedachten Ecke). Traufe 6,8 m, Walmdach oben flach.
  In der Straße zeigt die Vorderseite in die Seitenstraße, die Seitenfassade zur langen Straße.
- **corner_30:** Vorderseite 6,0 m, dann knickt die Front an der 2,2 m breiten Abschrägung
  um 30° nach hinten und läuft 5,0 m weiter (gemessen ab der gedachten Ecke). Hinten gerade,
  8 m tief, Traufe 7,0 m. In der Straße liegt die Vorderseite am Stück zum Torhaus, die
  Seitenfassade zur langen Straße.
- Beide Fassaden sind Straßenfassaden (mit Fenstern), die Rückseite sieht man nicht.

So geht's (wie bei allen Häusern): Szene doppelklicken, dein `.glb` auf den obersten Knoten
ziehen, in **Model** umbenennen (**F2**), nichts verschieben, **Strg+S**. Die Kollision ist der
Grundriss als Prisma und bleibt. Im Inspektor unter **Ecke** stehen Winkel, Breite der
Abschrägung und Länge der Seitenfassade; ändern sie sich, stelle die Häuser neu auf.

**Fenster in einer Seitenwand:** Wo eine Seitenwand frei zu sehen ist (z. B. das erste Haus
nach den zurückversetzten Häusern am Platz), bekommt das Haus Fenster darin – im Inspektor
unter **Aussehen → Side Windows** (0 = keine, -1 = links, 1 = rechts, 2 = beide).

### Stil-Modelle aus Blender (seit Etappe 4g)
Nach und nach bekommen die Häuser fertige Modelle im einheitlichen Stil (siehe
docs/STYLE_GUIDE.md). Sie werden nicht von Hand geklickt, sondern von einem Python-Script in
Blender gebaut – so bleiben alle Häuser gleich in Maßstab, Materialien und Detailgrad.
- **Anschauen in Blender:** `assets/models/source/houses/<typ>.blend` öffnen (z. B.
  `fashion_shop.blend`). Oben im Kopf auf **Material-Vorschau** schalten (Taste **Z** →
  „Material Preview“), dann siehst du die Texturen und Farben wie im Spiel.
- **Im Spiel:** `assets/models/houses/<typ>.glb` liegt als Knoten **Model** in der
  Haustyp-Szene (z. B. `scenes/world/houses/fashion_shop.tscn`). Farben je Haus wählst du wie
  bisher in `houses.tscn` (Wand-, Tür-, Akzentfarbe) – sie färben auch das Modell.
- **Neu bauen** (Terminal, im Projektordner):
  `blender -b --factory-startup --python tools/blender/build_houses.py -- fashion_shop --render`
  (ohne `--render` geht es schneller, dann ohne Kontrollbilder in `screenshots/blender/`;
  `--check` macht Prüfbilder rundherum, auf denen jede Rückseite pink leuchtet – pink wäre im
  Spiel ein Loch, durch das man hindurchsieht).
- **Texturen:** Alle Modelle teilen sich 20 selbst erzeugte, nahtlose Texturen
  (`assets/textures/style/house_albedo.png` und `house_normal.png`, je ein großes Bild mit
  4 × 5 Feldern). Neu erzeugen: `godot --headless -s res://scripts/tools/generate_style_textures.gd`.
  In Godot sind sie eine „Texturliste“ (Texture2DArray), darum zeigt Godot sie als ein Bild
  mit 20 Ebenen.
- **Änderungswünsche:** Die .blend-Datei ist zum Anschauen gedacht. Wünsche (z. B. „Tür
  grün statt blau“, „Markise länger“, anderer Ladenname) sagst du Claude – das Script baut
  das Haus dann neu, und es bleibt einheitlich. Farben je Haus kannst du jederzeit selbst in
  `houses.tscn` ändern. Möchtest du ein Haus ganz selbst modellieren, gilt der nächste
  Abschnitt („Alle Häuser eines Typs ersetzen“) – dann mit deinen eigenen Materialien.

### Pflanzen (seit Etappe 4g, Teil 4f)
Alle Pflanzen der Außenwelt (Efeu, Blumenkästen, Hängekörbe, Kübel, Sträuße, Garten) baut
`tools/blender/style_plants.py`. Jedes Blatt ist eine gebogene Fläche mit einer echten
Blattform, jedes Blatt hängt an einem Stiel, jeder Stiel an einem Trieb – nichts schwebt.
- **Blatt- und Blütenbilder:** `assets/textures/plants/plant_albedo.png` (Farbe, Alpha =
  Form: was durchsichtig ist, wird weggeschnitten) und `plant_normal.png` (Adern als Relief),
  je 4 × 4 Felder: Efeublatt, Laubblatt, schmales Blatt (Olive, Lavendel), Geranienblatt,
  Funkienblatt, Buchs-Zweig, Laubzweig, Farnwedel, Gras, Blüten (Geranie, Hortensie,
  Petunie, Margerite, Blütenblatt), Lavendelähre, Rinde. Neu erzeugen:
  `godot --headless -s res://scripts/tools/generate_plant_textures.gd`.
  **Eigene Bilder:** Du kannst ein Feld in einem Malprogramm ersetzen (gleiche Größe 512 × 512,
  Stielansatz unten in der Mitte, Blüten mittig, Hintergrund durchsichtig). Achtung: Ein neuer
  Lauf des Scripts überschreibt die Bilder – sag Claude Bescheid, dann wird das Script
  angepasst.
- **Material:** `assets/materials/plant_style.tres` (Shader `plant_style.gdshader`): beide
  Seiten sichtbar, Licht scheint leicht durch die Blätter (**Translucency Layers**), in der
  Ferne bleiben Blätter dicht. Rauheit je Feld: **Roughness Layers**.
- **Töpfe und Gruppen:** Töpfe gibt es in vier Größen (`POT_SIZES`: small, medium, large,
  xl). `pot_cluster` stellt 1–3 verschieden große Töpfe dicht nebeneinander an eine Wand
  (groß hinten, kleiner davor) – so stehen sie an der Straße und in den Gassen.
- **Hängekörbe:** drei Arten (`style_parts.BASKET_VARIANTS`): „summer“ (Drahtkorb mit
  Kokosmatte, Geranien, Lobelien, Petunien, Efeu), „fuchsia“ (Weidenkorb, Fuchsien hängen in
  Bögen über) und „cascade“ (grüne Schale, Petunien-Wasserfall). `hanging_basket(...,
  variant="fuchsia")` wählt die Art.
- **Efeu über die ganze Wand:** In `build_street.py` bei `SPECIAL` für ein Haus
  `ivy_cover=True` eintragen (bisher: GateStreet/Bend1, das hohe Steinhaus am Platz beim Pub).
- **Anschauen ohne Spiel:** `blender -b --factory-startup --python tools/blender/plant_showcase.py`
  stellt alle Pflanzen nebeneinander auf und macht Bilder nach `screenshots/blender/plants/`.
- **Prüfen:** `blender -b --factory-startup --python tools/blender/geo_check.py` sucht in allen
  fertigen Modellen schwebende Teile und Blätter, die in Wänden, Töpfen oder Kästen stecken
  (mit `-- --source` nennt es zu jedem Fund die Programmzeile).

### Schilder selbst gestalten (seit Etappe 4g)
Alle Schilder an den Stil-Häusern sind **Bilder** (PNG) – du kannst sie selbst malen oder
gestalten (z. B. in Krita, GIMP, Procreate oder auf Papier und eingescannt). Für jedes Schild
gibt es ein Startbild, das genau so groß ist, wie es sein muss:

| Bild (`assets/textures/signs/`) | Wo | Größe am Haus | Startbild (Pixel) |
|---|---|---|---|
| `fashion_shop_fascia.png` | Ladenschild über den Schaufenstern | 4,76 × 0,51 m | 2048 × 219 |
| `fashion_shop_hanging.png` | Ausleger-Schild (beide Seiten gleich) | 0,60 × 0,56 m, oben Bogen | 512 × 478 |
| `fashion_shop_chalkboard.png` | Kreidetafel vor dem Laden | 0,42 × 0,70 m | 360 × 600 |
| `fashion_shop_open.png` | „Geöffnet“-Kärtchen in der Tür | 0,26 × 0,11 m | 360 × 152 |
| `flower_shop_fascia.png` | Schild des Blumenladens | 4,76 × 0,43 m | 2048 × 185 |
| `flower_shop_chalkboard.png` | Kreidetafel vor dem Blumenladen | 0,42 × 0,70 m | 360 × 600 |
| `flower_shop_hanging.png` | Hängeschild am Blumenladen | 0,60 × 0,56 m | 512 × 478 |
| `pub_fascia.png` | Schild des Pubs („The Ink & Ivy“) | 4,92 × 0,53 m | 2048 × 221 |
| `pub_chalkboard.png` | Kreidetafel vor dem Pub | 0,42 × 0,70 m | 360 × 600 |
| `corner_90_fascia.png` | Schild der Teestube (Eckhaus am geraden Ende) | 1,6 × 0,4 m | 768 × 192 |
| `gatehouse_fascia.png` | Schildband am Torhaus („Alte Torgasse“) | 4,6 × 0,42 m | 2048 × 187 |
| `pub_hanging.png` | Rundes Hängeschild am Pub | 0,60 × 0,56 m (rund) | 512 × 478 |
| `corner_90_hanging.png` | Teekannen-Hängeschild der Teestube | 0,60 × 0,56 m | 512 × 478 |
| `bakery_shop_fascia.png` | Schild der Bäckerei (rechts neben dem Blumenladen) | 3,94 × 0,43 m | 2048 × 224 |
| `bakery_shop_chalkboard.png` | Kreidetafel vor der Bäckerei | 0,42 × 0,70 m | 360 × 600 |
| `corner_30_fascia.png` | Schild „Wolle & Stoff“ (Eckhaus vor dem Torhaus) | 1,6 × 0,4 m | 768 × 192 |
| `corner_30_hanging.png` | Hängeschild des Wolleladens | 0,60 × 0,56 m | 512 × 478 |
| `corner_30_chalkboard.png` | Kreidetafel vor dem Wolleladen | 0,42 × 0,70 m | 360 × 600 |
| `library_fascia.png` | Schild der Bücherei über den Fenstern (vorn und an der Gasse) | 3,6 × 0,52 m | 2048 × 296 |
| `library_door.png` | Schild der Bücherei über der Tür | 2,99 × 0,52 m | 1536 × 267 |

So geht's:
1. Das Startbild öffnen und darüber malen – oder ein neues Bild im **gleichen
   Seitenverhältnis** anlegen (gern größer, z. B. doppelt so viele Pixel, dann wird es schärfer).
2. Unter **genau demselben Namen** in `assets/textures/signs/` speichern (das alte ersetzen).
3. Godot öffnen – das Bild wird von selbst neu geladen und hängt sofort am Haus.
- Beim Ausleger-Schild ist oben ein Bogen: Was im Bild außerhalb des Bogens liegt (die grauen
  Ecken oben), sieht man nicht. Das Bild erscheint auf beiden Seiten lesbar.
- Deine Bilder werden **nie** überschrieben, auch nicht, wenn Claude das Haus neu baut. Nur
  wenn ein Bild fehlt, legt das Bau-Script wieder ein Startbild an.
- Etwas glänzender oder matter: das Material in `assets/materials/signs/` anklicken, im
  Inspektor **Roughness** (0 = glänzend, 1 = matt).

### Jedes Haus einzeln (seit Etappe 4g, Teil 2b)
Jedes Reihenhaus und das Wohnhaus hat ein **eigenes Modell**:
`assets/models/houses/street/<Gruppe>_<Name>.glb` (z. B. `Opposite_Opposite1_3.glb`). In
`houses.tscn` steht es beim Haus unter **Dieses Haus → Unique Model** (leer = Modell des
Haustyps). Die ganze Straße zum Anschauen in Blender: `assets/models/source/street.blend`.
- Gebaut werden sie mit `blender -b --factory-startup --python tools/blender/build_street.py`.
  Welche Häuser etwas Besonderes haben (Fachwerk, Vorgarten, Balkon …), steht oben im Script
  unter `SPECIAL`; alle anderen mischt der Zufall – bei jedem Bau gleich.
- **Farben** stehen weiter je Haus in `houses.tscn`: Wall Color (Wand), Door Color (Fenster
  und Tür), Accent Color (Läden, Blumenkästen). Das Wandmaterial ist „As Built“ (wie gebaut).
- **Selbst nachbearbeiten:** Jedes Haus ist eine eigene Datei. In Blender
  **Datei → Importieren → glTF 2.0** und z. B. `assets/models/houses/street/Opposite_Opposite1_3.glb`
  wählen (oder die ganze Straße in `assets/models/source/street.blend` anschauen). Nach dem
  Bearbeiten **Datei → Exportieren → glTF 2.0**, Format „glTF Binary“, unter **demselben Namen**
  speichern. Die Materialnamen „house“ und „glass“ bitte lassen – dann bleiben Texturen und
  Farben aus dem Spiel. Deine Datei wird beim nächsten Bau erkannt und **nicht überschrieben**
  (Hinweis „selbst bearbeitet“). Soll Claude sie wieder neu bauen: Datei löschen.
- **Glas:** Fenster der Wohnhäuser rau und leicht milchig (Material
  `assets/materials/house_glass.tres`: **Blur** = wie unscharf, **Spread** = wie weit verwischt,
  **Milkiness** = wie milchig); Schaufenster klar (`house_glass_clear.tres`).
- **Straße und Gehweg:** Materialien `assets/materials/cobblestone.tres` (Fahrbahn),
  `sidewalk.tres` (Gehweg, Platz, Gassen), `curb_stone.tres` (Bordstein, Treppe). Im Inspektor:
  **Layer** (welche Stil-Textur), **Tile Size** (Größe in Metern), **Tint** (Farbe).
  Abflussdeckel: Knoten `Outside/Street` → **Drain Spacing** (Abstand).
- Achtung: Stellst du die Häuser neu auf (`generate_houses.tscn`), danach `build_street.py`
  noch einmal laufen lassen – sonst zeigen die Häuser wieder ihr Typ-Modell.

### Wandmaterial je Haus (seit Etappe 4g)
Bei den Stil-Häusern wählst du für jedes Haus in `houses.tscn` im Inspektor unter
**Dieses Haus → Wall Material**: *Auto* (Standard: rote und braune Wandfarben werden
Backstein, helle Farben Putz, jedes dritte Rauputz), *As Built* (wie gebaut), *Brick*
(Backstein), *Stone* (Sandstein), *Render* (glatter Putz), *Roughcast* (Rauputz). Die
**Wall Color** färbt das Material – ein heller Ton auf Backstein ergibt gestrichenen Backstein.

### Bücherei-Fassade, Gassen und Laternen (seit Etappe 4g)
- **Fassade der Bücherei:** `assets/models/world/library_facade.glb` (Knoten „Facade“ in
  `scenes/rooms/ground_floor_room.tscn`), gebaut mit
  `blender -b --factory-startup --python tools/blender/build_library.py`.
- **Gassen:** `assets/models/world/alley_library.glb` und `alley_opposite.glb`. Neu bauen:
  erst `godot --headless --path . res://scenes/tools/export_layout.tscn` (schreibt die Lage
  nach `assets/models/source/layout.json`), dann
  `blender -b --factory-startup --python tools/blender/build_alleys.py`. Länge der Gasse und
  Größe des Gartens: `alley_depth`, `alley_garden_depth`, `alley_garden_extra_width`,
  Höhe der Hauswände `alley_wall_height` in `game_config.gd`.
- **Laternen:** Laternenmast `assets/models/props/street_lamp.glb`, Stellen am Knoten
  `Outside/Street` (**Lamp Positions**, x-Werte auf der Bücherei-Seite), Abflussdeckel
  ebenda (**Drain Spacing**). Hängende Laterne am Wandarm:
  `assets/models/props/wall_street_lantern.glb` (Ursprung = Befestigung an der Wand, +Z von der
  Wand weg); welche Häuser eine haben, steht in `tools/blender/build_street.py` unter
  `LANTERNS`, den Platz trägt das Script je Haus in `houses.tscn` ein (**Lanterns**).
  Neu bauen: `blender -b --factory-startup --python tools/blender/build_props.py -- street_lamp wall_street_lantern`.
- **Laternen selbst nachmodellieren:** In Blender `assets/models/source/props/street_lamp.blend`
  bzw. `wall_street_lantern.blend` öffnen (oder **Datei → Importieren → glTF 2.0** und die
  .glb wählen), bearbeiten, dann **Datei → Exportieren → glTF 2.0**, Format „glTF Binary“, unter
  demselben Namen nach `assets/models/props/` speichern. Ursprung und Größe beibehalten
  (Mast: Fuß auf dem Boden; Wandlaterne: Wandplatte im Ursprung). Deine Datei wird beim
  nächsten Bau erkannt und nicht überschrieben.
- **Bank im Garten:** Die Sitzplätze baut `Alley` (Knoten `Outside/Alley/Bench`, Winkel und
  Höhe oben im Script `scripts/world/alley.gd`); Passanten setzen sich nur auf die Plätze, die
  vom Weg aus erreichbar sind. Eigene Passanten-Figuren brauchen dafür eine Animation „Sit“
  (Gesäß auf 0,45 m).
- **Kleine Gasse gegenüber:** Boden `assets/materials/alley_setts.tres` (großes Kopfsteinpflaster,
  **Tile Size** = Größe der Steine).

### Puppen und Kleidung im Laden (seit Etappe 4g)
Im Modegeschäft stehen Schneiderpuppen und hängen Kleider – vorerst **Platzhalter**. Jedes
Stück ist eine eigene kleine Szene in `scenes/world/props/`:
`mannequin_dress.tscn`, `mannequin_coat.tscn` (Puppe = Knoten `Form`, Kleidung = `Outfit`),
`garment_dress.tscn`, `garment_blouse.tscn` (hängend, Knoten `Model`, Ursprung oben am Haken).
- **Farbe ändern:** `scenes/world/houses/fashion_shop_interior.tscn` öffnen, ein Stück
  anklicken, im Inspektor bei **Color** eine Farbe wählen.
- **Eigene Kleidung einsetzen:** In der Requisiten-Szene den Knoten `Outfit` (bzw. `Model`)
  löschen, dein Kleidungsmodell (.glb) hineinziehen und in **Outfit** umbenennen (**F2**).
  Die Puppe steht mit dem Fuß bei Höhe 0, die Vorderseite zeigt nach +Z; Vorlagen in echter
  Größe: `assets/models/props/dress_form.glb` (Körper ab 1,0 m bis 1,55 m Höhe).
- **Achtung:** `fashion_shop_interior.tscn` wird neu geschrieben, wenn Claude das Haus neu
  baut. Wenn du dort selbst etwas zusammenstellst, sag Bescheid – dann bleibt die Datei.
- Modelle neu bauen: `blender -b --factory-startup --python tools/blender/build_props.py`.

### Alle Häuser eines Typs ersetzen
1. Im Dateisystem-Fenster `scenes/world/houses/` öffnen und den Haustyp doppelklicken
   (z. B. `pub.tscn`).
2. Dein `.glb` aus `assets/models/` auf den obersten Knoten ziehen. Es erscheint als Kind.
3. Den neuen Knoten umbenennen in **Model** (Rechtsklick → Umbenennen oder **F2**).
4. Nichts verschieben – wenn du auf der Vorlage modelliert hast, sitzt es schon richtig.
5. **Strg+S**. Alle Häuser dieses Typs zeigen jetzt dein Modell (auch in `houses.tscn`).

### Nur ein einzelnes Haus ersetzen
1. Den Haustyp duplizieren: Im Dateisystem-Fenster Rechtsklick auf z. B. `terrace_50.tscn` →
   **Duplizieren…** → neuer Name, z. B. `my_bakery.tscn`.
2. Die neue Szene öffnen und dein Modell wie oben als **Model** einsetzen. Passen die Maße
   nicht ganz, im Inspektor beim obersten Knoten unter **Maße** Breite, Tiefe und Traufhöhe
   an dein Modell anpassen (die Kollision passt sich an). **Strg+S**.
3. `scenes/world/houses.tscn` öffnen und das Haus anklicken, das ersetzt werden soll.
   Im Inspektor unter **Transform** Rechtsklick auf **Position** → **Kopieren**.
4. Deine neue Szene aus dem Dateisystem auf dieselbe Gruppe im Szenenbaum ziehen (z. B.
   `Opposite`). Beim neuen Knoten Rechtsklick auf **Position** → **Einfügen**; genauso
   **Rotation** übernehmen.
5. Das alte Haus anklicken und mit **Entf** löschen. **Strg+S**.
Tipp: Auch die Farben eines einzelnen Hauses lassen sich so ändern – Haus anklicken, im
Inspektor unter **Dieses Haus** Wand-, Tür- und Akzentfarbe wählen.

### Häuser neu aufstellen
Die Lage der Häuser wurde einmal aus der Straße berechnet und fest in `houses.tscn`
geschrieben. Änderst du in `game_config.gd` etwas an der Straße (Breiten, gerades Ende,
Grenze und Kurve dahinter, sanfte Kurve und Torhaus, die Eckhäuser `straight_corner_house` /
`gate_corner_house`,
Haustypen der Nachbarn in `neighbor_house_types` / `alley_house_types`, das Haus gegenüber
in `opposite_feature_house`, die Reihenhaus-Typen in `terrace_house_types`), stelle die
Häuser neu auf:
1. Godot: `scenes/world/tools/generate_houses.tscn` öffnen und mit **F6** starten.
2. Das Fenster schließt sich von selbst; unten in der Ausgabe steht „Häuser neu erzeugt“.
3. Fragt Godot, ob `houses.tscn` neu geladen werden soll: **Neu laden**.
**Achtung:** Dabei werden eigene Änderungen in `houses.tscn` (verschobene, getauschte oder
umgefärbte Häuser) überschrieben. Eigene Modelle in den Haustyp-Szenen bleiben erhalten.

### Gassenende ersetzen
Szene `scenes/world/alley_end.tscn`. **Ursprung** unten in der Mitte der Gasse an ihrem Ende,
die **Vorderseite zeigt in die Gasse (-Z)**, also zur Spielfigur hin. Die Mauer ist 3,4 m breit
(Gassenbreite 2,8 m + je 0,3 m), 2,6 m hoch und 0,3 m dick (sie liegt von 0 bis +0,3 m hinter
dem Ursprung). Ein eigenes Model ersetzt Mauer, Tor **und** das Haus dahinter – dein Modell
darf also gern auch eine Hauswand dahinter zeigen. Die feste Mauer-Kollision bleibt.
Vorlage: `templates/world/alley_end.glb` (ohne das Haus dahinter).
Dieselbe Szene schließt auch die **kleine Gasse gegenüber** ab (1,8 m breit, die Mauer dort ist
also 2,4 m breit; das Spiel stellt die Breite über **Width** ein). Soll sie anders aussehen
als die große Gasse: Szene duplizieren (z. B. `small_alley_end.tscn`), dort dein Modell
einsetzen, dann in der Hauptszene den Knoten `Outside/OppositeAlley` anklicken und im
Inspektor bei **End Scene** die neue Szene hineinziehen.

### Eingangstreppe ersetzen
Szene `scenes/world/entrance_steps.tscn`. **Ursprung** außen auf der Hauswand in der Mitte der
Tür, auf Höhe des Ladenbodens; **+Z zeigt von der Wand weg nach draußen**. Die Treppe ist so
breit wie die schräge Wand (2,99 m) und reicht 1,54 m nach vorn (Podest 0,7 m + drei Stufen à
0,28 m; an den Seiten je drei Stufen à 0,2 m). Sie geht vom Ladenboden (0) 0,5 m hinunter bis
zum Gehweg (-0,5 m), vier gleich hohe Absätze à 12,5 cm. Die unsichtbare Rampe zum Laufen
bleibt; dein Modell sollte deshalb ungefähr diese Form haben.
Vorlage: `templates/world/entrance_steps.glb`.

## Leben auf der Straße: eigene Passanten, Fahrzeuge und Lieferwagen
Seit Etappe 5a sind draußen Passanten, Fahrräder, Autos und ein Lieferwagen unterwegs. Alle
sind eigene Szenen in `scenes/street_life/` mit demselben Aufbau wie die Möbel:
```
Passerby / Car / Cyclist / DeliveryVan   (Wurzel-Knoten mit Script)
├── Body    ← die Kollision (damit man nicht hindurchläuft) – bleibt
└── Model   ← nur die Optik: hier kommt dein Modell hin
```
Für alle gilt: **Vorderseite nach +Z** (das ist die Vorderansicht in Blender, Ziffernblock
**1**), **Füße bzw. Räder auf Höhe 0**, Ursprung in der Mitte. Vorlagen in echter Größe liegen
in `assets/models/templates/street_life/` (siehe „Vorlagen zum Modellieren“).

### Die Chibi-Figuren (seit Etappe 5c)
Niedliche Grundkörper ("Mannequins") wie auf den Vorlagen: großer runder Kopf (bei allen gleich
groß, 0,47 m), weicher Vinyl-Körper, Frauen mit Bandeau-Top und Slip, Männer mit Boxershorts –
die Unterwäsche ist nur **aufgemalt** (Farbe einstellbar), damit unter enger Kleidung nichts
hervorschaut. Noch ohne Haare und Kleidung. Gebaut mit `tools/blender/build_chibi.py` (Körper aus weichen
Grundformen: `chibi_sdf.py`; gezeichnetes Gesicht: `chibi_face.py`).
- **Sechs Dateien:** `assets/models/characters/chibi/<gender>_<größe>.glb`
  (`female_small`, `female_medium`, `female_tall`, `male_small` …). Größen: Frauen 1,50 / 1,58 / 1,66 m,
  Männer 1,58 / 1,67 / 1,76 m (änderbar oben in `chibi_sdf.py`, `HEIGHTS`).
- **Dünn – mittel – dick:** jede Datei hat die Formregler `thin` und `fat` (auch die Wäsche),
  also gibt es von jeder Größe alle drei Formen und alles dazwischen. In Godot: Eigenschaft
  **Body Shape** der Figur (-1 = dünn, 0 = mittel, 1 = dick).
- **In Godot benutzen:** `scenes/characters/chibi_character.tscn` in eine Szene ziehen und im
  Inspektor einstellen: Figure (welcher Körper), Body Shape, Hautfarbe, Wäschefarbe, Augenfarbe,
  Augenbrauenfarbe, unter „Gesicht“ den Ausdruck (Mood), Blickrichtung (Look), Blinzeln, Sprechen.
  Alle zusammen ansehen: `scenes/tools/chibi_lineup.tscn` öffnen und **F6** drücken.
- **Gesicht im Manga-Chibi-Stil:** je Geschlecht **3 Augenformen** (Eigenschaft **Eye Shape**):
  Frauen süß / elegant / lebhaft (mit Wimpern), Männer sanft / cool / fröhlich (ohne Wimpern,
  dezenter Glanz, kräftige Augenbrauen). Augenfarbe, Augenbrauenfarbe und Hautfarbe frei.
- **Gesichtsausdrücke (Mood, 26 Stück, für jede Augenform):** neutral, fröhlich, lachen,
  zufrieden, grinsen, begeistert, verliebt, Sternchenaugen, zwinkern, frech (Zunge), überrascht,
  schockiert, traurig, Tränen in den Augen, weinen, böse, wütend (><), genervt, selbstgefällig,
  besorgt, verlegen (Rotstriche), schüchtern, nachdenklich, müde, schlafend, schwindelig; dazu
  Blinzeln, Sprechen und Blickrichtung. Animieren: im AnimationPlayer eine Spur auf `mood`,
  `look`, `eyes_override` oder `mouth_override` der Figur. Die Bilder dafür liegen in
  `assets/textures/characters/chibi_face/` und werden von `chibi_face.py` gezeichnet.
- **Neu bauen:** `blender -b --factory-startup --python tools/blender/build_chibi.py`
  (Kontrollbilder: `-- --only=female_medium --render --views=around,faces,compare,shapes` →
  `screenshots/blender/chibi/`). Quellen: `assets/models/source/characters/chibi/*.blend`.
- **Mixamo:** `assets/models/characters/chibi/mixamo/<name>.fbx` (T-Pose, Arme waagerecht, nur das
  Netz – Mixamo setzt sein Skelett selbst ein). Ablauf wie unten bei „Animationen von Mixamo“;
  hochladen am besten `female_medium.fbx`. Ohne Animation lassen die Figuren in Godot die Arme
  locker hängen (Eigenschaft **Relaxed Arms**, 57°).

### Die Figuren (seit Etappe 5b)
Sechs Figuren im Stil des Spiels (Kopf etwas größer, Frisuren aus dicken Strähnen):
**Mila** (Pullover, Leggings, Stiefeletten), **Rosa** (Bluse, Mieder, langer Rock), **Hanna**
(Strickjacke, Rock, Dutt), **Theo** (Pullover, Jeans, Turnschuhe), **Bruno** (Hemd, Weste,
Schiebermütze, Bart) und **Arthur** (Mantel, Schal, Schnurrbart). Grundlage sind die
Quaternius-Grundkörper (CC0, frei verwendbar) – sie liegen unverändert in
`assets/models/characters/base_quaternius/` (zum Anschauen in Blender).
- **Fertige Figuren:** `assets/models/characters/<name>.glb` (Skelett + Körper, Kleidung, Haare,
  T-Pose). Alle nebeneinander in Godot: `scenes/tools/character_lineup.tscn` öffnen.
- **Baukasten:** `kit_female.glb` und `kit_male.glb` – der Körper in Teilen (Kopf, Rumpf, Arme,
  Beine, Füße …) mit **Formreglern** (Blend Shapes „Rundlich“, „Schlank“, beim Mann auch
  „Kraeftig“), dazu alle Kleidungsstücke und Frisuren, alle am selben Skelett. Jedes
  Kleidungsstück hat dieselben Formregler, passt also zu jeder Körperform. Die Blender-Dateien
  dazu: `assets/models/source/characters/kit_female.blend`, `kit_male.blend`, je Figur
  `<name>.blend`.
- **Neue Figur:** in `tools/blender/build_characters.py` bei `CHARACTERS` einen Eintrag
  ergänzen (Körper, Hautton, Formregler, Größe, Frisur + Farbe, Kleidungsstücke + Farben) und
  das Script laufen lassen: `blender -b --factory-startup --python
  tools/blender/build_characters.py` (Kontrollbilder: `-- --render mila` →
  `screenshots/blender/characters/`).

### Animationen von Mixamo (Bewegungen für die Figuren)
Mixamo kann nur im Browser benutzt werden – das machst du, den Rest Claude:
1. Auf mixamo.com anmelden und **Upload Character** wählen. Eine Figur aus
   `assets/models/characters/mixamo/` hochladen (z. B. `mila.fbx`; T-Pose, nur das Netz).
2. Der Auto-Rigger fragt nach Punkten: Kinn, Handgelenke, Ellbogen, Knie, Leiste – auf die
   Figur ziehen, **Next**. Mixamo setzt das Skelett ein.
3. Animationen suchen und je eine herunterladen (**Download**, Format **FBX Binary**, **Without
   Skin**, 30 fps). Gebraucht werden: Gehen (*Walking*), Stehen (*Idle*), Umschauen
   (*Looking Around*), Sitzen (*Sitting Idle*), gern auch Lesen, Winken, Ins-Schaufenster-Schauen.
   Bei Geh-Animationen **In Place** anhaken.
4. Die Dateien in den Ordner `assets/models/characters/animations/` legen (anlegen) und Claude
   Bescheid sagen. Einmal hochladen genügt: Alle Figuren haben dasselbe Skelett, Godot überträgt
   die Bewegungen auf jede Figur.

### Eigene Passanten (Figur mit Skelett und Animationen)
Gedacht für Figuren wie die Quaternius-Grundkörper mit Skelett, dazu deine Frisuren und
Kleidung. So geht's:
1. **In Blender:** Körper, Frisur und Kleidung an dasselbe Skelett hängen (Kleidung und Haare
   als Kinder des Skeletts bzw. mit Gewichten). Die Figur steht mit den Füßen auf dem Boden,
   schaut nach vorn (Vorderansicht) und ist etwa 1,72 m groß – die Vorlage
   `templates/street_life/passerby.glb` zeigt die Größe. Nötige Animationen: **Gehen** (als
   Schleife), **Stehen** (als Schleife), gern auch **Umschauen** (Kopf nach links und rechts)
   und **Ins-Schaufenster-Schauen**. Exportieren als **glTF Binary (.glb)** mit Animationen
   nach `~/Buecherei-Game/assets/models/street_life/` (Ordner anlegen). Jede Kombination aus
   Frisur und Kleidung ist eine eigene `.glb` (z. B. `passerby_anna.glb`, `passerby_ben.glb`).
2. **Schleifen einstellen:** In Godot die `.glb` im Dateisystem-Fenster doppelklicken
   („Erweiterte Importeinstellungen“). Links unter **Animation** die Gehen- und
   Stehen-Animation anklicken und rechts **Loop Mode** auf **Linear** stellen, dann
   **Neu importieren**.
3. **Szene anlegen:** Im Dateisystem-Fenster `scenes/street_life/passerby.tscn` rechts anklicken
   → **Duplizieren…** → Name z. B. `passerby_anna.tscn`. Die neue Szene doppelklicken.
4. Den Knoten **Model** anklicken und löschen (Entf). Deine `.glb` aus dem Dateisystem auf den
   obersten Knoten **Passerby** ziehen und den neuen Knoten in **Model** umbenennen (F2).
5. Oben den Knoten **Passerby** anklicken. Im Inspektor unter **Animationen (eigene Figur)**
   die Namen deiner Animationen eintragen (so, wie sie im AnimationPlayer deiner Figur heißen –
   bei Quaternius z. B. `Walk_Loop`, `Idle_Loop`): **Walk Animation**, **Idle Animation**,
   **Look Animation** (Umschauen, leer = Stehen), **Browse Animation** (Schaufenster, leer =
   Stehen). **Walk Animation Speed** = das Tempo (m/s), bei dem die Füße beim Gehen genau
   passen (ausprobieren: rutschen die Füße nach vorn, Zahl kleiner machen). Schaut die Figur
   rückwärts, **Model Faces Back** einschalten.
6. Speichern (**Strg+S**). Dann in `scripts/autoload/game_config.gd` die Szene in die Liste
   eintragen, z. B.
   `var passerby_scenes: Array[String] = ["res://scenes/street_life/passerby_anna.tscn", "res://scenes/street_life/passerby_ben.tscn"]`.
   Mehrere Szenen wechseln sich ab; den Platzhalter einfach aus der Liste nehmen.
7. Die Größe schwankt leicht von selbst (`GameConfig.passerby_height_range`). Ist deine Figur
   viel größer oder kleiner als 1,7 m, im Knoten **Body > CollisionShape3D** die Höhe anpassen.

Schatten und Leistung regelt das Spiel selbst: Figuren werfen nur in der Nähe Schatten. Weit
entfernte Figuren vereinfacht Godot beim Import automatisch (LOD).

### Autos, Fahrräder und Lieferwagen (seit Etappe 5b)
Alle Fahrzeuge baut `tools/blender/build_vehicles.py` (ohne Markenzeichen):
**Taxi** (englisches Taxi, immer schwarz, Schild „TAXI“), **Mini** (Wagenfarbe, helles Dach),
**Kombi mit Holzrahmen** („Traveller“), der **Lieferwagen** (Bulli, unten Wagenfarbe, oben creme,
großes V vorn, geteilte Frontscheibe, Dachträger mit Paketen) und das **Hollandrad**.
- Dateien: `assets/models/vehicles/<name>.glb` (Karosserie), `<name>_wheel.glb` (ein Rad – das
  Spiel setzt es viermal ein und dreht es beim Fahren), `delivery_van_door.glb` (Schiebetür),
  `bicycle_wheel.glb`, `bicycle_crank.glb` (Kurbel mit Pedalen); Blender-Dateien zum Anschauen in
  `assets/models/source/vehicles/`.
- Szenen: `scenes/street_life/car_taxi.tscn`, `car_mini.tscn`, `car_traveller.tscn`,
  `delivery_van.tscn`, `cyclist.tscn`. Welche Autos fahren, steht in
  `scripts/autoload/game_config.gd` bei `car_scenes` (Anzahl gleichzeitig: `car_count`).
- **Farben:** Die Autos (außer dem Taxi) bekommen eine Farbe aus `GameConfig.car_colors`. Am
  Knoten **Model** einer Auto-Szene: **Fixed Color** an = immer **Paint Color** (so beim Taxi);
  **Second Color** = Dach/obere Hälfte. Lieferwagen: `GameConfig.delivery_van_color`.
- **Logo am Lieferwagen:** Das Bild `assets/textures/signs/delivery_van_logo.png` (1024 × 496
  Pixel, entspricht 0,95 × 0,46 m an beiden Seiten). Selbst gestalten wie bei den Schildern:
  Bild öffnen, darüber malen oder ein neues im gleichen Seitenverhältnis anlegen, unter
  **genau demselben Namen** speichern – Godot lädt es von selbst.
- **Paketanimation:** unverändert; die Schiebetür heißt im Modell **Door** und gleitet beim
  Ausladen um **Door Slide** nach hinten, die Kartons hüpfen aus der Mitte der Öffnung
  (**Door Point** am Knoten **DeliveryVan**).
- **Eigenes Modell:** In der Szene unter **Model** die Karosserie (Kind `Car`, `Van`) durch dein
  `.glb` ersetzen (Vorderseite +Z, Räder auf y = 0). Bringt dein Modell eigene Räder mit, bei
  **Model** das Feld **Wheel Scene** leeren. Ist es deutlich länger oder breiter, oben am
  Wurzel-Knoten **Length** und **Width** anpassen und die Kiste in **Body > CollisionShape3D**.
- Neu bauen: `blender -b --factory-startup --python tools/blender/build_vehicles.py`
  (Kontrollbilder: `-- taxi --render` → `screenshots/blender/vehicles/`).

### Wo Passanten stehen bleiben
Vor den Schaufenstern der Haustypen in `GameConfig.passerby_window_house_types` (Modegeschäft,
Pub) bleiben Passanten von selbst stehen. Weitere Stellen (z. B. vor dem Fenster der Bücherei)
sind Punkte in der Hauptszene unter **Outside → StreetLife → WindowSpots**: einen Punkt
anklicken und verschieben, mit Strg+D verdoppeln. Der blaue Pfeil zeigt vom Fenster weg (der
Passant schaut in die Gegenrichtung).

## Farben und Texturen von Wänden und Böden
Die Materialien liegen in `assets/materials/` (z. B. `wall_plaster.tres`, `floor_wood.tres`).
Doppelklicke ein Material, dann siehst du rechts im **Inspektor** die Eigenschaften:
- **Albedo > Color**: die Grundfarbe
- **Albedo > Texture**: hier eine Textur aus `assets/textures/` hineinziehen

Wände und Boden nutzen „Triplanar“-Mapping: Texturen werden automatisch gleichmäßig
über die Fläche gelegt. Die Kachelgröße stellst du unter **UV1 > Scale** ein.

## Eigene Symbole für den Gestaltungsmodus
Beim Gestalten erscheint statt des Punkts ein Farbroller (Wand), ein eingerollter Teppich
(Boden) bzw. ein Roller an einer Stange (Decke). Das Lager-Symbol unten rechts (Häuschen) ist
`storage.svg`. Die Platzhalter liegen in `assets/ui/icons/`
(`paint_roller.svg`, `carpet_roll.svg`, `ceiling_roller.svg`).
Zum Austauschen: eigenes Bild (.png oder .svg, ca. 64 × 64 Pixel) in den Ordner kopieren, dann
`scenes/ui/hud.tscn` öffnen, den obersten Knoten `HUD` anklicken und im Inspektor bei
**Paint Roller Icon**, **Carpet Icon** bzw. **Ceiling Icon** dein Bild hineinziehen.
