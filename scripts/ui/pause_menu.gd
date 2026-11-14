extends CanvasLayer
## Pausenmenü als Notizbuch (seit Testrunde 7b, Wunsch der Entwicklerin): Ein zugeklapptes Notizbuch gleitet von unten ins
## Bild und klappt auf. Die erste Doppelseite zeigt nur das Wichtigste (Weiterspielen, Speichern, Speichern und beenden, dazu
## der heutige Tag). Bunte Haftnotizen am Rand führen zu den Kategorien: ein Klick blättert dorthin – die Notizen der
## umgeblätterten Seiten kleben danach auf der linken Seite, die übrigen rechts (wie in einem echten Buch).
## Jede Kategorie ist eine Doppelseite (SPREADS). Die Einstellungen kommen aus Settings.DEFINITIONS (je „section“ eine Seite);
## ein neuer Abschnitt, der in SPREADS fehlt, bekommt von selbst eine eigene Doppelseite.
##
## Esc öffnet es nur, wenn nichts anderes offen ist (MenuStack), und klappt es wieder zu. Das Spiel steht still (der Baum ist
## angehalten, die Uhr auch), die Maus ist frei. Läuft auch bei pausiertem Spiel (Process Mode "Always").

const INK := Color(0.24, 0.17, 0.12)
const INK_SOFT := Color(0.4, 0.31, 0.23)
const INK_FAINT := Color(0.4, 0.31, 0.23, 0.5)
const PAGE := Color(0.98, 0.95, 0.87)
const PAGE_LINE := Color(0.55, 0.62, 0.72, 0.18)
const COVER := Color(0.25, 0.33, 0.27)
const COVER_DARK := Color(0.17, 0.23, 0.19)
const GOLD := Color(0.86, 0.7, 0.4)
const ACCENT := Color(0.64, 0.24, 0.2)
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
		["E", "Benutzen: Lampen, Türen, Türschild, Sitzen, Kartons, Tablet, Bett, Katze streicheln, Spielzeug nehmen und werfen"],
		["E an der Theke", "Hinter der Theke: Ausweis nehmen, stempeln, Bücher scannen"],
		["Esc", "Schließt, was offen ist – sonst dieses Notizbuch"],
		["F3", "Bilder pro Sekunde anzeigen"],
	],
	"Bücher": [
		["Rechtsklick", "Buch nehmen (Regal, Tisch, Rückgabekasten …) – bis zu %d tragen"],
		["Linksklick", "Buch obenauf dort ablegen, wo du hinschaust"],
		["Linksklick halten", "Am Regal: alle passenden Bücher einräumen"],
		["Rechtsklick Kiste", "Hinter der Theke: ein Buch dieses Genres aus dem Lager"],
		["R", "Am Regal: Fächer, auffüllen, sortieren – sonst: Wo steht welches Buch?"],
		["Mausrad", "Buch vor dem Ablegen drehen"],
		["E beim Tragen", "Anderes Buch obenauf (Umschalt + E: zurück)"],
		["Q halten", "Alle getragenen Bücher zurück in die Kisten"],
		["E am Rückgabekasten", "So viele Bücher nehmen, wie in die Hände passen"],
	],
	"Gestalten": [
		["Tab", "Gestaltungsmodus öffnen und schließen"],
		["Y / X", "Kategorie zurück / vor"],
		["C / V", "Möbel zurück / vor (dazwischen: nichts ausgewählt)"],
		["Rechtsklick", "Angeschautes Möbel aufnehmen"],
		["Linksklick", "Abstellen bzw. streichen"],
		["Mausrad", "Drehen – mit leerer Hand: Möbel auswählen"],
		["Mausrad-Klick", "Weglegen (ins Inventar)"],
		["F · G · H", "Filter (Mauszeiger frei) · Raster · Tastenhilfe am unteren Rand"],
	],
}
const TEST_KEYS := [["F2", "Eine Stunde vorspringen"], ["F4", "Malstil an/aus"], ["F9", "Bücher in den Rückgabekasten"],
	["F10", "%s Testgeld"], ["F11", "Alle Fassaden-Varianten frei"]]

