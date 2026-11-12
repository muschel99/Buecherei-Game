extends CanvasLayer
## Pausenmenü als aufgeklapptes Buch (seit Etappe 7, Wunsch der Entwicklerin – vorher eine lange Liste, die nicht aufs Bild
## passte): links das Inhaltsverzeichnis mit Lesebändchen (Weiter, Steuerung in drei Seiten, je Bereich der Einstellungen
## eine Seite, Beenden), rechts die gewählte Seite. Die Einstellungs-Seiten bauen sich aus Settings.DEFINITIONS selbst
## (je „section“ eine Seite) – neue Einstellungen erscheinen also von allein. Jede Seite scrollt, falls sie einmal zu lang wird.
##
## Esc öffnet es nur, wenn nichts anderes offen ist (MenuStack), und schließt es wieder. Hält das Spiel an (die Uhr steht),
## gibt die Maus frei. Läuft auch bei pausiertem Spiel (Process Mode "Always").

const INK := Color(0.27, 0.19, 0.13)
const INK_SOFT := Color(0.42, 0.33, 0.25)
const INK_FAINT := Color(0.42, 0.33, 0.25, 0.55)
const PAGE := Color(0.97, 0.93, 0.84)
const COVER := Color(0.36, 0.17, 0.13)
const GOLD := Color(0.86, 0.68, 0.36)
const RIBBON := Color(0.62, 0.2, 0.18)
const SERIF := preload("res://assets/ui/fonts/DejaVuSerif.ttf")
const SERIF_BOLD := preload("res://assets/ui/fonts/DejaVuSerif-Bold.ttf")
const SERIF_ITALIC := preload("res://assets/ui/fonts/DejaVuSerif-Italic.ttf")

## Tastenhilfe: Seite → [[Taste, Bedeutung], …]
const CONTROLS := {
	"Laufen": [
		["W A S D", "Laufen"],
		["Umschalt", "Schneller laufen (gedrückt halten)"],
		["Leertaste", "Springen (im Sitzen: aufstehen)"],
		["Strg halten", "Hocken"],
		["Maus", "Umsehen"],
		["E", "Benutzen: Lampen, Tür, Schild, Sitzen, Kartons, Tablet, Bett, Katze streicheln, Spielzeug nehmen und werfen"],
		["Esc", "Schließt, was offen ist – sonst dieses Buch"],
		["F3", "Bilder pro Sekunde anzeigen"],
	],
	"Bücher": [
		["Rechtsklick", "Buch nehmen (Regal, Tisch, Rückgabekasten …) – bis zu %d tragen"],
		["Linksklick", "Buch obenauf genau dort ablegen, wo du hinschaust"],
		["Linksklick halten", "Am Regal: alle passenden Bücher einräumen, ab dem Fach, auf das du schaust"],
		["R", "Bücher-Menü (überall): Bücher aus dem Lager nehmen – am Regal auch Genre je Fach, auffüllen, sortieren"],
		["Mausrad", "Beim Tragen: Buch vor dem Ablegen drehen"],
		["E beim Tragen", "Anderes Buch obenauf (Umschalt + E: zurück), wenn das Angeschaute nichts mit E macht"],
		["Q halten", "Alle getragenen Bücher ins Lager legen"],
		["E am Rückgabekasten", "Innen neben der Tür: so viele Bücher nehmen, wie in die Hände passen"],
	],
	"Gestalten": [
		["Tab", "Gestaltungsmodus öffnen und schließen"],
		["Y / X", "Kategorie zurück / vor"],
		["C / V", "Möbel zurück / vor (dazwischen: nichts ausgewählt)"],
		["Rechtsklick", "Angeschautes Möbel aufnehmen"],
		["Linksklick", "Abstellen bzw. streichen"],
		["Mausrad", "Drehen"],
		["Mausrad-Klick", "Weglegen (ins Inventar)"],
		["F · G · H", "Filter (Mauszeiger frei) · Raster · Tastenhilfe am unteren Rand"],
	],
}
const TEST_KEYS := [["F2", "Eine Stunde vorspringen"], ["F4", "Malstil an/aus"], ["F9", "Bücher in den Rückgabekasten"],
	["F10", "%s Testgeld"], ["F11", "Alle Fassaden-Varianten frei"]]

var _book: Control
var _toc: VBoxContainer
var _page_title: Label
var _page_body: VBoxContainer
var _page_holder: Control
var _scroll: ScrollContainer
var _clock_label: Label
var _resume_button: Button
var _entries: Array[Button] = []
var _current := ""
var _resolution_button: OptionButton
var _window_mode_button: OptionButton
var _resolution_hint: Label
var _tween: Tween


