class_name Street
extends Node3D
## Die Straße vor der Bücherei (seit Etappe 4d): eine gerade Fahrbahn mit Gehwegen auf beiden
## Seiten. Ein Ende biegt in eine Seitenstraße ab, die durch den Bogen eines Torhauses
## weiterläuft und dahinter in einer sanften Kurve verschwindet (seit Etappe 4f); das andere
## läuft geradeaus weiter (GameConfig.straight_street_end) und knickt kurz hinter einer
## unsichtbaren Grenze ab – so verschwindet die Straße an beiden Enden hinter Häusern.
## Maße: GameConfig (sidewalk_width, street_width, curb_height …), Lage: StreetLayout.
##
## Dieser Knoten liegt (wie alles unter "Outside") auf Gehweg-Höhe: y = 0 ist der Gehweg.
## Er baut:
## - Gehwege (Plattenmuster), Bordsteine und Fahrbahn als wenige, einfache Meshes,
## - EINE ebene Bodenkollision für alles draußen (die Fahrbahn liegt nur optisch tiefer –
##   so stolpert die Spielfigur nie über einen Bordstein),
## - die Straße durch das Torhaus und die Kurve dahinter (Fahrbahn, Bordsteine, Gehwege als
##   Bänder entlang StreetLayout.gate_path(); unter dem Bogen sind die Gehwege schmaler),
## - unsichtbare, weiche Grenzen: im Bogen des Torhauses quer über die Durchfahrt, am geraden
##   Ende quer über Straße und Gehwege (GameConfig.straight_bound_offset hinter den Nachbarhäusern),
## - unsichtbare Start- und Endpunkte für spätere Autos, Radfahrer und Fußgänger
##   (Knoten "TrafficPoints", Gruppe "traffic_points"; noch fährt und läuft dort niemand).

const TRAFFIC_GROUP := "traffic_points"
## Breite der hellen Bordsteinkante oben auf dem Gehweg.
const CURB_TOP := 0.15

@export var sidewalk_material: Material = preload("res://assets/materials/sidewalk.tres")
@export var curb_material: Material = preload("res://assets/materials/curb_stone.tres")
@export var road_material: Material = preload("res://assets/materials/cobblestone.tres")


## Hinter dem Torhaus reichen die Gehwege so weit unter die Häuser (die Hausfronten folgen der
## Kurve in geraden Stücken – so bleibt nirgends eine Lücke ohne Boden).
const GATE_WALK_EXTRA := 1.5
## So weit hinter der Vorderseite des Torhauses liegt die Grenze im Bogen (Mitte der Grenze;
## die Spielfigur bleibt etwa 0,2 m unter dem Bogen stehen).
const GATE_BOUND_INSIDE := 0.8


func _ready() -> void:
	_build_surfaces()
	_build_ground_collision()
	_build_bounds()
	_build_traffic_points()


## Gehwege, Bordsteine und Fahrbahn.
func _build_surfaces() -> void:
	var s := CURB_TOP
	var front := StreetLayout.HOUSE_FRONT
	var curb := StreetLayout.curb_z()
	var far := StreetLayout.far_curb_z()
	var opposite := StreetLayout.opposite_front_z()
	var end_e := StreetLayout.side_street_end_z(1)
	var end_w := StreetLayout.side_street_end_z(-1)
	var east := StreetLayout.east_road()
	var west := StreetLayout.west_road()
	var east_x := StreetLayout.east_end_x()
	var west_x := StreetLayout.west_end_x()
	var row := StreetLayout.opposite_row()
	var road_y := -GameConfig.curb_height

	var walk := WorldMesh.new()
	var stone := WorldMesh.new()
	var road := WorldMesh.new()
	var white := Color.WHITE  # Farbe kommt aus dem Material
	# Gehweg auf der Bücherei-Seite (die Ecke an der Schräge und die Gasse bauen Plaza/Alley)
	_rect(walk, west_x, east_x, curb + s, front, 0.0)
	_rect(walk, west_x, west.x - s, curb, curb + s, 0.0)
	_rect(walk, east.y + s, east_x, curb, curb + s, 0.0)
	_rect(walk, east.y + s, east_x, end_e, curb, 0.0)  # um die Ecke in die Seitenstraße
	_rect(walk, west_x, west.x - s, end_w, curb, 0.0)
	_rect(stone, west.x - s, east.y + s, curb, curb + s, 0.0)
	_rect(stone, east.y, east.y + s, end_e, curb, 0.0)
	_rect(stone, west.x - s, west.x, end_w, curb, 0.0)
	# Gehweg gegenüber (läuft um die Ecken der Häuserreihe herum)
	_rect(walk, west.y + s, east.x - s, opposite, far - s, 0.0)
	_rect(walk, row.y, east.x - s, end_e, opposite, 0.0)
	_rect(walk, west.y + s, row.x, end_w, opposite, 0.0)
	_rect(stone, west.y, east.x, far - s, far, 0.0)
	_rect(stone, east.x - s, east.x, end_e, far - s, 0.0)
	_rect(stone, west.y, west.y + s, end_w, far - s, 0.0)
	# Bordsteinkanten (senkrecht, zur Fahrbahn hin)
	stone.add_wall(Vector2(west.x, curb), Vector2(east.y, curb), road_y, 0.0, Vector3.FORWARD, white)
	stone.add_wall(Vector2(east.y, end_e), Vector2(east.y, curb), road_y, 0.0, Vector3.LEFT, white)
	stone.add_wall(Vector2(west.x, end_w), Vector2(west.x, curb), road_y, 0.0, Vector3.RIGHT, white)
	stone.add_wall(Vector2(west.y, far), Vector2(east.x, far), road_y, 0.0, Vector3.BACK, white)
	stone.add_wall(Vector2(east.x, end_e), Vector2(east.x, far), road_y, 0.0, Vector3.RIGHT, white)
	stone.add_wall(Vector2(west.y, end_w), Vector2(west.y, far), road_y, 0.0, Vector3.LEFT, white)
	# Fahrbahn: gerade Strecke und die beiden Seitenstraßen
	_rect(road, west.x, east.y, far, curb, road_y)
	_rect(road, east.x, east.y, end_e, far, road_y)
	_rect(road, west.x, west.y, end_w, far, road_y)
	_build_gate_road(walk, stone, road)
	for part in [[walk, "Sidewalks", sidewalk_material], [stone, "Curbs", curb_material], [road, "Road", road_material]]:
		var mesh: MeshInstance3D = (part[0] as WorldMesh).make_instance(part[1], part[2], false)
		if mesh:
			add_child(mesh)


