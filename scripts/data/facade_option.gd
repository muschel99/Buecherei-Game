@tool
class_name FacadeOption
extends Resource
## Eine Wahl für die Fassade der Bücherei (seit Etappe 6b, App „Fassade“): ein Erdgeschoss, eine
## Wand oben, ein Fenster, eine Markise, ein Stoff, eine Tür, ein Blumenkasten, eine Ampel, eine
## Farbe, eine Pflanze oder wie voll alles blüht.
##
## Jede Datei in data/facade/ ist ein solches Datenblatt (erzeugt von tools/blender/facade_options.py,
## eigene lassen sich einfach dazulegen). Der Katalog liest den Ordner ein, die App zeigt je Kategorie
## alle Optionen als Kacheln, LibraryFacade baut die Fassade daraus. Neue Option = neues Datenblatt.

## Eindeutig innerhalb der Kategorie (steht im Spielstand – später nicht mehr ändern).
@export var id: String = ""
@export var display_name: String = ""
## Wofür die Option ist (seit Etappe 6c): wall, quoins, ground, ground_color, fascia, window_ground, window,
## frame_color, door, door_lights, door_color, awning, fabric, box, basket, plants, fullness, deco.
@export var category: String = ""
## Frei wählbar (true) oder gesperrt, bis die Geschichte sie freischaltet (FacadeDesign.unlock).
@export var unlocked: bool = false
## Reihenfolge in der App (kleiner = weiter vorn).
@export var order: int = 0
## Kosten beim Bauen (nur, wenn sich diese Kategorie ändert).
@export var price: int = 0
## Modell (Erdgeschoss, Obergeschoss, Markise, Türblatt, Blumenkasten, Ampel); leer = keins
## (z. B. „Keine Markise“).
@export_file("*.glb", "*.tscn") var scene_path: String = ""
## Ersetzt eine Fläche des Modells (Wand oben, Naturstein unten, Markisenstoff).
@export var material: Material
## Farbe (Anstrich unten, Fensterrahmen, Tür); durchsichtig = keine.
@export var color: Color = Color(0, 0, 0, 0)
## Farbe der Kachel (wenn es kein Modell zum Fotografieren gibt).
@export var swatch: Color = Color(0, 0, 0, 0)
## Zusammengehörige Optionen (z. B. Pflanzenart „Geranien“): eine Kachel mit Farbtupfern.
@export var group: String = ""
## Pflanzen (Szenen-Namen aus scenes/world/plants/, z. B. "box_geranium_red").
@export var plants: PackedStringArray = []
## Fülle: so viel mehr Pflanzen und so viel größer (1 = üppig).
@export var amount: float = 1.0
## Ecksteine im Obergeschoss ausblenden (z. B. bei Holz).
@export var hide_quoins: bool = false
## Wie alt und verwittert (0 neu … 1 bröckelnd): Putzreste, abgeplatzte Stellen, Risse, fehlende Steine
## bzw. abblätternde Farbe (Shader-Wert „weather“).
@export_range(0.0, 1.0) var weather: float = 0.0

@export_group("Fenster und Türen")
## Form der Öffnung: "rect", "arch" (oben ein Bogen, Stich = rise) oder "round".
@export var shape: String = "rect"
## Größe der Öffnung (Breite, Höhe) und Höhe der Unterkante über dem Ladenboden (Meter)
@export var opening: Vector2 = Vector2.ZERO
@export var bottom: float = 0.0
@export var rise: float = 0.0
## Sprossen: Spalten x Reihen (1 x 1 = keine)
@export var muntins: Vector2i = Vector2i.ONE
## Erker: so weit steht das Fenster vor (0 = kein Erker)
@export var bay_depth: float = 0.0
## Seitenlichter (Breite je Seite) und Oberlicht (Höhe) an der Ladentür
@export var side_width: float = 0.0
@export var transom: float = 0.0
## Erdgeschoss: "wood" (Holzfront aus dem Modell) oder "masonry" (Mauerwerk, Material der Wand bzw. eigenes)
@export var family: String = ""

@export_group("Pflanzen")
## Pflanzenmischung: Szenen für Hängekörbe (die für Kästen stehen in plants)
@export var basket_plants: PackedStringArray = []
## … und Ranken bzw. Gräser, die über die Ränder wachsen
@export var rim_plants: PackedStringArray = []
@export_group("")
## Eigenes Bild für die Kachel (leer = Foto des Modells bzw. Farbfeld).
@export var icon: Texture2D


## Farbe für die Kachel: eigene Farbe, sonst die Farbe der Option.
func get_swatch() -> Color:
	return swatch if swatch.a > 0.0 else color
