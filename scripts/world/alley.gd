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
		_build_backyard_walls()
		_build_bench()
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


## Feste, unsichtbare Wände zum Garten (seit Etappe 8d): an den Gartenmauern ringsum und über dem Bach (man kommt weder ins Wasser
## noch ans andere Ufer). So hoch, dass man auch springend nicht darüber kommt. Rückseiten von Bücherei, Hinterzimmer, Pub und
## Modeladen haben eigene Kollisionen.
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
	var garden_left := GameConfig.backyard_garden_left_x
	var cottage := GameConfig.backyard_cottage_front_z
	var back := GameConfig.backyard_back_wall_z
	var room_back := BackRoom.back_area().end.y + BackRoom.WALL
	_add_collider(body, Vector3(right - t, 0.0, _neighbor_back()), Vector3(right, h, back + t))
	_add_collider(body, Vector3(garden_left, 0.0, room_back - 0.05), Vector3(garden_left + t, h, cottage))
	_add_collider(body, Vector3(garden_left, 0.0, cottage - t), Vector3(left + t, h, cottage))
	_add_collider(body, Vector3(left, 0.0, cottage - t), Vector3(left + t, h, back + t))
	# Bach und das schmale Ufer dahinter
	_add_collider(body, Vector3(right, 0.0, GameConfig.backyard_stream_z - 0.05), Vector3(left, h, back + t))


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
