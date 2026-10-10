# CLAUDE.md – Arbeitsregeln für dieses Projekt

Dieses Projekt ist ein gemütlicher Bücherei-Simulator („Cozy Bücherei“) in Godot 4.
Die Gesamtidee steht in `docs/GAME_DESIGN.md`, der Etappenplan in `docs/ROADMAP.md`.

## Über die Entwicklerin
- Absolute Anfängerin: hat noch nie programmiert und noch nie mit einer Spiele-Engine gearbeitet.
- Kommunikation auf Deutsch, in einfachen Worten.
- Arbeitet mit **Fedora Linux** (Anleitungen für Terminal und Dateimanager entsprechend).
- Testet auf dem eigenen PC; Claude arbeitet im Browser und kann Godot dort nicht sehen.

## So arbeiten wir zusammen
- **Engine:** Godot 4 (aktuelle stabile Version, Standard-Version ohne .NET). **Sprache:** GDScript.
- In **kleinen Schritten** arbeiten. Vor größeren Aufgaben kurz den Plan zeigen.
- Nach jedem Schritt in einfachen Worten erklären, was gemacht wurde und was sie in Godot
  tun oder testen soll: welches Fenster, welcher Knopf, welche Taste.
  Fachbegriffe beim ersten Auftreten erklären.
- Sauberer, gut lesbarer Code mit **kurzen Kommentaren auf Deutsch**.
  **Variablen- und Dateinamen auf Englisch.**
- Alle einstellbaren Werte (Tageslänge, Preise, Laufgeschwindigkeit, Mausempfindlichkeit,
  Freischaltintervalle usw.) gehören zentral in `scripts/autoload/game_config.gd`
  (Autoload „GameConfig“, im Code: `GameConfig.walk_speed`).
- **Grafik und Sound:** Nichts aus dem Internet herunterladen. Einfache Platzhalter
  (Grundformen, einfache Farben). Alles so bauen, dass eigene 3D-Modelle (.glb), Texturen
  und Sounds leicht austauschbar sind (siehe `docs/ASSET_GUIDE.md`).
- **Git:** Nach jedem funktionierenden Schritt ein Commit mit verständlicher deutscher Nachricht.
- **Fehlermeldungen:** Erst kurz erklären, was die Meldung bedeutet, dann beheben.
- **Screenshots und Selbstkontrolle (feste Regel seit Etappe 4f):** Bei jeder sichtbaren
  Änderung startet Claude Godot ohne Bildschirm, macht Testbilder aus festen Blickwinkeln,
  schaut sie selbst an und bessert nach, bis es stimmt – erst dann meldet Claude „fertig“.
  Die wichtigsten Bilder schickt Claude am Ende mit (SendUserFile). So geht's:
  1. Einmal je Chat: `tools/setup_godot.sh` (lädt Godot 4.6 nach /tmp/godot, verlinkt es als
     `godot`, installiert Software-Vulkan „lavapipe“, importiert das Projekt; ca. 1 Minute).
  2. Bilder: `tools/screenshots.sh <gruppe>` (startet Godot über `xvfb-run` mit Forward+ und
     lädt `scenes/tools/screenshot_tour.tscn`; etwa 10–15 s je Bild). Gruppen und Blickpunkte:
     `tools/screenshots.sh --list`. Weitere Angaben: `--only=a,b` (nur diese Blickpunkte),
     `--cam=x,y,z:tx,ty,tz` (freier Blickpunkt: Kamera : Ziel), `--scene=res://…` (andere
     Szene, z. B. ein einzelnes Haus), `--tag=vorher` (Zusatz im Dateinamen für
     Vorher/Nachher), `--hud` (Oberfläche mit aufnehmen), `--fov=…`.
  3. Die Bilder landen in `screenshots/` im Projekt (nicht in Git), Name
     `<gruppe>-<blickpunkt>[-tag].png`; ansehen mit dem Read-Werkzeug.
  4. Neue feste Blickwinkel: `scripts/tools/screenshot_views.gd` (je Gruppe eine Funktion,
     Lage aus StreetLayout, Augenhöhe `eye()`), dann in `all_sets()`/`get_set()` eintragen.
  Bei Grenzen und Wegen zusätzlich prüfen: Lauftest mit Physik (Spielfigur per
  `move_and_slide` auf die Grenze zulaufen lassen; vorübergehende Test-Szene, danach löschen)
  und bei Kulissen die Draufsicht mit `python3 tools/plan_check.py` (liest
  `scenes/world/houses.tscn`): `plan` zeichnet alle Hausumrisse nach `screenshots/plan.png`,
  `bound` prüft mit Sichtstrahlen von der Grenze am geraden Ende (nie ins Leere, nie bis ans
  Ende der Seitenstraße), `gate` misst, wie viel vom Torhaus man von der Ladentür sieht.

