class_name TabletAppIcon
extends Button
## Ein großes App-Symbol auf dem Startbildschirm des Theken-Tablets: eine farbige, runde Kachel
## mit gezeichnetem Symbol (oder eigenem Bild) und dem Namen darunter.
## compact = true: nur die kleine Kachel (z. B. als Logo oben in der Leiste), so groß wie der
## Knoten (custom_minimum_size), ohne Namen.

const TILE_SIZE := 108.0
const LINE_COLOR := Color(1.0, 0.96, 0.88)

var app: TabletAppData
## Nur die Kachel, ohne Namen (Logo in der Leiste).
var compact := false

var _hovered := false


func setup(data: TabletAppData) -> void:
	app = data
	tooltip_text = ""
	focus_mode = Control.FOCUS_NONE
	queue_redraw()
	if compact:
		flat = true
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(TILE_SIZE + 40.0, TILE_SIZE + 44.0)
	flat = true
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw())


func _draw() -> void:
	if app == null:
		return
	if compact:
		# Die große Kachel verkleinert zeichnen (gleiches Bild, nur kleiner)
		var factor := minf(size.x, size.y) / TILE_SIZE
		draw_set_transform(size / 2.0 - Vector2(TILE_SIZE, TILE_SIZE) * factor / 2.0, 0.0, Vector2(factor, factor))
		_draw_tile(Rect2(Vector2.ZERO, Vector2(TILE_SIZE, TILE_SIZE)), 0)
		draw_set_transform(Vector2.ZERO)
		return
	var tile := Rect2(Vector2((size.x - TILE_SIZE) / 2.0, 2.0), Vector2(TILE_SIZE, TILE_SIZE))
	if _hovered:
		tile = tile.grow(3.0)
	_draw_tile(tile, 6)
	# Name darunter
	var font := get_theme_default_font()
	var font_size := 19
	draw_string(font, Vector2(0.0, tile.end.y + 26.0), app.display_name, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, font_size, LINE_COLOR)


