extends CanvasLayer
## Oberfläche des Gestaltungsmodus: Inventar unten, Tastenhilfe am Rand, Statuszeile.
##
## Das Inventar zeigt große Bild-Kacheln (Vorschaubild in der jeweiligen Farbe, klein in der
## Ecke die Anzahl) – nur, was gerade im Inventar liegt; jede Farbe ist eine eigene Kachel.
## Wandfarben, Böden und Decken erscheinen als Farbfeld (unbegrenzt). Name und Werte stehen nur
## im Tooltip. Kategorien und Filter sind kleine Symbol-Knöpfe (Name im Tooltip).
## Ein Klick auf eine Kachel meldet die Auswahl an den Gestaltungsmodus (BuildMode).
## Neues gibt es im Shop.

const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)
const WARNING_COLOR := Color(1.0, 0.68, 0.55)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
## Größe einer Bild-Kachel (das Bild passt sich bei jeder Auflösung mit an).
const TILE_SIZE := Vector2(132, 112)
const TAB_BUTTON_SIZE := 40.0

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
var _tab_buttons: Array[IconToggle] = []
var _cards := {}  # Oberfläche bzw. "id:farbe" -> Kachel (ItemTile)
var _grid_help_label: Label
var _current_tab: int = 0
var _refresh_queued := false
var _thumbnails: ThumbnailRenderer


func _ready() -> void:
	hide()
	_thumbnails = ThumbnailRenderer.new()
	_thumbnails.name = "Thumbnails"
	add_child(_thumbnails)
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
		var button := IconToggle.new(TAB_BUTTON_SIZE)
		var tab: Array = _tabs[i]
		button.icon_key = CatalogIcons.category_key(tab[2]) if tab[1] == "furniture" else CatalogIcons.surface_key(tab[2])
		button.tooltip_text = tab[0]
		button.pressed.connect(_show_tab.bind(i))
		_tab_row.add_child(button)
		_tab_buttons.append(button)
		if i == FurnitureData.Category.size() - 1:
			# Kleiner Abstand zwischen Möbeln und Oberflächen
			var gap := Control.new()
			gap.custom_minimum_size.x = 8
			_tab_row.add_child(gap)


func _show_tab(index: int) -> void:
	var same_tab := index == _current_tab
	var scroll := _item_scroll.scroll_horizontal
	_current_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
		# Reiter ohne eigene Dinge leicht ausgegraut (bleiben anklickbar)
		_tab_buttons[i].is_empty = get_owned_items(i).is_empty()
		_tab_buttons[i].queue_redraw()
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
		for entry in Inventory.get_stored_entries():
			var data: FurnitureData = entry.data
			if data.category != tab[2] or not _filter_bar.matches(data):
				continue
			var tile := ItemTile.new(TILE_SIZE)
			tile.setup(data, entry.variant, _thumbnails)
			tile.set_badge("×%d" % entry.count)
			tile.tooltip_text = ItemTile.describe(data, entry.variant)
			tile.pressed.connect(_build_mode.select_furniture.bind(data, entry.variant))
			_add_card(FurnitureData.make_key(data.get_id(), entry.variant), tile)
	else:
		for surface: SurfaceData in owned:
			if not _filter_bar.matches(surface):
				continue
			var tile := ItemTile.new(TILE_SIZE)
			tile.setup(surface, "", _thumbnails)
			tile.tooltip_text = ItemTile.describe(surface, "", ["unbegrenzt"])
			tile.pressed.connect(_build_mode.select_surface.bind(surface))
			_add_card(surface, tile)

	if _cards.is_empty():
		var empty := Label.new()
		empty.text = "Hier ist noch nichts. Bei „%s“ am Theken-Tablet findest du mehr." % CounterTablet.get_app_name("furnishing")
		if not owned.is_empty():
			empty.text = "Dazu passt hier gerade nichts – probier einen anderen Filter."
		empty.add_theme_color_override("font_color", MUTED_COLOR)
		empty.custom_minimum_size.y = TILE_SIZE.y
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	_queue_refresh()


## Inventar oder Einrichtung haben sich geändert: Karten neu aufbauen (einmal pro Bild).
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_show_tab(_current_tab)


## key = Oberfläche bzw. bei Möbeln "id:farbe" (FurnitureData.make_key).
func _add_card(key: Variant, card: Button) -> void:
	_item_row.add_child(card)
	_cards[key] = card


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
	var selected_key: Variant = selected
	if selected is FurnitureData:
		selected_key = FurnitureData.make_key(selected.get_id(), _build_mode.get_selected_variant())
	for key in _cards:
		_cards[key].set_pressed_no_signal(key == selected_key)
