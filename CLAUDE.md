# CLAUDE.md – Arbeitsregeln für dieses Projekt

Dieses Projekt ist ein gemütlicher Bücherei-Simulator („Cozy Bücherei“) in Godot 4.
Die Gesamtidee steht in `docs/GAME_DESIGN.md`, der Etappenplan in `docs/ROADMAP.md`.
Einzelheiten zu jedem System stehen als Kommentar oben in den Scripts – dort zuerst nachlesen.
(Die frühere, sehr ausführliche Fassung dieser Datei liegt in der Git-Geschichte.)

## Über die Entwicklerin
- Absolute Anfängerin: hat noch nie programmiert und noch nie mit einer Spiele-Engine gearbeitet.
- Kommunikation auf Deutsch, in einfachen Worten.
- Arbeitet mit **Fedora Linux** (Anleitungen für Terminal und Dateimanager entsprechend).
- Testet auf dem eigenen PC. Blender ist auch auf ihrem PC installiert (Modelle dort anschauen).

## Umgebung (seit Etappe 4g: Dev-Container auf ihrem PC)
- Claude läuft in einem Docker-Dev-Container (`.devcontainer/`), Projektordner `/workspace`.
- Firewall: nur GitHub, npm und Anthropic sind erreichbar (nichts sonst herunterladen).
- **Godot-Version:** Die Entwicklerin spielt mit **Godot 4.6.2**, im Container ist `godot` neuer (4.7.2) und verzeiht
  manches, was 4.6 als Fehler meldet (z. B. `return [a, b] if x else [b, a]` bei typisierter Rückgabe `Array[Vector3]`
  → „Trying to return an array of type Array …“, das Spiel hält an). Vor dem Hochladen darum auch mit 4.6.2 prüfen:
  Release von GitHub (`https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip`)
  in den Scratchpad laden, das Projekt dorthin kopieren (ohne .git, „Game design“, screenshots) und dort importieren und
  street_life_check laufen lassen (`SCRIPT ERROR` muss 0 sein) – nie mit 4.6 im Projektordner selbst (Import-Cache).
- Godot ist installiert (`godot`), es gibt keinen Bildschirm: `godot --headless` zum Prüfen, Importieren und für
  Werkzeug-Scripts. Testbilder brauchen `xvfb-run` (Software-Vulkan, langsam).
- Blender 3.4 ist installiert (`blender`), nur im Hintergrund: `blender -b --factory-startup --python script.py`.
  Kontrollbilder mit Cycles (CPU). EEVEE geht nicht.
- `gh` ist angemeldet: nach jedem fertigen Schritt committen und nach origin pushen.
- `Game design/` = Bildersammlung der Entwicklerin (Stilrichtung, Inspiration), mit `.gdignore`,
  nicht in Git.
- Der Spielstand im Container (`~/.local/share/godot/app_userdata/Cozy Bücherei/savegame.json`) sammelt bei Testläufen
  Kartons und Besucher – vor Tests löschen.

## So arbeiten wir zusammen
- **Engine:** Godot 4 (Standard-Version ohne .NET). **Sprache:** GDScript. Renderer Forward+.
- In **kleinen Schritten** arbeiten. Vor größeren Aufgaben kurz den Plan zeigen.
- Nach jedem Schritt in einfachen Worten erklären, was gemacht wurde und was sie in Godot
  tun oder testen soll: welches Fenster, welcher Knopf, welche Taste.
  Fachbegriffe beim ersten Auftreten erklären.
- Sauberer, gut lesbarer Code mit **kurzen Kommentaren auf Deutsch**.
  **Variablen- und Dateinamen auf Englisch.**
- Alle einstellbaren Werte (Tageslänge, Preise, Laufgeschwindigkeit, Mausempfindlichkeit,
  Freischaltintervalle usw.) gehören zentral in `scripts/autoload/game_config.gd`
  (Autoload „GameConfig“, im Code: `GameConfig.walk_speed`). Spieler-Einstellungen gehören in
  `Settings.DEFINITIONS` (`scripts/autoload/settings.gd`), das Pausenmenü baut sich daraus selbst.
