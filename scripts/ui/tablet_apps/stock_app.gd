extends TabletApp
## App "Bestand" auf dem Theken-Tablet: die Lagerübersicht.
##
## Je Genre eine Zeile: wie viele Bücher ich habe und wo sie sind – mit kleinen Symbolen und
## Zahlen statt Text (Kiste = im Lager, Regal = im Regal, liegendes Buch = ausgelegt,
## Pfeile = unterwegs, also in der Hand oder im Rückgabekasten).
## Bücher in die Hand nehmen: Mit − und + wählen, wie viele (1 bis 7, höchstens so viele, wie
## noch in die Hand passen und im Lager liegen), dann das Hand-Symbol. Oder das Genre aufklappen
## und einzelne Titel über ihre Cover nehmen. Das Tablet bleibt offen; die Zahl oben in der
## Leiste zeigt, wie viele Bücher ich trage. Sind die Hände voll, sind die Knöpfe ausgegraut,
## und ein Klick lässt nur das Stapel-Symbol sanft wackeln – ganz ohne Text.
## Funktioniert überall (auch ohne Regal in der Nähe), z. B. um Bücher auf der Theke auszulegen.

var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: HBoxContainer
## Je Genre: gewählte Anzahl zum Nehmen und ob die Titel aufgeklappt sind
var _amounts: Dictionary = {}
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


## Wie viele Bücher dieses Genres kann ich gerade höchstens nehmen?
func max_take(genre_id: String) -> int:
	return mini(BookStock.get_free_hand_space(), BookStock.get_stored_count(genre_id))


## Die gewählte Anzahl (immer zwischen 1 und dem, was gerade geht).
func get_amount(genre_id: String) -> int:
	return clampi(int(_amounts.get(genre_id, 1)), 1, maxi(max_take(genre_id), 1))


func change_amount(genre_id: String, change: int) -> void:
	_amounts[genre_id] = clampi(get_amount(genre_id) + change, 1, maxi(max_take(genre_id), 1))
	refresh()


## Nimmt die gewählte Anzahl Bücher dieses Genres aus dem Lager in die Hand. Liefert, wie
## viele es waren (0 = Hände voll oder nichts im Lager: dann wackelt es nur).
func take(genre_id: String, source: Control = null) -> int:
	var amount := mini(get_amount(genre_id), max_take(genre_id))
	if amount <= 0:
		if BookStock.is_hand_full():
			tablet.wobble(source)
		return 0
	var books := BookStock.take_books(genre_id, amount)
	var rest := BookStock.carry(books)
	BookStock.put_back_first(rest)
	return books.size() - rest.size()


## Nimmt genau diesen Titel aus dem Lager in die Hand.
func take_title(data: BookData) -> bool:
	if BookStock.is_hand_full():
		tablet.wobble()
		return false
	for book in BookStock.get_stored_books(data.genre_id):
		if book.data == data and BookStock.take_stored_book(book):
			BookStock.carry([book])
			return true
	return false


func toggle_titles(genre_id: String) -> void:
	_expanded[genre_id] = not _expanded.get(genre_id, false)
	refresh()


func refresh() -> void:
	var scroll := _scroll.scroll_vertical
	clear(_list)
	clear(_summary)
	var sums := [0, 0, 0, 0]
	for entry in BookStock.get_overview():
		_list.add_child(_create_genre_row(entry))
		var values := [entry.stored, entry.shelves, entry.loose, entry.elsewhere]
		for i in 4:
			sums[i] += values[i]
		if _expanded.get(entry.genre.get_id(), false):
			_list.add_child(_create_titles(entry.genre))
	# Oben: alles zusammen
	var title := make_label("Alle Bücher", 18, TabletFrame.MUTED_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary.add_child(title)
	_add_counts(_summary, sums, TabletFrame.KEY_COLOR)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = _controls_width()
	_summary.add_child(spacer)
	_scroll.set_deferred("scroll_vertical", scroll)


## Eine Zeile je Genre: Bücherstapel, Name, Symbole mit Zahlen, Anzahl wählen, nehmen, aufklappen.
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
	var name_label := make_label(genre.display_name, 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	_add_counts(row, [entry.stored, entry.shelves, entry.loose, entry.elsewhere], TabletFrame.TEXT_COLOR)

	# Anzahl wählen (− 3 +) und nehmen
	var controls := HBoxContainer.new()
	controls.name = "Take"
	controls.add_theme_constant_override("separation", 4)
	controls.custom_minimum_size.x = _controls_width()
	controls.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(controls)
	var possible := max_take(id)
	var hands_full := BookStock.is_hand_full()
	var minus := make_icon_button(TabletIconButton.Icon.MINUS, change_amount.bind(id, -1))
	minus.disabled = possible <= 1 or get_amount(id) <= 1
	controls.add_child(minus)
	var amount := make_label(str(get_amount(id)) if possible > 0 else "–", 18, TabletFrame.TEXT_COLOR)
	amount.name = "Amount"
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.custom_minimum_size.x = 24
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(amount)
	var plus := make_icon_button(TabletIconButton.Icon.PLUS, change_amount.bind(id, 1))
	plus.disabled = get_amount(id) >= possible
	controls.add_child(plus)
	var take_button := TabletIconButton.new()
	take_button.name = "TakeButton"
	take_button.icon_kind = TabletIconButton.Icon.TAKE
	take_button.pressed.connect(func() -> void: take(id, take_button))
	if hands_full:
		# Ausgegraut, aber klickbar: ein Klick lässt es nur sanft wackeln
		take_button.modulate.a = 0.4
	else:
		take_button.disabled = possible <= 0
	controls.add_child(take_button)
	var fold := make_icon_button(TabletIconButton.Icon.COLLAPSE if _expanded.get(id, false) else TabletIconButton.Icon.EXPAND,
		toggle_titles.bind(id))
	fold.disabled = entry.stored == 0 and not _expanded.get(id, false)
	controls.add_child(fold)
	return panel


## Aufgeklappt: die Titel dieses Genres im Lager als Cover-Kacheln (gleiche Titel zusammengefasst).
func _create_titles(genre: GenreData) -> Control:
	var counts := {}
	var titles: Array[BookData] = []
	for book in BookStock.get_stored_books(genre.get_id()):
		if not counts.has(book.data):
			titles.append(book.data)
		counts[book.data] = int(counts.get(book.data, 0)) + 1
	var entries := []
	for data in titles:
		entries.append({"data": data, "note": "×%d im Lager" % counts[data] if counts[data] > 1 else "im Lager"})
	var picker := BookPicker.new()
	picker.name = genre.get_id() + "_titles"
	picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picker.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker.book_chosen.connect(func(data: BookData) -> void: take_title(data))
	picker.show_entries(entries, "Im Lager liegt gerade nichts davon.")
	return picker


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


func _controls_width() -> float:
	return 4.0 * 34.0 + 46.0 + 24.0 + 5.0 * 4.0