func _ready() -> void:
	hide()
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		resume()
	elif not MenuStack.close_top():
		open()  # Nichts anderes war offen
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Spiel anhalten, wenn man zu einem anderen Fenster wechselt
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameConfig.pause_on_focus_loss and not visible and is_inside_tree():
		open()


func open() -> void:
	show()
	get_tree().paused = true
	Settings.apply_frame_limit()  # im Pausenmenü weniger Bilder pro Sekunde (spart Strom)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clock_label.text = "%s, Tag %d · %s Uhr" % [GameClock.weekday_name(), GameClock.day, GameClock.time_text()]
	_show_page(_current if _current != "" else "Laufen", false)
	# Aufklappen: das Buch wächst aus der Mitte und wird sichtbar
	_book.pivot_offset = _book.size / 2.0
	_book.scale = Vector2(0.86, 0.94)
	_book.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_book, "scale", Vector2.ONE, 0.28)
	_tween.tween_property(_book, "modulate:a", 1.0, 0.18)
	_resume_button.grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false
	Settings.apply_frame_limit()
	# Maus so einstellen, wie es das gerade Geöffnete braucht (z. B. Katalog = Mauszeiger sichtbar)
	MenuStack.restore_mouse_mode()


# --- Aufbau ---

func _build() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.08, 0.05, 0.03, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	# Das Buch: feste Anteile des Bildes (passt bei jeder Größe aufs Bild)
	_book = BookShape.new()
	_book.anchor_left = 0.1
	_book.anchor_right = 0.9
	_book.anchor_top = 0.08
	_book.anchor_bottom = 0.92
	add_child(_book)
	var pages := HBoxContainer.new()
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.offset_left = 58
	pages.offset_right = -58
	pages.offset_top = 46
	pages.offset_bottom = -46
	pages.add_theme_constant_override("separation", 96)
	_book.add_child(pages)
	# Linke Seite: Titel, Uhr, Inhaltsverzeichnis, Weiter und Beenden
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	left.add_theme_constant_override("separation", 6)
	pages.add_child(left)
	var title := _label("Pause", SERIF_BOLD, 34, INK)
	left.add_child(title)
	_clock_label = _label("", SERIF_ITALIC, 16, INK_SOFT)
	left.add_child(_clock_label)
	left.add_child(_rule())
	_resume_button = _toc_button("Weiter spielen", "")
	_resume_button.pressed.connect(resume)
	left.add_child(_resume_button)
	left.add_child(_section_label("Steuerung"))
	_toc = left
	for page_name: String in CONTROLS:
		left.add_child(_toc_button(page_name, page_name))
	if GameConfig.debug_keys_enabled:
		left.add_child(_toc_button("Testtasten", "Testtasten"))
	left.add_child(_section_label("Einstellungen"))
	for section in _setting_sections():
		left.add_child(_toc_button(section, section))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var quit := _toc_button("Speichern und beenden", "")
	quit.pressed.connect(func() -> void: SaveManager.quit_game())
	left.add_child(quit)
	# Rechte Seite: Überschrift und Inhalt (scrollt, falls nötig)
	_page_holder = VBoxContainer.new()
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.add_theme_constant_override("separation", 10)
	pages.add_child(_page_holder)
	_page_title = _label("", SERIF_BOLD, 26, INK)
	_page_holder.add_child(_page_title)
	_page_holder.add_child(_rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_holder.add_child(_scroll)
	_page_body = VBoxContainer.new()
	_page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_page_body)


func _setting_sections() -> Array[String]:
	var sections: Array[String] = []
	for definition in Settings.DEFINITIONS:
		if not String(definition.section) in sections:
			sections.append(definition.section)
	return sections


## Seite zeigen (mit kurzem Umblättern, wenn turn): Inhalt neu bauen, gewähltes Lesebändchen markieren.
func _show_page(page_name: String, turn: bool = true) -> void:
	_current = page_name
	for entry in _entries:
		(entry as Button).set_meta("selected", entry.get_meta("page", "") == page_name)
		entry.queue_redraw()
	if turn:
		# Umblättern: die rechte Seite klappt zur Mitte hin weg und mit dem neuen Inhalt wieder auf
		_page_holder.pivot_offset = Vector2(0.0, _page_holder.size.y / 2.0)
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(_page_holder, "scale:x", 0.04, 0.12).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_page_holder, "modulate:a", 0.2, 0.12)
		tween.tween_callback(_fill_page.bind(page_name))
		tween.tween_property(_page_holder, "scale:x", 1.0, 0.16).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_page_holder, "modulate:a", 1.0, 0.16)
	else:
		_fill_page(page_name)


