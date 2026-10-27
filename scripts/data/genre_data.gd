@tool
class_name GenreData
extends Resource
## Datenblatt für ein Buch-Genre (z. B. Krimi, Fantasy, Kinderbuch).
##
## Jede Datei in data/genres/ (Endung .tres) ist ein solches Datenblatt.
## Der Katalog liest den Ordner beim Spielstart automatisch ein – ein neues Genre braucht
## also keinen Code, nur ein neues Datenblatt und eine Bücherliste (data/books/<id>.txt).
## - Umbenennen: einfach "Display Name" ändern (die id bleibt gleich).
## - Freischalten: Häkchen bei "Is Unlocked" setzen (im Spiel später auch über
##   BookStock.unlock_genre("id"), z. B. in Etappe 10).
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
## Passender Stil (freiwillig): Stile aus data/styles/. Leer = stilneutral.
@export var style_ids: Array[String] = []
## Preis eines Bücherpakets in Talern (wie viele Bücher in einem Paket stecken, steht in
## GameConfig.books_per_package).
@export var price: int = 40
## Ist das Genre schon freigeschaltet (im Shop und im Regal-Menü zu sehen)?
@export var is_unlocked: bool = true
## Reihenfolge in Listen (kleiner = weiter vorn).
@export var sort_order: int = 100
## Textdatei mit den Büchern dieses Genres (eine Zeile pro Buch: Titel | Motiv).
## Leer = data/books/<id>.txt
@export_file("*.txt") var books_path: String = ""

@export_group("Cover")
## Schriftart für Titel auf Cover und Buchrücken.
enum CoverFont { SERIF, SANS, PLAYFUL }
@export var cover_font: CoverFont = CoverFont.SERIF
## Gestaltungen, die zu diesem Genre passen (eine davon bekommt jedes Buch, sofern in der
## Bücherliste keine eigene steht): classic (Rahmen, edel), picture (großes Bild),
## minimal (hell, schlicht), pattern (Muster mit Schild), band (Bild oben, Titelfeld unten),
## comic (bunt, kräftig). Mehrfach nennen = häufiger.
@export var cover_styles: Array[String] = ["classic", "picture", "band"]


## Eindeutiger Name (aus dem Feld "id" oder ersatzweise dem Dateinamen).
func get_id() -> String:
	if not id.is_empty():
		return id
	return resource_path.get_file().get_basename()


## Die Hauptfarbe des Genres (für Schilder, Punkte in Listen und Symbole).
func get_main_color() -> Color:
	return spine_colors[0] if not spine_colors.is_empty() else Color(0.55, 0.4, 0.3)


## Pfad der Bücherliste.
func get_books_path() -> String:
	if not books_path.is_empty():
		return books_path
	return "res://data/books/%s.txt" % get_id()


## Im Inspektor: Stile als Auswahlliste (aus data/styles/).
func _validate_property(property: Dictionary) -> void:
	if property.name == "style_ids":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = StyleTags.inspector_hint_string()


## Ältere Datenblätter speicherten die Stile als Zahl ("styles = 4", 1 Botanisch, 2 Modern,
## 4 Dark Academia) – beim Laden werden sie auf die heutigen Stile übertragen.
func _set(property: StringName, value: Variant) -> bool:
	if property == &"styles" and value is int:
		style_ids = StyleTags.from_legacy_flags(value)
		return true
	return false