- **Grafik und Sound:** Nichts aus dem Internet herunterladen. Seit Etappe 4g baut Claude die
  Grafik selbst im einheitlichen Stil (`docs/STYLE_GUIDE.md`): Modelle per Blender-Script,
  Texturen per Godot-Script; wo noch nichts gebaut ist, bleiben die einfachen Platzhalter.
  Alles so bauen, dass eigene 3D-Modelle (.glb), Texturen und Sounds leicht austauschbar sind
  (siehe `docs/ASSET_GUIDE.md`).
- Neue Schriften nur frei (OFL) über npm `@fontsource/<name>` (latin-Teil, .woff2), Lizenz daneben in `assets/ui/fonts/`.
- **Würde es in echt funktionieren? (Regel für alle Modelle, Wunsch der Entwicklerin seit Etappe 6d):**
  Bei jedem Objekt prüfen, ob es so gebaut werden und funktionieren könnte: nichts schwebt in der
  Luft, nichts steckt ineinander (außer gewollt überlappende Fugen), alle Teile sind sinnvoll
  verbunden (Streben enden an etwas, Lampen sitzen an Halterungen), nichts ist hohl, wo es nicht hohl
  sein soll (Reifen, Karosserien, Wände haben Volumen und Innenseiten), bewegliche Teile (Türen,
  Räder, Pedale, Markisen) stoßen nirgends an und lassen den Weg frei, wo man hindurchgeht oder
  -fährt. Offen und geschlossen, von innen und außen prüfen.
- **Git:** Nach jedem funktionierenden Schritt ein Commit mit verständlicher deutscher Nachricht.
- **Roadmap in Notion (seit Etappe 6):** Jedes Mal, wenn `docs/ROADMAP.md` aktualisiert wird, wird die
  Notion-Seite „Roadmap (aus Claude Code)“ (Unterseite von „Cozy-Bücherei-Spiel (Arbeitstitel)“) auf
  denselben Stand gebracht – übersichtlich und gut lesbar (Tabellen, Überschriften, Häkchen). Sonst
  nichts im Notion der Entwicklerin ändern (Lesen ist in Ordnung). Notion ist über den claude.ai-
  Zugang verbunden (Werkzeuge `notion-…`).
- **Fehlermeldungen:** Erst kurz erklären, was die Meldung bedeutet, dann beheben.
- **Prüfen:** Die Entwicklerin testet selbst am PC und braucht keine Kontrollbilder. Claude prüft trotzdem selbst
  (Godot headless laden, Probe-Szenen, street_life_check, bei sichtbaren Änderungen eigene Testbilder ansehen und
  nachbessern) und sagt am Ende, was sie sich ansehen soll.

## Dateien der Entwicklerin – nie überschreiben
- **Schilder = Bilder der Entwicklerin:** Bild `assets/textures/signs/<typ>_<name>.png` – vorhandene Bilder NIE
  überschreiben (`--reset-signs` nur auf ausdrücklichen Wunsch). Ausnahme nur auf ausdrücklichen Wunsch: die Ladenschilder
  aus `scenes/tools/make_signs.tscn`; Bilder, die sie selbst malt, nie überschreiben. Logo des Lieferwagens =
  Schild-Bild `delivery_van_logo.png` (nie überschreiben).
- .glb ohne "Cozy Bücherei"-Erzeuger = von der
  Entwicklerin bearbeitet → build_street.py lässt sie stehen (nie löschen/überschreiben).
- Hat die
  Entwicklerin die .blend bearbeitet (Fingerabdruck in `fashion_shop_storybook.stamp` passt
  nicht), überschreibt das Script nichts (nur mit `--force`); ihre Fassung bringt
  `tools/blender/export_storybook.py` ins Spiel.
- Möbel: Handarbeit bleibt: Dateien ohne die
  Erzeuger-Zeile (Godot hat gespeichert), geänderte .blend, ersetzte .glb (nur `--force`).
