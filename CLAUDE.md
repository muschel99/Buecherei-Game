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

## Projektstruktur
```
scenes/            Szenen (.tscn)
  main.tscn        Hauptszene: Licht, Umgebung, Raum, Spielfigur, Oberfläche
  player/          Spielfigur
  rooms/           Räume des Hauses
  furniture/       Möbel (je eine Szene, Modell austauschbar)
  objects/         Interaktive Objekte (Stehlampe, Lieferkarton; Scripts: LightSource, Seating,
                   Lichtschalter, Tür, Tablet, BookShelf, BookRow, BookLook, ReturnBox)
  effects/         Effekte (z. B. Staubpartikel)
  ui/              Oberfläche (HUD, Pausenmenü, Inventar, Shop, Hinweise, Stil-Anzeige,
                   Regal-Menü, Trage-Anzeige)
scripts/           GDScript-Dateien, gleiche Unterordner wie scenes/
  autoload/        Global verfügbare Scripts (GameConfig, Catalog, SaveManager, MenuStack, Settings,
                   Wallet, Inventory, BookStock)
  interaction/     Interaktionssystem (Interactable)
  building/        Gestaltungsmodus (BuildMode, PlacedFurniture, PlacementSurface, Vorschau)
  data/            Datenformate (FurnitureData, SurfaceData, StyleTags, GenreData, Book, BookTitles)
  rooms/           Raum-Logik (Room, PaintableWall, PaintableGrid: Möbel, Wände, Boden, Decke, Speichern)
  shop/            Lieferdienst (DeliveryManager)
data/
  furniture/       Datenblätter der Möbel (.tres) – werden automatisch in den Katalog geladen
  surfaces/        Datenblätter der Wandfarben und Böden (.tres)
  genres/          Datenblätter der Buch-Genres (.tres)
  book_titles/     Wortlisten für erfundene Buchtitel (.txt, eine je Genre)
assets/
  models/          Eigene 3D-Modelle (.glb)
  textures/        Texturen
  materials/       Gemeinsame Materialien (.tres), surfaces/ = Wand- und Bodenmaterialien
  shaders/         Shader (Platzhalter-Muster, Raster, Buchrücken)
  audio/music/     Musik
  audio/sfx/       Geräusche
  ui/              Oberflächen-Theme, icons/ = Symbole (Farbroller, Teppich)
docs/              Dokumentation
```

## Technische Konventionen
- Physik-Ebenen: 1 = `world`, 2 = `interactable`, 3 = `player`, 4 = `furniture`,
  5 = `build_blocker` (Sperrzonen für den Gestaltungsmodus, z. B. vor der Eingangstür),
  6 = `placement_surface` (Ablageflächen).
- **Jede Interaktion in der Spielwelt läuft über E.**
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
- **Oberflächen/Menüs:** Projekt nutzt Stretch-Modus `canvas_items` + `expand` (Basis 1600 x 900).
  Neue Menüs immer mit Anchors und Containern bauen, dann passen sie sich automatisch an.
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
  (Etappe 5 baut darauf auf). Anzeige als Text: `Wallet.format(betrag)`.
- **Inventar** (`Inventory`): Möbel mit Anzahl (`add_furniture`, `take_furniture`), Oberflächen
  einmal besessen (`add_surface`, `owns_surface`). Was im Raum steht, zählt der Raum
  (`Room.count_placed`). Der Gestaltungsmodus zeigt nur, was im Inventar liegt (Anzahl ≥ 1).
- `FurnitureData.is_essential` = gehört fest zur Bücherei (Tablet): nicht kaufbar, nicht
  verkaufbar; `Room.ensure_essentials()` stellt es zurück, falls es fehlt.
  `SurfaceData.owned_at_start` = von Anfang an vorhanden.
- **Shop:** `ShopWindow` (Gruppe `shop_window`, `open_shop()`); Bestellungen gehen an den
  `DeliveryManager` (Gruppe `delivery_manager`, `place_order(inhalt)`), Inhalt als Liste von
  `{ "kind": "furniture"/"surface"/"books", "id": …, "count": … }` (bei "books": id = Genre,
  count = Zahl der Bücherpakete). Reiter: Kaufen, Verkaufen, Bestand.
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
- Türen (`Door`, Gruppe `doors`): Teile, die mitschwingen, unter dem Knoten `Hinge`.
- Die Spielfigur kann man anhalten: `player.movement_enabled = false` (z. B. im Shop).
- Eingabe-Aktionen: `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `jump`,
  `crouch`, `interact`,
  `pause`, `toggle_build_mode` (Tab), `build_place`, `build_cancel` (rechte Maustaste),
  `build_rotate`/`build_rotate_back` (Mausrad), `build_toggle_grid`, `build_delete` (X),
  `build_paint_all` (Umschalt), `toggle_fps` (F3), `debug_fill_return_box` (F9, Testtaste).
- Möbel-Knoten in Szenen können ihre Nummer (`uid`) und ihr Trägermöbel (`support_uid`) fest
  eintragen (z. B. Tablet auf der Theke).
- Renderer: Forward+ (nötig für volumetrischen Nebel / Lichtstrahlen).
- **Bücher:** Neues Genre = neues Datenblatt in `data/genres/` + Wortliste
  `data/book_titles/<id>.txt` (kein Code). Bücher (`Book`) sind keine Knoten, sondern Daten;
  der Bestand (`BookStock`) kennt Lager und Getragenes (`carried`), zählt Regale
  (Gruppe `book_shelves`) und Rückgabekästen (Gruppe `return_boxes`) mit.
  Freigeschaltet: `BookStock.is_genre_unlocked(id)` / `unlock_genre(id)`.
- Bücher bewegen sich immer in Gruppen und nie mit Zeitdruck (Gemütlichkeit vor Arbeit).
- Bücherregale: Knoten `BookShelf` mit `BookRow`-Fächern (Ursprung = Mitte der Brett-Oberkante),
  optional `SignPoint` (Genre-Schild) und `Interactable`. Alle Bücher eines Regals sind ein
  MultiMesh (Aussehen aus `Book.look` über `BookLook`) – nie einzelne Knoten je Buch.
- Möbel mit Inhalt (Regal, Rückgabekasten): Knoten in der Gruppe `PlacedFurniture.CONTENTS_GROUP`
  mit `get_contents_data()`, `load_contents_data()`, `release_contents()` – der Raum speichert
  den Inhalt mit dem Möbelstück, beim Wegräumen (X) geht er ins Lager.
- Startgeschenke fürs Inventar: `GameConfig.start_furniture_gifts` (jedes nur einmal, auch in
  älteren Spielständen).
- Testtasten sind über GameConfig abschaltbar (z. B. `debug_return_box_key`).
