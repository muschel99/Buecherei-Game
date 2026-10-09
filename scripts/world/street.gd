class_name Street
extends Node3D
## Die Straße vor der Bücherei (seit Etappe 4d): eine schmale, gerade Fahrbahn (ein Auto
## breit) mit Gehwegen auf beiden Seiten. Ein Ende biegt vor einem quer stehenden Haus in eine
## Seitenstraße ab; das andere läuft geradeaus weiter (GameConfig.straight_street_end) und
## knickt erst weit hinter einer unsichtbaren Grenze ab – so verschwindet die Straße an beiden
## Enden hinter Häusern.
## Maße: GameConfig (sidewalk_width, street_width, curb_height …), Lage: StreetLayout.
##
## Dieser Knoten liegt (wie alles unter "Outside") auf Gehweg-Höhe: y = 0 ist der Gehweg.
## Er baut:
## - Gehwege (Plattenmuster), Bordsteine und Fahrbahn als wenige, einfache Meshes,
## - EINE ebene Bodenkollision für alles draußen (die Fahrbahn liegt nur optisch tiefer –
##   so stolpert die Spielfigur nie über einen Bordstein),
## - unsichtbare, weiche Grenzen: in der Seitenstraße kurz hinter der Ecke, am geraden Ende
##   quer über Straße und Gehwege (wo die Nachbarhäuser enden),
## - unsichtbare Start- und Endpunkte für spätere Autos, Radfahrer und Fußgänger
##   (Knoten "TrafficPoints", Gruppe "traffic_points"; noch fährt und läuft dort niemand).

const TRAFFIC_GROUP := "traffic_points"
## Breite der hellen Bordsteinkante oben auf dem Gehweg.
const CURB_TOP := 0.15

@export var sidewalk_material: Material = preload("res://assets/materials/sidewalk.tres")
@export var curb_material: Material = preload("res://assets/materials/curb_stone.tres")
@export var road_material: Material = preload("res://assets/materials/cobblestone.tres")


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
	var end := StreetLayout.side_street_end_z()
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
	_rect(walk, east.y + s, east_x, end, curb, 0.0)  # um die Ecke in die Seitenstraße
	_rect(walk, west_x, west.x - s, end, curb, 0.0)
	_rect(stone, west.x - s, east.y + s, curb, curb + s, 0.0)
	_rect(stone, east.y, east.y + s, end, curb, 0.0)
	_rect(stone, west.x - s, west.x, end, curb, 0.0)
	# Gehweg gegenüber (läuft um die Ecken der Häuserreihe herum)
	_rect(walk, west.y + s, east.x - s, opposite, far - s, 0.0)
	_rect(walk, row.y, east.x - s, end, opposite, 0.0)
	_rect(walk, west.y + s, row.x, end, opposite, 0.0)
	_rect(stone, west.y, east.x, far - s, far, 0.0)
	_rect(stone, east.x - s, east.x, end, far - s, 0.0)
	_rect(stone, west.y, west.y + s, end, far - s, 0.0)
	# Bordsteinkanten (senkrecht, zur Fahrbahn hin)
	stone.add_wall(Vector2(west.x, curb), Vector2(east.y, curb), road_y, 0.0, Vector3.FORWARD, white)
	stone.add_wall(Vector2(east.y, end), Vector2(east.y, curb), road_y, 0.0, Vector3.LEFT, white)
	stone.add_wall(Vector2(west.x, end), Vector2(west.x, curb), road_y, 0.0, Vector3.RIGHT, white)
	stone.add_wall(Vector2(west.y, far), Vector2(east.x, far), road_y, 0.0, Vector3.BACK, white)
	stone.add_wall(Vector2(east.x, end), Vector2(east.x, far), road_y, 0.0, Vector3.RIGHT, white)
	stone.add_wall(Vector2(west.y, end), Vector2(west.y, far), road_y, 0.0, Vector3.LEFT, white)
	# Fahrbahn: gerade Strecke und die beiden Seitenstraßen
	_rect(road, west.x, east.y, far, curb, road_y)
	_rect(road, east.x, east.y, end, far, road_y)
	_rect(road, west.x, west.y, end, far, road_y)
	for part in [[walk, "Sidewalks", sidewalk_material], [stone, "Curbs", curb_material], [road, "Road", road_material]]:
		var mesh: MeshInstance3D = (part[0] as WorldMesh).make_instance(part[1], part[2], false)
		if mesh:
			add_child(mesh)


func _rect(builder: WorldMesh, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	if x1 - x0 <= 0.001 or z1 - z0 <= 0.001:
		return
	builder.add_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, Color.WHITE)


## Ein großer, flacher Boden für alles draußen (Gehwege, Fahrbahn, Platz, Gasse).
func _build_ground_collision() -> void:
	var x0 := StreetLayout.west_end_x() - 2.0
	var x1 := StreetLayout.east_end_x() + 2.0
	var z0 := StreetLayout.side_street_end_z() - 2.0
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
## entlang statt hart anzustoßen. Am abbiegenden Ende quer über die Seitenstraße, am geraden
## Ende quer über Straße und Gehwege.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var limit := StreetLayout.side_street_limit_z()
	if StreetLayout.is_straight(1):
		_add_straight_bound(body, StreetLayout.HOUSE_FRONT)
	else:
		_add_bound(body, Vector2(StreetLayout.opposite_row().y - 0.5, limit), Vector2(StreetLayout.east_end_x(), limit))
	if StreetLayout.is_straight(-1):
		_add_straight_bound(body, StreetLayout.recess_z())
	else:
		_add_bound(body, Vector2(StreetLayout.west_end_x(), limit), Vector2(StreetLayout.opposite_row().x + 0.5, limit))


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


## Unsichtbare Start- und Endpunkte für späteren Verkehr, außer Sicht in den Seitenstraßen.
## Name = wer dort startet/endet; Metadaten "kind" = "car", "bike" oder "walker".
func _build_traffic_points() -> void:
	var root := Node3D.new()
	root.name = "TrafficPoints"
	add_child(root)
	var end := StreetLayout.side_street_end_z() + 1.0
	var road_y := -GameConfig.curb_height
	var east := StreetLayout.east_road()
	var west := StreetLayout.west_road()
	var points := {
		"CarWest": ["car", Vector3((west.x + west.y) / 2.0, road_y, end)],
		"CarEast": ["car", Vector3((east.x + east.y) / 2.0, road_y, end)],
		"BikeWest": ["bike", Vector3(west.x + 0.6, road_y, end)],
		"BikeEast": ["bike", Vector3(east.y - 0.6, road_y, end)],
		"WalkerWestNear": ["walker", Vector3(StreetLayout.west_end_x() + 0.8, 0.0, end)],
		"WalkerEastNear": ["walker", Vector3(StreetLayout.east_end_x() - 0.8, 0.0, end)],
		"WalkerWestFar": ["walker", Vector3(StreetLayout.opposite_row().x - 0.6, 0.0, end)],
		"WalkerEastFar": ["walker", Vector3(StreetLayout.opposite_row().y + 0.6, 0.0, end)],
	}
	for point_name in points:
		var marker := Marker3D.new()
		marker.name = point_name
		marker.position = points[point_name][1]
		marker.set_meta("kind", points[point_name][0])
		marker.add_to_group(TRAFFIC_GROUP)
		root.add_child(marker)
