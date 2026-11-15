class_name DeskSteps
extends CanvasLayer
## Kleine Anleitung in der Theken-Ansicht (CounterDesk; Wunsch der Entwicklerin nach Etappe 8b: „Wie bediene ich einen Kunden?
## Was muss ich nach und nach alles drücken?“): ein Zettel oben rechts (dort ist nur Fußboden, die Tüte links bleibt frei) mit
## den drei Handgriffen – Ausweis, Bücher, Tüte. Der
## jetzige Schritt ist hervorgehoben (Rosa), Erledigtes hakt sich ab (Bausteine aus TodoNote). Erscheint bei den
## ersten GameConfig.desk_help_servings Bedienungen (Tutorial.desk_help_wanted) und nur mit der Einstellung „To-do-Zettel“.

const TEXTS := [
	"Den Ausweis anklicken – er kommt in den Kartenleser",
	"Die Bücher nacheinander anklicken – sie gehen über den Scanner in die Tüte",
	"Die Tüte anklicken – der Gast bekommt sie",
]
const ACTIVE := Color(0.78, 0.36, 0.4)
const WIDTH := 330.0

var _paper: TodoNote.Paper
var _rows: Array[HBoxContainer] = []
var _step := -1
var _count: Label


func _ready() -> void:
	layer = 8
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_paper = TodoNote.Paper.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.custom_minimum_size = Vector2(WIDTH, 0)
	_paper.rotation_degrees = 1.2
	# oben rechts (Anker rechts, damit es bei jeder Fenstergröße passt)
	holder.resized.connect(_place)
	_paper.add_theme_constant_override("margin_left", 40)
	_paper.add_theme_constant_override("margin_right", 18)
	_paper.add_theme_constant_override("margin_top", 24)
	_paper.add_theme_constant_override("margin_bottom", 32)
	holder.add_child(_paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(box)
	var title := Label.new()
	title.text = "So bedienst du"
	title.add_theme_font_override("font", TodoNote.TITLE_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", TodoNote.INK)
	box.add_child(title)
	for text: String in TEXTS:
		var row := TodoNote.make_row(text, "book_place", false)
		box.add_child(row)
		_rows.append(row)
	# wie viele Bücher schon gescannt sind (neben dem zweiten Schritt)
	_count = Label.new()
	_count.add_theme_font_override("font", TodoNote.HAND)
	_count.add_theme_font_size_override("font_size", 17)
	_count.add_theme_color_override("font_color", ACTIVE)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_count)
	box.move_child(_count, 3)
	_paper.minimum_size_changed.connect(func() -> void: _paper.size = Vector2(WIDTH, 0.0))
	_paper.size = Vector2(WIDTH, 0.0)
	_place.call_deferred()
	# weich hereingleiten
	_paper.modulate.a = 0.0
	create_tween().tween_property(_paper, "modulate:a", 1.0, 0.35)


func _place() -> void:
	var holder := _paper.get_parent() as Control
	_paper.position = Vector2(holder.size.x - WIDTH - 30.0, 70.0)


## Stand übernehmen: step = 0 Ausweis, 1 Bücher, 2 Tüte, 3 fertig; scanned/total = Bücher.
func set_state(step: int, scanned: int, total: int) -> void:
	_count.text = "%d von %d Büchern" % [scanned, total] if step == 1 and total > 0 else ""
	_count.visible = step == 1 and total > 0
	if step == _step:
		return
	var first := _step < 0
	_step = step
	for i in _rows.size():
		var check: TodoNote.Check = _rows[i].get_meta("check")
		var label := _rows[i].get_child(1) as Label
		if i < step and not check.done:
			if first:
				check.done = true
				check.apply_done_look(false)
			else:
				check.tick()
		elif i == step:
			label.add_theme_color_override("font_color", ACTIVE)
		elif not check.done:
			label.add_theme_color_override("font_color", TodoNote.INK_SOFT)