## Die farbige Kachel mit Symbol (shadow = Schattengröße).
func _draw_tile(tile: Rect2, shadow: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = app.color.lightened(0.08) if _hovered else app.color
	box.set_corner_radius_all(26)
	box.anti_aliasing = true
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = shadow
	box.shadow_offset = Vector2(0, 3) if shadow > 0 else Vector2.ZERO
	draw_style_box(box, tile)
	var c := tile.get_center()
	if app.custom_icon:
		var icon_size := Vector2(TILE_SIZE, TILE_SIZE) * 0.62
		draw_texture_rect(app.custom_icon, Rect2(c - icon_size / 2.0, icon_size), false)
	else:
		_draw_symbol(c, app.symbol)


func _draw_symbol(c: Vector2, symbol: TabletAppData.Symbol) -> void:
	var w := 3.5
	match symbol:
		TabletAppData.Symbol.FURNISHING:
			# Sessel mit Stehlampe
			var seat := Rect2(c + Vector2(-26, 2), Vector2(36, 12))
			_rect(seat, w)
			_rect(Rect2(c + Vector2(-26, -14), Vector2(36, 16)), w)
			draw_line(c + Vector2(-22, 14), c + Vector2(-22, 22), LINE_COLOR, w, true)
			draw_line(c + Vector2(6, 14), c + Vector2(6, 22), LINE_COLOR, w, true)
			draw_line(c + Vector2(24, -12), c + Vector2(24, 22), LINE_COLOR, w, true)
			draw_line(c + Vector2(18, 22), c + Vector2(30, 22), LINE_COLOR, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(16, -12), c + Vector2(32, -12), c + Vector2(28, -24), c + Vector2(20, -24)]), LINE_COLOR)
		TabletAppData.Symbol.BOOKS:
			# Stapel aus drei Büchern
			for i in 3:
				var y := 14.0 - i * 13.0
				var x: float = [-24.0, -18.0, -22.0][i]
				_rect(Rect2(c + Vector2(x, y - 9.0), Vector2(44.0, 11.0)), w)
				draw_line(c + Vector2(x + 7.0, y - 7.0), c + Vector2(x + 7.0, y), LINE_COLOR, 2.5, true)
		TabletAppData.Symbol.STOCK:
			# Kiste mit Büchern darin
			_rect(Rect2(c + Vector2(-26, -2), Vector2(52, 26)), w)
			draw_line(c + Vector2(-26, 6), c + Vector2(26, 6), LINE_COLOR, w, true)
			for i in 4:
				var x := -18.0 + i * 10.0
				var h := [16.0, 22.0, 18.0, 14.0][i] as float
				_rect(Rect2(c + Vector2(x, -2.0 - h), Vector2(7.0, h)), 3.0)
		TabletAppData.Symbol.COLLECTION:
			# Vier Cover-Kacheln, eine mit Stern
			for i in 4:
				var cell := Rect2(c + Vector2(-24.0 + (i % 2) * 26.0, -24.0 + (i / 2) * 26.0), Vector2(22.0, 22.0))
				_rect(cell, 3.0)
			_star(c + Vector2(15, 15), 7.0)
		TabletAppData.Symbol.NEST:
			# "Nest & Nook": kleines Haus mit Herz und Blatt
			draw_polyline(PackedVector2Array([c + Vector2(-28, -2), c + Vector2(0, -26), c + Vector2(28, -2)]), LINE_COLOR, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-20, -8), c + Vector2(-20, 24), c + Vector2(20, 24), c + Vector2(20, -8)]), LINE_COLOR, w, true)
			_heart(c + Vector2(0, 6), 9.0)
			draw_line(c + Vector2(14, -16), c + Vector2(14, -26), LINE_COLOR, w, true)  # Schornstein
			_leaf(c + Vector2(26, 22), -0.6)
		TabletAppData.Symbol.BOOKSHOP:
			# Bücherladen: Einkaufstasche mit einem Buch
			var bag := PackedVector2Array([c + Vector2(-24, -10), c + Vector2(24, -10), c + Vector2(20, 26), c + Vector2(-20, 26), c + Vector2(-24, -10)])
			draw_polyline(bag, LINE_COLOR, w, true)
			draw_arc(c + Vector2(0, -10), 11.0, PI, TAU, 16, LINE_COLOR, w, true)
			_rect(Rect2(c + Vector2(-9, -1), Vector2(18, 20)), 3.0)
			draw_line(c + Vector2(-4, -1), c + Vector2(-4, 19), LINE_COLOR, 2.5, true)
		TabletAppData.Symbol.STATS:
			# Statistik: drei ruhige Säulen mit runden Köpfen auf einer Linie
			draw_line(c + Vector2(-28, 24), c + Vector2(28, 24), LINE_COLOR, w, true)
			for i in 3:
				var x := -16.0 + i * 16.0
				var h: float = [22.0, 36.0, 28.0][i]
				draw_line(c + Vector2(x, 18), c + Vector2(x, 18 - h), LINE_COLOR, 9.0, true)
				draw_circle(c + Vector2(x, 18 - h), 4.5, LINE_COLOR)
				draw_circle(c + Vector2(x, 18), 4.5, LINE_COLOR)
		TabletAppData.Symbol.TIPS:
			# Tipps & Tricks: aufgeschlagenes Büchlein mit kleinem Stern
			var left := PackedVector2Array([c + Vector2(0, -12), c + Vector2(-12, -18), c + Vector2(-28, -16), c + Vector2(-28, 18), c + Vector2(-12, 16), c + Vector2(0, 22)])
			var right := PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, -18), c + Vector2(28, -16), c + Vector2(28, 18), c + Vector2(12, 16), c + Vector2(0, 22)])
			draw_polyline(left, LINE_COLOR, w, true)
			draw_polyline(right, LINE_COLOR, w, true)
			draw_line(c + Vector2(0, -12), c + Vector2(0, 22), LINE_COLOR, 2.5, true)
			for i in 3:
				draw_line(c + Vector2(-22, -6 + i * 8), c + Vector2(-7, -8 + i * 8), LINE_COLOR, 2.0, true)
			_star(c + Vector2(15, 0), 8.0)
		_:
			draw_circle(c, 18.0, LINE_COLOR)


func _rect(rect: Rect2, width: float) -> void:
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]), LINE_COLOR, width, true)


func _heart(c: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		# Herzkurve, auf Größe r gebracht (Spitze unten)
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(c + Vector2(x, y) * r / 16.0)
	draw_colored_polygon(points, LINE_COLOR)


func _leaf(c: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var t := TAU * i / 16.0
		points.append(c + Vector2(cos(t) * 8.0, sin(t) * 4.0).rotated(angle))
	draw_colored_polygon(points, LINE_COLOR)


func _star(c: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		points.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius)
	draw_colored_polygon(points, LINE_COLOR)
