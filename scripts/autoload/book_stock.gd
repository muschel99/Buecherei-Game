extends Node
## Der Bücherbestand: alle Bücher, die mir gehören – getrennt vom Möbel-Inventar.
##
## Ein Buch ist immer an genau einem Ort:
## - im Lager (hier gespeichert, nach Genre sortiert),
## - in einem Regal (BookShelf, gespeichert mit dem Regal im Raum),
## - im Rückgabekasten (ReturnBox, ebenfalls mit dem Raum gespeichert),
## - oder ich trage es gerade (carried, hier gespeichert).
## Außerdem merkt sich der Bestand, welche Genres freigeschaltet sind.
## Im Code: BookStock.get_stored_count("crime"), BookStock.add_new_books("crime", 10) …
## Der Bestand wird mit dem Spielstand gespeichert (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich das Lager ändert.
signal changed
## Wird gesendet, wenn sich ändert, was ich trage.
signal carried_changed

## Gruppen der Regale und Rückgabekästen im Raum (zum Zählen).
const SHELF_GROUP := "book_shelves"
const RETURN_BOX_GROUP := "return_boxes"

## Name im Spielstand.
var save_key: String = "books"

## Bücher, die ich gerade trage (z. B. aus dem Rückgabekasten).
var carried: Array[Book] = []

var _stored: Dictionary = {}  # genre_id -> Array[Book]
## Genres, die im Spiel freigeschaltet wurden (zusätzlich zu "Is Unlocked" im Datenblatt)
var _unlocked: Array[String] = []
## Startgeschenke, die schon verteilt wurden (ids aus GameConfig.start_furniture_gifts)
var _gifts_given: Array[String] = []


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	# Neues Spiel (oder Spielstand von vor den Büchern): ein paar Bücher zum Einräumen
	for genre in get_unlocked_genres():
		_add_to_storage(_create_books(genre.get_id(), GameConfig.start_books_per_genre))


## Testtaste F9 (Aktion "debug_fill_return_box"): legt ein paar zufällige Bücher in den
## Rückgabekasten, solange es noch keine Besucher gibt. Abschalten: in GameConfig
## debug_return_box_key = false setzen.
func _unhandled_input(event: InputEvent) -> void:
	if GameConfig.debug_return_box_key and event.is_action_pressed("debug_fill_return_box"):
		fill_return_box_for_testing()
		get_viewport().set_input_as_handled()


## Legt GameConfig.debug_return_box_books zufällige Bücher in einen Rückgabekasten.
func fill_return_box_for_testing() -> void:
	var boxes := get_tree().get_nodes_in_group(RETURN_BOX_GROUP)
	if boxes.is_empty():
		Notice.post(self, "Test (F9): Stell zuerst einen Rückgabekasten auf (Tab → Theke).")
		return
	var genres := get_unlocked_genres()
	if genres.is_empty():
		return
	var books: Array[Book] = []
	for i in GameConfig.debug_return_box_books:
		books.append(Book.create(genres.pick_random().get_id()))
	boxes.pick_random().add_books(books)
	Notice.post(self, "Test (F9): %d Bücher liegen im Rückgabekasten." % books.size())


# --- Genres ---

func is_genre_unlocked(genre_id: String) -> bool:
	var genre := Catalog.get_genre(genre_id)
	return genre != null and (genre.is_unlocked or _unlocked.has(genre_id))


## Alle freigeschalteten Genres (sortiert).
func get_unlocked_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	for genre in Catalog.get_all_genres():
		if is_genre_unlocked(genre.get_id()):
			result.append(genre)
	return result


## Schaltet ein Genre frei (z. B. später als Belohnung in Etappe 8).
func unlock_genre(genre_id: String) -> void:
	if Catalog.get_genre(genre_id) == null or is_genre_unlocked(genre_id):
		return
	_unlocked.append(genre_id)
	_changed()


# --- Lager ---

## Wie viele Bücher dieses Genres liegen im Lager?
func get_stored_count(genre_id: String) -> int:
	return _stored.get(genre_id, []).size()


## Wie viele Bücher liegen insgesamt im Lager?
func get_stored_total() -> int:
	var total := 0
	for books: Array in _stored.values():
		total += books.size()
	return total


## Erzeugt neue Bücher (z. B. aus einem Bücherpaket) und legt sie ins Lager.
func add_new_books(genre_id: String, amount: int) -> Array[Book]:
	var books := _create_books(genre_id, amount)
	store_books(books)
	return books


## Legt Bücher ins Lager (z. B. aus einem Regal zurück).
func store_books(books: Array) -> void:
	if books.is_empty():
		return
	_add_to_storage(books)
	_changed()


## Nimmt bis zu "amount" Bücher eines Genres aus dem Lager.
func take_books(genre_id: String, amount: int) -> Array[Book]:
	var result: Array[Book] = []
	var books: Array = _stored.get(genre_id, [])
	while not books.is_empty() and result.size() < amount:
		result.append(books.pop_front())
	if books.is_empty():
		_stored.erase(genre_id)
	if not result.is_empty():
		_changed()
	return result


## Ein Buch zurück an den Anfang des Lagers (wenn es doch nicht ins Regal passt).
func put_back_first(books: Array) -> void:
	for i in range(books.size() - 1, -1, -1):
		var book: Book = books[i]
		if not _stored.has(book.genre_id):
			_stored[book.genre_id] = []
		_stored[book.genre_id].push_front(book)
	if not books.is_empty():
		_changed()


# --- Tragen ---

## Ich nehme Bücher in die Hand (z. B. aus dem Rückgabekasten).
func carry(books: Array) -> void:
	if books.is_empty():
		return
	carried.append_array(books)
	_carried_changed()


