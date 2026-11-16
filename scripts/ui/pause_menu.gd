extends CanvasLayer
## Pausenmenü als Notizbuch (seit Testrunde 7b, Wunsch der Entwicklerin): Ein zugeklapptes Notizbuch gleitet von unten ins
## Bild und klappt auf. Die erste Doppelseite zeigt nur das Wichtigste (Weiterspielen, Speichern, Speichern und beenden, dazu
## der heutige Tag). Bunte Haftnotizen am Rand führen zu den Kategorien: ein Klick blättert dorthin (immer nur ein Blatt). Jede
## Notiz klebt an IHRER Seite (Nachtest von Etappe 8): die der aufgeschlagenen Doppelseite oben auf der rechten Seite, die der
## anderen stecken zwischen den Blättern – umgeblätterte links, kommende rechts, hinter der aufgeschlagenen Seite (Ebene
## PagesShape über den Notizen). Normales Buchformat (GameConfig.pause_book_ratio), passt sich jeder Bildgröße an (_fit_book).
## Jede Kategorie ist eine Doppelseite (SPREADS). Die Einstellungen kommen aus Settings.DEFINITIONS (je „section“ eine Seite);
## ein neuer Abschnitt, der in SPREADS fehlt, bekommt von selbst eine eigene Doppelseite.
## Aussehen (Nachtest 7b: „weich, süß, gemütlich“): Handschrift (Caveat, Patrick Hand – assets/ui/fonts, OFL), runde und leicht
## unregelmäßige Formen (SoftShapes), Bedienelemente aus Papier (_paper_theme, InkCheck), kleine gezeichnete Blümchen;
## alle Bewegungen langsam und sanft (Zeiten in GameConfig pause_*).
##
## Esc öffnet es nur, wenn nichts anderes offen ist (MenuStack), und klappt es wieder zu. Das Spiel steht still (der Baum ist
## angehalten, die Uhr auch), die Maus ist frei. Läuft auch bei pausiertem Spiel (Process Mode "Always").

const INK := Color(0.33, 0.23, 0.19)
const INK_SOFT := Color(0.5, 0.39, 0.32)
const INK_FAINT := Color(0.5, 0.39, 0.32, 0.5)
const PAGE := Color(0.99, 0.96, 0.9)
const PAGE_EDGE := Color(0.93, 0.88, 0.79)
const PAGE_LINE := Color(0.6, 0.68, 0.8, 0.22)
const MARGIN_LINE := Color(0.92, 0.6, 0.6, 0.35)
const COVER := Color(0.62, 0.71, 0.6)
const COVER_DARK := Color(0.5, 0.6, 0.49)
const STITCH := Color(0.98, 0.95, 0.86, 0.85)
const ACCENT := Color(0.84, 0.47, 0.47)
const ROSE := Color(0.96, 0.72, 0.74)
const BUTTER := Color(0.99, 0.88, 0.58)
const LEAF := Color(0.6, 0.74, 0.55)
const PAPER_BUTTON := Color(1.0, 0.985, 0.95)
const TITLE_FONT := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
const NOTE_FONT := preload("res://assets/ui/fonts/Caveat-Regular.woff2")
const HAND := preload("res://assets/ui/fonts/PatrickHand-Regular.woff2")