## Projektstruktur
```
scenes/            Szenen (.tscn)
  main.tscn        Hauptszene: Licht, Umgebung, Raum, Spielfigur, Oberfläche
  player/          Spielfigur
  rooms/           Räume des Hauses
  furniture/       Möbel (je eine Szene, Modell austauschbar)
  objects/         Interaktive Objekte (Stehlampe, Lieferkarton, Rückgabekasten in der Wand,
                   Sprossenfenster shop_window, Ladentür shop_door,
                   return_slots/ = Einwurf-Varianten; Scripts: LightSource, Seating,
                   Lichtschalter, Tür, Tablet, BookShelf, BookRow, BookLook, ReturnBox,
                   LooseBooks = ausgelegte Bücher, BookStand = Buch-Aufsteller, Counter = Theke;
                   player/: HeldBook = Buch in der Hand)
  effects/         Effekte (z. B. Staubpartikel)
  world/           Außenwelt (Straße, houses.tscn = alle Häuser, houses/ = Haustypen, Platz,
                   Gasse, Gassenende, Eingangstreppe, tools/ = Erzeuger-Szenen)
  ui/              Oberfläche (HUD mit Tastensymbolen, Pausenmenü, Inventar, Theken-Tablet, Hinweise,
                   Stil-Anzeige, Regal-Menü, Trage-Anzeige, Buch-Infokarte, Genre-Schriftzug,
                   Bücherauswahl, Zähl-Anzeige CountBadge; Scripts BookCover und BookMotifs zeichnen
                   Cover und Buchrücken)
    tablet_apps/   Apps des Theken-Tablets (je eine kleine Szene)
scripts/           GDScript-Dateien, gleiche Unterordner wie scenes/
  autoload/        Global verfügbare Scripts (GameConfig, Catalog, SaveManager, MenuStack, Settings,
                   Wallet, Inventory, BookStock, BookArt, CounterStyle, DebugKeys)
  interaction/     Interaktionssystem (Interactable)
  building/        Gestaltungsmodus (BuildMode, PlacedFurniture, PlacementSurface, Vorschau)
  data/            Datenformate (FurnitureData, SurfaceData, StyleTags, GenreData, BookData, Book,
                   LooseBook, TabletAppData, ReturnSlotData)
  rooms/           Raum-Logik (Room, PaintableWall, PaintableGrid: Möbel, Wände, Boden, Decke, Speichern)
  shop/            Lieferdienst (DeliveryManager)
  world/           Außenwelt (StreetLayout, WorldMesh, Street, HouseFacade, GatehouseFacade,
                   CornerHouseFacade, HouseTypes, HousesLayout,
                   Plaza, Alley, AlleyEnd, EntranceSteps; tools/ = Erzeuger für houses.tscn
                   und die Vorlagen; Szenen in scenes/world/)
data/
  furniture/       Datenblätter der Möbel (.tres) – werden automatisch in den Katalog geladen
  surfaces/        Datenblätter der Wandfarben und Böden (.tres)
  genres/          Datenblätter der Buch-Genres (.tres)
  books/           Bücherlisten (.txt, eine je Genre, eine Zeile pro Buch: Titel | Motiv)
  tips/            Texte der App „Tipps & Tricks“ (tips.txt, Aufbau oben in der Datei)
  tablet_apps/     Datenblätter der Tablet-Apps (.tres) – werden automatisch auf den Startbildschirm geladen
  return_slots/    Datenblätter der Einwurf-Varianten des Rückgabekastens (.tres, App „Fassade“)
assets/
  models/          Eigene 3D-Modelle (.glb), templates/ = Vorlagen in echter Größe zum Modellieren
  textures/        Texturen
  materials/       Gemeinsame Materialien (.tres), surfaces/ = Wand- und Bodenmaterialien
  shaders/         Shader (Platzhalter-Muster, Raster, Buchrücken, Buch-Vorschau)
  audio/music/     Musik
  audio/sfx/       Geräusche
  ui/              Oberflächen-Theme, icons/ = Symbole (Farbroller, Teppich)
docs/              Dokumentation
tools/             Shell-Skripte für Claude im Browser-Container (setup_godot.sh, screenshots.sh)
screenshots/       Testbilder von tools/screenshots.sh (nicht in Git)
```
(Werkzeug-Szenen: `scenes/tools/` + `scripts/tools/`, z. B. ScreenshotTour, ScreenshotViews.)

## Technische Konventionen
- Physik-Ebenen: 1 = `world`, 2 = `interactable`, 3 = `player`, 4 = `furniture`,
  5 = `build_blocker` (Sperrzonen für den Gestaltungsmodus, z. B. vor der Eingangstür),
  6 = `placement_surface` (Ablageflächen).
- **Jede Interaktion in der Spielwelt läuft über E.** Ausnahme Bücher (die Maus ist für Bücher
  da): Rechtsklick nimmt ein Buch, Linksklick legt das Buch obenauf ab, Linksklick halten am
  Regal räumt alle passenden ein, Mausrad dreht das Buch vor dem freien Ablegen
  (Interactable-Signale `take_requested`, `place_requested`, `place_all_requested`; nur im
  Spiel bei gefangener Maus, nie im Gestaltungsmodus oder in Menüs).
- **E blättert:** Hat das angeschaute Objekt keine eigene E-Aktion
  (`Interactable.reacts_to_interact()` = `prompt_text` nicht leer), blättert E durch die
  Bücher in der Hand (`BookStock.cycle_active`, Umschalt + E rückwärts). Objekte mit E-Aktion
  haben immer Vorrang.
- **Menüs von Objekten öffnet R** (Aktion `open_menu`): Interactable mit `menu_text` (Wort neben
  dem R-Symbol, leer = kein Menü) und Signal `menu_requested`. Kurzer Druck, kein Halten, nie E –
  so öffnet sich nie aus Versehen ein Menü. Bisher: Regal-Menü (schließt mit R, Esc oder Kreuz).
  **R geht überall:** Hat das Angeschaute kein Menü (`Interactable.has_menu()`), öffnet R
  dasselbe Menü ohne Regal (`ShelfMenu.open_for(null)`): Regal-Teile ausgegraut, Bücherauswahl
  aktiv. Bücher aus dem Lager in die Hand nimmt man **nur** dort (Menü bleibt offen, bis die
  Hände voll sind). Code im ShelfMenu muss immer mit `shelf == null` klarkommen.
  Bücherauswahl: erst „Alle Bücher“ (`ShelfMenu.ALL_GENRES`), dann die Genres; Kacheln dezent
  in Genre-Farbe (`BookPicker`-Eintrag `tint`, Stärke `GameConfig.book_picker_tint`); im
  offenen Menü genommene Bücher bleiben als Kachel mit Handsymbol (`held`), ein Klick
  (`entry_chosen`) legt sie zurück ins Lager (`ShelfMenu.return_book`) – bewusste Ausnahme
  von „nur ein Weg“ (macht nur den eigenen Griff ins Lager rückgängig; volle Hände schließen
  das Menü, das letzte Buch geht dann mit Q ins Lager).
