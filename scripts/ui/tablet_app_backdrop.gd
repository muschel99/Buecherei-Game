class_name TabletAppBackdrop
extends Control
## Der Bildschirm-Hintergrund einer App auf dem Theken-Tablet (seit Etappe 6b): Farbe und ein feines,
## gezeichnetes Muster aus ihrem Stil (TabletAppStyle) – Leinen, Papierfasern, Linien wie im
## Kassenbuch, Karos wie auf Skizzenpapier, Packpapier oder Pünktchen. Keine Bilder, nur Striche.

## Rundung der Ecken (wie der Bildschirm des Tablets).
const RADIUS := 16

var style: TabletAppStyle:
	set(value):
		style = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), style)


## Malt Farbe und Muster eines Stils in das Rechteck (auch für den Bildschirm des Tablet-Rahmens).
static func paint(canvas: CanvasItem, rect: Rect2, style: TabletAppStyle, radius: int = RADIUS) -> void:
	if style == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = style.background
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	canvas.draw_style_box(box, rect)
	var c := style.pattern_color
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var size := rect.size
	var inner := Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12))
	match style.pattern:
		TabletAppStyle.Pattern.LINEN:
			# Feines Gewebe: dichte waagerechte und senkrechte Fäden, hier und da ein dickerer
			var y := inner.position.y
			while y < inner.end.y:
				var w := 1.6 if rnd.randf() < 0.12 else 0.8
				canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(c, c.a * rnd.randf_range(0.6, 1.2)), w)
				y += 4.0
			var x := inner.position.x
			while x < inner.end.x:
				canvas.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(c, c.a * rnd.randf_range(0.4, 0.9)), 0.8)
				x += 4.0
		TabletAppStyle.Pattern.PAPER, TabletAppStyle.Pattern.KRAFT:
			# Kurze Fasern kreuz und quer (Packpapier: mehr und dunkler)
			var count := int(size.x * size.y / (900.0 if style.pattern == TabletAppStyle.Pattern.KRAFT else 2600.0))
			for i in count:
				var p := Vector2(rnd.randf_range(inner.position.x, inner.end.x), rnd.randf_range(inner.position.y, inner.end.y))
				var d := Vector2.from_angle(rnd.randf() * TAU) * rnd.randf_range(3.0, 11.0)
				var shade := c if rnd.randf() < 0.7 else Color(1, 1, 1, c.a * 0.8)
				canvas.draw_line(p, p + d, shade, rnd.randf_range(0.6, 1.4), true)
		TabletAppStyle.Pattern.LINES:
			# Kassenbuch: blaue Linien, links ein roter Rand
			var y := inner.position.y + 46.0
			while y < inner.end.y:
				canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), c, 1.0)
				y += 30.0
			var margin_x := inner.position.x + 54.0
			canvas.draw_line(Vector2(margin_x, inner.position.y), Vector2(margin_x, inner.end.y), Color(0.85, 0.35, 0.35, 0.45), 1.5)
			canvas.draw_line(Vector2(margin_x + 4.0, inner.position.y), Vector2(margin_x + 4.0, inner.end.y), Color(0.85, 0.35, 0.35, 0.3), 1.0)
		TabletAppStyle.Pattern.GRID:
			# Skizzenpapier: feines Karo, jedes fünfte Kästchen kräftiger
			var step := 22.0
			var i := 0
			var x := inner.position.x
			while x < inner.end.x:
				canvas.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(c, c.a * (2.0 if i % 5 == 0 else 1.0)), 1.0)
				x += step
				i += 1
			i = 0
			var y := inner.position.y
			while y < inner.end.y:
				canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(c, c.a * (2.0 if i % 5 == 0 else 1.0)), 1.0)
				y += step
				i += 1
		TabletAppStyle.Pattern.DOTS:
			var y := inner.position.y + 11.0
			var row := 0
			while y < inner.end.y:
				var x := inner.position.x + (11.0 if row % 2 == 0 else 22.0)
				while x < inner.end.x:
					canvas.draw_circle(Vector2(x, y), 1.6, c, true, -1.0, true)
					x += 22.0
				y += 19.0
				row += 1
