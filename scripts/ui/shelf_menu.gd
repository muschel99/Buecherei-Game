class_name ShelfMenu
extends CanvasLayer
## Das Regal-Menü (R) – als Tablet am rechten Bildrand (TabletFrame, wie das Tablet an der Theke).
## Seit Testrunde 7b deutlich schlichter (Wunsch der Entwicklerin: zu viele Knöpfe, man fand Bücher schwer, man sah nicht,
## was wo steht). Bücher aus dem Lager nimmt man jetzt aus den Bücherkisten hinter der Theke (GenreCrates), nicht mehr hier.
##
## Am Regal (open_for(regal)):
## - oben drei Symbol-Knöpfe: aus dem Lager auffüllen, sortieren (kleine Auswahl, wonach), alle Bücher zurück ins Lager;
## - darunter je Fach eine Zeile (Fach 1, Fach 2 … von oben links nach unten rechts): was darin steht (Zahl, Genres) und
##   EINE Auswahlliste für sein Genre („Automatisch“ = das Fach nimmt alles und erkennt sein Genre selbst, „Gemischt“ oder ein
##   Genre); ganz oben dieselbe Liste für alle Fächer zugleich.
## Ohne Regal im Blick (open_for(null)) – das Bücherverzeichnis: alle eigenen Bücher mit Suchfeld und Genre-Auswahl, zu
## jedem Buch, wo es gerade ist (Regal und Fach, Kiste hinter der Theke, Rückgabekasten, ausgelegt, in der Hand, verliehen).
## Getragene Bücher räumt man nicht hier ein (Linksklick halten am Regal) und legt sie hier auch nicht ins Lager (Q halten) –
## jede Aktion hat nur einen Weg. Fahre ich über die Auswahlliste eines Fachs, leuchtet es im Regal auf
## (BookShelf.highlight_rows); die Ansicht rückt beim Öffnen sanft zur Seite, sodass das Regal neben dem Tablet bleibt.
## Schließen: Kreuz oben rechts, Esc oder R (Esc-Regel über MenuStack). Solange es offen ist, ist der Mauszeiger sichtbar
## und die Spielfigur steht still.

const GROUP := "shelf_menu"
const TEXT_COLOR := TabletFrame.TEXT_COLOR
const MUTED_COLOR := TabletFrame.MUTED_COLOR
const KEY_COLOR := TabletFrame.KEY_COLOR
## Breite des Tablets (Bildpunkte bei 1600 x 900) und Abstand zum oberen/unteren Rand (Anteil der Bildhöhe)
const TABLET_WIDTH := 520.0
const SCREEN_MARGIN := 0.06
## Abstand zum rechten Bildrand (Anteil der Bildbreite)
const RIGHT_MARGIN := 0.02
## Eintrag „Automatisch“ in den Auswahllisten der Fächer
const AUTO := "__auto__"
## Höchstens so viele Bücher zeigt das Verzeichnis auf einmal (Suchfeld grenzt ein)
const FINDER_LIMIT := 250

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)

var is_open: bool = false
var shelf: BookShelf = null

var _panel: TabletFrame
var _title: Label
var _info: Label
var _carried_box: HBoxContainer
var _carried_icon: TextureRect
var _carried_label: Label
var _main_view: VBoxContainer
var _finder_view: VBoxContainer
var _fill_button: TabletIconButton
var _sort_button: TabletIconButton
var _return_button: TabletIconButton
var _sort_popup: PopupMenu
var _all_choice: OptionButton
var _rows_scroll: ScrollContainer
var _rows_box: VBoxContainer
var _row_choices: Dictionary = {}  # Fach (row) -> OptionButton
var _row_infos: Dictionary = {}  # Fach (row) -> Label (was darin steht)
var _search: LineEdit
var _finder_genre: OptionButton
var _finder_list: VBoxContainer
var _finder_count: Label
var _message: Label
var _opened_frame := -1
var _refresh_queued := false
var _row_style: StyleBoxFlat
var _dots: Dictionary = {}  # Farbe -> kleines Punkt-Bild für die Auswahllisten
# Hervorgehobene Fächer: unter der Maus bzw. deren Liste gerade aufgeklappt ist
var _hover_rows: Array[int] = []
var _open_rows: Array[int] = []
# Ansicht: ursprüngliches Blickfeld und die laufende Bewegung
var _base_fov := -1.0
var _view_tween: Tween
var _framed := false  # wurde die Ansicht diesmal zur Seite gedreht?


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	TabletSounds.watch(self)
	hide()
	BookStock.changed.connect(_queue_refresh)
	BookStock.carried_changed.connect(_queue_refresh)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = is_open and not get_tree().paused
	if not visible and _sort_popup.visible:
		_sort_popup.hide()


