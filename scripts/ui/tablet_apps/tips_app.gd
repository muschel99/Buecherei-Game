extends TabletApp
## App "Tipps & Tricks" auf dem Theken-Tablet: ein kleines, gemütliches Büchlein.
##
## Zuerst das Inhaltsverzeichnis (Themen mit Symbol und Seitenzahl). Ein Klick auf ein Thema
## schlägt seine erste Seite auf. Mit den Pfeilen links und rechts neben dem Büchlein blättert
## man vor und zurück (über alle Themen hinweg, wie in einem Buch); das Symbol oben links
## führt zurück ins Inhaltsverzeichnis.
## Die Texte stehen in TIPS_PATH (data/tips/tips.txt) – dort ändern, ergänzen oder umsortieren;
## wie die Datei aufgebaut ist, steht oben in der Datei selbst.

const TIPS_PATH := "res://data/tips/tips.txt"
## Farben des Papiers und der Schrift
const PAPER_COLOR := Color(0.96, 0.92, 0.84)
const PAPER_EDGE_COLOR := Color(0.83, 0.75, 0.62)
const INK_COLOR := Color(0.33, 0.23, 0.16)
const SOFT_INK_COLOR := Color(0.55, 0.44, 0.34)
const KEY_INK_COLOR := Color(0.62, 0.36, 0.16)
const KEY_CAP_COLOR := Color(0.89, 0.83, 0.72)
## Breite des Büchleins (Bildpunkte bei 1600 x 900)
const PAGE_WIDTH := 660.0
## So lange dauert das sanfte Umblättern (Sekunden)
const TURN_TIME := 0.16

## Themen aus der Datei: [{ "name", "symbol", "pages": [{ "title", "paragraphs": [Text, …] }] }]
var topics: Array[Dictionary] = []
## Alle Seiten hintereinander: [{ "topic": Nummer, "page": Seite im Thema }]
var pages: Array[Dictionary] = []
## Aufgeschlagene Seite (-1 = Inhaltsverzeichnis)
var current_page := -1

var _contents_button: TabletIconButton
var _prev_button: TabletIconButton
var _next_button: TabletIconButton
var _paper: PanelContainer
var _content: VBoxContainer
var _turn_tween: Tween


func _ready() -> void:
	topics = load_tips(TIPS_PATH)
	for t in topics.size():
		for p in (topics[t].pages as Array).size():
			pages.append({"topic": t, "page": p})
	_build()


## Beim Öffnen der App immer das Inhaltsverzeichnis.
func app_opened() -> void:
	current_page = -1


func refresh() -> void:
	_show_current()


## Schlägt eine Seite auf (-1 = Inhaltsverzeichnis), mit sanftem Umblättern.
func open_page(index: int) -> void:
	index = clampi(index, -1, pages.size() - 1)
	if index == current_page:
		return
	current_page = index
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_property(_content, "modulate:a", 0.0, TURN_TIME / 2.0)
	_turn_tween.tween_callback(_show_current)
	_turn_tween.tween_property(_content, "modulate:a", 1.0, TURN_TIME / 2.0)


func open_topic(topic: int) -> void:
	for i in pages.size():
		if pages[i].topic == topic:
			open_page(i)
			return


func next_page() -> void:
	open_page(current_page + 1)


func previous_page() -> void:
	open_page(current_page - 1)


func show_contents() -> void:
	open_page(-1)