## Gibt getragene Bücher ab, die passen (genre_id "" = alle Genres), höchstens "limit".
func take_carried(genre_id: String, limit: int = -1) -> Array[Book]:
	var result: Array[Book] = []
	var kept: Array[Book] = []
	for book in carried:
		if (genre_id.is_empty() or book.genre_id == genre_id) and (limit < 0 or result.size() < limit):
			result.append(book)
		else:
			kept.append(book)
	if not result.is_empty():
		carried = kept
		_carried_changed()
	return result


## Wie viele getragene Bücher je Genre? (genre_id -> Anzahl, in Genre-Reihenfolge)
func get_carried_counts() -> Dictionary:
	return _count_by_genre(carried)


## Kurzer Text wie "3 Krimi, 4 Fantasy".
func describe_counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for genre_id in counts:
		var genre := Catalog.get_genre(genre_id)
		parts.append("%d %s" % [counts[genre_id], genre.display_name if genre else genre_id])
	return ", ".join(parts)


## Legt alles Getragene ins Lager.
func store_carried() -> int:
	var books := carried.duplicate()
	carried.clear()
	_add_to_storage(books)
	_changed()
	_carried_changed()
	return books.size()


# --- Übersicht ---

## Wie viele Bücher dieses Genres stehen in Regalen?
func count_in_shelves(genre_id: String) -> int:
	var count := 0
	for shelf in get_tree().get_nodes_in_group(SHELF_GROUP):
		count += shelf.count_books(genre_id)
	return count


## Wie viele Bücher dieses Genres liegen in Rückgabekästen?
func count_in_return_boxes(genre_id: String) -> int:
	var count := 0
	for box in get_tree().get_nodes_in_group(RETURN_BOX_GROUP):
		count += box.count_books(genre_id)
	return count


## Übersicht je Genre für die Bestandsliste am Tablet: Liste von
## { "genre": GenreData, "shelves": …, "stored": …, "elsewhere": …, "total": … }.
## "elsewhere" = getragen oder im Rückgabekasten. Gesperrte Genres erscheinen nur, wenn
## ich davon Bücher habe.
func get_overview() -> Array[Dictionary]:
	var carried_counts := get_carried_counts()
	var result: Array[Dictionary] = []
	for genre in Catalog.get_all_genres():
		var id := genre.get_id()
		var shelves := count_in_shelves(id)
		var stored := get_stored_count(id)
		var elsewhere := int(carried_counts.get(id, 0)) + count_in_return_boxes(id)
		var total := shelves + stored + elsewhere
		if total > 0 or is_genre_unlocked(id):
			result.append({"genre": genre, "shelves": shelves, "stored": stored, "elsewhere": elsewhere, "total": total})
	return result


## Alle Bücher dieses Genres, die mir gehören (überall).
func count_total(genre_id: String) -> int:
	return get_stored_count(genre_id) + count_in_shelves(genre_id) + count_in_return_boxes(genre_id) \
		+ int(get_carried_counts().get(genre_id, 0))


# --- Startgeschenke ---

## Legt die Startgeschenke (GameConfig.start_furniture_gifts, z. B. einen Rückgabekasten)
## ins Inventar – jedes nur einmal, auch bei älteren Spielständen.
## Wird von der Hauptszene nach dem Laden aufgerufen.
func give_start_gifts() -> void:
	for id in GameConfig.start_furniture_gifts:
		if _gifts_given.has(id) or Catalog.get_furniture(id) == null:
			continue
		Inventory.add_furniture(id, int(GameConfig.start_furniture_gifts[id]))
		_gifts_given.append(id)
		SaveManager.request_save()


# --- Hilfsfunktionen ---

func _create_books(genre_id: String, amount: int) -> Array[Book]:
	var books: Array[Book] = []
	if Catalog.get_genre(genre_id) == null:
		return books
	for i in maxi(amount, 0):
		books.append(Book.create(genre_id))
	return books


func _add_to_storage(books: Array) -> void:
	for book: Book in books:
		if not _stored.has(book.genre_id):
			_stored[book.genre_id] = []
		_stored[book.genre_id].append(book)


## Zählt Bücher je Genre (in der Reihenfolge der Genres).
func _count_by_genre(books: Array) -> Dictionary:
	var counts := {}
	for book: Book in books:
		counts[book.genre_id] = int(counts.get(book.genre_id, 0)) + 1
	var sorted := {}
	for genre in Catalog.get_all_genres():
		if counts.has(genre.get_id()):
			sorted[genre.get_id()] = counts[genre.get_id()]
	for genre_id in counts:
		if not sorted.has(genre_id):
			sorted[genre_id] = counts[genre_id]  # Genre gibt es nicht mehr
	return sorted


func _changed() -> void:
	changed.emit()
	SaveManager.request_save()


func _carried_changed() -> void:
	carried_changed.emit()
	SaveManager.request_save()


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var stored := {}
	for genre_id in _stored:
		stored[genre_id] = Book.list_to_save_data(_stored[genre_id])
	return {
		"stored": stored,
		"carried": Book.list_to_save_data(carried),
		"unlocked_genres": _unlocked.duplicate(),
		"gifts_given": _gifts_given.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_stored.clear()
	var stored = data.get("stored")
	if stored is Dictionary:
		for genre_id in stored:
			_add_to_storage(Book.list_from_save_data(stored[genre_id]))
	carried = Book.list_from_save_data(data.get("carried"))
	_unlocked.clear()
	_gifts_given.clear()
	for key in ["unlocked_genres", "gifts_given"]:
		var target: Array[String] = _unlocked if key == "unlocked_genres" else _gifts_given
		var values = data.get(key)
		if values is Array:
			for value in values:
				target.append(str(value))
	changed.emit()
	carried_changed.emit()
