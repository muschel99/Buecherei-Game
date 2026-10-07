class_name ShelfMenu
extends CanvasLayer
## Das Regal-Menü (R an einem Bücherregal) – als Tablet am rechten Bildrand (TabletFrame, wie
## das Tablet an der Theke).
##
## Bewusst schlicht, wenige klare Aktionen:
## - Oben eine Leiste mit Symbol-Knöpfen (Tooltip beim Darüberfahren): Buch aus dem Lager
##   wählen, aus dem Lager auffüllen, sortieren (Filtersymbol: kleine Auswahl, wonach) und alle
##   Bücher zurück ins Lager.
## - Darunter "Fächer": "Alle Fächer gleich" und jedes Fach (Fach 1, Fach 2 … von oben links
##   nach unten rechts) mit einer Auswahlliste für sein Genre oder "Gemischt".
## - "Buch aus dem Lager wählen" zeigt die Cover der passenden Bücher im Lager auf dem Tablet –
##   ein Klick legt das Buch obenauf in die Hand, dann stellt man es mit der linken Maustaste an
##   genau die Stelle, die man möchte.
## Getragene Bücher räumt man nicht hier ein (Linksklick halten am Regal) und legt sie hier auch
## nicht ins Lager (Q halten) – jede Aktion hat nur einen Weg.
## Das Tablet ist immer gleich groß (fast so hoch wie das Bild) und passt so bei jeder Auflösung;
## wird die Fächerliste zu lang, lässt sie sich scrollen.
## Fahre ich über die Auswahlliste eines Fachs oder klappe sie auf, leuchtet genau dieses Fach im
## Regal dezent auf (BookShelf.highlight_rows). Damit ich das sehe, rückt die Ansicht beim Öffnen
## sanft zur Seite (und zoomt bei Bedarf etwas heraus), sodass das Regal neben dem Tablet bleibt.
## Schließen: Kreuz oben rechts, Esc oder R (Esc-Regel über MenuStack). Solange es offen ist,
## ist der Mauszeiger sichtbar und die Spielfigur steht still.

const GROUP := "shelf_menu"
const TEXT_COLOR := TabletFrame.TEXT_COLOR
const MUTED_COLOR := TabletFrame.MUTED_COLOR
const KEY_COLOR := TabletFrame.KEY_COLOR
## Breite des Tablets und Abstand zum oberen/unteren Bildrand (Anteil der Bildhöhe)
const TABLET_WIDTH := 520.0
const SCREEN_MARGIN := 0.06
## Abstand des Tablets zum rechten Bildrand (Anteil der Bildbreite)
const RIGHT_MARGIN := 0.02

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)

var is_open: bool = false
var shelf: BookShelf = null

var _panel: TabletFrame
var _title: Label
var _info: Label
var _main_view: VBoxContainer
var _picker_view: VBoxContainer
var _pick_button: TabletIconButton
var _fill_button: TabletIconButton
var _sort_button: TabletIconButton
var _return_button: TabletIconButton
var _sort_popup: PopupMenu
var _all_choice: OptionButton
var _rows_scroll: ScrollContainer
var _rows_box: VBoxContainer
var _row_choices: Dictionary = {}  # Fach (row) -> OptionButton
var _picker_title: Label
var _picker_genre_choice: OptionButton
var _picker: BookPicker
var _picker_genre := ""
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


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	hide()
	BookStock.changed.connect(_queue_refresh)
	BookStock.carried_changed.connect(_queue_refresh)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = is_open and not get_tree().paused
	if not visible and _sort_popup.visible:
		_sort_popup.hide()


func _unhandled_input(event: InputEvent) -> void:
	# R schließt das Menü wieder (aber nicht derselbe Tastendruck, der es geöffnet hat)
	if is_open and event.is_action_pressed("open_menu") and Engine.get_process_frames() != _opened_frame \
			and not get_tree().paused:
		close()
		get_viewport().set_input_as_handled()


# --- Öffnen und Schließen ---

