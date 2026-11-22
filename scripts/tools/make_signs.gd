extends Node
## Ladenschilder malen (seit dem zweiten Nachtest der Überarbeitung, Wunsch der Entwicklerin: „unterschiedliche Ladenschilder mit
## unterschiedlichen Schriftarten, zum Stil des Spiels passend und trotzdem traditionell wie in einer englischen Straße“).
## Jedes Schild ist ein bemaltes Holzbrett (Maserung, abgegriffene Kanten, Zierlinien) mit eigener Schrift, eigenen Farben und
## gemalten Ornamenten. Schreibt die Bilder nach assets/textures/signs/ (gleiche Maße wie vorher – sie passen auf die Schildflächen
## der Hausmodelle). Schriften: assets/ui/fonts/ (OFL).
## Start (braucht Grafik):  xvfb-run -a godot --path . res://scenes/tools/make_signs.tscn -- [namen …]
##   ohne Namen alle; Namen = Dateinamen ohne .png, z. B. pub_fascia corner_90_hanging; "preview" = nur nach screenshots/signs/
## Die Bäckerei heißt vorläufig BAKERY_NAME (Vorschlag – die Entwicklerin sucht noch einen Namen).

const OUT := "res://assets/textures/signs/"
const BAKERY_NAME := "Rise & Shine"

const F_CINZEL := preload("res://assets/ui/fonts/CinzelDecorative-Black.woff2")
const F_CINZEL_BOLD := preload("res://assets/ui/fonts/CinzelDecorative-Bold.woff2")
const F_VIBES := preload("res://assets/ui/fonts/GreatVibes-Regular.woff2")
const F_CORMORANT_IT := preload("res://assets/ui/fonts/CormorantGaramond-BoldItalic.woff2")
const F_CORMORANT := preload("res://assets/ui/fonts/CormorantGaramond-SemiBold.woff2")
const F_FRAUNCES := preload("res://assets/ui/fonts/Fraunces-Black.woff2")
const F_FRAUNCES_IT := preload("res://assets/ui/fonts/Fraunces-SemiBoldItalic.woff2")
const F_LOBSTER := preload("res://assets/ui/fonts/Lobster-Regular.woff2")

## Name → [Breite, Höhe]
const SIGNS := {
	"pub_fascia": [2048, 239], "pub_hanging": [512, 478],
	"flower_shop_fascia": [2048, 185], "flower_shop_hanging": [512, 478],
	"corner_30_fascia": [768, 192], "corner_30_hanging": [512, 478],
	"corner_90_fascia": [768, 192], "corner_90_hanging": [512, 478],
	"bakery_shop_fascia": [2048, 224],
}

# Farben
const GOLD := Color(0.89, 0.71, 0.36)
const GOLD_LIGHT := Color(0.98, 0.87, 0.6)
const GOLD_DARK := Color(0.55, 0.38, 0.15)
const CREAM := Color(0.96, 0.92, 0.83)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var wanted := OS.get_cmdline_user_args()
	# "preview": nur nach screenshots/signs/ (zum Anschauen), die Schilder im Spiel bleiben
	var out := OUT
	if wanted.has("preview"):
		wanted.erase("preview")
		out = "res://screenshots/signs/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for sign_name: String in SIGNS:
		if not wanted.is_empty() and not wanted.has(sign_name):
			continue
		var size: Array = SIGNS[sign_name]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(int(size[0]), int(size[1]))
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.msaa_2d = Viewport.MSAA_4X
		add_child(viewport)
		var painter := SignPainter.new()
		painter.sign_name = sign_name
		painter.size = Vector2(viewport.size)
		viewport.add_child(painter)
		for k in 4:
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(out + sign_name + ".png"))
		print("Schild: ", sign_name)
		viewport.queue_free()
	get_tree().quit()


