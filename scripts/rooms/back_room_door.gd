class_name BackRoomDoor
extends Node3D
## Holztür zwischen Laden und Hinterzimmer (seit Testrunde 7b, statt des Vorhangs): Kassettentür mit Knauf, geht mit E auf
## und zu und schwingt ins Hinterzimmer (so bleibt der Platz hinter der Theke frei). Baut sich selbst (BackRoom.build):
## Scharnier an der linken Kante (vom Laden aus), Türblatt mit Kollision, E-Bereich. Kein Mitglied der Gruppe "doors" –
## das ist die Ladentür (Besucher, Katzen, Schild).

const LEAF_THICKNESS := 0.04
const OPEN_ANGLE := 100.0
const WOOD := Color(0.58, 0.38, 0.22)
const PANEL := Color(0.36, 0.22, 0.13)
const KNOB := Color(0.72, 0.58, 0.3)

var width := 0.95
var height := 2.15
var is_open := false
var _hinge: Node3D
var _interactable: Interactable
var _tween: Tween


## Tür in die Öffnung setzen: x = Mitte der Öffnung, z = Fläche der Wand, zu der sie aufgeht (Raumkoordinaten).
func setup(door_width: float, door_height: float) -> void:
	width = door_width - 0.006
	height = door_height - 0.006
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-width / 2.0, 0.0, 0.0)
	add_child(_hinge)
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(width / 2.0, 0.0, 0.0)
	_hinge.add_child(leaf)
	var wood := _material(WOOD, 0.75)
	var panel := _material(PANEL, 0.8)
	# Blatt: Rahmen mit vier vertieften Kassetten (von beiden Seiten)
	leaf.add_child(_box(Vector3(width, height, LEAF_THICKNESS * 0.6), Vector3(0, height / 2.0, 0), panel))
	var rail := 0.1
	for piece: Array in [[Vector3(rail, height, LEAF_THICKNESS), Vector3(-width / 2.0 + rail / 2.0, height / 2.0, 0)],
			[Vector3(rail, height, LEAF_THICKNESS), Vector3(width / 2.0 - rail / 2.0, height / 2.0, 0)],
			[Vector3(width - rail * 2.0, rail, LEAF_THICKNESS), Vector3(0, height - rail / 2.0, 0)],
			[Vector3(width - rail * 2.0, rail * 1.6, LEAF_THICKNESS), Vector3(0, rail * 0.8, 0)],
			[Vector3(width - rail * 2.0, rail * 0.8, LEAF_THICKNESS), Vector3(0, height * 0.52, 0)],
			[Vector3(rail * 0.7, height - rail * 2.6, LEAF_THICKNESS), Vector3(0, height * 0.5 + rail * 0.3, 0)]]:
		leaf.add_child(_box(piece[0], piece[1], wood))
	# Knauf auf beiden Seiten (an der Kante gegenüber dem Scharnier)
	for side: float in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.028
		sphere.height = 0.05
		knob.mesh = sphere
		knob.material_override = _material(KNOB, 0.35, 0.8)
		knob.position = Vector3(width / 2.0 - 0.08, 1.0, side * (LEAF_THICKNESS / 2.0 + 0.03))
		leaf.add_child(knob)
	# Kollision: die Spielfigur geht nicht durch die geschlossene Tür
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, LEAF_THICKNESS)
	shape.shape = box
	shape.position = Vector3(0, height / 2.0, 0)
	body.add_child(shape)
	leaf.add_child(body)
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(width, height, 0.2)
	area_shape.shape = area_box
	area_shape.position = Vector3(width / 2.0, height / 2.0, 0)
	_interactable.add_child(area_shape)
	_hinge.add_child(_interactable)
	_interactable.interacted.connect(func(_who: Node) -> void: set_open(not is_open))
	_update_prompt()


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween:
		_tween.kill()
	Audio.play_at("doors/door_open" if open else "doors/door_close", global_position + Vector3.UP, -4.0, Audio.vary(0.05))
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# +z = ins Hinterzimmer: Drehung um die Hochachse nach rechts
	_tween.tween_property(_hinge, "rotation:y", -deg_to_rad(OPEN_ANGLE) if open else 0.0, GameConfig.door_open_time)
	_update_prompt()


func _update_prompt() -> void:
	_interactable.prompt_text = "Schließen" if is_open else "Öffnen"


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	return mesh


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
