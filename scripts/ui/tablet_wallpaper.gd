class_name TabletWallpaper
extends Control
## Ruhiger, gemütlicher Hintergrund für den Startbildschirm des Theken-Tablets: ein warmer
## Farbverlauf mit weichen Lichtkreisen und einer angedeuteten Bücherreihe am unteren Rand.
## Austauschbar: statt dessen einfach ein TextureRect mit eigenem Bild verwenden.

const TOP_COLOR := Color(0.29, 0.2, 0.14)
const BOTTOM_COLOR := Color(0.15, 0.1, 0.08)

static var _glow: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	# Farbverlauf von oben nach unten (in Streifen)
	var steps := 24
	for i in steps:
		var t := float(i) / (steps - 1)
		var y0 := size.y * i / steps
		draw_rect(Rect2(0.0, y0, size.x, size.y / steps + 1.0), TOP_COLOR.lerp(BOTTOM_COLOR, t))
	# Weiche Lichtkreise wie Lampenschein (stufenloser Verlauf von innen nach außen)
	for glow in [[Vector2(0.18, 0.22), 0.36, 0.09], [Vector2(0.82, 0.35), 0.3, 0.07], [Vector2(0.55, 0.8), 0.45, 0.05]]:
		var center: Vector2 = glow[0] * size
		var radius: float = glow[1] * size.y
		draw_texture_rect(_glow_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			false, Color(1.0, 1.0, 1.0, glow[2] / 0.1))
	# Angedeutete Bücherreihe unten
	var x := 0.0
	var seed := 7
	while x < size.x:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var width := 10.0 + (seed % 9)
		var height := 34.0 + (seed % 23)
		var tone := 0.05 + (seed % 5) * 0.012
		draw_rect(Rect2(x, size.y - height, width - 2.0, height), Color(1.0, 0.85, 0.6, tone))
		x += width


## Ein runder, weicher Lichtfleck (innen warm, nach außen durchsichtig) – einmal erzeugt.
static func _glow_texture() -> GradientTexture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.82, 0.55, 0.1))
		gradient.set_color(1, Color(1.0, 0.82, 0.55, 0.0))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	return _glow
