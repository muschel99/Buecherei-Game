@tool
class_name ReturnSlotData
extends Resource
## Datenblatt einer Einwurf-Variante für den Rückgabekasten (außen in der Hauswand),
## z. B. schlichter Schlitz oder Klappe.
##
## Jede Datei in data/return_slots/ (Endung .tres) ist ein solches Datenblatt. Der Katalog
## liest den Ordner beim Spielstart automatisch ein, die App "Fassade" zeigt alle Varianten
## zur Auswahl – eine neue Variante braucht also keinen Code, nur ein Datenblatt und eine
## kleine Modell-Szene (Anleitung: docs/ASSET_GUIDE.md, Abschnitt "Rückgabekasten").

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "slot_plain".
## Wird im Spielstand gespeichert – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name in der App, z. B. "Schlichter Schlitz".
@export var display_name: String = "Neuer Einwurf"
## Modell des Einwurfs (.tscn oder .glb): Vorderseite zeigt nach +Z (zur Straße),
## Ursprung hinten in der Mitte (dort, wo es an der Hauswand anliegt).
@export_file("*.tscn", "*.glb") var scene_path: String = ""
## Eigenes Vorschaubild für die App (leer = das Modell wird fotografiert).
@export var icon: Texture2D
## Reihenfolge in der App (kleiner = weiter vorn).
@export var order: int = 0


func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()
