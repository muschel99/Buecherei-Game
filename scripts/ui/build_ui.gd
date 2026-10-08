extends CanvasLayer
## Oberfläche des Gestaltungsmodus: Inventar unten, Tastenhilfe am Rand, Statuszeile.
##
## Die Karten zeigen nur, was gerade im Inventar liegt: Möbel mit Anzahl (×2), Wandfarben,
## Böden und Decken ohne Anzahl (unbegrenzt). Was ganz im Raum steht, erscheint hier nicht –
## so bleibt die Liste übersichtlich, auch wenn es später sehr viele Objekte gibt.
## Ein Klick auf eine Karte meldet die Auswahl an den Gestaltungsmodus (BuildMode).
## Neues gibt es im Shop.

const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)
const WARNING_COLOR := Color(1.0, 0.68, 0.55)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const CARD_SIZE := Vector2(206, 100)

## Pfad zum Gestaltungsmodus (im Inspektor der Hauptszene eingetragen).
@export var build_mode_path: NodePath

@onready var _build_mode: BuildMode = get_node(build_mode_path)
@onready var _catalog_panel: PanelContainer = %CatalogPanel
@onready var _tab_row: HBoxContainer = %TabRow
@onready var _item_row: HBoxContainer = %ItemRow
@onready var _item_scroll: ScrollContainer = %ItemScroll
@onready var _filter_bar: FilterBar = %FilterBar
@onready var _catalog_hint: Label = %CatalogHint
@onready var _status_label: Label = %StatusLabel
@onready var _help_grid: GridContainer = %HelpGrid

## Reiter: [Anzeigename, "furniture" oder "surface", Kategorie bzw. Art]
var _tabs: Array = []
var _tab_buttons: Array[Button] = []
var _cards := {}  # Datenblatt -> Karte (Button)
var _grid_help_label: Label
var _selected_style: StyleBoxFlat
var _current_tab: int = 0
var _refresh_queued := false


func _ready() -> void:
	hide()
	_selected_style = _make_selected_style()
	for category in FurnitureData.Category.values():
		_tabs.append([FurnitureData.get_category_display_name(category), "furniture", category])
	_tabs.append(["Wandfarbe", "surface", SurfaceData.Kind.WALL])
	_tabs.append(["Boden", "surface", SurfaceData.Kind.FLOOR])
	_tabs.append(["Decke", "surface", SurfaceData.Kind.CEILING])
	_build_tab_buttons()
	_build_help()
	_show_tab(0)

	_build_mode.active_changed.connect(_on_active_changed)
	_build_mode.status_changed.connect(_on_status_changed)
	_build_mode.grid_changed.connect(_on_grid_changed)
	_build_mode.selection_changed.connect(_on_selection_changed)
	_on_grid_changed(_build_mode.grid_enabled)
	# Anzahlen neu zeigen, wenn sich Inventar oder Einrichtung ändern
	Inventory.changed.connect(_queue_refresh)
	_filter_bar.changed.connect(_on_filter_changed)
	_build_mode.get_room().layout_changed.connect(_queue_refresh)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = _build_mode.is_active and not get_tree().paused
	if not visible:
		return
	# Im Platzier-Zustand ist der Katalog nur dezent zu sehen
	var in_catalog := _build_mode.is_in_catalog_state()
	_catalog_panel.modulate.a = 1.0 if in_catalog else 0.6
	_catalog_hint.text = "Rechte Maustaste halten: umsehen" if in_catalog else "Rechtsklick: zurück zum Katalog"


# --- Katalog ---

func _build_tab_buttons() -> void:
	for i in _tabs.size():
		var button := Button.new()
		button.text = _tabs[i][0]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
		button.pressed.connect(_show_tab.bind(i))
		_tab_row.add_child(button)
		_tab_buttons.append(button)


func _show_tab(index: int) -> void:
	var same_tab := index == _current_tab
	var scroll := _item_scroll.scroll_horizontal
	_current_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
	for child in _item_row.get_children():
		_item_row.remove_child(child)
		child.queue_free()
	_cards.clear()

	var tab: Array = _tabs[index]
	var owned := get_owned_items(index)
	# Filter: nur die Unterkategorien anbieten, die es hier wirklich gibt
	_filter_bar.setup(FilterBar.present_subcategories(tab[2], owned) if tab[1] == "furniture" else [])
	_filter_bar.visible = not owned.is_empty()  # ohne Inhalt keine Filter
	if tab[1] == "furniture":
		for data: FurnitureData in owned:
			if not _filter_bar.matches(data):
				continue
			var count := Inventory.get_count(data.get_id())
			var card := _create_card(data.display_name, _size_text(data), data.styles, data.description, Color(0, 0, 0, 0), count)
			card.pressed.connect(_build_mode.select_furniture.bind(data))
			_add_card(data, card)
	else:
		for surface: SurfaceData in owned:
			if not _filter_bar.matches(surface):
				continue
			var card := _create_card(surface.display_name, "unbegrenzt", surface.styles, "", surface.preview_color)
			card.pressed.connect(_build_mode.select_surface.bind(surface))
			_add_card(surface, card)

	if _cards.is_empty():
		var empty := Label.new()
		empty.text = "Hier ist noch nichts. Bei „%s“ am Theken-Tablet findest du mehr." % CounterTablet.get_app_name("furnishing")
		if not owned.is_empty():
			empty.text = "Dazu passt hier gerade nichts – probier einen anderen Filter."
		empty.add_theme_color_override("font_color", MUTED_COLOR)
		_item_row.add_child(empty)
	_on_selection_changed(_build_mode.get_selected())
	# Beim Aktualisieren desselben Reiters bleibt die Liste, wo sie war
	_item_scroll.set_deferred("scroll_horizontal", scroll if same_tab else 0)


