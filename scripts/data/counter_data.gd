@tool
class_name CounterData
extends Resource
## Datenblatt einer Theken-Variante (die feste Theke im Laden), z. B. „Bibliothekstheke“ im Stil
## Dark Academia.
##
## Jede Datei in data/counters/ (Endung .tres) ist ein solches Datenblatt. Der Katalog liest den
## Ordner beim Spielstart ein, die App „Fassade“ zeigt alle Varianten zur Auswahl, CounterStyle
## merkt sich die gewählte, und die Theke (scenes/furniture/counter.tscn) setzt ihr Modell ein.
## Eine neue Theke braucht also keinen Code: Modell + Datenblatt (docs/ASSET_GUIDE.md, „Theke“).

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "counter_country".
## Wird im Spielstand gespeichert – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name in der App, z. B. "Landhaus-Theke".
@export var display_name: String = "Neue Theke"
## Ein, zwei Sätze für den Tooltip in der App.
@export_multiline var description: String = ""
## Passende Einrichtungsstile (freiwillig, leer = stilneutral). Zeigt die App als Farbpunkt.
@export var style_ids: Array[String] = []
## Modell der Theke (.glb oder .tscn): Vorderseite (Kundenseite) nach +Z, Fußpunkt in der Mitte
## auf Höhe 0, Oberkante der Platte genau auf 1 m, höchstens 2 m breit und 0,65 m tief
## (z von -0,305 bis 0,345) – so passen Kollision und Ablagefläche der Theken-Szene.
@export_file("*.glb", "*.tscn") var scene_path: String = ""
## Eigenes Vorschaubild für die App (leer = das Modell wird fotografiert).
@export var icon: Texture2D
## Reihenfolge in der App (kleiner = weiter vorn).
@export var order: int = 0
## Kosten beim Bauen in der App „Fassade“ (nur, wenn diese Theke neu gewählt wird).
@export var price: int = 0
## Frühere Kennungen dieser Theke (ältere Spielstände), z. B. "wood_warm".
@export var legacy_ids: PackedStringArray = []


func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()


func _validate_property(property: Dictionary) -> void:
	if property.name == "style_ids":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = StyleTags.inspector_hint_string()
