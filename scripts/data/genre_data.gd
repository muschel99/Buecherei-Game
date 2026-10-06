@tool
class_name GenreData
extends Resource
## Datenblatt für ein Buch-Genre (z. B. Krimi, Fantasy, Kinderbuch).
##
## Jede Datei in data/genres/ (Endung .tres) ist ein solches Datenblatt.
## Der Katalog liest den Ordner beim Spielstart automatisch ein – ein neues Genre braucht
## also keinen Code, nur ein neues Datenblatt (und am besten eine Wortliste für die Titel).
## - Umbenennen: einfach "Display Name" ändern (die id bleibt gleich).
## - Freischalten: Häkchen bei "Is Unlocked" setzen (im Spiel später auch über
##   BookStock.unlock_genre("id"), z. B. in Etappe 8).
## Anleitung: docs/ASSET_GUIDE.md, Abschnitt "Bücher und Genres".

## Eindeutiger Name ohne Leer- und Sonderzeichen, z. B. "crime".
## Wird im Spielstand gespeichert – nach dem ersten Benutzen nicht mehr ändern.
## Bleibt das Feld leer, wird der Dateiname verwendet.
@export var id: String = ""
## Name im Spiel, z. B. "Krimi".
@export var display_name: String = "Neues Genre"
## Kurze Beschreibung (erscheint im Shop, wenn die Maus über der Karte steht).
@export_multiline var description: String = ""
## Farben der Buchrücken. Jedes Buch bekommt eine davon, leicht abgewandelt
## (heller, dunkler, etwas wärmer oder kühler), damit kein Regal gleichförmig aussieht.
@export var spine_colors: Array[Color] = [Color(0.55, 0.4, 0.3)]
## Passender Stil (freiwillig). Ohne Häkchen = stilneutral.
@export_flags("Botanisch:1", "Modern:2", "Dark Academia:4") var styles: int = 0
## Preis eines Bücherpakets in Talern (wie viele Bücher in einem Paket stecken, steht in
## GameConfig.books_per_package).
@export var price: int = 40
## Ist das Genre schon freigeschaltet (im Shop und im Regal-Menü zu sehen)?
@export var is_unlocked: bool = true
## Reihenfolge in Listen (kleiner = weiter vorn).
@export var sort_order: int = 100
## Textdatei mit den Wortlisten für erfundene Buchtitel.
## Leer = data/book_titles/<id>.txt
@export_file("*.txt") var title_words_path: String = ""


## Eindeutiger Name (aus dem Feld "id" oder ersatzweise dem Dateinamen).
func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()


## Die Hauptfarbe des Genres (für Schilder, Punkte in Listen und Symbole).
func get_main_color() -> Color:
	return spine_colors[0] if not spine_colors.is_empty() else Color(0.55, 0.4, 0.3)


## Pfad der Wortliste für die Titel.
func get_title_words_path() -> String:
	if not title_words_path.is_empty():
		return title_words_path
	return "res://data/book_titles/%s.txt" % get_id()
