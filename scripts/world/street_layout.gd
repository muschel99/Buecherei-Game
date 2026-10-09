class_name StreetLayout
extends RefCounted
## Wo draußen was liegt (seit Etappe 4d) – eine gemeinsame Rechnung für Straße, Gasse,
## Platz, Häuser und Treppe. Alle Maße kommen aus GameConfig; hier steht nur, wie sie
## zusammenpassen. Koordinaten wie in der Hauptszene: Die Bücherei steht im Ursprung,
## ihre Vorderseite zeigt nach -Z (zur Straße), die Gasse liegt bei -X (Seite mit der Schräge).
##
## Von oben gesehen (Straße unten):
##
##     Haus D | Haus C | Gasse | Bücherei | Haus A | Haus B
##     (zurückversetzt)        ⟋ Tür
##     ----- Platz ---------- ⟋
##     ========= Gehweg ===============================
##     ========= Fahrbahn (ein Ende biegt ab, das andere läuft geradeaus weiter) ===
##     (am abbiegenden Ende führt die Seitenstraße durch den Bogen eines Torhauses)
##     ========= Gehweg gegenüber ======================
##           Reihenhäuser gegenüber

## Außenkante der Hauswand der Bücherei (fest in scenes/rooms/ground_floor_room.tscn gebaut).
const HOUSE_LEFT := -3.2
const HOUSE_RIGHT := 3.2
const HOUSE_FRONT := -4.2
const HOUSE_BACK := 4.2
## Innenmaße des Ladens und Wanddicke (für die Schräge)
const INNER_LEFT := -3.0
const INNER_FRONT := -4.0
const WALL := 0.2


## Höhe des Gehwegs (der Ladenboden liegt auf 0).
static func ground_y() -> float:
	return -GameConfig.shop_floor_rise


## Höhe der Fahrbahn.
static func road_y() -> float:
	return ground_y() - GameConfig.curb_height


## Linie x + z = Wert, auf der die Außenseite der schrägen Wand liegt.
static func cut_line() -> float:
	return INNER_LEFT + INNER_FRONT + GameConfig.corner_cut - WALL * sqrt(2.0)


## Wo die schräge Wand auf die Seitenwand an der Gasse trifft (z) – hier beginnt die Gasse,
## und hier liegt die Vorderkante der zurückversetzten Häuser.
static func recess_z() -> float:
	return cut_line() - HOUSE_LEFT


## Wo die schräge Wand auf die Vorderwand trifft (x).
static func diagonal_front_x() -> float:
	return cut_line() - HOUSE_FRONT


## Mitte der schrägen Wand außen (dort sitzt die Tür) und Richtung nach draußen.
static func door_center() -> Vector3:
	return Vector3((HOUSE_LEFT + diagonal_front_x()) / 2.0, 0.0, (recess_z() + HOUSE_FRONT) / 2.0)


## Breite der schrägen Wand außen (von Ecke zu Ecke).
static func diagonal_width() -> float:
	return (HOUSE_LEFT - diagonal_front_x()) * -sqrt(2.0)


static func door_outward() -> Vector3:
	return Vector3(-1.0, 0.0, -1.0).normalized()


## Bordsteinkante vor der Bücherei, Bordstein gegenüber, Hausfronten gegenüber (z).
static func curb_z() -> float:
	return HOUSE_FRONT - GameConfig.sidewalk_width


static func far_curb_z() -> float:
	return curb_z() - GameConfig.street_width


static func opposite_front_z() -> float:
	return far_curb_z() - GameConfig.opposite_sidewalk_width


## Gasse: von der Bücherei-Wand bis zur Hauswand gegenüber (x), und wo sie endet (z).
static func alley_far_x() -> float:
	return HOUSE_LEFT - GameConfig.alley_width


static func alley_end_z() -> float:
	return recess_z() + GameConfig.alley_depth


## Wo die Nachbarhäuser neben der Bücherei enden (x): rechts (+X) bündig, links (-X)
## hinter der Gasse.
static func neighbor_row_end_x() -> float:
	var x := HOUSE_RIGHT
	for id in GameConfig.neighbor_house_types:
		x += HouseTypes.width_of(id)
	return x


static func alley_row_end_x() -> float:
	var x := alley_far_x()
	for id in GameConfig.alley_house_types:
		x -= HouseTypes.width_of(id)
	return x


## Läuft dieses Straßenende geradeaus weiter? side: 1 = Osten (+X), -1 = Westen (-X).
static func is_straight(side: int) -> bool:
	return GameConfig.straight_street_end == ("east" if side > 0 else "west")


## Am geraden Ende: Lage der Grenze quer über die Straße (x) – straight_bound_offset hinter
## dem Ende der festen Nachbarhäuser. Sie reicht von der Hausfront bis zu den Häusern gegenüber.
static func straight_bound_x() -> float:
	if is_straight(1):
		return neighbor_row_end_x() + GameConfig.straight_bound_offset
	return alley_row_end_x() - GameConfig.straight_bound_offset


static func straight_side() -> int:
	return 1 if is_straight(1) else -1


