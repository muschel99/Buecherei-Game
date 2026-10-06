class_name BookCover
extends Control
## Zeichnet das Cover oder den Buchrücken eines Buchtitels (BookData) – aus Farbe, Schrift
## und einem kleinen Motiv (BookMotifs). Wird überall benutzt, wo man ein Buch sieht:
## im Shop und in der Sammlung (direkt als Oberfläche), im Regal (über den Buchrücken-Atlas,
## siehe BookArt) und in der Hand (als Bild, siehe BookArt.request_cover).
##
## Gestaltungen (BookData.style):
##   classic  Einband mit feinem Doppelrahmen, Titel oben, Motiv in der Mitte
##   picture  großes Bild vor zweifarbigem Hintergrund, Titel oben
##   minimal  helles Papier, farbiger Streifen, großer Titel links
##   pattern  Muster mit hellem Titelschild in der Mitte
##   band     Bild oben, helles Titelfeld unten
##   comic    kräftige Farben, Strahlenkranz, Titel mit Umriss

## Welche Seite gezeichnet wird
const COVER := 0
const SPINE := 1

## Welcher Titel?
var data: BookData:
	set(value):
		data = value
		queue_redraw()
## Cover oder Buchrücken?
var side: int = COVER:
	set(value):
		side = value
		queue_redraw()
## Nur für den Buchrücken: in welchem Teil des Feldes er liegt (leer = ganzes Feld).
## Der Rest wird in der Einbandfarbe gefüllt (wichtig für den Atlas).
var content_rect: Rect2 = Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if data == null:
		return
	if side == SPINE:
		draw_rect(Rect2(Vector2.ZERO, size), data.cover_color)
		var area := content_rect if content_rect.has_area() else Rect2(Vector2.ZERO, size)
		draw_spine(self, data, area)
	else:
		draw_cover(self, data, Rect2(Vector2.ZERO, size))


# --- Cover ---