- **Tablets:** Alles, was als Tablet erscheint (Regal-Menü, Theken-Tablet mit Apps), nutzt die
  gemeinsame Vorlage `TabletFrame` (Gehäuse + Bildschirm, Farben `TabletFrame.TEXT_COLOR` …,
  `make_label`, `make_close_button` = Kreuz oben rechts). Knöpfe sind Symbol-Knöpfe
  (`TabletIconButton`, gezeichnete Symbole, Tooltip mit einem Wort) statt langer Textzeilen.
  Tooltips und aufklappende Listen haben ihren Stil im Theme (`assets/ui/cozy_theme.tres`).
- **Theken-Tablet** (`CounterTablet`, Gruppe `counter_tablet`, `open_tablet()`, `open_app(id)`,
  `go_home()`): Startbildschirm mit App-Symbolen, Leiste mit Home, Logo + Name (+ Untertitel)
  der App, Kontostand, Kreuz. Esc schließt immer das ganze Tablet; Öffnen startet immer auf dem
  Startbildschirm. **Neue App = neue Szene** in `scenes/ui/tablet_apps/` (Wurzel-Script erbt von
  `TabletApp`: `app_opened()`, `refresh()`, Bausteine `make_label` …; `request_refresh()` statt
  direkt neu aufbauen, wenn ein Knopf sich selbst ersetzen würde) **+ Datenblatt**
  `data/tablet_apps/<id>.tres` (`TabletAppData`: Name = bei Läden der Ladenname, `tagline`,
  Symbol oder eigenes Bild, Farbe, Reihenfolge; neue Symbole hinten an das Enum anhängen) – kein
  Code am Startbildschirm. Einkaufs-Apps erben von `ShopApp` (Warenkorb, Angebotskarten).
  Apps: Nest & Nook (furnishing), Bücherladen (books), Lager (storage, nur Übersicht +
  Sammlung), Fassade (facade; Abschnitte: neue Fassaden-Einstellung = Funktion mit
  `make_section()` + Eintrag in `SECTIONS`, Auswahlkarten `make_option_card()`), Statistik
  (stats; neue Werte über Gruppe `stat_sources` mit `get_stats()`), Tipps & Tricks (tips;
  Texte in `data/tips/tips.txt`).
- **Jede Aktion hat nur einen Weg** (z. B. getragene Bücher einräumen = Linksklick halten am
  Regal, ins Lager = Q halten – nicht zusätzlich als Knopf im Regal-Menü). Einzige Ausnahme:
  Ein im R-Menü gerade genommenes Buch legt ein Klick auf seine Kachel zurück.
- **Esc-Regel:** Was sich öffnen lässt (Gestaltungsmodus, Menüs, später Shop), meldet sich mit
  `MenuStack.open(self)` an und hat `close_from_escape()`. Esc schließt immer zuerst das
  Oberste; nur wenn nichts offen ist, öffnet sich das Pausenmenü.
- Interaktive Objekte bekommen einen `Interactable`-Knoten (Area3D, `scripts/interaction/interactable.gd`)
  und reagieren auf dessen Signal `interacted`.
- Möbel-Szenen haben einen Knoten `Model` (austauschbare Optik) und einen `Body`
  (StaticBody3D mit Kollision). Fußpunkt auf Höhe 0, Vorderseite zeigt nach +Z.
  Regale bekommen eine Kollisionsform pro Brett. Ablageflächen sind `PlacementSurface`-Knoten
  (Ursprung = Oberkante). Dinge zum Aufhängen: Ursprung hinten in der Mitte.
- `FurnitureData.placement`: wohin ein Objekt darf (Boden, Ablagefläche, Wand, Tür, Decke).
  Deckenobjekte: Ursprung oben am Aufhängepunkt.
- Raster: `GameConfig.grid_cell_size` = 1/9 m; Boden/Decke in Abschnitten von 3 x 3 Feldern.
  Raummaße (Breite, Tiefe) sollen Vielfache von 1/3 m sein. Raumhöhe: `GameConfig.room_height`.
- **Eckladen (seit Etappe 4a):** Der erste Raum ist ein Rechteck (innen 6 x 8 m) mit
  abgeschrägter vorderer linker Ecke (schräge Eingangswand, Tür mittig). Mass der Schräge:
  `GameConfig.corner_cut` (2,0 m); `Room.is_inside_build_area` lässt die abgeschnittene Ecke
  frei. Die schräge Wand ist eine eigene `PaintableWall` (`Walls/Diagonal`) + CSG-Wand
  (`Structure/WallDiagonal` mit `DoorHole`). Fenster (`Walls/Front`, `Walls/Left` mit
  `WindowHole`) und Tür sind eigene, austauschbare Szenen (`scenes/objects/shop_window.tscn`,
  `shop_door.tscn`). Seit Etappe 4b sind auch Boden und Decke in der Ecke abgeschrägt
  (`Structure/Floor` und `Structure/Ceiling` sind CSG-Container mit einem `CornerCut`-Abschnitt;
  der Belag spart die Ecke über `PaintableGrid.cut_corner` aus und schneidet Felder genau an
  der Schräge ab), der Raum ist also ein sauberes Fünfeck.
  Transform-Basen der schrägen Knoten müssen rechtshändig sein (+Z in den Raum), sonst liegen
  Farbflächen/Modelle falsch herum. Der Raum hat kein künstliches Füll-Licht mehr; Licht kommt
  vom Umgebungslicht und den Fenstern.
