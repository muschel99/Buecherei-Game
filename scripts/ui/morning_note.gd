class_name MorningNote
extends CanvasLayer
## Notizzettel am Morgen (seit Etappe 7): Um GameConfig.clock_morning_hour (6 Uhr) – auch nach dem Schlafen – erscheint ein
## abgerissener, linierter Zettel mit den Zahlen des Vortags (Lending.history). Er bleibt, bis man klickt, E oder Esc drückt.
## Alte Zettel liest man in der App „Statistik“ (dort mit NotePaper gezeichnet).

var _paper: NotePaper
var _tween: Tween
var _shown := false


func _ready() -> void:
	layer = 12
	_paper = NotePaper.new()
	_paper.custom_minimum_size = Vector2(360, 440)
	_paper.size = _paper.custom_minimum_size
	_paper.set_anchors_preset(Control.PRESET_CENTER)
	_paper.position = -_paper.size / 2.0
	_paper.pivot_offset = _paper.size / 2.0
	_paper.rotation_degrees = -3.0
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.visible = false
	add_child(_paper)
	GameClock.morning.connect(func(_day: int) -> void: _show_latest.call_deferred())


## Zettel des Vortags zeigen (nur einmal je Tag, nur wenn es ihn gibt).
func _show_latest() -> void:
	if Lending.history.is_empty():
		return
	var stats: Dictionary = Lending.history[Lending.history.size() - 1]
	if int(stats.get("day", 0)) != GameClock.day - 1 or Lending.note_shown_day >= int(stats.day):
		return
	Lending.note_shown_day = int(stats.day)
	show_note(stats)


func show_note(stats: Dictionary) -> void:
	_paper.stats = stats
	_paper.queue_redraw()
	_paper.visible = true
	_paper.modulate.a = 0.0
	_paper.scale = Vector2.ONE * 0.9
	_shown = true
	MenuStack.open(self)
	Audio.play("books/page", -6.0, Audio.vary(0.05))
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_paper, "modulate:a", 1.0, 0.35)
	_tween.tween_property(_paper, "scale", Vector2.ONE, 0.45)


func hide_note() -> void:
	if not _shown:
		return
	_shown = false
	MenuStack.close(self)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_paper, "modulate:a", 0.0, 0.3)
	_tween.tween_property(_paper, "position:y", _paper.position.y + 40.0, 0.3)
	_tween.chain().tween_callback(func() -> void:
		_paper.visible = false
		_paper.position = -_paper.size / 2.0)


func close_from_escape() -> void:
	hide_note()


func _input(event: InputEvent) -> void:
	if not _shown:
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("interact"):
		hide_note()
		get_viewport().set_input_as_handled()


## Ein abgerissener, linierter Zettel mit den Zahlen eines Tages (Handschrift: Serifenschrift kursiv, Tinte blau).
class NotePaper:
	extends Control

	const PAPER := Color(0.98, 0.96, 0.88)
	const LINE := Color(0.55, 0.68, 0.85, 0.45)
	const MARGIN_LINE := Color(0.85, 0.35, 0.35, 0.5)
	const INK := Color(0.16, 0.22, 0.45)
	const SHADOW := Color(0, 0, 0, 0.22)

	var stats: Dictionary = {}
	var _font: Font = load("res://assets/ui/fonts/DejaVuSerif-Italic.ttf")

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var s := h / 440.0  # alles wächst mit der Größe des Zettels
		# Umriss mit abgerissener Oberkante (unregelmäßige Zacken, immer gleich je Tag)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(stats.get("day", 1)) * 7919
		var outline := PackedVector2Array()
		var steps := 22
		for i in steps + 1:
			outline.append(Vector2(w * i / steps, rng.randf_range(0.0, 9.0) * s))
		outline.append(Vector2(w, h))
		outline.append(Vector2(0, h))
		var shadow := PackedVector2Array()
		for p in outline:
			shadow.append(p + Vector2(5, 6) * s)
		draw_colored_polygon(shadow, SHADOW)
		draw_colored_polygon(outline, PAPER)
		# Linien und roter Rand
		var top := 64.0 * s
		var gap := 34.0 * s
		var y := top
		while y < h - 12.0 * s:
			draw_line(Vector2(6 * s, y), Vector2(w - 6 * s, y), LINE, maxf(1.0, s))
			y += gap
		draw_line(Vector2(46 * s, 12 * s), Vector2(46 * s, h), MARGIN_LINE, maxf(1.0, 1.5 * s))
		# Text: Datum oben, dann eine Zeile je Wert (auf den Linien)
		var x := 56.0 * s
		var day := int(stats.get("day", 1))
		var weekday: String = GameClock.WEEKDAYS[(day - 1) % 7]
		draw_string(_font, Vector2(x, top - 10 * s), "%s, Tag %d" % [weekday, day], HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), INK)
		var lines := lines_for(stats)
		for i in lines.size():
			draw_string(_font, Vector2(x, top + gap * (i + 1) - 8 * s), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - x - 10 * s,
				int(19 * s), INK)

	static func lines_for(day_stats: Dictionary) -> Array[String]:
		var result: Array[String] = []
		var visitors := int(day_stats.get("visitors", 0))
		var borrowed := int(day_stats.get("borrowed", 0))
		var returned := int(day_stats.get("returned", 0))
		var cards := int(day_stats.get("cards", 0))
		var income := int(day_stats.get("income", 0))
		var nothing := int(day_stats.get("nothing_found", 0))
		var counter := int(day_stats.get("to_counter", 0))
		if visitors == 0 and returned == 0:
			result.append("Ein ganz ruhiger Tag.")
			result.append("Zeit für Tee und Bücher ♥")
			return result
		result.append("Besucher: %d" % visitors)
		result.append("Ausgeliehen: %d %s" % [borrowed, "Buch" if borrowed == 1 else "Bücher"])
		result.append("Zurückgebracht: %d" % returned)
		if counter > 0:
			result.append("  (%d davon auf der Theke)" % counter)
		if cards > 0:
			result.append("Neue Leseausweise: %d" % cards)
		if nothing > 0:
			result.append("Nichts gefunden: %d" % nothing)
		result.append("Einnahmen: %s" % Wallet.format(income))
		return result
