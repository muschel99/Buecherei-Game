class_name OppositeAlley
extends Node3D
## Kleine Gasse in der Häuserreihe gegenüber (seit Etappe 4f): eine schmale Lücke zwischen zwei
## Häusern, damit die lange Front nicht so einheitlich wirkt. Mit denselben großen Platten
## belegt wie der Gehweg, begehbar bis an den Abschluss am Ende (Mauer mit Tor und einem Haus
## dahinter, dieselbe austauschbare Szene wie bei der Gasse neben der Bücherei).
## Lage und Maße: GameConfig.opposite_alley_x, opposite_alley_width, opposite_alley_depth;
## die Häuser links und rechts lässt HousesLayout dafür frei (houses.tscn neu erzeugen).
## Liegt (wie alles unter "Outside") auf Gehweg-Höhe. Die Seitenwände sind die Nachbarhäuser.

@export var end_scene: PackedScene = preload("res://scenes/world/alley_end.tscn")
@export var paving_material: Material = preload("res://assets/materials/sidewalk.tres")
## Stil-Modell (seit Etappe 4g, tools/blender/build_alleys.py): hinter dem Ende verläuft sich die
## Gasse zwischen Steinbögen. Ist es da, ersetzt es den Abschluss; am Ende bleibt eine
## unsichtbare Grenze.
@export var model_scene: PackedScene = preload("res://assets/models/world/alley_opposite.glb")


func _ready() -> void:
	var span := StreetLayout.opposite_alley()
	if span == Vector2.ZERO:
		return
	var start := StreetLayout.opposite_front_z()
	var end := StreetLayout.opposite_alley_end_z()
	var paving := WorldMesh.new()
	# Die Platten reichen 5 cm unter die Häuser, damit an den Wänden keine Fuge bleibt
	paving.add_quad(Vector3(span.x - 0.05, 0.0, end), Vector3(span.y + 0.05, 0.0, end),
		Vector3(span.y + 0.05, 0.0, start), Vector3(span.x - 0.05, 0.0, start), Vector3.UP, Color.WHITE)
	add_child(paving.make_instance("Paving", paving_material, false))
	if model_scene:
		var model := model_scene.instantiate()
		model.name = "Model"
		add_child(model)
		var body := StaticBody3D.new()
		body.name = "EndBound"
		body.collision_layer = 1  # Ebene "world"
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = Vector3(span.y - span.x + 0.6, 4.0, 0.3)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3((span.x + span.y) / 2.0, 2.0, end - 0.15)
		body.add_child(collision)
		add_child(body)
	elif end_scene:
		var closing := end_scene.instantiate() as Node3D
		closing.name = "End"
		closing.set("width", span.y - span.x)
		closing.position = Vector3((span.x + span.y) / 2.0, 0.0, end)
		closing.rotation.y = PI  # Mauer hinter dem Ende, Vorderseite zur Gasse (+Z)
		add_child(closing)
	# Fester Punkt vor dem Tor: Hier erscheinen und verschwinden Passanten (StreetLife, seit
	# Etappe 5a) – nur, wenn es gerade niemand sieht
	var spot := StreetPaths.opposite_alley_points()[0]
	var marker := Marker3D.new()
	marker.name = "TrafficPoint"
	marker.position = Vector3(spot.x, 0.0, spot.y)
	marker.set_meta("kind", "walker")
	marker.set_meta("place", "opposite_alley")
	marker.add_to_group(Street.TRAFFIC_GROUP)
	add_child(marker)
