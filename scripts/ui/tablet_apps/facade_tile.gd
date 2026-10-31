class_name FacadeTile
extends Button
## Eine große Bild-Kachel der App „Fassade“ (seit Etappe 6b): zeigt eine Wahl ohne Text (Name und Preis
## im Tooltip) – als Foto eines Modells (texture), als gezeichnete Probe (Farbe, Wandputz, Ziegel,
## Bretter, Stein, Stoffmuster, Fensterrahmen, Tür, Fülle) oder als „keine“. Die gewählte Kachel hat
## einen Rahmen in der Akzentfarbe der App und ein Häkchen. Gehören mehrere Farben zu einer Kachel
## (z. B. Geranien in Rot, Rosa, Weiß), stehen darunter Farbtupfer zum Antippen (Signal dot_chosen).

## Ein Farbtupfer wurde angetippt (id der Wahl).
signal dot_chosen(id: String)

enum Kind { PHOTO, MATERIAL, PAINT, FRAME, DOOR, NONE, FULLNESS, SHOPFRONT, WINDOW, DOOR_LIGHTS, QUOINS, FASCIA }

const DOT_SIZE := 17.0
const DOT_ROW := 24.0
const INSET := 7.0

var kind: Kind = Kind.PHOTO
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Farbe (PAINT, FRAME, DOOR) bzw. Material der Probe (MATERIAL)
var color: Color = Color.WHITE
var material_sample: Material
## Fülle (FULLNESS): 0,7 dezent … 1,35 überquellend
var amount: float = 1.0
## Art der Holzfront (SHOPFRONT): "classic", "beadboard", "victorian" – gezeichnet in color
var variant: String = ""
## Fenster bzw. Türlichter (WINDOW, DOOR_LIGHTS): die Wahl; round_top = Tür mit Rundbogen
var window: FacadeOption
var round_top := false
## Verwittert (0 … 1): Putzreste, Risse, abblätternde Farbe auf der Probe
var weather: float = 0.0
## Ecksteine (QUOINS): Material der Steine (null = ohne)
var quoin_sample: Material
## Gesperrt: ausgegraut mit Schloss, nicht wählbar
var locked := false
var selected := false
## Farbtupfer: je [id, Farbe, Name]; dot_selected = id des gewählten
var dots: Array = []
var dot_selected := ""

var _style: TabletAppStyle


func setup(app_style: TabletAppStyle, tile_size: Vector2) -> void:
	_style = app_style
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = tile_size + (Vector2(0.0, DOT_ROW) if dots.size() > 1 else Vector2.ZERO)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _style.panel
		box.set_corner_radius_all(maxi(_style.button_radius, 6))
		box.anti_aliasing = true
		box.border_color = _style.panel_border if _style.panel_border.a > 0.0 else Color(_style.text, 0.15)
		box.set_border_width_all(1)
		if selected:
			box.border_color = _style.accent
			box.set_border_width_all(3)
			box.bg_color = _style.panel.lerp(_style.accent, 0.12)
		elif state.begins_with("hover"):
			box.border_color = _style.accent.lerp(_style.panel, 0.35)
			box.set_border_width_all(2)
		if state == "focus":
			box.draw_center = false
			box.set_border_width_all(0)
		add_theme_stylebox_override(state, box)
	if dots.size() > 1:
		_add_dots()


func _add_dots() -> void:
	var row := HBoxContainer.new()
	row.name = "Dots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -DOT_ROW - 2.0
	row.offset_bottom = -4.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for dot: Array in dots:
		var button := _Dot.new()
		button.dot_color = dot[1]
		button.ring = _style.accent
		button.chosen = selected and dot[0] == dot_selected
		button.tooltip_text = dot[2]
		button.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func() -> void: dot_chosen.emit(dot[0]))
		row.add_child(button)