## Zeichnet ein Cover in das Rechteck r (auf einem beliebigen CanvasItem).
static func draw_cover(ci: CanvasItem, book: BookData, r: Rect2) -> void:
	var w := r.size.x
	var col := book.cover_color
	var acc := book.accent_color
	var paper := book.paper_color
	var font := BookArt.get_title_font(book)
	match book.style:
		"classic":
			ci.draw_rect(r, col)
			_frame(ci, r.grow(-w * 0.06), acc, w * 0.012)
			_frame(ci, r.grow(-w * 0.085), Color(acc, 0.6), w * 0.005)
			_title(ci, book, Rect2(r.position + Vector2(w * 0.14, r.size.y * 0.12), Vector2(w * 0.72, r.size.y * 0.32)),
				font, acc, w * 0.105, HORIZONTAL_ALIGNMENT_CENTER)
			_ornament(ci, r.position + Vector2(w * 0.5, r.size.y * 0.47), w * 0.22, acc)
			BookMotifs.draw(ci, book.motif, _box(r, 0.5, 0.66, 0.3), acc, col.lightened(0.25))
			_author(ci, book, r, 0.86, acc, HORIZONTAL_ALIGNMENT_CENTER)
		"picture":
			var sky := col.lightened(0.12)
			ci.draw_rect(r, sky)
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.74), Vector2(w, r.size.y * 0.26)), col.darkened(0.18))
			ci.draw_circle(r.position + Vector2(w * 0.5, r.size.y * 0.55), w * 0.36, sky.lightened(0.12))
			var motif_color := paper if col.get_luminance() < 0.55 else col.darkened(0.55)
			BookMotifs.draw(ci, book.motif, _box(r, 0.5, 0.56, 0.58), motif_color, acc)
			_title(ci, book, Rect2(r.position + Vector2(w * 0.08, r.size.y * 0.05), Vector2(w * 0.84, r.size.y * 0.28)),
				font, book.text_color, w * 0.11, HORIZONTAL_ALIGNMENT_CENTER, true)
			_author(ci, book, r, 0.9, book.text_color, HORIZONTAL_ALIGNMENT_CENTER)
		"minimal":
			ci.draw_rect(r, paper)
			var ink := col if col.get_luminance() < 0.55 else col.darkened(0.45)
			ci.draw_rect(Rect2(r.position + Vector2(w * 0.1, r.size.y * 0.08), Vector2(w * 0.8, r.size.y * 0.025)), col)
			_title(ci, book, Rect2(r.position + Vector2(w * 0.1, r.size.y * 0.15), Vector2(w * 0.8, r.size.y * 0.42)),
				font, ink, w * 0.12, HORIZONTAL_ALIGNMENT_LEFT)
			BookMotifs.draw(ci, book.motif, _box(r, 0.68, 0.7, 0.34), col, acc)
			_author(ci, book, r, 0.9, ink, HORIZONTAL_ALIGNMENT_LEFT)
		"pattern":
			ci.draw_rect(r, col)
			_pattern(ci, r, book.pattern, col.lightened(0.14))
			var label := Rect2(r.position + Vector2(w * 0.12, r.size.y * 0.28), Vector2(w * 0.76, r.size.y * 0.46))
			_rounded(ci, label, paper, w * 0.04)
			var ink := col if col.get_luminance() < 0.5 else col.darkened(0.5)
			BookMotifs.draw(ci, book.motif, _box(r, 0.5, 0.37, 0.16), col, acc)
			_title(ci, book, Rect2(label.position + Vector2(w * 0.06, label.size.y * 0.32), Vector2(label.size.x - w * 0.12, label.size.y * 0.46)),
				font, ink, w * 0.095, HORIZONTAL_ALIGNMENT_CENTER)
			_author(ci, book, Rect2(label.position, Vector2(label.size.x, label.size.y)), 0.88, Color(ink, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		"band":
			ci.draw_rect(r, col)
			var split := r.size.y * 0.6
			BookMotifs.draw(ci, book.motif, _box(r, 0.5, 0.31, 0.46), paper if col.get_luminance() < 0.55 else col.darkened(0.55), acc)
			ci.draw_rect(Rect2(r.position + Vector2(0, split), Vector2(w, r.size.y - split)), paper)
			ci.draw_rect(Rect2(r.position + Vector2(0, split - w * 0.015), Vector2(w, w * 0.03)), acc)
			var ink := col if col.get_luminance() < 0.5 else col.darkened(0.5)
			_title(ci, book, Rect2(r.position + Vector2(w * 0.08, split + r.size.y * 0.04), Vector2(w * 0.84, r.size.y * 0.24)),
				font, ink, w * 0.1, HORIZONTAL_ALIGNMENT_CENTER)
			_author(ci, book, r, 0.92, Color(ink, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		"comic":
			ci.draw_rect(r, col)
			_halftone(ci, r, col.lightened(0.18))
			_burst(ci, r.position + Vector2(w * 0.5, r.size.y * 0.6), w * 0.42, acc)
			BookMotifs.draw(ci, book.motif, _box(r, 0.5, 0.6, 0.48), paper, col.darkened(0.3))
			_title(ci, book, Rect2(r.position + Vector2(w * 0.06, r.size.y * 0.05), Vector2(w * 0.88, r.size.y * 0.3)),
				font, paper, w * 0.12, HORIZONTAL_ALIGNMENT_CENTER, false, Color(0.12, 0.1, 0.12))
			_author(ci, book, r, 0.93, paper, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			ci.draw_rect(r, col)
			_title(ci, book, r.grow(-w * 0.1), font, book.text_color, w * 0.1, HORIZONTAL_ALIGNMENT_CENTER)


# --- Buchrücken ---

## Zeichnet einen Buchrücken in das (schmale, hohe) Rechteck r. Der Titel läuft von oben
## nach unten.
static func draw_spine(ci: CanvasItem, book: BookData, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var col := book.cover_color
	var acc := book.accent_color
	var paper := book.paper_color
	var text_color := book.text_color
	var text_from := 0.08
	var text_to := 0.8
	match book.style:
		"classic":
			ci.draw_rect(r, col)
			for y in [0.05, 0.075, 0.915, 0.94]:
				ci.draw_rect(Rect2(r.position + Vector2(0, h * y), Vector2(w, maxf(h * 0.008, 1.0))), acc)
			text_color = acc
			text_from = 0.11
			text_to = 0.89
		"picture":
			ci.draw_rect(r, col)
			BookMotifs.draw(ci, book.motif, Rect2(r.position + Vector2(w * 0.1, h * 0.85), Vector2(w * 0.8, w * 0.8)),
				paper if col.get_luminance() < 0.55 else col.darkened(0.55), acc)
		"minimal":
			ci.draw_rect(r, paper)
			ci.draw_rect(Rect2(r.position, Vector2(w, h * 0.06)), col)
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.94), Vector2(w, h * 0.06)), col)
			text_color = col if col.get_luminance() < 0.55 else col.darkened(0.45)
			text_from = 0.1
			text_to = 0.9
		"pattern":
			ci.draw_rect(r, col)
			_pattern(ci, r, book.pattern, col.lightened(0.14))
			var label := Rect2(r.position + Vector2(w * 0.12, h * 0.1), Vector2(w * 0.76, h * 0.72))
			ci.draw_rect(label, paper)
			text_color = col if col.get_luminance() < 0.5 else col.darkened(0.5)
			text_from = 0.12
			text_to = 0.8
		"band":
			ci.draw_rect(r, col)
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.8), Vector2(w, h * 0.2)), paper)
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.8), Vector2(w, maxf(h * 0.01, 1.0))), acc)
			BookMotifs.draw(ci, book.motif, Rect2(r.position + Vector2(w * 0.12, h * 0.85), Vector2(w * 0.76, w * 0.76)), col, acc)
			text_to = 0.77
		"comic":
			ci.draw_rect(r, col)
			ci.draw_rect(Rect2(r.position, Vector2(w, h * 0.16)), acc)
			BookMotifs.draw(ci, book.motif, Rect2(r.position + Vector2(w * 0.1, h * 0.02), Vector2(w * 0.8, h * 0.12)), col.darkened(0.3), paper)
			text_color = paper
			text_from = 0.19
			text_to = 0.96
		_:
			ci.draw_rect(r, col)
	_spine_title(ci, book, Rect2(r.position + Vector2(0, h * text_from), Vector2(w, h * (text_to - text_from))),
		text_color, book.style == "comic")


