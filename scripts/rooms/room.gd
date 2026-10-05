class_name Room
extends Node3D
## Ein Raum des Hauses: verwaltet seine Möbel, Wandfarbe und Boden.
##
## Der Gestaltungsmodus fügt hier Möbel hinzu, verschiebt und entfernt sie.
## Der Raum merkt sich alles im Spielstand (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich Möbel, Wandfarbe oder Boden ändern.
signal layout_changed

## Eindeutiger Name dieses Raums im Spielstand.
@export var save_key: String = "ground_floor_room"
## Wandfarbe und Boden beim allerersten Start (ids aus data/surfaces/).
@export var default_wall_id: String = "wall_warm_plaster"
@export var default_floor_id: String = "floor_oak_planks"
## Innenfläche des Raums (x und z in Metern), in der Möbel stehen dürfen.
@export var build_area: Rect2 = Rect2(-3.0, -4.0, 6.0, 8.0)
## Höhe des Fußbodens.
@export var floor_height: float = 0.0

@onready var furniture_root: Node3D = $Furniture
## Alle Teile, die beim Streichen die Wandfarbe bekommen (inkl. Fenster- und Türlaibung).
@onready var _wall_parts: Array[CSGPrimitive3D] = [
	$Structure/WallLeft,
	$Structure/WallRight,
	$Structure/WallBack,
	$Structure/WallFront/Wall,
	$Structure/WallFront/WindowHole,
	$Structure/WallFront/DoorHole,
]
@onready var _floor_parts: Array[CSGPrimitive3D] = [$Structure/Floor]

var wall_surface_id: String = ""
var floor_surface_id: String = ""
var _next_uid: int = 1


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	for item in get_placed_furniture():
		_assign_uid(item)
	_apply_surface_id(default_wall_id)
	_apply_surface_id(default_floor_id)
	layout_changed.connect(SaveManager.request_save)


# --- Möbel ---

## Alle Möbel, die gerade im Raum stehen.
func get_placed_furniture() -> Array[PlacedFurniture]:
	var result: Array[PlacedFurniture] = []
	for child in furniture_root.get_children():
		if child is PlacedFurniture:
			result.append(child)
	return result


## Stellt ein neues Möbelstück in den Raum (Transform = Position und Drehung in der Welt).
func add_furniture(data: FurnitureData, world_transform: Transform3D, support: PlacedFurniture) -> PlacedFurniture:
	var item := PlacedFurniture.new()
	item.data = data
	item.name = data.get_id().to_pascal_case()
	furniture_root.add_child(item, true)
	item.global_transform = world_transform
	item.support_uid = support.uid if support else 0
	_assign_uid(item)
	layout_changed.emit()
	return item


## Verschiebt ein Möbelstück. Was darauf steht (z. B. eine Vase auf dem Tisch), wandert mit.
func move_furniture(item: PlacedFurniture, world_transform: Transform3D, support: PlacedFurniture) -> void:
	var old_inverse := item.global_transform.affine_inverse()
	for dependent in get_dependents(item):
		var relative := old_inverse * dependent.global_transform
		dependent.global_transform = world_transform * relative
	item.global_transform = world_transform
	item.support_uid = support.uid if support else 0
	layout_changed.emit()


## Entfernt ein Möbelstück samt allem, was darauf steht.
func remove_furniture(item: PlacedFurniture) -> void:
	for dependent in get_dependents(item):
		_free_furniture(dependent)
	_free_furniture(item)
	layout_changed.emit()


## Alles, was (auch indirekt) auf diesem Möbelstück steht.
func get_dependents(item: PlacedFurniture) -> Array[PlacedFurniture]:
	var result: Array[PlacedFurniture] = []
	var all_items := get_placed_furniture()
	var to_check: Array[PlacedFurniture] = [item]
	while not to_check.is_empty():
		var current: PlacedFurniture = to_check.pop_back()
		for other in all_items:
			if other != item and other.support_uid == current.uid and not result.has(other):
				result.append(other)
				to_check.append(other)
	return result


## Liegt dieser Punkt (in Weltkoordinaten) innerhalb der Raumfläche?
func is_inside_build_area(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return build_area.has_point(Vector2(local.x, local.z))


## Anteil jedes Stils an allen Möbeln im Raum (siehe StyleTags.calculate_shares).
func get_style_shares() -> Dictionary:
	var flags_list: Array[int] = []
	for item in get_placed_furniture():
		if item.data:
			flags_list.append(item.data.styles)
	return StyleTags.calculate_shares(flags_list)


# --- Wände und Boden ---

## Streicht alle Wände bzw. tauscht den ganzen Boden.
func apply_surface(surface: SurfaceData) -> void:
	if surface.material == null:
		push_warning("Oberfläche '%s' hat kein Material." % surface.display_name)
		return
	var parts := _wall_parts if surface.kind == SurfaceData.Kind.WALL else _floor_parts
	for part in parts:
		part.material = surface.material
	if surface.kind == SurfaceData.Kind.WALL:
		wall_surface_id = surface.get_id()
	else:
		floor_surface_id = surface.get_id()
	layout_changed.emit()


func _apply_surface_id(id: String) -> void:
	var surface := Catalog.get_surface(id)
	if surface:
		apply_surface(surface)
	elif not id.is_empty():
		push_warning("Raum: Oberfläche '%s' nicht im Katalog gefunden." % id)


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var furniture := []
	for item in get_placed_furniture():
		if item.data == null:
			continue
		furniture.append({
			"uid": item.uid,
			"id": item.data.get_id(),
			"position": [item.position.x, item.position.y, item.position.z],
			"rotation_y": item.rotation.y,
			"support_uid": item.support_uid,
		})
	return {
		"wall": wall_surface_id,
		"floor": floor_surface_id,
		"furniture": furniture,
	}


func load_save_data(save_data: Dictionary) -> void:
	# Möbel aus der Szene entfernen und durch die gespeicherten ersetzen
	for item in get_placed_furniture():
		_free_furniture(item)
	_next_uid = 1

	var entries = save_data.get("furniture", [])
	if entries is Array:
		for entry in entries:
			if entry is Dictionary:
				_load_furniture_entry(entry)

	_apply_surface_id(str(save_data.get("wall", default_wall_id)))
	_apply_surface_id(str(save_data.get("floor", default_floor_id)))
	layout_changed.emit()


func _load_furniture_entry(entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	var data := Catalog.get_furniture(id)
	if data == null:
		push_warning("Spielstand: Möbel '%s' gibt es nicht mehr – wird übersprungen." % id)
		return
	var item := PlacedFurniture.new()
	item.data = data
	item.name = id.to_pascal_case()
	var position_values = entry.get("position", [0, 0, 0])
	if position_values is Array and position_values.size() == 3:
		item.position = Vector3(position_values[0], position_values[1], position_values[2])
	item.rotation.y = float(entry.get("rotation_y", 0.0))
	item.uid = int(entry.get("uid", 0))
	item.support_uid = int(entry.get("support_uid", 0))
	furniture_root.add_child(item, true)
	_assign_uid(item)


func _assign_uid(item: PlacedFurniture) -> void:
	if item.uid <= 0:
		item.uid = _next_uid
	_next_uid = maxi(_next_uid, item.uid + 1)


func _free_furniture(item: PlacedFurniture) -> void:
	furniture_root.remove_child(item)
	item.queue_free()
