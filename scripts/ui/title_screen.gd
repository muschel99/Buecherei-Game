class_name TitleScreen
extends CanvasLayer
## Hauptmenü (seit dem Wunsch der Entwicklerin nach dem Nachtest von Etappe 8): Nach dem Ladebildschirm zeigt eine eigene kleine
## Welt (TitleBackdrop, scenes/ui/title_backdrop.tscn, in einem SubViewport) rechts den großen Gartenbaum mit der Rundbank auf
## einer schwebenden Rasen-Insel vor einem weichen Abendhimmel – ohne Häuser (Wunsch: „das Modell einzeln auf einem schönen,
## cozy Hintergrund“). Die Spielwelt wird solange nicht gezeichnet (disable_3d, erst nach dem Ladebildschirm – der bereitet die
## Grafik der Welt vor). Links hängt ein handgeschriebener Notizzettel mit dem Menü: Weiterspielen (nur mit Spielstand),
## Neues Spiel (mit Nachfrage, wenn es einen Spielstand gibt), Einstellungen (das Notizbuch, PauseMenu.open_from_title), Beenden.
## Weiterspielen: der Zettel gleitet weg, der Garten blendet weich ins Spiel über, dann geht es los. Neues Spiel: Spielstand weg,
## alles zurück auf Anfang (SaveManager.reset_to_start), die Welt lädt frisch – und die Geschichte beginnt (new_game_started).
## Nur beim echten Start (LoadingScreen setzt show_on_start), Prüfwerkzeuge laden main.tscn ohne Hauptmenü.

const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
const BACKDROP := preload("res://scenes/ui/title_backdrop.tscn")
const LOADING_SCRIPT := "res://scripts/ui/loading_screen.gd"
const TITLE_FONT := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
const NOTE_FONT := preload("res://assets/ui/fonts/Caveat-Regular.woff2")
const INK := Color(0.33, 0.23, 0.19)
const INK_SOFT := Color(0.5, 0.39, 0.32)
const PAPER := Color(0.99, 0.97, 0.91)
const LINE := Color(0.6, 0.68, 0.8, 0.28)
const MARGIN := Color(0.92, 0.6, 0.6, 0.4)
const ROSE := Color(0.96, 0.72, 0.74)
const BUTTER := Color(0.99, 0.88, 0.58)
## Stempel unten rechts auf dem Zettel: Farben wie auf dem Tablet (LoanScreen.STAMP/SOFT)
const STAMP := Color(0.86, 0.45, 0.48)
const STAMP_SOFT := Color(0.5, 0.42, 0.38)

## Beim nächsten Laden der Hauptszene das Hauptmenü zeigen (LoadingScreen)
static var show_on_start := false
## Ein neues Spiel hat gerade begonnen (die Geschichte mit der Maklerin startet, StoryIntro)
static var new_game_started := false