## Bildfläche der Kachel (ohne Rand und Farbtupfer).
func _picture_rect() -> Rect2:
	var bottom := DOT_ROW if dots.size() > 1 else 0.0
	return Rect2(Vector2(INSET, INSET), size - Vector2(INSET * 2.0, INSET * 2.0 + bottom))


func _draw() -> void:
	if _style == null:
		return
	var rect := _picture_rect()
	match kind:
		Kind.PHOTO:
			if texture:
				var side := minf(rect.size.x, rect.size.y)
				draw_texture_rect(texture, Rect2(rect.get_center() - Vector2.ONE * side / 2.0, Vector2.ONE * side), false)
		Kind.MATERIAL:
			_draw_material(rect)
		Kind.PAINT:
			_draw_paint(rect)
		Kind.FRAME:
			_draw_frame(rect)
		Kind.DOOR:
			_draw_door(rect)
		Kind.NONE:
			var center := rect.get_center()
			var radius := minf(rect.size.x, rect.size.y) * 0.3
			draw_arc(center, radius, 0.0, TAU, 40, _style.muted, 3.0, true)
			draw_line(center + Vector2(-radius, radius) * 0.7, center + Vector2(radius, -radius) * 0.7, _style.muted, 3.0, true)
		Kind.FULLNESS:
			_draw_fullness(rect)
		Kind.SHOPFRONT:
			_draw_shopfront(rect)
		Kind.WINDOW:
			_draw_window(rect)
		Kind.DOOR_LIGHTS:
			_draw_door_lights(rect)
		Kind.QUOINS:
			_draw_quoins(rect)
		Kind.FASCIA:
			_draw_fascia(rect)
	if weather > 0.0 and kind in [Kind.PAINT, Kind.FRAME, Kind.DOOR, Kind.FASCIA, Kind.MATERIAL]:
		_draw_weathering(rect.grow(-4.0))
	if locked:
		_draw_lock(rect)
	if selected:
		# Häkchen oben rechts
		var center := Vector2(size.x - 15.0, 15.0)
		draw_circle(center, 10.5, _style.accent)
		draw_polyline(PackedVector2Array([center + Vector2(-5.0, 0.0), center + Vector2(-1.5, 3.8), center + Vector2(5.0, -3.8)]),
			_style.accent_text, 2.4, true)


# --- Gezeichnete Proben ---

func _rounded(rect: Rect2, fill: Color, radius: int = 8) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	draw_style_box(box, rect)


## Farbkarte: Fläche in der Farbe mit hellem Glanz oben.
func _draw_paint(rect: Rect2) -> void:
	var chip := rect.grow(-4.0)
	_rounded(chip, color, 10)
	_rounded(Rect2(chip.position, Vector2(chip.size.x, chip.size.y * 0.28)), Color(1.0, 1.0, 1.0, 0.1), 10)
	# Holzfeld wie an der Ladenfront: feine Kante
	var panel := chip.grow(-chip.size.x * 0.18)
	draw_rect(panel, color.darkened(0.25), false, 2.0)
	draw_rect(panel.grow(-3.0), color.lightened(0.12), false, 1.0)


## Sprossenfenster in der Rahmenfarbe auf heller Wand.
func _draw_frame(rect: Rect2) -> void:
	_rounded(rect.grow(-4.0), Color(0.9, 0.86, 0.78), 10)
	var window := Rect2(rect.get_center() - Vector2(rect.size.x * 0.27, rect.size.y * 0.34), Vector2(rect.size.x * 0.54, rect.size.y * 0.68))
	draw_rect(window, Color(0.62, 0.72, 0.78))
	draw_rect(window, color, false, 6.0)
	draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), color, 4.0)
	draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y), color, 4.0)
	draw_rect(Rect2(window.position + Vector2(-5.0, window.size.y), Vector2(window.size.x + 10.0, 5.0)), color.darkened(0.15))