## Wird vom Regal aufgerufen (R).
func open_for(target: BookShelf) -> void:
	if is_open:
		return
	shelf = target
	is_open = true
	_opened_frame = Engine.get_process_frames()
	shelf.contents_changed.connect(_queue_refresh)
	MenuStack.open(self)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = ""
	_show_main()
	_rebuild_rows()
	_queue_refresh()
	_frame_shelf()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	_sort_popup.hide()
	_hover_rows.clear()
	_open_rows.clear()
	if is_instance_valid(shelf):
		shelf.highlight_rows([])
		if shelf.contents_changed.is_connected(_queue_refresh):
			shelf.contents_changed.disconnect(_queue_refresh)
	shelf = null
	_restore_view()
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


# --- Aktionen ---

## "Alle Fächer gleich": ein Genre für das ganze Regal.
func choose_genre(genre_id: String) -> void:
	if shelf == null or genre_id.is_empty():
		return
	var returned := shelf.set_genre(genre_id)
	_message.text = "Alle Fächer: %s." % BookShelf.genre_display_name(genre_id)
	_add_returned_note(returned)
	_queue_refresh()


## Genre eines einzelnen Fachs.
func choose_row_genre(row: int, genre_id: String) -> void:
	if shelf == null or genre_id == shelf.get_row_genre(row):
		return
	var returned := shelf.set_row_genre(row, genre_id)
	_message.text = "%s: %s." % [shelf.get_row_label(row), BookShelf.genre_display_name(genre_id)]
	_add_returned_note(returned)
	_queue_refresh()