- Aufbereitung der Originale der Entwicklerin
  („Game design/Sounds Cozy Bücherei“, nie verändern): `tools/prepare_sounds.py`.
- Figuren: `character_lib.py` bleibt (build_chibi nutzt ihn),
  ebenso die Quaternius-Grundkörper in `assets/models/characters/base_quaternius/` (.gdignore, nie verändern).

## Projektstruktur
```
scenes/  scripts/    gleiche Unterordner: player, rooms, furniture, objects, street_life, animals, world, ui (+ tablet_apps),
                     library (Besucher), story, talk, building (Gestaltungsmodus), tools (Prüf- und Bildwerkzeuge)
scripts/autoload/    GameConfig, Settings, Catalog, SaveManager, MenuStack, Wallet, Inventory, BookStock, BookArt,
                     CounterStyle, FacadeDesign, GameClock, Lending, Tutorial, Season, Audio, DebugKeys
data/                Datenblätter (.tres) und Texte: furniture, surfaces, styles, counters, genres, books (.txt),
                     tablet_apps, return_slots, facade, tips, story, tutorial, talk, visitors, animals/spots.json
assets/models/       .glb (houses/, facade/, props/, vehicles/, characters/, title/, templates/), source/ = .blend-Quellen
assets/materials/    gemeinsame Materialien, storybook/ (vom Blender-Export), furniture/<id>/, facade/, signs/
assets/shaders/      storybook.gdshaderinc (gemeinsamer Bilderbuch-Shader), Boden, Himmel, Figuren, Bücher, Malfilter
assets/textures/ assets/audio/ assets/ui/ (Theme, Schriften, Symbole, Mauszeiger)
tools/               Shell-/Python-Werkzeuge; tools/blender/ = alle Bau-Scripts der Modelle
docs/                GAME_DESIGN, ROADMAP, STYLE_GUIDE, ASSET_GUIDE
screenshots/         Testbilder (nicht in Git)
```

## Grundregeln im Code
- **Physik-Ebenen:** 1 world, 2 interactable, 3 player, 4 furniture, 5 build_blocker (Sperrzonen), 6 placement_surface,
  7 street_life (Passanten/Fahrzeuge), 8 sight_blocker (verdeckt nur die Sicht).
- **Bedienung:** Jede Interaktion in der Spielwelt läuft über **E**. Ausnahme Bücher (Maus): Rechtsklick nimmt, Linksklick
  legt ab, Linksklick halten räumt ein, Mausrad dreht; Q halten = getragene Bücher ins Lager. Menüs von Objekten öffnet
  **R** (`menu_text`). Hat das Angeschaute keine E-Aktion, blättert E durch die Bücher in der Hand.
  **Jede Aktion hat nur einen Weg.** Unter der Bildmitte nur kleine Tastensymbole mit höchstens einem Wort
  (`prompt_text`, `take_text`, `menu_text`), keine Sätze im Spielbild (Ausnahme: Sprechblasen im Gespräch).
  Beim Anschauen leuchtet nichts auf (`GameConfig.look_highlight`); nur der Gestaltungsmodus hebt hervor.
- **Esc-Regel:** Was sich öffnen lässt, meldet sich mit `MenuStack.open(self)` an und hat `close_from_escape()`; Esc
  schließt immer zuerst das Oberste, sonst öffnet sich das Pausenmenü.
- **Interaktive Objekte** bekommen einen `Interactable` (Area3D) und reagieren auf `interacted`; trifft der Blick den festen
  Körper, gilt dessen Interactable (`Interactable.find_for`).
