class_name StreetRoute
extends RefCounted
## Ein Weg für das Leben auf der Straße (seit Etappe 5a): eine Linie aus Punkten (x, z auf
## Gehweg-Höhe, Koordinaten wie unter "Outside") mit einem erlaubten Streifen links und rechts.
##
## Wer dem Weg folgt, hat eine Lage (s = Meter ab dem Anfang, lat = Abstand zur Seite).
## lat ist positiv in Richtung "normal" (bei der Straße: zur Bücherei-Seite hin, siehe
## StreetPaths). Jeder Punkt hat einen eigenen erlaubten Bereich [low, high] für lat – so bleiben
## Passanten auf dem Gehweg, in der Gasse oder auf der Fahrbahn, auch wenn sie ausweichen.
## Vor dem Anfang und hinter dem Ende geht der Weg geradeaus weiter (so kann jemand noch ein
## Stück weiterlaufen, falls der Ort zum Verschwinden gerade zu sehen ist).

var points := PackedVector2Array()
## Richtung zur positiven Seite (lat > 0) je Punkt.
var normals := PackedVector2Array()
## Meter ab dem Anfang je Punkt.
var lengths := PackedFloat32Array()
## Erlaubter Bereich für lat je Punkt.
var low := PackedFloat32Array()
var high := PackedFloat32Array()
## Bequemer Bereich für lat je Punkt (hier läuft man am liebsten; ausweichen darf man im ganzen
## erlaubten Bereich, z. B. unter dem Torbogen auch auf den Rand der Fahrbahn).
var comfort_low := PackedFloat32Array()
var comfort_high := PackedFloat32Array()
## Name des Abschnitts je Punkt (z. B. "middle", "curve", "passage", "alley").
var parts := PackedStringArray()


## Neuer Weg aus Punkten; die Seite (normal) zeigt links der Laufrichtung, wenn keine angegeben.
static func from_points(list: PackedVector2Array, half_width: float = 0.5) -> StreetRoute:
	var route := StreetRoute.new()
	for i in list.size():
		var dir := route._dir_at(list, i)
		route.add_point(list[i], Vector2(dir.y, -dir.x), -half_width, half_width, "path")
	return route


func add_point(pos: Vector2, normal: Vector2, lat_low: float, lat_high: float, part: String) -> void:
	var s := 0.0
	if not points.is_empty():
		s = lengths[lengths.size() - 1] + points[points.size() - 1].distance_to(pos)
		if s - lengths[lengths.size() - 1] < 0.0005:
			return  # doppelter Punkt
	points.append(pos)
	normals.append(normal.normalized())
	lengths.append(s)
	low.append(lat_low)
	high.append(lat_high)
	comfort_low.append(lat_low)
	comfort_high.append(lat_high)
	parts.append(part)


## Gesamtlänge.
func length() -> float:
	return lengths[lengths.size() - 1] if not lengths.is_empty() else 0.0


## Kopie mit anderem erlaubtem Bereich (z. B. derselbe Straßenverlauf für den Gehweg gegenüber).
## band(part) liefert Vector2(low, high) oder Vector4(low, high, bequem low, bequem high).
func with_band(band: Callable) -> StreetRoute:
	var route := StreetRoute.new()
	route.points = points.duplicate()
	route.normals = normals.duplicate()
	route.lengths = lengths.duplicate()
	route.parts = parts.duplicate()
	for i in points.size():
		var range: Variant = band.call(parts[i])
		var full := Vector4(range.x, range.y, range.x, range.y) if range is Vector2 else range as Vector4
		route.low.append(full.x)
		route.high.append(full.y)
		route.comfort_low.append(full.z)
		route.comfort_high.append(full.w)
	return route


## Index des Abschnitts, in dem s liegt (Punkt i bis i + 1).
func _segment(s: float) -> int:
	var count := points.size()
	if count < 2 or s <= 0.0:
		return 0
	if s >= lengths[count - 1]:
		return count - 2
	# Binäre Suche
	var lo := 0
	var hi := count - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if lengths[mid] <= s:
			lo = mid
		else:
			hi = mid
	return lo


## Punkt auf der Linie bei s (davor und dahinter geradeaus verlängert).
func position_at(s: float) -> Vector2:
	var i := _segment(s)
	var a := points[i]
	var b := points[i + 1]
	var span := lengths[i + 1] - lengths[i]
	return a + (b - a) * ((s - lengths[i]) / span)


## Richtung der Linie bei s (in Richtung wachsender s).
func direction_at(s: float) -> Vector2:
	var i := _segment(s)
	return (points[i + 1] - points[i]).normalized()


## Seitenrichtung (lat > 0) bei s, zwischen den Punkten weich überblendet.
func normal_at(s: float) -> Vector2:
	var i := _segment(s)
	var t := clampf((s - lengths[i]) / (lengths[i + 1] - lengths[i]), 0.0, 1.0)
	return normals[i].lerp(normals[i + 1], t).normalized()


## Punkt neben der Linie: s entlang, lat zur Seite.
func point_at(s: float, lat: float) -> Vector2:
	return position_at(s) + normal_at(s) * lat


## Erlaubter Bereich für lat bei s (Vector2(low, high)), zwischen den Punkten weich überblendet.
func band_at(s: float) -> Vector2:
	var i := _segment(s)
	var t := clampf((s - lengths[i]) / (lengths[i + 1] - lengths[i]), 0.0, 1.0)
	return Vector2(lerpf(low[i], low[i + 1], t), lerpf(high[i], high[i + 1], t))


## Bequemer Bereich für lat bei s.
func comfort_at(s: float) -> Vector2:
	var i := _segment(s)
	var t := clampf((s - lengths[i]) / (lengths[i + 1] - lengths[i]), 0.0, 1.0)
	return Vector2(lerpf(comfort_low[i], comfort_low[i + 1], t), lerpf(comfort_high[i], comfort_high[i + 1], t))


func part_at(s: float) -> String:
	var i := _segment(s)
	var t := (s - lengths[i]) / (lengths[i + 1] - lengths[i])
	return parts[i + 1] if t > 0.5 else parts[i]


## Lage eines Punkts auf dem Weg: Vector2(s, lat). Gesucht wird nur zwischen s_from und s_to
## (schneller, und eindeutig in Kurven).
func project(pos: Vector2, s_from: float = -INF, s_to: float = INF) -> Vector2:
	var count := points.size()
	var first := _segment(maxf(s_from, 0.0))
	var last := _segment(minf(s_to, length()))
	var best := Vector2(0.0, INF)
	var best_dist := INF
	for i in range(first, last + 1):
		var a := points[i]
		var b := points[i + 1]
		var ab := b - a
		var span := ab.length()
		var t := (pos - a).dot(ab) / (span * span)
		# Am ersten und letzten Stück darf die Lage auch davor bzw. dahinter liegen
		if not (i == 0 and t < 0.0) and not (i == count - 2 and t > 1.0):
			t = clampf(t, 0.0, 1.0)
		var foot := a + ab * t
		var dist := pos.distance_squared_to(foot)
		if dist < best_dist:
			best_dist = dist
			var s := lengths[i] + span * t
			best = Vector2(s, (pos - position_at(s)).dot(normal_at(s)))
	return best


func _dir_at(list: PackedVector2Array, i: int) -> Vector2:
	var a := list[maxi(0, i - 1)]
	var b := list[mini(list.size() - 1, i + 1)]
	if i == 0:
		a = list[0]
	return (b - a).normalized()
