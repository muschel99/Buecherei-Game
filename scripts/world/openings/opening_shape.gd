class_name OpeningShape
extends RefCounted
## Umrisse von Fenstern und Türen (seit Etappe 6c): eine gemeinsame Form für Wandausschnitt (Fassade
## außen, Wandloch des Ladens, Aussparung der Innenfarbe), Rahmen, Glas, Sprossen und Gardinen – so
## passen alle Teile bei jeder Fenster- und Türart genau zusammen.
##
## Ein Umriss ist ein Vieleck (PackedVector2Array, gegen den Uhrzeigersinn) in Wand-Koordinaten:
## x entlang der Wand (Mitte der Öffnung = 0), y nach oben (Unterkante = 0).

enum Kind { RECT, ARCH, ROUND }

## Wie fein Bögen und Kreise unterteilt werden (Punkte je Halbkreis)
const ARC_STEPS := 20


## Umriss einer Öffnung, w breit und h hoch. ARCH: oben ein Bogen mit dem Stich rise (rise = w/2 →
## Halbkreis), ROUND: Kreis bzw. Ellipse in w x h.
static func outline(kind: Kind, w: float, h: float, rise: float = 0.0) -> PackedVector2Array:
	var hw := w / 2.0
	var points := PackedVector2Array()
	match kind:
		Kind.ROUND:
			var steps := ARC_STEPS * 2
			for i in steps:
				var a := TAU * i / steps - PI / 2.0
				points.append(Vector2(cos(a) * hw, h / 2.0 + sin(a) * h / 2.0))
		Kind.ARCH:
			var r := clampf(rise, 0.01, hw)
			points.append(Vector2(-hw, 0.0))
			points.append(Vector2(hw, 0.0))
			points.append_array(arc(hw, h - r, r, true))
		_:
			points = PackedVector2Array([Vector2(-hw, 0.0), Vector2(hw, 0.0), Vector2(hw, h), Vector2(-hw, h)])
	return points


## Bogen von rechts (hw, spring) über den Scheitel (0, spring + rise) nach links (-hw, spring).
## include_ends = auch die beiden Kämpferpunkte.
static func arc(hw: float, spring: float, rise: float, include_ends: bool = true) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Kreis durch die Kämpfer und den Scheitel
	var radius := (rise * rise + hw * hw) / (2.0 * rise)
	var center := Vector2(0.0, spring + rise - radius)
	var a0 := atan2(spring - center.y, hw)
	var a1 := PI - a0
	var steps := maxi(4, roundi(ARC_STEPS * (a1 - a0) / PI))
	for i in steps + 1:
		if not include_ends and (i == 0 or i == steps):
			continue
		var a := lerpf(a0, a1, float(i) / steps)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


## Umriss nach innen (delta < 0) oder außen (delta > 0) verschoben (runde Ecken außen, scharfe innen).
static func offset(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	if is_zero_approx(delta):
		return poly
	var join := Geometry2D.JOIN_ROUND if delta > 0.0 else Geometry2D.JOIN_MITER
	var result := Geometry2D.offset_polygon(poly, delta, join)
	var best := PackedVector2Array()
	for candidate: PackedVector2Array in result:
		if not Geometry2D.is_polygon_clockwise(candidate) and candidate.size() > best.size():
			best = candidate
	return best


## Rechteck um einen Umriss.
static func bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## Umriss verschoben/gedreht (z. B. von der Öffnung in die Koordinaten einer Wand).
static func moved(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out


## Breite des Umrisses auf der Höhe y (für Fensterbänke, Gardinenstangen …).
static func width_at(poly: PackedVector2Array, y: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.y - y) * (b.y - y) <= 0.0 and not is_equal_approx(a.y, b.y):
			var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO


## Zerlegt eine Fläche (outer minus holes) in einfache Vielecke ohne Löcher: senkrechte Streifen an den
## Rändern jedes Lochs, dann ausschneiden – so liegt nie ein Loch ganz in einem Stück, und Godots
## Dreiecks-Zerlegung kommt ohne Löcher aus.
static func pieces(outer: PackedVector2Array, holes: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var box := bounds(outer)
	var cuts: Array[float] = [box.position.x, box.end.x]
	for hole: PackedVector2Array in holes:
		var hb := bounds(hole)
		for x in [hb.position.x + 0.0007, hb.end.x - 0.0007]:
			if x > box.position.x and x < box.end.x:
				cuts.append(x)
	cuts.sort()
	for k in cuts.size() - 1:
		var x0 := cuts[k]
		var x1 := cuts[k + 1]
		if x1 - x0 < 0.0002:
			continue
		var strip := PackedVector2Array([Vector2(x0, box.position.y - 1.0), Vector2(x1, box.position.y - 1.0),
			Vector2(x1, box.end.y + 1.0), Vector2(x0, box.end.y + 1.0)])
		var parts: Array = Geometry2D.intersect_polygons(strip, outer)
		for hole: PackedVector2Array in holes:
			var next: Array = []
			for part: PackedVector2Array in parts:
				if Geometry2D.is_polygon_clockwise(part):
					continue
				next.append_array(Geometry2D.clip_polygons(part, hole))
			parts = next
		for part: PackedVector2Array in parts:
			if not Geometry2D.is_polygon_clockwise(part) and part.size() >= 3:
				result.append(part)
	return result