## Tür in der Türfarbe mit runder Oberkante und Knauf.
func _draw_door(rect: Rect2) -> void:
	_rounded(rect.grow(-4.0), Color(0.9, 0.86, 0.78), 10)
	var width := rect.size.x * 0.44
	var bottom := rect.end.y - 6.0
	var top := rect.position.y + rect.size.y * 0.16
	var left := rect.get_center().x - width / 2.0
	draw_rect(Rect2(left, top + width / 2.0, width, bottom - top - width / 2.0), color)
	draw_circle(Vector2(rect.get_center().x, top + width / 2.0), width / 2.0, color)
	var inner := Rect2(left + width * 0.18, top + width * 0.55, width * 0.64, (bottom - top) * 0.3)
	draw_rect(inner, color.darkened(0.22), false, 2.0)
	draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y + 8.0), Vector2(inner.size.x, (bottom - top) * 0.28)), color.darkened(0.22), false, 2.0)
	draw_circle(Vector2(left + width * 0.8, (top + bottom) / 2.0 + 6.0), 3.2, Color(0.85, 0.68, 0.3))


## Ein Stück Holz-Ladenfront im Anstrich: Felder (klassisch), schmale Bretter (Nut und Feder) oder
## hohe Felder mit Bogen und Goldkante (viktorianisch); oben ein Gesims, unten ein Sockel.
func _draw_shopfront(rect: Rect2) -> void:
	var area := rect.grow(-4.0)
	_rounded(area, color, 8)
	var dark := color.darkened(0.3)
	var light := color.lightened(0.16)
	var gold := Color(0.86, 0.7, 0.36)
	var top := Rect2(area.position, Vector2(area.size.x, area.size.y * 0.13))
	var bottom := Rect2(area.position.x, area.end.y - area.size.y * 0.1, area.size.x, area.size.y * 0.1)
	var body := Rect2(area.position.x, top.end.y, area.size.x, bottom.position.y - top.end.y)
	match variant:
		"beadboard":
			var count := 9
			var w := body.size.x / count
			for i in range(1, count):
				var x := body.position.x + i * w
				draw_line(Vector2(x, body.position.y), Vector2(x, body.end.y), dark, 2.0)
				draw_line(Vector2(x + 2.0, body.position.y), Vector2(x + 2.0, body.end.y), light, 1.0)
		"victorian":
			for k in 2:
				var panel := Rect2(body.position.x + body.size.x * (0.1 + k * 0.45), body.position.y + body.size.y * 0.1,
					body.size.x * 0.35, body.size.y * 0.8)
				var arch := panel.size.x / 2.0
				var points := PackedVector2Array()
				points.append(Vector2(panel.position.x, panel.end.y))
				for i in 13:
					var angle := PI + PI * i / 12.0
					points.append(Vector2(panel.get_center().x, panel.position.y + arch) + Vector2.from_angle(angle) * arch)
				points.append(Vector2(panel.end.x, panel.end.y))
				points.append(points[0])
				draw_colored_polygon(points, color.darkened(0.12))
				draw_polyline(points, gold, 1.5, true)
				draw_circle(Vector2(panel.get_center().x, panel.position.y + panel.size.y * 0.62), 2.6, gold)
		_:
			for k in 2:
				var panel := Rect2(body.position.x + body.size.x * (0.09 + k * 0.47), body.position.y + body.size.y * 0.14,
					body.size.x * 0.35, body.size.y * 0.72)
				draw_rect(panel, light, false, 3.0)
				draw_rect(panel.grow(-5.0), dark, false, 2.0)
	draw_rect(top, dark)
	draw_rect(Rect2(top.position.x, top.end.y - 3.0, top.size.x, 3.0), light)
	draw_rect(bottom, dark)
	if variant == "victorian":
		draw_line(Vector2(top.position.x, top.end.y - 5.0), Vector2(top.end.x, top.end.y - 5.0), gold, 1.5)


