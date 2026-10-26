# CLAUDE.md – Arbeitsregeln für dieses Projekt

Dieses Projekt ist ein gemütlicher Bücherei-Simulator („Cozy Bücherei“) in Godot 4.
Die Gesamtidee steht in `docs/GAME_DESIGN.md`, der Etappenplan in `docs/ROADMAP.md`.

## Über die Entwicklerin
- Absolute Anfängerin: hat noch nie programmiert und noch nie mit einer Spiele-Engine gearbeitet.
- Kommunikation auf Deutsch, in einfachen Worten.
- Arbeitet mit **Fedora Linux** (Anleitungen für Terminal und Dateimanager entsprechend).
- Testet auf dem eigenen PC. Blender ist auch auf ihrem PC installiert (Modelle dort anschauen).

## Umgebung (seit Etappe 4g: Dev-Container auf ihrem PC)
- Claude läuft in einem Docker-Dev-Container (`.devcontainer/`), Projektordner `/workspace`.
- Firewall: nur GitHub, npm und Anthropic sind erreichbar (nichts sonst herunterladen).
- Godot ist installiert (`godot`), es gibt keinen Bildschirm: `godot --headless` zum Prüfen,
  Importieren und für Werkzeug-Scripts. Testbilder aus Godot brauchen Xvfb und Software-Vulkan
  (`xvfb`, `mesa-vulkan-drivers`, seit 4g im Dockerfile – nach dem Neubau des Containers geht
  `tools/screenshots.sh` wieder; `tools/setup_godot.sh` ist nur für den Browser-Container).
- Blender 3.4 ist installiert (`blender`), nur im Hintergrund: `blender -b --factory-startup
  --python script.py`. Kontrollbilder mit Cycles (CPU, ohne Entrauschen). EEVEE geht nicht
  (kein Bildschirm). Blenders glTF-Export braucht numpy (seit 4g im Dockerfile:
  `python3-numpy`); die Stil-Modelle schreiben ihre .glb ohnehin selbst (`style_lib.write_glb`).
- `gh` ist angemeldet: nach jedem fertigen Schritt committen und nach origin pushen.
- `Game design/` = Bildersammlung der Entwicklerin (Stilrichtung, Inspiration), mit `.gdignore`,
  nicht in Git.

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
- **Grafik und Sound:** Nichts aus dem Internet herunterladen. Seit Etappe 4g baut Claude die
  Grafik selbst im einheitlichen Stil (`docs/STYLE_GUIDE.md`): Modelle per Blender-Script,
  Texturen per Godot-Script; wo noch nichts gebaut ist, bleiben die einfachen Platzhalter.
  Alles so bauen, dass eigene 3D-Modelle (.glb), Texturen und Sounds leicht austauschbar sind
  (siehe `docs/ASSET_GUIDE.md`).
- **Git:** Nach jedem funktionierenden Schritt ein Commit mit verständlicher deutscher Nachricht.
- **Fehlermeldungen:** Erst kurz erklären, was die Meldung bedeutet, dann beheben.
- **Seit Etappe 4g (Wunsch der Entwicklerin): Keine Kontrollbilder nötig** – sie testet selbst
  am PC. Claude prüft ohne Bilder (Godot headless laden, Probe-Szenen, street_life_check,
  plan_check) und sagt am Ende, was sie sich ansehen soll. Die Bild-Werkzeuge unten bleiben
  für Fälle, in denen sie ausdrücklich Bilder möchte oder etwas nur so zu klären ist.
- **Screenshots und Selbstkontrolle (Regel seit Etappe 4f, siehe oben):** Bei jeder sichtbaren
  Änderung startet Claude Godot ohne Bildschirm, macht Testbilder aus festen Blickwinkeln,
  schaut sie selbst an und bessert nach, bis es stimmt – erst dann meldet Claude „fertig“.
  Die wichtigsten Bilder schickt Claude am Ende mit (bzw. nennt die Pfade).
  Für Blender-Modelle zusätzlich: `blender -b --factory-startup --python
  tools/blender/build_houses.py -- <typ> --render` macht Kontrollbilder nach
  `screenshots/blender/` (Cycles). Fehlt im Container Xvfb/Vulkan, ersetzen diese Bilder
  vorläufig die Godot-Testbilder; dann ausdrücklich sagen, dass der Blick in Godot noch fehlt.
  So geht's in Godot:
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
  Nahaufnahmen von Pflanzen und Deko: Gruppe `details` (seit Etappe 4g, Teil 4f).
  Straßenleben (seit Etappe 5a): `--simulate=<sek>` spult vor, `--seed=<zahl>` macht es
  wiederholbar, `--deliver=<n>` bestellt eine Testlieferung (Lieferwagen), `--focus=<meter>`
  (+ `--focus_vehicle`) zeigt die nächste Figur bzw. das nächste Fahrzeug aus der Nähe, `--stats`
  gibt Zeichenaufrufe aus, `--quality=0|1|2` wählt die Grafikstufe, `--no_street_life` zum
  Vergleich; Gruppe `street_life`. Prüfwerkzeug ohne Bilder:
  `godot --headless --path . res://scenes/tools/street_life_check.tscn -- --seconds=60 --seed=1`
  (Erscheinen/Verschwinden im Blickfeld muss 0 sein, keine Überschneidungen, niemand in Häusern
  oder festgefahren, "stall" = beim Gehen 2,5 s auf der Stelle soll 0 sein; Autos, die vor der
  Spielfigur auf der Fahrbahn warten, sind richtig). Engstellen lösen Passanten, indem sie kurz
  an den Fahrbahnrand treten (`Passerby.STEP_OFF`), Entgegenkommende gehen links vorbei
  (Gegenüber-Stillstand: einer geht ganz an seinen linken Rand, `YIELD_TIME`); überquert wird
  nur, wo zwischen Gehweg und Bordstein nichts steht (`StreetLife.CROSSING_ROOM`). Sicherheitsnetz:
  Wer an einer Laterne/einem Kübel klemmt, darf kurz hindurch (`Passerby.ghost_static`).
  Passanten aus dem Vorrat vergessen in `begin()` ihren alten Weg (sonst falsche Lage).
  Der Spielstand im Container (`~/.local/share/godot/app_userdata/Cozy Bücherei/`) sammelt bei
  Testläufen Kartons – vor Tests löschen.
  Bei Grenzen und Wegen zusätzlich prüfen: Lauftest mit Physik (Spielfigur per
  `move_and_slide` auf die Grenze zulaufen lassen; vorübergehende Test-Szene, danach löschen)
  und bei Kulissen die Draufsicht mit `python3 tools/plan_check.py` (liest
  `scenes/world/houses.tscn`): `plan` zeichnet alle Hausumrisse nach `screenshots/plan.png`,
  `bound` prüft mit Sichtstrahlen von der Grenze am geraden Ende (nie ins Leere, nie bis ans
  Ende der Seitenstraße), `gate` misst, wie viel vom Torhaus man von der Ladentür sieht,
  `unseen` sucht alle zu Fuß erreichbaren Stellen und meldet Blicke ins Leere und Häuser, die
  man nie sieht (feste Maße/Hindernisse oben im Script, nach Änderungen anpassen).

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
  street_life/     Leben auf der Straße (Passant, Fahrrad, Auto, Lieferwagen – je Szene mit
                   Body + austauschbarem Model)
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
  street_life/     Straßenleben (StreetLife, StreetPaths, StreetRoute, Passerby, StreetVehicle,
                   DeliveryVan, StreetObstacle, StreetShapes, Platzhalter-Modelle)
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
  models/          Eigene 3D-Modelle (.glb), templates/ = Vorlagen in echter Größe zum Modellieren,
                   houses/ = Stil-Modelle der Häuser (aus tools/blender), source/ = .blend-Quellen
                   (.gdignore)
  textures/        Texturen, style/ = gemeinsame Stil-Texturen (Texture2DArray, layers.json)
  materials/       Gemeinsame Materialien (.tres), surfaces/ = Wand- und Bodenmaterialien
  shaders/         Shader (Platzhalter-Muster, Raster, Buchrücken, Buch-Vorschau)
  audio/music/     Musik
  audio/sfx/       Geräusche
  ui/              Oberflächen-Theme, icons/ = Symbole (Farbroller, Teppich)
