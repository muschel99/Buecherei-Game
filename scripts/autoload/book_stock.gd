extends Node
## Der Bücherbestand: alle Bücher, die mir gehören – getrennt vom Möbel-Inventar.
##
## Ein Buch-Exemplar (Book) ist immer an genau einem Ort:
## - im Lager (hier gespeichert, nach Genre sortiert),
## - in einem Regal (BookShelf, gespeichert mit dem Regal im Raum),
## - im Rückgabekasten (ReturnBox, ebenfalls mit dem Raum gespeichert),
## - ausgelegt: frei auf einem Tisch, der Theke, dem Boden … (LooseBooks, mit dem Raum gespeichert),
## - oder in meinen Händen (carried, hier gespeichert). Eins davon liegt obenauf und ist
##   "aktiv" – das lege ich mit der linken Maustaste einzeln ab, ins Regal oder frei in die
##   Welt (Mausrad wechselt). Ich trage höchstens GameConfig.max_carried_books Bücher.
## Außerdem merkt sich der Bestand
## - die Sammlung: welche Titel ich schon entdeckt habe (Bücherpakete bringen bevorzugt neue),
## - welche Genres freigeschaltet sind.
## Im Code: BookStock.get_stored_count("crime"), BookStock.add_new_books("crime", 10) …
## Der Bestand wird mit dem Spielstand gespeichert (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich das Lager (oder die Sammlung) ändert.
signal changed
## Wird gesendet, wenn sich ändert, was ich trage (oder welches Buch obenauf liegt).
signal carried_changed
## Wird gesendet, wenn ich noch ein Buch nehmen möchte, die Hände aber voll sind
## (der Stapel in der Hand wackelt dann kurz – ganz ohne Text).
signal hands_full

## Gruppen der Regale und Rückgabekästen im Raum (zum Zählen).
const SHELF_GROUP := "book_shelves"
const RETURN_BOX_GROUP := "return_boxes"
## Gruppe der Knoten mit ausgelegten Büchern (LooseBooks, einer je Raum).
const LOOSE_GROUP := "loose_book_layers"

## Name im Spielstand.
var save_key: String = "books"

## Bücher, die ich gerade trage (z. B. aus dem Rückgabekasten oder aus einem Regal).
var carried: Array[Book] = []
## Welches getragene Buch obenauf liegt (Nummer in carried).
var active_index: int = 0

var _stored: Dictionary = {}  # genre_id -> Array[Book]
## Entdeckte Titel (Sammlung): BookData.id -> true
var _discovered: Dictionary = {}
## Genres, die im Spiel freigeschaltet wurden (zusätzlich zu "Is Unlocked" im Datenblatt)
var _unlocked: Array[String] = []
## Startgeschenke, die schon verteilt wurden (ids aus GameConfig.start_furniture_gifts)
var _gifts_given: Array[String] = []


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	# Neues Spiel (oder Spielstand von vor den Büchern): ein paar Bücher zum Einräumen
	for genre in get_unlocked_genres():
		_add_to_storage(_create_books(genre.get_id(), GameConfig.start_books_per_genre))


## Testtaste F9 (siehe DebugKeys): legt GameConfig.debug_return_box_books Bücher in einen
## Rückgabekasten – Titel, die ich schon entdeckt habe (so verrät der Test keine neuen Titel
## der Sammlung).
func fill_return_box_for_testing() -> void:
	var boxes := get_tree().get_nodes_in_group(RETURN_BOX_GROUP)
	if boxes.is_empty():
		Notice.post(self, "Test (F9): erst einen Rückgabekasten aufstellen")
		return
	var titles: Array[BookData] = []
	for genre in get_unlocked_genres():
		titles.append_array(get_discovered_titles(genre.get_id()))
	if titles.is_empty():
		return
	var books: Array[Book] = []
	for i in GameConfig.debug_return_box_books:
		books.append(Book.create_from(titles.pick_random()))
	boxes.pick_random().add_books(books)


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


# --- Sammlung ---

## Habe ich diesen Titel schon entdeckt (irgendwann besessen)?
func is_discovered(book_id: String) -> bool:
	return _discovered.has(book_id)


## Merkt sich einen Titel als entdeckt. Liefert true, wenn er neu ist.
func mark_discovered(book_id: String) -> bool:
	if _discovered.has(book_id):
		return false
	_discovered[book_id] = true
	return true


## Wie viele Titel dieses Genres habe ich schon entdeckt?
func get_discovered_count(genre_id: String) -> int:
	return get_discovered_titles(genre_id).size()


## Die entdeckten Titel eines Genres (Reihenfolge wie in der Bücherliste).
func get_discovered_titles(genre_id: String) -> Array[BookData]:
	var result: Array[BookData] = []
	for data in Catalog.get_books_of_genre(genre_id):
		if _discovered.has(data.id):
			result.append(data)
	return result


## Wie viele Exemplare je Titel besitze ich (überall)? BookData.id -> Anzahl
func count_copies() -> Dictionary:
	var counts := {}
	for book in get_all_owned_books():
		counts[book.data.id] = int(counts.get(book.data.id, 0)) + 1
	return counts


