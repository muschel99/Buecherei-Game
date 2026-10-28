extends CanvasLayer
## Oberfläche des Gestaltungsmodus: Inventarleiste unten, Statuszeile, Filter und eine kleine
## Tastenhilfe am unteren Rand.
##
## Die Inventarleiste zeigt große Bild-Kacheln (Vorschaubild in der jeweiligen Farbe, klein in der
## Ecke die Anzahl) – nur, was gerade im Inventar liegt; jede Farbe ist eine eigene Kachel.
## Wandfarben, Böden und Decken erscheinen als Farbfeld (unbegrenzt). Name und Werte stehen nur
## im Tooltip. Neues gibt es im Shop.
##
## Bedienung seit Etappe 6b (das Umsehen bleibt immer an der Maus):
## - Y/X: Kategorie zurück/vor, C/V: Möbel in der Kategorie zurück/vor. Vor dem ersten und nach
##   dem letzten Möbel liegt ein leerer Platz „nichts ausgewählt“ (vorn in der Leiste), dann geht
##   es von vorn los. Gewählte Kategorie und gewähltes Möbel sind in der Leiste markiert.
## - F: Filter auf/zu – nur dann ist der Mauszeiger frei (Filter und Kacheln lassen sich
##   anklicken); F oder Esc schließt ihn wieder.
## - H: Tastenhilfe am unteren Rand aus/ein (Einstellung "interface/build_key_help").
## Die Auswahl meldet die Leiste an den Gestaltungsmodus (BuildMode.select_furniture,
## select_surface, clear_selection).

const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)
const WARNING_COLOR := Color(1.0, 0.68, 0.55)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
## Größe einer Bild-Kachel (das Bild passt sich bei jeder Auflösung mit an).
const TILE_SIZE := Vector2(132, 112)
const TAB_BUTTON_SIZE := 40.0
## Breite des leeren Platzes „nichts ausgewählt“ vorn in der Leiste.
const EMPTY_SLOT_WIDTH := 46.0
const HELP_SETTING := "interface/build_key_help"

## Pfad zum Gestaltungsmodus (im Inspektor der Hauptszene eingetragen).
@export var build_mode_path: NodePath

@onready var _build_mode: BuildMode = get_node(build_mode_path)
@onready var _tab_row: HBoxContainer = %TabRow
@onready var _item_row: HBoxContainer = %ItemRow
@onready var _item_scroll: ScrollContainer = %ItemScroll
@onready var _filter_panel: PanelContainer = %FilterPanel
@onready var _filter_title: HBoxContainer = %FilterTitle
@onready var _filter_bar: FilterBar = %FilterBar
@onready var _filter_summary: HBoxContainer = %FilterSummary
@onready var _status_label: Label = %StatusLabel
@onready var _key_help: HBoxContainer = %KeyHelp

## Reiter: [Anzeigename, "furniture" oder "surface", Kategorie bzw. Art]
var _tabs: Array = []
var _tab_buttons: Array[IconToggle] = []
var _cards := {}  # Oberfläche bzw. "id:farbe" -> Kachel (ItemTile)
## Kacheln in Reihenfolge der Leiste: { "key", "item", "variant" } (für C/V)
var _order: Array[Dictionary] = []
var _empty_slot: Button
var _category_label: Label
var _grid_word: Label
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
	_build_filter_title()
	_build_key_help()
	_show_tab(0)

	_build_mode.active_changed.connect(_on_active_changed)
	_build_mode.status_changed.connect(_on_status_changed)
	_build_mode.grid_changed.connect(_on_grid_changed)
	_build_mode.selection_changed.connect(_on_selection_changed)
	_build_mode.filter_open_changed.connect(_on_filter_open_changed)
	_on_grid_changed(_build_mode.grid_enabled)
	# Anzahlen neu zeigen, wenn sich Inventar oder Einrichtung ändern
	Inventory.changed.connect(_queue_refresh)
	_filter_bar.changed.connect(_on_filter_changed)
	_build_mode.get_room().layout_changed.connect(_queue_refresh)
	Settings.setting_changed.connect(_on_setting_changed)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = _build_mode.is_active and not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if not _build_mode.is_active or get_tree().paused:
		return
	if event.is_action_pressed("build_filter"):
		_set_filter_open(not _build_mode.filter_open)
	elif event.is_action_pressed("build_category_prev"):
		_step_tab(-1)
	elif event.is_action_pressed("build_category_next"):
		_step_tab(1)
	elif event.is_action_pressed("build_item_prev"):
		_step_item(-1)
	elif event.is_action_pressed("build_item_next"):
		_step_item(1)
	elif event.is_action_pressed("build_toggle_help"):
		Settings.set_value(HELP_SETTING, not bool(Settings.get_value(HELP_SETTING)))
	else:
		return
	get_viewport().set_input_as_handled()