## Blumenkasten mit wenigen bis vielen Blüten.
func _draw_fullness(rect: Rect2) -> void:
	_rounded(rect.grow(-4.0), Color(0.88, 0.9, 0.86), 10)
	var box := Rect2(rect.position.x + rect.size.x * 0.14, rect.end.y - rect.size.y * 0.3, rect.size.x * 0.72, rect.size.y * 0.2)
	var count := roundi(lerpf(3.0, 11.0, clampf((amount - 0.7) / 0.65, 0.0, 1.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var flower_colors := [Color(0.85, 0.3, 0.35), Color(0.95, 0.6, 0.7), Color(0.98, 0.95, 0.9), Color(0.6, 0.45, 0.8)]
	for i in count:
		var x := box.position.x + box.size.x * (i + 0.5) / count + rng.randf_range(-4.0, 4.0)
		var y := box.position.y - rng.randf_range(4.0, 10.0 + amount * 14.0)
		draw_circle(Vector2(x - 5.0, y + 7.0), 5.0, Color(0.32, 0.52, 0.3))
		draw_circle(Vector2(x, y), 5.5 + amount * 1.5, flower_colors[i % flower_colors.size()])
		draw_circle(Vector2(x, y), 1.8, Color(0.95, 0.8, 0.3))
	_rounded(box, Color(0.55, 0.36, 0.24), 3)


## Probe eines Materials (Shader-Werte des Bilderbuch-Shaders): Putz, Ziegel, Quader, Bretter, Holz,
## Stoff mit Streifen, Karo oder Blümchen.
func _draw_material(rect: Rect2, sample: Material = null) -> void:
	var area := rect.grow(-4.0)
	var shader := (sample if sample else material_sample) as ShaderMaterial
	if shader == null:
		_rounded(area, color, 10)
		return
	var base := _param(shader, "base_color", Color(0.9, 0.85, 0.75))
	var second := _param(shader, "second_color", base)
	var third := _param(shader, "third_color", Color(0.95, 0.91, 0.82))
	var grain := int(_value(shader, "grain", 0))
	var stripes := float(_value(shader, "stripe_width", 0.0))
	var pattern := int(_value(shader, "pattern", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	draw_rect(area, base)
	match grain:
		3, 8:
			# Ziegel bzw. große Quader im Verband, Fugen in der zweiten Farbe
			draw_rect(area, second)
			var rows := 8 if grain == 3 else 4
			var per_row := 3.2 if grain == 3 else 1.8
			var h := area.size.y / rows
			var w := area.size.x / per_row
			for row in rows:
				var shift := (w * 0.5 if row % 2 == 1 else 0.0) if grain == 3 else rng.randf_range(0.0, w)
				var x := area.position.x - shift
				while x < area.end.x:
					var brick := Rect2(x + 1.5, area.position.y + row * h + 1.5, w - 3.0, h - 3.0).intersection(area)
					if brick.size.x > 0.0:
						draw_rect(brick, base * rng.randf_range(0.88, 1.06))
					x += w
		9:
			# Bretter mit Schatten unter jeder Kante
			var boards := 6
			var h := area.size.y / boards
			for row in boards:
				var y := area.position.y + row * h
				draw_rect(Rect2(area.position.x, y, area.size.x, h), base * rng.randf_range(0.9, 1.05))
				draw_rect(Rect2(area.position.x, y + h - 3.0, area.size.x, 3.0), base.darkened(0.32))
		2:
			for i in 7:
				var y := area.position.y + area.size.y * (i + 0.5) / 7.0
				draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y + rng.randf_range(-3.0, 3.0)), base.darkened(0.12), 2.0, true)
		4:
			if stripes > 0.0:
				var count := 6
				var w := area.size.x / count
				for i in count:
					if i % 2 == 1:
						draw_rect(Rect2(area.position.x + i * w, area.position.y, w, area.size.y), second)
			elif pattern == 1:
				# Karo: helle Bänder kreuz und quer
				var count := 5
				var w := area.size.x / count
				for i in count:
					draw_rect(Rect2(area.position.x + i * w, area.position.y, w * 0.5, area.size.y), Color(third, 0.5))
					draw_rect(Rect2(area.position.x, area.position.y + i * area.size.y / count, area.size.x, area.size.y / count * 0.5), Color(third, 0.5))
			elif pattern == 2:
				# Blümchen
				for i in 9:
					var center := area.position + Vector2((i % 3 + 0.5) * area.size.x / 3.0 + rng.randf_range(-6, 6), (floorf(i / 3.0) + 0.5) * area.size.y / 3.0 + rng.randf_range(-6, 6))
					for k in 5:
						draw_circle(center + Vector2.from_angle(TAU * k / 5.0) * 4.5, 3.6, second)
					draw_circle(center, 2.2, third)
			else:
				for i in 10:
					var y := area.position.y + area.size.y * i / 10.0
					draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), base.darkened(0.05), 1.0)
		_:
			# Putz/Stein: weiche Flecken
			for i in 26:
				var point := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
				draw_circle(point, rng.randf_range(1.0, 4.0), base * rng.randf_range(0.9, 1.08))
	draw_rect(area, Color(0.0, 0.0, 0.0, 0.12), false, 1.0)


## Fenster: Umriss mit Rahmen, Glas und Sprossen auf einer Probe der Wand (Erker mit Dach und Seiten).
func _draw_window(rect: Rect2) -> void:
	_draw_material(rect, material_sample)
	if window == null:
		return
	var outline := FacadeLayout.window_outline(window)
	var b := OpeningShape.bounds(outline)
	var area := rect.grow(-14.0)
	var scale := minf(area.size.x / b.size.x, area.size.y / b.size.y) * (0.78 if window.bay_depth > 0.0 else 0.92)
	var to_tile := func(p: Vector2) -> Vector2:
		return area.get_center() + Vector2(p.x - b.get_center().x, -(p.y - b.get_center().y)) * scale
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(to_tile.call(p))
	var frame_w := (0.09 if window.category == "window_ground" else 0.07) * scale * 1.4
	draw_colored_polygon(pts, color)
	var inner := OpeningShape.offset(outline, -frame_w / scale)
	var ipts := PackedVector2Array()
	for p in inner:
		ipts.append(to_tile.call(p))
	if ipts.size() >= 3:
		draw_colored_polygon(ipts, Color(0.62, 0.72, 0.78))
		draw_colored_polygon(PackedVector2Array([ipts[0], ipts[1], (ipts[1] + ipts[ipts.size() / 2]) / 2.0]), Color(1, 1, 1, 0.18))
	# Sprossen
	var ib := OpeningShape.bounds(inner)
	for i in range(1, window.muntins.x):
		var x := lerpf(ib.position.x, ib.end.x, float(i) / window.muntins.x)
		var span := WindowUnit.height_at(inner, x)
		if span.y > span.x:
			draw_line(to_tile.call(Vector2(x, span.x)), to_tile.call(Vector2(x, span.y)), color, maxf(1.5, 0.035 * scale))
	for j in range(1, window.muntins.y):
		var y := lerpf(ib.position.y, ib.end.y, float(j) / window.muntins.y)
		var span := OpeningShape.width_at(inner, y)
		if span.y > span.x:
			draw_line(to_tile.call(Vector2(span.x, y)), to_tile.call(Vector2(span.y, y)), color, maxf(1.5, 0.035 * scale))
	if window.bay_depth > 0.0:
		# Erker: Dach oben, Sockel unten, schräge Seiten angedeutet
		var tl: Vector2 = to_tile.call(Vector2(b.position.x, b.end.y))
		var tr: Vector2 = to_tile.call(Vector2(b.end.x, b.end.y))
		var bl: Vector2 = to_tile.call(Vector2(b.position.x, b.position.y))
		var br: Vector2 = to_tile.call(Vector2(b.end.x, b.position.y))
		var lift := 9.0
		draw_colored_polygon(PackedVector2Array([tl + Vector2(-6, 0), tr + Vector2(6, 0), tr + Vector2(-2, -lift), tl + Vector2(2, -lift)]),
			Color(0.55, 0.58, 0.6))
		draw_colored_polygon(PackedVector2Array([bl + Vector2(-4, 0), br + Vector2(4, 0), br + Vector2(4, 8), bl + Vector2(-4, 8)]), color.darkened(0.2))
		for side in [tl, tr]:
			var bottom: Vector2 = bl if side == tl else br
			draw_line(side, bottom, color.darkened(0.25), 3.0)
	else:
		# Fensterbank
		var low := WindowUnit.height_at(outline, 0.0).x
		var sill_w := b.size.x * (0.55 if window.shape == "round" else 1.08)
		var c: Vector2 = to_tile.call(Vector2(0.0, low))
		draw_rect(Rect2(c + Vector2(-sill_w * scale / 2.0, 0.0), Vector2(sill_w * scale, 4.0)), Color(0.85, 0.8, 0.7))


## Tür mit Seiten- und Oberlichtern (schematisch): Rahmen, Glas, Türblatt in der Türfarbe.
func _draw_door_lights(rect: Rect2) -> void:
	_rounded(rect.grow(-4.0), Color(0.86, 0.8, 0.72), 10)
	if window == null:
		return
	var side := window.side_width
	var transom := window.transom
	var width := FacadeLayout.LEAF_W + 2.0 * FacadeLayout.CASING + (2.0 * (side + FacadeLayout.MULLION) if side > 0.0 else 0.0)
	var outline: PackedVector2Array
	var leaf := OpeningShape.outline(OpeningShape.Kind.ARCH if round_top else OpeningShape.Kind.RECT, FacadeLayout.LEAF_W,
		FacadeLayout.LEAF_H, FacadeLayout.LEAF_W / 2.0)
	if round_top:
		var spring := FacadeLayout.LEAF_H - FacadeLayout.LEAF_W / 2.0 + FacadeLayout.CASING + transom * 0.6
		outline = OpeningShape.outline(OpeningShape.Kind.ARCH, width, spring + width / 2.0, width / 2.0)
	else:
		outline = OpeningShape.outline(OpeningShape.Kind.RECT, width, FacadeLayout.LEAF_H + FacadeLayout.CASING + (transom + 0.04 if transom > 0.0 else 0.0))
	var area := rect.grow(-12.0)
	var b := OpeningShape.bounds(outline)
	var scale := minf(area.size.x / 1.6, area.size.y / 2.75)
	var origin := Vector2(area.get_center().x, area.end.y)
	var conv := func(poly: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in poly:
			out.append(origin + Vector2(p.x, -p.y) * scale)
		return out
	draw_colored_polygon(conv.call(outline), Color(0.9, 0.86, 0.76))
	var inner := OpeningShape.offset(outline, -FacadeLayout.CASING)
	if inner.size() >= 3:
		draw_colored_polygon(conv.call(inner), Color(0.62, 0.72, 0.78))
	draw_colored_polygon(conv.call(OpeningShape.offset(leaf, 0.035)), Color(0.9, 0.86, 0.76))
	draw_colored_polygon(conv.call(leaf), color)
	draw_circle(origin + Vector2(-0.38, -1.0) * scale, 2.5, Color(0.85, 0.68, 0.3))
	if b.size.x > 0.0:
		pass


## Ecke einer Wand mit (oder ohne) Ecksteinen.
func _draw_quoins(rect: Rect2) -> void:
	_draw_material(rect, material_sample)
	var area := rect.grow(-4.0)
	if quoin_sample is ShaderMaterial:
		var stone := _param(quoin_sample as ShaderMaterial, "base_color", Color(0.86, 0.78, 0.63))
		var h := area.size.y / 6.0
		for j in 6:
			var w := area.size.x * (0.38 if j % 2 == 0 else 0.25)
			for side in [0, 1]:
				var x := area.position.x if side == 0 else area.end.x - w
				var r := Rect2(x + (2.0 if side == 0 else -2.0), area.position.y + j * h + 1.5, w, h - 3.0)
				draw_rect(r, stone * (0.95 + 0.06 * (j % 3)))
				draw_rect(r, stone.darkened(0.25), false, 1.0)
	else:
		draw_line(area.get_center() + Vector2(-14, -14), area.get_center() + Vector2(14, 14), Color(1, 1, 1, 0.7), 3.0, true)
		draw_line(area.get_center() + Vector2(14, -14), area.get_center() + Vector2(-14, 14), Color(1, 1, 1, 0.7), 3.0, true)


## Schild-Balken: ein Stück Wand, darauf der Balken in der Farbe bzw. dem Material, goldene Schrift angedeutet.
func _draw_fascia(rect: Rect2) -> void:
	var area := rect.grow(-4.0)
	_rounded(area, Color(0.78, 0.7, 0.6), 8)
	var band := Rect2(area.position.x, area.position.y + area.size.y * 0.3, area.size.x, area.size.y * 0.4)
	draw_rect(band, color)
	draw_rect(Rect2(band.position, Vector2(band.size.x, 4.0)), color.lightened(0.15))
	draw_rect(Rect2(band.position + Vector2(0.0, band.size.y - 4.0), Vector2(band.size.x, 4.0)), color.darkened(0.3))
	var y := band.get_center().y
	draw_line(Vector2(band.position.x + 18.0, y), Vector2(band.end.x - 18.0, y), Color(0.86, 0.7, 0.36), 3.0, true)


## Verwitterung auf einer Probe: Putzreste bzw. abgeblätterte Stellen und feine Risse.
func _draw_weathering(area: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var pale := Color(0.84, 0.78, 0.68, 0.85)
	for i in roundi(9 * weather):
		var c := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		for k in 4:
			draw_circle(c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4)), rng.randf_range(2.0, 5.5), pale)
	for i in 3:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y * 0.5)
		var pts := PackedVector2Array([p])
		for k in 4:
			p += Vector2(rng.randf_range(-7, 7), rng.randf_range(4, 9))
			pts.append(p)
		draw_polyline(pts, Color(0.2, 0.16, 0.12, 0.6), 1.2, true)