## Titel um 90° gedreht (liest sich von oben nach unten), passend verkleinert.
static func _spine_title(ci: CanvasItem, book: BookData, r: Rect2, color: Color, outline: bool) -> void:
	var font := BookArt.get_title_font(book)
	var text := book.title
	var length := r.size.y
	var font_size := int(r.size.x * 0.52)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > length:
		font_size = maxi(int(font_size * length / width), 6)
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Immer noch zu lang? Dann mit "…" kürzen
	while width > length and text.length() > 4:
		text = text.substr(0, text.length() - 2).strip_edges() + "…"
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	# Gedreht: Die Schrift läuft nach unten, die Buchstaben zeigen nach rechts.
	# Grundlinie so legen, dass die Zeile mittig in der Breite sitzt.
	var baseline_x := r.position.x + r.size.x / 2.0 - (ascent - descent) / 2.0
	var start_y := r.position.y + (length - width) / 2.0
	ci.draw_set_transform(Vector2(baseline_x, start_y), PI / 2.0)
	if outline:
		ci.draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			maxi(int(font_size * 0.25), 2), Color(0.12, 0.1, 0.12))
	ci.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	ci.draw_set_transform(Vector2.ZERO)


# --- Schrift auf dem Cover ---

## Titel in mehreren Zeilen, so groß wie möglich (höchstens font_size), passend ins Feld.
static func _title(ci: CanvasItem, book: BookData, r: Rect2, font: Font, color: Color, font_size: float,
		alignment: HorizontalAlignment, shadow: bool = false, outline: Color = Color(0, 0, 0, 0)) -> void:
	var px := int(font_size)
	var lines: PackedStringArray
	while true:
		lines = _wrap(book.title, font, px, r.size.x)
		var height := lines.size() * font.get_height(px) * 1.05
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if (height <= r.size.y and widest <= r.size.x) or px <= 7:
			break
		px -= 1
	var line_height := font.get_height(px) * 1.05
	var y := r.position.y + (r.size.y - lines.size() * line_height) / 2.0 + font.get_ascent(px)
	for line in lines:
		var at := Vector2(r.position.x, y)
		if shadow:
			ci.draw_string(font, at + Vector2(1, 1) * maxf(px * 0.06, 1.0), line, alignment, r.size.x, px,
				Color(0, 0, 0, 0.35))
		if outline.a > 0.0:
			ci.draw_string_outline(font, at, line, alignment, r.size.x, px, maxi(int(px * 0.22), 2), outline)
		ci.draw_string(font, at, line, alignment, r.size.x, px, color)
		y += line_height


