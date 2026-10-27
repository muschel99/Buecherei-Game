@tool
class_name FurnitureData
extends Resource
## Datenblatt für ein Möbelstück oder Deko-Objekt.
##
## Jede Datei in data/furniture/ (Endung .tres) ist ein solches Datenblatt.
## Der Katalog liest diesen Ordner automatisch ein (Shop und Inventar bauen darauf auf):
## Neue Möbel brauchen also keinen neuen Code, nur ein neues Datenblatt.
## Anleitung: docs/ASSET_GUIDE.md, Abschnitt "Ein neues Möbelstück anlegen".

## Kategorien im Katalog (Reihenfolge = Reihenfolge der Reiter).
## (Pflanzen sind seit "Fensterlicht und Filter" eine Unterkategorie von Deko.)
enum Category { SHELF, SEATING, TABLE, COUNTER, LIGHTING, DECO, DIVIDER }

const _CATEGORY_NAMES := {
	Category.SHELF: "Regale",
	Category.SEATING: "Sitzmöbel",
	Category.TABLE: "Tische",
	Category.COUNTER: "Theke",
	Category.LIGHTING: "Beleuchtung",
	Category.DECO: "Deko",
	Category.DIVIDER: "Raumteiler",
}

## Unterkategorien je Kategorie – sie erscheinen als Filter über der Liste in Shop und
## Inventar (in dieser Reihenfolge, nur wenn es dort etwas gibt).
## Neue Unterkategorie: einfach ein Paar ["id", "Anzeigename"] in die passende Zeile
## schreiben. Die id ist kurz, englisch, ohne Leerzeichen; im Datenblatt wählt man sie
## dann im Feld "Subcategory" aus.
const SUBCATEGORIES := {
	Category.SHELF: [["bookshelf", "Bücherregale"], ["deco_shelf", "Deko-Regale"], ["wall_shelf", "Wandregale"],
		["display_case", "Vitrinen"], ["cabinet", "Schränke und Kommoden"]],
	Category.SEATING: [["armchair", "Sessel"], ["sofa", "Sofas"], ["chair", "Stühle"], ["stool", "Hocker"]],
	Category.TABLE: [["side_table", "Beistelltische"], ["coffee_table", "Couchtische"], ["desk", "Schreibtische"],
		["dining_table", "Esstische"]],
	Category.COUNTER: [],
	Category.LIGHTING: [["table_lamp", "Tischlampen"], ["floor_lamp", "Stehlampen"], ["ceiling_lamp", "Deckenlampen"],
		["wall_lamp", "Wandlampen"], ["candle", "Kerzen und Laternen"], ["switch", "Lichtschalter"]],
	Category.DECO: [["plant", "Pflanzen"], ["vase", "Vasen und Blumen"], ["rug", "Teppiche"], ["picture", "Bilder und Wandschmuck"],
		["figure", "Figuren und Kuriositäten"], ["textile", "Textilien"], ["tableware", "Geschirr"],
		["storage", "Aufbewahrung und Organisation"], ["books", "Bücher"], ["bookend", "Buchstützen"]],
	Category.DIVIDER: [],
}

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "armchair_velvet".
## Wird im Spielstand gespeichert – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name im Katalog, z. B. "Ohrensessel".
@export var display_name: String = "Neues Möbelstück"
## Kurze Beschreibung (erscheint im Katalog, wenn die Maus darüber steht).
@export_multiline var description: String = ""
@export var category: Category = Category.DECO:
	set(value):
		category = value
		notify_property_list_changed()  # Auswahl der Unterkategorien im Inspektor anpassen
## Unterkategorie (für die Filter), passend zur Kategorie – siehe SUBCATEGORIES oben.
## Leer = keine; dann erscheint es nur unter "Alle".
@export var subcategory: String = ""
## Preis in Talern im Shop. Beim Verkaufen gibt es einen Teil davon zurück
## (GameConfig.sell_price_share).
@export var price: int = 0
## Stil-Merkmale: einer oder mehrere Stile aus data/styles/ (z. B. "dark_academia"). Leer = das
## Objekt ist stilneutral und zählt nicht zur Stilanzeige (z. B. Lichtschalter, Kasse).
@export var style_ids: Array[String] = []
## Die Szene (.tscn) oder das 3D-Modell (.glb) des Möbelstücks.
@export_file("*.tscn", "*.scn", "*.glb", "*.gltf") var scene_path: String = ""
## Eigenes Vorschaubild für den Shop (freiwillig). Leer = das Spiel fotografiert das
## Modell selbst.
@export var icon: Texture2D
## Grundfläche in Rasterfeldern (Breite x Tiefe). Ein Feld ist
## GameConfig.grid_cell_size groß (Standard 1/9 m ≈ 11,1 cm), 9 Felder = 1 Meter.
@export var footprint: Vector2i = Vector2i(2, 2)
## Erscheint das Möbelstück schon im Shop?
@export var is_unlocked: bool = true
## Gehört fest zur Bücherei (z. B. das Tablet mit dem Shop): Es steht nicht im Shop und
## lässt sich nicht verkaufen – nur verschieben oder ins Inventar legen.
@export var is_essential: bool = false
## Fest im Laden verbaut (z. B. die Theke): Es lässt sich im Gestaltungsmodus zwar frei
## verschieben, aber nicht wegräumen (X) und liegt nie im Inventar. Sinnvoll zusammen mit
## is_essential (dann auch nicht kaufbar und nicht verkaufbar).
@export var is_fixed: bool = false

