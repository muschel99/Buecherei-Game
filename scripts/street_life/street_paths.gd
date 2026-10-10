class_name StreetPaths
extends RefCounted
## Die Wege für das Leben auf der Straße (seit Etappe 5a), berechnet aus StreetLayout.
##
## Grundlage ist die Mittellinie der ganzen Straße als ein StreetRoute: vom versteckten Ende
## am geraden Straßenende (hinter der runden Kurve) über das gerade Mittelstück bis zum
## versteckten Ende hinter dem Torhaus. s wächst dabei immer in Richtung des abbiegenden Endes;
## lat > 0 liegt auf der Bücherei-Seite (wie StreetLayout.end_offset). Passanten, Fahrräder und
## Autos folgen alle dieser einen Linie, nur mit verschiedenen erlaubten Streifen:
## - Gehweg auf der Bücherei-Seite (side = 1) bzw. gegenüber (side = -1),
## - Fahrbahn (Fahrzeuge; Linksverkehr wie in England: lane_offset()).
## Dazu kommen die Wege in die Gassen (alley_route) und die Orte zum Erscheinen und
## Verschwinden (Gruppe Street.TRAFFIC_GROUP, siehe StreetLife).

## Abstand, den ein Passant (Mitte) mindestens zum Bordstein und zu Hauswänden hält.
const CURB_CLEARANCE := 0.3
const WALL_CLEARANCE := 0.4
## Innen in einer engen Kurve stehen die Häuser in geraden Stücken vor dem Kreisbogen
## (und die Ecke des Eckhauses ragt etwas heraus): dort mehr Abstand halten.
const INNER_CURVE_CLEARANCE := 0.8
## Unter dem Torbogen ist der Gehweg gegenüber sehr schmal: Passanten dürfen dort bis
## so weit auf den Rand der Fahrbahn ausweichen (lat-Betrag).
const PASSAGE_ROAD_EDGE := 1.9
## So viele Meter vor und hinter dem Torbogen gehen Passanten schon so wie unter dem Bogen
## (Abschnitte "before_passage", "after_passage") – so kommen sie nie an die Pfeiler.
const PASSAGE_LEAD := 2.5

static var _centerline: StreetRoute


## Die Mittellinie der ganzen Straße (einmal berechnet). Erlaubter Streifen: ganze Breite.
static func centerline() -> StreetRoute:
	if _centerline:
		return _centerline
	var route := StreetRoute.new()
	var east := StreetLayout.end_path(1)
	var west := StreetLayout.end_path(-1)
	# Ostende rückwärts (vom versteckten Ende zur Mitte), dann das Westende vorwärts
	for i in range(east.size() - 1, -1, -1):
		var p: Dictionary = east[i]
		route.add_point(p.pos, _library_normal(p, 1), -INF, INF, _part_name(p, i, 1))
	for i in west.size():
		var p: Dictionary = west[i]
		route.add_point(p.pos, _library_normal(p, -1), -INF, INF, _part_name(p, i, -1))
	_centerline = route.with_band(func(_part: String) -> Vector2: return Vector2(-20.0, 20.0))
	return _centerline


## Abschnitt eines Punkts; dicht vor und hinter dem Torbogen ein eigener Übergang.
static func _part_name(point: Dictionary, index: int, side: int) -> String:
	if index == 0:
		return "middle"
	var part: String = point.part
	if StreetLayout.is_straight(side):
		return part
	var start := StreetLayout.end_part_start(side, "passage")
	var finish := start + StreetLayout.gate_depth()
	var s: float = point.s
	if part != "passage" and s > start - PASSAGE_LEAD and s <= start + 0.001:
		return "before_passage"
	if part != "passage" and s >= finish - 0.001 and s < finish + PASSAGE_LEAD:
		return "after_passage"
	return part


## Nach Änderungen an GameConfig neu berechnen (z. B. im Prüfwerkzeug).
static func reset() -> void:
	_centerline = null


## Richtung zur Bücherei-Seite an einem Punkt von StreetLayout.end_path(side).
static func _library_normal(point: Dictionary, side: int) -> Vector2:
	var dir: Vector2 = point.dir
	return Vector2(-dir.y, dir.x) * float(side)


## Mittellinie mit dem Streifen eines Gehwegs: side = 1 Bücherei-Seite, -1 gegenüber.
static func sidewalk_route(side: int) -> StreetRoute:
	return centerline().with_band(func(part: String) -> Vector4: return sidewalk_band(part, side))


## Streifen für Fahrzeuge: die ganze Fahrbahn (mit etwas Abstand zum Bordstein).
static func road_route() -> StreetRoute:
	var half := GameConfig.street_width / 2.0
	return centerline().with_band(func(_part: String) -> Vector2: return Vector2(-half, half))


## Streifen zum Überqueren: beide Gehwege und die Fahrbahn dazwischen.
static func crossing_route() -> StreetRoute:
	return centerline().with_band(func(part: String) -> Vector2:
		return Vector2(sidewalk_band(part, -1).x, sidewalk_band(part, 1).y))


