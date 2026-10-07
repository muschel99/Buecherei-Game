class_name BookMotifs
extends RefCounted
## Kleine Bilder (Motive) für Cover und Buchrücken – aus einfachen Formen gezeichnet.
##
## Aufruf: BookMotifs.draw(canvas_item, "lighthouse", rechteck, farbe, schmuckfarbe)
## Jedes Motiv wird in ein Quadrat gezeichnet (Koordinaten 0 bis 1, mittig im Rechteck).
## Neues Motiv: unten eine Funktion _motif_<name>(c, r, col, acc) ergänzen – dann kann es in
## den Bücherlisten (data/books/) verwendet werden. Liste aller Motive: names().

const _SEGMENTS := 28

## Alle Motive (Name -> true), einmal aus den Funktionen _motif_... gelesen
static var _known: Dictionary = {}


## Alle vorhandenen Motive (Namen wie in den Bücherlisten).
static func names() -> Array[String]:
	_find_motifs()
	var result: Array[String] = []
	result.assign(_known.keys())
	result.sort()
	return result


## Gibt es dieses Motiv?
static func has_motif(motif: String) -> bool:
	_find_motifs()
	return _known.has(motif)


static func _find_motifs() -> void:
	if not _known.is_empty():
		return
	var script: Script = load("res://scripts/ui/book_motifs.gd")
	for method in script.get_script_method_list():
		var method_name: String = method.name
		if method_name.begins_with("_motif_"):
			_known[method_name.trim_prefix("_motif_")] = true


## Zeichnet ein Motiv in das (quadratische) Feld in der Mitte von rect.
## color = Hauptfarbe, accent = Farbe für Details.
static func draw(ci: CanvasItem, motif: String, rect: Rect2, color: Color, accent: Color) -> void:
	if not has_motif(motif):
		return
	var side := minf(rect.size.x, rect.size.y)
	var square := Rect2(rect.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))
	# Die Funktion _motif_<name> über das Script aufrufen (sie ist statisch)
	var script: Script = load("res://scripts/ui/book_motifs.gd")
	script.call("_motif_" + motif, ci, square, color, accent)


# --- Zeichenhilfen (Koordinaten von 0 bis 1 im Quadrat r) ---

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size


