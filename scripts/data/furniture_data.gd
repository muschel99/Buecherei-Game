class_name FurnitureData
extends Resource
## Datenblatt für ein Möbelstück oder Deko-Objekt.
##
## Jede Datei in data/furniture/ (Endung .tres) ist ein solches Datenblatt.
## Der Katalog im Gestaltungsmodus liest diesen Ordner automatisch ein:
## Neue Möbel brauchen also keinen neuen Code, nur ein neues Datenblatt.
## Anleitung: docs/ASSET_GUIDE.md, Abschnitt "Ein neues Möbelstück anlegen".

## Kategorien im Katalog (Reihenfolge = Reihenfolge der Reiter).
enum Category { SHELF, SEATING, TABLE, COUNTER, LIGHTING, PLANT, DECO, DIVIDER }

const _CATEGORY_NAMES := {
	Category.SHELF: "Regale",
	Category.SEATING: "Sitzmöbel",
	Category.TABLE: "Tische",
	Category.COUNTER: "Theke",
	Category.LIGHTING: "Beleuchtung",
	Category.PLANT: "Pflanzen",
	Category.DECO: "Deko",
	Category.DIVIDER: "Raumteiler",
}

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "armchair_velvet".
## Wird im Spielstand gespeichert – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name im Katalog, z. B. "Ohrensessel".
@export var display_name: String = "Neues Möbelstück"
## Kurze Beschreibung (erscheint im Katalog, wenn die Maus darüber steht).
@export_multiline var description: String = ""
@export var category: Category = Category.DECO
## Preis in Talern (wird ab Etappe 5 abgezogen).
@export var price: int = 0
## Stil-Merkmale: eines oder mehrere Häkchen setzen.
@export_flags("Botanisch:1", "Modern:2", "Dark Academia:4") var styles: int = 0
## Die Szene (.tscn) oder das 3D-Modell (.glb) des Möbelstücks.
@export_file("*.tscn", "*.scn", "*.glb", "*.gltf") var scene_path: String = ""
## Grundfläche in Rasterfeldern (Breite x Tiefe). Ein Feld ist
## GameConfig.grid_cell_size groß (Standard 0,125 m), 8 Felder = 1 Meter.
@export var footprint: Vector2i = Vector2i(2, 2)
## Erscheint das Möbelstück schon im Katalog?
@export var is_unlocked: bool = true

@export_group("Platzierung")
## Darf auf Tischen, Regalbrettern und anderen Ablageflächen stehen (z. B. Deko).
@export var can_stand_on_surfaces: bool = false
## Bietet selbst eine Ablagefläche, auf die Deko gestellt werden kann (z. B. Tisch, Regal).
@export var has_surface: bool = false


## Eindeutiger Name (aus dem Feld "id" oder ersatzweise dem Dateinamen).
func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()


func get_category_name() -> String:
	return get_category_display_name(category)


static func get_category_display_name(value: Category) -> String:
	return _CATEGORY_NAMES.get(value, "?")


## Grundfläche in Metern (Breite, Tiefe).
func get_footprint_size() -> Vector2:
	return Vector2(footprint) * GameConfig.grid_cell_size
