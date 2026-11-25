class_name Alley
extends Node3D
## Die schmale Gasse neben der Bücherei (seit Etappe 4d), an der Seite mit der Schräge
## (Seitenwand mit dem Fenster). Sie beginnt am kleinen Platz und führt etwa
## GameConfig.alley_depth Meter nach hinten; Breite GameConfig.alley_width. Sie ist
## durchgehend mit denselben großen Platten belegt wie Gehweg und Platz (keine Stufe, kein
## Bordstein) – nur die Straße hat eine glatte Fahrbahn.
##
## Rechts (Bücherei-Seite) begrenzt sie die Hauswand der Bücherei und dahinter eine niedrige
## Hofmauer, links das Nachbarhaus und dahinter ebenfalls eine Hofmauer. Die Hofmauer hinter
## der Bücherei ist nur ein Platzhalter: Wird die Bücherei später nach hinten erweitert,
## tritt der Anbau an ihre Stelle.
## Am Ende steht ein austauschbarer Abschluss (end_scene, z. B. Mauer mit Tor) – er ist fest,
## dahinter kommt man nicht. Seit Etappe 4g endet die Gasse im Garten mit Baum (model_scene):
## Auf der runden Bank um den Stamm kann man sich setzen (E), ab und zu auch ein Passant
## (Sitzplätze in der Gruppe StreetLife.SEAT_GROUP). Passanten erscheinen hier nicht mehr.
## Liegt (wie alles unter "Outside") auf Gehweg-Höhe.

const YARD_WALL_HEIGHT := 2.2
const YARD_WALL_THICKNESS := 0.3
## Runde Bank um den Baum (Maße wie in tools/blender/build_alleys.py): Sitzhöhe, Abstand der
## Sitzplätze von der Stammmitte, Richtungen der Sitzplätze (Winkel in Bogenmaß, 0 = +X, zur
## Gasse hin; frei von Kissen und Hocker) und welche davon Passanten nehmen (vom Weg aus
## erreichbar, nicht an den Beeten).
const BENCH_SEAT_HEIGHT := 0.3
const BENCH_SEAT_RADIUS := 0.68
const BENCH_SEAT_ANGLES: Array[float] = [1.75, 2.7, 3.65, 4.6, 5.55]
const BENCH_WALKER_SEATS: Array[float] = [1.75, 4.6, 5.55]
## So weit vor der Bank (von der Stammmitte) steht man, bevor man sich setzt.
const BENCH_APPROACH := 1.45

@export var end_scene: PackedScene = preload("res://scenes/world/alley_end.tscn")
## Stil-Modell der Gasse (seit Etappe 4g, tools/blender/build_alleys.py): hohe Hauswände und der
## Garten mit Baum am Ende. Ist es da, ersetzt es Hofmauern und Abschluss (die Kollisionen baut
## dieses Script weiter selbst).
## Seit Etappe 8d der große Garten hinter Bücherei und Pub (tools/blender/build_storybook_backyard.py): die Gasse führt offen
## hinein; Baum mit Bank und Vogelbad stehen wie zuvor im kleinen Garten.
@export var model_scene: PackedScene = preload("res://assets/models/world/backyard.glb")
@export var paving_material: Material = preload("res://assets/materials/sidewalk.tres")
## Bachwasser im Garten (bewegte Wellen, seit der Testrunde nach 8d) – ersetzt das Material „Wasser Bach“ des Modells
@export var stream_material: Material = preload("res://assets/materials/stream_water.tres")
## Holzhäuschen hinten links im Garten (seit Etappe 8d, Zettel 05 der Oase): Modell (tools/blender/build_storybook_cottage.py)
## und Tür (E öffnet); Platz und Drehung in GameConfig.backyard_cottage_*
@export var cottage_scene: PackedScene = preload("res://assets/models/world/garden_cottage.glb")
@export var cottage_door_scene: PackedScene = preload("res://scenes/objects/cottage_door.tscn")
@export var wall_material: Material = preload("res://assets/materials/outdoor_colors.tres")
@export var yard_wall_color: Color = Color(0.52, 0.31, 0.25)