func _unhandled_input(event: InputEvent) -> void:
	# R schließt das Menü wieder (aber nicht derselbe Tastendruck, der es geöffnet hat; nicht beim Tippen im Suchfeld)
	if is_open and event.is_action_pressed("open_menu") and Engine.get_process_frames() != _opened_frame \
			and not get_tree().paused and not _search.has_focus():
		close()
		get_viewport().set_input_as_handled()


# --- Öffnen und Schließen ---

## Öffnet das Menü: vom Regal aufgerufen (R) mit diesem Regal, sonst von der Spielfigur mit null (Bücherverzeichnis).
func open_for(target: BookShelf) -> void:
	if is_open:
		return
	shelf = target
	is_open = true
	Audio.play("ui/tablet_open", -6.0, 1.05)
	_opened_frame = Engine.get_process_frames()
	if shelf:
		shelf.contents_changed.connect(_queue_refresh)
	MenuStack.open(self)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = ""
	_main_view.visible = shelf != null
	_finder_view.visible = shelf == null
	if shelf == null:
		_search.text = ""
		_fill_finder_genres()
	_rebuild_rows()
	_queue_refresh()
	if shelf:
		_frame_shelf()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	_sort_popup.hide()
	_search.release_focus()
	_hover_rows = []
	_open_rows = []
	if is_instance_valid(shelf):
		shelf.highlight_rows([])
		if shelf.contents_changed.is_connected(_queue_refresh):
			shelf.contents_changed.disconnect(_queue_refresh)
	shelf = null
	if _framed:
		_restore_view()
	_framed = false
	MenuStack.close(self)
	_player.movement_enabled = true
	_player.interaction_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Esc (über den MenuStack): Menü schließen.
func close_from_escape() -> void:
	close()


## Nach dem Pausenmenü: Mauszeiger wieder sichtbar.
func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Aktionen am Regal ---

## Auswahl „für alle Fächer“: Automatisch, Gemischt oder ein Genre.
func choose_all(value: String) -> void:
	if shelf == null or value.is_empty():
		return
	if value == AUTO:
		shelf.set_all_auto(true)
		_message.text = "Alle Fächer: automatisch."
	else:
		var returned := shelf.set_genre(value)
		_message.text = "Alle Fächer: %s." % BookShelf.genre_display_name(value)
		_add_returned_note(returned)
	_queue_refresh()


## Auswahl eines Fachs: Automatisch, Gemischt oder ein Genre.
func choose_row(row: int, value: String) -> void:
	if shelf == null or value.is_empty():
		return
	if value == AUTO:
		shelf.set_row_auto(row, true)
		_message.text = "%s: automatisch." % shelf.get_row_label(row)
	else:
		var returned := shelf.set_row_genre(row, value)
		_message.text = "%s: %s." % [shelf.get_row_label(row), BookShelf.genre_display_name(value)]
		_add_returned_note(returned)
	_queue_refresh()


func _add_returned_note(returned: int) -> void:
	if returned > 0:
		_message.text += " %d %s in die Kisten." % [returned, "Buch passte nicht und ging" if returned == 1 \
			else "Bücher passten nicht und gingen"]


