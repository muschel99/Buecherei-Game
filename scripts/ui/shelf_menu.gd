class_name ShelfMenu
extends CanvasLayer
## Das Regal-Menü (R) – als Tablet am rechten Bildrand (TabletFrame, wie das Tablet an der Theke).
##
## R öffnet es überall: Schaue ich ein Regal an, gehört es zu diesem Regal (open_for(regal)).
## Schaue ich kein Regal an, ist es dasselbe Menü ohne Regal (open_for(null)): Die Regal-Teile
## (Genre je Fach, "Alle Fächer gleich", Auffüllen, Sortieren, alles ins Lager) sind dann dezent
## ausgegraut, die Bücherauswahl geht immer – z. B. um Bücher zum Dekorieren zu holen.
##
## Bewusst schlicht, wenige klare Aktionen:
## - Oben eine Leiste mit Symbol-Knöpfen (Tooltip beim Darüberfahren): Buch aus dem Lager
##   wählen, aus dem Lager auffüllen, sortieren (Filtersymbol: kleine Auswahl, wonach) und alle
##   Bücher zurück ins Lager.
## - Darunter "Fächer": "Alle Fächer gleich" und jedes Fach (Fach 1, Fach 2 … von oben links
##   nach unten rechts) mit einer Auswahlliste für sein Genre oder "Gemischt".
## - "Buch aus dem Lager wählen" zeigt die Cover der passenden Bücher im Lager auf dem Tablet –
##   ein Klick legt das Buch obenauf in die Hand, dann stellt man es mit der linken Maustaste an
##   genau die Stelle, die man möchte. Das Menü bleibt dabei offen (so kann ich nacheinander
##   mehrere Bücher nehmen) und schließt sich erst, wenn die Hände voll sind. Oben rechts zeigt
##   ein kleiner Stapel, wie viele Bücher ich trage.
## Bücher nimmt man nur hier aus dem Lager (nicht am Theken-Tablet).
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
var _carried_box: HBoxContainer
var _carried_icon: TextureRect
var _carried_label: Label
var _shelf_section: VBoxContainer
var _main_view: VBoxContainer
var _picker_view: VBoxContainer
var _pick_button: TabletIconButton
var _fill_button: TabletIconButton
var _sort_button: TabletIconButton
var _return_button: TabletIconButton
var _sort_popup: PopupMenu
var _all_choice: OptionButton
var _all_auto: CheckBox
var _rows_scroll: ScrollContainer
var _rows_box: VBoxContainer
var _row_choices: Dictionary = {}  # Fach (row) -> OptionButton
var _row_autos: Dictionary = {}  # Fach (row) -> CheckBox "Auto"
var _picker_title: Label
var _picker_genre_choice: OptionButton
var _picker: BookPicker
var _picker_genre := ""
## In der Bücherauswahl: "Alle Bücher" statt eines Genres
const ALL_GENRES := "*"
# Bücher, die ich in diesem Menü aus dem Lager genommen habe (bleiben als "in der Hand" sichtbar)
var _taken_here: Array[Book] = []
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

## Öffnet das Menü: vom Regal aufgerufen (R) mit diesem Regal, sonst von der Spielfigur mit
## null (kein Regal im Blick – nur die Bücherauswahl ist dann aktiv).
func open_for(target: BookShelf) -> void:
	if is_open:
		return
	shelf = target
	is_open = true
	_opened_frame = Engine.get_process_frames()
	if shelf:
		shelf.contents_changed.connect(_queue_refresh)
	MenuStack.open(self)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = ""
	_taken_here.clear()
	_show_main()
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


# --- Aktionen ---

## "Alle Fächer gleich": ein Genre für das ganze Regal.
func choose_genre(genre_id: String) -> void:
	if shelf == null or genre_id.is_empty() or (genre_id == shelf.genre_id and not shelf.row_auto.has(true)):
		return
	var returned := shelf.set_genre(genre_id)
	_message.text = "Alle Fächer: %s." % BookShelf.genre_display_name(genre_id)
	_add_returned_note(returned)
	_queue_refresh()