- **Möbel:** Szene mit `Model` (austauschbare Optik) + `Body` (Kollision), Fußpunkt auf 0, Vorderseite +Z; Ablageflächen
  `PlacementSurface` (Ursprung = Oberkante); Wanddinge Ursprung hinten mittig, Deckendinge oben. Neues Möbel/neue
  Oberfläche/neues Genre/neue Tablet-App/neue Fassaden-Option = neues Datenblatt, kein Code. Im Raum sind Möbel
  `PlacedFurniture` mit `FurnitureData`. Sitz- und Tischhöhen für die Chibi-Figuren: Sitz 0,30 m, Tisch 0,5 m,
  Couchtisch 0,3 m, Theke 0,85 m.
- **Geld** nur über `Wallet.spend/earn`. **Speichern:** Knoten in Gruppe `persist` mit `save_key`, `get_save_data()`,
  `load_save_data()`. Draußen wird nichts gespeichert – außer dem Draußen-Raum vor der Bücherei (`OutdoorArea`,
  `Room.outdoor`): Dort stellt man im Gestaltungsmodus nur Dinge der Kategorie `OUTDOOR` auf (Bau-Script
  `furniture_outdoor.py`, ids `out_…`); sie bekommen automatisch Ausweich-Kreise für Passanten.
- **Tablets/Apps:** gemeinsame Vorlage `TabletFrame`; neue App = Szene in `scenes/ui/tablet_apps/` (erbt `TabletApp`) +
  Datenblatt `data/tablet_apps/<id>.tres`; Apps nie mit festen Farben, sondern `style.…` und den Bausteinen von `TabletApp`.
- **Menüs/Oberflächen** immer mit Anchors und Containern (Stretch `canvas_items` + `expand`, Basis 1600 x 900); was wachsen
  kann, in einen ScrollContainer.
- **Signale von Autoloads und SceneTree nie mit Lambdas verbinden** (bleiben nach dem Neuladen der Szene verbunden) – Methoden.
- **Leben auf der Straße:** Niemand erscheint oder verschwindet sichtbar (`StreetLife.is_visible_spot`). Neue Häuser/Kulissen
  brauchen darum Kollision oder Sichtblocker; unsichtbare Grenzen mit Metadaten `see_through`. Was sich im Physik-Takt bewegt,
  wird weich zwischen zwei Physik-Lagen gezeigt (`MotionSmoother`, neue bewegte Dinge in `StreetLife._smoothed_nodes()`).
  Stau-Wächter `StreetUnblock` löst Steckenbleiben.
- **Skelett:** `get_bone_global_pose` zeigt außerhalb der Modifikatoren die Pose ohne sie – Lagen von Händen/Füßen im Signal
  `Skeleton3D.skeleton_updated` ablesen. Hand-Achsen: +Y Finger, +Z Handrücken.
- **Shader:** Relief nie über Bildschirm-Ableitungen (dFdx/dFdy → Treppchen); feine Muster in der Ferne ausblenden.
  `RenderingServer.global_shader_parameter_get` nie im Spiel benutzen (bremst, nur für den Editor).
- **Leistung:** keine Verdecker (Occluder) in Häuser mit Fenstern oder vor Türen; Vorschau-Fenster (SubViewports) mit
  `Settings.match_preview_quality`.
- **Z-Fighting vermeiden:** nie zwei Flächen genau in derselben Ebene – die kleinere 2 mm zurücksetzen.

## Modelle bauen (Blender-Scripts in `tools/blender/`)
- **Bilderbuch-Stil** (`docs/STYLE_GUIDE.md`): warm, handwerklich, bewusst unperfekt, aber solide (nie Knete). Bausteine
  `storybook_lib.py` (`Body`: box/span/slab/tube/lathe/blob/leaf/star … – jedes Teil ein **geschlossener Körper**, Farbton je
  Teil, weiche Kanten als Bevel), `storybook_common.py` (Materialien, Töpfe, Export `export_objects`, Fingerabdruck,
  Kontrollbilder `--render`), `storybook_town.py` (Läden), `storybook_furniture.py` (Möbel-`Kit`). Godot zeichnet nur
  Vorderseiten: nie Einzelflächen; hinter Glas immer etwas. Am Ende muss das Script „Offene Kanten: keine“ melden.
