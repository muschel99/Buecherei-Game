class_name Street
extends Node3D
## Die Straße vor der Bücherei (seit Etappe 4d): eine gerade Fahrbahn mit Gehwegen auf beiden
## Seiten. Seit Etappe 4f sind beide Enden rund: Das gerade Ende (GameConfig.straight_street_end)
## biegt kurz hinter einer unsichtbaren Grenze in einer runden 90°-Kurve zur Bücherei-Seite
## ab; das andere macht eine sanfte Kurve weg von der Bücherei und läuft auf ein Torhaus zu,
## durch dessen Bogen es weitergeht – so verschwindet die Straße an beiden Enden hinter Häusern.
## Maße: GameConfig (sidewalk_width, street_width, curb_height …), Lage: StreetLayout.
##
## Dieser Knoten liegt (wie alles unter "Outside") auf Gehweg-Höhe: y = 0 ist der Gehweg.
## Er baut:
## - Gehwege (Plattenmuster), Bordsteine und Fahrbahn als wenige, einfache Meshes,
## - EINE ebene Bodenkollision für alles draußen (die Fahrbahn liegt nur optisch tiefer –
##   so stolpert die Spielfigur nie über einen Bordstein),
## - beide Enden als Bänder entlang StreetLayout.end_path() (Fahrbahn, Bordsteine, Gehwege;
##   unter dem Bogen des Torhauses sind die Gehwege schmaler, dahinter gate_sidewalk_width),
## - unsichtbare, weiche Grenzen: im Bogen des Torhauses quer über die Durchfahrt, am geraden
##   Ende quer über Straße und Gehwege (GameConfig.straight_bound_offset hinter den Nachbarhäusern),
## - unsichtbare Start- und Endpunkte für spätere Autos, Radfahrer und Fußgänger
##   (Knoten "TrafficPoints", Gruppe "traffic_points"; noch fährt und läuft dort niemand).

const TRAFFIC_GROUP := "traffic_points"
## Breite der hellen Bordsteinkante oben auf dem Gehweg.
const CURB_TOP := 0.15
## So weit reichen die Gehwege an den Enden unter die Häuser (die Hausfronten folgen den
## Kurven in geraden Stücken – so bleibt nirgends eine Lücke ohne Boden).
const WALK_EXTRA := 1.5
## So weit hinter der Vorderseite des Torhauses liegt die Grenze im Bogen (Mitte der Grenze;
## die Spielfigur bleibt etwa 0,2 m unter dem Bogen stehen).
const GATE_BOUND_INSIDE := 0.8

@export var sidewalk_material: Material = preload("res://assets/materials/sidewalk.tres")
@export var curb_material: Material = preload("res://assets/materials/curb_stone.tres")
@export var road_material: Material = preload("res://assets/materials/cobblestone.tres")


func _ready() -> void:
	_build_surfaces()
	_build_ground_collision()
	_build_bounds()
	_build_traffic_points()


## Gehwege, Bordsteine und Fahrbahn: das gerade Mittelstück als Rechtecke, die Enden als Bänder.
func _build_surfaces() -> void:
	var s := CURB_TOP
	var front := StreetLayout.HOUSE_FRONT
	var curb := StreetLayout.curb_z()
	var far := StreetLayout.far_curb_z()
	var opposite := StreetLayout.opposite_front_z()
	var x0 := StreetLayout.end_start_x(-1)
	var x1 := StreetLayout.end_start_x(1)
	var road_y := -GameConfig.curb_height

	var walk := WorldMesh.new()
	var stone := WorldMesh.new()
	var road := WorldMesh.new()
	var white := Color.WHITE  # Farbe kommt aus dem Material
	# Gehweg auf der Bücherei-Seite (die Ecke an der Schräge und die Gasse bauen Plaza/Alley)
	_rect(walk, x0, x1, curb + s, front, 0.0)
	_rect(stone, x0, x1, curb, curb + s, 0.0)
	# Gehweg gegenüber
	_rect(walk, x0, x1, opposite, far - s, 0.0)
	_rect(stone, x0, x1, far - s, far, 0.0)
	# Bordsteinkanten (senkrecht, zur Fahrbahn hin) und Fahrbahn
	stone.add_wall(Vector2(x0, curb), Vector2(x1, curb), road_y, 0.0, Vector3.FORWARD, white)
	stone.add_wall(Vector2(x0, far), Vector2(x1, far), road_y, 0.0, Vector3.BACK, white)
	_rect(road, x0, x1, far, curb, road_y)
	for side in [1, -1]:
		_build_end(walk, stone, road, side)
	for part in [[walk, "Sidewalks", sidewalk_material], [stone, "Curbs", curb_material], [road, "Road", road_material]]:
		var mesh: MeshInstance3D = (part[0] as WorldMesh).make_instance(part[1], part[2], false)
		if mesh:
			add_child(mesh)


