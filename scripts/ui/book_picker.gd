class_name BookPicker
extends ScrollContainer
## Eine Auswahl von Büchern als Kacheln mit Cover (z. B. "Buch aus dem Lager wählen" im
## Regal-Menü und die Sammlung am Tablet).
##
## show_entries(liste) zeigt die Kacheln. Jeder Eintrag ist ein Dictionary:
##   "data":    BookData (der Titel)
##   "known":   false = noch nicht entdeckt (Kachel mit "?")
##   "note":    kleiner Text unter dem Titel, z. B. "×2 im Lager"
##   "enabled": false = nicht anklickbar (ausgegraut)
##   "tint":    Farbe, mit der die Kachel dezent hinterlegt wird (z. B. die Farbe des Genres)
##   "held":    true = dieses Buch ist gerade in der Hand: ausgegraut mit kleinem Handsymbol,
##              aber anklickbar (z. B. um es zurück ins Lager zu legen)
## Ein Klick auf eine Kachel sendet book_chosen(data) und entry_chosen(eintrag).
## interactive = false: nur zum Anschauen (z. B. die Sammlung in der Lager-App) – keine Kachel
## ist anklickbar, aber auch keine ausgegraut.

signal book_chosen(data: BookData)
signal entry_chosen(entry: Dictionary)

const CARD_WIDTH := 112.0
const COVER_WIDTH := 92.0
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.85)

## false = nur zum Anschauen (keine Kachel anklickbar, nichts ausgegraut).
var interactive := true

var _flow: HFlowContainer
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 8)
	_flow.add_theme_constant_override("v_separation", 8)
	add_child(_flow)
	_normal_style = _make_style(Color(0.3, 0.21, 0.15, 0.6))
	_hover_style = _make_style(Color(0.45, 0.31, 0.2, 0.95))


## Zeigt die Kacheln (empty_text erscheint, wenn die Liste leer ist).
func show_entries(entries: Array, empty_text: String = "") -> void:
	for child in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	for entry: Dictionary in entries:
		_flow.add_child(_create_card(entry))
	if entries.is_empty() and not empty_text.is_empty():
		var label := _label(empty_text, 16, MUTED_COLOR)
		label.custom_minimum_size.x = 360
		_flow.add_child(label)
	scroll_vertical = 0


func _create_card(entry: Dictionary) -> Button:
	var data: BookData = entry.data
	var known: bool = entry.get("known", true)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var normal := _normal_style
	var hover := _hover_style
	if entry.has("tint"):
		# Dezent in der Farbe des Genres hinterlegt (Stärke in GameConfig)
		var share := GameConfig.book_picker_tint
		normal = _make_style(Color(_normal_style.bg_color.lerp(entry.tint, share), _normal_style.bg_color.a))
		hover = _make_style(Color(_hover_style.bg_color.lerp(entry.tint, share), _hover_style.bg_color.a))
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("disabled", normal)
	card.disabled = not entry.get("enabled", true) or not known or not interactive
	if not interactive:
		card.add_theme_stylebox_override("hover", normal)
	if not card.disabled:
		card.pressed.connect(func() -> void:
			book_chosen.emit(data)
			entry_chosen.emit(entry))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	box.position = Vector2(10, 8)
	var cover_height := COVER_WIDTH * data.size.y / data.size.z
	if known:
		var cover := BookCover.new()
		cover.data = data
		cover.custom_minimum_size = Vector2(COVER_WIDTH, cover_height)
		box.add_child(cover)
		var title := _label(data.title, 12, TEXT_COLOR)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(COVER_WIDTH, 0)
		title.max_lines_visible = 3
		box.add_child(title)
		card.tooltip_text = "%s\n%s" % [data.title, data.author]
	else:
		# Noch nicht entdeckt: ein Platzhalter mit Fragezeichen
		var unknown := PanelContainer.new()
		unknown.custom_minimum_size = Vector2(COVER_WIDTH, cover_height)
		unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.16, 0.12, 0.9)
		style.border_color = Color(0.55, 0.42, 0.28, 0.5)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		unknown.add_theme_stylebox_override("panel", style)
		var mark := _label("?", 40, Color(0.85, 0.78, 0.68, 0.5))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_child(mark)
		box.add_child(unknown)
		var hint := _label("Noch nicht entdeckt", 12, MUTED_COLOR)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(COVER_WIDTH, 0)
		box.add_child(hint)
	var note: String = entry.get("note", "")
	if not note.is_empty():
		var note_label := _label(note, 11, MUTED_COLOR)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.custom_minimum_size = Vector2(COVER_WIDTH, 0)
		box.add_child(note_label)
	if card.disabled and known and interactive:
		card.modulate.a = 0.75
	if entry.get("held", false):
		# In der Hand: ausgegraut, darüber ein kleines Handsymbol
		box.modulate = Color(1, 1, 1, 0.45)
		var badge := HandBadge.new()
		badge.position = Vector2(CARD_WIDTH - 34.0, 4.0)
		card.add_child(badge)
		card.tooltip_text = "In der Hand – Klick legt es zurück ins Lager"
	# Kachel hoch genug für Cover, bis zu drei Titelzeilen und den kleinen Text
	card.custom_minimum_size.y = cover_height + 92.0
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style


## Kleines rundes Abzeichen mit einer Hand (das Buch ist gerade in der Hand).
class HandBadge:
	extends Control

	const SIZE := 30.0
	const BACK_COLOR := Color(0.2, 0.14, 0.1, 0.92)
	const LINE_COLOR := Color(0.96, 0.78, 0.48)

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size = Vector2(SIZE, SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(SIZE, SIZE) / 2.0
		draw_circle(c, SIZE / 2.0, BACK_COLOR)
		draw_arc(c, SIZE / 2.0 - 1.0, 0.0, TAU, 32, Color(LINE_COLOR, 0.6), 1.5, true)
		# Handfläche und vier Finger, dazu der Daumen
		var palm := Rect2(c + Vector2(-5.0, -1.0), Vector2(10.0, 8.0))
		draw_rect(palm, LINE_COLOR)
		for i in 4:
			var x := -4.5 + i * 3.0
			draw_line(c + Vector2(x, 0.0), c + Vector2(x, -8.0 + absf(i - 1.5) * 1.2), LINE_COLOR, 2.2, true)
		draw_line(c + Vector2(-5.0, 4.0), c + Vector2(-8.5, 0.5), LINE_COLOR, 2.2, true)