## "Auto" für alle Fächer ein- oder ausschalten.
func choose_all_auto(auto: bool) -> void:
	if shelf == null:
		return
	shelf.set_all_auto(auto)
	_message.text = "Alle Fächer: %s." % ("Auto" if auto else "festgelegt")
	_queue_refresh()


## "Auto" für ein Fach ein- oder ausschalten (aus = es bleibt beim Genre, das es gerade hat).
func choose_row_auto(row: int, auto: bool) -> void:
	if shelf == null:
		return
	shelf.set_row_auto(row, auto)
	_message.text = "%s: %s." % [shelf.get_row_label(row), "Auto" if auto else "festgelegt"]
	_queue_refresh()


## Genre eines einzelnen Fachs von Hand ("Auto" geht dabei aus).
func choose_row_genre(row: int, genre_id: String) -> void:
	if shelf == null or (genre_id == shelf.get_row_genre(row) and not shelf.is_row_auto(row)):
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
	var canvas_scale := _sort_button.get_global_transform_with_canvas().get_scale().y
	var below := _sort_button.get_screen_position() + Vector2(0.0, (_sort_button.size.y + 4.0) * canvas_scale)
	_sort_popup.reset_size()
	_sort_popup.popup(Rect2i(Vector2i(below), Vector2i.ZERO))


## Zeigt die Auswahl "Buch aus dem Lager wählen" auf dem Tablet.
func open_picker() -> void:
	_picker_genre = ALL_GENRES
	_main_view.hide()
	_picker_view.show()
	_refresh_picker()


func _show_main() -> void:
	_picker_view.hide()
	_main_view.show()


## Ein Buch aus dem Lager obenauf in die Hand nehmen – dann kann ich es mit der linken
## Maustaste genau dort abstellen, wo ich hinschaue. Das Menü bleibt offen, bis die Hände
## voll sind (so kann ich mehrere Bücher nacheinander nehmen).
func choose_book(data: BookData) -> void:
	if BookStock.is_hand_full():
		BookStock.show_hands_full()
		close()
		return
	for book in BookStock.get_stored_books(data.genre_id):
		if book.data == data and BookStock.take_stored_book(book):
			BookStock.carry([book])
			_taken_here.append(book)
			if BookStock.is_hand_full():
				close()
			return


## Ein Buch, das ich hier genommen habe, wieder zurück ins Lager legen (Klick auf die Kachel
## mit dem Handsymbol) – so lässt sich die Auswahl direkt im Menü korrigieren.
func return_book(book: Book) -> void:
	var back := BookStock.take_carried_where(func(carried: Book) -> bool: return carried == book)
	BookStock.store_books(back)
	_taken_here.erase(book)


func _on_entry_chosen(entry: Dictionary) -> void:
	if entry.get("held", false):
		return_book(entry.book)
	else:
		choose_book(entry.data)


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
		shelf = null  # das Regal ist inzwischen weg: weiter ohne Regal
	_refresh_carried()
	_refresh_picker_button()
	_message.visible = not _message.text.is_empty()
	if _picker_view.visible:
		_refresh_picker()
	if shelf == null:
		_refresh_without_shelf()
		return
	_shelf_section.modulate.a = 1.0
	_title.text = shelf.get_display_name()
	var count := shelf.get_books().size()
	_info.text = "%d %s · Platz für etwa %d" % [count, "Buch" if count == 1 else "Bücher", shelf.get_free_estimate()]

	# Symbol-Knöpfe: ausgegraut, wenn sie gerade nichts tun könnten (Tooltip sagt kurz, warum)
	var available := _available_in_storage()
	_fill_button.disabled = not shelf.has_genre() or available == 0 or shelf.get_free_estimate() == 0
	if not shelf.has_genre():
		_fill_button.tooltip_text = "Auffüllen – erst Bücher oder Genre"
	elif available == 0:
		_fill_button.tooltip_text = "Auffüllen – nichts Passendes im Lager"
	else:
		_fill_button.tooltip_text = "Auffüllen (%d im Lager)" % available
	_sort_button.disabled = count < 2
	_sort_button.tooltip_text = TabletIconButton.DEFAULT_TIPS[TabletIconButton.Icon.SORT]
	_return_button.disabled = count == 0
	_return_button.tooltip_text = TabletIconButton.DEFAULT_TIPS[TabletIconButton.Icon.STORE]
	_all_choice.disabled = false
	_all_auto.disabled = false

	# Genres der Fächer (die Liste selbst baut _rebuild_rows, hier nur die Auswahl)
	var genres := _genre_choices()
	_all_auto.set_pressed_no_signal(shelf.is_all_auto())
	var all_empty := "Verschieden" if shelf.has_genre() else ("Noch leer" if shelf.is_all_auto() else "Noch kein Genre")
	_fill_choice(_all_choice, genres, shelf.genre_id, all_empty)
	for r in _row_choices:
		(_row_autos[r] as CheckBox).set_pressed_no_signal(shelf.is_row_auto(r))
		_fill_choice(_row_choices[r], genres, shelf.get_row_genre(r),
			"Noch leer" if shelf.is_row_auto(r) else "Noch kein Genre")