## Tastenhilfe: Seite → [[Taste, Bedeutung], …]
const CONTROLS := {
	"Laufen": [
		["W A S D", "Laufen"],
		["Umschalt", "Schneller laufen (gedrückt halten)"],
		["Leertaste", "Springen (im Sitzen: aufstehen)"],
		["Strg halten", "Hocken"],
		["Maus", "Umsehen"],
		["E", "Benutzen: Lampen, Türen, Türschild, Sitzen, Kartons, Tablet, Bett, Katze streicheln, Spielzeug nehmen und werfen"],
		["E an der Theke", "Bedienen: Ausweis in den Leser, Bücher über den Scanner in die Tüte, Tüte zum Gast (alles mit der Maus); W A S D oder Esc: weggehen"],
		["E an einer Figur", "Reden – Klick oder E: weiter"],
		["Esc", "Schließt, was offen ist – sonst dieses Notizbuch"],
		["F3", "Bilder pro Sekunde anzeigen"],
	],
	"Bücher": [
		["Rechtsklick", "Buch nehmen (Regal, Tisch, Rückgabekasten …) – bis zu %d tragen"],
		["Linksklick", "Buch obenauf dort ablegen, wo du hinschaust"],
		["Linksklick halten", "Am Regal: alle passenden Bücher einräumen"],
		["Rechtsklick Kiste", "Unter der Theke: ein Buch dieses Genres aus dem Lager"],
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
	{"tab": "Start", "color": Color(0.99, 0.89, 0.6), "left": "start", "right": "actions"},
	{"tab": "Steuerung", "color": Color(0.98, 0.76, 0.76), "left": "keys:Laufen", "right": "keys:Bücher"},
	{"tab": "Gestalten", "color": Color(0.76, 0.89, 0.75), "left": "keys:Gestalten", "right": "test"},
	{"tab": "Bild", "color": Color(0.76, 0.86, 0.96), "left": "settings:Bildschirm", "right": "settings:Grafik"},
	{"tab": "Ton & Spiel", "color": Color(0.87, 0.8, 0.96), "left": "settings:Ton", "right": "settings:Spiel,Oberfläche"},
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
	"interface/todo": "Kleine Aufgaben am Rand für den Anfang – sie haken sich von selbst ab.",
	"interface/build_key_help": "Tastenleiste am unteren Rand im Gestaltungsmodus.",
	"audio/music_volume": "Die ruhige Musik im Hintergrund.",
	"audio/ambience_volume": "Straße, Vögel, Wind und Kaminfeuer.",
	"audio/effects_volume": "Bücher, Türen, Schritte, Tablet und Kasse.",
	"audio/voices_volume": "Kurze Laute der Passanten und Besucher.",
	"gameplay/day_length": "So viele Minuten dauert ein ganzer Tag in der Bücherei.",
}
## Farben für Haftnotizen weiterer Abschnitte (neue Einstellungen)
## Farben für Haftnotizen weiterer Abschnitte (neue Einstellungen)
const EXTRA_COLORS := [Color(0.99, 0.8, 0.62), Color(0.72, 0.9, 0.88), Color(0.96, 0.78, 0.88)]

var _spreads: Array[Dictionary] = []
## Geöffnet vom Hauptmenü aus (open_from_title): erste Seite ohne Speichern
var title_mode := false
var _current := 0
var _busy := false
var _close_pending := false  # Esc während des Aufklappens: danach gleich wieder zu
var _book: NotebookShape
var _left: VBoxContainer
var _right: VBoxContainer
var _cover: CoverShape
var _flip: PageShape
var _pages: PagesShape
var _tabs: Array[TabNote] = []
var _dimmer: ColorRect
var _resolution_button: OptionButton
var _window_mode_button: OptionButton
var _resolution_hint: Label
var _tween: Tween
var _tab_tween: Tween
static var _theme: Theme


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
## start_tab = Haftnotiz, bei der es aufgeschlagen wird (leer = erste Doppelseite).
func open(start_tab: String = "") -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_current = 0
	for i in _spreads.size():
		if not start_tab.is_empty() and String(_spreads[i].tab) == start_tab:
			_current = i
	_close_pending = false
	_fill_spread(_current)
	_fit_book()
	await get_tree().process_frame  # Größen stehen erst jetzt fest
	_place_pages()
	_play_open()


## Vom Hauptmenü aus (TitleScreen „Einstellungen“): aufgeschlagen bei „Bild“; auf der ersten Seite nur „Zurück“ und „Beenden“
## (auf dem Hauptmenü gibt es nichts zu speichern).
func open_from_title() -> void:
	title_mode = true
	open("Bild")


## Für Testbilder: sofort offen auf der Doppelseite mit diesem Namen (Haftnotiz oder Seitentitel).
func open_instant(page_name: String = "") -> void:
	show()
	_current = 0
	for i in _spreads.size():
		var spread: Dictionary = _spreads[i]
		if spread.tab == page_name or String(spread.left).ends_with(page_name) or String(spread.right).contains(page_name):
			_current = i
	_fill_spread(_current)
	_fit_book()
	_cover.visible = false
	_book.closed = false
	_book.queue_redraw()
	_set_pages_visible(true)
	_place_pages()
	for tab in _tabs:
		tab.modulate.a = 1.0
		tab.scale = Vector2.ONE


func resume() -> void:
	if _busy:
		_close_pending = true  # nach dem Aufklappen bzw. Umblättern
		return
	_play_close()


func _finish_close() -> void:
	hide()
	title_mode = false
	get_tree().paused = false
	Settings.apply_frame_limit()
	# Maus so einstellen, wie es das gerade Geöffnete braucht (z. B. Katalog = Mauszeiger sichtbar)
	MenuStack.restore_mouse_mode()


# --- Animationen (langsam und weich, Zeiten in GameConfig pause_*) ---

func _begin_motion() -> void:
	_busy = true
	Settings.apply_frame_limit(true)  # flüssig, solange sich etwas bewegt


func _end_motion() -> void:
	_busy = false
	Settings.apply_frame_limit()
	if _close_pending and visible:
		_close_pending = false
		_play_close()


func _play_open() -> void:
	_begin_motion()
	var w := _book.size.x
	var slide := GameConfig.pause_slide_time
	var half := GameConfig.pause_cover_time / 2.0
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
	_book.position = rest + Vector2(-w / 4.0, get_viewport().get_visible_rect().size.y * 0.9)
	_book.rotation = deg_to_rad(-7.0)
	_dimmer.modulate.a = 0.0
	if _tween:
		_tween.kill()
	# sanft herein (zum Schluss ein kleines Nachschwingen), leicht gedreht, dann gerade
	_tween = create_tween()
	_tween.tween_property(_book, "position", rest + Vector2(-w / 4.0, 0.0), slide).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_book, "rotation", deg_to_rad(1.2), slide * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_dimmer, "modulate:a", 1.0, slide).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_book, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Deckel klappt um den Rücken nach links auf, dabei rückt das Buch in die Mitte
	_tween.tween_property(_cover, "scale:x", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 8.0, 0.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Audio.play("books/page", -8.0, 0.85)
		_cover.front = false
		_cover.queue_redraw()
		_book.closed = false
		_book.queue_redraw()
		_set_pages_visible(true)
		_hide_tabs()  # die Haftnotizen kommen erst, wenn das Buch ganz offen ist
		_right_holder().modulate.a = 1.0
		_left_holder().modulate.a = 0.0)
	_tween.tween_property(_cover, "scale:x", -1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_book, "position", rest, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_left_holder(), "modulate:a", 1.0, half * 1.2).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_cover, "modulate:a", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_cover.visible = false
		_pop_tabs())


## Haftnotizen erscheinen nacheinander: wachsen weich aus dem Rand heraus.
func _pop_tabs() -> void:
	_layout_tabs(true)
	var tween := create_tween().set_parallel(true)
	for i in _tabs.size():
		var tab := _tabs[i]
		tab.visible = true
		tab.modulate.a = 0.0
		tab.scale = Vector2(0.6, 0.6)
		var delay := i * GameConfig.pause_tab_stagger
		tween.tween_property(tab, "modulate:a", 1.0, GameConfig.pause_tab_pop_time * 0.7).set_delay(delay)
		tween.tween_property(tab, "scale", Vector2.ONE, GameConfig.pause_tab_pop_time).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_end_motion)