## Ende der Häuserreihe auf der Bücherei-Seite (x): Dort steht quer ein Haus, und die Straße
## biegt davor ab. Am geraden Ende liegt dieser Knick straight_street_length hinter der Grenze.
static func east_end_x() -> float:
	if is_straight(1):
		return straight_bound_x() + GameConfig.straight_street_length
	return neighbor_row_end_x()


static func west_end_x() -> float:
	if is_straight(-1):
		return straight_bound_x() - GameConfig.straight_street_length
	return alley_row_end_x()


## Fahrbahn der Seitenstraßen: von - bis (x). Außen läuft der Gehweg weiter.
static func east_road() -> Vector2:
	var outer := east_end_x() - GameConfig.sidewalk_width
	return Vector2(outer - GameConfig.street_width, outer)


static func west_road() -> Vector2:
	var outer := west_end_x() + GameConfig.sidewalk_width
	return Vector2(outer, outer + GameConfig.street_width)


## Häuserreihe gegenüber: von - bis (x), zwischen den Gehwegen der Seitenstraßen.
static func opposite_row() -> Vector2:
	return Vector2(west_road().y + GameConfig.opposite_sidewalk_width,
		east_road().x - GameConfig.opposite_sidewalk_width)


## Hier endet die Seitenstraße einer Seite (quer stehen Häuser) (z). side: 1 = Osten, -1 = Westen.
static func side_street_end_z(side: int) -> float:
	if is_straight(side):
		return opposite_front_z() - GameConfig.straight_side_street_length
	return opposite_front_z() - GameConfig.side_street_length


## Die tiefere der beiden Seitenstraßen endet hier (z) – für Boden und Kollision.
static func deepest_end_z() -> float:
	return minf(side_street_end_z(1), side_street_end_z(-1))


## --- Abbiegendes Ende mit Torhaus (seit Etappe 4f) ---

## Seite des abbiegenden Endes: 1 = Osten, -1 = Westen.
static func turning_side() -> int:
	return -straight_side()


## Fahrbahn der abbiegenden Seitenstraße (x von – bis) und ihre Mitte.
static func turning_road() -> Vector2:
	return east_road() if turning_side() > 0 else west_road()


static func turning_road_center_x() -> float:
	var road := turning_road()
	return (road.x + road.y) / 2.0


## Vorderseite des Torhauses am Ende der abbiegenden Seitenstraße (z).
static func gatehouse_front_z() -> float:
	return side_street_end_z(turning_side())


## Lichte Breite des Bogens und Tiefe der Durchfahrt (aus der Szene des Torhauses).
static func gate_passage_width() -> float:
	return float(HouseTypes.value_of(GameConfig.gatehouse_type, "passage_width", 6.5))


static func gate_depth() -> float:
	return HouseTypes.depth_of(GameConfig.gatehouse_type)


## In diese Richtung (x) biegt die Straße hinter dem Torhaus ab: zur Stadtmitte hin.
static func gate_turn_sign() -> float:
	return -float(turning_side())


## Mittellinie der Straße ab der Vorderseite des Torhauses: durch den Bogen, ein Stück
## geradeaus, in einer Kurve zur Stadtmitte hin und noch ein Stück weiter. Liste von
## { "pos": Vector2 (x, z), "dir": Vector2 (Fahrtrichtung), "s": Meter ab dem Torhaus }.
static func gate_path(step: float = 0.5) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var pos := Vector2(turning_road_center_x(), gatehouse_front_z())
	var dir := Vector2(0.0, -1.0)
	var radius := GameConfig.gate_curve_radius
	var turn := gate_turn_sign() / radius  # Drehung je Meter in der Kurve
	# Abschnitte: Durchfahrt, gerade bis zur Kurve, Kurve, gerade bis zum Ende – jeder mit
	# eigenen Punkten, damit genau am Ende der Durchfahrt und an der Kurve ein Punkt liegt
	var parts := [
		[gate_depth(), 0.0],
		[GameConfig.gate_road_before_curve, 0.0],
		[deg_to_rad(GameConfig.gate_curve_angle) * radius, turn],
		[GameConfig.gate_road_after_curve, 0.0],
	]
	var s := 0.0
	points.append({"pos": pos, "dir": dir, "s": s})
	for part in parts:
		var length: float = part[0]
		if length <= 0.001:
			continue
		var count := ceili(length / step)
		var ds := length / count
		for i in count:
			var angle: float = part[1] * ds
			# Sehne in der mittleren Richtung des Schritts (genau auf dem Kreisbogen)
			var chord := ds if absf(angle) < 0.0001 else 2.0 * sin(angle / 2.0) / (angle / ds)
			pos += dir.rotated(angle / 2.0) * chord
			dir = dir.rotated(angle)
			s += ds
			points.append({"pos": pos, "dir": dir, "s": s})
	return points


## Seitlicher Versatz von der Mittellinie: positiv = zur Innenseite der Kurve.
static func gate_offset(point: Dictionary, offset: float) -> Vector2:
	var dir: Vector2 = point.dir
	return point.pos + Vector2(-dir.y, dir.x) * offset * gate_turn_sign()


## Abstand der Hausfronten hinter dem Torhaus von der Straßenmitte.
static func gate_facade_offset() -> float:
	return GameConfig.street_width / 2.0 + GameConfig.gate_sidewalk_width
