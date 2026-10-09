class_name HouseFacade
extends Node3D
## Platzhalter für ein Nachbarhaus (seit Etappe 4d): reine Kulisse, nicht betretbar.
## Ein schlichter Hauskörper mit Fenstern, Tür, Sockel und Satteldach (First parallel zur
## Straße), auf Wunsch mit Schornstein. Alles ist EIN Mesh mit Farben (ein Material) – das
## spart Rechenleistung, auch wenn viele Häuser in der Straße stehen.
##
## Ursprung: unten in der Mitte der Vorderseite (auf Gehweg-Höhe). Die Vorderseite zeigt nach
## +Z, das Haus reicht nach -Z (Tiefe). Wo die Häuser stehen, legt scripts/world/houses.gd fest.
##
## Eigenes Modell: Einen Knoten "Model" (z. B. eine .glb-Szene) als Kind anlegen – dann baut
## das Script keinen Platzhalter, die Kollision (Kasten so groß wie der Hauskörper) bleibt.

@export var width: float = 5.0
@export var depth: float = 8.0
## Höhe der Traufe (Unterkante des Dachs) über dem Gehweg.
@export var eaves_height: float = 6.6
## So viele Geschosse (Fensterreihen).
@export var storeys: int = 2
## So viele Fenster nebeneinander (0 = so viele, wie gut passen).
@export var window_columns: int = 0
## Tür im Erdgeschoss: -1 = links, 0 = keine, 1 = rechts (von vorn gesehen).
@export var door_side: int = 1
## So hoch steigt das Dach bis zum First.
@export var roof_rise: float = 2.0
@export var chimney: bool = true
@export var plinth_height: float = 0.35
@export var plinth_proud: float = 0.03
## Wirft das Haus Sonnenschatten? (Häuser weit weg oder gegenüber besser nicht.)
@export var casts_shadow: bool = true
## Hat das Haus eine feste Kollision (Spielfigur läuft nicht hindurch)?
@export var solid: bool = true

@export_group("Farben")
@export var wall_color: Color = Color(0.55, 0.3, 0.24)
@export var trim_color: Color = Color(0.93, 0.91, 0.86)
@export var door_color: Color = Color(0.18, 0.28, 0.42)
@export var roof_color: Color = Color(0.3, 0.31, 0.34)
@export var plinth_color: Color = Color(0.38, 0.36, 0.34)
@export var glass_color: Color = Color(0.3, 0.34, 0.38)

@export var material: Material = preload("res://assets/materials/outdoor_colors.tres")

const WINDOW_WIDTH := 0.95
const WINDOW_HEIGHT := 1.45
const DOOR_WIDTH := 1.0
const DOOR_HEIGHT := 2.15
const FRAME := 0.07


func _ready() -> void:
	if solid:
		_build_collision()
	if get_node_or_null("Model") == null:
		var builder := WorldMesh.new()
		_build_body(builder)
		_build_front(builder)
		_build_roof(builder)
		var mesh := builder.make_instance("Placeholder", material, casts_shadow)
		if mesh:
			add_child(mesh)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1  # Ebene "world"
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, eaves_height, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, eaves_height / 2.0, -depth / 2.0)
	body.add_child(collision)
	add_child(body)


## Hauswände (vorn, an den Seiten, hinten) und der Sockel vorn.
func _build_body(builder: WorldMesh) -> void:
	var w := width / 2.0
	builder.add_box(Vector3(-w, 0.0, -depth), Vector3(w, eaves_height, 0.0), wall_color,
		PackedStringArray(["bottom", "top"]))
	if plinth_height > 0.0:
		var door := _door_range()
		var low := Vector3(-w, 0.0, 0.0)
		var high := Vector3(w, plinth_height, plinth_proud)
		if door == Vector2.ZERO:
			builder.add_box(low, high, plinth_color, PackedStringArray(["bottom", "back"]))
		else:
			# An der Tür ist der Sockel unterbrochen
			builder.add_box(low, Vector3(door.x, high.y, high.z), plinth_color, PackedStringArray(["bottom", "back"]))
			builder.add_box(Vector3(door.y, 0.0, 0.0), high, plinth_color, PackedStringArray(["bottom", "back"]))


