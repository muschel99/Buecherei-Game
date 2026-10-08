class_name TipSymbol
extends Control
## Kleines gezeichnetes Symbol für ein Thema im Tipps-Büchlein (z. B. "keys", "books").
## Welche es gibt, steht in KINDS; unbekannte Namen zeigen einen kleinen Stern.

const KINDS := ["keys", "books", "shelf", "deco", "furniture", "palette", "shop", "heart", "lamp", "star"]

var kind := "star"
var color := Color(0.45, 0.31, 0.2)


static func create(new_kind: String, new_color: Color, side: float = 30.0) -> TipSymbol:
	var symbol := TipSymbol.new()
	symbol.kind = new_kind if KINDS.has(new_kind) else "star"
	symbol.color = new_color
	symbol.custom_minimum_size = Vector2(side, side)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return symbol


func _draw() -> void:
	# Gezeichnet für 30 x 30, auf die echte Größe gebracht
	var factor := minf(size.x, size.y) / 30.0
	draw_set_transform((size - Vector2(30, 30) * factor) / 2.0, 0.0, Vector2(factor, factor))
	var c := Vector2(15, 15)
	var w := 1.8
	match kind:
		"keys":
			# Zwei Tastenkappen
			for x in [3.0, 16.0]:
				_round_rect(Rect2(x, 9, 11, 11), w)
			draw_line(Vector2(6.5, 23), Vector2(23.5, 23), color, w, true)
		"books":
			# Drei Bücher, eins angelehnt
			_rect(Rect2(5, 8, 5, 16), w)
			_rect(Rect2(11, 6, 5, 18), w)
			draw_polyline(PackedVector2Array([Vector2(18, 24), Vector2(21.5, 8), Vector2(26, 9), Vector2(22.5, 25)]), color, w, true)
			draw_line(Vector2(3, 25), Vector2(27, 25), color, w, true)
		"shelf":
			_rect(Rect2(5, 4, 20, 22), w)
			draw_line(Vector2(5, 15), Vector2(25, 15), color, w, true)
			for x in [8.0, 11.0, 14.0]:
				draw_line(Vector2(x, 13), Vector2(x, 7), color, w, true)
			draw_line(Vector2(16, 24), Vector2(21, 18), color, w, true)
		"deco":
			# Topfpflanze
			draw_polyline(PackedVector2Array([Vector2(9, 18), Vector2(21, 18), Vector2(19, 26), Vector2(11, 26), Vector2(9, 18)]), color, w, true)
			draw_line(Vector2(15, 18), Vector2(15, 9), color, w, true)
			_leaf(Vector2(11, 11), -0.6)
			_leaf(Vector2(19, 8), 0.6)
		"furniture":
			# Sessel
			_round_rect(Rect2(7, 6, 16, 12), w)
			_rect(Rect2(4, 14, 22, 7), w)
			draw_line(Vector2(7, 21), Vector2(7, 25), color, w, true)
			draw_line(Vector2(23, 21), Vector2(23, 25), color, w, true)
		"palette":
			# Farbroller
			_round_rect(Rect2(5, 5, 18, 7), w)
			draw_polyline(PackedVector2Array([Vector2(23, 8.5), Vector2(26, 8.5), Vector2(26, 15), Vector2(15, 15), Vector2(15, 19)]), color, w, true)
			_rect(Rect2(13, 19, 4, 7), w)
		"shop":
			# Karton mit Klebeband
			_rect(Rect2(5, 10, 20, 15), w)
			draw_polyline(PackedVector2Array([Vector2(5, 10), Vector2(9, 5), Vector2(29, 5), Vector2(25, 10)]), color, w, true)
			draw_line(Vector2(15, 10), Vector2(19, 5), color, w, true)
			draw_line(Vector2(15, 10), Vector2(15, 16), color, w, true)
		"heart":
			_heart(c + Vector2(0, 1), 10.0)
		"lamp":
			draw_colored_polygon(PackedVector2Array([Vector2(9, 12), Vector2(21, 12), Vector2(18, 4), Vector2(12, 4)]), color)
			draw_line(Vector2(15, 12), Vector2(15, 25), color, w, true)
			draw_line(Vector2(10, 25), Vector2(20, 25), color, w, true)
		_:
			_star(c, 11.0)


func _rect(rect: Rect2, width: float) -> void:
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]), color, width, true)


func _round_rect(rect: Rect2, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(ceil(width)))
	box.set_corner_radius_all(3)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _leaf(at: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	for i in 14:
		var t := TAU * i / 14.0
		points.append(at + Vector2(cos(t) * 4.5, sin(t) * 2.2).rotated(angle))
	draw_colored_polygon(points, color)


func _heart(at: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(at + Vector2(x, y) * r / 16.0)
	draw_colored_polygon(points, color)


func _star(at: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		points.append(at + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius)
	draw_colored_polygon(points, color)
