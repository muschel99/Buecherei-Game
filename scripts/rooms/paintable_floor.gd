class_name PaintableFloor
extends MeshInstance3D
## Ein Boden, der in kleinen quadratischen Feldern belegt werden kann.
##
## Der Knoten liegt an der Ecke des Bodens mit den kleinsten x- und z-Werten.
## Feldgröße: GameConfig.floor_section_size. Felder mit gleichem Belag werden zu
## größeren Flächen zusammengefasst, damit das Spiel flüssig bleibt.

## Größe des Bodens in Metern (x = Breite, y = Tiefe).
@export var size: Vector2 = Vector2(6.0, 8.0)

## So weit liegt der Belag über dem eigentlichen Boden (verhindert Flackern).
const OFFSET := 0.003

## Oberfläche (id) je Feld, Zeile für Zeile.
var cell_ids: Array[String] = []
var columns: int = 1
var rows: int = 1
var _cell_size: float = 0.125


func _ready() -> void:
	_cell_size = GameConfig.floor_section_size
	columns = maxi(1, roundi(size.x / _cell_size))
	rows = maxi(1, roundi(size.y / _cell_size))
	cell_ids.resize(columns * rows)
	cell_ids.fill("")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Welches Feld liegt an diesem Punkt? (-1 = außerhalb)
func get_cell_at(world_point: Vector3) -> int:
	var local := to_local(world_point)
	if absf(local.y) > 0.05:
		return -1
	var column := int(floorf(local.x / _cell_size))
	var row := int(floorf(local.z / _cell_size))
	if column < 0 or column >= columns or row < 0 or row >= rows:
		return -1
	return row * columns + column


## Mitte eines Felds (in Weltkoordinaten).
func get_cell_center(index: int) -> Vector3:
	var column := index % columns
	var row := index / columns
	return to_global(Vector3((column + 0.5) * _cell_size, 0.0, (row + 0.5) * _cell_size))


## Belegt mehrere Felder und baut die Fläche danach einmal neu.
func paint_cells(indices: Array[int], surface: SurfaceData) -> void:
	var id := surface.get_id()
	for index in indices:
		cell_ids[index] = id
	rebuild()


## Belegt den ganzen Boden.
func paint_all(surface: SurfaceData) -> void:
	cell_ids.fill(surface.get_id())
	rebuild()


## Baut die sichtbare Fläche aus den Feldern: pro Belag eine Teilfläche,
## gleiche Felder in einer Zeile werden zu einem Streifen zusammengefasst.
func rebuild() -> void:
	var tools := {}  # Material -> SurfaceTool
	for row in rows:
		var start := 0
		while start < columns:
			var id := cell_ids[row * columns + start]
			var end := start + 1
			while end < columns and cell_ids[row * columns + end] == id:
				end += 1
			var surface := Catalog.get_surface(id)
			if surface and surface.material:
				if not tools.has(surface.material):
					var new_tool := SurfaceTool.new()
					new_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[surface.material] = new_tool
				_add_strip(tools[surface.material], start, end, row)
			start = end

	var new_mesh := ArrayMesh.new()
	for material: Material in tools:
		var tool: SurfaceTool = tools[material]
		tool.set_material(material)
		tool.commit(new_mesh)
	mesh = new_mesh


## Fügt einen Streifen aus Feldern als zwei Dreiecke hinzu.
func _add_strip(tool: SurfaceTool, start: int, end: int, row: int) -> void:
	var x0 := start * _cell_size
	var x1 := end * _cell_size
	var z0 := row * _cell_size
	var z1 := (row + 1) * _cell_size
	var corners := [Vector3(x0, OFFSET, z0), Vector3(x1, OFFSET, z0), Vector3(x1, OFFSET, z1), Vector3(x0, OFFSET, z1)]
	# Godot zeigt Dreiecke von der Seite, von der aus die Ecken im Uhrzeigersinn liegen
	for i in [0, 1, 2, 0, 2, 3]:
		var corner: Vector3 = corners[i]
		var world := to_global(corner)
		tool.set_normal(Vector3.UP)
		tool.set_uv(Vector2(world.x, world.z))
		tool.add_vertex(corner)