## Kein Regal im Blick: Regal-Teile dezent ausgegraut und nicht anklickbar.
func _refresh_without_shelf() -> void:
	_title.text = "Bücher"
	_info.text = "Kein Regal im Blick"
	for button: TabletIconButton in [_fill_button, _sort_button, _return_button]:
		button.disabled = true
		button.tooltip_text = "Nur am Regal"
	_all_choice.disabled = true
	_all_choice.clear()
	_all_choice.add_item("Nur am Regal")
	_all_auto.disabled = true
	_all_auto.set_pressed_no_signal(true)
	_shelf_section.modulate.a = 0.45


## "Buch aus dem Lager": ausgegraut, wenn die Hände voll sind oder nichts Passendes im Lager liegt.
func _refresh_picker_button() -> void:
	var choosable := _choosable_genres()
	_pick_button.disabled = choosable.is_empty() or BookStock.is_hand_full()
	if BookStock.is_hand_full():
		_pick_button.tooltip_text = "Buch aus dem Lager – Hände voll"
	elif choosable.is_empty():
		_pick_button.tooltip_text = "Buch aus dem Lager – nichts Passendes da"
	else:
		_pick_button.tooltip_text = "Buch aus dem Lager"


## Oben rechts: wie viele Bücher ich trage (Stapel im Genre des Buchs obenauf).
func _refresh_carried() -> void:
	var carried := BookStock.carried.size()
	_carried_label.text = "%d / %d" % [carried, GameConfig.max_carried_books]
	var active := BookStock.get_active_book()
	var genres := Catalog.get_all_genres()
	var genre: GenreData = active.get_genre() if active else (genres[0] if not genres.is_empty() else null)
	_carried_icon.texture = BookIcons.get_stack_icon(genre) if genre else null
	_carried_box.modulate.a = 1.0 if carried > 0 else 0.45


## Je Fach eine Zeile (Lesereihenfolge): "Fach 1" und eine Auswahlliste für sein Genre.
## Ohne Regal bleibt die Liste leer.
func _rebuild_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_choices.clear()
	_row_autos.clear()
	if shelf == null:
		return
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
		var row := r
		var auto := _make_auto_box()
		auto.toggled.connect(func(on: bool) -> void: choose_row_auto(row, on))
		_watch_hover(auto, [row])
		box.add_child(auto)
		_row_autos[r] = auto
		var choice := _make_choice()
		choice.item_selected.connect(func(index: int) -> void:
			choose_row_genre(row, str(choice.get_item_metadata(index))))
		_watch_choice(choice, [row])
		box.add_child(choice)
		_row_choices[r] = choice
		_rows_box.add_child(line)
	_rows_scroll.scroll_vertical = 0


