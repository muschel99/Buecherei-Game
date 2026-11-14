class_name GenreSymbols
extends RefCounted
## Erkennungszeichen der Genres (seit Etappe 8, Wunsch der Entwicklerin: „damit man direkt sieht, was es für ein Buch ist“).
## Kleine gemalte Bildchen: unten auf jedem Buchrücken, auf dem Cover, auf dem Schild der Bücherkiste und später in der
## Gedankenblase der Gäste. Welches Zeichen ein Genre trägt, steht in seinem Datenblatt (GenreData.symbol, einer der NAMES).
## draw(ci, name, center, size, color) zeichnet es in ein CanvasItem; size = ungefähre Breite.

const NAMES := ["heart", "magnifier", "dragon", "rocket", "feather", "note_flower", "teddy", "speech", "cake", "leaf",
	"suitcase", "brush", "hourglass", "owl", "teacup", "bulb"]


## Zeichnet das Zeichen name. color = Hauptfarbe, light = helle Zweitfarbe (Augen, Fenster, Glanz).
static func draw(ci: CanvasItem, symbol_name: String, center: Vector2, size: float, color: Color,
		light: Color = Color(1.0, 0.97, 0.9)) -> void:
	var s := size / 2.0  # halbe Größe
	var w := maxf(1.0, size * 0.09)  # Strichstärke
	match symbol_name:
		"heart":
			SoftShapes.heart(ci, center + Vector2(0, -s * 0.15), s * 0.95, color)
		"magnifier":
			ci.draw_arc(center + Vector2(-s * 0.15, -s * 0.15), s * 0.5, 0.0, TAU, 20, color, w * 1.4, true)
			ci.draw_circle(center + Vector2(-s * 0.15, -s * 0.15), s * 0.38, Color(light, 0.6))
			ci.draw_line(center + Vector2(s * 0.22, s * 0.22), center + Vector2(s * 0.8, s * 0.8), color, w * 2.2, true)
		"dragon":
			# kleiner, runder Drache von der Seite: Körper, Kopf, Flügel, Schwanz
			ci.draw_circle(center + Vector2(-s * 0.1, s * 0.2), s * 0.45, color)
			ci.draw_circle(center + Vector2(s * 0.45, -s * 0.25), s * 0.3, color)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.2, -s * 0.05), center + Vector2(-s * 0.55, -s * 0.85),
				center + Vector2(-s * 0.05, -s * 0.55), center + Vector2(s * 0.2, -s * 0.8), center + Vector2(s * 0.15, -s * 0.05)]), color)
			ci.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.5, s * 0.35), center + Vector2(-s * 0.85, s * 0.5),
				center + Vector2(-s * 0.95, s * 0.2)]), color, w * 1.6, true)
			ci.draw_circle(center + Vector2(s * 0.52, -s * 0.32), s * 0.08, light)
		"rocket":
			var body := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				body.append(center + Vector2(sin(t * PI) * s * 0.38 * (1.0 - 0.3 * t), lerpf(s * 0.55, -s * 0.95, t)))
			for i in range(11, 0, -1):
				var t := float(i) / 12.0
				body.append(center + Vector2(-sin(t * PI) * s * 0.38 * (1.0 - 0.3 * t), lerpf(s * 0.55, -s * 0.95, t)))
			for side: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([center + Vector2(side * s * 0.25, s * 0.15), center + Vector2(side * s * 0.65, s * 0.7),
					center + Vector2(side * s * 0.2, s * 0.55)]), color.darkened(0.15))
			ci.draw_colored_polygon(body, color)
			ci.draw_circle(center + Vector2(0, -s * 0.25), s * 0.17, light)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.15, s * 0.6), center + Vector2(s * 0.15, s * 0.6),
				center + Vector2(0, s * 0.95)]), Color(0.98, 0.7, 0.4))
		"feather":
			SoftShapes.leaf(ci, center + Vector2(s * 0.45, s * 0.75), Vector2(-0.55, -1.0), size * 0.95, color)
			ci.draw_line(center + Vector2(s * 0.55, s * 0.95), center + Vector2(-s * 0.35, -s * 0.75), light, w, true)
		"note_flower":
			ci.draw_circle(center + Vector2(-s * 0.25, s * 0.5), s * 0.28, color)
			ci.draw_line(center + Vector2(-s * 0.0, s * 0.5), center + Vector2(-s * 0.0, -s * 0.8), color, w * 1.3, true)
			ci.draw_polyline(PackedVector2Array([center + Vector2(0, -s * 0.8), center + Vector2(s * 0.35, -s * 0.55),
				center + Vector2(s * 0.3, -s * 0.25)]), color, w * 1.3, true)
			SoftShapes.flower(ci, center + Vector2(s * 0.55, s * 0.45), s * 0.42, Color(0.96, 0.62, 0.66), Color(0.99, 0.86, 0.5))
		"teddy":
			for side: float in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(side * s * 0.55, -s * 0.55), s * 0.25, color)
			ci.draw_circle(center, s * 0.68, color)
			ci.draw_circle(center + Vector2(0, s * 0.22), s * 0.27, light)
			ci.draw_circle(center + Vector2(0, s * 0.12), s * 0.08, color.darkened(0.4))
			for side: float in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(side * s * 0.25, -s * 0.15), s * 0.07, color.darkened(0.5))
		"speech":
			var bubble := SoftShapes.rounded_all(Rect2(center + Vector2(-s * 0.85, -s * 0.75), Vector2(s * 1.7, s * 1.1)), s * 0.35)
			ci.draw_colored_polygon(bubble, color)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.35, s * 0.3), center + Vector2(s * 0.05, s * 0.3),
				center + Vector2(-s * 0.45, s * 0.85)]), color)
			for i in 3:
				ci.draw_circle(center + Vector2((i - 1) * s * 0.45, -s * 0.2), s * 0.1, light)
		"cake":
			ci.draw_colored_polygon(SoftShapes.rounded_all(Rect2(center + Vector2(-s * 0.8, 0), Vector2(s * 1.6, s * 0.7)), s * 0.12), color)
			ci.draw_colored_polygon(SoftShapes.rounded_all(Rect2(center + Vector2(-s * 0.6, -s * 0.5), Vector2(s * 1.2, s * 0.55)), s * 0.12),
				color.lightened(0.15))
			ci.draw_line(center + Vector2(-s * 0.8, s * 0.05), center + Vector2(s * 0.8, s * 0.05), light, w * 1.4, true)
			ci.draw_circle(center + Vector2(0, -s * 0.68), s * 0.18, Color(0.88, 0.3, 0.35))
		"leaf":
			SoftShapes.leaf(ci, center + Vector2(-s * 0.7, s * 0.7), Vector2(1.0, -1.0), size * 0.98, color)
			ci.draw_line(center + Vector2(-s * 0.7, s * 0.7), center + Vector2(s * 0.45, -s * 0.45), light, w, true)
		"suitcase":
			ci.draw_arc(center + Vector2(0, -s * 0.45), s * 0.28, PI, TAU, 10, color, w * 1.5, true)
			ci.draw_colored_polygon(SoftShapes.rounded_all(Rect2(center + Vector2(-s * 0.85, -s * 0.45), Vector2(s * 1.7, s * 1.2)), s * 0.2), color)
			for side: float in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(side * s * 0.45, -s * 0.45), center + Vector2(side * s * 0.45, s * 0.75), light, w * 1.2, true)
		"brush":
			ci.draw_line(center + Vector2(s * 0.8, -s * 0.8), center + Vector2(-s * 0.05, s * 0.05), color.darkened(0.2), w * 1.8, true)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -s * 0.05), center + Vector2(s * 0.1, s * 0.1),
				center + Vector2(-s * 0.55, s * 0.9), center + Vector2(-s * 0.85, s * 0.6)]), color)
			ci.draw_circle(center + Vector2(-s * 0.72, s * 0.78), s * 0.17, color)
		"hourglass":
			ci.draw_line(center + Vector2(-s * 0.65, -s * 0.85), center + Vector2(s * 0.65, -s * 0.85), color.darkened(0.2), w * 1.8, true)
			ci.draw_line(center + Vector2(-s * 0.65, s * 0.85), center + Vector2(s * 0.65, s * 0.85), color.darkened(0.2), w * 1.8, true)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.5, -s * 0.75), center + Vector2(s * 0.5, -s * 0.75),
				center + Vector2(s * 0.06, 0), center + Vector2(s * 0.5, s * 0.75), center + Vector2(-s * 0.5, s * 0.75),
				center + Vector2(-s * 0.06, 0)]), color)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.3, s * 0.72), center + Vector2(s * 0.3, s * 0.72),
				center + Vector2(0, s * 0.35)]), light)
		"owl":
			for side: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([center + Vector2(side * s * 0.35, -s * 0.55), center + Vector2(side * s * 0.65, -s * 0.95),
					center + Vector2(side * s * 0.7, -s * 0.4)]), color)
			ci.draw_circle(center + Vector2(0, s * 0.05), s * 0.75, color)
			for side: float in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(side * s * 0.3, -s * 0.2), s * 0.26, light)
				ci.draw_circle(center + Vector2(side * s * 0.3, -s * 0.2), s * 0.1, color.darkened(0.55))
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.1, s * 0.05), center + Vector2(s * 0.1, s * 0.05),
				center + Vector2(0, s * 0.28)]), Color(0.95, 0.72, 0.35))
		"teacup":
			var cup := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				cup.append(center + Vector2(lerpf(-s * 0.7, s * 0.7, t), -s * 0.15 + sin(t * PI) * s * 0.75))
			ci.draw_colored_polygon(cup, color)
			ci.draw_arc(center + Vector2(s * 0.72, s * 0.15), s * 0.25, -PI / 2.0, PI / 2.0, 10, color, w * 1.5, true)
			ci.draw_line(center + Vector2(-s * 0.9, s * 0.72), center + Vector2(s * 0.9, s * 0.72), color.darkened(0.15), w * 1.6, true)
			for i in 2:
				var x := (i - 0.5) * s * 0.5
				ci.draw_polyline(PackedVector2Array([center + Vector2(x, -s * 0.3), center + Vector2(x + s * 0.12, -s * 0.55),
					center + Vector2(x, -s * 0.8)]), Color(color, 0.6), w, true)
		"bulb":
			ci.draw_circle(center + Vector2(0, -s * 0.2), s * 0.6, color)
			ci.draw_colored_polygon(SoftShapes.rounded_all(Rect2(center + Vector2(-s * 0.28, s * 0.35), Vector2(s * 0.56, s * 0.5)), s * 0.1),
				color.darkened(0.3))
			ci.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.2, -s * 0.1), center + Vector2(-s * 0.08, -s * 0.35),
				center + Vector2(s * 0.08, -s * 0.1), center + Vector2(s * 0.2, -s * 0.35)]), light, w, true)
		_:
			ci.draw_circle(center, s * 0.5, color)
