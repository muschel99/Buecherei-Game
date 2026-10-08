extends TabletApp
## App "Fassade" auf dem Theken-Tablet: Hier gestalte ich die Hausfront.
##
## Die App besteht aus Abschnitten (je ein Kasten mit Überschrift), von oben nach unten.
## Bisher gibt es einen: den Rückgabekasten (welcher Einwurf außen in der Hauswand sitzt,
## dazu dezent, wie viele Bücher gerade darin liegen).
##
## Neue Fassaden-Einstellung (z. B. Wandfarbe außen, Schild, Fenster): eine Funktion schreiben,
## die mit make_section() einen Abschnitt baut, und sie in SECTIONS eintragen. Auswahlen wie
## beim Einwurf baut make_option_card() (Vorschaubild, Name, ausgewählt hervorgehoben).

## Die Abschnitte (Namen der Funktionen, die sie bauen), von oben nach unten.
const SECTIONS := ["_build_return_box_section"]
const CARD_SIZE := Vector2(190, 178)
const PREVIEW_SIZE := Vector2(170, 112)

var _box: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	# Etwas Luft an den Seiten, damit es ruhig wirkt
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 8)
	_scroll.add_child(margin)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 22)
	margin.add_child(_box)


func app_opened() -> void:
	# Ändert sich der Rückgabekasten (Bücher kommen dazu), zeigt die App es gleich
	var box := ReturnBox.find(get_tree())
	if box and not box.changed.is_connected(request_refresh):
		box.changed.connect(request_refresh)


func refresh() -> void:
	var scroll := _scroll.scroll_vertical
	clear(_box)
	for builder: String in SECTIONS:
		if has_method(builder):
			call(builder)
	_scroll.set_deferred("scroll_vertical", scroll)


# --- Abschnitt: Rückgabekasten ---

func _build_return_box_section() -> void:
	var box := ReturnBox.find(get_tree())
	if box == null:
		return
	var content := make_section("Rückgabekasten", "Fest in der Hauswand neben der Eingangstür",
		_make_count(box.get_books().size(), box.get_capacity(), box.is_full()))
	content.add_child(make_label("Einwurf", 15, TabletFrame.MUTED_COLOR))
	var cards := HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	content.add_child(cards)
	for slot in Catalog.get_all_return_slots():
		var card := make_option_card(slot.display_name, slot.get_id() == box.slot_id, choose_slot.bind(slot.get_id()))
		card.name = slot.get_id()
		var preview := card.get_node("Box/Preview") as TextureRect
		_request_slot_picture(slot, preview)
		cards.add_child(card)


## Einwurf wählen (Kennung einer ReturnSlotData).
func choose_slot(id: String) -> void:
	var box := ReturnBox.find(get_tree())
	if box:
		box.set_slot(id)
	request_refresh()


## Buchsymbol und "12 / 50" (voll: in der Hinweisfarbe).
func _make_count(count: int, capacity: int, full: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Count"
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = "Bücher im Rückgabekasten"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var glyph := CountBadge.BookGlyph.new()
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.color = TabletFrame.TEXT_COLOR
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var number := make_label("%d / %d" % [count, capacity], 17, TabletFrame.KEY_COLOR if full else TabletFrame.TEXT_COLOR)
	number.name = "Number"
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	return row


func _request_slot_picture(slot: ReturnSlotData, target: TextureRect) -> void:
	if tablet == null or tablet.thumbnails == null:
		return
	# Schwache Referenz: Ist die Karte schon wieder weg, wird das Foto nicht mehr eingesetzt
	var target_ref: WeakRef = weakref(target)
	var show_picture := func(texture: Texture2D) -> void:
		var picture := target_ref.get_ref() as TextureRect
		if picture:
			picture.texture = texture
	# Mit einem Stück Hauswand dahinter, fast von vorn
	tablet.thumbnails.request_scene("return_slot/" + slot.get_id(), slot.scene_path, slot.icon,
		show_picture, Vector2(0.5, 0.36))


# --- Bausteine für Abschnitte ---

## Ein Abschnitt: Kasten mit Überschrift, dezenter Unterzeile und (freiwillig) etwas rechts
## daneben. Liefert den Bereich, in den der Inhalt kommt.
func make_section(title: String, subtitle: String = "", extra: Control = null) -> VBoxContainer:
	var panel := make_panel(16.0)
	panel.name = title.to_pascal_case() if not title.is_empty() else "Section"
	_box.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	content.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	names.add_child(make_label(title, 20))
	if not subtitle.is_empty():
		names.add_child(make_label(subtitle, 14, TabletFrame.MUTED_COLOR))
	if extra:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(extra)
	return content


## Eine Auswahl-Karte: Vorschaubild (Knoten "Box/Preview", Bild setzt der Abschnitt) und Name;
## die gewählte ist hervorgehoben (Rahmen) und trägt ein Häkchen.
func make_option_card(title: String, selected: bool, action: Callable) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.toggle_mode = true
	card.button_pressed = selected
	card.tooltip_text = title
	if selected:
		var style := TabletFrame.make_panel_style(Color(0.45, 0.31, 0.2, 1.0), 10, 8.0)
		style.border_color = TabletFrame.KEY_COLOR
		style.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			card.add_theme_stylebox_override(state, style)
	else:
		card.pressed.connect(action)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	var label := make_label(("✓ " if selected else "") + title, 16, TabletFrame.KEY_COLOR if selected else TabletFrame.TEXT_COLOR)
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	box.add_child(label)
	return card