## Gesperrt: blass überdeckt, in der Mitte ein kleines Schloss.
func _draw_lock(rect: Rect2) -> void:
	_rounded(rect.grow(-2.0), Color(_style.panel, 0.62), maxi(_style.button_radius, 6))
	var c := rect.get_center()
	var col := Color(_style.text, 0.85)
	draw_arc(c + Vector2(0, -6), 8.0, PI, TAU, 16, col, 3.0, true)
	draw_line(c + Vector2(-8, -6), c + Vector2(-8, 0), col, 3.0)
	draw_line(c + Vector2(8, -6), c + Vector2(8, 0), col, 3.0)
	_rounded(Rect2(c + Vector2(-12, -1), Vector2(24, 18)), col, 4)
	draw_circle(c + Vector2(0, 7), 2.5, Color(_style.panel, 1.0))


static func _value(shader: ShaderMaterial, name: String, fallback: Variant) -> Variant:
	var value: Variant = shader.get_shader_parameter(name)
	return fallback if value == null else value


static func _param(shader: ShaderMaterial, name: String, fallback: Color) -> Color:
	var value: Variant = shader.get_shader_parameter(name)
	return value if value is Color else fallback


## Ein runder Farbtupfer (gewählt: Ring in der Akzentfarbe).
class _Dot:
	extends Button
	var dot_color := Color.WHITE
	var ring := Color.WHITE
	var chosen := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		if chosen or is_hovered():
			draw_circle(center, radius, ring if chosen else Color(ring, 0.5))
		draw_circle(center, radius - 2.5, Color(0.98, 0.96, 0.9))
		draw_circle(center, radius - 4.0, dot_color)