## Malt ein Schild (je Name eine Funktion).
class SignPainter extends Control:
	var sign_name := ""
	var rng := RandomNumberGenerator.new()

	func _draw() -> void:
		rng.seed = hash(sign_name)
		call("_paint_" + sign_name)

	# --- Bausteine ---

	## Bemaltes Brett: Grundfarbe, feine Maserung in Längsrichtung, etwas dunklere Ränder, ein paar abgeriebene Stellen.
	func board(color: Color, rect := Rect2(), grain := 0.05) -> void:
		var r := rect if rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, size)
		draw_rect(r, color)
		var lines := int(r.size.y / 3.0)
		for i in lines:
			var y := r.position.y + (i + rng.randf()) * r.size.y / lines
			var shade := rng.randf_range(-grain, grain)
			var c := color.darkened(shade) if shade > 0.0 else color.lightened(-shade)
			var points := PackedVector2Array()
			var wave := rng.randf_range(0.5, 2.5)
			var phase := rng.randf() * TAU
			for k in 33:
				var x := r.position.x + r.size.x * k / 32.0
				points.append(Vector2(x, y + sin(x / r.size.x * TAU * wave + phase) * 1.6))
			draw_polyline(points, Color(c, 0.55), rng.randf_range(1.0, 2.6), true)
		# dunklere Ränder (Schatten der Leisten) und Abrieb
		var edge := minf(r.size.x, r.size.y) * 0.07
		for k in 6:
			var t := k / 6.0
			var inset := edge * t
			draw_rect(Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.035 * (1.0 - t)), false, edge / 6.0)
		for k in int(r.size.x * r.size.y / 9000.0):
			var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			draw_circle(p, rng.randf_range(0.5, 1.8), Color(color.lightened(0.25), rng.randf_range(0.05, 0.16)))

	## Rahmenlinie(n) innen (Abstand vom Rand, Linienbreite).
	func frame_line(inset: float, width: float, color: Color, rect := Rect2()) -> void:
		var r := rect if rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(-inset), color, false, width, true)

	## Gold-Linie mit Glanz (hell oben, dunkel unten).
	func gold_frame(inset: float, width: float, rect := Rect2()) -> void:
		var r := rect if rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, size)
		frame_line(inset + width * 0.25, width, GOLD_DARK, r)
		frame_line(inset, width, GOLD, r)
		frame_line(inset - width * 0.2, width * 0.35, GOLD_LIGHT, r)

	## Schriftgröße, damit text höchstens max_width breit und max_height hoch ist.
	func fit(font: Font, text: String, max_width: float, max_height: float) -> int:
		var font_size := int(max_height)
		while font_size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			font_size -= 2
		return font_size

	## Schrift mittig um center (Grundlinie aus der Schrifthöhe), mit Block-Schatten, Kontur, Füllung und Glanzkante.
	func lettering(font: Font, text: String, center: Vector2, font_size: int, fill: Color, shadow: Color, shadow_depth := 4.0,
			outline := 0, outline_color := Color.BLACK, shine := Color(1, 1, 1, 0.0), spacing := 0.0) -> float:
		var width := _width(font, text, font_size, spacing)
		var ascent := font.get_ascent(font_size)
		var descent := font.get_descent(font_size)
		var pos := Vector2(center.x - width / 2.0, center.y + (ascent - descent) / 2.0 - descent * 0.15)
		# Block-Schatten (wie gemalte Schilder: mehrere Schritte schräg nach unten rechts)
		var steps := int(maxf(1.0, shadow_depth))
		for k in range(steps, 0, -1):
			var off := Vector2(k, k * 1.15) * (shadow_depth / steps)
			_text(font, text, pos + off, font_size, shadow, spacing)
		if outline > 0:
			_text_outline(font, text, pos, font_size, outline, outline_color, spacing)
		_text(font, text, pos, font_size, fill, spacing)
		if shine.a > 0.0:
			_text(font, text, pos + Vector2(-1.2, -1.4), font_size, shine, spacing)
			_text(font, text, pos + Vector2(0.4, 0.4), font_size, fill, spacing)
		return width

	func _width(font: Font, text: String, font_size: int, spacing: float) -> float:
		if spacing == 0.0:
			return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var w := 0.0
		for ch in text:
			w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
		return w - spacing

	func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, spacing: float) -> void:
		if spacing == 0.0:
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			return
		var x := pos.x
		for ch in text:
			draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing

	func _text_outline(font: Font, text: String, pos: Vector2, font_size: int, outline: int, color: Color, spacing: float) -> void:
		if spacing == 0.0:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, color)
			return
		var x := pos.x
		for ch in text:
			draw_string_outline(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, color)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing

	## Schrift im Bogen (Mitte center, Halbmesser radius; top = oben im Bogen lesbar, sonst unten).
	func arc_text(font: Font, text: String, center: Vector2, radius: float, font_size: int, color: Color, top := true,
			shadow := Color(0, 0, 0, 0.0)) -> void:
		var widths: Array[float] = []
		var total := 0.0
		for ch in text:
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.06
			widths.append(w)
			total += w
		var angle := -total / radius / 2.0
		var i := 0
		for ch in text:
			var mid := angle + widths[i] / radius / 2.0
			var a := -PI / 2.0 + mid if top else PI / 2.0 - mid
			var p := center + Vector2(cos(a), sin(a)) * radius
			var rot := a + PI / 2.0 if top else a - PI / 2.0
			for layer in 2:
				if layer == 0 and shadow.a <= 0.0:
					continue
				draw_set_transform(p + (Vector2(2, 2.5) if layer == 0 else Vector2.ZERO), rot)
				draw_string(font, Vector2(-widths[i] / 2.0, font.get_ascent(font_size) * 0.35 if top else font.get_ascent(font_size) * 0.35),
					ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow if layer == 0 else color)
			angle += widths[i] / radius
			i += 1
		draw_set_transform(Vector2.ZERO, 0.0)

	func ellipse(center: Vector2, radii: Vector2, color: Color, angle := 0.0, points := 28) -> void:
		var poly := PackedVector2Array()
		for k in points:
			var a := TAU * k / points
			poly.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
		draw_colored_polygon(poly, color)

	## Blatt: spitz zulaufende Form von base in Richtung dir.
	func leaf(base: Vector2, dir: Vector2, length: float, width: float, color: Color) -> void:
		var n := dir.normalized()
		ellipse(base + n * length * 0.5, Vector2(length * 0.5, width * 0.55), color, n.angle())
		ellipse(base + n * length * 0.55 + n.orthogonal() * width * 0.12, Vector2(length * 0.35, width * 0.25), color.lightened(0.12), n.angle())
		draw_line(base, base + n * length * 0.85, color.darkened(0.25), maxf(1.0, width * 0.1), true)

	## Veilchen: fünf runde Blütenblätter (zwei oben größer), gelbe Mitte.
	func violet(center: Vector2, r: float, color: Color) -> void:
		var petals := [[-0.95, 1.05], [-2.2, 1.05], [0.35, 0.9], [2.75, 0.9], [1.57, 0.95]]
		for p: Array in petals:
			var a := float(p[0]) - PI / 2.0
			ellipse(center + Vector2(cos(a), sin(a)) * r * 0.62, Vector2(r * 0.58, r * 0.5) * float(p[1]), color.darkened(0.08 * float(p[1])), a)
		for p: Array in petals:
			var a := float(p[0]) - PI / 2.0
			ellipse(center + Vector2(cos(a), sin(a)) * r * 0.55, Vector2(r * 0.4, r * 0.32) * float(p[1]), color.lightened(0.12), a)
		draw_circle(center, r * 0.2, Color(0.98, 0.84, 0.35))
		draw_circle(center + Vector2(-r * 0.05, -r * 0.05), r * 0.08, Color(1, 0.96, 0.7))

	## Ähre: Halm mit Körnern rechts und links, oben eine Spitze.
	func wheat(base: Vector2, dir: Vector2, length: float, color: Color) -> void:
		var n := dir.normalized()
		var side := n.orthogonal()
		draw_line(base, base + n * length, color.darkened(0.2), maxf(2.0, length * 0.025), true)
		var grains := 7
		for k in grains:
			var t := 0.42 + 0.55 * k / grains
			var p := base + n * length * t
			for s: float in [-1.0, 1.0]:
				ellipse(p + side * s * length * 0.045 + n * length * 0.02, Vector2(length * 0.06, length * 0.028), color, (n + side * s * 0.9).angle())
		ellipse(base + n * length * 1.0, Vector2(length * 0.055, length * 0.025), color, n.angle())

	## Gerste/Hopfen-Zweig fürs Pub (wie Ähre, schlanker, mit Grannen).
	func barley(base: Vector2, dir: Vector2, length: float, color: Color) -> void:
		wheat(base, dir, length, color)
		var n := dir.normalized()
		var side := n.orthogonal()
		for k in 6:
			var t := 0.5 + 0.5 * k / 6.0
			var p := base + n * length * t
			for s: float in [-1.0, 1.0]:
				draw_line(p, p + (n * 0.8 + side * s * 0.6).normalized() * length * 0.16, Color(color, 0.8), 1.4, true)

	## Wollknäuel mit Fadenlinien und zwei Stricknadeln.
	func yarn_ball(center: Vector2, r: float, color: Color, needles := true) -> void:
		if needles:
			for s: float in [-1.0, 1.0]:
				var a := center + Vector2(s * r * 1.25, -r * 1.35)
				var b := center + Vector2(-s * r * 0.35, r * 0.35)
				draw_line(a, b, Color(0.55, 0.4, 0.26), r * 0.12, true)
				draw_circle(a, r * 0.14, Color(0.82, 0.62, 0.3))
		draw_circle(center + Vector2(r * 0.08, r * 0.1), r, color.darkened(0.3))
		draw_circle(center, r, color)
		for k in 7:
			var a0 := rng.randf() * TAU
			draw_arc(center + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * r, r * rng.randf_range(0.55, 0.95),
				a0, a0 + rng.randf_range(1.6, 2.8), 24, color.darkened(0.2), r * 0.06, true)
		for k in 4:
			var a0 := rng.randf() * TAU
			draw_arc(center, r * rng.randf_range(0.3, 0.85), a0, a0 + 1.5, 20, color.lightened(0.25), r * 0.05, true)
		# loser Faden
		var points := PackedVector2Array()
		for k in 20:
			var t := k / 19.0
			points.append(center + Vector2(r * (0.9 + t * 1.3), r * (0.5 + sin(t * 5.0) * 0.25 + t * 0.4)))
		draw_polyline(points, color.darkened(0.1), r * 0.07, true)

	## Teetasse mit Untertasse und Dampf.
	func teacup(center: Vector2, s: float, color: Color, trim: Color) -> void:
		ellipse(center + Vector2(0, s * 0.55), Vector2(s * 0.95, s * 0.18), color.darkened(0.1))
		ellipse(center + Vector2(0, s * 0.5), Vector2(s * 0.9, s * 0.15), color)
		var cup := PackedVector2Array()
		for k in 17:
			var t := k / 16.0
			var a := PI * t
			cup.append(center + Vector2(-cos(a) * s * 0.62, -s * 0.1 + sin(a) * s * 0.55))
		draw_colored_polygon(cup, color)
		draw_arc(center + Vector2(s * 0.68, s * 0.08), s * 0.2, -PI * 0.6, PI * 0.6, 16, color, s * 0.09, true)
		draw_line(center + Vector2(-s * 0.62, -s * 0.1), center + Vector2(s * 0.62, -s * 0.1), trim, s * 0.07, true)
		draw_line(center + Vector2(-s * 0.55, s * 0.12), center + Vector2(s * 0.55, s * 0.12), Color(trim, 0.7), s * 0.035, true)
		for k in 3:
			var pts := PackedVector2Array()
			for j in 12:
				var t := j / 11.0
				pts.append(center + Vector2((k - 1) * s * 0.28 + sin(t * 5.0 + k) * s * 0.08, -s * 0.25 - t * s * 0.6))
			draw_polyline(pts, Color(color, 0.55), s * 0.05, true)

	## Uhr auf fünf Uhr.
	func clock(center: Vector2, r: float, face: Color, ink: Color, rim: Color) -> void:
		draw_circle(center, r * 1.12, rim.darkened(0.3))
		draw_circle(center, r * 1.06, rim)
		draw_circle(center, r, face)
		for k in 12:
			var a := TAU * k / 12.0
			var d := Vector2(sin(a), -cos(a))
			draw_line(center + d * r * (0.78 if k % 3 == 0 else 0.84), center + d * r * 0.93, ink, r * (0.08 if k % 3 == 0 else 0.04), true)
		var hour := TAU * 5.0 / 12.0
		draw_line(center, center + Vector2(sin(hour), -cos(hour)) * r * 0.5, ink, r * 0.1, true)
		draw_line(center, center + Vector2(0, -r * 0.75), ink, r * 0.06, true)
		draw_circle(center, r * 0.08, ink)

	## Bogen-Schild (Ausleger): oben rund, unten gerade – Fläche und goldener Rahmen.
	func arched_frame(color: Color, inset: float, width: float) -> PackedVector2Array:
		var poly := _arch(inset)
		draw_polyline(poly + PackedVector2Array([poly[0]]), GOLD_DARK, width + 3.0, true)
		draw_polyline(poly + PackedVector2Array([poly[0]]), GOLD, width, true)
		draw_polyline(_arch(inset + width * 0.25) + PackedVector2Array([_arch(inset + width * 0.25)[0]]), Color(GOLD_LIGHT, 0.7), width * 0.3, true)
		return poly

	func _arch(inset: float) -> PackedVector2Array:
		var poly := PackedVector2Array()
		var w := size.x - inset * 2.0
		var top := size.y * 0.02 + inset
		var rise := size.y * 0.11
		poly.append(Vector2(inset, size.y - inset))
		poly.append(Vector2(inset, top + rise))
		for k in 25:
			var t := k / 24.0
			poly.append(Vector2(inset + w * t, top + rise - sin(t * PI) * rise))
		poly.append(Vector2(size.x - inset, size.y - inset))
		return poly

	# --- Ale & Amber (Pub) ---

	func _paint_pub_fascia() -> void:
		var oxblood := Color(0.33, 0.1, 0.11)
		board(oxblood, Rect2(), 0.07)
		gold_frame(16.0, 6.0)
		frame_line(32.0, 2.0, Color(GOLD, 0.8))
		var c := size / 2.0
		var font_size := fit(F_CINZEL, "ALE & AMBER", size.x * 0.56, size.y * 0.52)
		var w := lettering(F_CINZEL, "ALE & AMBER", c + Vector2(0, 4), font_size, GOLD, Color(0.12, 0.03, 0.04), 6.0, 3,
			Color(0.42, 0.24, 0.08), Color(GOLD_LIGHT, 0.85), font_size * 0.04)
		var small := int(size.y * 0.2)
		for side: float in [-1.0, 1.0]:
			var x := c.x + side * (w / 2.0 + (size.x / 2.0 - w / 2.0) * 0.5)
			lettering(F_CORMORANT, "FREE HOUSE" if side < 0.0 else "EST. 1868", Vector2(x, c.y + 4), small, Color(GOLD, 0.95),
				Color(0.1, 0.02, 0.03, 0.8), 2.0, 0, Color.BLACK, Color(0, 0, 0, 0), small * 0.18)
			for k: float in [-1.0, 1.0]:
				var bx := c.x + side * (w / 2.0 + 40.0)
				barley(Vector2(bx, c.y + 40.0), Vector2(side * 0.35 + k * 0.25, -1.0), size.y * 0.5, Color(0.88, 0.68, 0.33))

	func _paint_pub_hanging() -> void:
		var oxblood := Color(0.33, 0.1, 0.11)
		board(oxblood, Rect2(), 0.07)
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.47
		draw_arc(c, r - 6.0, 0, TAU, 96, GOLD_DARK, 10.0, true)
		draw_arc(c, r - 8.0, 0, TAU, 96, GOLD, 7.0, true)
		draw_arc(c, r - 26.0, 0, TAU, 96, Color(GOLD, 0.6), 2.0, true)
		# Bierglas mit Bernstein-Ale und Schaum
		var g := c + Vector2(0, 18)
		var glass := PackedVector2Array([g + Vector2(-46, -70), g + Vector2(46, -70), g + Vector2(36, 70), g + Vector2(-36, 70)])
		draw_colored_polygon(glass, Color(0.82, 0.48, 0.12))
		draw_colored_polygon(PackedVector2Array([g + Vector2(-44, -60), g + Vector2(-26, -60), g + Vector2(-22, 62), g + Vector2(-34, 62)]),
			Color(1, 0.82, 0.45, 0.5))
		for k in 9:
			draw_circle(g + Vector2(rng.randf_range(-25, 25), rng.randf_range(-40, 55)), rng.randf_range(1.5, 3.5), Color(1, 0.86, 0.5, 0.6))
		for k in 6:
			draw_circle(g + Vector2(-42 + k * 17, -74 + sin(k * 1.7) * 5.0), 17.0, CREAM)
		draw_polyline(glass + PackedVector2Array([glass[0]]), Color(1, 0.95, 0.85, 0.7), 3.0, true)
		draw_arc(g + Vector2(52, 0), 26, -PI * 0.55, PI * 0.55, 20, Color(1, 0.95, 0.85, 0.7), 7.0, true)
		arc_text(F_CINZEL, "ALE & AMBER", c, r - 58.0, 38, GOLD, true, Color(0.1, 0.02, 0.03, 0.8))
		arc_text(F_CORMORANT, "EST. 1868", c, r - 50.0, 30, Color(GOLD, 0.9), false, Color(0.1, 0.02, 0.03, 0.6))

	# --- Violetta's Flowers ---

	func _paint_flower_shop_fascia() -> void:
		var sage := Color(0.4, 0.5, 0.39)
		board(sage, Rect2(), 0.05)
		frame_line(12.0, 4.0, Color(CREAM, 0.95))
		frame_line(22.0, 1.5, Color(CREAM, 0.6))
		var c := size / 2.0
		var script_size := fit(F_VIBES, "Violetta's", size.x * 0.36, size.y * 0.66)
		var caps_size := int(size.y * 0.28)
		var script_w := F_VIBES.get_string_size("Violetta's", HORIZONTAL_ALIGNMENT_LEFT, -1, script_size).x
		var caps_w := _width(F_CORMORANT, "FLOWERS", caps_size, caps_size * 0.3)
		var total := script_w + 40.0 + caps_w
		var x0 := c.x - total / 2.0
		lettering(F_VIBES, "Violetta's", Vector2(x0 + script_w / 2.0, c.y + 8), script_size, CREAM, Color(0.2, 0.26, 0.2, 0.75), 4.0)
		lettering(F_CORMORANT, "FLOWERS", Vector2(x0 + script_w + 40.0 + caps_w / 2.0, c.y + 14), caps_size, Color(0.95, 0.88, 0.95),
			Color(0.2, 0.26, 0.2, 0.75), 3.0, 0, Color.BLACK, Color(0, 0, 0, 0), caps_size * 0.3)
		# Veilchen-Sträußchen an beiden Enden
		for side: float in [-1.0, 1.0]:
			var base := Vector2(c.x + side * size.x * 0.4, c.y)
			for k in 7:
				leaf(base + Vector2(rng.randf_range(-60, 60), rng.randf_range(10, 40)), Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, -0.2)),
					rng.randf_range(38, 60), rng.randf_range(13, 18), Color(0.3, 0.45, 0.28).lightened(rng.randf_range(0, 0.15)))
			var purples := [Color(0.48, 0.32, 0.66), Color(0.6, 0.42, 0.78), Color(0.38, 0.25, 0.55), Color(0.85, 0.75, 0.92)]
			for k in 6:
				violet(base + Vector2(rng.randf_range(-75, 75), rng.randf_range(-35, 25)), rng.randf_range(18, 26), purples[rng.randi() % purples.size()])

	func _paint_flower_shop_hanging() -> void:
		var sage := Color(0.4, 0.5, 0.39)
		board(sage, Rect2(), 0.05)
		arched_frame(sage, 22.0, 7.0)
		var c := Vector2(size.x / 2.0, size.y * 0.58)
		# Topf
		var pot := PackedVector2Array([c + Vector2(-58, 40), c + Vector2(58, 40), c + Vector2(44, 128), c + Vector2(-44, 128)])
		draw_colored_polygon(pot, Color(0.78, 0.45, 0.32))
		draw_rect(Rect2(c + Vector2(-66, 30), Vector2(132, 24)), Color(0.72, 0.4, 0.28))
		draw_rect(Rect2(c + Vector2(-66, 30), Vector2(132, 6)), Color(0.86, 0.56, 0.42))
		for k in 12:
			leaf(c + Vector2(rng.randf_range(-40, 40), 30), Vector2(rng.randf_range(-1.2, 1.2), -1.0), rng.randf_range(55, 85), rng.randf_range(15, 20),
				Color(0.3, 0.46, 0.28).lightened(rng.randf_range(0, 0.15)))
		var purples := [Color(0.48, 0.32, 0.66), Color(0.6, 0.42, 0.78), Color(0.38, 0.25, 0.55), Color(0.85, 0.75, 0.92)]
		for k in 11:
			violet(c + Vector2(rng.randf_range(-85, 85), rng.randf_range(-95, -5)), rng.randf_range(20, 27), purples[rng.randi() % purples.size()])
		lettering(F_VIBES, "Violetta's", Vector2(size.x / 2.0, size.y * 0.27), 60, CREAM, Color(0.2, 0.26, 0.2, 0.75), 3.0)

	# --- The Yarn Barn (Wolleladen, corner_30) ---

	func _paint_corner_30_fascia() -> void:
		var barn := Color(0.52, 0.2, 0.16)
		board(barn, Rect2(), 0.06)
		frame_line(10.0, 4.0, Color(CREAM, 0.95))
		frame_line(19.0, 1.5, Color(CREAM, 0.6))
		var c := size / 2.0
		var big := fit(F_FRAUNCES, "Yarn Barn", size.x * 0.56, size.y * 0.5)
		var w := lettering(F_FRAUNCES, "Yarn Barn", c + Vector2(8, 6), big, CREAM, Color(0.24, 0.07, 0.05), 4.0, 2, Color(0.32, 0.1, 0.07))
		lettering(F_FRAUNCES_IT, "The", Vector2(c.x - w / 2.0 + 6, c.y - big * 0.45), int(size.y * 0.17), Color(0.97, 0.84, 0.55),
			Color(0.24, 0.07, 0.05, 0.8), 2.0)
		lettering(F_CORMORANT, "WOOL · KNITTING · NEEDLECRAFT", Vector2(c.x + 8, c.y + big * 0.52 + 6), int(size.y * 0.1), Color(CREAM, 0.9),
			Color(0.24, 0.07, 0.05, 0.6), 1.0, 0, Color.BLACK, Color(0, 0, 0, 0), 2.5)
		yarn_ball(Vector2(size.x * 0.1, c.y + 10), 30.0, Color(0.9, 0.58, 0.58))
		yarn_ball(Vector2(size.x * 0.9, c.y + 10), 28.0, Color(0.95, 0.78, 0.38))

	func _paint_corner_30_hanging() -> void:
		var barn := Color(0.52, 0.2, 0.16)
		board(barn, Rect2(), 0.06)
		arched_frame(barn, 22.0, 7.0)
		yarn_ball(Vector2(size.x * 0.46, size.y * 0.6), 88.0, Color(0.9, 0.58, 0.58))
		yarn_ball(Vector2(size.x * 0.74, size.y * 0.8), 38.0, Color(0.95, 0.78, 0.38), false)
		lettering(F_FRAUNCES_IT, "The Yarn Barn", Vector2(size.x / 2.0, size.y * 0.23), 40, CREAM, Color(0.24, 0.07, 0.05, 0.8), 2.5)

	# --- Five O'Clock (Teeladen, corner_90) ---

	func _paint_corner_90_fascia() -> void:
		var navy := Color(0.13, 0.25, 0.32)
		board(navy, Rect2(), 0.05)
		gold_frame(10.0, 4.0)
		frame_line(20.0, 1.5, Color(GOLD, 0.7))
		var c := size / 2.0
		var big := fit(F_CORMORANT_IT, "Five O'Clock", size.x * 0.6, size.y * 0.62)
		lettering(F_CORMORANT_IT, "Five O'Clock", c + Vector2(0, -8), big, GOLD, Color(0.05, 0.1, 0.13), 4.0, 2, GOLD_DARK, Color(GOLD_LIGHT, 0.8))
		lettering(F_CINZEL_BOLD, "TEA ROOM", Vector2(c.x, c.y + big * 0.42), int(size.y * 0.12), Color(GOLD, 0.95), Color(0.05, 0.1, 0.13, 0.7),
			1.5, 0, Color.BLACK, Color(0, 0, 0, 0), 5.0)
		clock(Vector2(size.x * 0.1, c.y), 34.0, CREAM, Color(0.15, 0.2, 0.25), GOLD)
		teacup(Vector2(size.x * 0.9, c.y + 8), 46.0, CREAM, GOLD)

	func _paint_corner_90_hanging() -> void:
		var navy := Color(0.13, 0.25, 0.32)
		board(navy, Rect2(), 0.05)
		arched_frame(navy, 22.0, 7.0)
		var c := Vector2(size.x / 2.0, size.y * 0.55)
		# Teekanne: runder Bauch, Deckel mit Knauf, Tülle, Henkel, Goldband
		draw_arc(c + Vector2(-98, -4), 42, PI * 0.45, PI * 1.55, 24, CREAM, 16.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(70, 10), c + Vector2(138, -62), c + Vector2(150, -56), c + Vector2(96, 40)]), CREAM)
		ellipse(c, Vector2(100, 84), CREAM)
		ellipse(c + Vector2(-20, -22), Vector2(40, 26), Color(1, 1, 1, 0.35), -0.4)
		ellipse(c + Vector2(0, -82), Vector2(58, 16), CREAM.darkened(0.06))
		draw_circle(c + Vector2(0, -100), 14.0, GOLD)
		draw_arc(c, 82, PI * 0.15, PI * 0.85, 30, GOLD, 6.0, true)
		draw_line(c + Vector2(-96, -10), c + Vector2(96, -10), Color(GOLD, 0.9), 5.0, true)
		for k in 3:
			var pts := PackedVector2Array()
			for j in 14:
				var t := j / 13.0
				pts.append(c + Vector2(150 + sin(t * 6.0 + k) * 10.0 + k * 14.0 - 14.0, -72 - t * 70.0))
			draw_polyline(pts, Color(CREAM, 0.5), 5.0, true)
		lettering(F_CORMORANT_IT, "Five O'Clock", Vector2(size.x / 2.0, size.y * 0.88), 46, GOLD, Color(0.05, 0.1, 0.13), 2.5, 0,
			Color.BLACK, Color(GOLD_LIGHT, 0.7))

	# --- Bäckerei (Name vorläufig, BAKERY_NAME) ---

	func _paint_bakery_shop_fascia() -> void:
		var cream := Color(0.94, 0.88, 0.74)
		var cocoa := Color(0.36, 0.2, 0.13)
		board(cream, Rect2(), 0.04)
		frame_line(12.0, 5.0, cocoa)
		frame_line(24.0, 1.5, Color(cocoa, 0.6))
		var c := size / 2.0
		var big := fit(F_LOBSTER, BAKERY_NAME, size.x * 0.42, size.y * 0.66)
		var w := lettering(F_LOBSTER, BAKERY_NAME, c + Vector2(-60, -2), big, cocoa, Color(0.75, 0.55, 0.32, 0.8), 4.0, 0, Color.BLACK,
			Color(0.6, 0.38, 0.24, 0.5))
		var caps := int(size.y * 0.24)
		lettering(F_FRAUNCES_IT, "Bakery", Vector2(c.x - 60 + w / 2.0 + 120, c.y + 14), caps, Color(0.72, 0.46, 0.2),
			Color(0.75, 0.55, 0.32, 0.6), 2.0)
		for side: float in [-1.0, 1.0]:
			var base := Vector2(c.x + side * size.x * 0.4, c.y + 70)
			for k in 5:
				wheat(base, Vector2(side * (k - 2) * 0.22, -1.0), size.y * 0.62, Color(0.86, 0.64, 0.3).darkened(k * 0.03))
			draw_line(base + Vector2(-26, -40), base + Vector2(26, -40), Color(0.72, 0.4, 0.4), 7.0, true)