func _fill_page(page_name: String) -> void:
	for child in _page_body.get_children():
		_page_body.remove_child(child)
		child.queue_free()
	_resolution_button = null
	_window_mode_button = null
	_page_title.text = page_name
	_scroll.scroll_vertical = 0
	if CONTROLS.has(page_name):
		_fill_keys(CONTROLS[page_name])
	elif page_name == "Testtasten":
		_fill_keys(TEST_KEYS)
	else:
		_fill_settings(page_name)


func _fill_keys(rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 12)
	_page_body.add_child(grid)
	for row: Array in rows:
		var key := _label(row[0], SERIF_BOLD, 16, INK)
		key.custom_minimum_size = Vector2(150, 0)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(key)
		var text := String(row[1])
		if text.contains("%d"):
			text = text % GameConfig.max_carried_books
		elif text.contains("%s"):
			text = text % Wallet.format(GameConfig.debug_money_amount)
		var meaning := _label(text, SERIF, 16, INK_SOFT)
		meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meaning.custom_minimum_size = Vector2(200, 0)
		grid.add_child(meaning)


func _fill_settings(section: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	_page_body.add_child(grid)
	for definition in Settings.DEFINITIONS:
		if definition.section != section:
			continue
		var label := _label(definition.label, SERIF, 17, INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(160, 0)
		grid.add_child(label)
		grid.add_child(_create_control(definition))
	if section == "Bildschirm":
		_resolution_hint = _label("", SERIF_ITALIC, 14, INK_SOFT)
		_resolution_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page_body.add_child(_resolution_hint)
		_refresh_resolution()


## Passendes Bedienelement je Art der Einstellung.
func _create_control(definition: Dictionary) -> Control:
	var key: String = definition.key
	match definition.type:
		"choice":
			var choice := OptionButton.new()
			for option in definition.options:
				choice.add_item(option)
			choice.select(int(Settings.get_value(key)))
			if key == "display/window_mode":
				_window_mode_button = choice
			choice.item_selected.connect(func(index: int) -> void:
				Settings.set_value(key, index)
				_refresh_resolution())
			return _sized(choice)
		"toggle":
			var toggle := CheckButton.new()
			toggle.button_pressed = bool(Settings.get_value(key))
			toggle.text = "an" if toggle.button_pressed else "aus"
			# helle Schrift auf dem dunklen Knopf (wie die Auswahllisten)
			for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
				toggle.add_theme_color_override(state, Color(1.0, 0.96, 0.88))
			toggle.toggled.connect(func(on: bool) -> void:
				toggle.text = "an" if on else "aus"
				Settings.set_value(key, on))
			return _sized(toggle)
		"slider":
			var row := HBoxContainer.new()
			var slider := HSlider.new()
			slider.min_value = 0
			slider.max_value = 100
			slider.step = 5
			slider.value = float(Settings.get_value(key))
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var number := _label("%d %%" % int(slider.value), SERIF, 16, INK)
			number.custom_minimum_size = Vector2(52, 0)
			slider.value_changed.connect(func(v: float) -> void:
				number.text = "%d %%" % int(v)
				Settings.set_value(key, int(v)))
			row.add_child(slider)
			row.add_child(number)
			return _sized(row)
		"resolution":
			_resolution_button = OptionButton.new()
			_resolution_button.item_selected.connect(func(index: int) -> void:
				Settings.set_value(key, _resolution_button.get_item_text(index)))
			return _sized(_resolution_button)
	return Label.new()


func _sized(control: Control) -> Control:
	control.custom_minimum_size = Vector2(220, 0)
	return control


## Auflösungsliste füllen; im Vollbild gilt die Bildschirmauflösung. Läuft das Spiel im Editor eingebettet, sind Anzeige
## und Auflösung gesperrt.
func _refresh_resolution() -> void:
	if _resolution_button == null:
		return
	_resolution_button.clear()
	var current: String = Settings.get_value("display/resolution")
	var options := Settings.get_resolution_options()
	for i in options.size():
		_resolution_button.add_item(options[i])
		if options[i] == current:
			_resolution_button.select(i)
	_resolution_button.disabled = Settings.is_fullscreen() or Settings.is_embedded()
	if _window_mode_button:
		_window_mode_button.disabled = Settings.is_embedded()
	if _resolution_hint == null:
		return
	if Settings.is_embedded():
		_resolution_hint.text = "Das Spiel läuft im Godot-Editor eingebettet. Vollbild und Auflösung wirken nur, wenn das Spiel in einem eigenen Fenster läuft."
	elif Settings.is_fullscreen():
		_resolution_hint.text = "Im Vollbild wird die Auflösung des Bildschirms verwendet."
	else:
		_resolution_hint.text = ""


# --- Bausteine ---

func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _section_label(text: String) -> Label:
	var label := _label(text.to_upper(), SERIF_BOLD, 12, INK_FAINT)
	label.add_theme_constant_override("line_spacing", 0)
	var holder := label
	holder.custom_minimum_size = Vector2(0, 26)
	holder.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return holder


func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(INK.r, INK.g, INK.b, 0.18)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## Eintrag im Inhaltsverzeichnis: Text in Tinte; die gewählte Seite trägt ein rotes Lesebändchen am Rand.
func _toc_button(text: String, page: String) -> Button:
	var button := TocEntry.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", SERIF)
	button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_hover_color", RIBBON)
	button.add_theme_color_override("font_hover_pressed_color", RIBBON)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 22
	for box in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(box, empty)
	if page != "":
		button.set_meta("page", page)
		button.pressed.connect(func() -> void:
			if _current != page:
				_show_page(page))
		_entries.append(button)
	return button


## Eintrag mit Lesebändchen (gezeichnet, wenn gewählt).
class TocEntry extends Button:
	func _draw() -> void:
		if bool(get_meta("selected", false)):
			var h := size.y
			var ribbon := PackedVector2Array([Vector2(0, 4), Vector2(12, 4), Vector2(12, h - 4), Vector2(6, h - 9), Vector2(0, h - 4)])
			draw_colored_polygon(ribbon, RIBBON)


## Das Buch selbst: Ledereinband mit Goldlinie, zwei Seiten mit Schatten zum Falz und angedeuteten Blattkanten.
class BookShape extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# Einband mit weichem Schatten darunter
		draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.28))
		var cover := StyleBoxFlat.new()
		cover.bg_color = COVER
		cover.set_corner_radius_all(14)
		cover.border_color = COVER.darkened(0.35)
		cover.set_border_width_all(3)
		draw_style_box(cover, r)
		var gold := StyleBoxFlat.new()
		gold.draw_center = false
		gold.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
		gold.set_border_width_all(2)
		gold.set_corner_radius_all(10)
		draw_style_box(gold, r.grow(-9))
		# Blattkanten (mehrere Lagen unten und außen)
		var inset := 22.0
		var mid := size.x / 2.0
		for k in range(3, 0, -1):
			var shift := float(k) * 2.0
			var edge := Color(0.86, 0.8, 0.68).darkened(0.04 * k)
			draw_rect(Rect2(inset - shift, inset + shift, mid - inset + shift, size.y - inset * 2.0), edge)
			draw_rect(Rect2(mid, inset + shift, mid - inset + shift, size.y - inset * 2.0), edge)
		# die beiden Seiten
		var left := Rect2(inset, inset, mid - inset, size.y - inset * 2.0)
		var right := Rect2(mid, inset, mid - inset, size.y - inset * 2.0)
		draw_rect(left, PAGE)
		draw_rect(right, PAGE)
		# Schatten zum Falz hin (weicher Verlauf aus schmalen Streifen)
		for i in 18:
			var t := float(i) / 18.0
			var a := 0.16 * pow(1.0 - t, 2.0)
			draw_rect(Rect2(mid - 2.0 - (t + 1.0 / 18.0) * 44.0, inset, 44.0 / 18.0 + 0.5, left.size.y), Color(0.3, 0.2, 0.1, a))
			draw_rect(Rect2(mid + 2.0 + t * 44.0, inset, 44.0 / 18.0 + 0.5, right.size.y), Color(0.3, 0.2, 0.1, a))
		draw_line(Vector2(mid, inset), Vector2(mid, size.y - inset), Color(0.3, 0.2, 0.1, 0.35), 2.0)
		# ganz leichtes Papierkorn
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 220:
			var p := Vector2(rng.randf_range(inset, size.x - inset), rng.randf_range(inset, size.y - inset))
			draw_rect(Rect2(p, Vector2(2, 2)), Color(0.55, 0.45, 0.3, 0.05))