- Godot-Koordinaten x rechts, y oben, z nach vorn = Blender (x, -z, y); Möbel: Vorderseite Blender -y.
- **Welche Scripts:** Läden `build_storybook_<shop|pub|bakery|flowers|tea|wool|gatehouse>.py`, Wohnhäuser
  `build_storybook_street.py`, Bücherei-Fassade `build_storybook_facade.py` (+ `facade_options.py`), Gassen
  `build_storybook_alleys.py`, Straßenmöbel `build_storybook_props.py`, Laternen `build_storybook_lamps.py`, Eingangstreppe
  `build_storybook_steps.py`, Pflanzen `build_storybook_plants.py`, Herbst-Deko `build_storybook_autumn.py`, Taschen/Körbe
  `build_storybook_bags.py`, Autos `build_vehicles.py`, Fahrräder `build_storybook_vehicles.py`, Tiere `build_animals.py`,
  Figuren `build_chibi.py`, Hauptmenü-Garten `build_title_garden.py`, Möbel `tools/build_furniture.sh [ids]`, Briefkasten/
  Telefonzelle/Straßenuhr/Mülleimer `build_storybook_street_furniture.py`, Lieferkartons `build_storybook_boxes.py`.
- **Neu gebaute .glb:** Die Scripts schreiben die `.glb.import` ohne die bisherige `uid=` – alte Zeile aus Git zurückholen
  (`git show HEAD:<datei>.import`), dann `godot --headless --path . --import`.
- **Pflanzen** nie ins Haus-Modell (Pflanzplätze `PlantSpot_…`, gesetzt von `Greenery`), außer Efeu an Wänden.
- **Prüfungen vor dem Hochladen:** Lochprüfung `storybook_gap_check.py`, Überschneidungen `storybook_overlap_check.py`,
  Möbelbeine `leg_check.py`, schwebende Teile `geo_check.py` (bei Möbel-Pflanzen nicht aussagekräftig), Pflanzen in Töpfen,
  Kästen und Gittern der Möbel `plant_clip_check.py`; das Möbel-Bau-Script meldet „Offene Kanten“ je Objekt. Nach
  Änderungen an Häusern Tier-Plätze neu ausmessen (`scenes/tools/bake_animal_spots.tscn`).

## Prüf- und Bildwerkzeuge
- Straßenleben ohne Bilder: `godot --headless --path . res://scenes/tools/street_life_check.tscn -- --seconds=60 --seed=1`
  (Erscheinen/Verschwinden im Blickfeld 0, overlap/stall möglichst 0; Optionen u. a. `--visitors=<n>`, `--hour=<h>
  --run_clock`, `--cats`, `--wishes`).
- Testbilder: `tools/screenshots.sh <gruppe>` (`--list`, `--only=`, `--cam=x,y,z:tx,ty,tz`, `--time=<h>`, `--tag=`,
  `--scene=res://…`, `--ui=…`).
- Probe-Szenen in `scenes/tools/` (Start und Optionen stehen oben im jeweiligen Script): `pose_probe` (Haltungen der Figuren,
  `-- hand|drink|eat|bag …`), `furniture_probe`, `catalog_showroom`, `vehicle_showroom`, `desk_probe`, `talk_probe`,
  `title_probe`, `ui_probe`, `startup_probe`, `facade_probe`, `make_signs`.
- Draufsicht und Sichtprüfung der Straßenenden: `python3 tools/plan_check.py plan|bound|gate|unseen`.

## Agent skills

### Issue tracker

Aufgaben-Zettel (Tickets, Specs) liegen als Markdown-Dateien in `.scratch/<feature>/` (Text auf Deutsch, einfache Worte); `docs/ROADMAP.md` + Notion bleiben der Überblick. See `docs/agents/issue-tracker.md`.

### Triage labels

Standard-Namen (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) als `Status:`-Zeile in jedem Zettel. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: ein `GLOSSARY.md` + `docs/adr/` im Hauptordner (entstehen erst bei Bedarf). See `docs/agents/domain.md`.