func _play_close() -> void:
	_begin_motion()
	var w := _book.size.x
	var rest := _book.position
	var f := GameConfig.pause_close_factor
	var half := GameConfig.pause_cover_time / 2.0 * f
	if _tween:
		_tween.kill()
	_cover.visible = true
	_cover.modulate.a = 1.0
	_cover.front = false
	_cover.scale = Vector2(-1.0, 1.0)
	_cover.queue_redraw()
	_tween = create_tween()
	# Haftnotizen verschwinden sanft, dann Deckel zu, nach unten hinaus
	for tab in _tabs:
		_tween.parallel().tween_property(tab, "modulate:a", 0.0, 0.22)
	_tween.tween_property(_left_holder(), "modulate:a", 0.0, half * 0.9).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_cover, "scale:x", 0.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 8.0, 0.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Audio.play("books/page", -8.0, 0.8)
		_hide_tabs()
		_cover.front = true
		_cover.queue_redraw()
		_set_pages_visible(false)
		_book.closed = true
		_book.queue_redraw())
	_tween.tween_property(_cover, "scale:x", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_book, "position", rest + Vector2(-w / 4.0, 0.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var slide := GameConfig.pause_slide_time * f
	_tween.tween_property(_book, "position", rest + Vector2(-w / 4.0, get_viewport().get_visible_rect().size.y * 0.9), slide) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_book, "rotation", deg_to_rad(5.0), slide).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_dimmer, "modulate:a", 0.0, slide).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		_book.position = rest
		_book.rotation = 0.0
		_cover.visible = false
		_book.closed = false
		_set_pages_visible(true)
		_left_holder().modulate.a = 1.0
		_busy = false
		_close_pending = false
		_finish_close())


## Zu einer Doppelseite blättern: je umgeblätterte Seite schwingt ein Blatt weich über den Falz (höchstens drei; das erste
## langsam, weitere etwas schneller).
func _turn_to(index: int) -> void:
	if _busy or index == _current:
		return
	_begin_motion()
	Audio.play("books/page", -6.0, Audio.vary(0.08))
	var forward := index > _current
	var half := _book.page_rect(true).size.x
	var t := GameConfig.pause_turn_time
	# immer nur EIN Blatt, auch beim Sprung über mehrere Doppelseiten (Wunsch: sonst zu unruhig)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_flip.visible = true
		_flip.forward = forward
		_flip.position = (_book.page_rect(false) if forward else _book.page_rect(true)).position
		_flip.size = Vector2(half, _book.page_rect(true).size.y)
		_flip.pivot_offset = Vector2(0.0 if forward else half, 0.0)
		_flip.scale = Vector2.ONE
		_flip.queue_redraw())
	tween.tween_property(_flip, "scale:x", 0.0, t).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_current = index
		_fill_spread(index)
		_layout_tabs(false))
	tween.tween_callback(func() -> void:
		_flip.position = (_book.page_rect(true) if forward else _book.page_rect(false)).position
		_flip.pivot_offset = Vector2(half if forward else 0.0, 0.0))
	tween.tween_property(_flip, "scale:x", 1.0, t).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_flip.visible = false
		_end_motion())


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
	_dimmer.color = Color(0.2, 0.13, 0.09, 0.45)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dimmer)
	# Das Notizbuch: normales Buchformat, mittig, so groß wie es aufs Bild passt (links und rechts Platz für die Haftnotizen)
	_book = NotebookShape.new()
	_book.theme = _paper_theme()
	add_child(_book)
	_fit_book()
	get_viewport().size_changed.connect(_fit_book)
	# Ebene der aufgeschlagenen Seiten: Die Haftnotizen der anderen Seiten liegen darunter (zwischen den Blättern)
	_pages = PagesShape.new()
	_pages.name = "Pages"
	_pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.add_child(_pages)
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


## Größe des Notizbuchs: Doppelseite im Format pause_book_ratio, höchstens 86 % der Bildhöhe und so schmal, dass links und
## rechts die Haftnotizen Platz haben; mittig verankert (passt sich an, wenn sich die Fenstergröße ändert).
func _fit_book() -> void:
	if _book == null or not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var height := view.y * 0.86
	var width := minf(height * GameConfig.pause_book_ratio, view.x * 0.74)
	height = width / GameConfig.pause_book_ratio
	_book.anchor_left = 0.5
	_book.anchor_right = 0.5
	_book.anchor_top = 0.5
	_book.anchor_bottom = 0.5
	_book.offset_left = -width / 2.0
	_book.offset_right = width / 2.0
	_book.offset_top = -height / 2.0
	_book.offset_bottom = height / 2.0


