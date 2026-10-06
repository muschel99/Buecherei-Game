class_name ShelfMenu
extends CanvasLayer
## Das kleine Regal-Menü (E an einem Bücherregal).
##
## Hier wählt man, welches Genre in das Regal gehört (oder "Gemischt"), füllt es mit einem
## Klick aus dem Lager oder legt alle Bücher zurück ins Lager. Trägt man Bücher, kann man
## sie hier auch einräumen oder ins Lager legen.
## Das Menü steht rechts am Rand – so sieht man in der Mitte, wie die Bücher ins Regal gleiten.
## Schließen: Esc, E oder "Schließen" (Esc-Regel über MenuStack). Solange es offen ist, ist der
## Mauszeiger sichtbar und die Spielfigur steht still.

const GROUP := "shelf_menu"
const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.85)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)

var is_open: bool = false
var shelf: BookShelf = null

var _panel: PanelContainer
var _title: Label
var _info: Label
var _genre_flow: HFlowContainer
var _fill_button: Button
var _return_button: Button
var _carried_button: Button
var _store_carried_button: Button
var _message: Label
var _opened_frame := -1
var _refresh_queued := false
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	hide()
	BookStock.changed.connect(_queue_refresh)
	BookStock.carried_changed.connect(_queue_refresh)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = is_open and not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	# E schließt das Menü wieder (aber nicht derselbe Tastendruck, der es geöffnet hat)
	if is_open and event.is_action_pressed("interact") and Engine.get_process_frames() != _opened_frame:
		close()
		get_viewport().set_input_as_handled()


# --- Öffnen und Schließen ---

## Wird vom Regal aufgerufen (E).
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
	_queue_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	if is_instance_valid(shelf) and shelf.contents_changed.is_connected(_queue_refresh):
		shelf.contents_changed.disconnect(_queue_refresh)
	shelf = null
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

func choose_genre(genre_id: String) -> void:
	if shelf == null or genre_id == shelf.genre_id:
		return
	var returned := shelf.set_genre(genre_id)
	_message.text = "Dieses Regal ist jetzt für %s." % shelf.get_genre_name()
	if returned > 0:
		_message.text += " %d %s nicht dazu und %s wieder im Lager." % [returned,
			"Buch passte" if returned == 1 else "Bücher passten", "liegt" if returned == 1 else "liegen"]
	_queue_refresh()


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
	_message.text = "%d %s zurück ins Lager gelegt." % [count, "Buch" if count == 1 else "Bücher"]
	_queue_refresh()


func put_carried() -> void:
	if shelf == null:
		return
	var count := shelf.put_carried()
	_message.text = "%d getragene %s eingeräumt." % [count, "Buch" if count == 1 else "Bücher"] if count > 0 \
		else "Hier ist kein Platz mehr."
	_queue_refresh()


