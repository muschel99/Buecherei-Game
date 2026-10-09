class_name Alley
extends Node3D
## Die schmale Gasse neben der Bücherei (seit Etappe 4d), an der Seite mit der Schräge
## (Seitenwand mit dem Fenster). Sie beginnt am kleinen Platz und führt etwa
## GameConfig.alley_depth Meter nach hinten; Breite GameConfig.alley_width, an der
## Bücherei-Seite ein schmaler Gehweg (GameConfig.alley_sidewalk_width).
##
## Rechts (Bücherei-Seite) begrenzt sie die Hauswand der Bücherei und dahinter eine niedrige
## Hofmauer, links das Nachbarhaus und dahinter ebenfalls eine Hofmauer. Die Hofmauer hinter
## der Bücherei ist nur ein Platzhalter: Wird die Bücherei später nach hinten erweitert,
## tritt der Anbau an ihre Stelle.
## Am Ende steht ein austauschbarer Abschluss (end_scene, z. B. Mauer mit Tor) – er ist fest,
## dahinter kommt man nicht.
## Liegt (wie alles unter "Outside") auf Gehweg-Höhe.

## Wie tief die Fahrgasse unter dem Gehweg liegt (nur optisch).
const LANE_DROP := 0.06
const YARD_WALL_HEIGHT := 2.2
const YARD_WALL_THICKNESS := 0.3

@export var end_scene: PackedScene = preload("res://scenes/world/alley_end.tscn")
@export var lane_material: Material = preload("res://assets/materials/cobblestone.tres")
@export var sidewalk_material: Material = preload("res://assets/materials/sidewalk.tres")
@export var curb_material: Material = preload("res://assets/materials/curb_stone.tres")
@export var wall_material: Material = preload("res://assets/materials/outdoor_colors.tres")
@export var yard_wall_color: Color = Color(0.52, 0.31, 0.25)


func _ready() -> void:
	var library_x := StreetLayout.HOUSE_LEFT
	var far_x := StreetLayout.alley_far_x()
	var walk_x := library_x - GameConfig.alley_sidewalk_width
	var start := StreetLayout.recess_z()
	var end := StreetLayout.alley_end_z()
	var lane := WorldMesh.new()
	var walk := WorldMesh.new()
	var stone := WorldMesh.new()
	lane.add_quad(Vector3(far_x, -LANE_DROP, start), Vector3(walk_x, -LANE_DROP, start),
		Vector3(walk_x, -LANE_DROP, end), Vector3(far_x, -LANE_DROP, end), Vector3.UP, Color.WHITE)
	walk.add_quad(Vector3(walk_x, 0.0, start), Vector3(library_x, 0.0, start),
		Vector3(library_x, 0.0, end), Vector3(walk_x, 0.0, end), Vector3.UP, Color.WHITE)
	# Kanten: Bordstein am Gehweg und kleine Stufe vom Platz in die Gasse
	stone.add_wall(Vector2(walk_x, start), Vector2(walk_x, end), -LANE_DROP, 0.0, Vector3.LEFT, Color.WHITE)
	stone.add_wall(Vector2(far_x, start), Vector2(walk_x, start), -LANE_DROP, 0.0, Vector3.FORWARD, Color.WHITE)
	add_child(lane.make_instance("Lane", lane_material, false))
	add_child(walk.make_instance("Sidewalk", sidewalk_material, false))
	add_child(stone.make_instance("Curb", curb_material, false))
	_build_yard_walls(library_x, far_x, end)
	if end_scene:
		var closing := end_scene.instantiate() as Node3D
		closing.name = "End"
		closing.position = Vector3((library_x + far_x) / 2.0, 0.0, end)
		add_child(closing)


## Hofmauern hinter der Bücherei und hinter dem Nachbarhaus (bis zum Ende der Gasse).
func _build_yard_walls(library_x: float, far_x: float, end: float) -> void:
	var builder := WorldMesh.new()
	var body := StaticBody3D.new()
	body.name = "YardWalls"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	add_child(body)
	var library_back := StreetLayout.HOUSE_BACK
	var neighbor_back := StreetLayout.recess_z() + GameConfig.neighbor_house_depth
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