## Thema der Seiten: Bedienelemente wie aus Papier – helle, runde Felder mit Bleistiftrand, Handschrift, rosa Punkte.
static func _paper_theme() -> Theme:
	if _theme:
		return _theme
	var theme := Theme.new()
	theme.default_font = HAND
	theme.default_font_size = 21
	theme.set_constant("line_spacing", "Label", -5)  # Handschrift hat viel Luft zwischen den Zeilen
	var field := func(bg: Color, border: Color, width: int) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = border
		box.set_border_width_all(width)
		box.set_corner_radius_all(16)
		box.content_margin_left = 16
		box.content_margin_right = 12
		box.content_margin_top = 5
		box.content_margin_bottom = 6
		box.anti_aliasing = true
		box.shadow_color = Color(0.4, 0.28, 0.2, 0.12)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 2)
		return box
	theme.set_stylebox("normal", "OptionButton", field.call(PAPER_BUTTON, INK_FAINT, 2))
	theme.set_stylebox("hover", "OptionButton", field.call(Color(1.0, 0.95, 0.93), ACCENT, 2))
	theme.set_stylebox("pressed", "OptionButton", field.call(Color(1.0, 0.93, 0.9), ACCENT, 2))
	theme.set_stylebox("focus", "OptionButton", field.call(Color(0, 0, 0, 0), Color(ACCENT, 0.6), 2))
	theme.set_stylebox("disabled", "OptionButton", field.call(Color(0.95, 0.92, 0.86), Color(INK_FAINT, 0.25), 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "OptionButton", INK)
	theme.set_color("font_disabled_color", "OptionButton", INK_FAINT)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_font_size("font_size", "OptionButton", 21)
	# aufklappende Liste
	var panel := field.call(PAPER_BUTTON, INK_FAINT, 2) as StyleBoxFlat
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "PopupMenu", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(ROSE, 0.45)
	hover.set_corner_radius_all(10)
	hover.anti_aliasing = true
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_font("font", "PopupMenu", HAND)
	theme.set_font_size("font_size", "PopupMenu", 20)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_icon("radio_checked", "PopupMenu", SoftShapes.dot_texture(14, ACCENT))
	theme.set_icon("radio_unchecked", "PopupMenu", SoftShapes.dot_texture(14, Color(INK_FAINT, 0.0)))
	# Schieberegler: weicher Strich, runder rosa Knopf
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK_FAINT, 0.35)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = ROSE
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", SoftShapes.dot_texture(24, ACCENT, ACCENT.darkened(0.12)))
	theme.set_icon("grabber_highlight", "HSlider", SoftShapes.dot_texture(24, ACCENT.lightened(0.1), ACCENT))
	# schmale, runde Bildlaufleiste
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(INK_FAINT, 0.08)
	bar.set_corner_radius_all(4)
	bar.content_margin_left = 3
	bar.content_margin_right = 3
	theme.set_stylebox("scroll", "VScrollBar", bar)
	var grab := bar.duplicate() as StyleBoxFlat
	grab.bg_color = Color(INK_FAINT, 0.4)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grab)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = theme
	return theme


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
		holder.add_theme_constant_override("margin_left", 52 if pair[2] else 44)
		holder.add_theme_constant_override("margin_right", 44 if pair[2] else 52)
		holder.add_theme_constant_override("margin_top", 30)
		holder.add_theme_constant_override("margin_bottom", 34)
	var cover_rect := _book.page_rect(false).grow(10.0)
	_cover.position = cover_rect.position
	_cover.size = cover_rect.size
	_cover.pivot_offset = Vector2(0.0, cover_rect.size.y / 2.0)
	_layout_tabs(true)


## Haftnotizen an IHREN Seiten (Nachtest von Etappe 8): Die der aufgeschlagenen Doppelseite klebt oben auf der rechten Seite
## (mit Washi-Tape, über den Seiten). Die der anderen Doppelseiten stecken zwischen den Blättern – umgeblätterte links, kommende
## rechts – und liegen darum UNTER der Ebene der aufgeschlagenen Seiten (PagesShape): man sieht nur, was über den Rand des
## Seitenstapels hinausragt. Untereinander versetzt, jede etwas schief wie echte Notizen. instant = sofort, sonst wandern sie
## weich an ihren neuen Platz.
func _layout_tabs(instant: bool) -> void:
	if _tabs.is_empty() or _book.size.x <= 0.0:
		return
	var left_rect := _book.page_rect(true)
	var right_rect := _book.page_rect(false)
	var step := minf(82.0, (right_rect.size.y - 60.0) / maxf(1.0, _tabs.size()))
	var widest := 0.0
	for tab in _tabs:
		widest = maxf(widest, TITLE_FONT.get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TabNote.FONT_SIZE).x)
	var tab_width := maxf(124.0, widest + 58.0)
	if _tab_tween:
		_tab_tween.kill()
	if not instant:
		_tab_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Reihenfolge der Ebenen: Notizen zwischen den Blättern – Seiten – Inhalt – Notiz der aufgeschlagenen Seite – Blatt – Deckel
	for tab in _tabs:
		_book.move_child(tab, 0 if tab.index != _current else -1)
	_book.move_child(_flip, -1)
	_book.move_child(_cover, -1)
	for tab in _tabs:
		var on_left := tab.index < _current
		tab.on_left = on_left
		tab.selected = tab.index == _current
		tab.tucked = not tab.selected
		tab.size = Vector2(tab_width, step - 10.0)
		tab.pivot_offset = Vector2(tab_width if on_left else 0.0, tab.size.y / 2.0)
		var y := right_rect.position.y + 30.0 + tab.index * step
		# 30 Bildpunkte liegen auf bzw. unter der Seite (dort klebt das Tape), der Rest ragt über den Rand
		var target := Vector2(left_rect.position.x - tab.size.x + 30.0, y) if on_left else Vector2(right_rect.end.x - 30.0, y)
		var tilt := deg_to_rad((-1.0 if on_left else 1.0) * (1.6 if tab.index % 2 == 0 else -1.1))
		if instant:
			tab.position = target
			tab.rotation = tilt
		else:
			_tab_tween.tween_property(tab, "position", target, GameConfig.pause_tab_move_time)
			_tab_tween.tween_property(tab, "rotation", tilt, GameConfig.pause_tab_move_time)
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
		box.add_child(_note("Nur zum Ausprobieren – sie lassen sich in GameConfig alle auf einmal abschalten."))
		_fill_keys(box, TEST_KEYS)
	elif kind == "tips":
		_heading(box, "Notizen")
		box.add_child(_note("Mehr Tipps stehen im Büchlein „Tipps & Tricks“ auf dem Tablet an der Theke."))
	elif kind.begins_with("settings:"):
		var first := true
		for section in kind.trim_prefix("settings:").split(","):
			if not first:
				box.add_child(_spacer(20))
			first = false
			_heading(box, section)
			_fill_settings(box, section)


## Erste Seite links: Titel, Datum und der heutige Tag in ein paar Zahlen.
func _fill_start(box: VBoxContainer) -> void:
	box.add_child(_text("Pause", TITLE_FONT, 72, INK))
	box.add_child(_text("%s, Tag %d · %s Uhr" % [GameClock.weekday_name(), GameClock.day, GameClock.time_text()], NOTE_FONT, 30, INK_SOFT))
	box.add_child(_wavy_rule())
	box.add_child(_spacer(8))
	box.add_child(_text("Heute in der Bücherei", TITLE_FONT, 36, INK))
	var t := Lending.today
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for row: Array in [["Besucher", str(int(t.get("visitors", 0)))], ["Ausgeliehen", str(int(t.get("borrowed", 0)))],
			["Zurückgebracht", str(int(t.get("returned", 0)))], ["Einnahmen", Wallet.format(int(t.get("income", 0)))],
			["In der Kasse", Wallet.format(Wallet.money)], ["Geöffnet", "ja" if Lending.is_open else "nein"]]:
		for cell: Label in [_text(row[0], HAND, 22, INK_SOFT), _text(row[1], HAND, 23, INK)]:
			cell.autowrap_mode = TextServer.AUTOWRAP_OFF
			grid.add_child(cell)
	box.add_child(_spacer(14))
	box.add_child(_note("Die bunten Zettel am Rand führen zu Steuerung und Einstellungen.", INK_FAINT))