- **Hülle des Hauses (seit Etappe 4c):** Vordere, linke und schräge Wand (`Structure/Wall…/Wall`)
  sind `CSGPolygon3D`-Grundrisse (Trapeze, nach oben hochgezogen, `depth` = Höhe) und stoßen auf
  Gehrung zusammen; Außenecken der Schräge (-3,2 | -2,0828) und (-1,0828 | -4,2). Alle
  Außenwände reichen bis zur Oberkante der Deckenplatte (Raumhöhe + 0,2 m, `Room._apply_room_height`),
  die Deckenplatte liegt innen zwischen den Wänden. Jede Öffnung braucht drei passende Teile:
  CSG-Loch, Aussparung in der `PaintableWall` (`openings`) und Rahmen der Szene.
  Darüber baut `UpperFloors` (`scripts/rooms/upper_floors.gd`, Knoten in main.tscn) die
  Obergeschosse als geschlossene Hülle mit Fenster-Platzhaltern (`scenes/objects/upper_window.tscn`)
  und das Walmdach; Anzahl/Höhe: `GameConfig.upper_floor_count`, `upper_floor_height`; je
  Geschoss ein Knoten `Floor1`, `Floor2` … (später freischaltbar, `get_floor(i)`, `get_floor_base(i)`).
  `UpperFloors` baut seit Etappe 4d auch den Sockel unten am Haus (`plinth_sides`; rechts
  schließt das Nachbarhaus an).
- **Draußen (seit Etappe 4d):** Der Ladenboden bleibt auf 0; draußen liegt alles
  `GameConfig.shop_floor_rise` tiefer. `Outside` liegt auf Gehweg-Höhe (main.gd setzt y), darunter
  bauen sich aus GameConfig: `Street` (Fahrbahn, Gehwege, Bordsteine, Seitenstraßen, EINE ebene
  Bodenkollision – die Fahrbahn liegt nur optisch tiefer –, weiche Grenzen, `TrafficPoints` mit
  Gruppe `traffic_points` und Metadaten `kind` = car/bike/walker für späteren Verkehr),
  `Houses` (feste Szene `scenes/world/houses.tscn`, siehe unten), `Plaza`, `Alley` (mit
  `scenes/world/alley_end.tscn`). Lage aller Teile nur über
  `StreetLayout` (statische Funktionen, z. B. `ground_y()`, `curb_z()`, `recess_z()`,
  `straight_bound_x()`, `is_straight(seite)`, `end_path(seite)`), Maße nur in GameConfig.
  **Straßenenden (seit Etappe 4f rund):** Mittelstück gerade von `end_start_x(-1)` bis
  `end_start_x(1)`, jedes Ende ein Weg `StreetLayout.end_path(seite)` (Punkte mit pos, dir, s,
  part; Abschnitte curve/side_street bzw. bend/approach/passage/behind; seitlicher Versatz
  `end_offset(punkt, abstand, seite)`, positiv = Bücherei-Seite, bleibt in Kurven auf derselben
  Straßenseite). Gerades Ende (`GameConfig.straight_street_end`): Grenze quer bei
  `straight_bound_x()` = `straight_bound_offset` hinter den festen Nachbarn, `straight_street_length`
  dahinter eine runde 90°-Kurve zur Bücherei-Seite (`straight_curve_radius`), dann
  `straight_side_street_length` bis zu Querhäusern – so gewählt, dass man von der Grenze aus nie
  das Ende sieht. Anderes Ende: `gate_bend_offset` hinter den festen Nachbarn eine sanfte Kurve
  (`gate_bend_angle`, `gate_bend_radius`) weg von der Bücherei, `gate_approach_length` danach das
  **Torhaus** (`GatehouseFacade`, Haustyp `GameConfig.gatehouse_type`, Kollision nur die
  Pfeiler, `StreetLayout.gatehouse_front()`); so gewählt, dass man es von der Ladentür zu etwa
  80 % sieht. Innen in beiden Kurven ein **Eckhaus mit abgeschrägter Ecke**
  (`CornerHouseFacade`, Haustypen `corner_90`/`corner_30` = `straight_corner_house` /
  `gate_corner_house`; Ecke rechts, `corner_angle`, `chamfer_width`, `side_length`; Aufstellung
  `HousesLayout._corner_placement`). Straße, Bordsteine und Gehwege der Enden baut `Street` als
  Bänder entlang des Weges; die Grenze im Bogen liegt dort (`Street.GATE_BOUND_INSIDE`).
  Häuser entlang von Kurven: `HousesLayout._fill_curve` (Sehnen auf der Linie der Hausfronten,
  Vorderseite zur Straßenmitte). Prüfen: `tools/plan_check.py` (siehe Screenshot-Regel).
  `EntranceSteps` (Podest
  + Stufen, nie breiter als die schräge Wand, unsichtbare Rampe als Kollision) liegt auf
  Ladenboden-Höhe. Kulisse baut `WorldMesh` (Vierecke/Quader mit Vertex-Farben); Kulissen-
  Szenen nutzen statt des Platzhalters ein Kind „Model“, wenn vorhanden. Draußen wird nichts
  gespeichert.
