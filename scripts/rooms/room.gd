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
## Wandfarbe, Boden und Decke beim allerersten Start (ids aus data/surfaces/).
@export var default_wall_id: String = "wall_warm_plaster"
@export var default_floor_id: String = "floor_oak_planks"
@export var default_ceiling_id: String = "ceiling_warm_white"
## Innenfläche des Raums (x und z in Metern), in der Möbel stehen dürfen.
@export var build_area: Rect2 = Rect2(-3.0, -4.0, 6.0, 8.0)
## Höhe des Fußbodens.
@export var floor_height: float = 0.0

@onready var furniture_root: Node3D = $Furniture
## Die Wände, die in Abschnitten gestrichen werden können.
@onready var _walls: Array[PaintableWall] = [$Walls/Left, $Walls/Right, $Walls/Back, $Walls/Front]
## Boden und Decke, die in Abschnitten gestaltet werden können.
@onready var _grids := {
	SurfaceData.Kind.FLOOR: $FloorCovering as PaintableGrid,
	SurfaceData.Kind.CEILING: $CeilingCovering as PaintableGrid,
}
## Fenster- und Türlaibung: bekommen die Farbe des Wandabschnitts, in dem sie liegen.
@onready var _reveals: Array[CSGPrimitive3D] = [$Structure/WallFront/WindowHole, $Structure/WallFront/DoorHole]
@onready var _reveal_wall: PaintableWall = $Walls/Front
## Hier darf man etwas aufhängen (Wandbilder, Lichtschalter …).
@onready var _hang_walls: Array[Node] = [
	$Structure/WallLeft,
	$Structure/WallRight,
	$Structure/WallBack,
	$Structure/WallFront,
]
## Hier darf man etwas an die Tür hängen (z. B. einen Türkranz).
@onready var _hang_doors: Array[Node] = [$Door/DoorLeaf]

## Wohin etwas gehängt werden kann (gleiche Werte wie FurnitureData.placement).
enum HangKind { NONE = 0, WALL = 4, DOOR = 8 }

var _next_uid: int = 1


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	for item in get_placed_furniture():
		_assign_uid(item)
	_paint_everything(default_wall_id)
	_paint_everything(default_floor_id)
	_paint_everything(default_ceiling_id)
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


## Alle Lampen im Raum, die sich schalten lassen (für den Lichtschalter).
## Als Lampe zählt jedes Möbelstück, dessen Modell set_on() und is_on hat.
func get_lamps() -> Array[Node]:
	var lamps: Array[Node] = []
	for item in get_placed_furniture():
		var model := item.get_model()
		if model and model.has_method("set_on"):
			lamps.append(model)
	return lamps


