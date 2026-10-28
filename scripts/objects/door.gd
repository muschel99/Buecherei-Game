class_name Door
extends Node3D
## Eine Tür, die sich mit E öffnen und schließen lässt.
##
## Aufbau der Szene: Der Knoten "Hinge" (Scharnier) liegt an der Drehachse der Tür.
## Alles, was mitschwingen soll (Türblatt, Klinken, Interactable), hängt darunter.
## Die Tür öffnet sich nach innen (in den Raum). Winkel und Dauer: GameConfig.
##
## Dinge, die an der Tür hängen (z. B. ein Türkranz), schwingen mit. Dafür wird nur ihr
## Modell bewegt – ihre gespeicherte Position bleibt die bei geschlossener Tür.
## Eine offene Tür bleibt auch im Gestaltungsmodus offen (man kommt weiter durch); solange sie
## offen ist, hängt man dort nichts auf und nimmt nichts ab (siehe is_swinging).

## Öffnungsrichtung: 1 = Klinkenseite schwingt nach +Z (in den Raum), -1 = nach -Z.
@export var open_direction: float = 1.0

@onready var _hinge: Node3D = $Hinge
@onready var _leaf: Node3D = $Hinge/DoorLeaf
@onready var _interactable: Interactable = $Hinge/Interactable

var is_open: bool = false

var _closed_hinge: Transform3D
var _tween: Tween
var _hung_items: Array[PlacedFurniture] = []


func _ready() -> void:
	add_to_group("doors")
	_closed_hinge = _hinge.transform
	_interactable.interacted.connect(_on_interacted)
	_update_prompt()


func _on_interacted(_interactor: Node) -> void:
	set_open(not is_open)


## Öffnet oder schließt die Tür (sanft).
func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if open:
		_hung_items = _find_hung_items()
	if _tween:
		_tween.kill()
	var target := deg_to_rad(GameConfig.door_open_angle * open_direction) if open else 0.0
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_angle, _hinge.rotation.y, target, GameConfig.door_open_time)
	_update_prompt()


## Schließt die Tür sofort (z. B. beim Öffnen des Gestaltungsmodus).
func close_instantly() -> void:
	if _tween:
		_tween.kill()
	is_open = false
	_set_angle(0.0)
	_update_prompt()


func _set_angle(angle: float) -> void:
	_hinge.transform = _closed_hinge.rotated_local(Vector3.UP, angle)
	# Was an der Tür hängt, schwingt mit
	var swing := global_transform * _hinge.transform * (global_transform * _closed_hinge).affine_inverse()
	for item in _hung_items:
		var model := item.get_model() if is_instance_valid(item) else null
		if model:
			model.transform = item.global_transform.affine_inverse() * swing * item.global_transform
	if is_zero_approx(angle):
		for item in _hung_items:
			if is_instance_valid(item) and item.get_model():
				item.get_model().transform = Transform3D.IDENTITY
		_hung_items.clear()


## Hängt dieses Möbelstück gerade an der offenen Tür (schwingt mit)? Auch, solange die Tür
## noch zugeht – erst wenn sie ganz zu ist, hängt es wieder still.
func is_swinging(item: PlacedFurniture) -> bool:
	return _hung_items.has(item)


## Ist die Tür offen oder noch in Bewegung (nicht ganz zu)?
func is_ajar() -> bool:
	return is_open or not is_zero_approx(_hinge.rotation.y)


## Gehört dieser Körper zum Türblatt?
func is_leaf(collider: Object) -> bool:
	return collider == _leaf


## Türblatt aus der Fassade (seit Etappe 6b, LibraryFacade): ein eigenes Modell statt des einfachen
## Blatts (Scharnier-Koordinaten: Drehachse bei x = 0, Blatt nach -x, draußen -z), Fläche
## „facade_door“ in der Türfarbe. Die Kollision (DoorLeaf) bleibt – nur ihre Optik wird ausgeblendet.
## Leerer Pfad = das einfache Blatt der Szene.
func set_leaf(path: String, color: Color) -> void:
	var hinge := get_node("Hinge") as Node3D
	var old := hinge.get_node_or_null("LeafModel")
	if old:
		hinge.remove_child(old)
		old.queue_free()
	var builtin := path.is_empty() or not ResourceLoader.exists(path)
	for part in ["DoorLeaf", "LeafGlass", "LeafMuntinV", "LeafMuntinH", "Knob", "KnobOutside"]:
		var node := hinge.get_node_or_null(part) as Node3D
		if node:
			node.visible = builtin
	if builtin:
		return
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = "LeafModel"
	hinge.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i)
			if material and material.resource_name == "facade_door":
				mesh_instance.set_surface_override_material(i, FurnitureUtils.tinted_material(material, color))


func _update_prompt() -> void:
	_interactable.prompt_text = "Schließen" if is_open else "Öffnen"


## Alle Möbel, die bei geschlossener Tür am Türblatt hängen.
func _find_hung_items() -> Array[PlacedFurniture]:
	var result: Array[PlacedFurniture] = []
	var room := get_parent() as Room
	if room == null:
		return result
	var leaf_shape := _leaf as CSGBox3D
	var closed_leaf := global_transform * _closed_hinge * _leaf.transform
	var half: Vector3 = leaf_shape.size / 2.0 if leaf_shape else Vector3(0.5, 1.1, 0.03)
	for item in room.get_placed_furniture():
		if item.data == null or not item.data.allows(FurnitureData.PLACE_DOOR):
			continue
		var local := closed_leaf.affine_inverse() * item.global_position
		if absf(local.x) <= half.x + 0.02 and absf(local.y) <= half.y + 0.02 and absf(local.z) <= half.z + 0.03:
			result.append(item)
	return result