var _main: Node3D
var _player: Node3D
var _backdrop: SubViewportContainer
## Die Spielwelt wird gerade nicht gezeichnet (hinter dem Garten sieht man sie ohnehin nicht)
var _world_hidden := false
var _note: NoteCard
var _buttons: VBoxContainer
var _time := 0.0
var _leaving := false
## Einstellungen (Notizbuch) offen: der Zettel gleitet so lange zur Seite
var _settings_open := false
var _note_x := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent() as Node3D
	_player = _main.get_node_or_null("Player") as Node3D
	if _player:
		_player.set("movement_enabled", false)
		_player.set("interaction_enabled", false)
	_set_hud_visible(false)
	GameClock.running = false
	SaveManager.saving_enabled = false  # auf dem Hauptmenü ändert sich nichts am Spielstand
	_build_backdrop()
	MenuStack.open(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_note()


func close_from_escape() -> void:
	pass  # Esc tut auf dem Hauptmenü nichts (das Pausenmenü gehört ins Spiel)


func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Blick auf Baum und Bank; die Kamera wiegt sich ganz langsam (wie ein ruhiger Atemzug).
## Der Garten in seiner eigenen kleinen Welt, bildfüllend hinter dem Zettel.
func _build_backdrop() -> void:
	# eigene, untere Bildebene: über der Spielwelt, aber unter allen Menüs (das Notizbuch der Einstellungen liegt auf Ebene 10)
	var layer_below := CanvasLayer.new()
	layer_below.name = "BackdropLayer"
	layer_below.layer = -1
	add_child(layer_below)
	_backdrop = SubViewportContainer.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.stretch = true
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_below.add_child(_backdrop)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.audio_listener_enable_3d = false
	Settings.match_preview_quality(viewport)  # gleiche Kantenglättung wie das Spiel (sonst doppelte Vorbereitung der Grafik)
	_backdrop.add_child(viewport)
	viewport.add_child(BACKDROP.instantiate())


## Spielwelt zeichnen oder nicht (während das Hauptmenü sie verdeckt, spart das viel Arbeit).
func _set_world_hidden(hidden: bool) -> void:
	if hidden == _world_hidden:
		return
	_world_hidden = hidden
	get_viewport().disable_3d = hidden


func _loading_screen_up() -> bool:
	for node in get_tree().root.get_children():
		var script := node.get_script() as Script
		if script and script.resource_path == LOADING_SCRIPT:
			return true
	return false


func _exit_tree() -> void:
	_set_world_hidden(false)


func _process(delta: float) -> void:
	_time += delta
	# erst nach dem Ladebildschirm (der wartet, bis die Grafik der Welt vorbereitet ist)
	if not _leaving and not _world_hidden and not _loading_screen_up():
		_set_world_hidden(true)
	if _settings_open:
		var menu := _main.get_node_or_null("PauseMenu") as CanvasItem
		if menu == null or not menu.visible:
			_settings_open = false
			_slide_note(true)


# --- Notizzettel mit dem Menü ---

func _build_note() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_note = NoteCard.new()
	_note.anchor_left = 0.06
	_note.anchor_right = 0.34
	_note.anchor_top = 0.12
	_note.anchor_bottom = 0.86
	_note.theme = PAUSE_MENU._paper_theme()
	holder.add_child(_note)
	_note.resized.connect(func() -> void: _note.pivot_offset = _note.size / 2.0)
	_note.rotation_degrees = -2.0
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, {"left": 64, "right": 34, "top": 60, "bottom": 40}[side])
	_note.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_label("Cozy Bücherei", TITLE_FONT, 68, INK))
	box.add_child(_label("eine kleine Bücherei an der Ecke", NOTE_FONT, 30, INK_SOFT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	box.add_child(_buttons)
	_show_menu()
	# sanft hereingleiten
	_note.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_note, "modulate:a", 1.0, GameConfig.title_note_time)
	tween.tween_property(_note, "rotation_degrees", -2.0, GameConfig.title_note_time).from(-6.0)
	# danach ploppt der Stempel unten rechts auf (wie auf dem Tablet beim Bedienen)
	var stamp := create_tween()
	stamp.tween_interval(GameConfig.title_note_time + 0.25)
	stamp.tween_callback(Audio.play.bind("ui/stamp_pop", -8.0, 1.0))
	stamp.tween_property(_note, "stamp_pop", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_menu() -> void:
	_clear_buttons()
	var first: Button = null
	if SaveManager.has_save():
		first = _button("Weiterspielen", _continue)
	var fresh := _button("Neues Spiel", _ask_new_game)
	_button("Einstellungen", _settings)
	_button("Beenden", func() -> void: get_tree().quit())
	(first if first else fresh).call_deferred("grab_focus")


func _ask_new_game() -> void:
	if not SaveManager.has_save():
		_start_new_game()
		return
	_clear_buttons()
	var ask := _label("Neu anfangen? Dein bisheriges Spiel wird dabei überschrieben.", NOTE_FONT, 30, INK_SOFT)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buttons.add_child(ask)
	_button("Ja, neu anfangen", _start_new_game)
	var no := _button("Lieber nicht", _show_menu)
	no.call_deferred("grab_focus")


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _button(text: String, action: Callable) -> Button:
	var button := PAUSE_MENU.InkButton.new()
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
		button.add_theme_color_override(state, PAUSE_MENU.ACCENT.darkened(0.1))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 2
	empty.content_margin_bottom = 12
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(style, empty)
	button.pressed.connect(func() -> void:
		if not _leaving:
			Audio.play("ui/plop", -10.0, Audio.vary(0.05))
			action.call())
	_buttons.add_child(button)
	return button


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# --- Aktionen ---

func _settings() -> void:
	var menu := _main.get_node_or_null("PauseMenu")
	if menu and menu.has_method("open_from_title"):
		_slide_note(false)
		menu.call("open_from_title")
		_settings_open = true


## Zettel zur Seite (Notizbuch offen) bzw. zurück.
func _slide_note(back: bool) -> void:
	if not back:
		_note_x = _note.position.x
	_note.visible = true
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_note, "modulate:a", 1.0 if back else 0.0, GameConfig.title_note_time * 0.6)
	tween.tween_property(_note, "position:x", _note_x if back else _note_x - 140.0, GameConfig.title_note_time * 0.6)
	if not back:
		tween.chain().tween_callback(_note.hide)  # unsichtbare Knöpfe nicht anklickbar


## Weiterspielen: Zettel weg, Kamera fliegt zur Spielfigur, dann ist man im Spiel.
func _continue() -> void:
	_leaving = true
	_set_world_hidden(false)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_note, "modulate:a", 0.0, GameConfig.title_note_time * 0.6)
	tween.tween_property(_note, "position:x", _note.position.x - 120.0, GameConfig.title_note_time * 0.6)
	# der Garten blendet weich ins Spiel über (leicht heranzoomend)
	_backdrop.pivot_offset = _backdrop.size / 2.0
	tween.tween_property(_backdrop, "modulate:a", 0.0, GameConfig.title_fly_time).set_delay(0.15)
	tween.tween_property(_backdrop, "scale", Vector2.ONE * 1.06, GameConfig.title_fly_time).set_delay(0.15)
	tween.chain().tween_callback(_enter_game)