# --- Kategorien und Kacheln ---

func _build_tab_buttons() -> void:
	for i in _tabs.size():
		var button := IconToggle.new(TAB_BUTTON_SIZE)
		var tab: Array = _tabs[i]
		button.icon_key = CatalogIcons.category_key(tab[2]) if tab[1] == "furniture" else CatalogIcons.surface_key(tab[2])
		button.tooltip_text = tab[0]
		button.pressed.connect(_choose_tab.bind(i))
		_tab_row.add_child(button)
		_tab_buttons.append(button)
		if i == FurnitureData.Category.size() - 1:
			# Kleiner Abstand zwischen Möbeln und Oberflächen
			var gap := Control.new()
			gap.custom_minimum_size.x = 8
			_tab_row.add_child(gap)
	# Name der gewählten Kategorie gleich neben den Reitern
	_category_label = _small_label("", 16, TEXT_COLOR)
	_category_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_filter_summary.add_child(_category_label)


## Y/X: Kategorie wechseln (rundherum). Was neu in der Hand war, wird abgelegt – ein
## aufgenommenes Möbelstück bleibt in der Hand.
func _step_tab(direction: int) -> void:
	_choose_tab(posmod(_current_tab + direction, _tabs.size()))


func _choose_tab(index: int) -> void:
	if index != _current_tab and not _build_mode.is_moving() and not _build_mode.has_nothing_in_hand():
		_build_mode.clear_selection()
	_show_tab(index)


## C/V: das nächste bzw. vorige Möbel der Kategorie – vor dem ersten und nach dem letzten der
## leere Platz „nichts ausgewählt“.
func _step_item(direction: int) -> void:
	if _order.is_empty():
		_build_mode.clear_selection()
		return
	var current := _selected_position()
	var count := _order.size() + 1  # alle Kacheln + der leere Platz (Stelle -1)
	var next := posmod(current + 1 + direction, count) - 1
	if next < 0:
		_build_mode.clear_selection()
		return
	var entry: Dictionary = _order[next]
	if entry.item is FurnitureData:
		_build_mode.select_furniture(entry.item, entry.variant)
	else:
		_build_mode.select_surface(entry.item)


## Stelle der gewählten Kachel in der Leiste (-1 = nichts ausgewählt).
func _selected_position() -> int:
	var key: Variant = _selection_key(_build_mode.get_selected())
	for i in _order.size():
		if _order[i].key == key:
			return i
	return -1


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
	_order.clear()

	var tab: Array = _tabs[index]
	_category_label.text = tab[0]
	var owned := get_owned_items(index)
	# Filter: nur die Unterkategorien anbieten, die es hier wirklich gibt
	_filter_bar.setup(FilterBar.present_subcategories(tab[2], owned) if tab[1] == "furniture" else [])
	_empty_slot = _EmptySlot.new(Vector2(EMPTY_SLOT_WIDTH, TILE_SIZE.y))
	_empty_slot.tooltip_text = "Nichts ausgewählt"
	_empty_slot.pressed.connect(_build_mode.clear_selection)
	_item_row.add_child(_empty_slot)
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
			_add_card(FurnitureData.make_key(data.get_id(), entry.variant), tile, data, entry.variant)
	else:
		for surface: SurfaceData in owned:
			if not _filter_bar.matches(surface):
				continue
			var tile := ItemTile.new(TILE_SIZE)
			tile.setup(surface, "", _thumbnails)
			tile.tooltip_text = ItemTile.describe(surface, "", ["unbegrenzt"])
			tile.pressed.connect(_build_mode.select_surface.bind(surface))
			_add_card(surface, tile, surface, "")

	if _cards.is_empty():
		var empty := Label.new()
		empty.text = "Hier ist noch nichts. Bei „%s“ am Theken-Tablet findest du mehr." % CounterTablet.get_app_name("furnishing")
		if not owned.is_empty():
			empty.text = "Dazu passt hier gerade nichts – probier einen anderen Filter (F)."
		empty.add_theme_color_override("font_color", MUTED_COLOR)
		empty.custom_minimum_size.y = TILE_SIZE.y
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_item_row.add_child(empty)
	_update_filter_summary()
	_on_selection_changed(_build_mode.get_selected())
	# Beim Aktualisieren derselben Kategorie bleibt die Liste, wo sie war
	if same_tab:
		_item_scroll.set_deferred("scroll_horizontal", scroll)
	else:
		_item_scroll.set_deferred("scroll_horizontal", 0)


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


