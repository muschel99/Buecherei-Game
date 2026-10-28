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
## Wofür die Option ist: ground, ground_color, upper, window, frame_color, awning, fabric, door,
## door_color, box, box_plant, basket, basket_plant, fullness.
@export var category: String = ""
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
## Eigenes Bild für die Kachel (leer = Foto des Modells bzw. Farbfeld).
@export var icon: Texture2D


## Farbe für die Kachel: eigene Farbe, sonst die Farbe der Option.
func get_swatch() -> Color:
	return swatch if swatch.a > 0.0 else color