- **Häuser (seit Etappe 4e):** Jedes Haus ist ein fester Knoten in `scenes/world/houses.tscn`
  (Gruppen LibraryRow, Opposite, StraightEnd, GateStreet), Instanz eines Haustyps
  `scenes/world/houses/<id>.tscn` (Wurzel `HouseFacade`, @tool, feste Maße width/depth/
  eaves_height; je Haus nur Farben, `casts_shadow`, `solid`, ggf. `side_windows` = Fenster in
  einer sichtbaren Seitenwand, im Plan als "props"). Neu erzeugen nur über
  `scenes/world/tools/generate_houses.tscn` (Planung `HousesLayout`, Typen-Maße `HouseTypes`;
  GameConfig: `neighbor_house_types`, `alley_house_types`, `opposite_feature_house`,
  `terrace_house_types`) – überschreibt Handänderungen. Gleiche Maße = ein gemeinsames Mesh
  (Cache in HouseFacade), Material `house_facade.tres`: Alpha der Vertex-Farbe wählt die Farbe
  (1 fest, 0,75 Wand, 0,5 Tür, 0,25 Akzent), Farben je Haus als `instance uniform`
  (`set_instance_shader_parameter`). Häuser gegenüber/hinter der Grenze/an den Seitenstraßen
  ohne Schatten, Nachbarn nur bis `GameConfig.house_shadow_distance`; Kollision nur, wo man
  hinkommt. Reihen werden lückenlos gefüllt: Nachbarn überlappen um wenige cm, jedes zweite
  Haus steht 4 mm zurück (kein Z-Fighting).
- `WorldMesh.xform`: Teile in Fassaden-Koordinaten bauen (x entlang der Wand, +z nach draußen)
  und gedreht einsetzen (schräge Fassaden, Seitenwände); danach wieder `Transform3D.IDENTITY`.
- **Vorlagen zum Modellieren:** `assets/models/templates/{houses,furniture,world}/*.glb`
  (echte Größe, Ursprung/Vorderseite wie die Szene; Ordner mit `.gdignore`), erzeugt von
  `scenes/world/tools/export_templates.tscn`. Neue Möbel/Haustypen → Vorlagen neu erzeugen.
- Fensterbänke: `ShopWindow` (Script der Fenster-Szene) formt Bank, Ablage und Kollision
  (`SillBody`: Bank, Glas, Seitenrahmen) aus `GameConfig.window_sill_depth`.
- Sonnenschatten ohne `light_angular_distance` (PCSS zeigte Treppenkanten); weich macht sie
  `shadow_blur` mit dem Filter der Grafikstufe.
- **Oberflächen/Menüs:** Projekt nutzt Stretch-Modus `canvas_items` + `expand` (Basis 1600 x 900).
  Neue Menüs immer mit Anchors und Containern bauen, dann passen sie sich automatisch an.
  Menüs, deren Inhalt wachsen kann, dürfen nie höher als das Bild werden: feste Höhe über
  Anchors (Anteil der Bildhöhe), wachsender Teil in einen ScrollContainer, Kopf und
  „Schließen“ fest (Beispiel: `ShelfMenu`).
- Spieler-Einstellungen gehören in `Settings.DEFINITIONS` (`scripts/autoload/settings.gd`),
  nicht in GameConfig; der Einstellungsbereich im Pausenmenü baut sich daraus selbst.
- Alles, was Licht abgibt, bekommt `LightSource` (Art ELECTRIC oder FLAME) + Interactable.
  `shadow_importance` legt fest, ob die Lampe Schatten werfen darf (NONE, IMPORTANT, OPTIONAL
  = nur auf „Hoch“). Kleine Lichter (Kerzen) ohne Schatten.
- Grafikstufen (Niedrig/Mittel/Hoch) stehen in `GameConfig.graphics_presets`.
- Sitzmöbel: Knoten `Seating` mit `SeatPoint`-Markern (Blickrichtung +Z) + Interactable.
- Hervorhebung immer über `FurnitureUtils.get_highlight_material()` (dezent, Stärke in GameConfig).
- Möbel im Raum sind `PlacedFurniture`-Knoten (unter `Furniture` im Raum) mit einem
  Datenblatt (`FurnitureData`); das Modell wird daraus erzeugt.
- Neue Möbel/Oberflächen = neues Datenblatt in `data/furniture/` bzw. `data/surfaces/`, kein Code.
- Unterkategorien: `FurnitureData.SUBCATEGORIES` (je Kategorie Paare `[id, Name]`), im Datenblatt
  `subcategory`. Filter über Listen: `FilterBar` (`setup(...)`, `matches(objekt)`).
- Sonnenschatten: Kaskaden mit weicher Überblendung (`main.gd`, Werte in GameConfig); ohne
  Überblendung entsteht eine wandernde Linie im Fensterlicht.
- Speichern: Knoten in der Gruppe `persist` mit `save_key`, `get_save_data()` und
  `load_save_data()` werden vom `SaveManager` automatisch gespeichert (JSON in `user://`).
- Stil-Merkmale sind überall freiwillig; ohne Stil-Merkmal = stilneutral, zählt nicht mit.
- **Geld** ändert sich nur über `Wallet.spend(betrag, grund)` / `Wallet.earn(betrag, grund)`
  (Etappe 6 baut darauf auf). Anzeige als Text: `Wallet.format(betrag)`.
- **Inventar** (`Inventory`): Möbel mit Anzahl (`add_furniture`, `take_furniture`), Oberflächen
  einmal besessen (`add_surface`, `owns_surface`). Was im Raum steht, zählt der Raum
  (`Room.count_placed`). Der Gestaltungsmodus zeigt nur, was im Inventar liegt (Anzahl ≥ 1).
- `FurnitureData.is_essential` = gehört fest zur Bücherei (Tablet): nicht kaufbar, nicht
  verkaufbar; `Room.ensure_essentials()` stellt es zurück, falls es fehlt.
  `SurfaceData.owned_at_start` = von Anfang an vorhanden.
- `FurnitureData.is_fixed` (seit Etappe 4a) = fest verbaut (z. B. die Theke): im
  Gestaltungsmodus verschiebbar, aber nicht wegräumbar (X verweigert) und nie im Inventar
  (`BuildMode` prüft `is_fixed` beim Aufheben, Verschieben und Wegräumen). Sinnvoll mit
  `is_essential` zusammen.
