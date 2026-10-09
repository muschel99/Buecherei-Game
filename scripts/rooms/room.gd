class_name Room
extends Node3D
## Ein Raum des Hauses: verwaltet seine Möbel, Wandfarbe und Boden.
##
## Der Gestaltungsmodus fügt hier Möbel hinzu, verschiebt und entfernt sie.
## (Ob etwas im Inventar ist, regelt der Gestaltungsmodus mit Inventory.)
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
## Die Wände, die in Abschnitten gestrichen werden können (inkl. der schrägen Eingangswand).
@onready var _walls: Array[PaintableWall] = [$Walls/Left, $Walls/Right, $Walls/Back, $Walls/Front, $Walls/Diagonal]
## Boden und Decke, die in Abschnitten gestaltet werden können.
@onready var _grids := {
	SurfaceData.Kind.FLOOR: $FloorCovering as PaintableGrid,
	SurfaceData.Kind.CEILING: $CeilingCovering as PaintableGrid,
}
## Fenster- und Türlaibung: bekommen die Farbe des Wandabschnitts, in dem sie liegen.
## Jeder Eintrag: { "node": CSG-Aussparung, "wall": die Wand, zu der sie gehört }.
@onready var _reveals: Array = [
	{"node": $Structure/WallFront/WindowHole, "wall": $Walls/Front},
	{"node": $Structure/WallLeft/WindowHole, "wall": $Walls/Left},
	{"node": $Structure/WallDiagonal/DoorHole, "wall": $Walls/Diagonal},
]
## Hier darf man etwas aufhängen (Wandbilder, Lichtschalter …).
@onready var _hang_walls: Array[Node] = [
	$Structure/WallLeft,
	$Structure/WallRight,
	$Structure/WallBack,
	$Structure/WallFront,
	$Structure/WallDiagonal,
]
## Hier darf man etwas an die Tür hängen (z. B. einen Türkranz).
@onready var _hang_doors: Array[Node] = [$Door/Hinge/DoorLeaf]
## Hier darf man etwas an die Decke hängen (z. B. Deckenlampen).
@onready var _hang_ceilings: Array[Node] = [$Structure/Ceiling]

## Wohin etwas gehängt werden kann (gleiche Werte wie FurnitureData.placement).
enum HangKind { NONE = 0, WALL = 4, DOOR = 8, CEILING = 16 }

## Bücher, die in diesem Raum frei herumliegen (auf Tischen, dem Boden …), siehe LooseBooks.
var loose_books: LooseBooks

var _next_uid: int = 1
## Mass der abgeschrägten vorderen linken Ecke (aus GameConfig.corner_cut); die Ecke bleibt frei.
var _corner_cut: float = 0.0
## Wo Unverzichtbares (z. B. das Tablet) ursprünglich steht – falls es in einem Spielstand
## fehlt, kommt es dorthin zurück. id -> { "support_id": …, "transform": … }
var _essential_spots: Dictionary = {}


func _ready() -> void:
	loose_books = LooseBooks.new()
	loose_books.name = "LooseBooks"
	add_child(loose_books)
	_corner_cut = GameConfig.corner_cut
	_apply_room_height(GameConfig.room_height)
	add_to_group(SaveManager.PERSIST_GROUP)
	for item in get_placed_furniture():
		_assign_uid(item)
	_remember_essential_spots()
	_paint_everything(default_wall_id)
	_paint_everything(default_floor_id)
	_paint_everything(default_ceiling_id)
	layout_changed.connect(SaveManager.request_save)


## Passt Wände, Decke und Deckenbelag an die Raumhöhe an.
## (Die Wandabschnitte zum Streichen lesen die Höhe selbst, siehe PaintableWall.)
func _apply_room_height(height: float) -> void:
	# Die Außenwände reichen bis zur Oberkante der Deckenplatte: So deckt die Hauswand außen
	# auch die Kante der Decke ab und läuft glatt bis zum Obergeschoss durch.
	var wall_height := height + ($Structure/Ceiling/Slab as CSGBox3D).size.y
	for wall: CSGBox3D in [$Structure/WallRight, $Structure/WallBack]:
		wall.size.y = wall_height
		wall.position.y = wall_height / 2.0
	# Die Wände an der Schräge sind hochgezogene Grundrisse (Gehrung an den Ecken): Ihre
	# Höhe ist die Tiefe des Hochziehens, der Fuß liegt schon auf dem Boden.
	for wall: CSGPolygon3D in [$Structure/WallFront/Wall, $Structure/WallLeft/Wall,
			$Structure/WallDiagonal/Wall]:
		wall.depth = wall_height
	# Die Decke ist ein CSG-Container (abgeschrägte Ecke): sein Ursprung liegt an der Unterkante.
	($Structure/Ceiling as Node3D).position.y = height
	($CeilingCovering as Node3D).position.y = height