func fill() -> void:
	if shelf == null:
		return
	var count := shelf.fill_from_storage()
	_message.text = "%d %s eingeräumt." % [count, "Buch" if count == 1 else "Bücher"] if count > 0 \
		else "Gerade passt nichts mehr hinein."
	_queue_refresh()


func return_all() -> void:
	if shelf == null:
		return
	var count := shelf.return_all_to_storage()
	_message.text = "%d %s zurück in die Kisten." % [count, "Buch" if count == 1 else "Bücher"]
	_queue_refresh()


## Sortieren (mode: siehe BookShelf.SORT_MODES; leer = zuletzt gewählte Art).
func sort_shelf(mode: String = "") -> void:
	if shelf == null:
		return
	shelf.sort_books(mode)
	for entry: Array in BookShelf.SORT_MODES:
		if entry[0] == shelf.sort_mode:
			_message.text = "%s sortiert." % entry[1]
	_queue_refresh()


## Öffnet die Sortier-Auswahl unter dem Filtersymbol.
func open_sort_popup() -> void:
	if shelf == null:
		return
	for i in _sort_popup.item_count:
		_sort_popup.set_item_checked(i, BookShelf.SORT_MODES[i][0] == shelf.sort_mode)
	var canvas_scale := _sort_button.get_global_transform_with_canvas().get_scale().y
	var below := _sort_button.get_screen_position() + Vector2(0.0, (_sort_button.size.y + 4.0) * canvas_scale)
	_sort_popup.reset_size()
	_sort_popup.popup(Rect2i(Vector2i(below), Vector2i.ZERO))


# --- Anzeige ---

func _queue_refresh() -> void:
	if _refresh_queued or not is_open:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_open:
		return
	if shelf != null and not is_instance_valid(shelf):
		shelf = null  # das Regal ist inzwischen weg: weiter mit dem Verzeichnis
		_main_view.visible = false
		_finder_view.visible = true
		_fill_finder_genres()
	_refresh_carried()
	_message.visible = not _message.text.is_empty()
	if shelf == null:
		_title.text = "Bücherverzeichnis"
		_info.text = "Wo steht welches Buch?"
		_refresh_finder()
		return
	_title.text = shelf.get_display_name()
	var count := shelf.get_books().size()
	_info.text = "%d %s · Platz für etwa %d" % [count, "Buch" if count == 1 else "Bücher", shelf.get_free_estimate()]
	# Symbol-Knöpfe: ausgegraut, wenn sie gerade nichts tun könnten (Tooltip sagt kurz, warum)
	var available := _available_in_storage()
	_fill_button.disabled = available == 0 or shelf.get_free_estimate() == 0
	_fill_button.tooltip_text = "Auffüllen – nichts Passendes in den Kisten" if available == 0 \
		else "Auffüllen (%d in den Kisten)" % available
	_sort_button.disabled = count < 2
	_sort_button.tooltip_text = TabletIconButton.DEFAULT_TIPS[TabletIconButton.Icon.SORT]
	_return_button.disabled = count == 0
	_return_button.tooltip_text = "Alle zurück in die Kisten"
	var genres := _genre_choices()
	var all_value := AUTO if shelf.is_all_auto() else (shelf.genre_id if shelf.has_genre() else "")
	_fill_choice(_all_choice, genres, all_value, "Verschieden")
	for r in _row_choices:
		_fill_choice(_row_choices[r], genres, AUTO if shelf.is_row_auto(r) else shelf.get_row_genre(r), "Noch kein Genre")
		(_row_infos[r] as Label).text = _row_summary(r)


## Was in einem Fach steht: „7 Bücher · Krimi 5, Roman 2“ bzw. „leer“.
func _row_summary(row: int) -> String:
	var counts := {}
	var total := 0
	for book in shelf.get_books():
		if shelf.get_book_row(book) == row:
			counts[book.genre_id] = int(counts.get(book.genre_id, 0)) + 1
			total += 1
	if total == 0:
		return "leer"
	var parts: Array[String] = []
	var ids := counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	for id: String in ids:
		parts.append("%s %d" % [BookShelf.genre_display_name(id), counts[id]])
	return "%d %s · %s" % [total, "Buch" if total == 1 else "Bücher", ", ".join(parts)]