- **Theke** (`scenes/furniture/counter.tscn`, Script `Counter`): fest verbaut
  (is_essential + is_fixed). Ihr Stil (Farben) liegt zentral im Autoload `CounterStyle`
  (STYLES, `set_style`, `get_style`, Signal `changed`, gespeichert, Gruppe `persist`); die
  Theke hört auf `changed` und färbt sich. Stilauswahl in der App „Fassade“, aber bewusst
  von überall aufrufbar. Module (Backshop, Kaffee) hängen unter dem Knoten `Modules` –
  Struktur steht bereit, noch nichts umgesetzt.
- **Deko-Regal** (`deco_shelf_light`, Szene `deco_shelf.tscn`, Unterkategorie `deco_shelf`):
  ein Regal ohne `BookShelf`/`BookRow`, darum lassen sich dort keine Bücher einräumen – nur
  Ablageflächen zum Dekorieren. Bücherregale (mit BookShelf) gibt es weiter im Shop.
- **Einkaufen:** Läden „Nest & Nook“ (Möbel, Deko, Oberflächen; Kaufen/Verkaufen) und
  „Bücherladen“ (Pakete) am Theken-Tablet; Bestellungen gehen an den `DeliveryManager` (Gruppe
  `delivery_manager`, `place_order(inhalt)`), Inhalt als Liste von
  `{ "kind": "furniture"/"surface"/"books", "id": …, "count": … }` (bei "books": id = Genre,
  count = Zahl der Bücherpakete). Bücher aus dem Lager in die Hand: nur im R-Menü
  (`BookStock.take_stored_book` + `carry`).
- Lieferung: ein Karton pro Objekt (`DeliveryManager.split_contents`); Kartons stehen in Stapeln
  (`_stacks`), Lieferort = Marker3D `Outside/Deliveries`. Der E-Zielbereich eines Kartons darf
  nicht über ihn hinausragen (sonst trifft man beim Stapel den falschen).
- Lampen mit Licht zwischen vielen kleinen Teilen (Kronleuchter, Geflecht) bekommen
  `shadow_importance = NONE`.
- Dezente Hinweise oben im Bild: `Notice.post(self, "Text")`.
- Was ins Lager (Inventar) geht, zeigt beiläufig die Lager-Anzeige unten rechts:
  `StorageIndicator.add_item(self, datenblatt)` bzw. `add_icon(self, bild)` (mit Warteschlange).
  Vorschaubilder von Modellen: `ThumbnailRenderer` (zwischengespeichert).
- Interaktion: Trifft der Blick den festen Körper eines Objekts, gilt dessen Interactable
  (`Interactable.find_for`) – E-Bereiche müssen den Körper also nicht umschließen.
- Türen (`Door`, Gruppe `doors`): Teile, die mitschwingen, unter dem Knoten `Hinge`. Eine offene
  Tür bleibt im Gestaltungsmodus offen; an die offene Tür hängt man nichts, was an ihr hängt,
  wird erst bei geschlossener Tür bewegt (`Door.is_swinging(item)`, `is_leaf(collider)`).
  Der Schwenkbereich ist eine Sperrzone (Ebene `build_blocker`) – auch für ausgelegte Bücher
  (`LooseBooks._blocked_for_placing`).
