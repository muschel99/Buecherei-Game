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