## Straße durch das Torhaus und die Kurve dahinter: Bänder entlang der Mittellinie.
## Unter dem Bogen reichen die Gehwege bis an die Wände der Durchfahrt, dahinter sind sie
## gate_sidewalk_width breit (und reichen noch ein Stück unter die Häuser).
func _build_gate_road(walk: WorldMesh, stone: WorldMesh, road: WorldMesh) -> void:
	var s := CURB_TOP
	var half := GameConfig.street_width / 2.0
	var road_y := -GameConfig.curb_height
	var path := StreetLayout.gate_path()
	var depth := StreetLayout.gate_depth()
	var inside: Array[Dictionary] = []
	var outside: Array[Dictionary] = []
	for point in path:
		if point.s <= depth + 0.001:
			inside.append(point)
		if point.s >= depth - 0.001:
			outside.append(point)
	var walk_inside := StreetLayout.gate_passage_width() / 2.0
	var walk_outside := StreetLayout.gate_facade_offset() + GATE_WALK_EXTRA
	_ribbon(road, path, -half, half, road_y)
	for side in [-1.0, 1.0]:
		_ribbon(stone, path, side * half, side * (half + s), 0.0)
		_ribbon(walk, inside, side * (half + s), side * walk_inside, 0.0)
		_ribbon(walk, outside, side * (half + s), side * walk_outside, 0.0)
		# Senkrechte Bordsteinkante zur Fahrbahn hin
		for i in path.size() - 1:
			var a := StreetLayout.gate_offset(path[i], side * half)
			var b := StreetLayout.gate_offset(path[i + 1], side * half)
			var toward_road := StreetLayout.gate_offset(path[i], 0.0) - a
			stone.add_wall(a, b, road_y, 0.0, Vector3(toward_road.x, 0.0, toward_road.y).normalized(), Color.WHITE)


## Band entlang der Torstraße zwischen zwei seitlichen Abständen von der Mittellinie.
func _ribbon(builder: WorldMesh, path: Array[Dictionary], from: float, to: float, y: float) -> void:
	for i in path.size() - 1:
		var a0 := StreetLayout.gate_offset(path[i], from)
		var a1 := StreetLayout.gate_offset(path[i], to)
		var b0 := StreetLayout.gate_offset(path[i + 1], from)
		var b1 := StreetLayout.gate_offset(path[i + 1], to)
		builder.add_quad(Vector3(a0.x, y, a0.y), Vector3(a1.x, y, a1.y), Vector3(b1.x, y, b1.y), Vector3(b0.x, y, b0.y),
			Vector3.UP, Color.WHITE)


func _rect(builder: WorldMesh, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	if x1 - x0 <= 0.001 or z1 - z0 <= 0.001:
		return
	builder.add_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, Color.WHITE)


## Ein großer, flacher Boden für alles draußen (Gehwege, Fahrbahn, Platz, Gasse).
func _build_ground_collision() -> void:
	var x0 := StreetLayout.west_end_x() - 2.0
	var x1 := StreetLayout.east_end_x() + 2.0
	var z0 := StreetLayout.deepest_end_z() - 2.0
	var z1 := StreetLayout.alley_end_z() + 2.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, 1.0, z1 - z0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3((x0 + x1) / 2.0, -0.5, (z0 + z1) / 2.0)
	body.add_child(collision)
	add_child(body)