func _ready() -> void:
	var library_x := StreetLayout.HOUSE_LEFT
	var far_x := StreetLayout.alley_far_x()
	var start := StreetLayout.recess_z()
	var end := StreetLayout.alley_end_z()
	var paving := WorldMesh.new()
	# Pflaster bis hinter das Pub – dahinter liegen Rasen und Kiesweg des Gartens (im Modell)
	var paving_end := _neighbor_back() if model_scene else end
	paving.add_quad(Vector3(far_x, 0.0, start), Vector3(library_x, 0.0, start),
		Vector3(library_x, 0.0, paving_end), Vector3(far_x, 0.0, paving_end), Vector3.UP, Color.WHITE)
	add_child(paving.make_instance("Paving", paving_material, false))
	if model_scene:
		var model := model_scene.instantiate()
		model.name = "Model"
		add_child(model)
		# Die Wände sind nur von innen gebaut: Schatten trotzdem von beiden Seiten
		WorldMesh.cast_shadows_both_sides(model)
		var water := model.find_child("Wasser*", true, false) as MeshInstance3D
		if water and stream_material:
			water.material_override = stream_material
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_build_backyard_walls()
		_build_bench()
		_build_cottage()
	else:
		_build_yard_walls(library_x, far_x, end)
	if end_scene and model_scene == null:
		var closing := end_scene.instantiate() as Node3D
		closing.name = "End"
		closing.position = Vector3((library_x + far_x) / 2.0, 0.0, end)
		add_child(closing)
		# Ohne Garten: Passanten kommen durch das Tor am Ende
		_add_traffic_point(StreetPaths.library_alley_points()[0], "alley")


## Fester Punkt vor dem Tor am Ende: Hier erscheinen und verschwinden Passanten (StreetLife,
## seit Etappe 5a) – nur, wenn es gerade niemand sieht.
func _add_traffic_point(spot: Vector2, place: String) -> void:
	var marker := Marker3D.new()
	marker.name = "TrafficPoint"
	marker.position = Vector3(spot.x, 0.0, spot.y)
	marker.set_meta("kind", "walker")
	marker.set_meta("place", place)
	marker.add_to_group(Street.TRAFFIC_GROUP)
	add_child(marker)


## Sitzplätze auf der runden Bank um den Baum: für die Spielfigur (E, wie bei Sesseln) und für
## Passanten (Gruppe StreetLife.SEAT_GROUP; Metadaten "approach" = Stelle vor dem Sitz, "face" =
## Blickrichtung, beide als x/z unter "Outside").
func _build_bench() -> void:
	var tree := StreetLayout.garden_tree()
	var bench := Node3D.new()
	bench.name = "Bench"
	bench.position = Vector3(tree.x, 0.0, tree.y)
	var seating := Seating.new()
	seating.name = "Seating"
	for angle in BENCH_SEAT_ANGLES:
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var seat := SeatPoint.new()
		seat.name = "Seat%d" % (seating.get_child_count() + 1)
		# Blickrichtung +Z = vom Stamm weg
		seat.transform = Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out),
			out * BENCH_SEAT_RADIUS + Vector3.UP * BENCH_SEAT_HEIGHT)
		if angle in BENCH_WALKER_SEATS:
			seat.add_to_group(StreetLife.SEAT_GROUP)
			seat.set_meta("approach", tree + Vector2(out.x, out.z) * BENCH_APPROACH)
			seat.set_meta("face", Vector2(out.x, out.z))
		seating.add_child(seat)
	var area := Interactable.new()
	area.name = "Interactable"
	area.collision_layer = 2  # Ebene "interactable"
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 0.8, 2.1)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.0)
	area.add_child(shape)
	seating.add_child(area)
	bench.add_child(seating)
	add_child(bench)


