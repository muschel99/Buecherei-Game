extends TabletApp
## App "Lager" auf dem Theken-Tablet: die Übersicht über alle meine Bücher – mit der Sammlung.
##
## Je Genre eine Zeile: wie viele Bücher ich habe und wo sie sind – mit kleinen Symbolen und
## Zahlen statt Text (Kiste = im Lager, Regal = im Regal, liegendes Buch = ausgelegt,
## Pfeile = unterwegs, also in der Hand oder im Rückgabekasten). Unter dem Namen steht klein,
## wie viele Titel des Genres ich schon entdeckt habe.
## Klappe ich ein Genre auf (Pfeil), sehe ich seine Sammlung: alle Titel als Cover-Kacheln,
## unentdeckte als "?", darunter klein, wo meine Exemplare gerade sind.
## Nur zum Schauen: Bücher in die Hand nehmen geht über das R-Menü (ShelfMenu), nicht hier.

var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: HBoxContainer
## Je Genre: ob die Sammlung aufgeklappt ist
var _expanded: Dictionary = {}


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_summary = HBoxContainer.new()
	_summary.add_theme_constant_override("separation", 10)
	box.add_child(_summary)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)


func toggle_collection(genre_id: String) -> void:
	_expanded[genre_id] = not _expanded.get(genre_id, false)
	request_refresh()


func is_expanded(genre_id: String) -> bool:
	return _expanded.get(genre_id, false)


func refresh() -> void:
	var scroll := _scroll.scroll_vertical
	clear(_list)
	clear(_summary)
	var sums := [0, 0, 0, 0]
	var places := {}
	for entry in BookStock.get_overview():
		_list.add_child(_create_genre_row(entry))
		var values := [entry.stored, entry.shelves, entry.loose, entry.elsewhere]
		for i in 4:
			sums[i] += values[i]
		if is_expanded(entry.genre.get_id()):
			if places.is_empty():
				places = _count_places()
			_list.add_child(_create_collection(entry.genre, places))
	# Oben: alles zusammen
	var title := make_label("Alle Bücher", 18, TabletFrame.MUTED_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary.add_child(title)
	_add_counts(_summary, sums, TabletFrame.KEY_COLOR)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = _fold_width()
	_summary.add_child(spacer)
	_scroll.set_deferred("scroll_vertical", scroll)


## Eine Zeile je Genre: Bücherstapel, Name (mit Sammelstand), Symbole mit Zahlen, aufklappen.
func _create_genre_row(entry: Dictionary) -> Control:
	var genre: GenreData = entry.genre
	var id := genre.get_id()
	var panel := make_panel(8.0)
	panel.name = id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = BookIcons.get_stack_icon(genre)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	names.add_child(make_label(genre.display_name, 18))
	var found := make_label("%d von %d Titeln entdeckt" % [entry.discovered, entry.catalog], 13, TabletFrame.MUTED_COLOR)
	found.name = "Discovered"
	names.add_child(found)
	_add_counts(row, [entry.stored, entry.shelves, entry.loose, entry.elsewhere], TabletFrame.TEXT_COLOR)
	var fold := make_icon_button(TabletIconButton.Icon.COLLAPSE if is_expanded(id) else TabletIconButton.Icon.EXPAND,
		toggle_collection.bind(id))
	fold.name = "Fold"
	fold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fold)
	return panel


## Aufgeklappt: die Sammlung des Genres – alle Titel als Cover-Kacheln, unentdeckte als "?".
func _create_collection(genre: GenreData, places: Dictionary) -> Control:
	var entries := []
	for data in Catalog.get_books_of_genre(genre.get_id()):
		var known := BookStock.is_discovered(data.id)
		var notes: Array[String] = []
		for place: Array in [["stored", "im Lager"], ["shelves", "im Regal"], ["loose", "ausgelegt"], ["elsewhere", "unterwegs"]]:
			var count := int(places[place[0]].get(data.id, 0))
			if count > 0:
				notes.append("%d %s" % [count, place[1]])
		if known and notes.is_empty():
			notes.append("gerade keins da")
		entries.append({"data": data, "known": known, "note": " · ".join(notes)})
	var picker := BookPicker.new()
	picker.name = genre.get_id() + "_collection"
	picker.interactive = false
	picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picker.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker.show_entries(entries, "Zu diesem Genre gibt es noch keine Titel.")
	return picker


## Wo meine Exemplare sind, je Titel gezählt: {"stored": {id: n}, "shelves": …, "loose": …,
## "elsewhere": …} (unterwegs = alles, was nicht im Lager, im Regal oder ausgelegt ist).
func _count_places() -> Dictionary:
	var result := {"stored": {}, "shelves": {}, "loose": {}, "elsewhere": {}}
	var total := {}
	for book in BookStock.get_all_owned_books():
		total[book.data.id] = int(total.get(book.data.id, 0)) + 1
	for genre in Catalog.get_all_genres():
		for book in BookStock.get_stored_books(genre.get_id()):
			_add(result.stored, book)
	for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		for book: Book in shelf.get_books():
			_add(result.shelves, book)
	for layer in get_tree().get_nodes_in_group(BookStock.LOOSE_GROUP):
		for book: Book in layer.get_books():
			_add(result.loose, book)
	for id in total:
		var away := int(total[id]) - int(result.stored.get(id, 0)) - int(result.shelves.get(id, 0)) \
			- int(result.loose.get(id, 0))
		if away > 0:
			result.elsewhere[id] = away
	return result


static func _add(counts: Dictionary, book: Book) -> void:
	counts[book.data.id] = int(counts.get(book.data.id, 0)) + 1


## Die vier Symbole mit Zahlen (Lager, Regal, ausgelegt, unterwegs).
func _add_counts(row: HBoxContainer, values: Array, color: Color) -> void:
	var kinds := [StockSymbol.Kind.STORAGE, StockSymbol.Kind.SHELF, StockSymbol.Kind.LOOSE, StockSymbol.Kind.AWAY]
	for i in 4:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size.x = 74
		cell.add_theme_constant_override("separation", 4)
		cell.tooltip_text = StockSymbol.TIPS[kinds[i]]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var symbol := StockSymbol.create(kinds[i])
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(symbol)
		var number := make_label(str(values[i]), 18, color if int(values[i]) > 0 else TabletFrame.MUTED_COLOR)
		number.autowrap_mode = TextServer.AUTOWRAP_OFF
		number.custom_minimum_size.x = 36
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(number)
		row.add_child(cell)


## Breite des Aufklapp-Knopfs (damit die Summen oben über den Zahlen stehen).
func _fold_width() -> float:
	return 34.0 + 10.0 + 8.0
