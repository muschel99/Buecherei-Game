class_name TabletAppIcon
extends Button
## Ein großes App-Symbol auf dem Startbildschirm des Theken-Tablets: eine farbige, runde Kachel
## mit gezeichnetem Symbol (oder eigenem Bild) und dem Namen darunter.

const TILE_SIZE := 108.0
const LINE_COLOR := Color(1.0, 0.96, 0.88)

var app: TabletAppData

var _hovered := false


func setup(data: TabletAppData) -> void:
	app = data
	tooltip_text = ""
	focus_mode = Control.FOCUS_NONE
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
	var tile := Rect2(Vector2((size.x - TILE_SIZE) / 2.0, 2.0), Vector2(TILE_SIZE, TILE_SIZE))
	if _hovered:
		tile = tile.grow(3.0)
	var box := StyleBoxFlat.new()
	box.bg_color = app.color.lightened(0.08) if _hovered else app.color
	box.set_corner_radius_all(26)
	box.anti_aliasing = true
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	draw_style_box(box, tile)
	var c := tile.get_center()
	if app.custom_icon:
		var icon_size := Vector2(TILE_SIZE, TILE_SIZE) * 0.62
		draw_texture_rect(app.custom_icon, Rect2(c - icon_size / 2.0, icon_size), false)
	else:
		_draw_symbol(c, app.symbol)
	# Name darunter
	var font := get_theme_default_font()
	var font_size := 19
	draw_string(font, Vector2(0.0, tile.end.y + 26.0), app.display_name, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, font_size, LINE_COLOR)


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
		_:
			draw_circle(c, 18.0, LINE_COLOR)


func _rect(rect: Rect2, width: float) -> void:
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]), LINE_COLOR, width, true)


func _star(c: Vector2, r: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		points.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius)
	draw_colored_polygon(points, LINE_COLOR)
