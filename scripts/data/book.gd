class_name Book
extends RefCounted
## Ein einzelnes Buch-Exemplar: welcher Titel (BookData aus dem Katalog) und in welchem Zustand.
##
## Von einem Titel kann es mehrere Exemplare geben – alle sehen gleich aus (Größe, Cover,
## Buchrücken stehen im Titel). Bücher sind keine eigenen 3D-Objekte: Im Regal zeichnet sie
## das Regal gesammelt (BookShelf), im Lager stehen sie nur in einer Liste (BookStock).

## Zustand eines Buchs. Vorerst sind alle Bücher in gutem Zustand; beschädigte Bücher
## (Reparatur) kommen später dazu.
enum Condition { GOOD, WORN, DAMAGED }

const _CONDITION_IDS := {Condition.GOOD: "good", Condition.WORN: "worn", Condition.DAMAGED: "damaged"}

## Der Titel aus dem Katalog.
var data: BookData
var condition: Condition = Condition.GOOD
## Feste Zufallszahl je Exemplar – nur für winzige Unterschiede beim Hinstellen
## (leicht schief, etwas weiter vorn oder hinten).
var look: int = 0

## Kurzer Zugriff auf Titel und Genre.
var title: String:
	get:
		return data.title if data else ""
var genre_id: String:
	get:
		return data.genre_id if data else ""


## Ein neues Exemplar eines Titels.
static func create_from(book_data: BookData) -> Book:
	var book := Book.new()
	book.data = book_data
	book.look = randi()
	return book


## Das Datenblatt des Genres (oder null, falls es das Genre nicht mehr gibt).
func get_genre() -> GenreData:
	return Catalog.get_genre(genre_id)


# --- Speichern und Laden ---

func to_save_data() -> Dictionary:
	# Titel und Genre stehen zur Sicherheit mit drin (falls die Zeile einmal gelöscht wird)
	return {"id": data.id, "title": data.title, "genre": data.genre_id,
		"condition": _CONDITION_IDS[condition], "look": look}


static func from_save_data(saved: Variant) -> Book:
	if not saved is Dictionary:
		return null
	var genre_id_value := str(saved.get("genre", ""))
	var book_data: BookData = null
	if saved.has("id"):
		book_data = Catalog.get_book(str(saved["id"]))
		if book_data == null and not genre_id_value.is_empty():
			# Titel steht nicht mehr in der Bücherliste: so behalten, wie er war
			book_data = BookData.create(Catalog.get_genre(genre_id_value), str(saved.get("title", "Ohne Titel")))
			Catalog.register_custom_book(book_data)
			book_data = Catalog.get_book(book_data.id)
	elif not genre_id_value.is_empty():
		# Spielstand von vor den echten Titeln: ein Titel aus der Bücherliste des Genres
		book_data = BookStock.pick_title_for_old_book(genre_id_value)
	if book_data == null:
		return null
	var book := Book.new()
	book.data = book_data
	var condition_value: Variant = _CONDITION_IDS.find_key(str(saved.get("condition", "good")))
	book.condition = condition_value if condition_value != null else Condition.GOOD
	book.look = int(saved.get("look", randi()))
	BookStock.mark_discovered(book_data.id)
	return book


## Wandelt eine Liste von Büchern in Speicherdaten um.
static func list_to_save_data(books: Array) -> Array:
	var result := []
	for book: Book in books:
		result.append(book.to_save_data())
	return result


## Liest eine Liste von Büchern aus Speicherdaten (Unlesbares wird übersprungen).
static func list_from_save_data(saved: Variant) -> Array[Book]:
	var result: Array[Book] = []
	if saved is Array:
		for entry in saved:
			var book := from_save_data(entry)
			if book:
				result.append(book)
	return result
