class_name FilterBar
extends VBoxContainer
## Kleine Filter-Knöpfe über einer Liste (im Shop und im Inventar des Gestaltungsmodus) –
## nur Symbole, der Name steht im Tooltip.
##
## Zwei Gruppen:
## - Unterkategorie: „Alle“ und die Unterkategorien, die es in der Liste gerade gibt
##   (z. B. Sessel, Sofas, Stühle – siehe FurnitureData.SUBCATEGORIES, Symbole: CatalogIcons)
## - Stil: „Alle Stile“, die Stile aus data/styles/ (StyleTags, Farbpunkt oder eigenes Symbol),
##   „Stilneutral“ (= ohne Stil-Merkmal)
## Mit two_rows stehen die Gruppen in zwei eigenen Zeilen, sonst nebeneinander. Passt die Breite
## nicht, rutschen die Knöpfe in die nächste Zeile. matches(objekt) prüft, ob ein Objekt passt.

## Wird gesendet, wenn ein Filter angeklickt wurde.
signal changed

## Stil-Filter: ANY_STYLE = alle, NEUTRAL = ohne Stil-Merkmal, sonst eine Stil-id.
const ANY_STYLE := ""
const NEUTRAL := "-neutral-"
const BUTTON_SIZE := 36.0
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)

## Unterkategorien und Stile in zwei eigenen Zeilen (true) oder nebeneinander (false)?
@export var two_rows: bool = false

## Gewählte Unterkategorie ("" = alle).
var subcategory: String = ""
## Gewählter Stil (ANY_STYLE, NEUTRAL oder eine Stil-id).
var style: String = ANY_STYLE

var _subcategory_buttons := {}  # id -> IconToggle
var _style_buttons := {}  # Stil -> IconToggle
var _first_row: HFlowContainer
var _second_row: HFlowContainer


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_first_row = _make_row()
	_second_row = _make_row()


## Baut die Knöpfe neu. subcategories: Liste von [id, Anzeigename] – nur die, die in der Liste
## wirklich vorkommen. Leer = keine Unterkategorie-Gruppe (z. B. bei Wandfarben).
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
	if subcategories.size() > 1:
		_add_button(_first_row, _subcategory_buttons, "", "Alle").icon_key = "all"
		for entry in subcategories:
			_add_button(_first_row, _subcategory_buttons, entry[0], entry[1]).icon_key = entry[0]
		if two_rows:
			style_row = _second_row
		else:
			_first_row.add_child(_make_divider())

	var any := _add_button(style_row, _style_buttons, ANY_STYLE, "Alle Stile")
	var colors: Array[Color] = []
	for style_data in StyleTags.all():
		colors.append(style_data.color)
	any.dot_colors = colors
	for style_data in StyleTags.all():
		var tip := style_data.display_name
		if not style_data.description.is_empty():
			tip += "\n" + style_data.description
		var button := _add_button(style_row, _style_buttons, style_data.get_id(), tip)
		if style_data.icon:
			button.texture = style_data.icon
		else:
			button.dot_color = style_data.color
	var neutral := _add_button(style_row, _style_buttons, NEUTRAL, "Stilneutral")
	neutral.dot_color = MUTED_COLOR
	neutral.dot_ring = true
	_second_row.visible = _second_row.get_child_count() > 0
	_update_pressed()


## Passt ein Datenblatt (Möbel oder Oberfläche) zu den gewählten Filtern?
func matches(item: Resource) -> bool:
	if not subcategory.is_empty():
		if not item is FurnitureData or item.subcategory != subcategory:
			return false
	var styles: Array[String] = StyleTags.known(item.style_ids)
	if style == NEUTRAL:
		return styles.is_empty()
	if style != ANY_STYLE:
		return styles.has(style)
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


## Alle Filter-Knöpfe (z. B. für Tests).
func get_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for row in [_first_row, _second_row]:
		for child in row.get_children():
			if child is Button and not child.is_queued_for_deletion():
				result.append(child)
	return result


func _make_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	add_child(row)
	return row


## Dünner senkrechter Strich zwischen den Gruppen.
func _make_divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1.0, 0.94, 0.84, 0.18)
	line.custom_minimum_size = Vector2(1, BUTTON_SIZE * 0.7)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", 6)
	box.add_theme_constant_override("margin_right", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return box


func _add_button(row: HFlowContainer, group: Dictionary, value: String, tip: String) -> IconToggle:
	var button := IconToggle.new(BUTTON_SIZE)
	button.tooltip_text = tip
	button.pressed.connect(_on_pressed.bind(group, value))
	row.add_child(button)
	group[value] = button
	return button


func _on_pressed(group: Dictionary, value: String) -> void:
	if is_same(group, _subcategory_buttons):
		subcategory = value
	else:
		style = value
	_update_pressed()
	changed.emit()


func _update_pressed() -> void:
	for id in _subcategory_buttons:
		_subcategory_buttons[id].set_pressed_no_signal(id == subcategory)
		_subcategory_buttons[id].queue_redraw()
	for tag in _style_buttons:
		_style_buttons[tag].set_pressed_no_signal(tag == style)
		_style_buttons[tag].queue_redraw()