func _add_returned_note(returned: int) -> void:
	if returned > 0:
		_message.text += " %d %s ins Lager." % [returned, "Buch passte nicht und ging" if returned == 1 \
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
	_message.text = "%d %s zurück ins Lager." % [count, "Buch" if count == 1 else "Bücher"]
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
	# Direkt unter dem Knopf (so rechnet Godot es auch bei seinen Auswahllisten)
	var scale := _sort_button.get_global_transform_with_canvas().get_scale().y
	var below := _sort_button.get_screen_position() + Vector2(0.0, (_sort_button.size.y + 4.0) * scale)
	_sort_popup.reset_size()
	_sort_popup.popup(Rect2i(Vector2i(below), Vector2i.ZERO))


## Zeigt die Auswahl "Buch aus dem Lager wählen" auf dem Tablet.
func open_picker() -> void:
	_picker_genre = ""
	_main_view.hide()
	_picker_view.show()
	_refresh_picker()


func _show_main() -> void:
	_picker_view.hide()
	_main_view.show()


## Ein Buch aus dem Lager obenauf in die Hand nehmen – dann kann ich es mit der linken
## Maustaste genau dort abstellen, wo ich hinschaue.
func choose_book(data: BookData) -> void:
	if BookStock.is_hand_full():
		_message.text = "Deine Hände sind voll."
		BookStock.show_hands_full()
		return
	for book in BookStock.get_stored_books(data.genre_id):
		if book.data == data and BookStock.take_stored_book(book):
			BookStock.carry([book])
			close()
			return


# --- Anzeige ---

func _queue_refresh() -> void:
	if _refresh_queued or not is_open:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_open or not is_instance_valid(shelf):
		return
	_title.text = shelf.get_display_name()
	var count := shelf.get_books().size()
	_info.text = "%d %s · Platz für etwa %d" % [count, "Buch" if count == 1 else "Bücher", shelf.get_free_estimate()]

	# Symbol-Knöpfe: ausgegraut, wenn sie gerade nichts tun könnten (Tooltip sagt kurz, warum)
	var available := _available_in_storage()
	_fill_button.disabled = not shelf.has_genre() or available == 0 or shelf.get_free_estimate() == 0
	if not shelf.has_genre():
		_fill_button.tooltip_text = "Auffüllen – erst ein Genre wählen"
	elif available == 0:
		_fill_button.tooltip_text = "Auffüllen – nichts Passendes im Lager"
	else:
		_fill_button.tooltip_text = "Auffüllen (%d im Lager)" % available
	var choosable := _choosable_genres()
	_pick_button.disabled = choosable.is_empty()
	_pick_button.tooltip_text = "Buch aus dem Lager" if not choosable.is_empty() \
		else "Buch aus dem Lager – nichts Passendes da"
	_sort_button.disabled = count < 2
	_return_button.disabled = count == 0
	_message.visible = not _message.text.is_empty()

	# Genres der Fächer (die Liste selbst baut _rebuild_rows, hier nur die Auswahl)
	var genres := _genre_choices()
	_fill_choice(_all_choice, genres, shelf.genre_id, true)
	for r in _row_choices:
		_fill_choice(_row_choices[r], genres, shelf.get_row_genre(r), false)
	if _picker_view.visible:
		_refresh_picker()


## Je Fach eine Zeile (Lesereihenfolge): "Fach 1" und eine Auswahlliste für sein Genre.
func _rebuild_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_choices.clear()
	for r in shelf.get_fach_order():
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", _row_style)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		line.add_child(box)
		var label := TabletFrame.make_label(shelf.get_row_label(r), 17, TEXT_COLOR)
		label.custom_minimum_size.x = 80
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(label)
		var choice := _make_choice()
		var row := r
		choice.item_selected.connect(func(index: int) -> void:
			choose_row_genre(row, str(choice.get_item_metadata(index))))
		_watch_choice(choice, [row])
		box.add_child(choice)
		_row_choices[r] = choice
		_rows_box.add_child(line)
	_rows_scroll.scroll_vertical = 0


## Füllt eine Auswahlliste: "Gemischt" und die freigeschalteten Genres (+ das gewählte, falls
## gesperrt). Ohne Genre: ein grauer Eintrag "Noch kein Genre" (bzw. bei "Alle Fächer gleich":
## "Verschieden", wenn die Fächer unterschiedlich sind).
func _fill_choice(choice: OptionButton, genres: Array[GenreData], current: String, for_all: bool) -> void:
	if choice.get_popup().visible:
		return  # nicht umbauen, während die Liste aufgeklappt ist
	choice.clear()
	if current.is_empty():
		var different := for_all and shelf.has_genre()
		choice.add_item("Verschieden" if different else "Noch kein Genre")
		choice.set_item_metadata(0, "")
		choice.set_item_disabled(0, true)
	choice.add_icon_item(_dot(MUTED_COLOR, true), "Gemischt")
	choice.set_item_metadata(choice.item_count - 1, BookShelf.MIXED)
	for genre in genres:
		choice.add_icon_item(_dot(genre.get_main_color().lightened(0.35), false), genre.display_name)
		choice.set_item_metadata(choice.item_count - 1, genre.get_id())
	for i in choice.item_count:
		if str(choice.get_item_metadata(i)) == current:
			choice.select(i)


func _genre_choices() -> Array[GenreData]:
	var genres := BookStock.get_unlocked_genres()
	for r in shelf.get_row_count():
		var current := Catalog.get_genre(shelf.get_row_genre(r))
		if current and not genres.has(current):
			genres.append(current)  # gesperrtes Genre, das schon gewählt ist
	return genres


## Genres, aus denen hier Bücher passen und die im Lager liegen.
func _choosable_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	for genre in Catalog.get_all_genres():
		if shelf.accepts(genre.get_id()) and BookStock.get_stored_count(genre.get_id()) > 0:
			result.append(genre)
	return result


## Die Auswahl neu zeigen: Genre-Liste und die Cover der Titel im Lager.
func _refresh_picker() -> void:
	var genres := _choosable_genres()
	if genres.is_empty():
		_show_main()
		return
	var ids: Array = genres.map(func(genre: GenreData) -> String: return genre.get_id())
	if not ids.has(_picker_genre):
		_picker_genre = ids[0]
	_picker_genre_choice.clear()
	for genre in genres:
		_picker_genre_choice.add_icon_item(_dot(genre.get_main_color().lightened(0.35), false), genre.display_name)
		_picker_genre_choice.set_item_metadata(_picker_genre_choice.item_count - 1, genre.get_id())
	_picker_genre_choice.select(ids.find(_picker_genre))
	_picker_genre_choice.visible = genres.size() > 1
	# Gleiche Titel zusammenfassen ("×2 im Lager")
	var counts := {}
	var titles: Array[BookData] = []
	for book in BookStock.get_stored_books(_picker_genre):
		if not counts.has(book.data):
			titles.append(book.data)
		counts[book.data] = int(counts.get(book.data, 0)) + 1
	var entries := []
	for data in titles:
		entries.append({"data": data, "note": "×%d im Lager" % counts[data] if counts[data] > 1 else "im Lager"})
	var genre := Catalog.get_genre(_picker_genre)
	_picker_title.text = "Buch aus dem Lager (%d)" % titles.size() if genres.size() > 1 \
		else "%s aus dem Lager (%d)" % [genre.display_name if genre else "Buch", titles.size()]
	_picker.show_entries(entries, "Im Lager liegt gerade nichts davon.")


## Wie viele Bücher, die hierher passen, liegen im Lager?
func _available_in_storage() -> int:
	var genres := {}
	for r in shelf.get_row_count():
		var id := shelf.get_row_genre(r)
		if id == BookShelf.MIXED:
			return BookStock.get_stored_total()
		if not id.is_empty():
			genres[id] = true
	var count := 0
	for id in genres:
		count += BookStock.get_stored_count(id)
	return count


# --- Aufbau ---

## Baut das Tablet aus Containern (passt sich jeder Auflösung an).
func _build() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_row_style = TabletFrame.make_panel_style(TabletFrame.PANEL_COLOR, 9, 6.0)
	_row_style.content_margin_left = 12.0

	_panel = TabletFrame.new()
	_panel.name = "Tablet"
	# Am rechten Rand, feste Breite, fast so hoch wie das Bild
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

	# Kopf: Name des Regals, kurze Info, Kreuz zum Schließen
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
	var close_button := TabletFrame.make_close_button()
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_build_main(screen)
	_build_picker(screen)

	# Rückmeldung (z. B. "12 Bücher eingeräumt.") fest unten
	_message = TabletFrame.make_label("", 16, KEY_COLOR)
	screen.add_child(_message)


func _build_main(screen: VBoxContainer) -> void:
	_main_view = VBoxContainer.new()
	_main_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_view.add_theme_constant_override("separation", 12)
	screen.add_child(_main_view)

	# Symbol-Leiste
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	_main_view.add_child(toolbar)
	_pick_button = _icon_button(TabletIconButton.Icon.PICK, open_picker)
	toolbar.add_child(_pick_button)
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

	# Fächer
	_main_view.add_child(TabletFrame.make_label("Fächer", 18, KEY_COLOR))
	var all_line := HBoxContainer.new()
	all_line.add_theme_constant_override("separation", 12)
	_main_view.add_child(all_line)
	var all_label := TabletFrame.make_label("Alle Fächer gleich", 17, TEXT_COLOR)
	all_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	all_line.add_child(all_label)
	_all_choice = _make_choice()
	_all_choice.item_selected.connect(func(index: int) -> void:
		choose_genre(str(_all_choice.get_item_metadata(index))))
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


## "Buch aus dem Lager wählen": Cover-Kacheln auf dem Tablet, Pfeil zurück.
func _build_picker(screen: VBoxContainer) -> void:
	_picker_view = VBoxContainer.new()
	_picker_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_view.add_theme_constant_override("separation", 10)
	_picker_view.hide()
	screen.add_child(_picker_view)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_picker_view.add_child(header)
	header.add_child(_icon_button(TabletIconButton.Icon.BACK, _show_main))
	_picker_title = TabletFrame.make_label("", 18, TEXT_COLOR)
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_picker_title)
	_picker_genre_choice = _make_choice()
	_picker_genre_choice.item_selected.connect(func(index: int) -> void:
		_picker_genre = str(_picker_genre_choice.get_item_metadata(index))
		_refresh_picker.call_deferred())
	_picker_view.add_child(_picker_genre_choice)
	_picker_view.add_child(TabletFrame.make_label("Klick auf ein Buch: Es liegt dann obenauf in deiner Hand.", 15, MUTED_COLOR))
	_picker = BookPicker.new()
	_picker.book_chosen.connect(choose_book)
	_picker_view.add_child(_picker)