## Oben rechts: wie viele Bücher ich trage (Stapel im Genre des Buchs obenauf).
func _refresh_carried() -> void:
	var carried := BookStock.carried.size()
	_carried_label.text = "%d / %d" % [carried, GameConfig.max_carried_books]
	var active := BookStock.get_active_book()
	var genres := Catalog.get_all_genres()
	var genre: GenreData = active.get_genre() if active else (genres[0] if not genres.is_empty() else null)
	_carried_icon.texture = BookIcons.get_stack_icon(genre) if genre else null
	_carried_box.modulate.a = 1.0 if carried > 0 else 0.45


## Je Fach eine Zeile (Lesereihenfolge): Name, was darin steht, eine Auswahlliste für sein Genre.
func _rebuild_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_choices.clear()
	_row_infos.clear()
	if shelf == null:
		return
	for r in shelf.get_fach_order():
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", _row_style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		line.add_child(box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		box.add_child(top)
		var label := TabletFrame.make_label(shelf.get_row_label(r), 17, TEXT_COLOR)
		label.custom_minimum_size.x = 80
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(label)
		var row := r
		var choice := _make_choice()
		choice.item_selected.connect(func(index: int) -> void: choose_row(row, str(choice.get_item_metadata(index))))
		_watch_choice(choice, [row])
		top.add_child(choice)
		_row_choices[r] = choice
		var info := TabletFrame.make_label("", 14, MUTED_COLOR)
		box.add_child(info)
		_row_infos[r] = info
		_rows_box.add_child(line)
	_rows_scroll.scroll_vertical = 0


## Füllt eine Auswahlliste: „Automatisch“, „Gemischt“ und die freigeschalteten Genres (+ das gewählte, falls gesperrt).
## Ist nichts davon gewählt (value leer): ein grauer Eintrag empty_text.
func _fill_choice(choice: OptionButton, genres: Array[GenreData], value: String, empty_text: String) -> void:
	if choice.get_popup().visible:
		return  # nicht umbauen, während die Liste aufgeklappt ist
	choice.clear()
	if value.is_empty():
		choice.add_item(empty_text)
		choice.set_item_metadata(0, "")
		choice.set_item_disabled(0, true)
	choice.add_icon_item(_dot(KEY_COLOR, true), "Automatisch")
	choice.set_item_metadata(choice.item_count - 1, AUTO)
	choice.add_icon_item(_dot(MUTED_COLOR, true), "Gemischt")
	choice.set_item_metadata(choice.item_count - 1, BookShelf.MIXED)
	for genre in genres:
		choice.add_icon_item(_dot(genre.get_main_color().lightened(0.35), false), genre.display_name)
		choice.set_item_metadata(choice.item_count - 1, genre.get_id())
	for i in choice.item_count:
		if str(choice.get_item_metadata(i)) == value:
			choice.select(i)


func _genre_choices() -> Array[GenreData]:
	var genres := BookStock.get_unlocked_genres()
	if shelf == null:
		return genres
	for r in shelf.get_row_count():
		var current := Catalog.get_genre(shelf.get_row_genre(r))
		if current and not genres.has(current):
			genres.append(current)  # gesperrtes Genre, das schon gewählt ist
	return genres


## Wie viele Bücher, die hierher passen, liegen in den Kisten (im Lager)?
func _available_in_storage() -> int:
	var genres := {}
	for r in shelf.get_row_count():
		var id := shelf.get_row_genre(r)
		if id == BookShelf.MIXED and shelf.is_row_auto(r):
			for present in shelf.genres_in_row(r):
				genres[present] = true  # gemischtes Auto-Fach: nur Genres, die schon darin stehen
		elif id == BookShelf.MIXED or (id.is_empty() and shelf.is_row_auto(r)):
			return BookStock.get_stored_total()
		elif not id.is_empty():
			genres[id] = true
	var count := 0
	for id in genres:
		count += BookStock.get_stored_count(id)
	return count