## Alle Exemplare, die mir gehören: Lager, Regale, Rückgabekästen und Hände.
func get_all_owned_books() -> Array[Book]:
	var result: Array[Book] = []
	for books: Array in _stored.values():
		result.append_array(books)
	result.append_array(carried)
	for shelf in get_tree().get_nodes_in_group(SHELF_GROUP):
		result.append_array(shelf.get_books())
	for box in get_tree().get_nodes_in_group(RETURN_BOX_GROUP):
		result.append_array(box.get_books())
	for layer in get_tree().get_nodes_in_group(LOOSE_GROUP):
		result.append_array(layer.get_books())
	return result


## Titel für neue Bücher eines Genres: erst die, die ich noch nicht kenne (zufällig), dann
## die, von denen ich am wenigsten Exemplare habe. So bringt jedes Paket Überraschungen.
func _pick_titles(genre_id: String, amount: int) -> Array[BookData]:
	var result: Array[BookData] = []
	var all := Catalog.get_books_of_genre(genre_id)
	if all.is_empty():
		return result
	var fresh := all.filter(func(data: BookData) -> bool: return not _discovered.has(data.id))
	fresh.shuffle()
	for data: BookData in fresh:
		if result.size() >= amount:
			return result
		result.append(data)
	var copies := count_copies()
	for data in result:
		copies[data.id] = int(copies.get(data.id, 0)) + 1
	while result.size() < amount:
		var pool := all.duplicate()
		pool.shuffle()
		pool.sort_custom(func(a: BookData, b: BookData) -> bool:
			return int(copies.get(a.id, 0)) < int(copies.get(b.id, 0)))
		var data: BookData = pool[0]
		result.append(data)
		copies[data.id] = int(copies.get(data.id, 0)) + 1
	return result


## Für Spielstände von vor den echten Titeln: Ein altes Buch bekommt einen Titel aus der
## Bücherliste seines Genres (bevorzugt einen, den ich noch nicht habe).
func pick_title_for_old_book(genre_id: String) -> BookData:
	var titles := _pick_titles(genre_id, 1)
	return titles[0] if not titles.is_empty() else null


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


## Die Bücher eines Genres im Lager (nach Titel sortiert, z. B. für eine Auswahlliste).
func get_stored_books(genre_id: String) -> Array[Book]:
	var result: Array[Book] = []
	result.assign(_stored.get(genre_id, []))
	result.sort_custom(func(a: Book, b: Book) -> bool: return a.title.naturalnocasecmp_to(b.title) < 0)
	return result


## Erzeugt neue Bücher (z. B. aus einem Bücherpaket) und legt sie ins Lager.
## Neue Titel kommen in die Sammlung.
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


## Nimmt genau dieses Buch aus dem Lager (false, wenn es dort nicht liegt).
func take_stored_book(book: Book) -> bool:
	var books: Array = _stored.get(book.genre_id, [])
	if not books.has(book):
		return false
	books.erase(book)
	if books.is_empty():
		_stored.erase(book.genre_id)
	_changed()
	return true


## Bücher zurück an den Anfang des Lagers (wenn sie doch nicht ins Regal passen).
func put_back_first(books: Array) -> void:
	for i in range(books.size() - 1, -1, -1):
		var book: Book = books[i]
		if not _stored.has(book.genre_id):
			_stored[book.genre_id] = []
		_stored[book.genre_id].push_front(book)
	if not books.is_empty():
		_changed()


# --- Tragen ---

## Ich nehme Bücher in die Hand (z. B. aus dem Rückgabekasten). Das zuletzt genommene
## liegt obenauf. Es passen höchstens GameConfig.max_carried_books in die Hände: Liefert die
## Bücher, die nicht mehr passen (der Aufrufer behält sie).
func carry(books: Array) -> Array[Book]:
	var rest: Array[Book] = []
	var space := get_free_hand_space()
	for book: Book in books:
		if space > 0:
			carried.append(book)
			space -= 1
		else:
			rest.append(book)
	if rest.size() < books.size():
		active_index = carried.size() - 1
		_carried_changed()
	if not rest.is_empty():
		hands_full.emit()
	return rest


## Für wie viele Bücher habe ich noch Platz in den Händen?
func get_free_hand_space() -> int:
	return maxi(0, GameConfig.max_carried_books - carried.size())


## Sind die Hände voll? (Dann wackelt der Stapel kurz – siehe show_hands_full.)
func is_hand_full() -> bool:
	return get_free_hand_space() <= 0


## Zeigt (ohne Text), dass nichts mehr in die Hände passt: Der Stapel wackelt kurz.
func show_hands_full() -> void:
	hands_full.emit()


## Das Buch, das obenauf liegt (oder null, wenn ich nichts trage).
func get_active_book() -> Book:
	if carried.is_empty():
		return null
	active_index = clampi(active_index, 0, carried.size() - 1)
	return carried[active_index]


