class_name CatalogIcons
extends RefCounted
## Gezeichnete Symbole für Kategorien und Unterkategorien (Filter in Shop und Gestaltungsmodus).
##
## Jedes Symbol ist eine kleine Strichzeichnung auf einem 24er-Raster (wie die Symbole der
## Tablet-Knöpfe). Schlüssel: Unterkategorie-ids aus FurnitureData.SUBCATEGORIES (z. B.
## "armchair"), Kategorien als "cat_<name>" (siehe category_key), Oberflächen "surf_wall",
## "surf_floor", "surf_ceiling" sowie "all" (alles) und "neutral" (stilneutral).
## Unbekannte Schlüssel zeigen den ersten Buchstaben – eine neue Unterkategorie funktioniert also
## sofort, ein eigenes Symbol kann man hier nachträglich ergänzen (Funktion in draw()).

const CATEGORY_KEYS := {
	FurnitureData.Category.SHELF: "cat_shelf",
	FurnitureData.Category.SEATING: "cat_seating",
	FurnitureData.Category.TABLE: "cat_table",
	FurnitureData.Category.COUNTER: "cat_counter",
	FurnitureData.Category.LIGHTING: "cat_lighting",
	FurnitureData.Category.DECO: "cat_deco",
	FurnitureData.Category.DIVIDER: "cat_divider",
}

const SURFACE_KEYS := {
	SurfaceData.Kind.WALL: "surf_wall",
	SurfaceData.Kind.FLOOR: "surf_floor",
	SurfaceData.Kind.CEILING: "surf_ceiling",
}


static func category_key(category: FurnitureData.Category) -> String:
	return CATEGORY_KEYS.get(category, "all")


static func surface_key(kind: SurfaceData.Kind) -> String:
	return SURFACE_KEYS.get(kind, "all")


