class_name Book
extends RefCounted
## Ein einzelnes Buch: Titel, Genre und Zustand.
##
## Bücher sind keine eigenen 3D-Objekte – im Regal zeichnet sie das Regal gesammelt
## (siehe BookShelf), im Lager stehen sie nur in einer Liste (BookStock).
## "look" ist eine feste Zufallszahl je Buch: Daraus entstehen Höhe, Dicke und Farbton.
## So sieht jedes Buch nach dem Laden genauso aus wie vorher.

## Zustand eines Buchs. Vorerst sind alle Bücher in gutem Zustand; beschädigte Bücher
## (Reparatur) kommen später dazu.
enum Condition { GOOD, WORN, DAMAGED }

const _CONDITION_IDS := {Condition.GOOD: "good", Condition.WORN: "worn", Condition.DAMAGED: "damaged"}

var title: String = ""
var genre_id: String = ""
var condition: Condition = Condition.GOOD
## Feste Zufallszahl für das Aussehen (Höhe, Dicke, Farbton).
var look: int = 0


## Ein neues Buch eines Genres mit erfundenem, passendem Titel.
static func create(new_genre_id: String) -> Book:
	var book := Book.new()
	book.genre_id = new_genre_id
	book.title = BookTitles.generate(Catalog.get_genre(new_genre_id))
	book.look = randi()
	return book


## Das Datenblatt des Genres (oder null, falls es das Genre nicht mehr gibt).
func get_genre() -> GenreData:
	return Catalog.get_genre(genre_id)


# --- Speichern und Laden ---

func to_save_data() -> Dictionary:
	return {"title": title, "genre": genre_id, "condition": _CONDITION_IDS[condition], "look": look}


static func from_save_data(data: Variant) -> Book:
	if not data is Dictionary:
		return null
	var book := Book.new()
	book.title = str(data.get("title", ""))
	book.genre_id = str(data.get("genre", ""))
	var condition_value: Variant = _CONDITION_IDS.find_key(str(data.get("condition", "good")))
	book.condition = condition_value if condition_value != null else Condition.GOOD
	book.look = int(data.get("look", 0))
	if book.genre_id.is_empty():
		return null
	return book


## Wandelt eine Liste von Büchern in Speicherdaten um.
static func list_to_save_data(books: Array) -> Array:
	var result := []
	for book: Book in books:
		result.append(book.to_save_data())
	return result


## Liest eine Liste von Büchern aus Speicherdaten (Unlesbares wird übersprungen).
static func list_from_save_data(data: Variant) -> Array[Book]:
	var result: Array[Book] = []
	if data is Array:
		for entry in data:
			var book := from_save_data(entry)
			if book:
				result.append(book)
	return result