## Wechselt das Buch obenauf (Mausrad): direction +1 = nächstes, -1 = vorheriges.
func cycle_active(direction: int) -> void:
	if carried.size() < 2:
		return
	active_index = posmod(active_index + direction, carried.size())
	_carried_changed()


## Gibt das Buch obenauf ab (z. B. um es ins Regal zu stellen).
func take_active() -> Book:
	var book := get_active_book()
	if book:
		carried.remove_at(active_index)
		active_index = clampi(active_index, 0, maxi(carried.size() - 1, 0))
		_carried_changed()
	return book


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
		active_index = clampi(active_index, 0, maxi(carried.size() - 1, 0))
		_carried_changed()
	return result


## Gibt die getragenen Bücher ab, für die die Bedingung gilt (z. B. "passt in dieses Regal").
func take_carried_where(condition: Callable) -> Array[Book]:
	var result: Array[Book] = []
	var kept: Array[Book] = []
	for book in carried:
		if condition.call(book):
			result.append(book)
		else:
			kept.append(book)
	if not result.is_empty():
		carried = kept
		active_index = clampi(active_index, 0, maxi(carried.size() - 1, 0))
		_carried_changed()
	return result


## Legt Bücher zurück in die Hand, ohne das Buch obenauf zu wechseln
## (z. B. die, die doch nicht ins Regal gepasst haben).
func return_to_hand(books: Array) -> void:
	if books.is_empty():
		return
	var active := get_active_book()
	carried.append_array(books)
	active_index = carried.find(active) if active else carried.size() - 1
	_carried_changed()


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


## Legt alles Getragene ins Lager (mit einem kleinen Bücherstapel je Genre in der
## Lager-Anzeige unten rechts).
func store_carried() -> int:
	var books := carried.duplicate()
	if books.is_empty():
		return 0
	for genre_id in get_carried_counts():
		var genre := Catalog.get_genre(genre_id)
		if genre:
			StorageIndicator.add_item(self, genre)
	carried.clear()
	active_index = 0
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


## Wie viele Bücher dieses Genres liegen ausgelegt herum (Tische, Theke, Boden …)?
func count_loose(genre_id: String) -> int:
	var count := 0
	for layer in get_tree().get_nodes_in_group(LOOSE_GROUP):
		count += layer.count_books(genre_id)
	return count


## Übersicht je Genre für die Bestandsliste am Tablet: Liste von
## { "genre": GenreData, "shelves": …, "stored": …, "loose": …, "elsewhere": …, "total": …,
##   "discovered": …, "catalog": … }. "loose" = ausgelegt.
## "elsewhere" = getragen oder im Rückgabekasten; "discovered"/"catalog" = Sammlung
## (entdeckte Titel / Titel im Genre). Gesperrte Genres erscheinen nur, wenn ich davon
## Bücher habe.
func get_overview() -> Array[Dictionary]:
	var carried_counts := get_carried_counts()
	var result: Array[Dictionary] = []
	for genre in Catalog.get_all_genres():
		var id := genre.get_id()
		var shelves := count_in_shelves(id)
		var stored := get_stored_count(id)
		var elsewhere := int(carried_counts.get(id, 0)) + count_in_return_boxes(id)
		var loose := count_loose(id)
		var total := shelves + stored + loose + elsewhere
		if total > 0 or is_genre_unlocked(id):
			result.append({"genre": genre, "shelves": shelves, "stored": stored, "loose": loose, "elsewhere": elsewhere,
				"total": total, "discovered": get_discovered_count(id),
				"catalog": Catalog.get_books_of_genre(id).size()})
	return result


## Alle Bücher dieses Genres, die mir gehören (überall).
func count_total(genre_id: String) -> int:
	return get_stored_count(genre_id) + count_in_shelves(genre_id) + count_in_return_boxes(genre_id) \
		+ count_loose(genre_id) + int(get_carried_counts().get(genre_id, 0))


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

## Neue Exemplare eines Genres; ihre Titel kommen in die Sammlung.
func _create_books(genre_id: String, amount: int) -> Array[Book]:
	var books: Array[Book] = []
	for data in _pick_titles(genre_id, maxi(amount, 0)):
		mark_discovered(data.id)
		books.append(Book.create_from(data))
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
		"active_index": active_index,
		"discovered": _discovered.keys(),
		"unlocked_genres": _unlocked.duplicate(),
		"gifts_given": _gifts_given.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	# Erst die Sammlung, dann die Bücher (alte Bücher bekommen dabei passende neue Titel)
	_discovered.clear()
	var discovered = data.get("discovered")
	if discovered is Array:
		for id in discovered:
			_discovered[str(id)] = true
	_stored.clear()
	var stored = data.get("stored")
	if stored is Dictionary:
		for genre_id in stored:
			_add_to_storage(Book.list_from_save_data(stored[genre_id]))
	carried = Book.list_from_save_data(data.get("carried"))
	active_index = clampi(int(data.get("active_index", carried.size() - 1)), 0, maxi(carried.size() - 1, 0))
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