## Liest die Tipps-Datei (Aufbau: siehe Kopf der Datei).
static func load_tips(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("Tipps: Die Datei '%s' fehlt." % path)
		return result
	var topic: Dictionary = {}
	var page: Dictionary = {}
	var paragraph := ""
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		if line.begins_with("==") or line.begins_with("=") or line.is_empty():
			# Ein Absatz ist zu Ende
			if not paragraph.is_empty() and not page.is_empty():
				(page.paragraphs as Array).append(paragraph)
			paragraph = ""
		if line.begins_with("=="):
			if topic.is_empty():
				continue  # Seite ohne Thema: überspringen
			page = {"title": line.substr(2).strip_edges(), "paragraphs": []}
			(topic.pages as Array).append(page)
		elif line.begins_with("="):
			var parts := line.substr(1).split("|")
			topic = {"name": parts[0].strip_edges(), "symbol": parts[1].strip_edges() if parts.size() > 1 else "star",
				"pages": []}
			page = {}
			result.append(topic)
		elif not line.is_empty() and not page.is_empty():
			paragraph = line if paragraph.is_empty() else paragraph + " " + line
	if not paragraph.is_empty() and not page.is_empty():
		(page.paragraphs as Array).append(paragraph)
	# Themen ohne Seiten zeigen wir nicht
	return result.filter(func(entry: Dictionary) -> bool: return not (entry.pages as Array).is_empty())


# --- Anzeige ---

func _show_current() -> void:
	clear(_content)
	_content.modulate.a = 1.0 if not (_turn_tween and _turn_tween.is_running()) else _content.modulate.a
	if current_page < 0 or pages.is_empty():
		_show_contents_page()
	else:
		_show_tip_page(current_page)
	_contents_button.visible = current_page >= 0
	_prev_button.disabled = current_page < 0
	_next_button.disabled = current_page >= pages.size() - 1


func _show_contents_page() -> void:
	var title := _ink_label("Tipps & Tricks", 30, INK_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var sub := _ink_label("Inhalt", 16, SOFT_INK_COLOR)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)
	_content.add_child(_ornament())
	if topics.is_empty():
		_content.add_child(_ink_label("Hier stehen bald ein paar Tipps.", 17, SOFT_INK_COLOR))
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	_content.add_child(list)
	for t in topics.size():
		list.add_child(_create_contents_entry(t))


## Eine Zeile im Inhaltsverzeichnis: Symbol, Thema, Pünktchen, Seitenzahl.
func _create_contents_entry(topic: int) -> Button:
	var entry := Button.new()
	entry.name = "Topic%d" % topic
	entry.focus_mode = Control.FOCUS_NONE
	entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entry.custom_minimum_size.y = 46
	entry.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := TabletFrame.make_panel_style(Color(PAPER_EDGE_COLOR, 0.35), 8, 0.0)
	entry.add_theme_stylebox_override("hover", hover)
	entry.add_theme_stylebox_override("pressed", hover)
	entry.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	entry.pressed.connect(open_topic.bind(topic))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(row)
	var symbol := TipSymbol.create(str(topics[topic].symbol), KEY_INK_COLOR, 28.0)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(symbol)
	var name_label := _ink_label(str(topics[topic].name), 19, INK_COLOR)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var dots := DottedLeader.new()
	dots.color = PAPER_EDGE_COLOR
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dots)
	var number := _ink_label(str(_first_page_of(topic) + 1), 17, SOFT_INK_COLOR)
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	return entry


func _show_tip_page(index: int) -> void:
	var topic: Dictionary = topics[pages[index].topic]
	var page: Dictionary = (topic.pages as Array)[pages[index].page]
	# Kopf: Symbol und Thema, darunter die Überschrift der Seite
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	_content.add_child(head)
	head.add_child(TipSymbol.create(str(topic.symbol), KEY_INK_COLOR, 24.0))
	var topic_label := _ink_label(str(topic.name), 15, SOFT_INK_COLOR)
	topic_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	topic_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(topic_label)
	var title := _ink_label(str(page.title), 26, INK_COLOR)
	title.name = "PageTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	_content.add_child(_ornament())
	for paragraph: String in page.paragraphs:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("normal_font_size", 19)
		text.add_theme_font_size_override("bold_font_size", 18)
		text.add_theme_color_override("default_color", INK_COLOR)
		text.add_theme_constant_override("line_separation", 6)
		text.text = to_bbcode(paragraph)
		_content.add_child(text)
	# Unten ein großes, ganz zartes Symbol des Themas, darunter die Seitenzahl
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var mark := TipSymbol.create(str(topic.symbol), Color(PAPER_EDGE_COLOR, 0.55), 72.0)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(mark)
	var number := _ink_label("– %d –" % (index + 1), 15, SOFT_INK_COLOR)
	number.name = "PageNumber"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(number)