## Füllt eine Auswahlliste: "Gemischt" und die freigeschalteten Genres (+ das gewählte, falls
## gesperrt). Ohne Genre: ein grauer Eintrag empty_text ("Noch leer" bei "Auto", "Noch kein
## Genre", bei "Alle Fächer gleich" auch "Verschieden", wenn die Fächer unterschiedlich sind).
func _fill_choice(choice: OptionButton, genres: Array[GenreData], current: String, empty_text: String) -> void:
	if choice.get_popup().visible:
		return  # nicht umbauen, während die Liste aufgeklappt ist
	choice.clear()
	if current.is_empty():
		choice.add_item(empty_text)
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
	if shelf == null:
		return genres
	for r in shelf.get_row_count():
		var current := Catalog.get_genre(shelf.get_row_genre(r))
		if current and not genres.has(current):
			genres.append(current)  # gesperrtes Genre, das schon gewählt ist
	return genres


## Genres, aus denen hier Bücher passen und die im Lager liegen (ohne Regal: alle im Lager).
func _choosable_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	for genre in Catalog.get_all_genres():
		if (shelf == null or shelf.accepts(genre.get_id())) and BookStock.get_stored_count(genre.get_id()) > 0:
			result.append(genre)
	return result


## Die Auswahl neu zeigen: "Alle Bücher" und die Genres, darunter die Cover der Titel im Lager
## (dezent in der Farbe ihres Genres) und die Bücher, die ich hier schon genommen habe
## (ausgegraut mit Handsymbol).
func _refresh_picker() -> void:
	var held := _held_here()
	var genres := _choosable_genres()
	for book in held:
		var genre := book.get_genre()
		if genre and not genres.has(genre) and (shelf == null or shelf.accepts(genre.get_id())):
			genres.append(genre)
	if genres.is_empty():
		_show_main()
		return
	var ids: Array = genres.map(func(genre: GenreData) -> String: return genre.get_id())
	if _picker_genre != ALL_GENRES and not ids.has(_picker_genre):
		_picker_genre = ALL_GENRES
	_picker_genre_choice.clear()
	_picker_genre_choice.add_item("Alle Bücher")
	_picker_genre_choice.set_item_metadata(0, ALL_GENRES)
	for genre in genres:
		_picker_genre_choice.add_icon_item(_dot(genre.get_main_color().lightened(0.35), false), genre.display_name)
		_picker_genre_choice.set_item_metadata(_picker_genre_choice.item_count - 1, genre.get_id())
	_picker_genre_choice.select(0 if _picker_genre == ALL_GENRES else ids.find(_picker_genre) + 1)
	var shown: Array = ids if _picker_genre == ALL_GENRES else [_picker_genre]
	# Gleiche Titel im Lager zusammenfassen ("×2 im Lager")
	var counts := {}
	var titles: Array[BookData] = []
	for id in shown:
		for book in BookStock.get_stored_books(id):
			if not counts.has(book.data):
				titles.append(book.data)
			counts[book.data] = int(counts.get(book.data, 0)) + 1
	var held_shown := held.filter(func(book: Book) -> bool: return shown.has(book.genre_id))
	for book in held_shown:
		if not titles.has(book.data):
			titles.append(book.data)
	# Feste Reihenfolge (Genre, dann Titel) – so springt nichts, wenn ein Buch genommen wird
	titles.sort_custom(func(a: BookData, b: BookData) -> bool:
		if a.genre_id != b.genre_id:
			return ids.find(a.genre_id) < ids.find(b.genre_id)
		return a.title.naturalnocasecmp_to(b.title) < 0)
	var entries := []
	for data in titles:
		var genre := Catalog.get_genre(data.genre_id)
		var tint := genre.get_main_color() if genre else Color(0.5, 0.4, 0.3)
		var count := int(counts.get(data, 0))
		if count > 0:
			entries.append({"data": data, "tint": tint,
				"note": "×%d im Lager" % count if count > 1 else "im Lager"})
		for book in held_shown:
			if book.data == data:
				entries.append({"data": data, "tint": tint, "held": true, "book": book, "note": "in der Hand"})
	var stored_titles := titles.filter(func(data: BookData) -> bool: return counts.has(data)).size()
	var genre := Catalog.get_genre(_picker_genre)
	_picker_title.text = "Buch aus dem Lager (%d)" % stored_titles if genre == null \
		else "%s aus dem Lager (%d)" % [genre.display_name, stored_titles]
	# Nach dem Nehmen an derselben Stelle weiterschauen
	var scroll := _picker.scroll_vertical
	_picker.show_entries(entries, "Im Lager liegt gerade nichts davon.")
	_picker.set_deferred("scroll_vertical", scroll)