## Inventar oder Einrichtung haben sich geändert: Kacheln neu aufbauen (einmal pro Bild).
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_show_tab(_current_tab)


## key = Oberfläche bzw. bei Möbeln "id:farbe" (FurnitureData.make_key).
func _add_card(key: Variant, card: Button, item: Resource, variant: String) -> void:
	_item_row.add_child(card)
	_cards[key] = card
	_order.append({"key": key, "item": item, "variant": variant})


func _selection_key(selected: Resource) -> Variant:
	if selected is FurnitureData:
		return FurnitureData.make_key(selected.get_id(), _build_mode.get_selected_variant())
	return selected


# --- Filter (F) ---

func _build_filter_title() -> void:
	var icon := KeyHintIcon.new()
	KeyHints.setup_icon(icon, "build_filter", false)
	_filter_title.add_child(icon)
	var title := _small_label("Filter", 16, TEXT_COLOR)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_filter_title.add_child(title)


## F: Filter auf oder zu. Nur bei offenem Filter ist der Mauszeiger frei; solange meldet sich
## die Leiste beim MenuStack an, damit Esc zuerst den Filter schließt.
func _set_filter_open(open: bool) -> void:
	_build_mode.set_filter_open(open)


func _on_filter_open_changed(open: bool) -> void:
	_filter_panel.visible = open
	if open:
		MenuStack.open(self)
	else:
		MenuStack.close(self)


## Esc bei offenem Filter (MenuStack): nur den Filter schließen.
func close_from_escape() -> void:
	_set_filter_open(false)


## Nach dem Pausenmenü: Mauszeiger wieder frei (der Filter ist noch offen).
func restore_mouse_mode() -> void:
	_build_mode.restore_mouse_mode()


func _on_filter_changed() -> void:
	_item_scroll.scroll_horizontal = 0
	_queue_refresh()


## In der Kopfzeile: kleine Symbole der gerade aktiven Filter (Unterkategorie, Stil).
func _update_filter_summary() -> void:
	for child in _filter_summary.get_children():
		if child != _category_label:
			_filter_summary.remove_child(child)
			child.queue_free()
	if not _filter_bar.is_filtering():
		return
	var funnel := _small_label("·", 18, MUTED_COLOR)
	funnel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_filter_summary.add_child(funnel)
	if not _filter_bar.subcategory.is_empty():
		var sub := _summary_icon("Filter: " + FurnitureData.get_subcategory_display_name(_tabs[_current_tab][2],
			_filter_bar.subcategory))
		sub.icon_key = _filter_bar.subcategory
		_filter_summary.add_child(sub)
	if _filter_bar.style != FilterBar.ANY_STYLE:
		var style_icon := _summary_icon("Filter: Stilneutral")
		if _filter_bar.style == FilterBar.NEUTRAL:
			style_icon.dot_color = MUTED_COLOR
			style_icon.dot_ring = true
		else:
			style_icon.tooltip_text = "Filter: " + StyleTags.get_display_name(_filter_bar.style)
			style_icon.dot_color = StyleTags.get_color(_filter_bar.style)
		_filter_summary.add_child(style_icon)


func _summary_icon(tip: String) -> IconToggle:
	var icon := IconToggle.new(28.0)
	icon.tooltip_text = tip
	icon.button_pressed = true
	icon.focus_mode = Control.FOCUS_NONE
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