func store_carried() -> void:
	for genre_id in BookStock.get_carried_counts():
		var genre := Catalog.get_genre(genre_id)
		if genre:
			StorageIndicator.add_item(self, genre)
	var count := BookStock.store_carried()
	_message.text = "%d getragene %s ins Lager gelegt." % [count, "Buch" if count == 1 else "Bücher"]
	_queue_refresh()


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
	_panel.reset_size()  # wieder genau so hoch wie der Inhalt
	_title.text = shelf.get_display_name()
	var count := shelf.books.size()
	_info.text = "%d %s im Regal · Platz für etwa %d weitere" % [count, "Buch" if count == 1 else "Bücher",
		shelf.get_free_estimate()]

	# Genre-Knöpfe: Gemischt + alle freigeschalteten Genres (+ das aktuelle, falls gesperrt)
	for child in _genre_flow.get_children():
		_genre_flow.remove_child(child)
		child.queue_free()
	_genre_flow.add_child(_genre_button(BookShelf.MIXED, "Gemischt", MUTED_COLOR))
	var genres := BookStock.get_unlocked_genres()
	var current := Catalog.get_genre(shelf.genre_id)
	if current and not genres.has(current):
		genres.append(current)
	for genre in genres:
		_genre_flow.add_child(_genre_button(genre.get_id(), genre.display_name, genre.get_main_color().lightened(0.5)))

	# Auffüllen: wie viele passende Bücher liegen im Lager?
	var available := _available_in_storage()
	_fill_button.disabled = not shelf.has_genre() or available == 0 or shelf.get_free_estimate() == 0
	if not shelf.has_genre():
		_fill_button.text = "Aus dem Lager auffüllen (erst ein Genre wählen)"
	elif available == 0:
		_fill_button.text = "Aus dem Lager auffüllen (keine passenden im Lager)"
	else:
		_fill_button.text = "Aus dem Lager auffüllen (%d im Lager)" % available
	_return_button.disabled = count == 0
	_return_button.text = "Alle Bücher zurück ins Lager"

	var carried := BookStock.carried.size()
	var matching := shelf.count_matching_carried() if shelf.has_genre() else 0
	_carried_button.visible = matching > 0
	_carried_button.text = "Getragene einräumen (%d passen)" % matching
	_store_carried_button.visible = carried > 0
	_store_carried_button.text = "Getragene Bücher ins Lager legen (%d)" % carried


## Wie viele Bücher, die hierher passen, liegen im Lager?
func _available_in_storage() -> int:
	if not shelf.has_genre():
		return 0
	if shelf.genre_id == BookShelf.MIXED:
		return BookStock.get_stored_total()
	return BookStock.get_stored_count(shelf.genre_id)


func _genre_button(genre_id: String, text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = "● " + text if genre_id != BookShelf.MIXED else "◐ " + text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.button_pressed = shelf.genre_id == genre_id
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_hover_pressed_color", color)
	button.add_theme_stylebox_override("normal", _normal_style)
	button.add_theme_stylebox_override("hover", _selected_style if button.button_pressed else _normal_style)
	button.add_theme_stylebox_override("pressed", _selected_style)
	button.add_theme_stylebox_override("hover_pressed", _selected_style)
	button.pressed.connect(choose_genre.bind(genre_id))
	return button


## Baut das Menü aus Containern (passt sich jeder Auflösung an).
func _build() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_normal_style = _make_style(Color(0.3, 0.21, 0.15, 0.85), Color(0, 0, 0, 0))
	_selected_style = _make_style(Color(0.45, 0.31, 0.2, 1), KEY_COLOR)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	# Rechts am Rand, feste Breite
	panel.anchor_left = 0.97
	panel.anchor_right = 0.97
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.x = 470
	# Oben fest, nach unten so hoch wie der Inhalt
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.12
	panel.grow_vertical = Control.GROW_DIRECTION_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.12, 0.09, 0.94)
	style.border_color = Color(0.55, 0.42, 0.28, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_panel = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = _label("", 22, TEXT_COLOR)
	box.add_child(_title)
	_info = _label("", 15, MUTED_COLOR)
	box.add_child(_info)
	box.add_child(_label("Genre dieses Regals", 16, KEY_COLOR))
	_genre_flow = HFlowContainer.new()
	_genre_flow.add_theme_constant_override("h_separation", 6)
	_genre_flow.add_theme_constant_override("v_separation", 6)
	box.add_child(_genre_flow)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	_fill_button = _button(fill)
	box.add_child(_fill_button)
	_carried_button = _button(put_carried)
	box.add_child(_carried_button)
	_return_button = _button(return_all)
	box.add_child(_return_button)
	_store_carried_button = _button(store_carried)
	box.add_child(_store_carried_button)
	_message = _label("", 15, KEY_COLOR)
	box.add_child(_message)

	var close_button := _button(close)
	close_button.text = "Schließen (Esc)"
	box.add_child(close_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	return button


func _make_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	return style