# --- Bücherverzeichnis (ohne Regal) ---

func _fill_finder_genres() -> void:
	_finder_genre.clear()
	_finder_genre.add_item("Alle Genres")
	_finder_genre.set_item_metadata(0, "")
	for genre in Catalog.get_all_genres():
		_finder_genre.add_icon_item(_dot(genre.get_main_color().lightened(0.35), false), genre.display_name)
		_finder_genre.set_item_metadata(_finder_genre.item_count - 1, genre.get_id())
	_finder_genre.select(0)


## Alle eigenen Bücher mit ihrem Ort (Suchtext im Titel, Genre-Auswahl), sortiert nach Genre und Titel.
func _refresh_finder() -> void:
	for child in _finder_list.get_children():
		_finder_list.remove_child(child)
		child.queue_free()
	var query := _search.text.strip_edges().to_lower()
	var genre_id := str(_finder_genre.get_item_metadata(_finder_genre.selected)) if _finder_genre.selected >= 0 else ""
	var entries: Array[Dictionary] = []
	for entry: Dictionary in collect_book_places():
		var book: Book = entry.book
		if not genre_id.is_empty() and book.genre_id != genre_id:
			continue
		if not query.is_empty() and not book.title.to_lower().contains(query):
			continue
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ga := (a.book as Book).genre_id
		var gb := (b.book as Book).genre_id
		if ga != gb:
			return BookShelf.genre_display_name(ga) < BookShelf.genre_display_name(gb)
		return (a.book as Book).title.naturalnocasecmp_to((b.book as Book).title) < 0)
	_finder_count.text = "%d %s" % [entries.size(), "Buch" if entries.size() == 1 else "Bücher"]
	for i in mini(entries.size(), FINDER_LIMIT):
		var entry: Dictionary = entries[i]
		var book: Book = entry.book
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var dot := TextureRect.new()
		var genre := book.get_genre()
		dot.texture = _dot(genre.get_main_color().lightened(0.35) if genre else MUTED_COLOR, false)
		dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		dot.custom_minimum_size = Vector2(14, 22)
		line.add_child(dot)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		line.add_child(texts)
		texts.add_child(TabletFrame.make_label(book.title, 16, TEXT_COLOR))
		texts.add_child(TabletFrame.make_label(String(entry.place), 13, MUTED_COLOR))
		_finder_list.add_child(line)
	if entries.size() > FINDER_LIMIT:
		_finder_list.add_child(TabletFrame.make_label("… und %d weitere – das Suchfeld grenzt ein." % (entries.size() - FINDER_LIMIT),
			14, MUTED_COLOR))


## Alle eigenen Bücher mit Ort (auch für spätere Apps): [{book, place}].
func collect_book_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		var s := node as BookShelf
		if s == null:
			continue
		for book in s.get_books():
			result.append({"book": book, "place": "%s · %s" % [s.get_display_name(), s.get_row_label(s.get_book_row(book))]})
	for genre in Catalog.get_all_genres():
		for book in BookStock.get_stored_books(genre.get_id()):
			result.append({"book": book, "place": "Kiste hinter der Theke"})
	var box := ReturnBox.find(get_tree())
	if box:
		for book in box.get_books():
			result.append({"book": book, "place": "Rückgabekasten"})
	for node in get_tree().get_nodes_in_group(LooseBooks.GROUP):
		for entry in (node as LooseBooks).get_entries():
			result.append({"book": entry.book, "place": "ausgelegt"})
	for book in BookStock.carried:
		result.append({"book": book, "place": "in der Hand"})
	for loan in Lending.loans:
		for book: Book in loan.books:
			result.append({"book": book, "place": "verliehen (zurück an Tag %d)" % int(loan.day)})
	return result