## Erste Seite rechts: die wichtigsten Knöpfe, groß und handschriftlich unterstrichen.
func _fill_actions(box: VBoxContainer) -> void:
	box.add_child(_spacer(34))
	var resume_button := _action_button("Zurück" if title_mode else "Weiterspielen")
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	if title_mode:
		var leave := _action_button("Beenden")
		leave.pressed.connect(func() -> void: get_tree().quit())
		box.add_child(leave)
		resume_button.call_deferred("grab_focus")
		return
	var save := _action_button("Speichern")
	save.pressed.connect(func() -> void:
		SaveManager.save_game()
		save.text = "Gespeichert ♥")
	box.add_child(save)
	var quit := _action_button("Speichern und beenden")
	quit.pressed.connect(func() -> void: SaveManager.quit_game())
	box.add_child(quit)
	box.add_child(_spacer(24))
	box.add_child(_note("Esc klappt das Notizbuch wieder zu.", INK_FAINT))
	resume_button.call_deferred("grab_focus")


func _fill_keys(box: VBoxContainer, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for row: Array in rows:
		var key := Label.new()
		key.text = String(row[0])
		var key_box := StyleBoxFlat.new()
		key_box.bg_color = PAPER_BUTTON
		key_box.border_color = Color(INK, 0.3)
		key_box.set_border_width_all(2)
		key_box.set_corner_radius_all(11)
		key_box.anti_aliasing = true
		key_box.shadow_color = Color(0.4, 0.28, 0.2, 0.16)
		key_box.shadow_size = 2
		key_box.shadow_offset = Vector2(0, 2)
		key_box.content_margin_left = 8
		key_box.content_margin_right = 8
		key_box.content_margin_top = 0
		key_box.content_margin_bottom = 1
		key.add_theme_stylebox_override("normal", key_box)
		key.add_theme_font_override("font", HAND)
		key.add_theme_font_size_override("font_size", 19)
		key.add_theme_color_override("font_color", INK)
		key.custom_minimum_size = Vector2(142, 0)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(key)
		var text := String(row[1])
		if text.contains("%d"):
			text = text % GameConfig.max_carried_books
		elif text.contains("%s"):
			text = text % Wallet.format(GameConfig.debug_money_amount)
		var meaning := _text(text, HAND, 21, INK_SOFT)
		meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meaning.custom_minimum_size = Vector2(160, 0)
		grid.add_child(meaning)


func _fill_settings(box: VBoxContainer, section: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for definition in Settings.DEFINITIONS:
		if definition.section != section:
			continue
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.custom_minimum_size = Vector2(150, 0)
		texts.add_theme_constant_override("separation", -2)
		texts.add_child(_text(definition.label, HAND, 22, INK))
		if SETTING_NOTES.has(definition.key):
			texts.add_child(_text(SETTING_NOTES[definition.key], NOTE_FONT, 21, INK_SOFT))
		grid.add_child(texts)
		var control := _create_control(definition)
		control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(control)
	if section == "Bildschirm":
		_resolution_hint = _note("")
		box.add_child(_resolution_hint)


## Passendes Bedienelement je Art der Einstellung (aus Papier: Thema _paper_theme, Kästchen zum Ankreuzen InkCheck).
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
			var toggle := InkCheck.new()
			toggle.button_pressed = bool(Settings.get_value(key))
			toggle.text = "an" if toggle.button_pressed else "aus"
			toggle.toggled.connect(func(on: bool) -> void:
				toggle.text = "an" if on else "aus"
				Settings.set_value(key, on))
			return _sized(toggle)
		"slider":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var slider := HSlider.new()
			slider.min_value = 0
			slider.max_value = 100
			slider.step = 5
			slider.value = float(Settings.get_value(key))
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var number := _text("%d %%" % int(slider.value), HAND, 20, INK)
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


## Kleine Notiz in Handschrift (Erklärungen, Hinweise).
func _note(text: String, color: Color = INK_SOFT) -> Label:
	return _text(text, NOTE_FONT, 23, color)


func _heading(box: VBoxContainer, text: String) -> void:
	box.add_child(_text(text, TITLE_FONT, 44, INK))
	box.add_child(_wavy_rule())


func _wavy_rule() -> Control:
	var rule := WavyRule.new()
	rule.custom_minimum_size = Vector2(0, 12)
	return rule


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Großer Knopf wie mit Tinte geschrieben; beim Darüberfahren zieht sich langsam eine rosa Linie darunter.
func _action_button(text: String) -> Button:
	var button := InkButton.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", TITLE_FONT)
	button.add_theme_font_size_override("font_size", 50)
	for state in ["font_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ACCENT.darkened(0.1))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 2
	empty.content_margin_bottom = 12
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(style, empty)
	return button


## Knopf mit handgezogener Linie darunter: blass; mit der Maus darauf (oder gewählt) zieht sich weich eine rosa Linie
## von links nach rechts, dahinter ein kleines Herz.
class InkButton extends Button:
	var reveal := 0.0:
		set(value):
			reveal = value
			queue_redraw()
	var _tween: Tween

	func _ready() -> void:
		mouse_entered.connect(_grow.bind(true))
		mouse_exited.connect(_grow.bind(false))
		focus_entered.connect(_grow.bind(true))
		focus_exited.connect(_grow.bind(false))

	func _grow(on: bool) -> void:
		on = on or is_hovered() or has_focus()
		if _tween:
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "reveal", 1.0 if on else 0.0, 0.45 if on else 0.3)

	func _draw() -> void:
		var y := size.y - 7.0
		var width := minf(size.x, get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size("font_size")).x + 6.0)
		var faint := PackedVector2Array()
		for i in 17:
			var t := float(i) / 16.0
			faint.append(Vector2(t * width, y + sin(t * 9.0) * 1.6))
		draw_polyline(faint, INK_FAINT, 1.6, true)
		if reveal <= 0.01:
			return
		var strong := PackedVector2Array()
		var n := maxi(2, int(16 * reveal))
		for i in n + 1:
			var t := float(i) / 16.0 * (16.0 * reveal / n)
			strong.append(Vector2(t * width, y + sin(t * 9.0) * 1.6))
		draw_polyline(strong, ACCENT, 3.0, true)
		if reveal > 0.85:
			SoftShapes.heart(self, Vector2(width + 14.0, y - 8.0), 8.0 * (reveal - 0.85) / 0.15, ROSE)


## Kästchen zum Ankreuzen (statt Schalter): handgezeichnetes, rundes Kästchen, angekreuzt mit einem rosa Haken.
class InkCheck extends Button:
	func _init() -> void:
		toggle_mode = true  # vor dem Setzen von button_pressed (sonst bleibt es aus)

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_override("font", HAND)
		add_theme_font_size_override("font_size", 21)
		for state in ["font_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(state, INK)
		for state in ["font_hover_color", "font_hover_pressed_color"]:
			add_theme_color_override(state, ACCENT.darkened(0.1))
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 44
		empty.content_margin_top = 4
		empty.content_margin_bottom = 4
		for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(style, empty)
		toggled.connect(func(_on: bool) -> void: queue_redraw())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var box := Rect2(4.0, size.y / 2.0 - 14.0, 28.0, 28.0)
		var shape := SoftShapes.rounded_all(box, 8.0, 0.7, 5)
		SoftShapes.shadow(self, shape, Vector2(0, 2), Color(0.4, 0.28, 0.2, 0.08), 2, 1.5)
		draw_colored_polygon(shape, PAPER_BUTTON)
		draw_polyline(SoftShapes.closed(shape), ACCENT if is_hovered() else INK_SOFT, 2.0, true)
		if button_pressed:
			var c := box.position
			draw_polyline(PackedVector2Array([c + Vector2(6, 15), c + Vector2(12, 22), c + Vector2(26, 3)]), ACCENT, 4.0, true)


## Wellige Linie unter Überschriften (wie mit dem Füller gezogen), rosa.
class WavyRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var points := PackedVector2Array()
		var n := 28
		for i in n + 1:
			var t := float(i) / n
			points.append(Vector2(t * size.x * 0.62, size.y / 2.0 + sin(t * 15.0) * 2.0))
		draw_polyline(points, Color(ACCENT, 0.7), 2.4, true)
		SoftShapes.flower(self, Vector2(size.x * 0.62 + 14.0, size.y / 2.0), 6.0, ROSE, BUTTER)


## Das Notizbuch: weicher Einband aus salbeigrünem Leinen mit Steppnaht, zwei linierte Seiten mit runden Ecken, Schatten zum
## Falz, Blattkanten, Lesebändchen, ein paar gezeichnete Blümchen in den Ecken. Alle Ränder leicht unregelmäßig (handgemacht).
class NotebookShape extends Control:
	## zugeklappt zeichnet nur der Deckel (CoverShape); die Seiten (PagesShape) verschwinden mit
	var closed := false:
		set(value):
			closed = value
			queue_redraw()
			for child in get_children():
				if child is PagesShape:
					(child as Control).queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	## Rechteck einer Seite (left = linke Seite).
	func page_rect(left: bool) -> Rect2:
		var inset := 22.0
		var mid := size.x / 2.0
		return Rect2(inset, inset, mid - inset, size.y - inset * 2.0) if left else Rect2(mid, inset, mid - inset, size.y - inset * 2.0)

	## Einband mit Steppnaht, Blattkanten des Seitenstapels und Lesebändchen. Die aufgeschlagenen Seiten zeichnet PagesShape
	## (eine Ebene darüber – dazwischen stecken die Haftnotizen der anderen Seiten).
	func _draw() -> void:
		if closed:
			return
		var r := Rect2(Vector2.ZERO, size)
		var cover := SoftShapes.rounded_all(r, 30.0, 1.6, 11)
		SoftShapes.shadow(self, cover, Vector2(10, 16), Color(0.2, 0.12, 0.06, 0.06), 5, 4.0)
		draw_colored_polygon(cover, COVER)
		SoftShapes.dashed(self, SoftShapes.rounded_all(r.grow(-9.0), 22.0, 1.0, 12), STITCH, 2.0)
		var mid := size.x / 2.0
		var left := page_rect(true)
		var right := page_rect(false)
		var outer := 22.0
		# Blattkanten (mehrere Lagen unten und außen)
		for k in range(4, 0, -1):
			var shift := float(k) * 2.2
			var edge := PAGE_EDGE.darkened(0.03 * k)
			draw_colored_polygon(SoftShapes.rounded(Rect2(left.position + Vector2(-shift, shift), left.size),
				Vector4(outer, 0, 0, outer), 0.8, 20 + k), edge)
			draw_colored_polygon(SoftShapes.rounded(Rect2(right.position + Vector2(0, shift), right.size + Vector2(shift, 0)),
				Vector4(0, outer, outer, 0), 0.8, 30 + k), edge)
		# Lesebändchen unten aus dem Falz (rund ausgeschnitten)
		var ribbon := PackedVector2Array([Vector2(mid + 10, size.y - 30), Vector2(mid + 26, size.y - 30), Vector2(mid + 26, size.y + 20),
			Vector2(mid + 22, size.y + 16), Vector2(mid + 18, size.y + 12), Vector2(mid + 14, size.y + 16), Vector2(mid + 10, size.y + 20)])
		draw_colored_polygon(ribbon, ACCENT)


## Die beiden aufgeschlagenen Seiten (eigene Ebene über den Haftnotizen, die zwischen den Blättern stecken): Papier, Linien,
## rosa Rand, weicher Schatten zum Falz, Blümchen, Papierkorn.
class PagesShape extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var book := get_parent() as NotebookShape
		if book == null or book.closed:
			return
		var mid := size.x / 2.0
		var left := book.page_rect(true)
		var right := book.page_rect(false)
		var outer := 22.0
		draw_colored_polygon(SoftShapes.rounded(left, Vector4(outer, 3, 3, outer), 0.8, 41), PAGE)
		draw_colored_polygon(SoftShapes.rounded(right, Vector4(3, outer, outer, 3), 0.8, 42), PAGE)
		# Linien wie im Notizbuch (leicht wellig), ein rosa Rand je Seite
		var y := left.position.y + 64.0
		var line := 0
		while y < left.end.y - 20.0:
			SoftShapes.wavy_line(self, Vector2(left.position.x + 20.0, y), Vector2(left.end.x - 16.0, y), PAGE_LINE, 1.0, 0.6, line)
			SoftShapes.wavy_line(self, Vector2(right.position.x + 16.0, y), Vector2(right.end.x - 20.0, y), PAGE_LINE, 1.0, 0.6, line + 7)
			y += 32.0
			line += 1
		SoftShapes.wavy_line(self, Vector2(left.position.x + 36.0, left.position.y + 10.0), Vector2(left.position.x + 36.0, left.end.y - 10.0),
			MARGIN_LINE, 1.6, 0.8, 3)
		SoftShapes.wavy_line(self, Vector2(right.end.x - 36.0, right.position.y + 10.0), Vector2(right.end.x - 36.0, right.end.y - 10.0),
			MARGIN_LINE, 1.6, 0.8, 5)
		# Schatten zum Falz hin (weich)
		for i in 22:
			var t := float(i) / 22.0
			var a := 0.14 * pow(1.0 - t, 2.2)
			var w := 56.0 / 22.0 + 0.5
			draw_rect(Rect2(mid - 2.0 - (t + 1.0 / 22.0) * 56.0, left.position.y + 2.0, w, left.size.y - 4.0), Color(0.35, 0.22, 0.12, a))
			draw_rect(Rect2(mid + 2.0 + t * 56.0, right.position.y + 2.0, w, right.size.y - 4.0), Color(0.35, 0.22, 0.12, a))
		draw_line(Vector2(mid, left.position.y + 3.0), Vector2(mid, left.end.y - 3.0), Color(0.35, 0.22, 0.12, 0.25), 2.0, true)
		# Blümchen und Sternchen in den Ecken (wie hineingemalt)
		var corner := Vector2(left.position.x + 70.0, left.end.y - 46.0)
		SoftShapes.leaf(self, corner + Vector2(-4, 6), Vector2(-1.0, 0.5), 22.0, Color(LEAF, 0.55))
		SoftShapes.leaf(self, corner + Vector2(10, 8), Vector2(1.0, 0.7), 20.0, Color(LEAF, 0.55))
		SoftShapes.flower(self, corner, 13.0, Color(ROSE, 0.7), Color(BUTTER, 0.9))
		SoftShapes.flower(self, corner + Vector2(26, -14), 8.0, Color(BUTTER, 0.75), Color(ROSE, 0.9), 5, 0.6)
		SoftShapes.star(self, Vector2(right.end.x - 74.0, right.end.y - 54.0), 8.0, Color(BUTTER, 0.8))
		SoftShapes.star(self, Vector2(right.end.x - 52.0, right.end.y - 38.0), 5.0, Color(ROSE, 0.75), 0.3)
		SoftShapes.heart(self, Vector2(right.end.x - 92.0, right.end.y - 34.0), 6.0, Color(ROSE, 0.6))
		# leichtes Papierkorn
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 300:
			var p := Vector2(rng.randf_range(left.position.x + 6.0, right.end.x - 6.0), rng.randf_range(left.position.y + 6.0, left.end.y - 6.0))
			draw_circle(p, 1.1, Color(0.55, 0.45, 0.3, 0.05))


## Deckel: vorn salbeigrünes Leinen mit Steppnaht, Titelschild in Handschrift, Blümchen und rosa Gummiband; innen
## (umgeklappt) Vorsatzpapier mit Pünktchen.
class CoverShape extends Control:
	var front := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var shape := SoftShapes.rounded(r, Vector4(10, 30, 30, 10), 1.4, 21)
		if front:
			SoftShapes.shadow(self, shape, Vector2(8, 12), Color(0.2, 0.12, 0.06, 0.06), 4, 4.0)
		draw_colored_polygon(shape, COVER if front else Color(0.95, 0.89, 0.8))
		if not front:
			# Vorsatzpapier mit Pünktchen in Rosa und Butter
			var k := 0
			for x in range(34, int(size.x) - 24, 30):
				for y in range(34, int(size.y) - 24, 30):
					draw_circle(Vector2(x + (15 if (y / 30) % 2 == 0 else 0), y), 3.0, Color(ROSE if k % 2 == 0 else BUTTER, 0.55))
					k += 1
			return
		SoftShapes.dashed(self, SoftShapes.rounded(r.grow(-11.0), Vector4(4, 22, 22, 4), 1.0, 22), STITCH, 2.2)
		# Titelschild (Papier, leicht schief)
		var label_rect := Rect2(size.x * 0.17, size.y * 0.24, size.x * 0.62, size.y * 0.22)
		var plate := SoftShapes.rounded_all(label_rect, 18.0, 1.0, 23)
		SoftShapes.shadow(self, plate, Vector2(3, 5), Color(0.2, 0.12, 0.06, 0.08), 3, 2.0)
		draw_colored_polygon(plate, PAGE)
		draw_polyline(SoftShapes.closed(SoftShapes.rounded_all(label_rect.grow(-7.0), 13.0, 0.8, 24)), Color(ACCENT, 0.5), 1.6, true)
		var title := "Notizbuch"
		var ts := TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56)
		draw_string(TITLE_FONT, Vector2(label_rect.get_center().x - ts.x / 2.0, label_rect.get_center().y + 4.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 56, INK)
		var sub := "Cozy Bücherei"
		var ss := NOTE_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		draw_string(NOTE_FONT, Vector2(label_rect.get_center().x - ss.x / 2.0, label_rect.get_center().y + 40.0), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK_SOFT)
		# Blümchen unter dem Schild
		var c := Vector2(label_rect.get_center().x, label_rect.end.y + 70.0)
		SoftShapes.leaf(self, c + Vector2(-6, 8), Vector2(-1.0, 0.4), 30.0, Color(0.48, 0.6, 0.45))
		SoftShapes.leaf(self, c + Vector2(6, 8), Vector2(1.0, 0.4), 30.0, Color(0.48, 0.6, 0.45))
		SoftShapes.flower(self, c, 20.0, ROSE, BUTTER)
		SoftShapes.flower(self, c + Vector2(-46, 18), 12.0, BUTTER, ROSE, 5, 0.5)
		SoftShapes.flower(self, c + Vector2(44, 20), 11.0, Color(0.98, 0.95, 0.9), BUTTER, 5, 0.2)
		# Gummiband senkrecht (rosa, rund)
		var band := SoftShapes.rounded_all(Rect2(size.x - 50.0, -2.0, 14.0, size.y + 4.0), 6.0, 0.6, 25)
		draw_colored_polygon(band, ACCENT)


## Ein Blatt, das beim Umblättern über den Falz schwingt: liniert, zur Mitte hin weich schattiert, mit runder Außenecke.
class PageShape extends Control:
	var forward := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var radii := Vector4(3, 22, 22, 3) if position.x >= get_parent_control().size.x / 2.0 - 1.0 else Vector4(22, 3, 3, 22)
		draw_colored_polygon(SoftShapes.rounded(rect, radii, 0.8, 50), PAGE.darkened(0.02))
		var y := 64.0
		var line := 0
		while y < size.y - 20.0:
			SoftShapes.wavy_line(self, Vector2(16.0, y), Vector2(size.x - 16.0, y), PAGE_LINE, 1.0, 0.6, line)
			y += 32.0
			line += 1
		for i in 14:
			var t := float(i) / 14.0
			draw_rect(Rect2(t * size.x, 2.0, size.x / 14.0 + 0.5, size.y - 4.0), Color(0.35, 0.22, 0.12, 0.06 * sin(t * PI)))


## Haftnotiz am Seitenrand: pastellfarbener Zettel mit runden Ecken, ein Stück Washi-Tape an der Klebekante, Wort in
## Handschrift. Jede etwas schief (Drehung setzt _layout_tabs); mit der Maus darauf rutscht sie weich ein Stück heraus;
## die aktuelle trägt ein kleines Herz.
class TabNote extends Button:
	const FONT_SIZE := 27
	var color := Color.YELLOW
	var index := 0
	var on_left := false
	var selected := false
	## steckt zwischen den Blättern (nicht die aufgeschlagene Seite): ohne Tape, etwas im Schatten der Seite darüber
	var tucked := false
	var lift := 0.0:
		set(value):
			lift = value
			queue_redraw()
	var _tween: Tween

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			add_theme_color_override(state, Color(0, 0, 0, 0))  # Text zeichnet _draw
		var empty := StyleBoxEmpty.new()
		for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(style, empty)
		mouse_entered.connect(_slide.bind(true))
		mouse_exited.connect(_slide.bind(false))

	func _slide(out: bool) -> void:
		if _tween:
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "lift", 8.0 if out else 0.0, 0.25)

	func _draw() -> void:
		var shift := Vector2(-lift if on_left else lift, 0.0)
		var r := Rect2(shift, size)
		var radii := Vector4(12, 3, 3, 12) if on_left else Vector4(3, 12, 12, 3)
		var note := SoftShapes.rounded(r, radii, 0.9, index * 7 + 3)
		SoftShapes.shadow(self, note, Vector2(3, 5), Color(0.25, 0.15, 0.08, 0.07), 3, 2.0)
		draw_colored_polygon(note, color.lightened(0.12) if selected else (color.darkened(0.05) if tucked else color))
		if not tucked:
			# Washi-Tape an der Klebekante (halb durchsichtig, feine Streifen) – nur die Notiz der aufgeschlagenen Seite
			var tape_x := r.end.x - 30.0 if on_left else r.position.x - 2.0
			var tape := Rect2(Vector2(tape_x, r.position.y + 6.0), Vector2(32.0, size.y - 12.0))
			draw_colored_polygon(SoftShapes.rounded_all(tape, 3.0, 0.5, index), Color(1, 1, 1, 0.42))
			var stripe := tape.position.x + 4.0
			while stripe < tape.end.x - 2.0:
				draw_line(Vector2(stripe, tape.position.y + 1.0), Vector2(stripe + 6.0, tape.end.y - 1.0), Color(color.darkened(0.25), 0.18), 2.0, true)
				stripe += 8.0
		else:
			# Schatten der Seite darüber am Rand des Seitenstapels
			var edge_x := r.end.x - 30.0 if on_left else r.position.x + 30.0
			for i in 6:
				var w := 2.0
				var x := edge_x - (i + 1) * w if on_left else edge_x + i * w
				draw_rect(Rect2(x, r.position.y + 2.0, w, size.y - 4.0), Color(0.3, 0.2, 0.1, 0.07 * (1.0 - i / 6.0)))
		var text_width := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var room := size.x - 44.0
		var text_x := (10.0 if on_left else 36.0) + shift.x + maxf(0.0, (room - text_width) / 2.0)
		draw_string(TITLE_FONT, Vector2(text_x, size.y / 2.0 + 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, room, FONT_SIZE, INK)
		if selected:
			SoftShapes.heart(self, Vector2(text_x + minf(text_width, room) + 12.0, size.y / 2.0 - 1.0), 6.0, Color(ACCENT, 0.8))