docs/              Dokumentation
tools/             Shell-Skripte (setup_godot.sh, screenshots.sh, plan_check.py),
  blender/         Blender-Scripts der Stil-Modelle (style_lib.py = Bauteile + .glb-Export,
                   build_houses.py = Häuser; Bilderbuch-Stil: storybook_lib.py,
                   storybook_parts.py, storybook_common.py, storybook_plants.py,
                   build_storybook_shop.py = Modegeschäft, build_storybook_pub.py = Pub,
                   storybook_town.py = Bausteine der übrigen Läden, build_storybook_bakery/
                   flowers/tea/wool/gatehouse.py, build_storybook_lamps.py = Laternen,
                   export_storybook.py, storybook_gap_check.py = Lochprüfung,
                   storybook_overlap_check.py = Töpfe/Deko in Wänden; Stil-Umbau der Welt:
                   build_storybook_street.py + storybook_houses.py = Wohnhäuser,
                   build_storybook_library.py, build_storybook_alleys.py, build_storybook_props.py,
                   build_storybook_plants.py + storybook_greenery.py = Pflanzen)
screenshots/       Testbilder von tools/screenshots.sh (nicht in Git)
```
(Werkzeug-Szenen: `scenes/tools/` + `scripts/tools/`, z. B. ScreenshotTour, ScreenshotViews.)

## Technische Konventionen
- Physik-Ebenen: 1 = `world`, 2 = `interactable`, 3 = `player`, 4 = `furniture`,
  5 = `build_blocker` (Sperrzonen für den Gestaltungsmodus, z. B. vor der Eingangstür),
  6 = `placement_surface` (Ablageflächen), 7 = `street_life` (Passanten und Fahrzeuge; die
  Spielfigur stößt daran, Maske 73), 8 = `sight_blocker` (verdeckt nur die Sicht: Häuser ohne
  feste Kollision, über dem Torbogen – für die Sichtprüfung des Straßenlebens).
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
  `straight_side_street_length` weiter (ohne Querhäuser) – so gewählt, dass man von der Grenze
  aus nie das Ende sieht. Anderes Ende: `gate_bend_offset` hinter den festen Nachbarn eine sanfte Kurve
  (`gate_bend_angle`, `gate_bend_radius`) weg von der Bücherei, `gate_approach_length` danach
  (direkt hinter dem Eckhaus) das **Torhaus** (`GatehouseFacade`, Haustyp
  `GameConfig.gatehouse_type`, Kollision nur die Pfeiler, `StreetLayout.gatehouse_front()`,
  mittig zwischen den Hausfronten: `gate_center_offset()` – Durchfahrt, Grenze und Gehwege
  darunter sind entsprechend versetzt);
  von der Ladentür zu etwa 95 % sichtbar. Hinter dem Bogen Abschnitte `behind` (bis Ende der
  Kurve, Häuser auf beiden Seiten) und `behind_end` (nur außen Häuser).
  **Nur Sichtbares bauen:** Häuser, die man von keiner erreichbaren Stelle sieht, plant
  `HousesLayout` gar nicht erst (keine Querhäuser an den Enden, innen in der Seitenstraße
  keine; Reihen unter `HousesLayout.MIN_ROW_LENGTH` bleiben leer); nach Änderungen an den Enden mit `tools/plan_check.py unseen` prüfen (0 Blicke ins
  Leere, keine unsichtbaren Häuser). Kleine Gasse gegenüber: `OppositeAlley`
  (`scenes/world/opposite_alley.tscn`, `StreetLayout.opposite_alley()`, Werte
  `opposite_alley_x/_width/_depth`; die Reihe gegenüber wird dort geteilt, Abschluss
  `AlleyEnd` mit eigener `width`). Innen in beiden Kurven ein **Eckhaus mit abgeschrägter Ecke**
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
- **Stil-Modelle (seit Etappe 4g, Stil: docs/STYLE_GUIDE.md):** Häuser (später Möbel, Laden)
  werden per Python-Script in Blender gebaut (`tools/blender/`), in Godot-Koordinaten
  (x rechts, y oben, z nach vorn). Jede Fläche = Ebene der Stil-Texturen + Rolle (fixed/wall/
  door/accent) + feste Farbe; `style_lib.write_glb` schreibt die .glb (UV = Meter/Kachelgröße,
  UV2 = (Ebene, Rolle), COLOR = feste Farbe linear, Alpha = 1 − Leuchten) mit den Materialien
  „house“ (→ `assets/materials/house_style.tres`, Shader `house_style.gdshader`, ein
  Zeichenaufruf je Haus) und „glass“ (→ `house_glass.tres`, Schaufenster); die
  `.glb.import` dazu legt das Script an. Knoten „…-colonly“ = feste Kollision (z. B. Kübel).
  Texturen: `scripts/tools/generate_style_textures.gd` (headless, `-s`), Ebenen nur hinten
  anhängen. HouseFacade gibt Hausfarben und Schatten auch an „Model“ weiter. Die Maße liest
  das Bau-Script aus der Haustyp-Szene (Grundriss und Traufe bleiben), Dachneigung der
  Stil-Modelle 35°. Jedes Modell bekommt eine .blend-Quelle in `assets/models/source/`.
  **Geschlossen bauen:** Godot zeichnet nur Vorderseiten. Dünne Teile als `slab`/`beam`/`box`
  (nie Einzelflächen, außer `poly(..., both=True)` für Tuch/Blätter), nie zwei Flächen genau
  aufeinander; hinter Glas immer etwas (Laden: ganzer Raum, `Builder.room`). Nach jeder
  Änderung `build_houses.py -- <typ> --check`: Prüfbilder mit pinken Rückseiten, keine pinke
  Stelle darf bleiben. Bauteile: `style_parts.py` (Pflanzen, Blumenkasten, Hängekorb,
  Ausleger-Schild, Kreidetafel, Faden-Kringel), verspielte Schrift `Builder.playful_text`.
  Straßen-Requisiten (Laternen, Abflussdeckel): `tools/blender/build_props.py` →
  `assets/models/props/`. Innenräume leuchten über Material-Glow, keine Lampen-Lichter.
  **Wandmaterial je Haus:** Wandflächen (Rolle wall) werden als Backstein gebaut;
  `HouseFacade.wall_material` (AUTO/AS_BUILT/BRICK/STONE/RENDER/ROUGHCAST) setzt per Instanz-Wert
  `wall_layer` eine andere Ebene (Shader rechnet die Texturkoordinaten über `tile_layers` um).
  Ändern sich Ebenen in layers.json, die Listen in `house_style.tres` (roughness/metallic/
  tile_layers) mit anpassen. Seitenfenster bei Modellen: Variante `<typ>_side_left/right/both.glb`
  (HouseFacade tauscht sie zur Laufzeit ein). **Seit Teil 2b jedes Wohnhaus einzeln:**
  `tools/blender/build_street.py` liest houses.tscn, baut je Reihenhaus/Wohnhaus ein Modell aus
  einer Beschreibung (`street_houses.build_house(spec)`; feste Wünsche in `SPECIAL`, sonst
  Zufall mit Samen aus dem Hausnamen) und trägt `unique_model`, Farben und
  `wall_material = AS_BUILT` in houses.tscn ein (HouseFacade versteckt dann das Typ-Modell,
  Knoten "UniqueModel"). Fensterrahmen + Tür = Rolle door, Läden/Blumenkästen = accent;
  kein reines Weiß (Creme). Hinter jedem Glas immer etwas (`street_houses.backdrop`); Räume
  (Wohnzimmer/Küche) nur vereinzelt. Stufen vor Türen mit `Builder.ramp` (Kollision zum
  Darüberlaufen), feste Teile vor dem Haus als `colliders`. Selbsttest vor dem Hochladen:
  `blender -b --factory-startup --python tools/blender/build_street.py -- --check <Gruppe/Name> …`
  → `screenshots/blender/street_check/` (je Haus vorn, schräg links/rechts, nah; Rückseiten
  pink, nur direkt gesehene), danach `build_street.py` ohne --check (schreibt houses.tscn),
  Godot-Import, Ladeprüfung, street_life_check. .glb ohne "Cozy Bücherei"-Erzeuger = von der
  Entwicklerin bearbeitet → build_street.py lässt sie stehen (nie löschen/überschreiben).
  Fensterläden: beide oder keiner, 6–15° offen oder zu (`closed_share`, `closed_ground`).
  Gassen: `tools/blender/build_alleys.py` (Lage aus `scenes/tools/export_layout.tscn` →
  `assets/models/source/layout.json`), Kollisionen in Alley/OppositeAlley. Bücherei-Fassade:
  `tools/blender/build_library.py` (Raumkoordinaten, Knoten "Facade" im Raum). Häuser mit
  Schaufenstern an zwei Seiten: `HouseFacade.see_through` (sonst erscheinen Passanten
  sichtbar hinter dem Haus). Unsichtbare Grenzen (Körper "Bounds") immer mit Metadaten
  `see_through`, sonst gelten Orte dahinter als verdeckt. Hängende Straßenlaternen:
  `HouseFacade.lanterns` (Plätze sucht `street_houses.find_lantern_spot`, Häuser in
  `build_street.LANTERNS`), Modell `wall_street_lantern.glb`; Laternenmasten nur auf der
  Bücherei-Seite (`Street.lamp_positions`). Passanten erscheinen nur außerhalb der Reichweite
  der Spielfigur (Straßenenden hinter den Grenzen, Tür hinter den Bögen der Gasse gegenüber);
  Sitzplätze für Passanten: SeatPoint in Gruppe `StreetLife.SEAT_GROUP` mit Metadaten
  "approach"/"face" (Bank im Garten, `Alley`), Schritt "sit" im Passerby. Boden-/Wand-Shader `ground_style.gdshader`: `stone_tint` färbt nur
  einfärbbare Stellen (Ziegel), `tint` die ganze Fläche.
  **Schilder = Bilder der Entwicklerin:** Schild-Flächen mit `Mat(..., sign="name")` und
  `poly(..., uvs=…)` (0..1) → glb-Material `sign_<name>` → `assets/materials/signs/<typ>_<name>.tres`
  → Bild `assets/textures/signs/<typ>_<name>.png`. Startbild aus der Gestaltung in
  `SIGNS` (build_houses.py), nur wenn das Bild fehlt – vorhandene Bilder NIE überschreiben
  (`--reset-signs` nur auf ausdrücklichen Wunsch).
- **Bilderbuch-Stil (seit Etappe 4h, Regeln: docs/STYLE_GUIDE.md „Bilderbuch-Stil“):** Häuser
  werden Haus für Haus neu gebaut – warm, handwerklich, bewusst unperfekt, aber solide (nie Knete).
  Lage, Maße (Breite/Tiefe/Traufe des Haustyps), Wege und Kollision bleiben. Erstes Haus:
  Modegeschäft, eigenes Script `tools/blender/build_storybook_shop.py` mit Bausteinen
  `storybook_lib.py` (`Body`: box/span/slab/tube/lathe/sheet/blob/leaf/text – jedes Teil ein
  **geschlossener Körper**, Farbton je Teil im Farbattribut "tint", weiche Kanten als Bevel-
  Modifikator; Öffnungen per `boolean_cut` mit `cutter(matrix=…)` in derselben Ebene wie das
  Fenster; `settle()` verzieht alles gemeinsam: Wellen, Neigung, Dachdurchhang, Werte je Haus in
  `SETTLE`). Am Ende meldet das Script „Offene Kanten: keine“ – sonst nachbessern.
  **Lochprüfung vor jedem Hochladen:** `blender -b <haus>.blend --python
  tools/blender/storybook_gap_check.py -- --size=<Breite>,<Tiefe>,<Traufe> [--side=-1|1]`
  (Einrichtung aus, Glas undurchsichtig, pinker Prüfkörper im Haus, viele Blicke von der Straße,
  nach oben zu Tür und Schild) muss „keine Löcher gefunden“ melden. Leicht schiefe Teile, die
  aneinanderstoßen, immer überlappen lassen (Scheiben in Rahmen und Riegel, Türpfosten über den
  Schaufensterrahmen, Füllungen bis in die Riegel, Schild auf geschlossenem Schildkasten).
  Eckhäuser/Torhaus: `--probe=x0,y0,x1,y1` bzw. `x0,y0,z0,x1,y1,z1` (Prüfkörper ganz innen) und
  `--ring=cx,cy,r` (Blicke rundherum). **Überschneidungen:** `blender -b <haus>.blend --python
  tools/blender/storybook_overlap_check.py` muss „keine Überschneidungen“ melden (alles, was auf dem
  Boden steht, gegen Mauern/Fenster/Ladenfront und untereinander). Töpfe vor Ladenfronten mit
  `storybook_town.pot_out(r)` (Brüstung und Sockel ragen bis 24 cm vor), Kästen mit
  `gap=FRONT_CLEAR`; an Hausenden auf Teile des Nachbarhauses achten (Torhaus-Töpfe neben dem
  Wolleladen). **Stil-Umbau der Welt (Etappe 4h, Checkliste in docs/ROADMAP.md „Stil-Umbau der
  Welt“):** Wohnhäuser `build_storybook_street.py` (Beschreibung aus build_street.make_spec, Stil je
  Haus `storybook_houses.house_style`, je Haus .glb in assets/models/houses/storybook/ und .blend in
  assets/models/source/houses/storybook/; Sammel-Materialien `export_objects(palette=True)`: Farbe in
  den Ecken, 8–10 Zeichenaufrufe je Haus). **Pflanzen** nie im Haus-Modell: Häuser/Töpfe/Kästen legen
  Pflanzplätze an (`storybook_common.plant_spot` → leere Objekte „PlantSpot_<art>_<n>“ mit extras
  kind/width/depth/height/hint; `pot()`, `zinc_tub()`, `planter_box()` tun das selbst). `Outside/Greenery`
  (scripts/world/greenery.gd) setzt beim Start Szenen aus scenes/world/plants/ (Wurzel `PlantPiece`)
  darauf, als MultiMesh je Gebiet. Pflanzen-Stil (Wunsch der Entwicklerin): pralle, runde Blätter
  (`Body.leaf`, unter 17 cm ohne inneren Ring = weniger Dreiecke), Blüten mit runden Blütenblättern
  (`Body.star`), weich schattiert (`build(smooth_angle=180)`), Kerne klein/dunkel und von Blättern
  verdeckt (`leaf_ball` rechnet die Blattzahl aus der Fläche), Lavendel als Busch mit Ähren
  (`lavender_bush`, `spike`), Baumkronen aus Blattbüscheln ohne Kern (`crown`/`spray`, wenige Hauptäste).
  **Efeu/Kletterpflanzen wachsen mit ihrer Wand** (Ausnahme von „nie im Haus-Modell“): `wall_ivy` kennt
  Fenster, Kästen, Läden, Tür, Laterne, Kübel (holes) und wächst wild – verschieden hoch, im Bogen um
  Fenster, unter Kästen hindurch, auf breiten Wandbändern seitlich (nie als Säule durch schmale Streifen),
  an freien Ecken herum (wrap); gebaut von `House.ivy` (nicht jedes Haus; Häuser mit Vorgarten und
  Eckbeet immer), `alley_ivy` (Gassen; Gasse gegenüber: Mauern beginnen 3 cm hinter den Häusern, ihr Dach erst hinter
  deren Dachüberstand (`back_wall(roof_trim=, notch=)`), Sockelsteine `plinth_run` bis vorn an die
  Straße; Bögen aus durchgehenden Keilsteinen), Torhaus (Glyzinie), Pub (`pub_ivy`: dicht um die Gassenecke, über
  Gesims und Schild), Blumenladen (`garland` = Rosengirlande um die Ladenfront, vor der Vorderkante des
  Schildkastens; Ranken hängen nur an den Schildenden). Eckbeet: `CORNERS` in build_storybook_street.py
  (Haus → Seite, wie weit das Nachbarhaus vorsteht) → `House.corner_bed` (Randsteine, Strauch, Beet
  "garden", Efeu an beiden Wänden der Innenecke). Fensterläden: wo der Platz nicht reicht
  (Nachbarfenster, Eckpfosten der Fachwerkhäuser mit Vorkragung), klappen sie weiter auf (bis 75°). Gefäße:
  `Plant(container=CONTAINERS[art])` – Ranken über den Rand nur mit `drape`/`trail`, `clear_rim` legt
  Teile aus der Gefäßwand über den Rand (Pflanzen dürfen sich überschneiden, Töpfe nie). Sorten und
  Farbvarianten: `PLANTS` in build_storybook_plants.py (nicht mehr gelistete baut das Script ab).
  Greenery: Nachbarn im Umkreis `variety_radius` bekommen andere Sorten (`_pick_varied`), Blumenkästen
  zwei bis drei Sorten im Wechsel (lange Kästen drei bis sechs in unregelmäßigen Gruppen), Beete dicht
  (Vorgärten/Eckbeet mit Hinweis "garden": Stockrosen, Fingerhut, Rittersporn, große Hortensien, Rosen,
  Pfingstrosen, Buchs …), Topfpflanzen quellen über (`pot_overflow`), an Töpfen wachsen Gras und
  Ranken über den Rand (Art `rim`, `rim_chance`). Großer Gartenbaum `tree_garden_big` (Hinweis "garden",
  feste Lage, Krone bleibt in `GARDEN_BOUNDS` = Hof aus layout.json). Grasbüschel: Art `walltuft` (nach
  vorn gefächert, aus der Ecke Wand/Gehweg, Ursprung = Ecke vor dem Sockel, verschieden groß, ab und zu
  Wildblumen) am Fuß der Wohnhäuser (`place_spots`) und Gassenwände (`wall_tufts`), unregelmäßig;
  Art `tuft` (rund) nur selten in der Rinne und an Laternenfüßen (`Street._build_tuft_spots`, nicht am
  Halteplatz des Lieferwagens). Laternen-Ampeln = Pflanzplätze (Art `basket`). Schnittblumen (Art
  `bucket`, Ursprung = Mitte des Rands): `SC.flower_bucket` (Zinkeimer, Vase), `T.bicycle(...,
  flowers=True)`; Sträuße `cut_bunch` mit `head_*`. Blumenladen innen randvoll (Regale Topf an Topf,
  Wandregale, Eimerreihen, Hängetöpfe), außen Stufenständer (`flower_stand`, vor der 24 cm vorstehenden
  Brüstung), Ampeln unter dem Schild. Alle gesetzten Pflanzen zusammen höchstens etwa 9 Mio. Dreiecke.
  Eingangstreppe: eigenes Material `entrance_steps.tres` (Muster 4, ohne Fugen,
  nach der Lage im Modell). `T.placed` setzt neue Objekte über `matrix_basis` (sonst landen
  leere Objekte im Ursprung). Boden: Shader `storybook_ground.gdshader` (Materialien cobblestone,
  sidewalk, curb_stone, alley_setts), runde Kanten `WorldMesh.add_round_edge`. Bücherei außen:
  `build_storybook_library.py`, UpperFloors `build_visuals = false`. **Relief nie über Bildschirm-Ableitungen**
  (dFdx/dFdy arbeiten in 2x2-Blöcken → Treppchen und Pixel an Fugen): `storybook.gdshaderinc` rechnet die
  Höhe (`surface_height`) an drei Stellen im Abstand eines Bildpunkts, `storybook_ground.gdshader` die
  Steigung genau aus der Steinform (`slope`); Steine sind Kissen (Rundung je Fugenrichtung malgenommen,
  Kopfstein oben flach) – sonst laufen Knickkanten von den Ecken zur Mitte. Weiche Schatten und
  Umgebungsverschattung rauschen ohne TAA pixelig: Grafikstufen Mittel/Hoch mit `taa` (graphics_presets),
  Niedrig FXAA. **Oberflächen im Spiel:** feine Muster blendet der Shader aus, sobald sie kleiner als
  ein paar Bildpunkte werden (`detail_fade`, sonst flimmert es sandig); gestrichenes Holz hat
  `grain="paint"` (matt, keine Maserung), nur echtes Holz `wood` (feine Linien), Stein ohne
  Risslinien. Markisen: Gelenkarme seitlich neben dem Stoff, Wind bläht nur nach außen.
  **Weitere Läden (seit 4h):** Bäckerei, Blumenladen, Teeladen (corner_90), Wolleladen (corner_30)
  und Torhaus haben je ein eigenes Script `build_storybook_<haus>.py` mit den Bausteinen
  `storybook_town.py`: Wände entlang beliebiger Grundrisse (`corner_outline` = genau
  `CornerHouseFacade.footprint()`, `wall_matrix`/`canon`/`placed` für Teile an schrägen Wänden,
  `outline_walls`, `band` = Gesims/Leiste ohne Fuge um Ecken), `hip_roof`/`pitched_roof` aus
  einzelnen Ziegeln, `door`, `shop_window`, `fascia` (Schildkasten + Bild), `shutters`,
  `hanging_basket` (Ampel ohne Pflanze), `bicycle` (steht auf dem Ständer, runde Körbe),
  `round_basket` (geflochten: Staken, Ruten abwechselnd davor/dahinter, gedrehter Rand), `loop_tube` (Ring ohne Fuge), `wall_lantern`,
  `cloth_awning` (Markise = EIN Stück Stoff aus Blenders Stoffsimulation + Dicke; Alpha der
  Vertex-Farbe = wie frei der Stoff im Wind schwingt, Shader `wind_strength`), `run` (Ablauf wie
  beim Pub). Spiel-Dateien `assets/models/houses/{bakery,flower_shop,tea_shop,wool_shop,gatehouse}.glb`,
  eingetragen als `unique_model` in houses.tscn; build_street.py überspringt diese Häuser (`STORYBOOK`).
  **Alles Körper, auch im Spiel (Wunsch der Entwicklerin):** jedes Blatt ein kleiner linsenförmiger
  Körper (`Body.leaf`, Formen heart/round/oval/narrow), jede Blüte ein Stern-Körper (`Body.star`),
  Stiele/Äste runde Röhren (`tube(..., smooth=, round_ends=True)`), weiche Kanten breit
  (`BEVEL_SCALE`), nie Einzelflächen. Ein Durchgang: Szene bauen → Spiel-Kopie
  `assets/models/houses/fashion_shop.glb` (Teile je Material zusammengefasst, Kollisionskästen
  „…-colonly“ aus `OBSTACLES`, LODs an) und `assets/models/source/houses/fashion_shop_storybook.blend`
  (Einzelteile, zum Weiterbauen). Vor der Tür nur eine flache Platte (2,5 cm), keine Stufen.
  Gemeinsame Teile: `storybook_parts.py` (Laternenkopf `lantern_head` – gleicher Kopf für
  Wandlaternen, hängende Laternen und Straßenlaternen; `scroll`); `storybook_common.py`
  (Materialien `materials()`, Töpfe `pot`/`zinc_tub`, Blumenkästen `planter_box`, Kreidetafel,
  Ausleger-Schild `projecting_sign`, `settle`, Export, Fingerabdruck, Kontrollbilder);
  `storybook_plants.py` (alte Geranien/Ranken, nicht mehr benutzt). **Pflanzen an Pub und
  Modegeschäft vorerst weggelassen** (Wunsch der Entwicklerin): nur Töpfe, Kübel, Kästen mit Erde.
  **Schilder = Bilder der Entwicklerin** auch im Bilderbuch-Stil: `sign_material(typ, name)` +
  `Body.panel` (Schild-Platte als Körper, Bild vorn) → im Spiel StandardMaterial auf
  `assets/textures/signs/<typ>_<name>.png` (nie überschreiben). Pub: `build_storybook_pub.py`
  → `assets/models/houses/pub.glb`, Quelle `pub_storybook.blend`; build_street.py überspringt ihn
  (`STORYBOOK`). Eine bearbeitete .blend bringt `export_storybook.py` ins Spiel (erkennt das Haus
  an der Sammlung). Laternen baut
  `tools/blender/build_storybook_lamps.py` → `assets/models/props/street_lamp.glb`,
  `wall_street_lantern.glb` (Maße wie bisher), Quelle `assets/models/source/props/storybook_lamps.blend`. Godot-Materialien schreibt das Script nach `assets/materials/storybook/`
  (Shader `storybook.gdshader` / `storybook_plant.gdshader` beidseitig, gemeinsamer Teil
  `storybook.gdshaderinc`: rechnet Grundfarbe x tint x Flecken, Holz, Ziegel, Stein, Streifen
  aus der Lage im Modell nach; `glow` = Leuchten innen, keine Lampen im Spiel). Hat die
  Entwicklerin die .blend bearbeitet (Fingerabdruck in `fashion_shop_storybook.stamp` passt
  nicht), überschreibt das Script nichts (nur mit `--force`); ihre Fassung bringt
  `tools/blender/export_storybook.py` ins Spiel. Bilder:
  `-- --render` (Cycles, ohne Rauschfilter – OIDN fehlt im Container, dafür viele Samples;
  Lampen mit `visible_camera/transmission = False`), Blickpunkte im Spiel: Gruppe `fashion`.
- **Pflanzen (seit Etappe 4g, Teil 4f):** nie mehr Kugeln als Laub. Alle Pflanzen baut
  `tools/blender/style_plants.py` (Efeu `ivy_wall`/`ivy_garland`/`trailing_ivy`, Balkonblumen
  `bedding_row`, `geranium`, `petunia_plant`, `lobelia`, Kübel `potted`/`pot_plant`, `box_ball`,
  `olive`, `hydrangea`, `lavender`, `fern`, `hosta`, `shrub`, `tree`, Sträuße `bouquet`):
  Blätter/Blüten sind Karten (`card`, `blossom`) mit Pflanzen-Texturen
  (`assets/textures/plants/`, `scripts/tools/generate_plant_textures.gd`, Alpha = Form) im
  Material „plant“ (`plant_style.tres`, beidseitig, ein Zeichenaufruf je Haus; Mat mit
  Pflanzen-Ebene → `Mat.plant`). Jedes Blatt hängt an Stiel und Trieb. Hindernisse über
  `Space` (wall, floor, block, plane, inside) bzw. `PotSpace`/`BoxSpace`/`BasketSpace`;
  Gefäße immer offen mit Rand und Erde (`vessel`, `trough`) – sie melden sich an, und der
  Schlussschritt `settle` (S.FINISHERS, `Builder.finish()`) schiebt am Ende alle Blätter aus
  allen Gefäßwänden. Viele Stück: `with PL.detail(0.6):`. Efeu an Fassaden mit `holes`
  (Fenster/Türen/Fallrohr) und `bumps` (Gesimse, Sockel). Prüfen:
  `blender -b --factory-startup --python tools/blender/geo_check.py` (alle .glb: schwebende
  Teile, Blätter in festen Teilen; `-- --source [Namen]` baut aus den Scripts und nennt die
  Programmzeile) – muss vor dem Hochladen „in Ordnung“ melden; Pflanzen ansehen:
  `tools/blender/plant_showcase.py`. Schmiedeeisen-Schnecken mit `attach` (P.weld),
  Türknäufe `P.door_knob`, Ketten `P.chain`.
  Seit Teil 4f2: Töpfe in Gruppen `PL.pot_cluster` (Größen `POT_SIZES`, `blocks` = Fensterbänke/
  Rohre an der Wand), Hängekörbe in drei Arten (`P.BASKET_VARIANTS`, Korb meldet sich als
  "bowl" an), Efeu über die ganze Wand mit `ivy_cover` (build_street `SPECIAL`). Nach `settle`
  trennt `separate` fast deckungsgleiche Blätter (Flimmern) durch Kippen um den Stielansatz;
  Ansatz (`roots`) und Hindernisse (`spaces`) merkt `_tag` in Modell-Koordinaten (`b.xf`),
  gekippte Blätter werden erneut durch ihr `Space` geschoben; hebt `settle` einen Ansatz an,
  setzt es ein kurzes Stielstück dazu. Jedes Blatt hält einen eigenen kleinen Zusatzabstand zu
  Wänden/Ebenen/Erde (`_EXTRA`, `LEAF_GAP_STEP`), damit angedrückte Blätter nicht aufeinander
  liegen. Töpfe sind unten schmaler (`_cyl_outer`), Innenwände Vielecke (sdi mit 0,945);
  Blattkanten, die als Sehne durch einen Nachbartopf laufen, hebt `_chord_lift`. Sperren:
  `block` schiebt nur nach oben/vorn/seitlich – für Glas davor oder ein Brett darüber
  `planes` (Punkt, Richtung ins Freie, Abstand) nehmen. geo_check meldet auch Flimmern (zwei
  Flächen genau aufeinander: die kleinere 2–3 mm zurücksetzen, Deckel/Böden in anderen Teilen
  mit `skip`, Rückseiten in der Wand weglassen) und Gefäße, die in festen Teilen stecken.
- **Figuren (seit Etappe 5b):** `tools/blender/build_characters.py` (Figuren `CHARACTERS`,
  Kleidungsstücke `make_part`, Frisuren `make_hair`) mit `character_lib.py`. Grundkörper:
  Quaternius (CC0) in `assets/models/characters/base_quaternius/` (.gdignore, nie verändern);
  Blenders glTF-Import braucht den numpy-Kniff am Anfang von character_lib (np.bool …).
  Nähte verschweißen (`weld`), Kleidung = `shell` (Körperkopie, Normale nach außen, glätten,
  `cuts` = gerade Säume per bisect, `neck_cuts` mit Bereich), Röcke `bell`, Schuhe `shoe`,
  Haare `long_hair`/`bun_hair`/`cropped_hair` (Strähnen über `HeadShape.surface_dir`, Gesicht
  bleibt frei), Schichten `_layer_clothes` + `push_out_of`. Farbtöne in Texturen einrechnen
  (`tinted_image`) – der glTF-Export übernimmt keine Farb-Knoten. Export: Figuren mit fest
  angewandten Formreglern (`<name>.glb`, JPEG-Texturen), Baukasten `kit_<körper>.glb` (Körper in
  Teilen `SEGMENTS`, Formregler bleiben, Teile mit Extra "covers"), Mixamo `mixamo/<name>.fbx`
  (nur Netze, .gdignore). Ansicht: `scenes/tools/character_lineup.tscn`.
- **Chibi-Figuren (seit Etappe 5c, Körper neu gebaut; ersetzen später die Figuren aus 5b):**
  `tools/blender/build_chibi.py` baut 6 Grundkörper in drei Stufen: **Form** = Abstandsfeld
  `chibi_sdf.Body` (Grundformen; Teile in einer Linie – Ober-/Unterarm, Schenkel, Fingerglieder –
  hart vereinigt, sonst Beulen; Kopf für alle gleich, `HEAD_HEIGHT`; Maße `DIMS`, Formen
  `SHAPE_FACTORS`, `Body.parts` = einzelne Teile). **Netz** = Käfig `chibi_cage.build` (nur
  Vierecke: Rumpf 8 Ringe × 20 Ecken mit 5x5-Deckeln, Arm-/Bein-/Halsöffnungen; Arme/Beine/Hals
  10er-Ringe mit je einem Ring auf dem Gelenk; Hand 10er-Ringe 4-1-4-1, Finger/Daumen 4er-Ringe,
  Kanten zwischen Nachbarfingern vorn an der Schwimmhaut `WEB_X`/`WEB_Z`, Daumen direkt auf der
  Handseite `THUMB_BASE`; Handfläche = weiches Kissen + gewölbter Handrücken; Kopf Würfelkugel 5x5, Ohren aus
  2x2 Feldern mit Ringen aus 8 Ecken auf Ellipsen `EAR_RINGS` (4er-Ringe gaben Ecken), Nase/Nabel eingesetzte Felder), zweimal
  Catmull-Clark (`SUBDIVISIONS`), dann `fit_to_shape` (entlang der Normalen auf die Form,
  `project_along` mit Schritt- und Weitenbegrenzung, dann gleichmäßig verteilt). Normalen aus dem Netz
  (keine eigenen – die alten wichen bis 16° ab: fleckiges Licht). Käfig-Ecken tragen Bereiche
  (`region_…`, beim Glätten weich verteilt). **Skelett + Gewichte** = `chibi_rig` (Namen =
  SkeletonProfileHumanoid; Schulterlinie flach `DIMS["shoulder"]`, Schlüsselbein fast waagerecht;
  breite Übergänge `*_BLEND`, Oberarm zieht am Ansatz nur Haut nah an der Armachse `ARM_RADIAL`,
  danach `SMOOTH_ITERATIONS` Glätten). Formregler `thin`/`fat` = dasselbe Netz der anderen Form
  **ohne** die Arm-/Bein-Verschiebung (`limb_offsets`): die macht in Godot `ChibiShapeModifier`
  (SkeletonModifier3D, Werte als glTF-Extras `chibi_bone_offsets` am Skelett) – sonst knickt der
  Ellbogen neben dem Gelenk. T-Pose: Arme waagerecht, Handflächen unten, Daumen vorn; in Godot
  hängen die Arme ohne Animation um `relaxed_arms` 57° (Schlüsselbein `SHOULDER_SHARE` 6°, Ellbogen
  `ELBOW_RELAX`). Prüfen: `--views=poses` (Bewegungsprobe mit hartem Licht: Arme runter/vor/hoch,
  Ellbogen, Faust, Sitzen, Gehen), `wire` (Netz), `hands`, `collide` (hängende Arme ≥ 0 mm vom
  Rumpf), `joints` (alle Gelenke innen), `underwear`, außerdem compare, around, lineups, heads,
  armpits, tpose, eyes. Konsole: "Netz: 0 offene/mehrfache Kanten" muss bleiben.
  **Mixamo-FBX** (`export_mixamo`): `mixamo/<name>.fbx` **mit unserem Skelett** (Knochen mit
  Mixamo-Namen `mixamorig:…`, `mixamo_name`, Endknochen HeadTop_End/…4/Toe_End ohne Gewicht) –
  Mixamo übernimmt es, kein Punkte-Setzen; `<name>_mesh_only.fbx` = nur das Netz (Ersatz, Mixamo setzt
  sein Skelett ein). Beide in Zentimetern (Zahlen ×100, Szene `scale_length` 0.01) und ohne
  Lcl-Drehung/-Skalierung (sonst hält Mixamo die Figur für 1,5 cm groß): Netz per
  `bake_space_transform`, mit Skelett Zahlen schon "y oben" (Knochen per `EditBone.transform`).
  Mixamo liest kein .glb. Fleckige, flackernde Stellen nur auf der beleuchteten Seite in Mixamos Vorschau
  sind Schatten-Akne der Vorschau (Netz geprüft: geschlossen, Flächen außen, Normalen passend) – in Godot
  nicht vorhanden (Gehprobe mit Sonnenschatten).
  **UV2:** x = Verschattung (AO; Vertex-Farben kommen beim Export durcheinander), y = Abstand
  zum Rand der **aufgemalten Unterwäsche** (`Body.underwear_distance`, negativ = Stoff; in Godot
  `1 - UV2.y`; Bandeau-Kante nach der Richtung um den Körper, nicht nach der Tiefe) – keine
  Stoff-Netze, damit später nichts unter enger Kleidung hervorschaut.
  Gesicht: Material „face“ mit Zylinder-UV; `chibi_face.py` zeichnet die Atlanten (Augen:
  12 Bilder × 6 Sätze = je Geschlecht 3 Augenformen `EYE_SHAPES`; Männer ohne Wimpern/Lidspitze,
  dezenter Glanz; 26 Ausdrücke `EXPRESSIONS` = `ChibiCharacter.MOODS`; Maße müssen zu
  `assets/shaders/chibi_face.gdshader` passen, auch `SET_IRIS`), Shader wählt die Mipmap-Stufe
  selbst (sonst Rauschen). Godot: `ChibiCharacter` (`scenes/characters/chibi_character.tscn`;
  Instanz-Werte für Farben und Gesicht, Enum `Mood` – „Expression“ ist in Godot schon belegt).
  Ansicht `scenes/tools/chibi_lineup.tscn`; Prüfbilder nach `screenshots/blender/chibi/`.
  **Animationen (5c):** Mixamo-FBX in `assets/models/characters/animations/` (Liste
  `chibi_anim.CLIPS`: walk, idle, idle_2 = Schaufenster, sit_down, sit_idle, stand_up) überträgt
  build_chibi auf alle Figuren (je Knochen die Drehung gegenüber der T-Pose in Weltachsen, Hüfte ×
  Verhältnis der Hüfthöhen, Sitz-Clips ohne seitliches Wandern) → NLA-Spuren → Animationen in der
  .glb; Zusatzangaben als Extras `chibi_anim` am Skelett (walk_speed, sit_seat, sit_down/stand_up
  _time/_shift). Godot: `ChibiPasserbyModel` spielt sie (Passerby `model_animates`), Umschauen =
  Kopf drehen nach der Animation (`ChibiHeadModifier`), Sitzen hebt das Modell um
  sit_height − sit_seat. Rock: Gewichte mindestens wie die Haut darunter (`_skin_weights_below`),
  darunter Hosenrock im Haut-Shader (`lower_cloth_color`, Grenze über UV = Höhe in der Ruhelage).
  Godot zeichnet nur Vorderseiten: Umlaufsinn neuer Kleidung prüfen (Cycles zeigt beide Seiten).
  **Kleidung/Frisuren** (`chibi_outfit.py`, `build_chibi.build_outfit`): jede Figur enthält alle Stücke
  als eigene Netze „Cloth_<name>“/„Hair_<name>“ (Material cloth_…/hair_…); `ChibiCharacter` blendet ein
  (top/bottom/shoes/hair + Farben als Instanz-Werte, Shader `chibi_cloth`/`chibi_hair`). Kleidung =
  `shell`: Körperflächen nach Schnitten (`garment_specs`: Funktionen f(p) ≥ 0), Randecken auf die
  Schnittlinie geschoben (auch über Diagonalen) und entlang des Saums geglättet, Außenseite entlang
  der Normalen (`offset`), geglättet und mit `keep_clear` nie näher als 85 % des Abstands an den Körper
  (je Formregler mit der Verschiebung von Armen/Beinen), Innenseite nur als Streifen am Saum
  (`INNER_BAND`), gleiche Gewichte/Formregler wie der Körper. Schichten: Oberteile ≥ 7,5 mm, Hose
  und Rockbund darunter (≤ 6 mm). Rock = Glocke (`skirt`, außen um Rumpf und Beine gemessen).
  Frisuren = Abstandsfeld (`hair_field`, Gesichtsfenster bis über die Brauen, Kerben im Pony),
  Surface Nets (`HAIR_GRID`), Flächen tief im Kopf entfallen, Gewicht Head = 1. Erste Texturkoordinate
  immer gefüllt (sonst vervielfacht der Export jede Ecke: 21 statt 6 MB). Passanten:
  `passerby_chibi.tscn` + `ChibiPasserbyModel` (randomize_look, animate = einfache eigene Bewegung über
  `set_bone_turns`, set_shadows; `Passerby.vary_size = false`).
- **Fahrzeuge (seit Etappe 5b):** `tools/blender/build_vehicles.py`: Karosserie `Body`
  (Querschnitte entlang z, Radkästen, weiche Normalen, Fenster/Lack je Fläche über
  `window_mats`), Teile auf der Haut über BVH (`hit`, `round_lamp`, `plate`). Lack = Rolle
  accent (Godot: Wagenfarbe), zweite Farbe = Rolle door; Räder als eigene .glb, eingesetzt und
  gedreht von `VehicleModel` (scripts/street_life/vehicle_model.gd), Lieferwagen-Tür = Knoten
  "Door". Logo des Lieferwagens = Schild-Bild `delivery_van_logo.png` (Startbild `logo_design`,
  nie überschreiben). Hollandrad: `style_parts.bicycle` (auch vor dem Blumenladen), auf der Straße
  Rahmen/Räder/Kurbel getrennt (`CyclistPlaceholder`). Stil-Ebenen 20–23: car_paint, chrome,
  rubber, leather (Shader-Listen jetzt 24 lang).
- `WorldMesh.xform`: Teile in Fassaden-Koordinaten bauen (x entlang der Wand, +z nach draußen)
  und gedreht einsetzen (schräge Fassaden, Seitenwände); danach wieder `Transform3D.IDENTITY`.
- **Vorlagen zum Modellieren:** `assets/models/templates/{houses,furniture,world}/*.glb`
  (echte Größe, Ursprung/Vorderseite wie die Szene; Ordner mit `.gdignore`), erzeugt von
  `scenes/world/tools/export_templates.tscn`. Neue Möbel/Haustypen → Vorlagen neu erzeugen.
- Fensterbänke: `ShopWindow` (Script der Fenster-Szene) formt Bank, Ablage und Kollision
  (`SillBody`: Bank, Glas, Seitenrahmen) aus `GameConfig.window_sill_depth`.
- Sonnenschatten ohne `light_angular_distance` (PCSS zeigte Treppenkanten); weich macht sie
  `shadow_blur` mit dem Filter der Grafikstufe.
- **Hellere Schatten draußen (seit Teil 4f2):** Himmelslicht `SkyFill` (DirectionalLight3D ohne
  Schatten, main.tscn) wirkt nur auf Render-Ebene `GameConfig.OUTDOOR_RENDER_LAYER` (2);
  `main.gd` setzt diese Ebene für alles unter Outside, EntranceSteps, UpperFloors und der
  Bücherei-Fassade (auch später hinzukommende Knoten). Stärke/Farbe: `outdoor_fill_energy`,
  `outdoor_fill_color`. Innen bleibt es dunkler (kein Füll-Licht im Raum).
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
- **Sichtfeld:** `Player.fitted_fov(größe)` – oben/unten `GameConfig.camera_fov`, aber links/rechts nie
  breiter als `camera_max_horizontal_fov[Einstellung „Sichtfeld“]` (sonst Fischauge auf 21:9/32:9);
  passt sich bei Fenstergröße und Einstellung an.
- **Malfilter „Aquarell“** (Gezeichnet-Look, Einstellung Grafik → „Malstil“, Testtaste F4 – nie F8, das beendet in Godot das
  laufende Spiel –, Testbilder
  `--paint=0|1`): `PaintFilterEffect` (scripts/rendering/, ein `CompositorEffect` nach allen festen und
  durchsichtigen Dingen, vor Belichtung/Leuchten; main.gd hängt ihn als `Compositor` an die
  WorldEnvironment) mit zwei Rechen-Shadern `assets/shaders/paint/paint_copy.glsl` (Arbeitskopie) und
  `paint_filter.glsl` (Farben scharf am Bildpunkt – Wunsch: nicht verschwommen; Kuwahara-Pinselflächen nur
  wahlweise, `paint_radius` > 0; dunklere Farbränder nur an deutlichen Farbgrenzen; gerade Tuschelinien
  (`paint_wobble` 0) in dunklem Braun relativ zur Fläche darunter – nie Schwarz; Farbränder und Linien
  enden bei `paint_line_fade_distance`, sonst flimmert es pixelig; Papierkörnung grob; bei aktivem Filter
  immer FXAA; Linien aus Tiefe +
  normal_roughness, Papier, warme Farbstimmung). Alle Werte in GameConfig (`paint_*`), Pinselgröße je
  Grafikstufe (`graphics_presets` "paint_radius"). Die Oberfläche (HUD, Menüs) bleibt scharf.
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
- **Leben auf der Straße (seit Etappe 5a):** `StreetLife` (Knoten `Outside/StreetLife`, Gruppe
  `street_life`) verwaltet Passanten (`Passerby`), Fahrräder und Autos (`StreetVehicle`) und den
  Lieferwagen (`DeliveryVan`); alle Werte in GameConfig (Abschnitt „Leben auf der Straße“),
  Menge über `StreetLife.activity()` (später Tageszeit). **Grundregel: niemand erscheint oder
  verschwindet sichtbar** – nur an Punkten der Gruppe `Street.TRAFFIC_GROUP` (Metadaten `kind`,
  `place` = east/west/alley/opposite_alley) und nur, wenn `StreetLife.is_visible_spot()` false
  ist (Bild mit Rand `street_view_margin` + Sichtstrahl gegen Ebenen world/sight_blocker; Körper
  mit Metadaten `see_through` wie die Fensterbank-Kollision zählen nicht). Neue Häuser/Kulissen
  brauchen darum eine Kollision oder einen Sichtblocker. Alle folgen der Mittellinie der Straße
  (`StreetPaths.centerline()`, ein `StreetRoute`: s wächst zum abbiegenden Ende, lat > 0 =
  Bücherei-Seite) mit erlaubtem Streifen je Punkt (Gehwege `sidewalk_route(seite)`, Fahrbahn,
  Überqueren); die Gehwege misst `StreetLife` beim Start an den Häusern aus. Gassen und
  Schaufenster sind kurze eigene `StreetRoute`s. Passanten: Schritte (walk, cross, stand, leave)
  plant `StreetLife._plan_walker`; Ausweichen über Bereiche auf dem Streifen (links ausweichen),
  `blocks_move` = nie näher an jemanden. Feste Hindernisse draußen: `StreetObstacle`-Kreise
  (Gruppe `street_obstacles`, z. B. von `EntranceSteps`). Fahrzeuge: Linksverkehr
  (`StreetPaths.lane_offset`), bremsen nur für Menschen, die auf der Fahrbahn sind
  (`Passerby.body_on_road`); je Richtung startet nur, wer niemanden einholt
  (`direction_free`). Alles ist beim Start gebaut (Vorrat), Platzhalter aus `StreetShapes`
  (ein Material `street_figure.tres`, Alpha der Vertex-Farbe wie bei den Häusern),
  Schatten je Grafikstufe (`street_shadow_distance`), weit weg vereinfacht
  (`street_detail_distance`). Für Besucher (nächster Schritt): Signal `passing_library`,
  Punkt `StreetPaths.library_entrance()`. Draußen wird nichts gespeichert.
- **Lieferwagen:** Fällige Bestellungen warten im `DeliveryManager` (`_due`), `StreetLife.send_van`
  holt sie ab (`_van_load`, wird als Bestellung mit Restzeit 0 gespeichert); der Wagen ruft je
  Karton `DeliveryManager.unload_one(tür)` (PLACED/BLOCKED/EMPTY; nie dorthin, wo jemand steht,
  `StreetLife.blocking_points`). Ohne Straßenleben liefert der DeliveryManager direkt. Kartons
  höchstens `DeliveryManager.MAX_ROWS` (2) Reihen tief, damit der Gehweg frei bleibt.
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