## Ein Straßenende als Bänder entlang seiner Mittellinie. Die Gehwege reichen bis zu den
## Hausfronten (und ein Stück darunter); unter dem Bogen des Torhauses bis an die Wände der
## Durchfahrt, dahinter sind sie gate_sidewalk_width breit.
func _build_end(walk: WorldMesh, stone: WorldMesh, road: WorldMesh, side: int) -> void:
	var s := CURB_TOP
	var half := GameConfig.street_width / 2.0
	var road_y := -GameConfig.curb_height
	var path := StreetLayout.end_path(side)
	for i in path.size() - 1:
		var a: Dictionary = path[i]
		var b: Dictionary = path[i + 1]
		var part: String = b.part
		_band(road, a, b, side, -half, half, road_y)
		for edge in [1.0, -1.0]:
			_band(stone, a, b, side, edge * half, edge * (half + s), 0.0)
			_band(walk, a, b, side, edge * (half + s), edge * _walk_outer(part, edge), 0.0)
			# Senkrechte Bordsteinkante zur Fahrbahn hin
			var p := StreetLayout.end_offset(a, edge * half, side)
			var q := StreetLayout.end_offset(b, edge * half, side)
			var toward := StreetLayout.end_offset(a, 0.0, side) - p
			stone.add_wall(p, q, road_y, 0.0, Vector3(toward.x, 0.0, toward.y).normalized(), Color.WHITE)


## Bis zu diesem Abstand von der Mittellinie reicht der Gehweg (edge: 1 = Bücherei-Seite,
## -1 = gegenüber). Innen in Kurven nie über den Kurvenmittelpunkt hinaus.
func _walk_outer(part: String, edge: float) -> float:
	match part:
		"passage":
			# Bis an die Wände der Durchfahrt (der Bogen sitzt etwas zur Bücherei-Seite versetzt)
			return StreetLayout.gate_passage_width() / 2.0 + edge * StreetLayout.gate_center_offset()
		"behind", "behind_end":
			return StreetLayout.gate_facade_offset() + WALK_EXTRA
	var facade := StreetLayout.library_facade_offset() if edge > 0.0 else StreetLayout.opposite_facade_offset()
	var radius := INF
	if part == "curve" and edge > 0.0:
		radius = GameConfig.straight_curve_radius  # Innenseite der runden Kurve
	elif part == "bend" and edge < 0.0:
		radius = GameConfig.gate_bend_radius  # Innenseite der sanften Kurve
	return minf(facade + WALK_EXTRA, radius - 0.3)


## Ein Stück Band zwischen zwei Punkten der Mittellinie, von Abstand "from" bis "to".
func _band(builder: WorldMesh, a: Dictionary, b: Dictionary, side: int, from: float, to: float, y: float) -> void:
	var a0 := StreetLayout.end_offset(a, from, side)
	var a1 := StreetLayout.end_offset(a, to, side)
	var b0 := StreetLayout.end_offset(b, from, side)
	var b1 := StreetLayout.end_offset(b, to, side)
	builder.add_quad(Vector3(a0.x, y, a0.y), Vector3(a1.x, y, a1.y), Vector3(b1.x, y, b1.y), Vector3(b0.x, y, b0.y),
		Vector3.UP, Color.WHITE)


func _rect(builder: WorldMesh, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	if x1 - x0 <= 0.001 or z1 - z0 <= 0.001:
		return
	builder.add_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, Color.WHITE)


