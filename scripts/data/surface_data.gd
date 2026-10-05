class_name SurfaceData
extends Resource
## Datenblatt für eine Wandfarbe oder einen Bodenbelag.
##
## Jede Datei in data/surfaces/ (Endung .tres) ist ein solches Datenblatt.
## Wandfarben und Böden sind stilneutral: Sie zählen nicht zur Stilberechnung.
## Das Aussehen steckt im Feld "material": Dort kann ein einfaches Material
## mit Farbe oder ein Material mit eigener Textur stehen.
## Anleitung: docs/ASSET_GUIDE.md, Abschnitt "Eigene Wandfarben und Böden".

enum Kind { WALL, FLOOR }

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "wall_sage_green".
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name im Katalog, z. B. "Salbeigrün".
@export var display_name: String = "Neue Oberfläche"
## Wand oder Boden?
@export var kind: Kind = Kind.WALL
## Preis in Talern für den ganzen Raum (wird ab Etappe 5 abgezogen).
@export var price: int = 0
## Das Material, das auf Wände bzw. Boden gelegt wird.
@export var material: Material
## Farbe des Farbfelds im Katalog.
@export var preview_color: Color = Color(0.8, 0.75, 0.65)
## Erscheint die Oberfläche schon im Katalog?
@export var is_unlocked: bool = true


func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()