## Doppelseiten: Haftnotiz (Wort, Farbe), linke und rechte Seite. Seiten-Arten: start, actions, keys:<Name>, test,
## settings:<Abschnitt>[,<Abschnitt>] (mehrere Abschnitte untereinander).
const SPREADS := [
	{"tab": "Start", "color": Color(0.98, 0.86, 0.45), "left": "start", "right": "actions"},
	{"tab": "Steuerung", "color": Color(0.98, 0.66, 0.66), "left": "keys:Laufen", "right": "keys:Bücher"},
	{"tab": "Gestalten", "color": Color(0.67, 0.86, 0.68), "left": "keys:Gestalten", "right": "test"},
	{"tab": "Bild", "color": Color(0.66, 0.8, 0.95), "left": "settings:Bildschirm", "right": "settings:Grafik"},
	{"tab": "Ton & Spiel", "color": Color(0.82, 0.72, 0.94), "left": "settings:Ton", "right": "settings:Spiel,Oberfläche"},
]
## Kurze Erklärung unter jeder Einstellung (füllt die Seiten und hilft; fehlt eine, steht nichts darunter)
const SETTING_NOTES := {
	"display/window_mode": "Fenster oder ganzer Bildschirm.",
	"display/resolution": "Größe des Fensters (im Vollbild die Bildschirmauflösung).",
	"display/vsync": "Gegen Bildrisse beim Umsehen – an ist meist am ruhigsten.",
	"display/max_fps": "Weniger Bilder pro Sekunde sparen Strom und halten den Rechner leise.",
	"graphics/quality": "Niedrig für ältere Rechner, Hoch für weiche Schatten und mehr Pflanzen-Schatten.",
	"graphics/field_of_view": "Wie viel man auf einmal sieht – weiter für breite Bildschirme.",
	"graphics/paint_style": "Aquarell: alles wie gemalt, mit feinen Tuschelinien.",
	"graphics/show_fps": "Kleine Zahl oben in der Ecke – nur zum Nachschauen.",
	"interface/hints": "Was unter der Bildmitte neben den Tasten steht.",
	"interface/build_key_help": "Tastenleiste am unteren Rand im Gestaltungsmodus.",
	"audio/music_volume": "Die ruhige Musik im Hintergrund.",
	"audio/ambience_volume": "Straße, Vögel, Wind und Kaminfeuer.",
	"audio/effects_volume": "Bücher, Türen, Schritte, Tablet und Kasse.",
	"audio/voices_volume": "Kurze Laute der Passanten und Besucher.",
	"gameplay/day_length": "So viele Minuten dauert ein ganzer Tag in der Bücherei.",
}
## Farben für Haftnotizen weiterer Abschnitte (neue Einstellungen)
const EXTRA_COLORS := [Color(0.98, 0.78, 0.55), Color(0.7, 0.9, 0.88), Color(0.95, 0.75, 0.86)]

## Zeiten der Animationen (Sekunden)
const SLIDE_TIME := 0.38
const FLIP_TIME := 0.24
const TURN_TIME := 0.13

var _spreads: Array[Dictionary] = []
var _current := 0
var _busy := false
var _book: NotebookShape
var _left: VBoxContainer
var _right: VBoxContainer
var _cover: CoverShape
var _flip: PageShape
var _tabs: Array[TabNote] = []
var _dimmer: ColorRect
var _resolution_button: OptionButton
var _window_mode_button: OptionButton
var _resolution_hint: Label
var _tween: Tween


func _ready() -> void:
	hide()
	_spreads = _make_spreads()
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


## Öffnen: das zugeklappte Notizbuch gleitet von unten herein, dann klappt der Deckel auf (erste Doppelseite).
func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	Settings.apply_frame_limit()  # im Pausenmenü weniger Bilder pro Sekunde (spart Strom)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_current = 0
	_fill_spread(0)
	await get_tree().process_frame  # Größen stehen erst jetzt fest
	_place_pages()
	_play_open()


## Für Testbilder: sofort offen auf der Doppelseite mit diesem Namen (Haftnotiz oder Seitentitel).
func open_instant(page_name: String = "") -> void:
	show()
	_current = 0
	for i in _spreads.size():
		var spread: Dictionary = _spreads[i]
		if spread.tab == page_name or String(spread.left).ends_with(page_name) or String(spread.right).contains(page_name):
			_current = i
	_fill_spread(_current)
	_cover.visible = false
	_book.closed = false
	_book.queue_redraw()
	_set_pages_visible(true)
	_place_pages()