# --- Möbel ---

## Alle Möbel, die gerade im Raum stehen.
func get_placed_furniture() -> Array[PlacedFurniture]:
	var result: Array[PlacedFurniture] = []
	for child in furniture_root.get_children():
		if child is PlacedFurniture:
			result.append(child)
	return result


## Wie viele Möbel mit dieser id stehen gerade im Raum?
func count_placed(id: String) -> int:
	var count := 0
	for item in get_placed_furniture():
		if item.data and item.data.get_id() == id:
			count += 1
	return count


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


## Verschiebt ein Möbelstück. Was darauf steht (z. B. eine Vase auf dem Tisch) und Bücher,
## die darauf liegen, wandern mit.
func move_furniture(item: PlacedFurniture, world_transform: Transform3D, support: PlacedFurniture) -> void:
	var old_inverse := item.global_transform.affine_inverse()
	var dependents := get_dependents(item)
	for dependent in dependents:
		var relative := old_inverse * dependent.global_transform
		dependent.global_transform = world_transform * relative
	loose_books.move_with(get_uids(item, dependents), world_transform * old_inverse)
	item.global_transform = world_transform
	item.support_uid = support.uid if support else 0
	layout_changed.emit()


## Entfernt ein Möbelstück samt allem, was darauf steht.
## Inhalte (z. B. die Bücher eines Regals) und Bücher, die darauf liegen, gehen dabei ins Lager.
func remove_furniture(item: PlacedFurniture) -> void:
	var dependents := get_dependents(item)
	var books := loose_books.release_on(get_uids(item, dependents))
	BookStock.store_books(books)
	var shown := {}
	for book in books:
		var genre := book.get_genre()
		if genre and not shown.has(genre):
			shown[genre] = true
			StorageIndicator.add_item(self, genre)
	for dependent in dependents:
		dependent.release_contents()
		_free_furniture(dependent)
	item.release_contents()
	_free_furniture(item)
	layout_changed.emit()


## Die Nummern eines Möbelstücks und aller Dinge darauf (für die ausgelegten Bücher).
func get_uids(item: PlacedFurniture, dependents: Array[PlacedFurniture]) -> Array[int]:
	var uids: Array[int] = [item.uid]
	for dependent in dependents:
		uids.append(dependent.uid)
	return uids


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


## Unverzichtbares (FurnitureData.is_essential, z. B. das Tablet mit dem Shop) darf nie
## verloren gehen. Fehlt es im Raum und im Inventar (etwa bei einem Spielstand von vor dem
## Shop), wird es wieder an seinen Platz gestellt – oder ins Inventar gelegt, falls das
## Möbelstück fehlt, auf dem es stand. Wird nach dem Laden des Spielstands aufgerufen.
func ensure_essentials() -> void:
	for data in Catalog.get_all_furniture():
		var id := data.get_id()
		if not data.is_essential or count_placed(id) > 0 or Inventory.get_count(id) > 0:
			continue
		var spot: Dictionary = _essential_spots.get(id, {})
		var support := _find_placed(str(spot.get("support_id", "")))
		if spot.is_empty() or (not str(spot.support_id).is_empty() and support == null):
			Inventory.add_furniture(id)
			continue
		var world: Transform3D = spot.transform
		if support:
			world = support.global_transform * world
		add_furniture(data, world, support)


func _remember_essential_spots() -> void:
	for item in get_placed_furniture():
		if item.data == null or not item.data.is_essential:
			continue
		var support: PlacedFurniture = null
		for other in get_placed_furniture():
			if other.uid == item.support_uid and item.support_uid > 0:
				support = other
		if support:
			_essential_spots[item.data.get_id()] = {"support_id": support.data.get_id(),
				"transform": support.global_transform.affine_inverse() * item.global_transform}
		else:
			_essential_spots[item.data.get_id()] = {"support_id": "", "transform": item.global_transform}


## Das erste Möbelstück mit dieser id im Raum (oder null).
func _find_placed(id: String) -> PlacedFurniture:
	for item in get_placed_furniture():
		if item.data and item.data.get_id() == id:
			return item
	return null


## Alle Lichtquellen im Raum, die der Lichtschalter schaltet: elektrische Lampen –
## und Kerzen/Laternen nur, wenn GameConfig.light_switch_includes_flames an ist.
func get_switchable_lights() -> Array[LightSource]:
	var lights: Array[LightSource] = []
	for item in get_placed_furniture():
		var source := item.get_model() as LightSource
		if source and (source.is_electric() or GameConfig.light_switch_includes_flames):
			lights.append(source)
	return lights


