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
	for width in GameConfig.neighbor_house_widths:
		x += width
	return x


static func alley_row_end_x() -> float:
	var x := alley_far_x()
	for width in GameConfig.alley_house_widths:
		x -= width
	return x


## Läuft dieses Straßenende geradeaus weiter? side: 1 = Osten (+X), -1 = Westen (-X).
static func is_straight(side: int) -> bool:
	return GameConfig.straight_street_end == ("east" if side > 0 else "west")


## Am geraden Ende: Lage der Grenze quer über die Straße (x) und wie weit sie reicht (z: von
## der Hausfront bis zu den Häusern gegenüber).
static func straight_bound_x() -> float:
	return neighbor_row_end_x() if is_straight(1) else alley_row_end_x()


static func straight_side() -> int:
	return 1 if is_straight(1) else -1


## Ende der Häuserreihe auf der Bücherei-Seite (x): Dort steht quer ein Haus, und die Straße
## biegt davor ab. Am geraden Ende liegt dieser Knick straight_street_length weiter draußen.
static func east_end_x() -> float:
	return neighbor_row_end_x() + (GameConfig.straight_street_length if is_straight(1) else 0.0)


static func west_end_x() -> float:
	return alley_row_end_x() - (GameConfig.straight_street_length if is_straight(-1) else 0.0)


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


## Hier enden die Seitenstraßen (quer steht ein Haus) und so weit darf man hinein (z).
static func side_street_end_z() -> float:
	return opposite_front_z() - GameConfig.side_street_length


static func side_street_limit_z() -> float:
	return far_curb_z() - GameConfig.side_street_walkable