## Fenster und Tür auf der Vorderseite (flach aufgesetzt, leicht vorstehend).
func _build_front(builder: WorldMesh) -> void:
	var columns := _column_count()
	var storey_height := eaves_height / maxf(1.0, storeys)
	for storey in storeys:
		var center_y := storey * storey_height + storey_height * 0.5 + (0.1 if storey == 0 else 0.0)
		for column in columns:
			var x := _column_x(column, columns)
			if storey == 0 and _is_door_column(column, columns):
				_add_door(builder, x)
			else:
				_add_window(builder, x, center_y)


func _add_window(builder: WorldMesh, x: float, center_y: float) -> void:
	var hw := WINDOW_WIDTH / 2.0
	var hh := WINDOW_HEIGHT / 2.0
	builder.add_quad(Vector3(x - hw, center_y - hh, 0.01), Vector3(x + hw, center_y - hh, 0.01),
		Vector3(x + hw, center_y + hh, 0.01), Vector3(x - hw, center_y + hh, 0.01), Vector3.BACK, glass_color)
	var skip := PackedStringArray(["bottom", "back"])
	# Rahmen rundherum, Sprossenkreuz, Fensterbank
	builder.add_box(Vector3(x - hw - FRAME, center_y - hh, 0.0), Vector3(x - hw, center_y + hh, 0.05), trim_color, skip)
	builder.add_box(Vector3(x + hw, center_y - hh, 0.0), Vector3(x + hw + FRAME, center_y + hh, 0.05), trim_color, skip)
	builder.add_box(Vector3(x - hw - FRAME, center_y + hh, 0.0), Vector3(x + hw + FRAME, center_y + hh + FRAME, 0.05), trim_color, skip)
	builder.add_box(Vector3(x - 0.02, center_y - hh, 0.0), Vector3(x + 0.02, center_y + hh, 0.03), trim_color, skip)
	builder.add_box(Vector3(x - hw, center_y - 0.02, 0.0), Vector3(x + hw, center_y + 0.02, 0.028), trim_color, skip)
	builder.add_box(Vector3(x - hw - FRAME - 0.04, center_y - hh - 0.06, 0.0),
		Vector3(x + hw + FRAME + 0.04, center_y - hh, 0.09), trim_color, PackedStringArray(["back"]))


func _add_door(builder: WorldMesh, x: float) -> void:
	var hw := DOOR_WIDTH / 2.0
	builder.add_quad(Vector3(x - hw, 0.0, 0.012), Vector3(x + hw, 0.0, 0.012),
		Vector3(x + hw, DOOR_HEIGHT, 0.012), Vector3(x - hw, DOOR_HEIGHT, 0.012), Vector3.BACK, door_color)
	var skip := PackedStringArray(["bottom", "back"])
	builder.add_box(Vector3(x - hw - FRAME, 0.0, 0.0), Vector3(x - hw, DOOR_HEIGHT + FRAME, 0.06), trim_color, skip)
	builder.add_box(Vector3(x + hw, 0.0, 0.0), Vector3(x + hw + FRAME, DOOR_HEIGHT + FRAME, 0.06), trim_color, skip)
	builder.add_box(Vector3(x - hw, DOOR_HEIGHT, 0.0), Vector3(x + hw, DOOR_HEIGHT + FRAME, 0.06), trim_color, skip)
	# Oberlicht über der Tür
	builder.add_quad(Vector3(x - hw, DOOR_HEIGHT + FRAME, 0.01), Vector3(x + hw, DOOR_HEIGHT + FRAME, 0.01),
		Vector3(x + hw, DOOR_HEIGHT + FRAME + 0.35, 0.01), Vector3(x - hw, DOOR_HEIGHT + FRAME + 0.35, 0.01),
		Vector3.BACK, glass_color)
	builder.add_box(Vector3(x - hw - FRAME, DOOR_HEIGHT + FRAME + 0.35, 0.0),
		Vector3(x + hw + FRAME, DOOR_HEIGHT + 2.0 * FRAME + 0.35, 0.06), trim_color, skip)