## Feste, unsichtbare Wände zum Garten (seit Etappe 8d): an den Gartenmauern ringsum und entlang des Bachs (man kommt nicht ins
## Wasser und springt nicht hinüber) – außer an der Brücke: Sie hat einen gewölbten Steg mit sanften Rampen an den Enden und
## hohe, unsichtbare Geländer. Rückseiten von Bücherei, Hinterzimmer, Pub und Nachbarn haben eigene Kollisionen.
func _build_backyard_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	add_child(body)
	var h := GameConfig.alley_wall_height
	var t := YARD_WALL_THICKNESS
	var right := StreetLayout.backyard_right_x()
	var left := GameConfig.backyard_left_x
	var back := GameConfig.backyard_back_wall_z
	var front_left := StreetLayout.HOUSE_FRONT + HouseTypes.depth_of(GameConfig.neighbor_house_types[0])
	_add_collider(body, Vector3(right - t, 0.0, _neighbor_back()), Vector3(right, h, back + t))
	_add_collider(body, Vector3(left, 0.0, front_left), Vector3(left + t, h, back + t))
	_add_collider(body, Vector3(right - t, 0.0, back), Vector3(left + t, h, back + t))
	# Bach: Kästen entlang der Mittellinie (nicht unter der Brücke)
	var line := StreetLayout.backyard_stream_line()
	var width := GameConfig.backyard_stream_width
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var mid := (a + b) / 2.0
		if mid.x < right or mid.x > left or _on_bridge(mid, 0.15):
			continue
		_add_turned_collider(body, Vector3(mid.x, h / 2.0, mid.y), Vector3(width - 0.1, h, a.distance_to(b) + 0.08),
			atan2(b.x - a.x, b.y - a.y), 0.0)
	_build_bridge(body)


## Liegt ein Punkt (x/z unter "Outside") auf der Brücke (quer gesehen innerhalb ihrer Breite, längs innerhalb ihrer Länge)?
func _on_bridge(p: Vector2, margin: float) -> bool:
	var turn := deg_to_rad(GameConfig.backyard_bridge_turn)
	var along := Vector2(sin(turn), cos(turn))
	var rel := p - GameConfig.backyard_bridge_center
	return absf(rel.dot(along)) < GameConfig.backyard_bridge_size.x / 2.0 \
		and absf(rel.dot(Vector2(along.y, -along.x))) < GameConfig.backyard_bridge_size.y / 2.0 + margin


## Brücke: gewölbter Steg (Bogen wie im Modell: Höhe rise·(1 - t²) + 0,1, an den Enden etwas weiter bis in den Boden – die Rampen),
## dazu zwei hohe, unsichtbare Geländer.
func _build_bridge(body: StaticBody3D) -> void:
	var center := GameConfig.backyard_bridge_center
	var size := GameConfig.backyard_bridge_size
	var turn := deg_to_rad(GameConfig.backyard_bridge_turn)
	var along := Vector2(sin(turn), cos(turn))
	var half := size.x / 2.0
	var steps := 12
	var t0 := -1.15
	for i in steps:
		var ta := t0 + 2.0 * absf(t0) * i / steps
		var tb := t0 + 2.0 * absf(t0) * (i + 1) / steps
		var pa := center + along * ta * half
		var pb := center + along * tb * half
		var ya := maxf(size.z * (1.0 - ta * ta) + 0.1, 0.0)
		var yb := maxf(size.z * (1.0 - tb * tb) + 0.1, 0.0)
		var mid := (pa + pb) / 2.0
		var run := pa.distance_to(pb)
		var pitch := atan2(yb - ya, run)
		var thick := 0.12
		# Mitte des Kastens: unter der Lauffläche (Oberkante = Lauffläche)
		_add_turned_collider(body, Vector3(mid.x, (ya + yb) / 2.0 - thick / 2.0, mid.y), Vector3(size.y, thick, run / cos(pitch) + 0.02),
			turn, pitch)
	for side: float in [-1.0, 1.0]:
		var offset := Vector2(along.y, -along.x) * side * (size.y / 2.0 + 0.02)
		var c := center + offset
		_add_turned_collider(body, Vector3(c.x, 1.1, c.y), Vector3(0.08, 2.2, size.x * 0.95), turn, 0.0)


## Kasten um die Hochachse gedreht (yaw, Richtung der Länge = +z gedreht) und um die eigene Querachse geneigt (pitch, steigt nach vorn).
func _add_turned_collider(body: StaticBody3D, center: Vector3, size: Vector3, yaw: float, pitch: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch), center)
	body.add_child(collision)