@export_group("Platzierung")
## Wo darf es hin? Ein oder mehrere Häkchen:
## Boden, Ablagefläche (Tisch, Regalbrett, Sitzfläche, Fensterbank …), Wand, Tür, Decke.
## Welche Ablageflächen ein Möbelstück selbst anbietet, steht in seiner Szene
## (Knoten vom Typ PlacementSurface).
@export_flags("Boden:1", "Ablagefläche:2", "Wand:4", "Tür:8", "Decke:16") var placement: int = PLACE_FLOOR

@export_group("Bücher")
## Bücher lassen sich daran anlehnen (wie an eine Wand): Lehnen von Sofas, Sesseln und Stühlen,
## große Blumentöpfe. Nie bei kleiner Deko (Figuren, kleine Vasen …).
@export var books_can_lean: bool = false
## Bücher lassen sich flach obendrauf legen, auch ohne Ablagefläche (Polster: Kissen, Decke).
@export var books_can_lie: bool = false

@export_group("Farben")
## Farbvarianten beim Kauf (3–5 je Objekt). Die erste ist die Standardfarbe. Eingefärbt werden
## nur Teile, deren Material so heißt wie ein Eintrag der Variante (siehe ColorVariant).
## Leer = nur eine Farbe (so, wie das Modell gebaut ist).
@export var color_variants: Array[ColorVariant] = []

## Trennzeichen zwischen id und Farbe in Inventar und Spielstand, z. B. "armchair_wing:bordeaux".
const VARIANT_SEPARATOR := ":"

## Werte für "placement"
const PLACE_FLOOR := 1
const PLACE_SURFACE := 2
const PLACE_WALL := 4
const PLACE_DOOR := 8
const PLACE_CEILING := 16


## Darf es dorthin? (z. B. allows(PLACE_WALL))
func allows(where: int) -> bool:
	return (placement & where) != 0


## Wird es an Wand oder Tür gehängt? (richtet sich dann nach der Fläche aus)
func is_wall_mounted() -> bool:
	return allows(PLACE_WALL) or allows(PLACE_DOOR)


## Wird es aufgehängt (an Wand, Tür oder Decke)?
func is_hanging() -> bool:
	return is_wall_mounted() or allows(PLACE_CEILING)


## Eindeutiger Name (aus dem Feld "id" oder ersatzweise dem Dateinamen).
func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()


## Hat das Objekt mehrere Farben zur Auswahl?
func has_variants() -> bool:
	return not color_variants.is_empty()


## Die Farbvariante mit dieser id (oder null). Unbekannte/leere id = die Standardfarbe.
func get_variant(variant_id: String) -> ColorVariant:
	for variant in color_variants:
		if variant and variant.id == variant_id:
			return variant
	return color_variants[0] if has_variants() else null


## Gültige Farb-id: die angegebene, falls es sie gibt, sonst die Standardfarbe ("" ohne Farben).
## So werden alte Spielstände ohne Farbe zur Standardfarbe.
func resolve_variant(variant_id: String) -> String:
	var variant := get_variant(variant_id)
	return variant.id if variant else ""


## Name der Farbe für Tooltips (leer ohne Farbvarianten).
func get_variant_name(variant_id: String) -> String:
	var variant := get_variant(variant_id)
	if variant == null:
		return ""
	return variant.display_name if not variant.display_name.is_empty() else variant.id


## Schlüssel für Inventar und Spielstand: "id" bzw. "id:farbe".
static func make_key(furniture_id: String, variant_id: String) -> String:
	if variant_id.is_empty():
		return furniture_id
	return furniture_id + VARIANT_SEPARATOR + variant_id


## Zerlegt einen Schlüssel in [id, farbe] ("id" allein -> [id, ""]).
static func split_key(key: String) -> Array[String]:
	var at := key.find(VARIANT_SEPARATOR)
	if at < 0:
		return [key, ""]
	return [key.substr(0, at), key.substr(at + 1)]


## Anzeigename der Unterkategorie (leer, wenn keine gewählt ist).
func get_subcategory_name() -> String:
	return get_subcategory_display_name(category, subcategory)


static func get_subcategory_display_name(of_category: Category, id: String) -> String:
	for entry in SUBCATEGORIES.get(of_category, []):
		if entry[0] == id:
			return entry[1]
	return ""


## Im Inspektor: Feld "Subcategory" als Auswahlliste mit den Unterkategorien der Kategorie.
func _validate_property(property: Dictionary) -> void:
	if property.name == "style_ids":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = StyleTags.inspector_hint_string()
	if property.name == "subcategory":
		var ids: Array[String] = [""]
		for entry in SUBCATEGORIES.get(category, []):
			ids.append(entry[0])
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(ids)


func get_category_name() -> String:
	return get_category_display_name(category)


static func get_category_display_name(value: Category) -> String:
	return _CATEGORY_NAMES.get(value, "?")


## Was man beim Verkaufen zurückbekommt (Anteil GameConfig.sell_price_share des Preises).
func get_sell_price() -> int:
	return maxi(0, roundi(price * GameConfig.sell_price_share))


## Grundfläche in Metern (Breite, Tiefe).
func get_footprint_size() -> Vector2:
	return Vector2(footprint) * GameConfig.grid_cell_size


## Ältere Datenblätter speicherten die Stile als Zahl ("styles = 4", 1 Botanisch, 2 Modern,
## 4 Dark Academia) – beim Laden werden sie auf die heutigen Stile übertragen.
func _set(property: StringName, value: Variant) -> bool:
	if property == &"styles" and value is int:
		style_ids = StyleTags.from_legacy_flags(value)
		return true
	return false