# --- Aufbau ---

## Baut das Tablet aus Containern (passt sich jeder Auflösung an).
func _build() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_row_style = TabletFrame.make_panel_style(TabletFrame.PANEL_COLOR, 9, 6.0)
	_row_style.content_margin_left = 12.0
	_panel = TabletFrame.new()
	_panel.name = "Tablet"
	_panel.anchor_left = 1.0 - RIGHT_MARGIN
	_panel.anchor_right = 1.0 - RIGHT_MARGIN
	_panel.anchor_top = SCREEN_MARGIN
	_panel.anchor_bottom = 1.0 - SCREEN_MARGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size.x = TABLET_WIDTH
	add_child(_panel)
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 12)
	_panel.add_child(screen)
	# Kopf: Name, kurze Info, getragene Bücher, Kreuz
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	screen.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	_title = TabletFrame.make_label("", 24, TEXT_COLOR)
	titles.add_child(_title)
	_info = TabletFrame.make_label("", 15, MUTED_COLOR)
	titles.add_child(_info)
	_carried_box = HBoxContainer.new()
	_carried_box.name = "Carried"
	_carried_box.add_theme_constant_override("separation", 6)
	_carried_box.tooltip_text = "In der Hand"
	_carried_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_carried_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(_carried_box)
	_carried_icon = TextureRect.new()
	_carried_icon.custom_minimum_size = Vector2(28, 28)
	_carried_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carried_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_carried_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carried_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carried_box.add_child(_carried_icon)
	_carried_label = TabletFrame.make_label("", 16, MUTED_COLOR)
	_carried_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_carried_label.custom_minimum_size.x = 0
	_carried_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_carried_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carried_box.add_child(_carried_label)
	var close_button := TabletFrame.make_close_button()
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_build_main(screen)
	_build_finder(screen)
	_message = TabletFrame.make_label("", 16, KEY_COLOR)
	screen.add_child(_message)


func _build_main(screen: VBoxContainer) -> void:
	_main_view = VBoxContainer.new()
	_main_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_view.add_theme_constant_override("separation", 12)
	screen.add_child(_main_view)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	_main_view.add_child(toolbar)
	_fill_button = _icon_button(TabletIconButton.Icon.FILL, fill)
	toolbar.add_child(_fill_button)
	_sort_button = _icon_button(TabletIconButton.Icon.SORT, open_sort_popup)
	toolbar.add_child(_sort_button)
	_return_button = _icon_button(TabletIconButton.Icon.STORE, return_all)
	toolbar.add_child(_return_button)
	_sort_popup = PopupMenu.new()
	_sort_popup.name = "SortChoice"
	_sort_popup.add_theme_font_size_override("font_size", 17)
	for i in BookShelf.SORT_MODES.size():
		_sort_popup.add_radio_check_item(BookShelf.SORT_MODES[i][1], i)
	_sort_popup.id_pressed.connect(func(id: int) -> void: sort_shelf(BookShelf.SORT_MODES[id][0]))
	add_child(_sort_popup)
	_main_view.add_child(TabletFrame.make_label("Fächer", 18, KEY_COLOR))
	var all_line := HBoxContainer.new()
	all_line.add_theme_constant_override("separation", 12)
	_main_view.add_child(all_line)
	var all_label := TabletFrame.make_label("Alle Fächer", 17, TEXT_COLOR)
	all_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	all_label.custom_minimum_size.x = 92
	all_line.add_child(all_label)
	_all_choice = _make_choice()
	_all_choice.item_selected.connect(func(index: int) -> void: choose_all(str(_all_choice.get_item_metadata(index))))
	_watch_choice(_all_choice, [])  # leer = alle Fächer
	all_line.add_child(_all_choice)
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_view.add_child(_rows_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_scroll.add_child(_rows_box)


## Bücherverzeichnis: Suchfeld, Genre-Auswahl, Liste (scrollt).
func _build_finder(screen: VBoxContainer) -> void:
	_finder_view = VBoxContainer.new()
	_finder_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_finder_view.add_theme_constant_override("separation", 10)
	_finder_view.hide()
	screen.add_child(_finder_view)
	_search = LineEdit.new()
	_search.placeholder_text = "Titel suchen …"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 17)
	_search.text_changed.connect(func(_text: String) -> void: _queue_refresh())
	_finder_view.add_child(_search)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	_finder_view.add_child(line)
	_finder_genre = _make_choice()
	_finder_genre.item_selected.connect(func(_index: int) -> void: _queue_refresh())
	line.add_child(_finder_genre)
	_finder_count = TabletFrame.make_label("", 15, MUTED_COLOR)
	_finder_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_finder_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_finder_count)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_finder_view.add_child(scroll)
	_finder_list = VBoxContainer.new()
	_finder_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finder_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_finder_list)