## Text aus der Datei für die Anzeige: Tasten in spitzen Klammern (<E>) als kleine Tastenkappe.
static func to_bbcode(text: String) -> String:
	var safe := text.replace("[", "[lb]")
	var result := ""
	var regex := RegEx.create_from_string("<([^<>]+)>")
	var last := 0
	for found in regex.search_all(safe):
		result += safe.substr(last, found.get_start() - last)
		result += "[bgcolor=#%s][color=#%s][b] %s [/b][/color][/bgcolor]" % [KEY_CAP_COLOR.to_html(false),
			KEY_INK_COLOR.to_html(false), found.get_string(1)]
		last = found.get_end()
	return result + safe.substr(last)


func _first_page_of(topic: int) -> int:
	for i in pages.size():
		if pages[i].topic == topic:
			return i
	return 0


func _ink_label(text: String, font_size: int, color: Color) -> Label:
	var label := make_label(text, font_size, color)
	label.custom_minimum_size.x = 0
	return label


## Kleine Zierlinie unter Überschriften: Linie, Punkt, Linie.
func _ornament() -> Control:
	var line := Ornament.new()
	line.color = PAPER_EDGE_COLOR
	return line


# --- Aufbau ---

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# Oben links: zurück ins Inhaltsverzeichnis
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 44  # gleich hoch, ob der Knopf zu sehen ist oder nicht
	root.add_child(top)
	_contents_button = make_icon_button(TabletIconButton.Icon.CONTENTS, show_contents)
	_contents_button.name = "ContentsButton"
	_contents_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_contents_button)
	# Mitte: Pfeil, Büchlein, Pfeil
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 28)
	root.add_child(middle)
	_prev_button = make_icon_button(TabletIconButton.Icon.BACK, previous_page, "Zurückblättern")
	_prev_button.name = "PrevButton"
	_prev_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(_prev_button)
	_paper = PanelContainer.new()
	_paper.name = "Paper"
	_paper.custom_minimum_size.x = PAGE_WIDTH
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = PAPER_COLOR
	paper_style.border_color = PAPER_EDGE_COLOR
	paper_style.border_width_left = 6  # angedeuteter Buchrücken
	paper_style.border_width_bottom = 3
	paper_style.set_corner_radius_all(10)
	paper_style.corner_radius_top_left = 4
	paper_style.corner_radius_bottom_left = 4
	paper_style.anti_aliasing = true
	paper_style.shadow_color = Color(0, 0, 0, 0.35)
	paper_style.shadow_size = 10
	paper_style.shadow_offset = Vector2(2, 4)
	paper_style.content_margin_left = 56
	paper_style.content_margin_right = 50
	paper_style.content_margin_top = 34
	paper_style.content_margin_bottom = 22
	_paper.add_theme_stylebox_override("panel", paper_style)
	middle.add_child(_paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_paper.add_child(_content)
	_next_button = make_icon_button(TabletIconButton.Icon.NEXT, next_page, "Weiterblättern")
	_next_button.name = "NextButton"
	_next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(_next_button)


## Pünktchen zwischen Thema und Seitenzahl im Inhaltsverzeichnis.
class DottedLeader:
	extends Control

	var color := Color(0.8, 0.7, 0.6)

	func _init() -> void:
		custom_minimum_size = Vector2(20, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 4.0
		while x < size.x - 2.0:
			draw_circle(Vector2(x, size.y - 2.0), 1.3, color)
			x += 8.0


## Zierlinie: zwei feine Linien mit einem kleinen Punkt in der Mitte.
class Ornament:
	extends Control

	var color := Color(0.8, 0.7, 0.6)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_line(c + Vector2(-70, 0), c + Vector2(-10, 0), color, 1.5, true)
		draw_line(c + Vector2(10, 0), c + Vector2(70, 0), color, 1.5, true)
		draw_circle(c, 3.0, color)