## Weiche Grenzen: abgerundet (Zylinder an den Enden), so gleitet die Spielfigur sanft daran
## entlang statt hart anzustoßen. Am abbiegenden Ende quer durch den Bogen des Torhauses, am
## geraden Ende quer über Straße und Gehwege.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	if StreetLayout.is_straight(1):
		_add_straight_bound(body, StreetLayout.HOUSE_FRONT)
	if StreetLayout.is_straight(-1):
		_add_straight_bound(body, StreetLayout.recess_z())
	# Im Bogen: Die Spielfigur kommt bis knapp unter den Bogen, aber nicht hindurch. Die Enden
	# stecken in den Mauerpfeilern (die Pfeiler selbst sind fest).
	var x := StreetLayout.turning_road_center_x()
	var half := StreetLayout.gate_passage_width() / 2.0 + 0.3
	var z := StreetLayout.gatehouse_front_z() - GATE_BOUND_INSIDE
	_add_bound(body, Vector2(x - half, z), Vector2(x + half, z))


## Grenze am geraden Ende: von der Hausfront (front_z) bis in die Häuser gegenüber.
func _add_straight_bound(body: StaticBody3D, front_z: float) -> void:
	var x := StreetLayout.straight_bound_x()
	_add_bound(body, Vector2(x, front_z + 0.5), Vector2(x, StreetLayout.opposite_front_z() - 0.5))


func _add_bound(body: StaticBody3D, a: Vector2, b: Vector2) -> void:
	var height := 3.0
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), height, 0.6)
	var collision := CollisionShape3D.new()
	collision.shape = box
	var mid := (a + b) / 2.0
	collision.position = Vector3(mid.x, height / 2.0, mid.y)
	collision.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	body.add_child(collision)
	for end in [a, b]:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.3
		cylinder.height = height
		var cap := CollisionShape3D.new()
		cap.shape = cylinder
		cap.position = Vector3(end.x, height / 2.0, end.y)
		body.add_child(cap)


## Unsichtbare Start- und Endpunkte für späteren Verkehr, außer Sicht: am geraden Ende in der
## Seitenstraße, am abbiegenden Ende hinter der Kurve hinter dem Torhaus.
## Name = wer dort startet/endet; Metadaten "kind" = "car", "bike" oder "walker".
func _build_traffic_points() -> void:
	var root := Node3D.new()
	root.name = "TrafficPoints"
	add_child(root)
	var points := {}
	for side in [1, -1]:
		var suffix := "East" if side > 0 else "West"
		var spots := _traffic_spots(side)
		points["Car" + suffix] = ["car", spots[0]]
		points["Bike" + suffix] = ["bike", spots[1]]
		points["Walker%sNear" % suffix] = ["walker", spots[2]]
		points["Walker%sFar" % suffix] = ["walker", spots[3]]
	for point_name in points:
		var marker := Marker3D.new()
		marker.name = point_name
		marker.position = points[point_name][1]
		marker.set_meta("kind", points[point_name][0])
		marker.add_to_group(TRAFFIC_GROUP)
		root.add_child(marker)


## Auto (Fahrbahnmitte), Rad (am äußeren Rand der Fahrbahn), Fußgänger auf dem äußeren
## (Near) und dem inneren Gehweg (Far) – am Ende der Seitenstraße einer Seite.
func _traffic_spots(side: int) -> Array[Vector3]:
	var road_y := -GameConfig.curb_height
	var half := GameConfig.street_width / 2.0
	if not StreetLayout.is_straight(side):
		var last: Dictionary = StreetLayout.gate_path().back()
		var walk := half + GameConfig.gate_sidewalk_width / 2.0
		var spots: Array[Vector3] = []
		for spot in [[0.0, road_y], [-(half - 0.6), road_y], [-walk, 0.0], [walk, 0.0]]:
			var p := StreetLayout.gate_offset(last, spot[0])
			spots.append(Vector3(p.x, spot[1], p.y))
		return spots
	var end := StreetLayout.side_street_end_z(side) + 1.0
	var road := StreetLayout.east_road() if side > 0 else StreetLayout.west_road()
	var outer_x := StreetLayout.east_end_x() if side > 0 else StreetLayout.west_end_x()
	var row_x := StreetLayout.opposite_row().y if side > 0 else StreetLayout.opposite_row().x
	return [
		Vector3((road.x + road.y) / 2.0, road_y, end),
		Vector3(road.y - 0.6 if side > 0 else road.x + 0.6, road_y, end),
		Vector3(outer_x - side * 0.8, 0.0, end),
		Vector3(row_x + side * 0.6, 0.0, end),
	]
