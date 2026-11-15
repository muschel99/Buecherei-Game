class_name TodoNote
extends Control
## To-do-Zettel am rechten Rand (Wunsch der Entwicklerin: nach der Übergabe durch die Maklerin kleine Listen für die kleinen
## Schritte): ein kleiner, leicht schräger Papierzettel mit Washi-Tape, Überschrift in Handschrift, Kästchen und – wo es
## hilft – dem Tastensymbol. Erledigtes hakt sich von selbst ab (Häkchen wird gezeichnet, Text durchgestrichen); ist der Zettel
## fertig, gleitet er nach rechts hinaus und der nächste herein (Tutorial.todo_changed). Inhalt: data/tutorial/todo.txt.
## Ausblenden: Einstellung „interface/todo“; in Menüs und Gesprächen tritt er zurück. Liegt im HUD (dort mit ausgeblendet).

const PAPER := Color(1.0, 0.975, 0.9)
const MARGIN_LINE := Color(0.93, 0.62, 0.64, 0.55)
const TAPE := Color(0.73, 0.86, 0.78, 0.85)
const INK := Color(0.33, 0.23, 0.19)
const INK_SOFT := Color(0.5, 0.39, 0.32)
const TICK := Color(0.84, 0.42, 0.44)
const TITLE_FONT := preload("res://assets/ui/fonts/Caveat-Bold.woff2")
const HAND := preload("res://assets/ui/fonts/PatrickHand-Regular.woff2")
const WIDTH := 350.0
const SLIDE := 360.0

var _paper: Paper
var _title: Label
var _rows: VBoxContainer
var _shown_index := -2
var _checks: Dictionary = {}  # Kennung → Check
var _tween: Tween
var _quiet := 0.0  # 0 = voll sichtbar, 1 = zurückgetreten (Menü, Gespräch)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -WIDTH - 26.0
	offset_right = -26.0
	offset_top = 118.0
	offset_bottom = 118.0
	_paper = Paper.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.custom_minimum_size = Vector2(WIDTH, 0)
	_paper.add_theme_constant_override("margin_left", 40)
	_paper.add_theme_constant_override("margin_right", 18)
	_paper.add_theme_constant_override("margin_top", 26)
	_paper.add_theme_constant_override("margin_bottom", 34)
	add_child(_paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(box)
	_title = Label.new()
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 31)
	_title.add_theme_color_override("font_color", INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 7)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rows)
	_paper.resized.connect(func() -> void: _paper.pivot_offset = _paper.size / 2.0)
	# Höhe immer nach dem Inhalt (umbrechende Zeilen sind beim ersten Aufbau zu hoch)
	_paper.minimum_size_changed.connect(_fit_paper.call_deferred)
	_paper.rotation_degrees = 1.4
	_paper.visible = false
	Tutorial.todo_changed.connect(_on_todo_changed)
	Settings.setting_changed.connect(_on_setting_changed)
	_on_todo_changed.call_deferred()


func _process(delta: float) -> void:
	# In Menüs, Gesprächen und an der Theke tritt der Zettel zurück
	var quiet := MenuStack.has_open() or Conversation.current != null
	_quiet = move_toward(_quiet, 1.0 if quiet else 0.0, delta * 4.0)
	modulate.a = 1.0 - _quiet * 0.85


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "interface/todo":
		visible = bool(Settings.get_value("interface/todo"))


func _on_todo_changed() -> void:
	visible = bool(Settings.get_value("interface/todo"))
	var list := Tutorial.current_list()
	var index := Tutorial.list_index if not list.is_empty() else -1
	if index != _shown_index:
		_swap_to(list, index)
		return
	# derselbe Zettel: neu Erledigtes abhaken
	for id: String in _checks:
		var check: Check = _checks[id]
		if Tutorial.is_done(id) and not check.done:
			check.tick()