## Liegt dieser Punkt (in Weltkoordinaten) innerhalb der Raumfläche?
func is_inside_build_area(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return build_area.has_point(Vector2(local.x, local.z))


## Ist der getroffene Kollisionskörper eine Wand oder die Tür dieses Raums?
func get_hang_kind(collider: Object) -> HangKind:
	if _hang_walls.has(collider):
		return HangKind.WALL
	if _hang_doors.has(collider):
		return HangKind.DOOR
	return HangKind.NONE


## Anteil jedes Stils im Raum (siehe StyleTags.calculate_shares).
## Stilneutrale Dinge (ohne Stil-Merkmal) zählen nicht mit.
func get_style_shares() -> Dictionary:
	var flags_list: Array[int] = []
	for item in get_placed_furniture():
		if item.data:
			flags_list.append(item.data.styles)
	# Wandfarben, Böden und Decken: jede verwendete Oberfläche mit Stil zählt einmal
	for id in _get_used_surface_ids():
		var surface := Catalog.get_surface(id)
		if surface:
			flags_list.append(surface.styles)
	return StyleTags.calculate_shares(flags_list)


## Alle Oberflächen (ids), die gerade irgendwo im Raum zu sehen sind.
func _get_used_surface_ids() -> Array[String]:
	var ids: Array[String] = []
	var all_ids: Array[String] = []
	for wall in _walls:
		all_ids.append_array(wall.segment_ids)
	for grid: PaintableGrid in _grids.values():
		all_ids.append_array(grid.cell_ids)
	for id in all_ids:
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	return ids


# --- Wände und Boden ---

## Welcher Wandabschnitt liegt an diesem Punkt? Ergebnis: { "wall": PaintableWall,
## "index": Nummer } – oder leer, wenn der Punkt auf keiner streichbaren Wand liegt.
func find_wall_segment(world_point: Vector3) -> Dictionary:
	for wall in _walls:
		var index := wall.get_segment_at(world_point)
		if index >= 0:
			return {"wall": wall, "index": index}
	return {}


## Welcher Boden- bzw. Deckenabschnitt liegt an diesem Punkt? (-1 = keiner)
func find_grid_cell(kind: SurfaceData.Kind, world_point: Vector3) -> int:
	return (_grids[kind] as PaintableGrid).get_cell_at(world_point)


## Streicht einen Wandabschnitt.
func paint_wall_segment(wall: PaintableWall, index: int, surface: SurfaceData) -> void:
	wall.paint_segment(index, surface)
	_update_reveals()
	layout_changed.emit()


## Streicht eine ganze Wand.
func paint_wall(wall: PaintableWall, surface: SurfaceData) -> void:
	for index in wall.get_segment_count():
		wall.paint_segment(index, surface)
	_update_reveals()
	layout_changed.emit()


## Gestaltet einen Boden- bzw. Deckenabschnitt (je nach Art der Oberfläche).
func paint_grid_cell(index: int, surface: SurfaceData) -> void:
	(_grids[surface.kind] as PaintableGrid).paint_cells([index], surface)
	layout_changed.emit()


## Gestaltet den ganzen Boden bzw. die ganze Decke.
func paint_grid(surface: SurfaceData) -> void:
	(_grids[surface.kind] as PaintableGrid).paint_all(surface)
	layout_changed.emit()


## Streicht alle Wände bzw. gestaltet den ganzen Boden / die ganze Decke.
func _paint_everything(id: String) -> void:
	var surface := Catalog.get_surface(id)
	if surface == null:
		if not id.is_empty():
			push_warning("Raum: Oberfläche '%s' nicht im Katalog gefunden." % id)
		return
	if surface.kind == SurfaceData.Kind.WALL:
		for wall in _walls:
			for index in wall.get_segment_count():
				wall.paint_segment(index, surface)
		_update_reveals()
	else:
		(_grids[surface.kind] as PaintableGrid).paint_all(surface)


## Fenster- und Türlaibung in der Farbe des Abschnitts streichen, in dem sie liegen.
func _update_reveals() -> void:
	for reveal in _reveals:
		var x := _reveal_wall.to_local(reveal.global_position).x
		var surface := Catalog.get_surface(_reveal_wall.segment_ids[_reveal_wall.get_segment_index_at_x(x)])
		if surface:
			reveal.material = surface.material


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
	var walls := {}
	for wall in _walls:
		walls[wall.name] = wall.segment_ids.duplicate()
	return {
		"walls": walls,
		"floor": _grid_save_data(_grids[SurfaceData.Kind.FLOOR]),
		"ceiling": _grid_save_data(_grids[SurfaceData.Kind.CEILING]),
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

	_load_walls(save_data)
	_load_grid(save_data.get("floor"), _grids[SurfaceData.Kind.FLOOR], default_floor_id)
	_load_grid(save_data.get("ceiling"), _grids[SurfaceData.Kind.CEILING], default_ceiling_id)
	layout_changed.emit()


func _load_walls(save_data: Dictionary) -> void:
	_paint_everything(default_wall_id)
	var walls = save_data.get("walls")
	if walls is Dictionary:
		for wall in _walls:
			var ids = walls.get(wall.name)
			if ids is Array:
				for index in mini(ids.size(), wall.get_segment_count()):
					var surface := Catalog.get_surface(str(ids[index]))
					if surface:
						wall.paint_segment(index, surface)
	elif save_data.get("wall") is String:
		_paint_everything(save_data["wall"])  # Spielstand aus Etappe 2
	_update_reveals()


func _grid_save_data(grid: PaintableGrid) -> Dictionary:
	return {"columns": grid.columns, "rows": grid.rows, "cells": _compress(grid.cell_ids)}


func _load_grid(grid_data, grid: PaintableGrid, default_id: String) -> void:
	_paint_everything(default_id)
	if grid_data is Dictionary:
		var cells := _decompress(grid_data.get("cells", []))
		var old_columns := int(grid_data.get("columns", 0))
		var old_rows := int(grid_data.get("rows", 0))
		if old_columns > 0 and cells.size() == old_columns * old_rows:
			# Klappt auch, wenn sich die Abschnittsgröße seit dem Speichern geändert hat
			grid.load_resized(cells, old_columns, old_rows)
	elif grid_data is String:
		_paint_everything(grid_data)  # Spielstand aus Etappe 2


## Fasst gleiche Felder hintereinander zusammen: ["a","a","b"] -> [["a", 2], ["b", 1]].
## So bleibt die Speicherdatei klein.
func _compress(ids: Array[String]) -> Array:
	var result := []
	for id in ids:
		if not result.is_empty() and result.back()[0] == id:
			result.back()[1] += 1
		else:
			result.append([id, 1])
	return result


func _decompress(runs: Array) -> Array[String]:
	var result: Array[String] = []
	for run in runs:
		if run is Array and run.size() == 2:
			for i in int(run[1]):
				result.append(str(run[0]))
	return result


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