## Holzhäuschen an seinen Platz (Vorderseite mit Tür zum Garten): Modell, Boden innen und Veranda als Kollision auf Höhe des
## Fußbodens, davor eine flache Rampe über die Steinstufe, die Tür in die Öffnung (Punkt „GameSpot_cottage_door“ im Modell:
## Lage, Maße, Tiefe und Breite der Veranda). Die Wände und Verandapfosten bringt das Modell als Kollision mit.
func _build_cottage() -> void:
	if cottage_scene == null:
		return
	var cottage := Node3D.new()
	cottage.name = "Cottage"
	var center := GameConfig.backyard_cottage_center
	# das Modell schaut nach +z (Blender -y); zum Garten soll es nach (-sin, -cos) der Drehung schauen
	cottage.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(GameConfig.backyard_cottage_turn) + PI), Vector3(center.x, 0.0, center.y))
	add_child(cottage)
	var model := cottage_scene.instantiate() as Node3D
	model.name = "Model"
	cottage.add_child(model)
	var spot := model.find_child("GameSpot_cottage_door", true, false) as Node3D
	if spot == null:
		return
	var extras: Dictionary = spot.get_meta("extras", {})
	var at := spot.position
	var floor_y := at.y
	var front := at.z                                   # Außenkante der Vorderwand
	var wall := float(extras.get("wall", 0.14))
	var porch := float(extras.get("porch", 1.0))
	var porch_x := float(extras.get("porch_x", 0.82))
	var size := GameConfig.backyard_cottage_size
	var body := StaticBody3D.new()
	body.name = "CottageFloor"
	cottage.add_child(body)
	_add_turned_collider(body, Vector3(0.0, floor_y / 2.0, 0.0), Vector3(size.x - 2.0 * wall, floor_y, size.y - 2.0 * wall), 0.0, 0.0)
	_add_turned_collider(body, Vector3(0.0, floor_y / 2.0, front - wall / 2.0), Vector3(1.0, floor_y, wall), 0.0, 0.0)  # Schwelle
	_add_turned_collider(body, Vector3(0.0, floor_y / 2.0, front + porch / 2.0), Vector3(2.0 * porch_x + 0.2, floor_y, porch), 0.0, 0.0)
	# Rampe von der Wiese auf die Veranda (über die Stufe hinweg)
	var run := 0.6
	var pitch := atan2(floor_y, run)
	var length := Vector2(run, floor_y).length()
	_add_turned_collider(body, Vector3(0.0, floor_y / 2.0 - 0.02 * cos(pitch), front + porch + run / 2.0), Vector3(1.4, 0.04, length),
		0.0, -pitch)
	var door := cottage_door_scene.instantiate() as Node3D
	door.name = "Door"
	# die Tür geht nach +z ihres Knotens auf (ins Häuschen, Modell -z), draußen ist ihr -z: um 180° gedreht
	door.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(at.x, floor_y, front - wall / 2.0))
	cottage.add_child(door)


## Rückseite des Hauses hinter der Gasse (Pub), z unter "Outside".
func _neighbor_back() -> float:
	var first_house: String = GameConfig.alley_house_types[0] if not GameConfig.alley_house_types.is_empty() else ""
	return StreetLayout.recess_z() + (HouseTypes.depth_of(first_house) if first_house != "" else 0.0)


func _add_collider(body: StaticBody3D, low: Vector3, high: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = high - low
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = (low + high) / 2.0
	body.add_child(collision)


## Hofmauern hinter der Bücherei und hinter dem Nachbarhaus (bis zum Ende der Gasse).
func _build_yard_walls(library_x: float, far_x: float, end: float) -> void:
	var builder := WorldMesh.new()
	var body := StaticBody3D.new()
	body.name = "YardWalls"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	add_child(body)
	var library_back := StreetLayout.HOUSE_BACK
	var first_house: String = GameConfig.alley_house_types[0] if not GameConfig.alley_house_types.is_empty() else ""
	var neighbor_back := StreetLayout.recess_z() + (HouseTypes.depth_of(first_house) if first_house != "" else 0.0)
	var t := YARD_WALL_THICKNESS
	var h := YARD_WALL_HEIGHT
	_add_wall(builder, body, Vector3(library_x, 0.0, library_back), Vector3(library_x + t, h, end))
	_add_wall(builder, body, Vector3(far_x - t, 0.0, neighbor_back), Vector3(far_x, h, end))
	add_child(builder.make_instance("Walls", wall_material, true))


func _add_wall(builder: WorldMesh, body: StaticBody3D, low: Vector3, high: Vector3) -> void:
	if high.z - low.z <= 0.01:
		return
	builder.add_box(low, high, yard_wall_color)
	builder.add_box(Vector3(low.x - 0.03, high.y, low.z), Vector3(high.x + 0.03, high.y + 0.08, high.z),
		yard_wall_color.lightened(0.25))  # Mauerkrone
	var shape := BoxShape3D.new()
	shape.size = high - low
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = (low + high) / 2.0
	body.add_child(collision)