func resume() -> void:
	if _busy:
		return
	_play_close()


func _finish_close() -> void:
	hide()
	get_tree().paused = false
	Settings.apply_frame_limit()
	# Maus so einstellen, wie es das gerade Geöffnete braucht (z. B. Katalog = Mauszeiger sichtbar)
	MenuStack.restore_mouse_mode()


# --- Animationen ---

func _play_open() -> void:
	_busy = true
	var w := _book.size.x
	_book.pivot_offset = _book.size / 2.0
	# zugeklappt: nur der Deckel (rechte Hälfte), das Buch so verschoben, dass er mittig steht
	_book.closed = true
	_book.queue_redraw()
	_set_pages_visible(false)
	_cover.visible = true
	_cover.scale = Vector2.ONE
	_cover.modulate.a = 1.0
	_cover.front = true
	_cover.queue_redraw()
	var rest := _book.position
	_book.position = rest + Vector2(-w / 4.0, get_viewport().get_visible_rect().size.y)
	_book.rotation = deg_to_rad(-4.0)
	_dimmer.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_book, "position", rest + Vector2(-w / 4.0, 0.0), SLIDE_TIME)
	_tween.parallel().tween_property(_book, "rotation", 0.0, SLIDE_TIME)
	_tween.parallel().tween_property(_dimmer, "modulate:a", 1.0, SLIDE_TIME)
	# Deckel klappt um den Rücken nach links auf, dabei rückt das Buch in die Mitte
	_tween.tween_property(_cover, "scale:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 8.0, 0.0), FLIP_TIME)
	_tween.tween_callback(func() -> void:
		_cover.front = false
		_cover.queue_redraw()
		_book.closed = false
		_book.queue_redraw()
		_set_pages_visible(true)
		_hide_tabs()  # die Haftnotizen kommen erst, wenn das Buch ganz offen ist
		_right_holder().modulate.a = 1.0
		_left_holder().modulate.a = 0.0)
	_tween.tween_property(_cover, "scale:x", -1.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_book, "position", rest, FLIP_TIME)
	_tween.parallel().tween_property(_left_holder(), "modulate:a", 1.0, FLIP_TIME)
	_tween.parallel().tween_property(_cover, "modulate:a", 0.0, FLIP_TIME).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_cover.visible = false
		_layout_tabs(false)
		for tab in _tabs:
			tab.visible = true
		_busy = false)


func _play_close() -> void:
	_busy = true
	var w := _book.size.x
	var rest := _book.position
	if _tween:
		_tween.kill()
	# zur ersten Seite zurück (Notizen wandern nach rechts), dann Deckel zu, nach unten hinaus
	_hide_tabs()
	_cover.visible = true
	_cover.modulate.a = 1.0
	_cover.front = false
	_cover.scale = Vector2(-1.0, 1.0)
	_cover.queue_redraw()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_left_holder(), "modulate:a", 0.0, FLIP_TIME * 0.8)
	_tween.parallel().tween_property(_cover, "scale:x", 0.0, FLIP_TIME).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 8.0, 0.0), FLIP_TIME)
	_tween.tween_callback(func() -> void:
		_cover.front = true
		_cover.queue_redraw()
		_set_pages_visible(false)
		_book.closed = true
		_book.queue_redraw())
	_tween.tween_property(_cover, "scale:x", 1.0, FLIP_TIME).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 4.0, 0.0), FLIP_TIME)
	_tween.tween_property(_book, "position", rest + Vector2(-w / 4.0, get_viewport().get_visible_rect().size.y), SLIDE_TIME * 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_dimmer, "modulate:a", 0.0, SLIDE_TIME * 0.8)
	_tween.tween_callback(func() -> void:
		_book.position = rest
		_cover.visible = false
		_book.closed = false
		_set_pages_visible(true)
		_busy = false
		_finish_close())


