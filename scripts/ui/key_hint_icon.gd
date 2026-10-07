class_name KeyHintIcon
extends Control
## Ein kleines, weiches Tastensymbol für die Hinweise unter der Bildmitte:
## eine abgerundete Taste mit Buchstaben (z. B. "E", "Q") oder eine Maus, bei der die linke
## bzw. rechte Taste hell ist. Halte-Aktionen haben einen feinen Ring, der sich beim
## Gedrückthalten füllt (progress).

enum Kind { KEY, MOUSE_LEFT, MOUSE_RIGHT }

const ICON_SIZE := 38.0
const FILL_COLOR := Color(0.12, 0.09, 0.07, 0.42)
const LINE_COLOR := Color(1.0, 0.96, 0.88, 0.92)
const RING_COLOR := Color(1.0, 0.96, 0.88, 0.32)
const PROGRESS_COLOR := Color(1.0, 0.86, 0.6)

var kind: Kind = Kind.KEY
## Buchstabe auf der Taste (nur bei Kind.KEY).
var key_text: String = "E"
## Halte-Aktion: feiner Ring ums Symbol.
var is_hold: bool = false
## Fortschritt beim Gedrückthalten (0 bis 1), kleiner als 0 = kein Fortschritt.
var progress: float = -1.0:
	set(value):
		progress = value
		queue_redraw()

var _box: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_box = StyleBoxFlat.new()
	_box.bg_color = FILL_COLOR
	_box.border_color = LINE_COLOR
	_box.set_border_width_all(2)
	_box.anti_aliasing = true


func _draw() -> void:
	var center := size / 2.0
	match kind:
		Kind.KEY:
			_box.set_corner_radius_all(7)
			var rect := Rect2(center - Vector2(11.0, 11.0), Vector2(22.0, 22.0))
			draw_style_box(_box, rect)
			var font := get_theme_default_font()
			var font_size := 14
			var ascent := font.get_ascent(font_size)
			var descent := font.get_descent(font_size)
			var baseline := center.y + (ascent - descent) / 2.0
			draw_string(font, Vector2(rect.position.x, baseline), key_text, HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x, font_size, LINE_COLOR)
		_:
			_draw_mouse(center, kind == Kind.MOUSE_LEFT)
	if is_hold:
		draw_arc(center, 17.0, 0.0, TAU, 48, RING_COLOR, 1.5, true)
	if progress >= 0.0:
		draw_arc(center, 17.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, PROGRESS_COLOR, 3.0, true)


## Eine kleine Maus: Körper mit Trennlinie, die gemeinte Taste ist hell gefüllt.
func _draw_mouse(center: Vector2, left: bool) -> void:
	var body := Rect2(center - Vector2(8.0, 11.5), Vector2(16.0, 23.0))
	var radius := 7.5
	var split_y := body.position.y + 9.0
	# Die gemeinte Taste (oben links oder rechts, mit abgerundeter Ecke)
	var points := PackedVector2Array()
	if left:
		# Mitte unten -> links unten -> runde Ecke links oben -> Mitte oben
		var corner := Vector2(body.position.x + radius, body.position.y + radius)
		points.append(Vector2(center.x, split_y))
		points.append(Vector2(body.position.x, split_y))
		for i in 9:
			points.append(corner + Vector2.from_angle(PI + i * (PI / 2.0) / 8.0) * radius)
		points.append(Vector2(center.x, body.position.y))
	else:
		# Mitte oben -> runde Ecke rechts oben -> rechts unten -> Mitte unten
		var corner := Vector2(body.end.x - radius, body.position.y + radius)
		points.append(Vector2(center.x, body.position.y))
		for i in 9:
			points.append(corner + Vector2.from_angle(-PI / 2.0 + i * (PI / 2.0) / 8.0) * radius)
		points.append(Vector2(body.end.x, split_y))
		points.append(Vector2(center.x, split_y))
	_box.set_corner_radius_all(int(radius))
	draw_style_box(_box, body)
	draw_colored_polygon(points, Color(LINE_COLOR, 0.85))
	draw_line(Vector2(body.position.x + 1.0, split_y), Vector2(body.end.x - 1.0, split_y), LINE_COLOR, 1.5, true)
	draw_line(Vector2(center.x, body.position.y + 1.0), Vector2(center.x, split_y), LINE_COLOR, 1.5, true)