static func _pts(r: Rect2, coords: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		result.append(_p(r, coords[i], coords[i + 1]))
	return result


static func _poly(c: CanvasItem, r: Rect2, coords: Array, col: Color) -> void:
	c.draw_colored_polygon(_pts(r, coords), col)


static func _circle(c: CanvasItem, r: Rect2, x: float, y: float, radius: float, col: Color) -> void:
	c.draw_circle(_p(r, x, y), radius * r.size.x, col, true, -1.0, true)


static func _ring(c: CanvasItem, r: Rect2, x: float, y: float, radius: float, width: float, col: Color) -> void:
	c.draw_arc(_p(r, x, y), radius * r.size.x, 0.0, TAU, _SEGMENTS * 2, col, width * r.size.x, true)


static func _arc(c: CanvasItem, r: Rect2, x: float, y: float, radius: float, from_deg: float, to_deg: float,
		width: float, col: Color) -> void:
	c.draw_arc(_p(r, x, y), radius * r.size.x, deg_to_rad(from_deg), deg_to_rad(to_deg), _SEGMENTS, col,
		width * r.size.x, true)


static func _ellipse(c: CanvasItem, r: Rect2, x: float, y: float, rx: float, ry: float, col: Color,
		rotation: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in _SEGMENTS:
		var angle := TAU * i / _SEGMENTS
		var offset := Vector2(cos(angle) * rx, sin(angle) * ry).rotated(deg_to_rad(rotation))
		points.append(_p(r, x + offset.x, y + offset.y))
	c.draw_colored_polygon(points, col)


static func _rect(c: CanvasItem, r: Rect2, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(_p(r, x, y), Vector2(w, h) * r.size), col)


static func _line(c: CanvasItem, r: Rect2, coords: Array, width: float, col: Color) -> void:
	c.draw_polyline(_pts(r, coords), col, width * r.size.x, true)


## Halbe Ellipse (oben oder unten offen), z. B. für Tassen, Hügel, Pilzhüte.
static func _half_ellipse(c: CanvasItem, r: Rect2, x: float, y: float, rx: float, ry: float, col: Color,
		top: bool) -> void:
	var points := PackedVector2Array()
	for i in _SEGMENTS + 1:
		var angle := PI * i / _SEGMENTS
		points.append(_p(r, x + cos(angle) * rx, y + (-1.0 if top else 1.0) * sin(angle) * ry))
	c.draw_colored_polygon(points, col)


## Stern mit n Zacken.
static func _star(c: CanvasItem, r: Rect2, x: float, y: float, outer: float, inner: float, col: Color,
		points_count: int = 5) -> void:
	var points := PackedVector2Array()
	for i in points_count * 2:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + PI * i / points_count
		points.append(_p(r, x + cos(angle) * radius, y + sin(angle) * radius))
	c.draw_colored_polygon(points, col)


## Mondsichel: Kreis (x, y, radius) ohne den Teil, den ein verschobener Kreis verdeckt.
static func _crescent(c: CanvasItem, r: Rect2, x: float, y: float, radius: float, shift: Vector2,
		cut_radius: float, col: Color) -> void:
	var cut_center := Vector2(x, y) + shift
	var points := PackedVector2Array()
	var steps := 48
	# Außenkante (alles, was außerhalb des verdeckenden Kreises liegt)
	var start := shift.angle() + PI
	for i in steps + 1:
		var angle := start - PI + TAU * i / steps
		var point := Vector2(x, y) + Vector2(cos(angle), sin(angle)) * radius
		if point.distance_to(cut_center) >= cut_radius:
			points.append(_p(r, point.x, point.y))
	# Innenkante (Teil des verdeckenden Kreises innerhalb des Mondes), rückwärts
	var inner := PackedVector2Array()
	for i in steps + 1:
		var angle := TAU * i / steps
		var point := cut_center + Vector2(cos(angle), sin(angle)) * cut_radius
		if point.distance_to(Vector2(x, y)) <= radius:
			inner.append(_p(r, point.x, point.y))
	if points.size() < 3 or inner.is_empty():
		_circle(c, r, x, y, radius, col)
		return
	# Innenkante so anhängen, dass sie am letzten Punkt der Außenkante weitergeht
	var ordered := _order_arc(inner, points[points.size() - 1])
	points.append_array(ordered)
	c.draw_colored_polygon(points, col)


## Ordnet Punkte eines Kreisbogens so, dass er beim Punkt "near" beginnt.
static func _order_arc(arc: PackedVector2Array, near: Vector2) -> PackedVector2Array:
	# Größte Lücke im Bogen suchen (dort ist er "offen") und dort aufschneiden
	var gap_index := 0
	var gap := 0.0
	for i in arc.size():
		var distance := arc[i].distance_to(arc[(i + 1) % arc.size()])
		if distance > gap:
			gap = distance
			gap_index = i
	var ordered := PackedVector2Array()
	for i in arc.size():
		ordered.append(arc[(gap_index + 1 + i) % arc.size()])
	if ordered[ordered.size() - 1].distance_to(near) < ordered[0].distance_to(near):
		ordered.reverse()
	return ordered


# --- Himmel und Wetter ---

static func _motif_moon(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_crescent(c, r, 0.48, 0.5, 0.33, Vector2(0.16, -0.08), 0.28, col)
	_star(c, r, 0.76, 0.28, 0.07, 0.03, acc)
	_star(c, r, 0.8, 0.62, 0.045, 0.02, acc)


static func _motif_sun(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	for i in 10:
		var angle := TAU * i / 10.0
		var direction := Vector2(cos(angle), sin(angle))
		_line(c, r, [0.5 + direction.x * 0.27, 0.5 + direction.y * 0.27, 0.5 + direction.x * 0.42,
			0.5 + direction.y * 0.42], 0.05, col)
	_circle(c, r, 0.5, 0.5, 0.22, col)
	_circle(c, r, 0.44, 0.44, 0.06, acc.lerp(col, 0.4))


static func _motif_star(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_star(c, r, 0.5, 0.52, 0.42, 0.18, col)
	_star(c, r, 0.5, 0.52, 0.18, 0.08, acc)


static func _motif_stars(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_star(c, r, 0.38, 0.58, 0.26, 0.11, col)
	_star(c, r, 0.72, 0.3, 0.15, 0.065, acc)
	_star(c, r, 0.76, 0.72, 0.1, 0.045, col)
	_star(c, r, 0.18, 0.22, 0.07, 0.03, acc)


static func _motif_sparkle(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_star(c, r, 0.45, 0.52, 0.36, 0.08, col, 4)
	_star(c, r, 0.76, 0.24, 0.14, 0.035, acc, 4)
	_star(c, r, 0.78, 0.76, 0.09, 0.025, col, 4)


static func _motif_cloud(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.33, 0.56, 0.15, col)
	_circle(c, r, 0.52, 0.44, 0.2, col)
	_circle(c, r, 0.7, 0.56, 0.14, col)
	_rect(c, r, 0.33, 0.56, 0.37, 0.14, col)
	_line(c, r, [0.3, 0.82, 0.24, 0.92], 0.035, acc)
	_line(c, r, [0.5, 0.82, 0.44, 0.92], 0.035, acc)
	_line(c, r, [0.7, 0.82, 0.64, 0.92], 0.035, acc)


static func _motif_rainbow(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_arc(c, r, 0.5, 0.72, 0.38, 180, 360, 0.08, col)
	_arc(c, r, 0.5, 0.72, 0.29, 180, 360, 0.08, acc)
	_arc(c, r, 0.5, 0.72, 0.2, 180, 360, 0.08, col.lerp(acc, 0.5))
	_circle(c, r, 0.14, 0.76, 0.08, Color(1, 1, 1, 0.9))
	_circle(c, r, 0.86, 0.76, 0.08, Color(1, 1, 1, 0.9))


static func _motif_snowflake(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	for i in 6:
		var angle := TAU * i / 6.0
		var tip := Vector2(cos(angle), sin(angle))
		_line(c, r, [0.5, 0.5, 0.5 + tip.x * 0.4, 0.5 + tip.y * 0.4], 0.045, col)
		var mid := Vector2(0.5, 0.5) + tip * 0.26
		for side in [-1.0, 1.0]:
			var branch := tip.rotated(side * 0.8) * 0.1
			_line(c, r, [mid.x, mid.y, mid.x + branch.x, mid.y + branch.y], 0.035, col)
	_circle(c, r, 0.5, 0.5, 0.06, acc)


# --- Pflanzen ---

static func _motif_tree(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.45, 0.55, 0.1, 0.35, acc)
	_circle(c, r, 0.5, 0.42, 0.26, col)
	_circle(c, r, 0.32, 0.52, 0.16, col)
	_circle(c, r, 0.68, 0.52, 0.16, col)
	_circle(c, r, 0.42, 0.36, 0.05, acc.lerp(col, 0.5))


static func _motif_pine(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.45, 0.78, 0.1, 0.14, acc)
	_poly(c, r, [0.5, 0.08, 0.72, 0.38, 0.28, 0.38], col)
	_poly(c, r, [0.5, 0.24, 0.78, 0.58, 0.22, 0.58], col)
	_poly(c, r, [0.5, 0.42, 0.84, 0.8, 0.16, 0.8], col)


static func _motif_leaf(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.48, 0.2, 0.38, col, 35)
	_line(c, r, [0.28, 0.82, 0.5, 0.48, 0.7, 0.18], 0.03, acc)
	_line(c, r, [0.5, 0.48, 0.38, 0.4], 0.02, acc)
	_line(c, r, [0.56, 0.38, 0.68, 0.44], 0.02, acc)


static func _motif_flower(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_line(c, r, [0.5, 0.5, 0.5, 0.94], 0.04, acc.lerp(col, 0.3))
	_ellipse(c, r, 0.62, 0.78, 0.1, 0.05, acc.lerp(col, 0.3), -30)
	for i in 6:
		var angle := TAU * i / 6.0
		_circle(c, r, 0.5 + cos(angle) * 0.17, 0.38 + sin(angle) * 0.17, 0.12, col)
	_circle(c, r, 0.5, 0.38, 0.1, acc)


static func _motif_tulip(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_line(c, r, [0.5, 0.5, 0.5, 0.94], 0.04, acc)
	_ellipse(c, r, 0.38, 0.74, 0.07, 0.17, acc, -30)
	_poly(c, r, [0.3, 0.2, 0.4, 0.32, 0.5, 0.16, 0.6, 0.32, 0.7, 0.2, 0.68, 0.46, 0.5, 0.58, 0.32, 0.46], col)


static func _motif_mushroom(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.4, 0.5, 0.2, 0.36, acc)
	_half_ellipse(c, r, 0.5, 0.54, 0.36, 0.34, col, true)
	_circle(c, r, 0.36, 0.38, 0.05, acc)
	_circle(c, r, 0.56, 0.3, 0.06, acc)
	_circle(c, r, 0.68, 0.44, 0.04, acc)


static func _motif_plant(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.36, 0.36, 0.08, 0.2, col, -30)
	_ellipse(c, r, 0.64, 0.36, 0.08, 0.2, col, 30)
	_ellipse(c, r, 0.5, 0.28, 0.08, 0.22, col)
	_poly(c, r, [0.28, 0.56, 0.72, 0.56, 0.66, 0.9, 0.34, 0.9], acc)
	_rect(c, r, 0.26, 0.54, 0.48, 0.06, acc.darkened(0.15))


static func _motif_cactus(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.42, 0.18, 0.16, 0.5, col)
	_circle(c, r, 0.5, 0.18, 0.08, col)
	_rect(c, r, 0.26, 0.36, 0.1, 0.2, col)
	_rect(c, r, 0.26, 0.5, 0.2, 0.08, col)
	_rect(c, r, 0.64, 0.28, 0.1, 0.2, col)
	_rect(c, r, 0.54, 0.42, 0.2, 0.08, col)
	_poly(c, r, [0.3, 0.66, 0.7, 0.66, 0.64, 0.92, 0.36, 0.92], acc)


# --- Orte und Gebäude ---

static func _motif_house(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.22, 0.46, 0.56, 0.42, col)
	_poly(c, r, [0.14, 0.48, 0.5, 0.16, 0.86, 0.48], acc)
	_rect(c, r, 0.44, 0.64, 0.12, 0.24, acc)
	_rect(c, r, 0.28, 0.54, 0.1, 0.1, acc)
	_rect(c, r, 0.62, 0.54, 0.1, 0.1, acc)
	_rect(c, r, 0.64, 0.2, 0.08, 0.16, col)


static func _motif_lighthouse(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.5, 0.2, 0.92, 0.12, 0.92, 0.34], Color(acc, 0.35))
	_poly(c, r, [0.5, 0.2, 0.08, 0.12, 0.08, 0.34], Color(acc, 0.35))
	_poly(c, r, [0.4, 0.3, 0.6, 0.3, 0.66, 0.9, 0.34, 0.9], col)
	_poly(c, r, [0.38, 0.48, 0.62, 0.48, 0.63, 0.58, 0.37, 0.58], acc)
	_poly(c, r, [0.36, 0.7, 0.64, 0.7, 0.65, 0.8, 0.35, 0.8], acc)
	_rect(c, r, 0.42, 0.16, 0.16, 0.14, acc)
	_poly(c, r, [0.38, 0.17, 0.5, 0.06, 0.62, 0.17], col)
	_rect(c, r, 0.36, 0.28, 0.28, 0.03, col)


static func _motif_castle(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.22, 0.44, 0.56, 0.46, col)
	for i in 4:
		_rect(c, r, 0.24 + i * 0.14, 0.38, 0.08, 0.07, col)
	_rect(c, r, 0.12, 0.3, 0.16, 0.6, col)
	_rect(c, r, 0.72, 0.3, 0.16, 0.6, col)
	_poly(c, r, [0.1, 0.32, 0.2, 0.14, 0.3, 0.32], acc)
	_poly(c, r, [0.7, 0.32, 0.8, 0.14, 0.9, 0.32], acc)
	_half_ellipse(c, r, 0.5, 0.9, 0.09, 0.2, acc, true)
	_line(c, r, [0.8, 0.14, 0.8, 0.04], 0.015, acc)
	_poly(c, r, [0.8, 0.04, 0.9, 0.07, 0.8, 0.1], acc)


static func _motif_island(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_half_ellipse(c, r, 0.5, 0.78, 0.38, 0.14, acc, true)
	_line(c, r, [0.5, 0.74, 0.52, 0.5, 0.56, 0.3], 0.04, col.darkened(0.1))
	_ellipse(c, r, 0.44, 0.3, 0.14, 0.05, col, -20)
	_ellipse(c, r, 0.68, 0.3, 0.14, 0.05, col, 20)
	_ellipse(c, r, 0.56, 0.22, 0.04, 0.12, col, 10)
	_line(c, r, [0.1, 0.88, 0.25, 0.85, 0.4, 0.88, 0.55, 0.85, 0.7, 0.88, 0.9, 0.85], 0.03, col)


static func _motif_mountain(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.06, 0.86, 0.4, 0.22, 0.74, 0.86], col)
	_poly(c, r, [0.4, 0.86, 0.66, 0.4, 0.94, 0.86], col.darkened(0.15))
	_poly(c, r, [0.4, 0.22, 0.49, 0.39, 0.44, 0.36, 0.4, 0.42, 0.35, 0.36, 0.31, 0.39], acc)
	_poly(c, r, [0.66, 0.4, 0.73, 0.53, 0.66, 0.5, 0.6, 0.53], acc)


static func _motif_map(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.12, 0.22, 0.38, 0.14, 0.38, 0.8, 0.12, 0.88], col)
	_poly(c, r, [0.38, 0.14, 0.62, 0.22, 0.62, 0.88, 0.38, 0.8], col.lightened(0.18))
	_poly(c, r, [0.62, 0.22, 0.88, 0.14, 0.88, 0.8, 0.62, 0.88], col)
	_line(c, r, [0.2, 0.7, 0.32, 0.56, 0.46, 0.6, 0.56, 0.44, 0.7, 0.4], 0.025, acc)
	_line(c, r, [0.72, 0.3, 0.8, 0.38], 0.03, acc)
	_line(c, r, [0.8, 0.3, 0.72, 0.38], 0.03, acc)


# --- Wasser und Reisen ---

static func _motif_boat(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.14, 0.62, 0.86, 0.62, 0.74, 0.8, 0.26, 0.8], col)
	_line(c, r, [0.5, 0.62, 0.5, 0.12], 0.03, col)
	_poly(c, r, [0.53, 0.14, 0.53, 0.56, 0.8, 0.56], acc)
	_poly(c, r, [0.47, 0.22, 0.47, 0.56, 0.26, 0.56], acc.lerp(col, 0.3))
	_line(c, r, [0.08, 0.88, 0.22, 0.84, 0.36, 0.88, 0.5, 0.84, 0.64, 0.88, 0.78, 0.84, 0.92, 0.88], 0.03, acc)


static func _motif_anchor(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ring(c, r, 0.5, 0.18, 0.07, 0.035, col)
	_line(c, r, [0.5, 0.25, 0.5, 0.84], 0.06, col)
	_line(c, r, [0.32, 0.36, 0.68, 0.36], 0.05, col)
	_arc(c, r, 0.5, 0.58, 0.28, 20, 160, 0.06, col)
	_poly(c, r, [0.72, 0.6, 0.86, 0.66, 0.76, 0.74], col)
	_poly(c, r, [0.28, 0.6, 0.14, 0.66, 0.24, 0.74], col)
	_circle(c, r, 0.5, 0.36, 0.04, acc)


static func _motif_wave(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	for row in 3:
		var y := 0.34 + row * 0.18
		var coords := []
		for i in 13:
			var x := 0.08 + i * 0.07
			coords.append(x)
			coords.append(y + sin(i * 1.1 + row) * 0.05)
		_line(c, r, coords, 0.05, col if row != 1 else acc)


static func _motif_shell(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	var points := [0.5, 0.86]
	for i in 11:
		var angle := PI + PI * i / 10.0
		points.append(0.5 + cos(angle) * 0.4)
		points.append(0.56 + sin(angle) * 0.42 * (0.9 + 0.1 * (i % 2)))
	_poly(c, r, points, col)
	for i in 5:
		var angle := PI + PI * (i + 1) / 6.0
		_line(c, r, [0.5, 0.82, 0.5 + cos(angle) * 0.34, 0.56 + sin(angle) * 0.36], 0.02, acc)
	_rect(c, r, 0.42, 0.82, 0.16, 0.08, col.darkened(0.15))


static func _motif_compass(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ring(c, r, 0.5, 0.5, 0.38, 0.05, col)
	_poly(c, r, [0.5, 0.18, 0.58, 0.5, 0.42, 0.5], acc)
	_poly(c, r, [0.5, 0.82, 0.58, 0.5, 0.42, 0.5], col)
	_circle(c, r, 0.5, 0.5, 0.04, col)
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		_circle(c, r, 0.5 + cos(angle) * 0.3, 0.5 + sin(angle) * 0.3, 0.025, col)


static func _motif_bicycle(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ring(c, r, 0.26, 0.64, 0.17, 0.035, col)
	_ring(c, r, 0.74, 0.64, 0.17, 0.035, col)
	_line(c, r, [0.26, 0.64, 0.44, 0.42, 0.66, 0.42, 0.74, 0.64], 0.035, acc)
	_line(c, r, [0.44, 0.42, 0.5, 0.64, 0.66, 0.42], 0.035, acc)
	_line(c, r, [0.26, 0.64, 0.5, 0.64], 0.035, acc)
	_line(c, r, [0.44, 0.42, 0.4, 0.32], 0.03, col)
	_rect(c, r, 0.34, 0.29, 0.12, 0.04, col)
	_line(c, r, [0.66, 0.42, 0.64, 0.28, 0.72, 0.26], 0.03, col)


static func _motif_train(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.14, 0.42, 0.5, 0.28, col)
	_rect(c, r, 0.56, 0.26, 0.28, 0.44, col)
	_rect(c, r, 0.62, 0.32, 0.16, 0.14, acc)
	_rect(c, r, 0.22, 0.26, 0.1, 0.16, col)
	_circle(c, r, 0.27, 0.18, 0.07, Color(acc, 0.7))
	_circle(c, r, 0.38, 0.1, 0.05, Color(acc, 0.5))
	for x in [0.26, 0.46, 0.7]:
		_circle(c, r, x, 0.74, 0.08, acc)
		_circle(c, r, x, 0.74, 0.03, col)


static func _motif_balloon(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.36, 0.3, 0.32, col)
	_ellipse(c, r, 0.5, 0.36, 0.1, 0.32, acc)
	_poly(c, r, [0.26, 0.56, 0.74, 0.56, 0.58, 0.7, 0.42, 0.7], col)
	_line(c, r, [0.43, 0.7, 0.44, 0.8], 0.015, col)
	_line(c, r, [0.57, 0.7, 0.56, 0.8], 0.015, col)
	_rect(c, r, 0.42, 0.8, 0.16, 0.1, acc)


static func _motif_kite(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.5, 0.08, 0.76, 0.36, 0.5, 0.66, 0.24, 0.36], col)
	_poly(c, r, [0.5, 0.08, 0.76, 0.36, 0.5, 0.36], acc)
	_poly(c, r, [0.5, 0.36, 0.24, 0.36, 0.5, 0.66], acc)
	_line(c, r, [0.5, 0.66, 0.44, 0.76, 0.54, 0.84, 0.46, 0.94], 0.02, col)
	_poly(c, r, [0.44, 0.76, 0.38, 0.72, 0.38, 0.8], acc)
	_poly(c, r, [0.54, 0.84, 0.6, 0.8, 0.6, 0.88], acc)


static func _motif_umbrella(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_half_ellipse(c, r, 0.5, 0.46, 0.4, 0.32, col, true)
	for x in [0.23, 0.5, 0.77]:
		_half_ellipse(c, r, x, 0.46, 0.135, 0.05, acc, false)
	_line(c, r, [0.5, 0.46, 0.5, 0.82], 0.035, acc.darkened(0.2))
	_arc(c, r, 0.42, 0.82, 0.08, 0, 180, 0.035, acc.darkened(0.2))


static func _motif_rocket(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.5, 0.06, 0.64, 0.28, 0.64, 0.7, 0.36, 0.7, 0.36, 0.28], col)
	_circle(c, r, 0.5, 0.36, 0.08, acc)
	_poly(c, r, [0.36, 0.5, 0.22, 0.72, 0.36, 0.7], acc)
	_poly(c, r, [0.64, 0.5, 0.78, 0.72, 0.64, 0.7], acc)
	_poly(c, r, [0.42, 0.72, 0.58, 0.72, 0.5, 0.94], Color(1.0, 0.72, 0.3))


static func _motif_planet(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_arc(c, r, 0.5, 0.5, 0.42, 180, 360, 0.04, acc)  # Ring hinten (wird teils verdeckt)
	_circle(c, r, 0.5, 0.5, 0.26, col)
	_ellipse(c, r, 0.42, 0.44, 0.08, 0.04, col.lightened(0.2), -20)
	var ring := PackedVector2Array()
	for i in 21:
		var angle := PI * i / 20.0
		ring.append(_p(r, 0.5 + cos(angle) * 0.44, 0.52 + sin(angle) * 0.1))
	c.draw_polyline(ring, acc, 0.045 * r.size.x, true)
	_star(c, r, 0.84, 0.18, 0.05, 0.02, acc)


static func _motif_telescope(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_line(c, r, [0.5, 0.56, 0.3, 0.92], 0.03, acc)
	_line(c, r, [0.5, 0.56, 0.7, 0.92], 0.03, acc)
	_line(c, r, [0.5, 0.56, 0.5, 0.92], 0.03, acc)
	var basis := Transform2D(deg_to_rad(-30.0), _p(r, 0.48, 0.5))
	c.draw_set_transform_matrix(basis)
	c.draw_rect(Rect2(Vector2(-0.34, -0.07) * r.size.x, Vector2(0.62, 0.14) * r.size.x), col)
	c.draw_rect(Rect2(Vector2(0.28, -0.09) * r.size.x, Vector2(0.08, 0.18) * r.size.x), acc)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_star(c, r, 0.84, 0.14, 0.06, 0.025, acc)


static func _motif_whale(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.46, 0.6, 0.32, 0.2, col)
	_poly(c, r, [0.74, 0.58, 0.92, 0.4, 0.88, 0.58, 0.94, 0.74], col)
	_half_ellipse(c, r, 0.42, 0.64, 0.24, 0.12, col.lightened(0.25), false)
	_circle(c, r, 0.28, 0.54, 0.025, acc)
	_line(c, r, [0.4, 0.38, 0.4, 0.24], 0.025, acc)
	_line(c, r, [0.4, 0.28, 0.32, 0.18], 0.025, acc)
	_line(c, r, [0.4, 0.28, 0.48, 0.18], 0.025, acc)


static func _motif_fish(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.44, 0.5, 0.28, 0.17, col)
	_poly(c, r, [0.66, 0.5, 0.9, 0.32, 0.9, 0.68], col)
	_circle(c, r, 0.3, 0.46, 0.035, acc)
	_arc(c, r, 0.5, 0.5, 0.12, -60, 60, 0.025, acc)


# --- Tiere ---

static func _motif_cat(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.7, 0.24, 0.2, col)
	_arc(c, r, 0.74, 0.62, 0.14, -90, 90, 0.05, col)
	_circle(c, r, 0.5, 0.38, 0.17, col)
	_poly(c, r, [0.35, 0.3, 0.36, 0.14, 0.46, 0.24], col)
	_poly(c, r, [0.65, 0.3, 0.64, 0.14, 0.54, 0.24], col)
	_circle(c, r, 0.44, 0.37, 0.025, acc)
	_circle(c, r, 0.56, 0.37, 0.025, acc)
	_poly(c, r, [0.47, 0.43, 0.53, 0.43, 0.5, 0.46], acc)


static func _motif_dog(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.5, 0.48, 0.22, col)
	_ellipse(c, r, 0.29, 0.5, 0.08, 0.17, acc, 15)
	_ellipse(c, r, 0.71, 0.5, 0.08, 0.17, acc, -15)
	_ellipse(c, r, 0.5, 0.6, 0.11, 0.08, col.lightened(0.25))
	_circle(c, r, 0.5, 0.56, 0.035, acc)
	_circle(c, r, 0.42, 0.44, 0.025, acc)
	_circle(c, r, 0.58, 0.44, 0.025, acc)
	_line(c, r, [0.5, 0.6, 0.5, 0.66], 0.015, acc)


static func _motif_fox(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.2, 0.18, 0.4, 0.34, 0.6, 0.34, 0.8, 0.18, 0.76, 0.5, 0.5, 0.82, 0.24, 0.5], col)
	_poly(c, r, [0.26, 0.52, 0.5, 0.82, 0.38, 0.56], acc)
	_poly(c, r, [0.74, 0.52, 0.5, 0.82, 0.62, 0.56], acc)
	_poly(c, r, [0.25, 0.24, 0.36, 0.33, 0.28, 0.36], acc)
	_poly(c, r, [0.75, 0.24, 0.64, 0.33, 0.72, 0.36], acc)
	_circle(c, r, 0.4, 0.5, 0.025, col.darkened(0.6))
	_circle(c, r, 0.6, 0.5, 0.025, col.darkened(0.6))
	_circle(c, r, 0.5, 0.8, 0.03, col.darkened(0.6))


static func _motif_owl(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.56, 0.27, 0.32, col)
	_poly(c, r, [0.26, 0.34, 0.3, 0.16, 0.4, 0.3], col)
	_poly(c, r, [0.74, 0.34, 0.7, 0.16, 0.6, 0.3], col)
	_circle(c, r, 0.4, 0.44, 0.1, acc)
	_circle(c, r, 0.6, 0.44, 0.1, acc)
	_circle(c, r, 0.41, 0.45, 0.04, col.darkened(0.5))
	_circle(c, r, 0.59, 0.45, 0.04, col.darkened(0.5))
	_poly(c, r, [0.46, 0.54, 0.54, 0.54, 0.5, 0.62], acc.darkened(0.2))
	_ellipse(c, r, 0.5, 0.74, 0.14, 0.1, col.lightened(0.2))


static func _motif_bird(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.48, 0.56, 0.24, 0.18, col)
	_circle(c, r, 0.68, 0.4, 0.13, col)
	_poly(c, r, [0.78, 0.38, 0.9, 0.42, 0.78, 0.45], acc)
	_poly(c, r, [0.26, 0.5, 0.08, 0.38, 0.14, 0.58], col)
	_ellipse(c, r, 0.44, 0.52, 0.14, 0.08, acc, -15)
	_circle(c, r, 0.7, 0.37, 0.022, col.darkened(0.6))
	_line(c, r, [0.46, 0.72, 0.44, 0.84], 0.02, acc)
	_line(c, r, [0.54, 0.72, 0.56, 0.84], 0.02, acc)


static func _motif_rabbit(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.4, 0.22, 0.06, 0.18, col, -10)
	_ellipse(c, r, 0.6, 0.22, 0.06, 0.18, col, 10)
	_ellipse(c, r, 0.4, 0.22, 0.025, 0.12, acc, -10)
	_ellipse(c, r, 0.6, 0.22, 0.025, 0.12, acc, 10)
	_ellipse(c, r, 0.5, 0.74, 0.22, 0.18, col)
	_circle(c, r, 0.5, 0.46, 0.16, col)
	_circle(c, r, 0.44, 0.44, 0.02, col.darkened(0.6))
	_circle(c, r, 0.56, 0.44, 0.02, col.darkened(0.6))
	_circle(c, r, 0.5, 0.5, 0.025, acc)


static func _motif_hedgehog(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	var spikes := [0.16, 0.74]
	for i in 11:
		var angle := PI + PI * i / 10.0
		var radius := 0.38 if i % 2 == 0 else 0.3
		spikes.append(0.5 + cos(angle) * radius)
		spikes.append(0.74 + sin(angle) * radius * 0.95)
	spikes.append_array([0.84, 0.74])
	_poly(c, r, spikes, col)
	_poly(c, r, [0.66, 0.74, 0.74, 0.56, 0.92, 0.72, 0.84, 0.78], acc)
	_circle(c, r, 0.92, 0.72, 0.025, col.darkened(0.6))
	_circle(c, r, 0.76, 0.64, 0.02, col.darkened(0.6))


static func _motif_bee(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.4, 0.3, 0.14, 0.1, Color(1, 1, 1, 0.75), -30)
	_ellipse(c, r, 0.6, 0.3, 0.14, 0.1, Color(1, 1, 1, 0.75), 30)
	_ellipse(c, r, 0.5, 0.56, 0.22, 0.17, acc)
	_rect(c, r, 0.4, 0.4, 0.06, 0.32, col)
	_rect(c, r, 0.54, 0.4, 0.06, 0.32, col)
	_circle(c, r, 0.27, 0.54, 0.08, col)
	_poly(c, r, [0.72, 0.52, 0.82, 0.56, 0.72, 0.6], col)


static func _motif_butterfly(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.32, 0.36, 0.17, 0.15, col, -20)
	_ellipse(c, r, 0.68, 0.36, 0.17, 0.15, col, 20)
	_ellipse(c, r, 0.36, 0.64, 0.12, 0.11, acc, 20)
	_ellipse(c, r, 0.64, 0.64, 0.12, 0.11, acc, -20)
	_circle(c, r, 0.32, 0.36, 0.05, acc)
	_circle(c, r, 0.68, 0.36, 0.05, acc)
	_ellipse(c, r, 0.5, 0.5, 0.03, 0.22, col.darkened(0.4))
	_line(c, r, [0.5, 0.3, 0.42, 0.16], 0.015, col.darkened(0.4))
	_line(c, r, [0.5, 0.3, 0.58, 0.16], 0.015, col.darkened(0.4))


static func _motif_snail(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.1, 0.8, 0.86, 0.8, 0.86, 0.72, 0.3, 0.7, 0.24, 0.5, 0.16, 0.5, 0.14, 0.7], acc)
	_line(c, r, [0.18, 0.52, 0.12, 0.34], 0.02, acc)
	_line(c, r, [0.22, 0.52, 0.26, 0.34], 0.02, acc)
	_circle(c, r, 0.56, 0.52, 0.26, col)
	_ring(c, r, 0.56, 0.52, 0.17, 0.03, acc)
	_ring(c, r, 0.58, 0.5, 0.08, 0.03, acc)


static func _motif_dragon(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.62, 0.66, 0.9, 0.86, 0.66, 0.78], col)
	_ellipse(c, r, 0.5, 0.64, 0.2, 0.17, col)
	_poly(c, r, [0.5, 0.52, 0.8, 0.26, 0.74, 0.5], acc)
	_circle(c, r, 0.32, 0.38, 0.15, col)
	_poly(c, r, [0.24, 0.26, 0.2, 0.12, 0.3, 0.24], acc)
	_poly(c, r, [0.36, 0.24, 0.38, 0.1, 0.44, 0.26], acc)
	_circle(c, r, 0.28, 0.36, 0.03, Color(1, 1, 1))
	_circle(c, r, 0.27, 0.36, 0.015, col.darkened(0.6))
	_ellipse(c, r, 0.5, 0.7, 0.1, 0.08, col.lightened(0.25))
	_circle(c, r, 0.19, 0.44, 0.012, col.darkened(0.5))


# --- Dinge ---

static func _motif_teacup(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.48, 0.84, 0.36, 0.06, acc)
	_arc(c, r, 0.76, 0.6, 0.09, -90, 90, 0.04, col)
	_half_ellipse(c, r, 0.48, 0.48, 0.28, 0.32, col, false)
	_rect(c, r, 0.2, 0.46, 0.56, 0.04, col.lightened(0.2))
	_line(c, r, [0.38, 0.36, 0.34, 0.26, 0.4, 0.16], 0.025, acc)
	_line(c, r, [0.54, 0.36, 0.5, 0.24, 0.56, 0.14], 0.025, acc)


static func _motif_teapot(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.7, 0.62, 0.92, 0.36, 0.86, 0.34, 0.68, 0.5], col)
	_arc(c, r, 0.22, 0.58, 0.13, 90, 270, 0.045, col)
	_ellipse(c, r, 0.48, 0.6, 0.26, 0.22, col)
	_ellipse(c, r, 0.48, 0.4, 0.14, 0.05, acc)
	_circle(c, r, 0.48, 0.33, 0.04, acc)
	_rect(c, r, 0.3, 0.6, 0.36, 0.04, acc)


static func _motif_bowl(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_half_ellipse(c, r, 0.5, 0.52, 0.38, 0.3, col, false)
	_ellipse(c, r, 0.5, 0.52, 0.38, 0.06, acc)
	_rect(c, r, 0.38, 0.8, 0.24, 0.06, col)
	_line(c, r, [0.38, 0.4, 0.34, 0.3, 0.4, 0.2], 0.025, acc)
	_line(c, r, [0.52, 0.4, 0.48, 0.28, 0.54, 0.16], 0.025, acc)
	_line(c, r, [0.66, 0.4, 0.62, 0.3, 0.68, 0.2], 0.025, acc)


static func _motif_cake(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.2, 0.5, 0.6, 0.36, col)
	_rect(c, r, 0.2, 0.64, 0.6, 0.05, acc)
	var drip := [0.18, 0.5]
	for i in 7:
		drip.append(0.18 + i * 0.107)
		drip.append(0.58 if i % 2 == 0 else 0.53)
	drip.append_array([0.82, 0.5, 0.82, 0.44, 0.18, 0.44])
	_poly(c, r, drip, acc)
	_circle(c, r, 0.5, 0.36, 0.07, Color(0.85, 0.2, 0.25))
	_line(c, r, [0.5, 0.3, 0.55, 0.2], 0.02, Color(0.3, 0.5, 0.25))


static func _motif_bread(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_half_ellipse(c, r, 0.5, 0.62, 0.38, 0.32, col, true)
	_rect(c, r, 0.12, 0.62, 0.76, 0.16, col)
	_line(c, r, [0.3, 0.52, 0.38, 0.38], 0.03, acc)
	_line(c, r, [0.46, 0.52, 0.54, 0.36], 0.03, acc)
	_line(c, r, [0.62, 0.52, 0.7, 0.4], 0.03, acc)


static func _motif_apple(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.38, 0.58, 0.24, col)
	_circle(c, r, 0.62, 0.58, 0.24, col)
	_circle(c, r, 0.5, 0.7, 0.2, col)
	_line(c, r, [0.5, 0.38, 0.52, 0.2], 0.035, col.darkened(0.5))
	_ellipse(c, r, 0.62, 0.24, 0.1, 0.05, acc, -25)
	_circle(c, r, 0.36, 0.5, 0.05, col.lightened(0.3))


static func _motif_lemon(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.56, 0.32, 0.24, col, -15)
	_poly(c, r, [0.16, 0.62, 0.22, 0.58, 0.2, 0.68], col)
	_poly(c, r, [0.84, 0.5, 0.78, 0.46, 0.8, 0.56], col)
	_ellipse(c, r, 0.58, 0.28, 0.1, 0.05, acc, -30)
	_ellipse(c, r, 0.42, 0.5, 0.08, 0.04, col.lightened(0.35), -15)


static func _motif_key(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ring(c, r, 0.28, 0.5, 0.13, 0.06, col)
	_rect(c, r, 0.4, 0.47, 0.48, 0.06, col)
	_rect(c, r, 0.72, 0.53, 0.06, 0.12, col)
	_rect(c, r, 0.82, 0.53, 0.06, 0.08, col)
	_circle(c, r, 0.28, 0.5, 0.04, acc)


static func _motif_lantern(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_arc(c, r, 0.5, 0.18, 0.08, 180, 360, 0.03, col)
	_poly(c, r, [0.34, 0.3, 0.66, 0.3, 0.58, 0.2, 0.42, 0.2], col)
	_circle(c, r, 0.5, 0.52, 0.2, Color(acc, 0.35))
	_rect(c, r, 0.36, 0.3, 0.28, 0.44, acc)
	_line(c, r, [0.36, 0.3, 0.36, 0.74], 0.03, col)
	_line(c, r, [0.64, 0.3, 0.64, 0.74], 0.03, col)
	_ellipse(c, r, 0.5, 0.52, 0.04, 0.08, Color(1.0, 0.95, 0.7))
	_rect(c, r, 0.32, 0.74, 0.36, 0.06, col)


static func _motif_candle(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.5, 0.28, 0.16, Color(acc, 0.3))
	_rect(c, r, 0.38, 0.4, 0.24, 0.46, col)
	_ellipse(c, r, 0.5, 0.4, 0.12, 0.03, col.lightened(0.2))
	_line(c, r, [0.5, 0.4, 0.5, 0.34], 0.015, col.darkened(0.5))
	_poly(c, r, [0.5, 0.14, 0.56, 0.28, 0.5, 0.34, 0.44, 0.28], acc)
	_rect(c, r, 0.3, 0.86, 0.4, 0.04, acc.darkened(0.2))


static func _motif_book(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.1, 0.28, 0.5, 0.36, 0.9, 0.28, 0.9, 0.78, 0.5, 0.86, 0.1, 0.78], col)
	_poly(c, r, [0.14, 0.24, 0.48, 0.32, 0.48, 0.8, 0.14, 0.72], acc)
	_poly(c, r, [0.86, 0.24, 0.52, 0.32, 0.52, 0.8, 0.86, 0.72], acc.lightened(0.1))
	for i in 3:
		_line(c, r, [0.2, 0.38 + i * 0.1, 0.42, 0.44 + i * 0.1], 0.015, col)
		_line(c, r, [0.58, 0.44 + i * 0.1, 0.8, 0.38 + i * 0.1], 0.015, col)


static func _motif_letter(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.12, 0.28, 0.76, 0.48, col)
	_line(c, r, [0.12, 0.28, 0.5, 0.56, 0.88, 0.28], 0.03, acc)
	_line(c, r, [0.12, 0.76, 0.4, 0.5], 0.02, acc)
	_line(c, r, [0.88, 0.76, 0.6, 0.5], 0.02, acc)
	_circle(c, r, 0.46, 0.56, 0.05, Color(0.8, 0.25, 0.25))
	_circle(c, r, 0.54, 0.56, 0.05, Color(0.8, 0.25, 0.25))
	_poly(c, r, [0.41, 0.58, 0.59, 0.58, 0.5, 0.68], Color(0.8, 0.25, 0.25))


static func _motif_feather(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.54, 0.42, 0.12, 0.34, col, 30)
	_line(c, r, [0.28, 0.9, 0.42, 0.66, 0.68, 0.16], 0.025, acc)
	for i in 4:
		var t := 0.3 + i * 0.12
		var base := Vector2(0.42, 0.66).lerp(Vector2(0.68, 0.16), t)
		_line(c, r, [base.x, base.y, base.x - 0.1, base.y - 0.02], 0.015, acc)


static func _motif_scroll(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_rect(c, r, 0.2, 0.24, 0.6, 0.52, col)
	_ellipse(c, r, 0.5, 0.24, 0.34, 0.06, acc)
	_ellipse(c, r, 0.5, 0.76, 0.34, 0.06, acc)
	for i in 4:
		_line(c, r, [0.3, 0.38 + i * 0.09, 0.7, 0.38 + i * 0.09], 0.015, acc)


static func _motif_crown(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.14, 0.7, 0.14, 0.32, 0.32, 0.5, 0.5, 0.24, 0.68, 0.5, 0.86, 0.32, 0.86, 0.7], col)
	_rect(c, r, 0.14, 0.7, 0.72, 0.1, col.darkened(0.15))
	for x in [0.14, 0.5, 0.86]:
		_circle(c, r, x, 0.3 if x != 0.5 else 0.22, 0.045, acc)
	_circle(c, r, 0.5, 0.6, 0.05, acc)
	_circle(c, r, 0.3, 0.62, 0.035, acc)
	_circle(c, r, 0.7, 0.62, 0.035, acc)


static func _motif_heart(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.36, 0.4, 0.17, col)
	_circle(c, r, 0.64, 0.4, 0.17, col)
	_poly(c, r, [0.2, 0.47, 0.8, 0.47, 0.5, 0.84], col)
	_circle(c, r, 0.32, 0.36, 0.05, acc)


static func _motif_magnifier(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.42, 0.42, 0.24, Color(acc, 0.35))
	_ring(c, r, 0.42, 0.42, 0.24, 0.06, col)
	_line(c, r, [0.6, 0.6, 0.84, 0.84], 0.09, col)
	_arc(c, r, 0.42, 0.42, 0.15, 200, 260, 0.03, Color(1, 1, 1, 0.8))


static func _motif_music(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.3, 0.74, 0.1, 0.07, col, -20)
	_ellipse(c, r, 0.7, 0.66, 0.1, 0.07, col, -20)
	_line(c, r, [0.38, 0.72, 0.38, 0.24], 0.035, col)
	_line(c, r, [0.78, 0.64, 0.78, 0.16], 0.035, col)
	_poly(c, r, [0.36, 0.22, 0.8, 0.13, 0.8, 0.23, 0.36, 0.32], acc)


static func _motif_palette(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_ellipse(c, r, 0.5, 0.52, 0.38, 0.3, col, -10)
	_circle(c, r, 0.62, 0.66, 0.06, col.darkened(0.35))
	var paints := [Color(0.85, 0.3, 0.3), Color(0.95, 0.78, 0.3), Color(0.35, 0.6, 0.85), Color(0.4, 0.7, 0.4), acc]
	for i in paints.size():
		var angle := PI * 1.05 + i * 0.42
		_circle(c, r, 0.5 + cos(angle) * 0.24, 0.52 + sin(angle) * 0.18, 0.055, paints[i])


static func _motif_brush(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	var basis := Transform2D(deg_to_rad(40.0), _p(r, 0.5, 0.5))
	c.draw_set_transform_matrix(basis)
	var unit := r.size.x
	c.draw_rect(Rect2(Vector2(-0.05, -0.42) * unit, Vector2(0.1, 0.46) * unit), col)
	c.draw_rect(Rect2(Vector2(-0.06, 0.04) * unit, Vector2(0.12, 0.1) * unit), acc)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-0.06, 0.14) * unit, Vector2(0.06, 0.14) * unit,
		Vector2(0.0, 0.36) * unit]), col.darkened(0.4))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _motif_clock(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.5, 0.5, 0.38, col)
	_circle(c, r, 0.5, 0.5, 0.31, acc)
	for i in 12:
		var angle := TAU * i / 12.0
		_circle(c, r, 0.5 + cos(angle) * 0.26, 0.5 + sin(angle) * 0.26, 0.015, col)
	_line(c, r, [0.5, 0.5, 0.5, 0.3], 0.035, col)
	_line(c, r, [0.5, 0.5, 0.64, 0.56], 0.03, col)
	_circle(c, r, 0.5, 0.5, 0.03, col)


static func _motif_hourglass(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_poly(c, r, [0.3, 0.18, 0.7, 0.18, 0.52, 0.5, 0.7, 0.82, 0.3, 0.82, 0.48, 0.5], Color(acc, 0.45))
	_poly(c, r, [0.38, 0.3, 0.62, 0.3, 0.5, 0.48], acc)
	_poly(c, r, [0.5, 0.6, 0.66, 0.8, 0.34, 0.8], acc)
	_rect(c, r, 0.24, 0.12, 0.52, 0.07, col)
	_rect(c, r, 0.24, 0.81, 0.52, 0.07, col)
	_line(c, r, [0.28, 0.19, 0.28, 0.81], 0.025, col)
	_line(c, r, [0.72, 0.19, 0.72, 0.81], 0.025, col)


static func _motif_glasses(c: CanvasItem, r: Rect2, col: Color, acc: Color) -> void:
	_circle(c, r, 0.3, 0.54, 0.15, Color(acc, 0.35))
	_circle(c, r, 0.7, 0.54, 0.15, Color(acc, 0.35))
	_ring(c, r, 0.3, 0.54, 0.15, 0.045, col)
	_ring(c, r, 0.7, 0.54, 0.15, 0.045, col)
	_arc(c, r, 0.5, 0.56, 0.06, 200, 340, 0.035, col)
	_line(c, r, [0.15, 0.5, 0.06, 0.42], 0.03, col)
	_line(c, r, [0.85, 0.5, 0.94, 0.42], 0.03, col)