func _enter_game() -> void:
	MenuStack.close(self)
	_set_hud_visible(true)
	GameClock.running = true
	SaveManager.saving_enabled = true
	if _player:
		_player.set("movement_enabled", true)
		_player.set("interaction_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


## Neues Spiel: Spielstand weg, alles auf Anfang, die Welt lädt frisch (hinter einem weichen Papier-Überblenden).
func _start_new_game() -> void:
	_leaving = true
	MenuStack.close(self)
	ScreenFade.new_game()


func _set_hud_visible(on: bool) -> void:
	for name_ in ["HUD", "StyleMeter", "CarryIndicator"]:
		var node := _main.get_node_or_null(name_)
		if node and "suppressed" in node:
			node.set("suppressed", not on)  # das HUD blendet sich sonst jedes Bild selbst wieder ein
		elif node is CanvasLayer:
			(node as CanvasLayer).visible = on


## Der Notizzettel: abgerissenes, liniertes Papier mit rosa Rand, oben ein Stück Washi-Tape, unten ein Blümchen.
class NoteCard extends Control:
	var stamp_pop := 0.0:
		set(value):
			stamp_pop = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var paper := SoftShapes.rounded_all(r, 10.0, 1.4, 61)
		SoftShapes.shadow(self, paper, Vector2(8, 12), Color(0.2, 0.12, 0.06, 0.07), 5, 4.0)
		draw_colored_polygon(paper, PAPER)
		var y := 120.0
		var line := 0
		while y < size.y - 24.0:
			SoftShapes.wavy_line(self, Vector2(18.0, y), Vector2(size.x - 18.0, y), LINE, 1.0, 0.6, line)
			y += 40.0
			line += 1
		SoftShapes.wavy_line(self, Vector2(48.0, 14.0), Vector2(48.0, size.y - 14.0), MARGIN, 1.6, 0.8, 9)
		# Washi-Tape oben in der Mitte
		var tape := Rect2(Vector2(size.x / 2.0 - 60.0, -16.0), Vector2(120.0, 34.0))
		draw_colored_polygon(SoftShapes.rounded_all(tape, 3.0, 0.5, 3), Color(ROSE, 0.75))
		var stripe := tape.position.x + 6.0
		while stripe < tape.end.x - 4.0:
			draw_line(Vector2(stripe, tape.position.y + 2.0), Vector2(stripe + 8.0, tape.end.y - 2.0), Color(1, 1, 1, 0.35), 3.0, true)
			stripe += 12.0
		# Stempel unten rechts wie auf dem Tablet beim Bedienen (rosa Kreis mit Herz; seit dem zweiten Nachtest der Überarbeitung –
		# Wunsch der Entwicklerin): ploppt auf, wenn der Zettel hereingeglitten ist (stamp_pop 0 → 1)
		var sc := Vector2(size.x - 64.0, size.y - 62.0)
		draw_arc(sc, 27.0, 0.0, TAU, 32, Color(STAMP_SOFT, 0.45), 2.5, true)
		if stamp_pop > 0.0:
			var grow := lerpf(1.8, 1.0, stamp_pop)
			draw_circle(sc, 22.0 * grow, Color(STAMP, 0.85 * stamp_pop))
			SoftShapes.heart(self, sc + Vector2(0, -2) * grow, 10.0 * grow, Color(1.0, 0.95, 0.92, stamp_pop))
		# Blümchen links daneben
		var c := Vector2(size.x - 128.0, size.y - 46.0)
		SoftShapes.leaf(self, c + Vector2(-6, 8), Vector2(-1.0, 0.5), 22.0, Color(0.6, 0.74, 0.55, 0.7))
		SoftShapes.leaf(self, c + Vector2(8, 10), Vector2(1.0, 0.6), 20.0, Color(0.6, 0.74, 0.55, 0.7))
		SoftShapes.flower(self, c, 13.0, ROSE, BUTTER)


## Weiches Überblenden über Papierfarbe, das ein Neuladen der Szene übersteht (hängt an der Wurzel, nicht an der Szene).
## new_game: alte Szene entladen, ERST DANN alles auf Anfang setzen (sonst reagiert die alte Szene noch auf die Änderungen),
## dann die Hauptszene frisch laden.
class ScreenFade extends CanvasLayer:
	const MAIN_SCENE := "res://scenes/main.tscn"
	var _rect: ColorRect

	static func new_game() -> void:
		var fade := ScreenFade.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(fade)
		fade._run_new_game()

	func _run_new_game() -> void:
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(_rect, "modulate:a", 1.0, 0.7)
		await tween.finished
		var tree := get_tree()
		tree.unload_current_scene()
		await tree.process_frame
		SaveManager.saving_enabled = true
		SaveManager.delete_save()
		SaveManager.reset_to_start()
		Tutorial.start_new_game()  # die Maklerin übergibt das Haus (StoryIntro)
		GameClock.running = true
		TitleScreen.show_on_start = false
		TitleScreen.new_game_started = true
		tree.change_scene_to_file(MAIN_SCENE)
		for i in 20:
			await tree.process_frame
		var back := create_tween().set_trans(Tween.TRANS_SINE)
		back.tween_property(_rect, "modulate:a", 0.0, 1.0)
		await back.finished
		queue_free()

	func _ready() -> void:
		layer = 100
		process_mode = Node.PROCESS_MODE_ALWAYS
		_rect = ColorRect.new()
		_rect.color = Color(0.96, 0.93, 0.86)
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_rect.modulate.a = 0.0
		add_child(_rect)
