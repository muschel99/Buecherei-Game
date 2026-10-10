class_name AlleyEnd
extends Node3D
## Abschluss am Ende der Gasse (seit Etappe 4d, Platzhalter): eine Backsteinmauer mit einem
## geschlossenen Holztor, dahinter ein Haus als Kulisse. Die Mauer ist fest – hier endet die
## Gasse.
##
## Ursprung: unten in der Mitte der Gasse an ihrem Ende; die Mauer steht dahinter (+Z), ihre
## Vorderseite zeigt in die Gasse (-Z). Eigenes Modell: Kind-Knoten "Model" anlegen – dann
## baut das Script keinen Platzhalter (die Kollision der Mauer bleibt).

## Breite der Gasse (0 = GameConfig.alley_width, die Gasse neben der Bücherei).
@export var width: float = 0.0
@export var wall_height: float = 2.6
@export var wall_color: Color = Color(0.5, 0.3, 0.24)
@export var gate_color: Color = Color(0.32, 0.22, 0.15)
@export var trim_color: Color = Color(0.86, 0.84, 0.78)
@export var material: Material = preload("res://assets/materials/outdoor_colors.tres")
## Haus hinter der Mauer (Kulisse, damit man über der Mauer nicht ins Leere schaut).
@export var house_scene: PackedScene = preload("res://scenes/world/house_facade.tscn")

const THICKNESS := 0.3
const GATE_WIDTH := 1.8
const GATE_HEIGHT := 2.0


func _ready() -> void:
	var alley_width := width if width > 0.0 else GameConfig.alley_width
	var half := alley_width / 2.0 + THICKNESS
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(half * 2.0, wall_height, THICKNESS)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, wall_height / 2.0, THICKNESS / 2.0)
	body.add_child(collision)
	add_child(body)
	if get_node_or_null("Model") != null:
		return
	var builder := WorldMesh.new()
	builder.add_box(Vector3(-half, 0.0, 0.0), Vector3(half, wall_height, THICKNESS), wall_color)
	builder.add_box(Vector3(-half - 0.03, wall_height, -0.03), Vector3(half + 0.03, wall_height + 0.08, THICKNESS + 0.03),
		wall_color.lightened(0.25))
	# Holztor (zwei Flügel) mit hellem Rahmen
	var g := GATE_WIDTH / 2.0
	var skip := PackedStringArray(["bottom", "front"])
	builder.add_box(Vector3(-g, 0.0, -0.04), Vector3(-0.01, GATE_HEIGHT, 0.0), gate_color, skip)
	builder.add_box(Vector3(0.01, 0.0, -0.04), Vector3(g, GATE_HEIGHT, 0.0), gate_color, skip)
	builder.add_box(Vector3(-g - 0.08, 0.0, -0.05), Vector3(-g, GATE_HEIGHT + 0.08, 0.0), trim_color, skip)
	builder.add_box(Vector3(g, 0.0, -0.05), Vector3(g + 0.08, GATE_HEIGHT + 0.08, 0.0), trim_color, skip)
	builder.add_box(Vector3(-g, GATE_HEIGHT, -0.05), Vector3(g, GATE_HEIGHT + 0.08, 0.0), trim_color, skip)
	add_child(builder.make_instance("Placeholder", material, false))
	if house_scene:
		var house := house_scene.instantiate() as HouseFacade
		house.name = "HouseBehind"
		house.position = Vector3(0.0, 0.0, 3.0)
		house.rotation.y = PI  # Vorderseite zur Gasse
		house.width = alley_width + 6.0
		house.depth = 6.0
		house.eaves_height = 6.4
		house.wall_color = Color(0.74, 0.7, 0.62)
		house.door_side = 0
		house.casts_shadow = false
		house.solid = false
		add_child(house)