## Die Bücher, die ich in diesem Menü genommen habe und noch trage.
func _held_here() -> Array[Book]:
	var result: Array[Book] = []
	for book in _taken_here:
		if BookStock.carried.has(book):
			result.append(book)
	return result


## Wie viele Bücher, die hierher passen, liegen im Lager?
func _available_in_storage() -> int:
	var genres := {}
	for r in shelf.get_row_count():
		var id := shelf.get_row_genre(r)
		if id == BookShelf.MIXED and shelf.is_row_auto(r):
			for present in shelf.genres_in_row(r):
				genres[present] = true  # gemischtes Auto-Fach: nur Genres, die schon darin stehen
		elif id == BookShelf.MIXED:
			return BookStock.get_stored_total()
		elif not id.is_empty():
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
	# Getragene Bücher (Stapel mit Zahl), dann das Kreuz
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

	# Fächer (ohne Regal dezent ausgegraut)
	_shelf_section = VBoxContainer.new()
	_shelf_section.name = "ShelfSection"
	_shelf_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf_section.add_theme_constant_override("separation", 12)
	_main_view.add_child(_shelf_section)
	_shelf_section.add_child(TabletFrame.make_label("Fächer", 18, KEY_COLOR))
	var all_line := HBoxContainer.new()
	all_line.add_theme_constant_override("separation", 12)
	_shelf_section.add_child(all_line)
	var all_label := TabletFrame.make_label("Alle Fächer gleich", 17, TEXT_COLOR)
	all_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	all_line.add_child(all_label)
	_all_auto = _make_auto_box()
	_all_auto.toggled.connect(choose_all_auto)
	_watch_hover(_all_auto, [])
	all_line.add_child(_all_auto)
	_all_choice = _make_choice()
	_all_choice.item_selected.connect(func(index: int) -> void:
		choose_genre(str(_all_choice.get_item_metadata(index))))
	_watch_choice(_all_choice, [])  # leer = alle Fächer
	all_line.add_child(_all_choice)

	_rows_scroll = ScrollContainer.new()
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf_section.add_child(_rows_scroll)
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
	_picker_view.add_child(TabletFrame.make_label("Klick auf ein Buch: Es liegt dann obenauf in deiner Hand. Noch ein Klick legt es zurück.", 15, MUTED_COLOR))
	_picker = BookPicker.new()
	_picker.entry_chosen.connect(_on_entry_chosen)
	_picker_view.add_child(_picker)


# --- Fach hervorheben ---

## Maus über der Auswahlliste oder Liste aufgeklappt: diese Fächer hervorheben
## (rows leer = alle Fächer, für "Alle Fächer gleich").
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


## Tickbox "Auto": Das Fach übernimmt sein Genre aus den Büchern darin.
func _make_auto_box() -> CheckBox:
	var box := CheckBox.new()
	box.text = "Auto"
	box.focus_mode = Control.FOCUS_NONE
	box.tooltip_text = "Genre aus den Büchern"
	box.add_theme_font_size_override("font_size", 16)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		box.add_theme_color_override(state, TEXT_COLOR)
	box.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	# Schlicht, ohne eigenen Kasten (nur beim Darüberfahren ein Hauch Hintergrund)
	var hover := TabletFrame.make_panel_style(Color(1.0, 0.95, 0.85, 0.08), 8, 6.0)
	for state in ["normal", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(6.0)
		box.add_theme_stylebox_override(state, empty)
	box.add_theme_stylebox_override("hover", hover)
	box.add_theme_stylebox_override("hover_pressed", hover)
	return box


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