## Liegt dieser Punkt (in Weltkoordinaten) innerhalb der Raumfläche? Die abgeschrägte vordere
## linke Ecke (schräge Eingangswand) zählt nicht dazu – dort lässt sich nichts aufstellen.
func is_inside_build_area(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	if not build_area.has_point(Vector2(local.x, local.z)):
		return false
	# Abgeschnittene Ecke: der Dreiecks-Bereich an der Ecke mit den kleinsten x/z bleibt frei.
	var along_x := local.x - build_area.position.x
	var along_z := local.z - build_area.position.y
	return along_x + along_z >= _corner_cut


## Ist der getroffene Kollisionskörper eine Wand, die Tür oder die Decke dieses Raums?
func get_hang_kind(collider: Object) -> HangKind:
	if _hang_walls.has(collider):
		return HangKind.WALL
	if _hang_doors.has(collider):
		return HangKind.DOOR
	if _hang_ceilings.has(collider):
		return HangKind.CEILING
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


## Füllwerkzeug für Boden und Decke: füllt alle zusammenhängenden Abschnitte mit
## demselben Belag wie der angeklickte (siehe PaintableGrid.get_connected_cells).
func fill_grid(start_index: int, surface: SurfaceData) -> void:
	var grid := _grids[surface.kind] as PaintableGrid
	grid.paint_cells(grid.get_connected_cells(start_index), surface)
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
	for entry in _reveals:
		var wall: PaintableWall = entry["wall"]
		var reveal: CSGPrimitive3D = entry["node"]
		var x := wall.to_local(reveal.global_position).x
		var surface := Catalog.get_surface(wall.segment_ids[wall.get_segment_index_at_x(x)])
		if surface:
			reveal.material = surface.material


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var furniture := []
	for item in get_placed_furniture():
		if item.data == null:
			continue
		var entry := {
			"uid": item.uid,
			"id": item.data.get_id(),
			"position": [item.position.x, item.position.y, item.position.z],
			"rotation_y": item.rotation.y,
			"support_uid": item.support_uid,
		}
		# Was darin ist (z. B. Genre und Bücher eines Regals)
		var contents := item.get_contents_data()
		if not contents.is_empty():
			entry["contents"] = contents
		furniture.append(entry)
	var walls := {}
	for wall in _walls:
		walls[wall.name] = wall.segment_ids.duplicate()
	return {
		"walls": walls,
		"floor": _grid_save_data(_grids[SurfaceData.Kind.FLOOR]),
		"ceiling": _grid_save_data(_grids[SurfaceData.Kind.CEILING]),
		"furniture": furniture,
		"loose_books": loose_books.get_save_data(),
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

	# Ausgelegte Bücher (ältere Spielstände haben keine)
	loose_books.load_save_data(save_data.get("loose_books", []))
	_load_walls(save_data)
	_load_grid(save_data.get("floor"), _grids[SurfaceData.Kind.FLOOR], default_floor_id)
	_load_grid(save_data.get("ceiling"), _grids[SurfaceData.Kind.CEILING], default_ceiling_id)
	# Was im Raum zu sehen ist, gehört mir (wichtig für Spielstände von vor dem Inventar)
	for id in _get_used_surface_ids():
		Inventory.add_surface(id)
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
	if data == null and id == ReturnBox.LEGACY_FURNITURE_ID:
		_migrate_legacy_return_box(entry)
		return
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
	# Dinge an der Decke wandern mit, falls sich die Raumhöhe geändert hat
	if data.placement == FurnitureData.PLACE_CEILING:
		item.position.y = GameConfig.room_height - 0.002
	item.uid = int(entry.get("uid", 0))
	item.support_uid = int(entry.get("support_uid", 0))
	furniture_root.add_child(item, true)
	_assign_uid(item)
	if entry.get("contents") is Dictionary:
		item.load_contents_data(entry["contents"])


## Alter Spielstand (vor Etappe 3l): Ein aufgestellter Rückgabekasten wird nicht mehr
## aufgebaut – seine Bücher wandern in den festen Kasten in der Wand (was nicht passt, ins Lager).
func _migrate_legacy_return_box(entry: Dictionary) -> void:
	var contents = entry.get("contents")
	var old_books := Book.list_from_save_data(contents.get("books") if contents is Dictionary else null)
	var box := ReturnBox.find(get_tree())
	if box:
		box.receive_legacy_books(old_books)
	else:
		BookStock.store_books(old_books)


func _assign_uid(item: PlacedFurniture) -> void:
	if item.uid <= 0:
		item.uid = _next_uid
	_next_uid = maxi(_next_uid, item.uid + 1)


func _free_furniture(item: PlacedFurniture) -> void:
	furniture_root.remove_child(item)
	item.queue_free()