# --- Fach hervorheben ---

## Maus über der Auswahlliste oder Liste aufgeklappt: diese Fächer hervorheben
## (rows leer = alle Fächer, für „Alle Fächer“).
func _watch_choice(choice: OptionButton, rows: Array[int]) -> void:
	_watch_hover(choice, rows)
	choice.get_popup().about_to_popup.connect(func() -> void:
		_open_rows = _rows_or_all(rows)
		_update_highlight())
	choice.get_popup().popup_hide.connect(func() -> void:
		_open_rows = []
		_update_highlight())


## Maus über einem Bedienelement eines Fachs (Auswahlliste, Tickbox "Auto"): Fach hervorheben.
func _watch_hover(control: Control, rows: Array[int]) -> void:
	control.mouse_entered.connect(func() -> void:
		_hover_rows = _rows_or_all(rows)
		_update_highlight())
	control.mouse_exited.connect(func() -> void:
		_hover_rows = []
		_update_highlight())


func _rows_or_all(rows: Array[int]) -> Array[int]:
	if not rows.is_empty() or shelf == null:
		return rows.duplicate()
	return shelf.get_fach_order()


func _update_highlight() -> void:
	if is_open and is_instance_valid(shelf):
		shelf.highlight_rows(_open_rows if not _open_rows.is_empty() else _hover_rows)


# --- Ansicht: das Regal bleibt neben dem Tablet sichtbar ---

