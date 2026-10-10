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
##     ========= Fahrbahn: rechts weit geradeaus, dann rund um 90° zur Bücherei-Seite;
##               links eine sanfte Kurve weg von der Bücherei bis zu einem Torhaus (seit 4f)
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


## Kleine Gasse in der Reihe gegenüber (seit Etappe 4f): von – bis (x); leer = keine Gasse.
static func opposite_alley() -> Vector2:
	var half := GameConfig.opposite_alley_width / 2.0
	if half <= 0.0:
		return Vector2.ZERO
	return Vector2(GameConfig.opposite_alley_x - half, GameConfig.opposite_alley_x + half)


static func opposite_alley_end_z() -> float:
	return opposite_front_z() - GameConfig.opposite_alley_depth


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


## --- Die beiden Straßenenden (seit Etappe 4f als Mittellinie mit Kurven) ---
## Jedes Ende ist ein Weg ab dem Ende des geraden Mittelstücks: end_path(side). Seitlicher
## Versatz von der Mittellinie mit end_offset(): positiv = Bücherei-Seite, negativ = Seite
## gegenüber (bleibt auch in den Kurven auf derselben Straßenseite).
##   Gerades Ende: ein Stück hinter der Grenze eine runde 90°-Kurve zur Bücherei-Seite hin,
##   danach die Seitenstraße bis zu quer stehenden Häusern.
##   Abbiegendes Ende: eine sanfte Kurve (gate_bend_angle) von der Bücherei-Seite weg, dann
##   geradeaus bis zum Torhaus, durch den Bogen, dahinter eine Kurve in dieselbe Richtung.

## Seite des abbiegenden Endes (mit Torhaus): 1 = Osten, -1 = Westen.
static func turning_side() -> int:
	return -straight_side()


## Mittellinie der Fahrbahn auf dem geraden Mittelstück (z).
static func road_center_z() -> float:
	return (curb_z() + far_curb_z()) / 2.0


## Abstand der Hausfronten von der Straßenmitte: Bücherei-Seite und gegenüber.
static func library_facade_offset() -> float:
	return GameConfig.street_width / 2.0 + GameConfig.sidewalk_width


static func opposite_facade_offset() -> float:
	return GameConfig.street_width / 2.0 + GameConfig.opposite_sidewalk_width


## Ende der festen Häuser auf der Bücherei-Seite (x): rechts die bündigen Nachbarn, links die
## Häuser hinter der Gasse.
static func row_end_x(side: int) -> float:
	return neighbor_row_end_x() if side > 0 else alley_row_end_x()


## Hier beginnt der Weg eines Straßenendes (x auf der Mittellinie): am geraden Ende
## straight_street_length hinter der Grenze, am abbiegenden gate_bend_offset hinter den
## festen Nachbarhäusern.
static func end_start_x(side: int) -> float:
	if is_straight(side):
		return straight_bound_x() + side * GameConfig.straight_street_length
	return row_end_x(side) + side * GameConfig.gate_bend_offset


## Abschnitte eines Endes: [Länge, Drehung je Meter (positiv = nach rechts), Name].
static func _end_parts(side: int) -> Array:
	if is_straight(side):
		var radius := GameConfig.straight_curve_radius
		return [
			[deg_to_rad(90.0) * radius, side / radius, "curve"],
			[GameConfig.straight_side_street_length, 0.0, "side_street"],
		]
	var bend := GameConfig.gate_bend_radius
	var curve := GameConfig.gate_curve_radius
	return [
		[deg_to_rad(GameConfig.gate_bend_angle) * bend, -side / bend, "bend"],
		[GameConfig.gate_approach_length, 0.0, "approach"],
		[gate_depth(), 0.0, "passage"],
		[GameConfig.gate_road_before_curve, 0.0, "behind"],
		[deg_to_rad(GameConfig.gate_curve_angle) * curve, -side / curve, "behind"],
		[GameConfig.gate_road_after_curve, 0.0, "behind_end"],
	]


## Mittellinie eines Straßenendes. Liste von { "pos": Vector2 (x, z), "dir": Vector2
## (Fahrtrichtung), "s": Meter ab dem Anfang, "part": Abschnitt (curve, side_street, bend,
## approach, passage, behind = hinter dem Bogen bis zum Ende der Kurve, behind_end = danach) }. Genau an jedem Abschnittswechsel liegt ein Punkt.
static func end_path(side: int, step: float = 0.5) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var pos := Vector2(end_start_x(side), road_center_z())
	var dir := Vector2(float(side), 0.0)
	var s := 0.0
	var parts := _end_parts(side)
	points.append({"pos": pos, "dir": dir, "s": s, "part": parts[0][2]})
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
			points.append({"pos": pos, "dir": dir, "s": s, "part": part[2]})
	return points


## Punkt neben der Mittellinie: positiv = Bücherei-Seite, negativ = gegenüber.
static func end_offset(point: Dictionary, offset: float, side: int) -> Vector2:
	var dir: Vector2 = point.dir
	return point.pos + Vector2(-dir.y, dir.x) * offset * float(side)


## Wo der Weg in einen Abschnitt übergeht (Meter ab dem Anfang).
static func end_part_start(side: int, part: String) -> float:
	var s := 0.0
	for item in _end_parts(side):
		if item[2] == part:
			return s
		s += item[0]
	return s


## Schnittpunkt zweier Geraden (Punkt + Richtung).
static func line_intersection(p: Vector2, d: Vector2, q: Vector2, e: Vector2) -> Vector2:
	var den := d.cross(e)
	if absf(den) < 0.00001:
		return p
	return p + d * ((q - p).cross(e) / den)


## --- Torhaus am abbiegenden Ende ---

## Lichte Breite des Bogens und Tiefe der Durchfahrt (aus der Szene des Torhauses).
static func gate_passage_width() -> float:
	return float(HouseTypes.value_of(GameConfig.gatehouse_type, "passage_width", 6.5))


static func gate_depth() -> float:
	return HouseTypes.depth_of(GameConfig.gatehouse_type)


## Vorderseite des Torhauses: Punkt auf der Mittellinie und Richtung durch den Bogen.
static func gatehouse_front() -> Dictionary:
	var side := turning_side()
	var front_s := end_part_start(side, "passage")
	for point in end_path(side):
		if absf(point.s - front_s) < 0.001:
			return point
	return end_path(side).back()


## Das Torhaus sitzt mittig zwischen den Hausfronten (nicht mittig auf der Fahrbahn), damit
## beide Pfeiler gleich breit sind: so weit liegt seine Mitte zur Bücherei-Seite hin.
static func gate_center_offset() -> float:
	return (library_facade_offset() - opposite_facade_offset()) / 2.0


## Abstand der Hausfronten hinter dem Torhaus von der Straßenmitte.
static func gate_facade_offset() -> float:
	return GameConfig.street_width / 2.0 + GameConfig.gate_sidewalk_width