## Satteldach: First parallel zur Vorderseite, Giebeldreiecke an den Seiten, weiße Traufkante
## vorn und hinten, auf Wunsch ein Schornstein.
func _build_roof(builder: WorldMesh) -> void:
	var w := width / 2.0
	var overhang := 0.2
	var base := eaves_height
	var ridge_y := base + roof_rise
	var ridge_z := -depth / 2.0
	var front_low := Vector3(0.0, base, overhang)
	var back_low := Vector3(0.0, base, -depth - overhang)
	var ridge := Vector3(0.0, ridge_y, ridge_z)
	var front_normal := Vector3(0.0, depth / 2.0 + overhang, roof_rise).normalized()
	var back_normal := Vector3(0.0, depth / 2.0 + overhang, -roof_rise).normalized()
	builder.add_quad(Vector3(-w, front_low.y, front_low.z), Vector3(w, front_low.y, front_low.z),
		Vector3(w, ridge.y, ridge.z), Vector3(-w, ridge.y, ridge.z), front_normal, roof_color)
	builder.add_quad(Vector3(-w, back_low.y, back_low.z), Vector3(w, back_low.y, back_low.z),
		Vector3(w, ridge.y, ridge.z), Vector3(-w, ridge.y, ridge.z), back_normal, roof_color)
	# Giebel (Wandfarbe)
	for side in [-1.0, 1.0]:
		var x: float = side * w
		builder.add_triangle(Vector3(x, base, 0.0), Vector3(x, base, -depth), Vector3(x, ridge_y, ridge_z),
			Vector3(side, 0.0, 0.0), wall_color)
	# Traufkante
	builder.add_box(Vector3(-w, base - 0.18, 0.0), Vector3(w, base, overhang), trim_color, PackedStringArray(["top"]))
	builder.add_box(Vector3(-w, base - 0.18, -depth - overhang), Vector3(w, base, -depth), trim_color, PackedStringArray(["top"]))
	if chimney:
		var cx := w - 0.7 if door_side >= 0 else -w + 0.7
		builder.add_box(Vector3(cx - 0.3, ridge_y - 0.6, ridge_z - 0.35), Vector3(cx + 0.3, ridge_y + 0.9, ridge_z + 0.35),
			wall_color.darkened(0.15))
		builder.add_box(Vector3(cx - 0.36, ridge_y + 0.9, ridge_z - 0.41), Vector3(cx + 0.36, ridge_y + 0.98, ridge_z + 0.41),
			trim_color.darkened(0.2))


func _column_count() -> int:
	if window_columns > 0:
		return window_columns
	return maxi(1, floori(width / 1.7))


## Mitte einer Fensterspalte (gleichmäßig verteilt).
func _column_x(column: int, columns: int) -> float:
	return -width / 2.0 + width * (column + 0.5) / columns


func _is_door_column(column: int, columns: int) -> bool:
	if door_side == 0:
		return false
	return column == (columns - 1 if door_side > 0 else 0)


## Wo die Tür liegt (x von – bis), oder Vector2.ZERO ohne Tür.
func _door_range() -> Vector2:
	if door_side == 0:
		return Vector2.ZERO
	var columns := _column_count()
	var x := _column_x(columns - 1 if door_side > 0 else 0, columns)
	return Vector2(x - DOOR_WIDTH / 2.0 - FRAME, x + DOOR_WIDTH / 2.0 + FRAME)