## Alten Zettel hinausgleiten lassen, neuen herein.
func _swap_to(list: Dictionary, index: int) -> void:
	var had_note := _paper.visible and _shown_index >= 0
	_shown_index = index
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if had_note:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.tween_property(_paper, "position:x", SLIDE, 0.55)
	_tween.tween_callback(_fill.bind(list))
	if list.is_empty():
		return
	_tween.tween_property(_paper, "position:x", 0.0, 0.7).from(SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill(list: Dictionary) -> void:
	for child in _rows.get_children():
		child.queue_free()
	_checks.clear()
	if list.is_empty():
		_paper.visible = false
		return
	_title.text = String(list.title)
	for task: Dictionary in (list.tasks as Array):
		_rows.add_child(_make_row(task))
	_paper.visible = true
	_fit_paper.call_deferred()
	Audio.play("books/page", -10.0, Audio.vary(0.06))


func _fit_paper() -> void:
	_paper.size = Vector2(WIDTH, 0.0)  # schrumpft auf die Mindestgröße


func _make_row(task: Dictionary) -> Control:
	var row := make_row(String(task.text), String(task.get("action", "")), Tutorial.is_done(String(task.id)))
	_checks[String(task.id)] = row.get_meta("check")
	return row


## Eine Zeile: Kästchen, Text in Handschrift, Tastensymbole (Aktionen mit Komma getrennt, z. B. "build_item_prev,build_item_next").
## Das Kästchen steht als Metadatum "check" an der Zeile (auch für die Bedien-Anleitung an der Theke, DeskSteps).
static func make_row(text: String, actions: String, done: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var check := Check.new()
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (in der Theken-Ansicht ist die Maus frei – Klicks gehen in die Welt)
	check.done = done
	check.custom_minimum_size = Vector2(24, 24)
	check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(check)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", HAND)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	check.label = label
	check.apply_done_look(false)
	for entry in actions.split(",", false):
		var action := StringName(entry.strip_edges())
		if InputMap.has_action(action):
			var key := InkKey.new()
			key.setup(action)
			key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(key)
	row.set_meta("check", check)
	return row


## Das Papier: weicher Zettel mit rosa Randlinie, einem Streifen Washi-Tape oben und einem Blümchen unten.
class Paper extends MarginContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var paper := SoftShapes.rounded_all(r, 8.0, 1.2, 17)
		SoftShapes.shadow(self, paper, Vector2(5, 8), Color(0.2, 0.12, 0.06, 0.08), 4, 3.0)
		draw_colored_polygon(paper, PAPER)
		draw_line(Vector2(28, 8), Vector2(28, size.y - 8), MARGIN_LINE, 1.2, true)
		var tape := Rect2(size.x / 2.0 - 46.0, -11.0, 92.0, 24.0)
		var tape_shape := SoftShapes.rounded_all(tape, 3.0, 1.6, 23)
		draw_colored_polygon(tape_shape, TAPE)
		SoftShapes.flower(self, Vector2(size.x - 26.0, size.y - 17.0), 7.0, Color(0.96, 0.72, 0.74), Color(0.98, 0.86, 0.5))


## Ein Kästchen: leer oder mit gezeichnetem Häkchen (wächst beim Abhaken in einem kleinen Strich herein).
class Check extends Control:
	var done := false
	var label: Label
	var _grow := 1.0

	func tick() -> void:
		done = true
		_grow = 0.0
		Audio.play("ui/tab", -8.0, Audio.vary(0.08))
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void:
			_grow = v
			queue_redraw(), 0.0, 1.0, 0.35)
		apply_done_look(true)

	## Erledigt: Text blasser und mit einer weichen Linie durchgestrichen.
	func apply_done_look(animate: bool) -> void:
		if label == null:
			return
		var color := INK_SOFT if done else INK
		color.a = 0.7 if done else 1.0
		if animate:
			create_tween().tween_property(label, "theme_override_colors/font_color", color, 0.4)
		else:
			label.add_theme_color_override("font_color", color)
		if done and not label.draw.is_connected(_strike):
			label.draw.connect(_strike)
			label.queue_redraw()

	## Durchstreichen Zeile für Zeile genau über dem Text (wächst beim Abhaken von links nach rechts).
	func _strike() -> void:
		var lines := {}  # Oberkante der Zeile → Rect2 über alle Buchstaben dieser Zeile
		for i in label.text.length():
			var r := label.get_character_bounds(i)
			if r.size.x <= 0.0:
				continue
			var key := roundi(r.position.y)
			lines[key] = (lines[key] as Rect2).merge(r) if lines.has(key) else r
		var keys := lines.keys()
		keys.sort()
		var total := 0.0
		for key: int in keys:
			total += (lines[key] as Rect2).size.x
		var left := total * _grow
		for key: int in keys:
			var r: Rect2 = lines[key]
			var w := minf(r.size.x, left)
			left -= w
			if w <= 0.5:
				break
			var y := r.position.y + r.size.y * 0.58
			SoftShapes.wavy_line(label, Vector2(r.position.x - 2.0, y), Vector2(r.position.x + w + 2.0, y), Color(TICK, 0.8), 1.6, 1.0)

	func _draw() -> void:
		var box := Rect2(2, 2, size.x - 4, size.y - 4)
		var shape := SoftShapes.rounded_all(box, 6.0, 0.6, 7)
		draw_colored_polygon(shape, Color(1, 1, 1, 0.6))
		draw_polyline(SoftShapes.closed(shape), INK_SOFT, 1.8, true)
		if not done:
			return
		var a := Vector2(5, size.y * 0.52)
		var b := Vector2(size.x * 0.42, size.y - 5)
		var c := Vector2(size.x + 3, -2)
		var first := clampf(_grow / 0.4, 0.0, 1.0)
		var second := clampf((_grow - 0.4) / 0.6, 0.0, 1.0)
		draw_line(a, a.lerp(b, first), TICK, 3.0, true)
		if second > 0.0:
			draw_line(b, b.lerp(c, second), TICK, 3.0, true)
		if label:
			label.queue_redraw()


## Tastensymbol in Tinte (die Symbole unter der Bildmitte sind für das dunkle Spielbild gemacht): Taste mit Namen (nach der
## Belegung, KeyHints.key_name) oder eine kleine Maus mit der gemeinten Taste in Rosa.
class InkKey extends Control:
	const FONT := preload("res://assets/ui/fonts/Nunito-Bold.woff2")
	var kind := KeyHintIcon.Kind.KEY
	var text := "E"

	func setup(action: StringName) -> void:
		var probe := KeyHintIcon.new()
		KeyHints.setup_icon(probe, action, false)
		kind = probe.kind
		text = probe.key_text
		probe.free()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width := 24.0
		if kind == KeyHintIcon.Kind.KEY:
			width = maxf(24.0, FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0)
		custom_minimum_size = Vector2(width, 26.0)

	func _draw() -> void:
		var center := size / 2.0
		if kind == KeyHintIcon.Kind.KEY:
			var rect := Rect2(1.0, 2.0, size.x - 2.0, 22.0)
			var shape := SoftShapes.rounded_all(rect, 6.0, 0.5, 3)
			draw_colored_polygon(shape, Color(1, 1, 1, 0.75))
			draw_polyline(SoftShapes.closed(shape), INK_SOFT, 1.6, true)
			var baseline := rect.position.y + (rect.size.y + FONT.get_ascent(13) - FONT.get_descent(13)) / 2.0
			draw_string(FONT, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, INK)
			return
		# Maus: Körper, Trennlinie, gemeinte Taste gefüllt
		var body := Rect2(center.x - 8.0, 1.0, 16.0, 24.0)
		var shape := SoftShapes.rounded_all(body, 7.5, 0.0, 1)
		draw_colored_polygon(shape, Color(1, 1, 1, 0.75))
		var left := kind == KeyHintIcon.Kind.MOUSE_LEFT
		var right := kind == KeyHintIcon.Kind.MOUSE_RIGHT
		if left or right:
			var x0 := body.position.x + (1.5 if left else body.size.x / 2.0)
			var button := Rect2(x0, body.position.y + 1.5, body.size.x / 2.0 - 1.5, 9.0)
			draw_rect(button, Color(TICK, 0.85))
		elif kind in [KeyHintIcon.Kind.MOUSE_WHEEL, KeyHintIcon.Kind.MOUSE_MIDDLE]:
			# Mausrad: kleines rundes Rad in der Mitte
			var wheel := Rect2(center.x - 2.5, body.position.y + 3.0, 5.0, 8.0)
			draw_colored_polygon(SoftShapes.rounded_all(wheel, 2.4, 0.0, 2), Color(TICK, 0.9))
		draw_polyline(SoftShapes.closed(shape), INK_SOFT, 1.6, true)
		draw_line(Vector2(body.position.x + 1.0, body.position.y + 11.0), Vector2(body.end.x - 1.0, body.position.y + 11.0),
			INK_SOFT, 1.3, true)
		draw_line(Vector2(center.x, body.position.y + 1.0), Vector2(center.x, body.position.y + 11.0), INK_SOFT, 1.3, true)