## Zu einer Doppelseite blättern: je umgeblätterte Seite schwingt ein Blatt über den Falz (höchstens drei, schnell).
func _turn_to(index: int) -> void:
	if _busy or index == _current:
		return
	_busy = true
	Audio.play("books/page", -6.0, Audio.vary(0.08))
	var forward := index > _current
	var flips := mini(absi(index - _current), 3)
	var half := _book.page_rect(true).size.x
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	for i in flips:
		var last := i == flips - 1
		tween.tween_callback(func() -> void:
			_flip.visible = true
			_flip.position = (_book.page_rect(false) if forward else _book.page_rect(true)).position
			_flip.size = Vector2(half, _book.page_rect(true).size.y)
			_flip.pivot_offset = Vector2(0.0 if forward else half, 0.0)
			_flip.scale = Vector2.ONE)
		tween.tween_property(_flip, "scale:x", 0.0, TURN_TIME).set_ease(Tween.EASE_IN)
		if last:
			tween.tween_callback(func() -> void:
				_current = index
				_fill_spread(index)
				_layout_tabs(false))
		tween.tween_callback(func() -> void:
			_flip.position = (_book.page_rect(true) if forward else _book.page_rect(false)).position
			_flip.pivot_offset = Vector2(half if forward else 0.0, 0.0))
		tween.tween_property(_flip, "scale:x", 1.0, TURN_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_flip.visible = false
		_busy = false)


# --- Aufbau ---

func _make_spreads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used: Array[String] = []
	for spread: Dictionary in SPREADS:
		var copy := spread.duplicate()
		if copy.right == "test" and not GameConfig.debug_keys_enabled:
			copy.right = "tips"
		result.append(copy)
		for side: String in [String(copy.left), String(copy.right)]:
			if side.begins_with("settings:"):
				used.append_array(side.trim_prefix("settings:").split(","))
	# Abschnitte der Einstellungen, die keine Doppelseite haben (neue Einstellungen): je zwei eine Doppelseite
	var missing: Array[String] = []
	for definition in Settings.DEFINITIONS:
		var section := String(definition.section)
		if not section in used and not section in missing:
			missing.append(section)
	var i := 0
	while i < missing.size():
		result.append({"tab": missing[i], "color": EXTRA_COLORS[(i / 2) % EXTRA_COLORS.size()], "left": "settings:" + missing[i],
			"right": "settings:" + missing[i + 1] if i + 1 < missing.size() else "tips"})
		i += 2
	return result


func _build() -> void:
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.08, 0.05, 0.03, 0.55)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dimmer)
	# Das Notizbuch: feste Anteile des Bildes (passt bei jeder Größe aufs Bild); rechts Platz für die Haftnotizen
	_book = NotebookShape.new()
	_book.anchor_left = 0.09
	_book.anchor_right = 0.88
	_book.anchor_top = 0.07
	_book.anchor_bottom = 0.93
	add_child(_book)
	for side: String in ["Left", "Right"]:
		var holder := MarginContainer.new()
		holder.name = side + "Page"
		_book.add_child(holder)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		holder.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 12)
		scroll.add_child(box)
		if side == "Left":
			_left = box
		else:
			_right = box
	_book.resized.connect(_place_pages)
	_flip = PageShape.new()
	_flip.visible = false
	_book.add_child(_flip)
	_cover = CoverShape.new()
	_cover.visible = false
	_book.add_child(_cover)
	for i in _spreads.size():
		var tab := TabNote.new()
		tab.text = String(_spreads[i].tab)
		tab.color = _spreads[i].color
		tab.index = i
		tab.pressed.connect(func() -> void: _turn_to(tab.index))
		_book.add_child(tab)
		_tabs.append(tab)


func _left_holder() -> Control:
	return _book.get_node("LeftPage") as Control


func _right_holder() -> Control:
	return _book.get_node("RightPage") as Control


func _set_pages_visible(on: bool) -> void:
	_left_holder().visible = on
	_right_holder().visible = on
	for tab in _tabs:
		tab.visible = on


## Seitenränder: Inhalt innerhalb der Seiten, mit Luft zum Falz.
func _place_pages() -> void:
	for pair: Array in [[_left_holder(), _book.page_rect(true), true], [_right_holder(), _book.page_rect(false), false]]:
		var holder: MarginContainer = pair[0]
		var rect: Rect2 = pair[1]
		holder.position = rect.position
		holder.size = rect.size
		holder.add_theme_constant_override("margin_left", 46 if pair[2] else 40)
		holder.add_theme_constant_override("margin_right", 40 if pair[2] else 46)
		holder.add_theme_constant_override("margin_top", 34)
		holder.add_theme_constant_override("margin_bottom", 30)
	var cover_rect := _book.page_rect(false).grow(10.0)
	_cover.position = cover_rect.position
	_cover.size = cover_rect.size
	_cover.pivot_offset = Vector2(0.0, cover_rect.size.y / 2.0)
	_layout_tabs(false)


