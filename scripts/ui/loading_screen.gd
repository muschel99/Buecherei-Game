extends CanvasLayer
## Ladebildschirm (seit Etappe 8, Wunsch der Entwicklerin: „das Spiel braucht ewig zum Starten“). Ist die Startszene des
## Projekts: erscheint sofort (warmes Papier, ein gemaltes Buch, das umblättert, wechselnde Sätze in Handschrift, ein
## Bleistiftstrich als Fortschritt), lädt dann die Hauptszene, setzt sie ein und
## bleibt darüber liegen, bis die ersten Bilder flüssig laufen – so lange bereitet die Grafikkarte ihre Malprogramme vor
## (nach einem Update dauert das am längsten). Dann blendet er weich aus. Am Ende schreibt er die Zeiten in die Ausgabe
## („Start: …“), damit man sehen kann, wo die Zeit bleibt.
## Seit dem zweiten Nachtest der Überarbeitung („das Buch hängt einfach fest“): Die Hauptszene lädt in einem Hintergrund-Faden
## (ohne Unter-Fäden – mit ihnen luden zwei Fäden dieselben Hausmodelle doppelt), das Buch blättert dabei flüssig weiter. Die
## Seite blättert nach Bildern statt nach der Uhr (_flip): Auch wenn die Grafikkarte später für ein Bild eine Sekunde braucht,
## bewegt sie sich in jedem Bild sichtbar ein Stück – man sieht, dass nichts hängt.
## Testbilder und Prüfwerkzeuge laden main.tscn weiter direkt.

const MAIN_SCENE := "res://scenes/main.tscn"
const PAPER := Color(0.99, 0.96, 0.9)
const INK := Color(0.33, 0.23, 0.19)
const INK_SOFT := Color(0.5, 0.39, 0.32)
const ROSE := Color(0.96, 0.72, 0.74)
const ACCENT := Color(0.84, 0.47, 0.47)
const BUTTER := Color(0.99, 0.88, 0.58)
const LEAF := Color(0.6, 0.74, 0.55)
const COVER := Color(0.62, 0.71, 0.6)
const TITLE_FONT := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
const NOTE_FONT := preload("res://assets/ui/fonts/Caveat-Regular.woff2")
const LINES := ["Die Bücherei öffnet …", "Der Tee zieht noch …", "Die Bücher werden abgestaubt …", "Die Katze streckt sich …",
	"Die Laternen werden geputzt …", "Die Blumen bekommen Wasser …"]
## Bilder, die mindestens gezeichnet werden, und wie ruhig sie sein müssen, bevor ausgeblendet wird
const MIN_FRAMES := 12
const SMOOTH_FRAMES := 6
const SMOOTH_TIME := 0.08
const MAX_WARM_TIME := 45.0
const FADE_TIME := 0.9
## Eine Seite braucht so lange; je Bild blättert sie mindestens/höchstens so viele Sekunden weiter
const FLIP_TIME := 1.6
const FLIP_STEP_MIN := 1.0 / 60.0
const FLIP_STEP_MAX := 0.13

enum Phase { LOADING, PLACING, WARMING, FADING }

var _phase := Phase.LOADING
var _progress := 0.0
var _shown_progress := 0.0
var _time := 0.0
var _flip := 0.0             # Seiten-Fortschritt (1 = eine Seite)
var _threaded := false       # lädt die Hauptszene im Hintergrund
var _frames := 0
var _recent: Array[float] = []
var _warm_time := 0.0
var _canvas: Control
var _t_loaded := 0
var _t_placed := 0
var _ready_ticks := 0  # Programmstart bis der Ladebildschirm stand (Engine, Autoloads)
var _loaded_scene: PackedScene


func _ready() -> void:
	_ready_ticks = Time.get_ticks_msec()
	TitleScreen.show_on_start = true  # nach dem Laden erscheint das Hauptmenü
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Painting.new()
	_canvas.screen = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas)
	_progress = 0.12


func _process(delta: float) -> void:
	_time += delta
	_flip += clampf(delta, FLIP_STEP_MIN, FLIP_STEP_MAX) / FLIP_TIME
	_shown_progress = lerpf(_shown_progress, _progress, minf(1.0, delta * 4.0))
	_canvas.queue_redraw()
	match _phase:
		Phase.LOADING:
			# erst ein paar Bilder zeigen, dann im Hintergrund laden (klappt das nicht, im Vordergrund – dann steht das Bild kurz)
			_frames += 1
			if _frames == 3:
				_threaded = ResourceLoader.load_threaded_request(MAIN_SCENE, "", false) == OK
			if _frames >= 3:
				var packed: PackedScene = null
				if _threaded:
					var progress := []
					var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
					if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
						if not progress.is_empty():
							_progress = maxf(_progress, 0.12 + 0.58 * float(progress[0]))
						return
					if status == ResourceLoader.THREAD_LOAD_LOADED:
						packed = ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
					else:
						push_warning("Ladebildschirm: Laden im Hintergrund ging nicht – lade im Vordergrund.")
				if packed == null:
					packed = load(MAIN_SCENE) as PackedScene
				if packed == null:
					push_error("Ladebildschirm: Hauptszene konnte nicht geladen werden.")
					set_process(false)
					return
				_loaded_scene = packed
				_t_loaded = Time.get_ticks_msec()
				_progress = 0.7
				_frames = 0
				_phase = Phase.PLACING  # ein Bild warten, damit der Fortschritt zu sehen ist
		Phase.PLACING:
			var main := _loaded_scene.instantiate()
			_loaded_scene = null
			get_tree().root.add_child(main)
			get_tree().current_scene = main
			_t_placed = Time.get_ticks_msec()
			_progress = 0.8
			_phase = Phase.WARMING
		Phase.WARMING:
			# die Welt zeichnet sich dahinter schon: warten, bis die Bilder ruhig kommen
			# ruhig = die letzten Bilder kommen gleichmäßig (schnell oder – auf langsamen Rechnern – wenigstens ohne Hänger)
			_frames += 1
			_warm_time += delta
			_recent.append(delta)
			if _recent.size() > SMOOTH_FRAMES:
				_recent.pop_front()
			var calm: bool = _recent.size() == SMOOTH_FRAMES and float(_recent.max()) < maxf(SMOOTH_TIME, 2.0 * float(_recent.min()))
			_progress = minf(0.98, 0.8 + 0.18 * float(_frames) / float(MIN_FRAMES + SMOOTH_FRAMES))
			if (_frames >= MIN_FRAMES and calm) or _warm_time > MAX_WARM_TIME:
				_finish()


