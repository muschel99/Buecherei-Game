class_name SoftShapes
extends RefCounted
## Weiche, leicht unregelmäßige Formen für die Oberfläche (seit Testrunde 7b, fürs Notizbuch-Pausenmenü – „weich, süß,
## gemütlich“): abgerundete Rechtecke mit handgezeichnet welligem Rand, weiche Schatten, gestrichelte Nähte, Blümchen,
## Sternchen und Herzchen. Alles statisch: SoftShapes.rounded(…), SoftShapes.flower(self, …) in _draw().


## Umriss eines abgerundeten Rechtecks. radii = Radien der Ecken (oben links, oben rechts, unten rechts, unten links);
## wobble = so viele Bildpunkte wellt sich der Rand (gleiches seed = gleiche Wellen); step = Abstand der Punkte.
static func rounded(rect: Rect2, radii: Vector4, wobble: float = 0.0, seed: int = 0, step: float = 10.0) -> PackedVector2Array:
	var corners := [
		[Vector2(rect.position.x + radii.x, rect.position.y + radii.x), radii.x, PI, 1.5 * PI],
		[Vector2(rect.end.x - radii.y, rect.position.y + radii.y), radii.y, 1.5 * PI, TAU],
		[Vector2(rect.end.x - radii.z, rect.end.y - radii.z), radii.z, 0.0, 0.5 * PI],
		[Vector2(rect.position.x + radii.w, rect.end.y - radii.w), radii.w, 0.5 * PI, PI]]
	var pts := PackedVector2Array()
	for corner: Array in corners:
		var r: float = corner[1]
		if r < 0.5:
			pts.append(corner[0])
			continue
		var n := maxi(2, int(r / 3.0))
		for i in n + 1:
			var a: float = lerpf(corner[2], corner[3], float(i) / n)
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * r)
	# gerade Kanten unterteilen (sonst wellt sich nichts)
	var dense := PackedVector2Array()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if not dense.is_empty() and dense[dense.size() - 1].distance_to(a) < 0.01:
			continue
		dense.append(a)
		var d := a.distance_to(b)
		if d > step:
			var k := int(d / step)
			for j in range(1, k + 1):
				dense.append(a.lerp(b, float(j) / (k + 1)))
	if wobble <= 0.0:
		return dense
	var out := PackedVector2Array()
	var length := 0.0
	var phase := float(seed) * 1.37
	for i in dense.size():
		if i > 0:
			length += dense[i].distance_to(dense[i - 1])
		var tangent := (dense[(i + 1) % dense.size()] - dense[(i - 1 + dense.size()) % dense.size()]).normalized()
		var normal := Vector2(tangent.y, -tangent.x)
		var w := sin(length * 0.021 + phase) * 0.6 + sin(length * 0.057 + phase * 2.3) * 0.4
		out.append(dense[i] + normal * w * wobble)
	return out


## Gleiche Radien an allen Ecken.
static func rounded_all(rect: Rect2, radius: float, wobble: float = 0.0, seed: int = 0) -> PackedVector2Array:
	return rounded(rect, Vector4.ONE * radius, wobble, seed)


## Geschlossene Linie (für draw_polyline).
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


static func moved(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, offset) * points


## Weicher Schatten unter einer Form: mehrere wachsende, sehr blasse Lagen.
static func shadow(ci: CanvasItem, points: PackedVector2Array, offset: Vector2, color: Color = Color(0.25, 0.15, 0.08, 0.07),
		layers: int = 4, spread: float = 3.0) -> void:
	for k in layers:
		var grown := Geometry2D.offset_polygon(points, spread * k)
		if grown.is_empty():
			continue
		ci.draw_colored_polygon(moved(grown[0], offset), color)


## Gestrichelte Naht entlang einer geschlossenen Linie.
static func dashed(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float = 2.0, dash: float = 9.0,
		gap: float = 6.0) -> void:
	var line := closed(points)
	var drawing := true
	var left := dash
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var d := a.distance_to(b)
		var pos := 0.0
		while pos < d:
			var piece := minf(left, d - pos)
			if drawing:
				ci.draw_line(a.lerp(b, pos / d), a.lerp(b, (pos + piece) / d), color, width, true)
			pos += piece
			left -= piece
			if left <= 0.001:
				drawing = not drawing
				left = dash if drawing else gap


## Wellige Linie (wie mit dem Füller gezogen) von a nach b.
static func wavy_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.5, amplitude: float = 1.2,
		seed: int = 0) -> void:
	var pts := PackedVector2Array()
	var n := maxi(4, int(a.distance_to(b) / 14.0))
	var normal := (b - a).normalized().orthogonal()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + normal * sin(t * 11.0 + seed * 0.7) * amplitude)
	ci.draw_polyline(pts, color, width, true)


## Blümchen: runde Blütenblätter um einen kleinen Kern.
static func flower(ci: CanvasItem, center: Vector2, radius: float, petal: Color, heart: Color, petals: int = 5,
		turn: float = 0.0) -> void:
	for i in petals:
		var a := turn + TAU * i / petals
		ci.draw_circle(center + Vector2(cos(a), sin(a)) * radius * 0.6, radius * 0.47, petal)
	ci.draw_circle(center, radius * 0.34, heart)


## Kleines Blatt (Linse) von base in Richtung direction.
static func leaf(ci: CanvasItem, base: Vector2, direction: Vector2, length: float, color: Color) -> void:
	var d := direction.normalized()
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(base + d * length * t + n * sin(t * PI) * length * 0.32)
	for i in range(7, 0, -1):
		var t := float(i) / 8.0
		pts.append(base + d * length * t - n * sin(t * PI) * length * 0.32)
	ci.draw_colored_polygon(pts, color)


## Sternchen mit runden Spitzen (fünf Zacken).
static func star(ci: CanvasItem, center: Vector2, radius: float, color: Color, turn: float = -PI / 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := turn + TAU * i / 10.0
		pts.append(center + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * 0.5))
	ci.draw_colored_polygon(pts, color)
	for i in 5:
		var a := turn + TAU * i / 5.0
		ci.draw_circle(center + Vector2(cos(a), sin(a)) * radius * 0.9, radius * 0.16, color)


## Herzchen.
static func heart(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var r := radius * 0.5
	ci.draw_circle(center + Vector2(-r * 0.95, -r * 0.3), r, color)
	ci.draw_circle(center + Vector2(r * 0.95, -r * 0.3), r, color)
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 1.9, -r * 0.05), center + Vector2(r * 1.9, -r * 0.05),
		center + Vector2(0.0, r * 2.0)]), color)


## Runder Punkt als Bild (Schieberegler, Auswahlpunkt in Listen): weicher Rand, innen heller.
static func dot_texture(size: int, color: Color, ring: Color = Color(0, 0, 0, 0)) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 0.86, 0.92])
	var edge := ring if ring.a > 0.0 else color
	gradient.colors = PackedColorArray([color.lightened(0.18), color, edge, edge, Color(edge, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size
	texture.height = size
	return texture