## Ein großer, flacher Boden für alles, wo man draußen hinkommt (Straße bis zur Grenze und bis
## zum Torhaus, Gehwege, Platz, beide Gassen).
func _build_ground_collision() -> void:
	var points := PackedVector2Array([
		Vector2(StreetLayout.straight_bound_x(), StreetLayout.opposite_front_z()),
		Vector2(StreetLayout.straight_bound_x(), StreetLayout.HOUSE_FRONT),
		Vector2(StreetLayout.alley_far_x(), StreetLayout.alley_end_z()),
		Vector2(StreetLayout.HOUSE_RIGHT, StreetLayout.alley_end_z()),
	])
	var alley := StreetLayout.opposite_alley()
	if alley != Vector2.ZERO:
		points.append(Vector2(alley.x, StreetLayout.opposite_alley_end_z()))
	var side := StreetLayout.turning_side()
	for point in StreetLayout.end_path(side):
		if point.part in ["bend", "approach", "passage"]:
			for offset in [-8.0, 8.0]:
				points.append(StreetLayout.end_offset(point, offset, side))
	var low := points[0]
	var high := points[0]
	for p in points:
		low = Vector2(minf(low.x, p.x), minf(low.y, p.y))
		high = Vector2(maxf(high.x, p.x), maxf(high.y, p.y))
	low -= Vector2(2.0, 2.0)
	high += Vector2(2.0, 2.0)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(high.x - low.x, 1.0, high.y - low.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3((low.x + high.x) / 2.0, -0.5, (low.y + high.y) / 2.0)
	body.add_child(collision)
	add_child(body)


## Weiche Grenzen: abgerundet (Zylinder an den Enden), so gleitet die Spielfigur sanft daran
## entlang statt hart anzustoßen. Am geraden Ende quer über Straße und Gehwege, am anderen
## Ende quer durch den Bogen des Torhauses.
func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var x := StreetLayout.straight_bound_x()
	_add_bound(body, Vector2(x, StreetLayout.HOUSE_FRONT + 0.5), Vector2(x, StreetLayout.opposite_front_z() - 0.5))
	# Im Bogen: Die Spielfigur kommt bis knapp unter den Bogen, aber nicht hindurch. Die Enden
	# stecken in den Mauerpfeilern (die Pfeiler selbst sind fest).
	var gate := StreetLayout.gatehouse_front()
	var dir: Vector2 = gate.dir
	var across := Vector2(-dir.y, dir.x) * (StreetLayout.gate_passage_width() / 2.0 + 0.3)
	var middle: Vector2 = StreetLayout.end_offset(gate, StreetLayout.gate_center_offset(), StreetLayout.turning_side()) \
		+ dir * GATE_BOUND_INSIDE
	_add_bound(body, middle - across, middle + across)


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


## Unsichtbare Start- und Endpunkte für späteren Verkehr, außer Sicht am Ende beider
## Straßenenden (hinter der Kurve bzw. hinter dem Torhaus).
## Name = wer dort startet/endet; Metadaten "kind" = "car", "bike" oder "walker".
func _build_traffic_points() -> void:
	var root := Node3D.new()
	root.name = "TrafficPoints"
	add_child(root)
	var road_y := -GameConfig.curb_height
	var half := GameConfig.street_width / 2.0
	for side in [1, -1]:
		var suffix := "East" if side > 0 else "West"
		var last: Dictionary = StreetLayout.end_path(side).back()
		var near := half + GameConfig.sidewalk_width / 2.0
		var far := half + GameConfig.opposite_sidewalk_width / 2.0
		if last.part in ["behind", "behind_end"]:
			near = half + GameConfig.gate_sidewalk_width / 2.0
			far = near
		# Auto in der Mitte, Rad am Rand gegenüber, Fußgänger auf beiden Gehwegen
		var spots := {
			"Car" + suffix: ["car", 0.0, road_y],
			"Bike" + suffix: ["bike", -(half - 0.6), road_y],
			"Walker%sNear" % suffix: ["walker", near, 0.0],
			"Walker%sFar" % suffix: ["walker", -far, 0.0],
		}
		for point_name in spots:
			var spot: Array = spots[point_name]
			var p := StreetLayout.end_offset(last, spot[1], side)
			var marker := Marker3D.new()
			marker.name = point_name
			marker.position = Vector3(p.x, spot[2], p.y)
			marker.set_meta("kind", spot[0])
			marker.add_to_group(TRAFFIC_GROUP)
			root.add_child(marker)