func _finish() -> void:
	_phase = Phase.FADING
	_progress = 1.0
	var now := Time.get_ticks_msec()
	print("Start: Programm %.1f s, Laden %.1f s, Aufbauen %.1f s, erste Bilder %.1f s – zusammen %.1f s" % [
		_ready_ticks / 1000.0, (_t_loaded - _ready_ticks) / 1000.0, (_t_placed - _t_loaded) / 1000.0,
		(now - _t_placed) / 1000.0, now / 1000.0])
	var tween := create_tween()
	tween.tween_property(_canvas, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)


## Das Bild des Ladebildschirms: Papier, ein offenes Buch mit umschwingender Seite, Blümchen, Satz, Bleistiftstrich.
class Painting extends Control:
	var screen: Node

	func _draw() -> void:
		var s: Node = screen
		var t: float = s._time
		draw_rect(Rect2(Vector2.ZERO, size), PAPER)
		var c := size / 2.0 + Vector2(0, -60)
		# offenes Buch
		var w := 120.0
		var h := 150.0
		var cover := SoftShapes.rounded_all(Rect2(c + Vector2(-w - 12, -h / 2 - 10), Vector2(w * 2 + 24, h + 20)), 16.0, 1.2, 3)
		SoftShapes.shadow(self, cover, Vector2(6, 9), Color(0.25, 0.15, 0.08, 0.05), 4, 3.0)
		draw_colored_polygon(cover, COVER)
		for side: float in [-1.0, 1.0]:
			var page := Rect2(c + Vector2(0.0 if side > 0 else -w, -h / 2), Vector2(w, h))
			var radii := Vector4(2, 14, 14, 2) if side > 0 else Vector4(14, 2, 2, 14)
			draw_colored_polygon(SoftShapes.rounded(page, radii, 0.8, int(side) + 5), Color(1.0, 0.985, 0.95))
			for i in 6:
				var y := page.position.y + 34.0 + i * 18.0
				SoftShapes.wavy_line(self, Vector2(page.position.x + 16, y), Vector2(page.end.x - 16, y),
					Color(0.6, 0.68, 0.8, 0.3), 1.2, 0.7, i + int(side) * 3)
		# umschwingende Seite (nach Bildern, siehe _flip)
		var phase := fmod(float(s._flip), 1.0)
		var swing := cos(phase * PI)  # 1 = rechts, -1 = links
		var turning := Rect2(c + Vector2(0.0 if swing >= 0.0 else swing * w, -h / 2), Vector2(absf(swing) * w, h))
		if turning.size.x > 14.0:
			draw_colored_polygon(SoftShapes.rounded_all(turning, 6.0, 0.0), Color(0.97, 0.95, 0.9).darkened(0.06 * (1.0 - absf(swing))))
		elif turning.size.x > 1.0:
			draw_rect(turning, Color(0.97, 0.95, 0.9).darkened(0.06))
		draw_line(c + Vector2(0, -h / 2), c + Vector2(0, h / 2), Color(0.35, 0.22, 0.12, 0.25), 2.0, true)
		# Blümchen am Buch
		SoftShapes.leaf(self, c + Vector2(w - 4, h / 2 + 6), Vector2(1.0, -0.3), 24.0, LEAF)
		SoftShapes.flower(self, c + Vector2(w + 4, h / 2 - 2), 15.0, ROSE, BUTTER, 5, t * 0.3)
		SoftShapes.flower(self, c + Vector2(-w - 6, -h / 2 + 4), 10.0, BUTTER, ROSE, 5, -t * 0.25)
		# Satz in Handschrift (wechselt alle 2,6 s, sanft ein- und ausgeblendet)
		var index := int(t / 2.6) % LINES.size()
		var local := fmod(t, 2.6)
		var alpha := clampf(minf(local / 0.5, (2.6 - local) / 0.5), 0.0, 1.0)
		var text: String = LINES[index]
		var ts := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
		draw_string(TITLE_FONT, Vector2(size.x / 2.0 - ts.x / 2.0, c.y + h / 2 + 80), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48,
			Color(INK, alpha))
		# Bleistiftstrich als Fortschritt
		var line_w := minf(420.0, size.x * 0.4)
		var a := Vector2(size.x / 2.0 - line_w / 2.0, c.y + h / 2 + 118)
		SoftShapes.wavy_line(self, a, a + Vector2(line_w, 0), Color(INK_SOFT, 0.18), 3.0, 1.2, 1)
		var p: float = s._shown_progress
		if p > 0.01:
			SoftShapes.wavy_line(self, a, a + Vector2(line_w * p, 0), ACCENT, 3.5, 1.2, 1)
			SoftShapes.heart(self, a + Vector2(line_w * p + 10, -2), 7.0, ROSE)
		var sub := "Cozy Bücherei"
		var ss := NOTE_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		draw_string(NOTE_FONT, Vector2(size.x / 2.0 - ss.x / 2.0, c.y - h / 2 - 50), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK_SOFT)
