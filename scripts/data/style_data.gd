@tool
class_name StyleData
extends Resource
## Datenblatt für einen Einrichtungsstil (z. B. Dark Academia, Minimalistisch, Landhaus).
##
## Jede Datei in data/styles/ (Endung .tres) ist ein Stil. Möbel, Oberflächen und Genres
## nennen ihre Stile über die id (Feld "Style Ids" im Datenblatt). Ein neuer Stil ist nur
## eine neue Datei hier – kein Code: Er erscheint von selbst als Filter in Shop und
## Gestaltungsmodus, in der Stilanzeige und im Inspektor als Auswahl.
## Der Stil dient nur dem Einrichten (er bestimmt keine Besucher und keine Musik).

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "dark_academia".
## Steht in den Datenblättern der Möbel – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name im Spiel, z. B. "Dark Academia".
@export var display_name: String = "Neuer Stil"
## Ein kurzer Satz, worum es in dem Stil geht (erscheint im Tooltip des Filters).
@export_multiline var description: String = ""
## Erkennungsfarbe (Filter, Stilanzeige).
@export var color: Color = Color(0.8, 0.7, 0.55)
## Kleines Symbol für den Filter-Knopf (freiwillig). Leer = ein Punkt in der Erkennungsfarbe.
@export var icon: Texture2D
## Reihenfolge in Listen (kleiner = weiter vorn).
@export var order: int = 100


func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()