# --- Fach hervorheben ---

## Maus über der Auswahlliste oder Liste aufgeklappt: diese Fächer hervorheben
## (rows leer = alle Fächer, für "Alle Fächer gleich").
func _watch_choice(choice: OptionButton, rows: Array[int]) -> void:
	choice.mouse_entered.connect(func() -> void:
		_hover_rows = _rows_or_all(rows)
		_update_highlight())
	choice.mouse_exited.connect(func() -> void:
		_hover_rows = []
		_update_highlight())
	choice.get_popup().about_to_popup.connect(func() -> void:
		_open_rows = _rows_or_all(rows)
		_update_highlight())
	choice.get_popup().popup_hide.connect(func() -> void:
		_open_rows = []
		_update_highlight())


func _rows_or_all(rows: Array[int]) -> Array[int]:
	if not rows.is_empty() or shelf == null:
		return rows
	return shelf.get_fach_order()


func _update_highlight() -> void:
	if is_open and is_instance_valid(shelf):
		shelf.highlight_rows(_open_rows if not _open_rows.is_empty() else _hover_rows)


# --- Ansicht: das Regal bleibt neben dem Tablet sichtbar ---

## Rückt die Ansicht sanft so zur Seite, dass das Regal links neben dem Tablet zu sehen ist.
## Ist es dafür zu breit (oder stehe ich sehr nah davor), zoomt die Ansicht etwas heraus
## (höchstens bis GameConfig.shelf_menu_max_fov). Die Spielfigur selbst bewegt sich nicht.
func _frame_shelf() -> void:
	var camera := _player.camera
	# Gleitet die Ansicht gerade noch zurück, gilt weiter das gemerkte Blickfeld
	var restoring := _view_tween != null and _view_tween.is_running()
	if _view_tween:
		_view_tween.kill()
	if _base_fov < 0.0 or not restoring:
		_base_fov = camera.fov
	camera.fov = _base_fov
	camera.h_offset = 0.0
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
	var left_depth := 1.0
	var right_depth := 1.0
	var forward := -camera.global_basis.z
	for i in 8:
		var corner := model.global_transform * box.get_endpoint(i)
		if camera.is_position_behind(corner):
			continue
		var x := camera.unproject_position(corner).x
		var depth := maxf((corner - camera.global_position).dot(forward), 0.05)
		if x < left:
			left = x
			left_depth = depth
		if x > right:
			right = x
			right_depth = depth
	if left == INF or right <= avail_right:
		return  # das Regal ist schon frei (oder gar nicht zu sehen)
	# Zu breit für den freien Platz? Dann etwas herauszoomen (um die Bildmitte)
	var half_tan := tan(deg_to_rad(_base_fov) / 2.0)
	var shrink := clampf((avail_right - avail_left) / maxf(right - left, 1.0), 0.0, 1.0)
	var new_half_tan := minf(half_tan / maxf(shrink, 0.01), tan(deg_to_rad(GameConfig.shelf_menu_max_fov) / 2.0))
	var factor := half_tan / new_half_tan
	var center := view.x / 2.0
	left = center + (left - center) * factor
	right = center + (right - center) * factor
	# Dann so weit zur Seite, dass der rechte Rand neben dem Tablet liegt (links nicht hinaus)
	var shift := maxf(right - avail_right, 0.0)
	shift = minf(shift, maxf(left - avail_left, 0.0))
	var aspect := view.x / view.y
	# Bildpunkte -> Meter in der Tiefe des rechten Rands (dort muss es passen)
	var meters := shift / view.x * 2.0 * right_depth * new_half_tan * aspect
	var new_fov := rad_to_deg(2.0 * atan(new_half_tan))
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(camera, "fov", new_fov, GameConfig.shelf_menu_view_time)
	_view_tween.tween_property(camera, "h_offset", meters, GameConfig.shelf_menu_view_time)


## Beim Schließen gleitet die Ansicht zurück.
func _restore_view() -> void:
	if _base_fov < 0.0:
		return
	var camera := _player.camera
	if _view_tween:
		_view_tween.kill()
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(camera, "fov", _base_fov, GameConfig.shelf_menu_view_time)
	_view_tween.tween_property(camera, "h_offset", 0.0, GameConfig.shelf_menu_view_time)


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