## Haftnotizen: die der schon umgeblätterten Doppelseiten (bis zur aktuellen) links, die übrigen rechts; untereinander
## versetzt wie echte Notizen. Die aktuelle ist etwas weiter herausgezogen.
func _layout_tabs(_instant: bool) -> void:
	if _tabs.is_empty() or _book.size.x <= 0.0:
		return
	var left_rect := _book.page_rect(true)
	var right_rect := _book.page_rect(false)
	var step := minf(78.0, (right_rect.size.y - 60.0) / maxf(1.0, _tabs.size()))
	var font := SERIF_ITALIC
	var widest := 0.0
	for tab in _tabs:
		widest = maxf(widest, font.get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var tab_width := maxf(118.0, widest + 52.0)
	for tab in _tabs:
		var on_left := tab.index <= _current
		tab.on_left = on_left
		tab.selected = tab.index == _current
		tab.size = Vector2(tab_width, step - 8.0)
		var y := right_rect.position.y + 30.0 + tab.index * step
		if on_left:
			tab.position = Vector2(left_rect.position.x - tab.size.x + (28.0 if not tab.selected else 14.0), y)
		else:
			tab.position = Vector2(right_rect.end.x - 28.0, y)
		tab.queue_redraw()


func _hide_tabs() -> void:
	for tab in _tabs:
		tab.visible = false


# --- Inhalt der Seiten ---

func _fill_spread(index: int) -> void:
	var spread: Dictionary = _spreads[index]
	_resolution_button = null
	_window_mode_button = null
	_resolution_hint = null
	for pair: Array in [[_left, String(spread.left)], [_right, String(spread.right)]]:
		var box: VBoxContainer = pair[0]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		_fill_page(box, pair[1])
	_refresh_resolution()


func _fill_page(box: VBoxContainer, kind: String) -> void:
	if kind == "start":
		_fill_start(box)
	elif kind == "actions":
		_fill_actions(box)
	elif kind.begins_with("keys:"):
		var page_name := kind.trim_prefix("keys:")
		_heading(box, page_name)
		_fill_keys(box, CONTROLS.get(page_name, []))
	elif kind == "test":
		_heading(box, "Testtasten")
		box.add_child(_text("Nur zum Ausprobieren – sie lassen sich in GameConfig alle auf einmal abschalten.", SERIF_ITALIC, 15, INK_SOFT))
		_fill_keys(box, TEST_KEYS)
	elif kind == "tips":
		_heading(box, "Notizen")
		box.add_child(_text("Mehr Tipps stehen im Büchlein „Tipps & Tricks“ auf dem Tablet an der Theke.", SERIF_ITALIC, 17, INK_SOFT))
	elif kind.begins_with("settings:"):
		var first := true
		for section in kind.trim_prefix("settings:").split(","):
			if not first:
				box.add_child(_spacer(18))
			first = false
			_heading(box, section)
			_fill_settings(box, section)


## Erste Seite links: Titel, Datum und der heutige Tag in ein paar Zahlen.
func _fill_start(box: VBoxContainer) -> void:
	box.add_child(_text("Pause", SERIF_BOLD, 44, INK))
	box.add_child(_text("%s, Tag %d · %s Uhr" % [GameClock.weekday_name(), GameClock.day, GameClock.time_text()], SERIF_ITALIC, 19, INK_SOFT))
	box.add_child(_wavy_rule())
	box.add_child(_spacer(10))
	box.add_child(_text("Heute in der Bücherei", SERIF_BOLD, 21, INK))
	var t := Lending.today
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for row: Array in [["Besucher", str(int(t.get("visitors", 0)))], ["Ausgeliehen", str(int(t.get("borrowed", 0)))],
			["Zurückgebracht", str(int(t.get("returned", 0)))], ["Einnahmen", Wallet.format(int(t.get("income", 0)))],
			["In der Kasse", Wallet.format(Wallet.money)], ["Geöffnet", "ja" if Lending.is_open else "nein"]]:
		for cell: Label in [_text(row[0], SERIF, 18, INK_SOFT), _text(row[1], SERIF_BOLD, 18, INK)]:
			cell.autowrap_mode = TextServer.AUTOWRAP_OFF
			grid.add_child(cell)
	box.add_child(_spacer(16))
	box.add_child(_text("Die bunten Zettel am Rand führen zu Steuerung und Einstellungen.", SERIF_ITALIC, 16, INK_FAINT))


## Erste Seite rechts: die wichtigsten Knöpfe, groß und handschriftlich unterstrichen.
func _fill_actions(box: VBoxContainer) -> void:
	box.add_child(_spacer(40))
	var resume_button := _action_button("Weiterspielen")
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	var save := _action_button("Speichern")
	save.pressed.connect(func() -> void:
		SaveManager.save_game()
		save.text = "Gespeichert ✓")
	box.add_child(save)
	var quit := _action_button("Speichern und beenden")
	quit.pressed.connect(func() -> void: SaveManager.quit_game())
	box.add_child(quit)
	box.add_child(_spacer(30))
	box.add_child(_text("Esc klappt das Notizbuch wieder zu.", SERIF_ITALIC, 16, INK_FAINT))
	resume_button.call_deferred("grab_focus")


func _fill_keys(box: VBoxContainer, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 11)
	box.add_child(grid)
	for row: Array in rows:
		var key := Label.new()
		key.text = String(row[0])
		var key_box := StyleBoxFlat.new()
		key_box.bg_color = Color(1.0, 0.99, 0.95, 0.9)
		key_box.border_color = Color(INK.r, INK.g, INK.b, 0.4)
		key_box.set_border_width_all(1)
		key_box.set_corner_radius_all(6)
		key_box.content_margin_left = 6
		key_box.content_margin_right = 6
		key_box.content_margin_top = 1
		key_box.content_margin_bottom = 2
		key.add_theme_stylebox_override("normal", key_box)
		key.add_theme_font_override("font", SERIF_BOLD)
		key.add_theme_font_size_override("font_size", 15)
		key.add_theme_color_override("font_color", INK)
		key.custom_minimum_size = Vector2(150, 0)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(key)
		var text := String(row[1])
		if text.contains("%d"):
			text = text % GameConfig.max_carried_books
		elif text.contains("%s"):
			text = text % Wallet.format(GameConfig.debug_money_amount)
		var meaning := _text(text, SERIF, 17, INK_SOFT)
		meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meaning.custom_minimum_size = Vector2(160, 0)
		grid.add_child(meaning)


func _fill_settings(box: VBoxContainer, section: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for definition in Settings.DEFINITIONS:
		if definition.section != section:
			continue
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.custom_minimum_size = Vector2(150, 0)
		texts.add_theme_constant_override("separation", 2)
		texts.add_child(_text(definition.label, SERIF, 18, INK))
		if SETTING_NOTES.has(definition.key):
			texts.add_child(_text(SETTING_NOTES[definition.key], SERIF_ITALIC, 14, INK_SOFT))
		grid.add_child(texts)
		var control := _create_control(definition)
		control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(control)
	if section == "Bildschirm":
		_resolution_hint = _text("", SERIF_ITALIC, 15, INK_SOFT)
		box.add_child(_resolution_hint)


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
			var number := _text("%d %%" % int(slider.value), SERIF, 16, INK)
			number.custom_minimum_size = Vector2(52, 0)
			number.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	control.custom_minimum_size = Vector2(200, 0)
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

func _text(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _heading(box: VBoxContainer, text: String) -> void:
	box.add_child(_text(text, SERIF_BOLD, 28, INK))
	box.add_child(_wavy_rule())


func _wavy_rule() -> Control:
	var rule := WavyRule.new()
	rule.custom_minimum_size = Vector2(0, 10)
	return rule


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Großer Knopf wie mit Tinte geschrieben; beim Darüberfahren rot unterstrichen.
func _action_button(text: String) -> Button:
	var button := InkButton.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", SERIF_BOLD)
	button.add_theme_font_size_override("font_size", 30)
	for state in ["font_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ACCENT)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 8
	empty.content_margin_bottom = 14
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(style, empty)
	return button


## Knopf mit handgezogener Linie darunter (rot, wenn die Maus darauf ist oder er gewählt ist).
class InkButton extends Button:
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var active := is_hovered() or has_focus()
		var y := size.y - 6.0
		var width := minf(size.x, get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size("font_size")).x + 8.0)
		var points := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			points.append(Vector2(t * width, y + sin(t * 9.0) * 1.5))
		draw_polyline(points, ACCENT if active else INK_FAINT, 2.5 if active else 1.5, true)


## Wellige Linie unter Überschriften (wie mit dem Füller gezogen).
class WavyRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var points := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var t := float(i) / n
			points.append(Vector2(t * size.x * 0.7, size.y / 2.0 + sin(t * 17.0) * 1.6))
		draw_polyline(points, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6), 2.0, true)


## Das Notizbuch: Einband aus grünem Leinen mit Gummiband, zwei linierte Seiten mit Schatten zum Falz, Blattkanten.
class NotebookShape extends Control:
	var closed := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	## Rechteck einer Seite (left = linke Seite).
	func page_rect(left: bool) -> Rect2:
		var inset := 22.0
		var mid := size.x / 2.0
		return Rect2(inset, inset, mid - inset, size.y - inset * 2.0) if left else Rect2(mid, inset, mid - inset, size.y - inset * 2.0)

	func _draw() -> void:
		if closed:
			return  # zugeklappt zeichnet nur der Deckel (CoverShape)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(12, 16), r.size), Color(0, 0, 0, 0.3))
		var cover := StyleBoxFlat.new()
		cover.bg_color = COVER
		cover.set_corner_radius_all(16)
		cover.border_color = COVER_DARK
		cover.set_border_width_all(3)
		draw_style_box(cover, r)
		var mid := size.x / 2.0
		var left := page_rect(true)
		var right := page_rect(false)
		# Blattkanten (mehrere Lagen unten und außen)
		for k in range(4, 0, -1):
			var shift := float(k) * 2.0
			var edge := Color(0.9, 0.85, 0.74).darkened(0.035 * k)
			draw_rect(Rect2(left.position.x - shift, left.position.y + shift, left.size.x + shift, left.size.y), edge)
			draw_rect(Rect2(mid, right.position.y + shift, right.size.x + shift, right.size.y), edge)
		draw_rect(left, PAGE)
		draw_rect(right, PAGE)
		# Linien wie im Notizbuch, ein roter Rand je Seite
		var y := left.position.y + 64.0
		while y < left.end.y - 16.0:
			draw_line(Vector2(left.position.x + 18.0, y), Vector2(left.end.x - 14.0, y), PAGE_LINE, 1.0)
			draw_line(Vector2(right.position.x + 14.0, y), Vector2(right.end.x - 18.0, y), PAGE_LINE, 1.0)
			y += 32.0
		draw_line(Vector2(left.position.x + 34.0, left.position.y), Vector2(left.position.x + 34.0, left.end.y), Color(0.85, 0.45, 0.42, 0.25), 1.5)
		draw_line(Vector2(right.end.x - 34.0, right.position.y), Vector2(right.end.x - 34.0, right.end.y), Color(0.85, 0.45, 0.42, 0.25), 1.5)
		# Schatten zum Falz hin
		for i in 18:
			var t := float(i) / 18.0
			var a := 0.17 * pow(1.0 - t, 2.0)
			draw_rect(Rect2(mid - 2.0 - (t + 1.0 / 18.0) * 48.0, left.position.y, 48.0 / 18.0 + 0.5, left.size.y), Color(0.3, 0.2, 0.1, a))
			draw_rect(Rect2(mid + 2.0 + t * 48.0, right.position.y, 48.0 / 18.0 + 0.5, right.size.y), Color(0.3, 0.2, 0.1, a))
		draw_line(Vector2(mid, left.position.y), Vector2(mid, left.end.y), Color(0.3, 0.2, 0.1, 0.35), 2.0)
		# Lesebändchen unten aus dem Falz
		draw_colored_polygon(PackedVector2Array([Vector2(mid + 10, size.y - 30), Vector2(mid + 24, size.y - 30),
			Vector2(mid + 24, size.y + 18), Vector2(mid + 17, size.y + 10), Vector2(mid + 10, size.y + 18)]), ACCENT)
		# leichtes Papierkorn
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 260:
			var p := Vector2(rng.randf_range(left.position.x, right.end.x), rng.randf_range(left.position.y, left.end.y))
			draw_rect(Rect2(p, Vector2(2, 2)), Color(0.55, 0.45, 0.3, 0.045))


## Deckel: vorn grünes Leinen mit Titelschild und Gummiband, innen (umgeklappt) Vorsatzpapier.
class CoverShape extends Control:
	var front := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.bg_color = COVER if front else Color(0.86, 0.8, 0.66)
		box.set_corner_radius_all(14)
		box.border_color = COVER_DARK
		box.set_border_width_all(3)
		draw_style_box(box, r)
		if not front:
			# Vorsatzpapier mit feinem Muster
			for x in range(30, int(size.x) - 20, 26):
				for y in range(30, int(size.y) - 20, 26):
					draw_circle(Vector2(x, y), 2.0, Color(0.5, 0.42, 0.3, 0.25))
			return
		# Titelschild
		var label_rect := Rect2(size.x * 0.18, size.y * 0.24, size.x * 0.64, size.y * 0.2)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.96, 0.92, 0.82)
		plate.set_corner_radius_all(8)
		plate.border_color = GOLD
		plate.set_border_width_all(2)
		draw_style_box(plate, label_rect)
		var font := SERIF_BOLD
		var title := "Notizbuch"
		var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
		draw_string(font, Vector2(label_rect.get_center().x - ts.x / 2.0, label_rect.get_center().y - 2.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
		var sub := "Cozy Bücherei"
		var ss := SERIF_ITALIC.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(SERIF_ITALIC, Vector2(label_rect.get_center().x - ss.x / 2.0, label_rect.get_center().y + 30.0), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK_SOFT)
		# Gummiband senkrecht
		draw_rect(Rect2(size.x - 46.0, 0.0, 12.0, size.y), Color(0.42, 0.13, 0.12))
		# Ecken aus Leder
		for corner: Vector2 in [Vector2(size.x, 0.0), Vector2(size.x, size.y)]:
			var d := 1.0 if corner.y == 0.0 else -1.0
			draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(-46.0, 0.0), corner + Vector2(0.0, 46.0 * d)]),
				COVER_DARK)


