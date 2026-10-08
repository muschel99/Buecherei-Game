extends TabletApp
## App "Sammlung" auf dem Theken-Tablet: alle Titel eines Genres mit Cover; unentdeckte als "?".
## Links die Genres mit Sammelstand. Unter jedem Titel steht, wo meine Exemplare sind. Ein
## Klick auf ein Buch, das im Lager liegt, legt es obenauf in die Hand (das Tablet bleibt
## offen; volle Hände: sanftes Wackeln, ganz ohne Text).

var _genre := ""
var _genre_list: VBoxContainer
var _header: Label
var _picker: BookPicker


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	var genre_scroll := ScrollContainer.new()
	genre_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	genre_scroll.custom_minimum_size.x = 250
	columns.add_child(genre_scroll)
	_genre_list = VBoxContainer.new()
	_genre_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_genre_list.add_theme_constant_override("separation", 6)
	genre_scroll.add_child(_genre_list)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	columns.add_child(column)
	_header = make_label("", 19)
	column.add_child(_header)
	_picker = BookPicker.new()
	_picker.book_chosen.connect(choose_book)
	column.add_child(_picker)


## Genres in der Sammlung: freigeschaltete und alle, von denen ich schon Titel kenne.
func get_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	for genre in Catalog.get_all_genres():
		if BookStock.is_genre_unlocked(genre.get_id()) or BookStock.get_discovered_count(genre.get_id()) > 0:
			result.append(genre)
	return result


func show_genre(id: String) -> void:
	_genre = id
	request_refresh()


func refresh() -> void:
	var genres := get_genres()
	if genres.is_empty():
		return
	var ids: Array = genres.map(func(genre: GenreData) -> String: return genre.get_id())
	if not ids.has(_genre):
		_genre = ids[0]
	# Genre-Knöpfe links mit Sammelstand
	clear(_genre_list)
	for genre in genres:
		var id := genre.get_id()
		var button := make_choice_button("%s  %d/%d" % [genre.display_name, BookStock.get_discovered_count(id),
			Catalog.get_books_of_genre(id).size()], show_genre.bind(id))
		button.set_pressed_no_signal(id == _genre)
		_genre_list.add_child(button)
	# Wo stehen meine Exemplare? Je Titel gezählt: insgesamt, im Lager, im Regal, ausgelegt
	var total := {}
	var stored := {}
	var shelved := {}
	var loose := {}
	for layer in get_tree().get_nodes_in_group(BookStock.LOOSE_GROUP):
		for book: Book in layer.get_books():
			loose[book.data.id] = int(loose.get(book.data.id, 0)) + 1
	for book in BookStock.get_all_owned_books():
		total[book.data.id] = int(total.get(book.data.id, 0)) + 1
	for book in BookStock.get_stored_books(_genre):
		stored[book.data.id] = int(stored.get(book.data.id, 0)) + 1
	for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		for book: Book in shelf.get_books():
			shelved[book.data.id] = int(shelved.get(book.data.id, 0)) + 1
	var entries := []
	for data in Catalog.get_books_of_genre(_genre):
		var known := BookStock.is_discovered(data.id)
		var in_storage := int(stored.get(data.id, 0))
		var on_shelf := int(shelved.get(data.id, 0))
		var laid_out := int(loose.get(data.id, 0))
		var elsewhere := int(total.get(data.id, 0)) - in_storage - on_shelf - laid_out
		var notes: Array[String] = []
		if in_storage > 0:
			notes.append("%d im Lager" % in_storage)
		if on_shelf > 0:
			notes.append("%d im Regal" % on_shelf)
		if laid_out > 0:
			notes.append("%d ausgelegt" % laid_out)
		if elsewhere > 0:
			notes.append("%d unterwegs" % elsewhere)
		if known and notes.is_empty():
			notes.append("gerade keins da")
		entries.append({"data": data, "known": known, "note": " · ".join(notes), "enabled": in_storage > 0})
	var genre := Catalog.get_genre(_genre)
	_header.text = "%s: %d von %d Titeln entdeckt" % [genre.display_name, BookStock.get_discovered_count(_genre), entries.size()]
	var scroll := _picker.scroll_vertical
	_picker.show_entries(entries)
	_picker.set_deferred("scroll_vertical", scroll)


## Ein Buch aus dem Lager obenauf in die Hand nehmen (das Tablet bleibt offen).
func choose_book(data: BookData) -> void:
	if BookStock.is_hand_full():
		tablet.wobble()
		return
	for book in BookStock.get_stored_books(data.genre_id):
		if book.data == data and BookStock.take_stored_book(book):
			BookStock.carry([book])
			return
