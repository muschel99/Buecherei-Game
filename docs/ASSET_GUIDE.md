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
Für jedes Möbelstück, jeden Haustyp, das Gassenende und die Eingangstreppe gibt es eine
schlichte **Vorlage** als `.glb`-Datei – in echter Größe (1 Einheit = 1 Meter) und genau so
gelegen wie im Spiel. Darauf (oder daneben) modellierst du dein eigenes Modell; dann passt es
später ohne Verschieben oder Skalieren.

| Was            | Ordner                                   | Dateiname                     |
|----------------|------------------------------------------|-------------------------------|
| Möbel und Deko | `assets/models/templates/furniture/`     | Id des Möbelstücks, z. B. `armchair_velvet.glb` |
| Häuser         | `assets/models/templates/houses/`        | Haustyp, z. B. `pub.glb`      |
| Gassenende, Treppe | `assets/models/templates/world/`     | `alley_end.glb`, `entrance_steps.glb` |

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