## Alles Eigene in diesem Reiter (ungefiltert): Möbel, die im Inventar liegen (mindestens
## eins), bzw. die Oberflächen, die mir gehören.
func get_owned_items(index: int) -> Array[Resource]:
	var tab: Array = _tabs[index]
	var result: Array[Resource] = []
	if tab[1] == "furniture":
		for data in Inventory.get_stored_furniture():
			if data.category == tab[2]:
				result.append(data)
	else:
		result.append_array(Inventory.get_owned_surfaces(tab[2]))
	return result


func _on_filter_changed() -> void:
	_item_scroll.scroll_horizontal = 0
	_show_tab(_current_tab)


## Inventar oder Einrichtung haben sich geändert: Karten neu aufbauen (einmal pro Bild).
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_show_tab(_current_tab)



func _add_card(data: Resource, card: Button) -> void:
	_item_row.add_child(card)
	_cards[data] = card


## Eine Karte im Inventar: Name, Anzahl (count, -1 = ohne), Zusatzzeile, Stile und
## optional ein Farbfeld.
func _create_card(title: String, subtitle: String, styles: int, tooltip: String, swatch := Color(0, 0, 0, 0), count := -1) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = tooltip
	card.add_theme_stylebox_override("pressed", _selected_style)
	card.add_theme_stylebox_override("hover_pressed", _selected_style)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	if swatch.a > 0.0:
		var color_field := ColorRect.new()
		color_field.color = swatch
		color_field.custom_minimum_size = Vector2(0, 18)
		color_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(color_field)

	# Name und daneben die Anzahl (z. B. "×2")
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	var title_label := _small_label(title, 16, TEXT_COLOR)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2 if swatch.a <= 0.0 else 1
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	if count >= 0:
		var badge := _small_label("×%d" % count, 17, KEY_COLOR if count > 0 else MUTED_COLOR)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title_row.add_child(badge)
	box.add_child(_small_label(subtitle, 14, MUTED_COLOR))

	var style_row := HBoxContainer.new()
	style_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_row.add_theme_constant_override("separation", 8)
	for style in StyleTags.to_list(styles):
		style_row.add_child(_small_label("● " + StyleTags.get_display_name(style), 13, StyleTags.get_color(style)))
	if styles == 0:
		style_row.add_child(_small_label("○ stilneutral", 13, MUTED_COLOR))
	box.add_child(style_row)
	return card


func _size_text(data: FurnitureData) -> String:
	var size := data.get_footprint_size()
	return "%s × %s m" % [String.num(size.x, 2), String.num(size.y, 2)]


func _make_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.45, 0.31, 0.2, 1)
	style.border_color = KEY_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	return style


# --- Tastenhilfe ---

func _build_help() -> void:
	var entries := [
		["Tab / Esc", "Gestaltungsmodus schließen"],
		["Linksklick", "Auswählen / aufheben / platzieren"],
		["Rechte Maustaste", "Halten: umsehen · Klick: zurücklegen"],
		["Mausrad", "Drehen"],
		["G", ""],  # Text kommt aus _on_grid_changed
		["X", "Ins Inventar legen"],
		["Umschalt + Klick", "Ganze Wand · Boden/Decke füllen"],
	]
	for entry in entries:
		_help_grid.add_child(_small_label(entry[0], 14, KEY_COLOR))
		var label := _small_label(entry[1], 14, TEXT_COLOR)
		_help_grid.add_child(label)
		if entry[0] == "G":
			_grid_help_label = label


func _small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# --- Rückmeldungen vom Gestaltungsmodus ---

func _on_active_changed(active: bool) -> void:
	if active:
		_status_label.text = ""


func _on_status_changed(text: String, is_warning: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", WARNING_COLOR if is_warning else TEXT_COLOR)


func _on_grid_changed(enabled: bool) -> void:
	_grid_help_label.text = "Einrasten an/aus (jetzt: %s)" % ("an" if enabled else "aus")


func _on_selection_changed(selected: Resource) -> void:
	for data in _cards:
		_cards[data].set_pressed_no_signal(data == selected)