## Ein leeres Blatt, das beim Umblättern über den Falz schwingt.
class PageShape extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), PAGE.darkened(0.03))
		var y := 64.0
		while y < size.y - 16.0:
			draw_line(Vector2(14.0, y), Vector2(size.x - 14.0, y), PAGE_LINE, 1.0)
			y += 32.0
		for i in 12:
			var t := float(i) / 12.0
			draw_rect(Rect2(t * size.x, 0.0, size.x / 12.0 + 0.5, size.y), Color(0.3, 0.2, 0.1, 0.05 * sin(t * PI)))


## Haftnotiz am Seitenrand: bunter Zettel mit leicht schräger Kante und Wort; die aktuelle ist etwas weiter herausgezogen.
class TabNote extends Button:
	var color := Color.YELLOW
	var index := 0
	var on_left := false
	var selected := false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_font_override("font", SERIF_ITALIC)
		add_theme_font_size_override("font_size", 16)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			add_theme_color_override(state, Color(0, 0, 0, 0))  # Text zeichnet _draw
		var empty := StyleBoxEmpty.new()
		for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(style, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lift := 5.0 if is_hovered() else 0.0
		var shift := Vector2(-lift if on_left else lift, 0.0)
		draw_rect(Rect2(r.position + shift + Vector2(3, 4), r.size), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(r.position + shift, r.size), color.lightened(0.08) if selected else color)
		# Klebestreifen-Kante (etwas dunkler) dort, wo der Zettel unter der Seite steckt
		var glue_x := r.end.x - 26.0 if on_left else 0.0
		draw_rect(Rect2(Vector2(glue_x, 0.0) + shift, Vector2(26.0, size.y)), Color(color.darkened(0.12), 0.9))
		var font := SERIF_ITALIC
		var font_size := 16
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var text_x := (8.0 if on_left else 32.0) + shift.x
		var room := size.x - 40.0
		draw_string(font, Vector2(text_x + maxf(0.0, (room - text_width) / 2.0), size.y / 2.0 + 6.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, room, font_size, INK)
		if selected:
			draw_line(Vector2(text_x + 4.0, size.y / 2.0 + 10.0), Vector2(text_x + room - 4.0, size.y / 2.0 + 10.0), INK_SOFT, 1.0)