## Zeichnet das Symbol key in das Quadrat rect (Strichstärke passt sich der Größe an).
static func draw(canvas: CanvasItem, key: String, rect: Rect2, color: Color) -> void:
	var p := _Pen.new(canvas, rect, color)
	match key:
		"all":
			for x in [5.0, 13.0]:
				for y in [5.0, 13.0]:
					p.rect(x, y, 6, 6)
		"neutral":
			p.circle(12, 12, 6.5)
		"cat_shelf", "bookshelf":
			p.rect(5, 3, 14, 18)
			p.line(5, 9, 19, 9)
			p.line(5, 15, 19, 15)
			for x in [8.0, 10.0, 12.5]:
				p.line(x, 9, x, 5.5 if x != 10.0 else 6.5)
			p.line(15.5, 15, 17, 11)
			for x in [8.0, 10.0]:
				p.line(x, 15, x, 11.5)
		"deco_shelf":
			p.rect(5, 3, 14, 18)
			p.line(5, 9, 19, 9)
			p.line(5, 15, 19, 15)
			p.circle(10, 7, 1.6)
			p.poly([[14, 9], [15.5, 5.5], [17, 9]])
			p.circle(12, 13, 1.8)
		"wall_shelf":
			p.line(3, 13, 21, 13)
			p.poly([[6, 13], [6, 17], [9, 13]])
			p.poly([[18, 13], [18, 17], [15, 13]])
			p.rect(7, 7, 2.5, 6)
			p.rect(10, 8, 2.5, 5)
			p.circle(16, 11, 1.8)
		"display_case":
			p.rect(6, 3, 12, 18)
			p.line(6, 12, 18, 12)
			p.line(9, 5.5, 11, 3.5)
			p.line(9, 9, 14, 4)
			p.line(9, 18, 13, 14)
		"cabinet":
			p.rect(4, 5, 16, 13)
			p.line(12, 5, 12, 18)
			p.circle(10.5, 11.5, 0.8, true)
			p.circle(13.5, 11.5, 0.8, true)
			p.line(6, 18, 6, 20.5)
			p.line(18, 18, 18, 20.5)
		"cat_seating", "armchair":
			p.poly([[7, 12], [7, 6], [9, 4], [15, 4], [17, 6], [17, 12]])
			p.rect(4, 11, 3, 6)
			p.rect(17, 11, 3, 6)
			p.line(7, 14, 17, 14)
			p.line(5.5, 17, 5.5, 20)
			p.line(18.5, 17, 18.5, 20)
		"sofa":
			p.poly([[5, 12], [5, 7], [19, 7], [19, 12]])
			p.line(12, 7, 12, 14)
			p.rect(2, 11, 3, 6)
			p.rect(19, 11, 3, 6)
			p.line(5, 14, 19, 14)
			p.line(3.5, 17, 3.5, 19.5)
			p.line(20.5, 17, 20.5, 19.5)
		"chair":
			p.line(8, 3, 8, 20)
			p.line(8, 12, 17, 12)
			p.line(17, 12, 17, 20)
			p.line(8, 6, 11, 6)
		"stool":
			p.ellipse(12, 7, 7, 2.5)
			p.line(7, 8.5, 5.5, 20)
			p.line(17, 8.5, 18.5, 20)
			p.line(12, 9.5, 12, 20)
			p.line(7, 15, 17, 15)
		"cat_table", "side_table":
			p.ellipse(12, 7, 7.5, 2.5)
			p.line(12, 9.5, 12, 18)
			p.line(8, 20, 12, 18)
			p.line(16, 20, 12, 18)
		"coffee_table":
			p.line(3, 12, 21, 12)
			p.line(4, 14, 20, 14)
			p.line(5, 14, 5, 18)
			p.line(19, 14, 19, 18)
		"desk":
			p.line(3, 8, 21, 8)
			p.line(4, 8, 4, 20)
			p.rect(13, 8, 7, 12)
			p.line(13, 14, 20, 14)
			p.circle(16.5, 11, 0.8, true)
			p.circle(16.5, 17, 0.8, true)
		"dining_table":
			p.line(2, 9, 22, 9)
			p.line(3, 11, 21, 11)
			p.line(4.5, 11, 4.5, 20)
			p.line(19.5, 11, 19.5, 20)
		"cat_counter":
			p.line(3, 9, 21, 9)
			p.rect(4, 9, 16, 11)
			p.line(4, 13, 20, 13)
			p.rect(14, 4, 5, 5)
		"cat_lighting", "table_lamp":
			p.poly([[8, 4], [16, 4], [18.5, 11], [5.5, 11]], true)
			p.line(12, 11, 12, 18)
			p.ellipse(12, 19, 4.5, 1.5)
		"floor_lamp":
			p.poly([[9, 2.5], [15, 2.5], [17, 8], [7, 8]], true)
			p.line(12, 8, 12, 20)
			p.ellipse(12, 20.5, 4, 1.2)
		"ceiling_lamp":
			p.line(12, 2, 12, 9)
			p.arc(12, 15, 6, PI, TAU)
			p.line(6, 15, 18, 15)
			p.circle(12, 17.5, 1.5)
		"wall_lamp":
			p.line(4, 4, 4, 20)
			p.line(4, 14, 10, 14)
			p.line(10, 14, 12, 9)
			p.poly([[9.5, 4], [15.5, 4], [17.5, 10], [7.5, 10]], true)
		"candle":
			p.rect(9, 11, 6, 9)
			p.line(12, 11, 12, 9)
			p.poly([[12, 3], [14.5, 7.5], [12, 9], [9.5, 7.5]], true)
		"switch":
			p.rect(6, 4, 12, 16)
			p.rect(10, 7, 4, 7)
			p.line(10, 10.5, 14, 10.5)
		"cat_deco", "plant":
			p.poly([[7, 14], [17, 14], [15.5, 21], [8.5, 21]], true)
			p.leaf(12, 14, 12, 3.5, 2.6)
			p.leaf(12, 14, 6, 6.5, 2.4)
			p.leaf(12, 14, 18, 6.5, 2.4)
		"rug":
			p.rect(5, 7, 14, 10)
			p.rect(7.5, 9.5, 9, 5)
			for y in [8.0, 10.5, 13.0, 15.5]:
				p.line(2.5, y, 5, y)
				p.line(19, y, 21.5, y)
		"picture":
			p.rect(3.5, 5, 17, 14)
			p.poly([[5.5, 17], [10, 11], [13, 14], [15.5, 11.5], [18.5, 17]])
			p.circle(16, 8.5, 1.5)
		"figure":
			p.circle(12, 6.5, 3.2)
			p.arc(12, 16, 6, PI, TAU)
			p.line(6, 16, 18, 16)
			p.rect(8, 16, 8, 4.5)
		"textile":
			p.poly([[5, 6], [12, 7.5], [19, 6], [17.5, 12], [19, 18], [12, 16.5], [5, 18], [6.5, 12]], true)
			p.circle(12, 12, 1.2, true)
		"storage":
			p.poly([[4, 10], [20, 10], [18, 20], [6, 20]], true)
			p.line(5, 13.5, 19, 13.5)
			p.line(5.5, 17, 18.5, 17)
			p.arc(12, 10, 5, PI, TAU)
		"books":
			p.rect(4, 15, 16, 4)
			p.rect(6, 11, 13, 4)
			p.rect(5, 7, 12, 4)
		"bookend":
			p.poly([[5, 4], [5, 20], [11, 20]])
			p.poly([[9, 19], [14, 6], [17.5, 7.5], [12.5, 20.5]], true)
		"cat_divider":
			p.poly([[3, 6], [8.5, 4], [8.5, 20], [3, 18]], true)
			p.poly([[8.5, 4], [15.5, 6], [15.5, 18], [8.5, 20]], true)
			p.poly([[15.5, 6], [21, 4], [21, 20], [15.5, 18]], true)
		"surf_wall":
			p.rect(4, 4, 13, 6)
			p.line(17, 7, 20, 7)
			p.line(20, 7, 20, 12)
			p.line(20, 12, 12, 12)
			p.line(12, 12, 12, 15)
			p.rect(10.5, 15, 3, 6)
		"surf_floor":
			p.poly([[7, 7], [17, 7], [21, 18], [3, 18]], true)
			p.line(10.3, 7, 9, 18)
			p.line(13.6, 7, 15, 18)
			p.line(5, 12.5, 19, 12.5)
		"surf_ceiling":
			p.poly([[3, 5], [21, 5], [17, 13], [7, 13]], true)
			p.line(9, 5, 10, 13)
			p.line(15, 5, 14, 13)
			p.line(12, 13, 12, 16)
			p.arc(12, 19.5, 3.2, PI, TAU)
			p.line(8.8, 19.5, 15.2, 19.5)
		_:
			# Unbekannt: der erste Buchstabe in einem Kreis
			p.circle(12, 12, 8)
			var font := ThemeDB.fallback_font
			var size := int(rect.size.y * 0.45)
			var letter := key.substr(0, 1).to_upper()
			var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			canvas.draw_string(font, rect.get_center() + Vector2(-width / 2.0, size * 0.36), letter,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Kleiner Zeichenstift: rechnet Raster-Koordinaten (0–24) in das Ziel-Quadrat um.
class _Pen:
	var canvas: CanvasItem
	var origin: Vector2
	var unit: float
	var color: Color
	var width: float

	func _init(target: CanvasItem, rect: Rect2, line_color: Color) -> void:
		canvas = target
		var side := minf(rect.size.x, rect.size.y)
		origin = rect.position + (rect.size - Vector2(side, side)) / 2.0
		unit = side / 24.0
		color = line_color
		width = maxf(1.2, unit * 1.5)

	func at(x: float, y: float) -> Vector2:
		return origin + Vector2(x, y) * unit

	func line(x0: float, y0: float, x1: float, y1: float) -> void:
		canvas.draw_line(at(x0, y0), at(x1, y1), color, width, true)

	func rect(x: float, y: float, w: float, h: float) -> void:
		poly([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], true)

	func poly(points: Array, closed: bool = false) -> void:
		var line_points := PackedVector2Array()
		for point in points:
			line_points.append(at(point[0], point[1]))
		if closed:
			line_points.append(line_points[0])
		canvas.draw_polyline(line_points, color, width, true)

	func circle(x: float, y: float, r: float, filled: bool = false) -> void:
		if filled:
			canvas.draw_circle(at(x, y), r * unit, color)
		else:
			canvas.draw_arc(at(x, y), r * unit, 0.0, TAU, 32, color, width, true)

	func arc(x: float, y: float, r: float, from: float, to: float) -> void:
		canvas.draw_arc(at(x, y), r * unit, from, to, 20, color, width, true)

	func ellipse(x: float, y: float, rx: float, ry: float) -> void:
		var points := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			points.append(at(x + cos(a) * rx, y + sin(a) * ry))
		canvas.draw_polyline(points, color, width, true)

	## Ein Blatt vom Stiel (x0, y0) bis zur Spitze (x1, y1), Breite w.
	func leaf(x0: float, y0: float, x1: float, y1: float, w: float) -> void:
		var a := Vector2(x0, y0)
		var b := Vector2(x1, y1)
		var side := (b - a).orthogonal().normalized() * w
		var points := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			var bulge := sin(t * PI)
			var q := a.lerp(b, t) + side * bulge
			points.append(at(q.x, q.y))
		for i in range(11, -1, -1):
			var t := i / 12.0
			var bulge := sin(t * PI)
			var q := a.lerp(b, t) - side * bulge
			points.append(at(q.x, q.y))
		canvas.draw_polyline(points, color, width, true)