## Dreht die Ansicht sanft ein Stück nach rechts, sodass das Regal links neben dem Tablet zu
## sehen ist. Ist es dafür zu breit (oder stehe ich sehr nah davor), zoomt die Ansicht etwas
## heraus (höchstens bis GameConfig.shelf_menu_max_fov). Die Kamera bleibt an ihrem Platz
## (nur gedreht – so schaut man nie durch eine Wand), die Spielfigur bewegt sich nicht.
func _frame_shelf() -> void:
	var camera := _player.camera
	# Gleitet die Ansicht gerade noch zurück, gilt weiter das gemerkte Blickfeld
	var restoring := _view_tween != null and _view_tween.is_running()
	if _view_tween:
		_view_tween.kill()
	if _base_fov < 0.0 or not restoring:
		_base_fov = camera.fov
	camera.fov = _base_fov
	camera.rotation.y = 0.0
	_framed = true
	var item := FurnitureUtils.find_placed_furniture(shelf)
	var model := item.get_model() if item else null
	if model == null:
		return
	var view := get_viewport().get_visible_rect().size
	var margin := view.x * 0.03
	var avail_left := margin
	var avail_right := view.x * (1.0 - RIGHT_MARGIN) - maxf(TABLET_WIDTH, _panel.size.x) - margin
	# Wo das Regal gerade im Bild ist (Ecken seines Modells, in Bildpunkten)
	var box := FurnitureUtils.get_local_aabb(model)
	var left := INF
	var right := -INF
	for i in 8:
		var corner := model.global_transform * box.get_endpoint(i)
		if camera.is_position_behind(corner):
			continue
		var x := camera.unproject_position(corner).x
		left = minf(left, x)
		right = maxf(right, x)
	if left == INF or right <= avail_right:
		return  # das Regal ist schon frei (oder gar nicht zu sehen)
	# Mit Winkeln rechnen (die Kamera dreht sich nur, dann bleiben die Winkel genau):
	# Winkel der beiden Regalränder zur Blickrichtung (rechts = positiv)
	var center := view.x / 2.0
	var aspect := view.x / view.y
	var base_tan := tan(deg_to_rad(_base_fov) / 2.0)
	var angle_left := atan((left - center) / center * base_tan * aspect)
	var angle_right := atan((right - center) / center * base_tan * aspect)
	# Zu breit für den freien Platz? Dann so wenig wie nötig herauszoomen (schrittweise suchen)
	var max_tan := tan(deg_to_rad(GameConfig.shelf_menu_max_fov) / 2.0)
	var new_half_tan := base_tan
	for i in 40:
		if _screen_angle(avail_right, center, new_half_tan * aspect) - _screen_angle(avail_left, center, new_half_tan * aspect) \
				>= angle_right - angle_left or new_half_tan >= max_tan:
			break
		new_half_tan = minf(new_half_tan * 1.02, max_tan)
	# So weit nach rechts drehen, dass der rechte Rand neben dem Tablet liegt (links nicht hinaus)
	var turn := maxf(angle_right - _screen_angle(avail_right, center, new_half_tan * aspect), 0.0)
	turn = minf(turn, maxf(angle_left - _screen_angle(avail_left, center, new_half_tan * aspect), 0.0))
	var new_fov := rad_to_deg(2.0 * atan(new_half_tan))
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(camera, "fov", new_fov, GameConfig.shelf_menu_view_time)
	_view_tween.tween_property(camera, "rotation:y", -turn, GameConfig.shelf_menu_view_time)


## Winkel (zur Blickrichtung) einer Stelle x im Bild bei diesem Blickfeld (half_tan_x = tan der
## halben Bildbreite).
static func _screen_angle(x: float, center: float, half_tan_x: float) -> float:
	return atan((x - center) / center * half_tan_x)


## Beim Schließen gleitet die Ansicht zurück.
func _restore_view() -> void:
	if _base_fov < 0.0:
		return
	var camera := _player.camera
	if _view_tween:
		_view_tween.kill()
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(camera, "fov", _base_fov, GameConfig.shelf_menu_view_time)
	_view_tween.tween_property(camera, "rotation:y", 0.0, GameConfig.shelf_menu_view_time)


func _icon_button(kind: TabletIconButton.Icon, action: Callable) -> TabletIconButton:
	var button := TabletIconButton.new()
	button.icon_kind = kind
	button.pressed.connect(action)
	return button


func _make_choice() -> OptionButton:
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.fit_to_longest_item = false
	# Auch dasselbe Genre noch einmal wählen zählt (legt ein Auto-Fach auf dieses Genre fest)
	choice.allow_reselect = true
	choice.add_theme_font_size_override("font_size", 17)
	choice.get_popup().add_theme_font_size_override("font_size", 17)
	return choice


## Kleiner farbiger Punkt für die Auswahllisten (half = halb gefüllt, für "Gemischt").
func _dot(color: Color, half: bool) -> Texture2D:
	var key := "%s/%s" % [color.to_html(), half]
	if _dots.has(key):
		return _dots[key]
	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			var d := Vector2(x + 0.5 - 7.0, y + 0.5 - 7.0).length()
			var alpha := clampf(5.5 - d, 0.0, 1.0)
			if half and x >= 7 and d < 4.5:
				alpha *= 0.25  # rechte Hälfte nur angedeutet
			image.set_pixel(x, y, Color(color, color.a * alpha))
	var texture := ImageTexture.create_from_image(image)
	_dots[key] = texture
	return texture