static func _author(ci: CanvasItem, book: BookData, r: Rect2, y_share: float, color: Color,
		alignment: HorizontalAlignment) -> void:
	var font := BookArt.get_author_font()
	var px := maxi(int(r.size.x * 0.06), 6)
	var margin := r.size.x * 0.1
	ci.draw_string(font, r.position + Vector2(margin, r.size.y * y_share), book.author, alignment,
		r.size.x - margin * 2.0, px, color)


## Teilt einen Text in Zeilen, die höchstens max_width breit sind.
static func _wrap(text: String, font: Font, px: int, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in text.split(" ", false):
		var attempt := word if current.is_empty() else current + " " + word
		if font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= max_width or current.is_empty():
			current = attempt
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines


# --- Schmuck ---

static func _box(r: Rect2, x: float, y: float, share: float) -> Rect2:
	var side := r.size.x * share
	return Rect2(r.position + Vector2(r.size.x * x, r.size.y * y) - Vector2(side, side) / 2.0, Vector2(side, side))


static func _frame(ci: CanvasItem, r: Rect2, color: Color, width: float) -> void:
	ci.draw_rect(r, color, false, maxf(width, 1.0))


static func _rounded(ci: CanvasItem, r: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.draw(ci.get_canvas_item(), r)


## Kleine Zierlinie mit Raute in der Mitte.
static func _ornament(ci: CanvasItem, center: Vector2, width: float, color: Color) -> void:
	var thickness := maxf(width * 0.02, 1.0)
	ci.draw_line(center - Vector2(width / 2.0, 0), center - Vector2(width * 0.1, 0), color, thickness, true)
	ci.draw_line(center + Vector2(width * 0.1, 0), center + Vector2(width / 2.0, 0), color, thickness, true)
	var d := width * 0.06
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -d), center + Vector2(d, 0),
		center + Vector2(0, d), center + Vector2(-d, 0)]), color)


## Muster: 0 = Punkte, 1 = Streifen, 2 = Karos, 3 = Wellen.
static func _pattern(ci: CanvasItem, r: Rect2, kind: int, color: Color) -> void:
	var step := maxf(r.size.x * 0.14, 5.0)
	match kind:
		0:
			var y := r.position.y + step * 0.5
			var row := 0
			while y < r.end.y:
				var x := r.position.x + step * (0.25 if row % 2 == 0 else 0.75)
				while x < r.end.x - step * 0.16:
					ci.draw_circle(Vector2(x, y), step * 0.16, color, true, -1.0, true)
					x += step
				y += step * 0.6
				row += 1
		1:
			var x := r.position.x - r.size.y
			while x < r.end.x:
				_clipped_line(ci, r, PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y)]),
					color, step * 0.25)
				x += step
		2:
			var y := r.position.y
			var row := 0
			while y < r.end.y:
				var x := r.position.x + (step if row % 2 == 1 else 0.0)
				while x < r.end.x:
					ci.draw_rect(Rect2(Vector2(x, y), Vector2(step, step)).intersection(r), color)
					x += step * 2.0
				y += step
				row += 1
		_:
			var y := r.position.y + step * 0.5
			while y < r.end.y:
				var points := PackedVector2Array()
				var x := r.position.x
				while x <= r.end.x + step:
					points.append(Vector2(x, y + sin((x - r.position.x) / step * PI) * step * 0.18))
					x += step * 0.25
				_clipped_line(ci, r, points, color, maxf(step * 0.12, 1.0))
				y += step * 0.7


## Linie, die nicht über das Rechteck hinausragt.
static func _clipped_line(ci: CanvasItem, r: Rect2, points: PackedVector2Array, color: Color, width: float) -> void:
	# Etwas kleiner schneiden, damit die Linienbreite nicht über den Rand steht
	var inner := r.grow(-width / 2.0)
	var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
		Vector2(inner.position.x, inner.end.y)])
	for piece in Geometry2D.intersect_polyline_with_polygon(points, box):
		ci.draw_polyline(piece, color, width, true)


## Rasterpunkte wie im Comic.
static func _halftone(ci: CanvasItem, r: Rect2, color: Color) -> void:
	var step := maxf(r.size.x * 0.07, 4.0)
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			ci.draw_circle(Vector2(x, y), step * 0.22, color)
			x += step
		y += step * 0.86
		row += 1


## Strahlenkranz hinter dem Comic-Motiv.
static func _burst(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		var distance := radius if i % 2 == 0 else radius * 0.72
		points.append(center + Vector2(cos(angle), sin(angle)) * distance)
	ci.draw_colored_polygon(points, color)