- Die Spielfigur kann man anhalten: `player.movement_enabled = false` (z. B. im Shop).
- Eingabe-Aktionen: `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `jump`,
  `crouch`, `interact`,
  `pause`, `toggle_build_mode` (Tab), `build_place`, `build_cancel` (rechte Maustaste),
  `build_rotate`/`build_rotate_back` (Mausrad), `build_toggle_grid`, `build_delete` (X),
  `build_paint_all` (Umschalt), `toggle_fps` (F3), `debug_fill_return_box` (F9, Testtaste),
  `debug_add_money` (F10, Testtaste), `book_rotate`/`book_rotate_back` (Mausrad, Buch obenauf
  vor dem Ablegen drehen), `book_take` (rechte Maustaste), `book_place` (linke Maustaste;
  halten am Regal = alle einräumen),
  `store_books` (Q halten: alle getragenen Bücher ins Lager), `open_menu` (R: Menü des
  angeschauten Objekts, z. B. Regal-Menü).
- Möbel-Knoten in Szenen können ihre Nummer (`uid`) und ihr Trägermöbel (`support_uid`) fest
  eintragen (z. B. Tablet auf der Theke).
- Renderer: Forward+ (nötig für volumetrischen Nebel / Lichtstrahlen).
- **Bücher:** Neues Genre = neues Datenblatt in `data/genres/` + Bücherliste
  `data/books/<id>.txt` (kein Code). Neues Buch = neue Zeile `Titel | Motiv` (Motive:
  `BookMotifs`, Liste in docs/ASSET_GUIDE.md). Titel sind gemütlich, erfunden, nie düster.
  Ein Titel ist `BookData` (Katalog, `Catalog.get_book(id)`, id = "genre/titel-slug"),
  ein Exemplar ist `Book` (`book.data`, Zustand). Bücher sind keine Knoten, sondern Daten;
  der Bestand (`BookStock`) kennt Lager, Getragenes (`carried`, Buch obenauf:
  `get_active_book()`) und die Sammlung (`is_discovered`), zählt Regale (Gruppe
  `book_shelves`), den Rückgabekasten (Gruppe `return_boxes`) und ausgelegte Bücher (Gruppe
  `LooseBooks.GROUP`) mit.
  Freigeschaltet: `BookStock.is_genre_unlocked(id)` / `unlock_genre(id)`.
- Bücher: einzeln möglich, aber nie nötig – alles Einzelne hat eine Sammel-Variante (Auffüllen,
  alle einräumen, sortieren); nie Zeitdruck (Gemütlichkeit vor Arbeit).
- Cover und Buchrücken zeichnet `BookCover` (Gestaltungen in `BookData.STYLES`); `BookArt`
  macht daraus den Atlas aller Rücken (Regale), Cover-Bilder (`request_cover`) und einen
  Cover-Atlas für ausgelegte Bücher (`retain_cover` / `release_cover`, Feld per `get_cover_slot`).
- **E tippen / E halten:** Ein Interactable mit `supports_hold` unterscheidet kurz (Signal
  `interacted`, beim Loslassen) und lang (Signal `held`, `GameConfig.interact_hold_time`) –
  gerade nutzt das kein Objekt (Menüs öffnen mit R, nicht mit E halten).
  Genauso Linksklick: `handles_placing` = das Objekt nimmt Bücher selbst an (Signal
  `place_requested`); mit `supports_place_all` zählt Halten als „alle einräumen“
  (`place_all_requested`, `GameConfig.place_all_hold_time`). Ein kurzer Druck ist nie Halten
  und umgekehrt; während der Ring läuft, passiert nichts anderes. Q halten:
  `GameConfig.store_books_hold_time`.
  `aimed(from, richtung)` meldet jedes Bild den Blick (z. B. welches Buch im Regal);
  `highlight_owner = false` = Objekt hebt selbst hervor.
- **Weniger Text:** Unter der Bildmitte nur kleine Tastensymbole mit höchstens einem Wort
  (`KeyHints`, `KeyHintIcon`). Die Wörter kommen aus dem Interactable: `prompt_text` (E),
  `hold_prompt_text` (E halten, Ring ums Symbol), `take_text` (rechte Maustaste, „Nehmen“),
  `menu_text` (R, „Menü“) – immer **ein** kurzes Wort („Öffnen“, „Sitzen“, „An“), leer = kein
  Symbol. Hinweise beim Tragen (Ablegen, Einräumen, Drehen, Blättern, Lager) zeigt die
  Trage-Anzeige unten (`CarryIndicator`, `show_hints`, Ring um Q beim Halten); „Drehen“ nur,
  wo das Mausrad wirkt (`LooseBooks.can_turn()`), „Blättern“ nur, wenn E nichts anderes tut. Keine Sätze im Spielbild; Erklärungen gehören in die Tastenhilfe
  im Pausenmenü. Spieler-Einstellung „Hinweise“: `Settings` `interface/hints`.
- Bücherregale: Knoten `BookShelf` mit `BookRow`-Fächern (Ursprung = Mitte der Brett-Oberkante)
  und einem `Interactable` **ohne eigene Kollisionsform** (getroffen wird der Körper des
  Regals, so bleibt Deko im Regal erreichbar). Jedes Brett bekommt automatisch eine
  Ablagefläche für Deko (`PlacementSurface.max_height` = Fachhöhe). Jedes Buch hat eine freie
  Lage auf seinem Brett (linke Kante, feines Raster `GameConfig.shelf_grid_step`); wo Deko
  steht (Möbel mit `support_uid` = Regal), kommen keine Bücher hin. Alle Bücher eines Regals
  sind ein MultiMesh (Shader `book_spine.gdshader`, Rücken aus dem Atlas) – nie einzelne
  Knoten je Buch. Das Genre zeigt beim Anschauen `GenreCaption.show_text(self, "Krimi")`.
- **Fächer** (nie „Etage“ sagen): Jedes Brett (`BookRow`) ist ein Fach mit eigenem Genre
  (`BookShelf.row_genres`, "" = noch keins, `MIXED` = Gemischt; `get_row_genre(row)`,
  `set_row_genre(row, id)`, `row_accepts(row, genre)`; `set_genre(id)` = alle Fächer gleich).
  **Automodus** (Standard): `row_auto[row]` – das Fach nimmt alles an, `get_row_genre` liefert
  dann das erkannte Genre (`detect_row_genre`); `set_row_genre`/`set_genre` schalten Auto aus,
  `set_row_auto`/`set_all_auto`. Immer `get_row_genre`/`row_accepts` benutzen, nie
  `row_genres` direkt lesen. Gespeichert als "row_auto"; ohne Wert: Auto, wenn kein Genre.
  Namen „Fach 1“, „Fach 2“ … in Lesereihenfolge von oben links nach unten rechts
  (`get_fach_order()`, `get_row_label(row)`), unabhängig von der Reihenfolge in der Szene.
  Auffüllen, Einräumen und Sortieren beachten die Fächer; was nirgends passt, bleibt in der
  Hand. Linksklick halten: `put_carried_at(row, x)` ab dem angeschauten Fach und der Stelle,
  Rest in die nächstgelegenen passenden Fächer; Auffüllen füllt von oben nach unten.
  Sortierarten: `BookShelf.SORT_MODES` (+ `_sort_key`), gewählte Art `sort_mode` wird mit dem
  Regal gespeichert ("sort"). Fach hervorheben: `highlight_rows([…])` (Shader
  `fach_highlight.gdshader`, Stärke in GameConfig). Ältere Spielstände: das alte Regal-Genre
  gilt für alle Fächer, Sortierart Genre und Titel.
- **Ausgelegte Bücher** (frei in der Welt, z. B. auf Tischen): ein `LooseBooks`-Knoten je Raum
  (`room.loose_books`), jedes Buch ein `LooseBook` (Exemplar, Lage, `support_uid` = Möbel
  darunter, `pose` FLAT/UPRIGHT/LEANING/OPEN – OPEN „aufgeschlagen“ ist vorgesehen, aber noch
  nicht umgesetzt). Ablegen geht überall, wo Deko hindarf (Ablageflächen, Boden), flach mit
  Cover oben; an Wänden angelehnt, neben Buchstützen (Unterkategorie `bookend`) oder
  stehenden Büchern aufrecht. Für spätere Besucher: `find_spot(from, richtung, buch)`,
  `place(buch, lage, support_uid, pose)`, `remove(eintrag)` – keine Spieler-Logik darin
  nötig. Alle Bücher eines Raums sind **ein** MultiMesh (Shader `book_loose.gdshader`, Cover
  aus dem Cover-Atlas) – nie einzelne Knoten je Buch; Zielsuche nur in der Nähe.
  Drehen vor dem Ablegen: `LooseBooks.turn_degrees` (relativ zum Blick bzw. zum Buch darunter,
  nach dem Ablegen 0), `turn_active_book(±1)`, Schritt `GameConfig.book_turn_step`; angelehnt
  höchstens `GameConfig.loose_book_lean_max_turn`; aufrecht in Reihen und im Regal nie. Die
  Drehung steckt in der gespeicherten Lage (kein eigenes Feld).
  Der Raum verschiebt sie mit ihrem Möbelstück (`move_with`) und gibt sie beim Wegräumen (X)
  ins Lager (`release_on`); gespeichert unter `loose_books` im Raum. Ausgelegte Bücher haben
  keine Kollision: Der Gestaltungsmodus prüft sie extra (`overlaps_shape`), die Spielfigur
  über `pick_distance` (verglichen mit dem ersten festen Körper, nicht mit E-Bereichen).
  Ablegen: Ein Buch darf nie in ein Objekt hineinragen (`_blocked_by_solid`, Kollisionsformen
  der Ebenen world + furniture, um `SOLID_MARGIN` kleiner) – sonst rot. Kollisionsformen von
  Möbeln sollen darum zur sichtbaren Form passen und oben genau mit ihren Ablageflächen enden.
  Vorschau ("Blaupause") für Bücher und Möbel: `FurnitureUtils.make_blueprint_material()` +
  `set_blueprint_valid()` (Shader `blueprint.gdshader`: unshaded, ruhiges Blau, Deckkraft
  `GameConfig.preview_opacity`, leicht zur Kamera versetzt – kein Z-Fighting, keine Lichtkante).
  Stapel = Bücher, die lückenlos aufeinander liegen (`LooseBooks.STACK_GAP`).
  **Buchstützen** (Unterkategorie `bookend`, `BookShelf.is_bookend(data)`): Bücher rasten an
  ihnen ein, nie umgekehrt – Deko rastet im Gestaltungsmodus nie an Büchern ein. Luft zu Büchern
  `BookShelf.deco_margin(data)` (Buchstütze `BOOKEND_MARGIN`, sonst `DECO_MARGIN`); frei
  ausgelegt knapp daneben (`GameConfig.bookend_snap_distance`) steht ein Buch aufrecht daran;
  Blick auf eine Buchstütze im Regal zählt als Blick aufs Regal (`Interactable.find_for`,
  `BookShelf.holding(item)`).
  Anlehnen an Möbel nur mit `FurnitureData.books_can_lean` (Lehnen, große Töpfe), flach auf
  Möbeln ohne Ablagefläche nur mit `books_can_lie` (Polster) – nie an kleiner Deko, nie frei
  hochkant. **Buch-Aufsteller:** Knoten `BookStand` (+ Marker `BookSpot`) in einer Möbel-Szene;
  das Buch darin ist ein ausgelegtes Buch mit Haltung `DISPLAYED` und `support_uid` = Aufsteller
  (genau eins je Aufsteller).
- Bücher tragen: höchstens `GameConfig.max_carried_books`; `BookStock.carry(liste)` liefert,
  was nicht mehr passt; volle Hände ohne Text zeigen: `BookStock.show_hands_full()`
  (der Stapel in der Hand wackelt).
- Z-Fighting vermeiden: Teile eines Modells nie mit Flächen genau in derselben Ebene
  enden lassen (gleiche Richtung, überlappend) – die kleinere Fläche 2 mm nach innen setzen.
- **Rückgabekasten** (`ReturnBox`, `scenes/objects/return_box.tscn`): genau einer, fest in der
  Hauswand neben der Tür (Knoten im Raum, kein Möbel; Ort = Marker unter `ReturnBoxSpots`,
  `move_to_spot`). `ReturnBox.find(get_tree())`, `add_books(liste)` liefert, was nicht passt
  (`GameConfig.return_box_capacity`), `take_some`/`take_all`, `set_slot(id)` = Einwurf-Variante
  (`ReturnSlotData`, `Catalog.get_return_slot`), Signal `changed`. Speichert sich selbst
  (Schlüssel "return_box": Bücher, Einwurf, Ort). Immer geschlossen; Anzahl beim Anschauen
  über `CountBadge.show_count(self, n, voll)`. Alte Spielstände: Möbel-id "return_box" →
  `Room._migrate_legacy_return_box` (Bücher in den festen Kasten, Rest ins Lager).
- Sperrzonen (Ebene `build_blocker`) können ihren Hinweis als Metadaten tragen
  (`keep_clear_text`, z. B. „Vor dem Rückgabekasten bitte frei lassen.“).
- Vorschaubilder beliebiger Szenen: `ThumbnailRenderer.request_scene(key, pfad, icon, callback,
  wand_größe)` (mit Stück Hauswand dahinter, fast von vorn).
- Möbel mit Inhalt (Regal): Knoten in der Gruppe `PlacedFurniture.CONTENTS_GROUP`
  mit `get_contents_data()`, `load_contents_data()`, `release_contents()` – der Raum speichert
  den Inhalt mit dem Möbelstück, beim Wegräumen (X) geht er ins Lager.
- Startgeschenke fürs Inventar: `GameConfig.start_furniture_gifts` (jedes nur einmal, auch in
  älteren Spielständen).
- Testtasten laufen über das Autoload `DebugKeys` und lassen sich alle auf einmal abschalten:
  `GameConfig.debug_keys_enabled = false`.