# --- Tastenhilfe am unteren Rand (H) ---

## Kleine Symbole mit je einem Wort: Kategorie, Möbel, Aufnehmen, Ablegen, Drehen, Weglegen,
## Filter, Raster, Hilfe. Ausgeblendet bleibt nur ein dezentes „H Hilfe“.
func _build_key_help() -> void:
	for child in _key_help.get_children():
		_key_help.remove_child(child)
		child.queue_free()
	var full := bool(Settings.get_value(HELP_SETTING))
	var entries: Array = [
		[["build_category_prev", "build_category_next"], "Kategorie"],
		[["build_item_prev", "build_item_next"], "Möbel"],
		[["build_pick"], "Aufnehmen"],
		[["build_place"], "Ablegen"],
		[["build_rotate"], "Drehen"],
		[["build_drop"], "Weglegen"],
		[["build_filter"], "Filter"],
		[["build_toggle_grid"], "Raster"],
		[["build_toggle_help"], "Hilfe"],
	]
	if not full:
		entries = [entries.back()]
	for entry: Array in entries:
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 2)
		for action: String in entry[0]:
			var icon := KeyHintIcon.new()
			KeyHints.setup_icon(icon, action, false)
			item.add_child(icon)
		var word := _small_label(entry[1], 14, TEXT_COLOR)
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		word.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		word.add_theme_constant_override("shadow_outline_size", 4)
		item.add_child(word)
		if entry[0][0] == "build_toggle_grid":
			_grid_word = word
		_key_help.add_child(item)
	_key_help.modulate.a = 0.85 if full else 0.5
	_on_grid_changed(_build_mode.grid_enabled)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == HELP_SETTING:
		_build_key_help()


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
	else:
		_filter_panel.visible = false


func _on_status_changed(text: String, is_warning: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", WARNING_COLOR if is_warning else TEXT_COLOR)


func _on_grid_changed(enabled: bool) -> void:
	if is_instance_valid(_grid_word):
		_grid_word.text = "Raster an" if enabled else "Raster"


## Die gewählte Kachel (bzw. der leere Platz) ist markiert und rückt ins Bild.
func _on_selection_changed(selected: Resource) -> void:
	var selected_key: Variant = _selection_key(selected)
	var shown: Control = _empty_slot
	for key in _cards:
		var chosen: bool = key == selected_key
		_cards[key].set_pressed_no_signal(chosen)
		if chosen:
			shown = _cards[key]
	if is_instance_valid(_empty_slot):
		# Leerer Platz leuchtet nur, wenn wirklich nichts in der Hand ist
		_empty_slot.set_pressed_no_signal(shown == _empty_slot and not _build_mode.is_moving())
		_empty_slot.queue_redraw()
	if is_instance_valid(shown):
		_scroll_to.call_deferred(shown)


## Kachel ins Bild rücken (verzögert – gibt es sie dann noch?).
func _scroll_to(control: Control) -> void:
	if is_instance_valid(control) and _item_scroll.is_ancestor_of(control):
		_item_scroll.ensure_control_visible(control)


## Der leere Platz vorn in der Leiste: „nichts ausgewählt“ (gestrichelter Rahmen, leere Hand).
class _EmptySlot:
	extends Button

	func _init(slot_size: Vector2) -> void:
		custom_minimum_size = slot_size
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.set_corner_radius_all(12)
			box.bg_color = Color(0.36, 0.27, 0.2, 0.25) if not state.contains("pressed") else Color(0.48, 0.34, 0.22, 0.75)
			if state.contains("pressed"):
				box.border_color = KEY_COLOR
				box.set_border_width_all(3)
			if state == "focus":
				box.bg_color = Color(0, 0, 0, 0)
			add_theme_stylebox_override(state, box)

	func _draw() -> void:
		# Ein kleiner leerer Kreis: hier liegt nichts
		var color := KEY_COLOR if button_pressed else MUTED_COLOR
		draw_arc(size / 2.0, 9.0, 0.0, TAU, 32, color, 2.0, true)
		draw_line(size / 2.0 + Vector2(-6.0, 6.0), size / 2.0 + Vector2(6.0, -6.0), color, 2.0, true)

	func _toggled(_on: bool) -> void:
		queue_redraw()