## Erlaubter Bereich (lat von – bis) auf einem Gehweg in einem Abschnitt der Straße, als
## Vector4(low, high, bequem low, bequem high).
static func sidewalk_band(part: String, side: int) -> Vector4:
	var half := GameConfig.street_width / 2.0
	var inner := half + Street.CURB_TOP + CURB_CLEARANCE
	var facade := _facade_offset(part, side)
	var clearance := WALL_CLEARANCE
	# Innen in der Kurve: am geraden Ende die Bücherei-Seite, am abbiegenden Ende gegenüber
	if (part == "curve" and side > 0) or (part == "bend" and side < 0):
		clearance = INNER_CURVE_CLEARANCE
	var outer := facade - clearance
	var comfort := Vector2(inner, outer)
	if part in ["passage", "before_passage", "after_passage"]:
		# Unter dem Bogen ist der Gehweg schmal: bequem dicht an der Wand, zum Ausweichen darf
		# man auf den Rand der Fahrbahn. Kurz davor und dahinter schon genauso (dort ist mehr
		# Platz zur Hauswand, aber man soll nicht in die Pfeiler laufen).
		var wall := _facade_offset("passage", side) - 0.27
		comfort = Vector2(minf(inner, wall - 0.05), wall)
		outer = wall
		inner = PASSAGE_ROAD_EDGE
	if side > 0:
		return Vector4(inner, outer, comfort.x, comfort.y)
	return Vector4(-outer, -inner, -comfort.y, -comfort.x)


## Abstand der Hausfronten (oder Wände der Durchfahrt) von der Mittellinie.
static func _facade_offset(part: String, side: int) -> float:
	match part:
		"passage":
			return StreetLayout.gate_passage_width() / 2.0 + side * StreetLayout.gate_center_offset()
		"behind", "behind_end", "after_passage":
			return StreetLayout.gate_facade_offset()
	return StreetLayout.library_facade_offset() if side > 0 else StreetLayout.opposite_facade_offset()


## Fahrspur (lat) für eine Fahrtrichtung: direction = 1 (s wächst, zum Torhaus hin) fährt im
## Linksverkehr auf der Bücherei-Seite, -1 gegenüber.
static func lane_offset(direction: int, offset: float) -> float:
	return offset * float(direction)


## s der Stelle auf der Mittellinie, die x auf dem geraden Mittelstück entspricht.
static func s_at_x(x: float) -> float:
	var route := centerline()
	var middle := route.project(Vector2(x, StreetLayout.road_center_z()))
	return middle.x


## Bereich (s von – bis), in dem Passanten über die Straße gehen dürfen: das gerade Mittelstück
## (dort sieht man sie), mit etwas Abstand zu Grenze und Kurve.
static func crossing_range() -> Vector2:
	var a := s_at_x(StreetLayout.straight_bound_x() - StreetLayout.straight_side() * 4.0)
	var b := s_at_x(StreetLayout.end_start_x(StreetLayout.turning_side()) - StreetLayout.turning_side() * 2.0)
	return Vector2(minf(a, b), maxf(a, b))


## Vor der Ladentür, unten an der Treppe (für den nächsten Schritt: Besucher gehen hinein).
static func library_entrance() -> Vector2:
	var door := StreetLayout.door_center()
	var out := StreetLayout.door_outward()
	var reach := GameConfig.entrance_podium_depth + GameConfig.entrance_step_count * GameConfig.entrance_step_depth + 0.5
	return Vector2(door.x + out.x * reach, door.z + out.z * reach)


## Weg aus einer Gasse bis auf den Gehweg (vom Tor am Ende bis zur Einmündung). "gate": Punkt
## vor dem Tor, "mouth": Einmündung auf Gehweg/Platz, "join": Punkt auf dem Gehweg, half: halbe
## erlaubte Breite.
static func alley_route(points: PackedVector2Array, half: float) -> StreetRoute:
	return StreetRoute.from_points(points, half)


## Die Gasse neben der Bücherei: vom Tor am Ende bis auf den Platz davor. Die Mitte liegt
## etwas von der Bücherei weg, damit man mit Abstand an der Eingangstreppe vorbeikommt.
static func library_alley_points() -> PackedVector2Array:
	var x := (StreetLayout.HOUSE_LEFT + StreetLayout.alley_far_x()) / 2.0 - 0.25
	return PackedVector2Array([
		Vector2(x, StreetLayout.alley_end_z() - 0.6),
		Vector2(x, StreetLayout.recess_z() + 0.4),
		Vector2(x - 0.4, StreetLayout.recess_z() - 1.4),
	])


static func library_alley_half_width() -> float:
	return GameConfig.alley_width / 2.0 - 0.45


## Die kleine Gasse gegenüber: vom Tor bis zur Einmündung auf den Gehweg.
static func opposite_alley_points() -> PackedVector2Array:
	var span := StreetLayout.opposite_alley()
	if span == Vector2.ZERO:
		return PackedVector2Array()
	var x := (span.x + span.y) / 2.0
	return PackedVector2Array([
		Vector2(x, StreetLayout.opposite_alley_end_z() + 0.6),
		Vector2(x, StreetLayout.opposite_front_z() + 0.4),
	])


static func opposite_alley_half_width() -> float:
	return maxf(0.05, GameConfig.opposite_alley_width / 2.0 - 0.4)
