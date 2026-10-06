class_name FilterBar
extends VBoxContainer
## Kleine Filter-Schaltflächen über einer Liste (im Shop und im Inventar des Gestaltungsmodus).
##
## Zwei Gruppen nebeneinander:
## - Unterkategorie: "Alle" und die Unterkategorien, die es in der Liste gerade gibt
##   (z. B. Sessel, Sofas, Stühle – siehe FurnitureData.SUBCATEGORIES)
## - Stil: "Alle Stile", Botanisch, Modern, Dark Academia, Neutral (= ohne Stil-Merkmal)
## Mit two_rows stehen die Gruppen in zwei eigenen Zeilen (im Shop), sonst nebeneinander
## (im Gestaltungsmodus). Passt die Breite nicht, rutschen die Schaltflächen in die nächste Zeile.
## Mit matches(objekt) prüft die Liste, ob ein Objekt zum Filter passt.

## Wird gesendet, wenn ein Filter angeklickt wurde.
signal changed

## Stil-Filter: ANY_STYLE = alle, NEUTRAL = ohne Stil-Merkmal, sonst ein StyleTags-Wert.
const ANY_STYLE := -1
const NEUTRAL := 0

const KEY_COLOR := Color(0.96, 0.78, 0.48)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)

## Unterkategorien und Stile in zwei eigenen Zeilen (true) oder nebeneinander (false)?
@export var two_rows: bool = false

## Gewählte Unterkategorie ("" = alle).
var subcategory: String = ""
## Gewählter Stil (ANY_STYLE, NEUTRAL oder ein StyleTags-Wert).
var style: int = ANY_STYLE

var _subcategory_buttons := {}  # id -> Button
var _style_buttons := {}  # Stil -> Button
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _first_row: HFlowContainer
var _second_row: HFlowContainer


func _init() -> void:
	add_theme_constant_override("separation", 5)
	_first_row = _make_row()
	_second_row = _make_row()
	_normal_style = _make_style(Color(0.3, 0.21, 0.15, 0.85), Color(0, 0, 0, 0))
	_hover_style = _make_style(Color(0.45, 0.31, 0.2, 0.95), Color(0, 0, 0, 0))
	_selected_style = _make_style(Color(0.45, 0.31, 0.2, 1), KEY_COLOR)


## Baut die Schaltflächen neu. subcategories: Liste von [id, Anzeigename] – nur die, die in
## der Liste wirklich vorkommen. Leer = keine Unterkategorie-Gruppe (z. B. bei Wandfarben).
## Eine gewählte Unterkategorie bleibt gewählt, solange es sie noch gibt; der Stil bleibt immer.
func setup(subcategories: Array) -> void:
	for row in [_first_row, _second_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	_subcategory_buttons.clear()
	_style_buttons.clear()
	var ids: Array = subcategories.map(func(entry: Array) -> String: return entry[0])
	if not ids.has(subcategory):
		subcategory = ""

	var style_row := _first_row
	if not subcategories.is_empty():
		_add_button(_first_row, _subcategory_buttons, "", "Alle", TEXT_COLOR)
		for entry in subcategories:
			_add_button(_first_row, _subcategory_buttons, entry[0], entry[1], TEXT_COLOR)
		if two_rows:
			style_row = _second_row
		else:
			var gap := Control.new()
			gap.custom_minimum_size.x = 14
			_first_row.add_child(gap)

	_add_button(style_row, _style_buttons, ANY_STYLE, "Alle Stile", TEXT_COLOR)
	for tag in StyleTags.ALL:
		_add_button(style_row, _style_buttons, tag, "● " + StyleTags.get_display_name(tag), StyleTags.get_color(tag))
	_add_button(style_row, _style_buttons, NEUTRAL, "○ Neutral", MUTED_COLOR)
	_second_row.visible = _second_row.get_child_count() > 0
	_update_pressed()


## Passt ein Datenblatt (Möbel oder Oberfläche) zu den gewählten Filtern?
func matches(item: Resource) -> bool:
	if not subcategory.is_empty():
		if not item is FurnitureData or item.subcategory != subcategory:
			return false
	var styles: int = item.styles
	if style == NEUTRAL:
		return styles == 0
	if style != ANY_STYLE:
		return (styles & style) != 0
	return true


## Ist gerade irgendein Filter aktiv?
func is_filtering() -> bool:
	return not subcategory.is_empty() or style != ANY_STYLE


## Unterkategorien (id, Name) einer Kategorie, die in dieser Liste vorkommen –
## in der Reihenfolge aus FurnitureData.SUBCATEGORIES.
static func present_subcategories(category: FurnitureData.Category, items: Array) -> Array:
	var used := {}
	for item in items:
		if item is FurnitureData:
			used[item.subcategory] = true
	var result := []
	for entry in FurnitureData.SUBCATEGORIES.get(category, []):
		if used.has(entry[0]):
			result.append(entry)
	return result


## Alle Filter-Schaltflächen (z. B. für Tests).
func get_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for row in [_first_row, _second_row]:
		for child in row.get_children():
			if child is Button and not child.is_queued_for_deletion():
				result.append(child)
	return result


func _make_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	add_child(row)
	return row


func _add_button(row: HFlowContainer, group: Dictionary, value: Variant, text: String, color: Color) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", color.lightened(0.15))
	button.add_theme_color_override("font_hover_pressed_color", color.lightened(0.15))
	button.add_theme_stylebox_override("normal", _normal_style)
	button.add_theme_stylebox_override("hover", _hover_style)
	button.add_theme_stylebox_override("pressed", _selected_style)
	button.add_theme_stylebox_override("hover_pressed", _selected_style)
	button.pressed.connect(_on_pressed.bind(group, value))
	row.add_child(button)
	group[value] = button


func _on_pressed(group: Dictionary, value: Variant) -> void:
	if is_same(group, _subcategory_buttons):
		subcategory = value
	else:
		style = value
	_update_pressed()
	changed.emit()


func _update_pressed() -> void:
	for id in _subcategory_buttons:
		_subcategory_buttons[id].set_pressed_no_signal(id == subcategory)
	for tag in _style_buttons:
		_style_buttons[tag].set_pressed_no_signal(tag == style)


func _make_style(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
	return box
