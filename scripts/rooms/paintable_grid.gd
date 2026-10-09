class_name PaintableGrid
extends MeshInstance3D
## Ein Boden oder eine Decke, die in quadratischen Abschnitten gestaltet werden kann.
##
## Der Knoten liegt an der Ecke mit den kleinsten x- und z-Werten, auf Höhe der Fläche.
## Ein Abschnitt ist GameConfig.floor_section_cells Rasterfelder breit (Standard 3 x 3).
## Abschnitte mit gleichem Belag werden zu größeren Flächen zusammengefasst,
## damit das Spiel flüssig bleibt.

## Größe der Fläche in Metern (x = Breite, y = Tiefe).
@export var size: Vector2 = Vector2(6.0, 8.0)
## An = Decke (Fläche zeigt nach unten), aus = Boden (Fläche zeigt nach oben).
@export var faces_down: bool = false
## Eckladen (seit Etappe 4b): Felder in der Ecke mit den kleinsten x/z (dem Ursprung) werden
## ausgespart, wenn das an ist – dann folgt der Belag der schrägen Eingangswand. Mass der
## Schräge: GameConfig.corner_cut. Felder, durch die die Schräge läuft, werden seit Etappe 4c
## genau an der Schräge abgeschnitten (vorher ragten ihre Ecken durch die Wand nach draußen).
@export var cut_corner: bool = false

## So weit liegt der Belag vor der eigentlichen Fläche (verhindert Flackern).
const OFFSET := 0.003
## Rechen-Spielraum beim Vergleich mit der Schräge (in Metern).
const CUT_EPSILON := 0.0001

## Oberfläche (id) je Feld, Zeile für Zeile.
var cell_ids: Array[String] = []
var columns: int = 1
var rows: int = 1
var _cell_size: float = 1.0 / 3.0
## Mass der abgeschrägten Ecke (0 = keine Schräge).
var _corner_cut: float = 0.0


func _ready() -> void:
	_cell_size = GameConfig.grid_cell_size * GameConfig.floor_section_cells
	columns = maxi(1, roundi(size.x / _cell_size))
	rows = maxi(1, roundi(size.y / _cell_size))
	cell_ids.resize(columns * rows)
	cell_ids.fill("")
	if cut_corner:
		_corner_cut = GameConfig.corner_cut
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Liegt dieses Feld ganz in der ausgesparten (abgeschrägten) Ecke?
## (Die Schräge ist die Linie x + z = corner_cut, gemessen ab dem Ursprung des Knotens.)
func _is_cut(column: int, row: int) -> bool:
	if _corner_cut <= 0.0:
		return false
	return (column + row + 2) * _cell_size <= _corner_cut + CUT_EPSILON


## Läuft die Schräge durch dieses Feld? Dann bekommt es nur den Teil vor der Schräge.
func _is_partly_cut(column: int, row: int) -> bool:
	if _corner_cut <= 0.0 or _is_cut(column, row):
		return false
	return (column + row) * _cell_size < _corner_cut - CUT_EPSILON


## Welches Feld liegt an diesem Punkt? (-1 = außerhalb oder in der abgeschrägten Ecke)
func get_cell_at(world_point: Vector3) -> int:
	var local := to_local(world_point)
	if absf(local.y) > 0.05:
		return -1
	var column := int(floorf(local.x / _cell_size))
	var row := int(floorf(local.z / _cell_size))
	if column < 0 or column >= columns or row < 0 or row >= rows:
		return -1
	if _is_cut(column, row) or local.x + local.z < _corner_cut:
		return -1
	return row * columns + column


## Mitte eines Felds (in Weltkoordinaten).
func get_cell_center(index: int) -> Vector3:
	var column := index % columns
	var row := index / columns
	return to_global(Vector3((column + 0.5) * _cell_size, 0.0, (row + 0.5) * _cell_size))


## Übernimmt Felder aus einem Spielstand mit anderer Feldeinteilung: Jeder neue
## Abschnitt bekommt den Belag, der früher in seiner Mitte lag.
func load_resized(old_ids: Array[String], old_columns: int, old_rows: int) -> void:
	for row in rows:
		for column in columns:
			var old_column := clampi(int((column + 0.5) * old_columns / columns), 0, old_columns - 1)
			var old_row := clampi(int((row + 0.5) * old_rows / rows), 0, old_rows - 1)
			var id := old_ids[old_row * old_columns + old_column]
			if Catalog.get_surface(id):
				cell_ids[row * columns + column] = id
	rebuild()


## Belegt mehrere Felder und baut die Fläche danach einmal neu.
func paint_cells(indices: Array[int], surface: SurfaceData) -> void:
	var id := surface.get_id()
	for index in indices:
		cell_ids[index] = id
	rebuild()


## Füllwerkzeug (wie der Farbeimer in Paint): Alle Abschnitte, die mit dem Startabschnitt
## zusammenhängen und denselben Belag haben. Nur direkte Nachbarn zählen (vorne, hinten,
## links, rechts – nicht diagonal). Grenzen sind die Wände und Abschnitte mit anderem Belag.
func get_connected_cells(start: int) -> Array[int]:
	var id := cell_ids[start]
	var result: Array[int] = []
	var visited := {start: true}
	var to_check: Array[int] = [start]
	while not to_check.is_empty():
		var index: int = to_check.pop_back()
		result.append(index)
		var column := index % columns
		var row := index / columns
		var neighbours: Array[int] = []
		if column > 0:
			neighbours.append(index - 1)
		if column < columns - 1:
			neighbours.append(index + 1)
		if row > 0:
			neighbours.append(index - columns)
		if row < rows - 1:
			neighbours.append(index + columns)
		for next in neighbours:
			if not visited.has(next) and cell_ids[next] == id and not _is_cut(next % columns, next / columns):
				visited[next] = true
				to_check.append(next)
	return result


## Belegt die ganze Fläche.
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
			# Ausgesparte Eckfelder (abgeschrägte Ecke) überspringen – sie bekommen keinen Belag
			if _is_cut(start, row):
				start += 1
				continue
			var id := cell_ids[row * columns + start]
			# Ein Feld an der Schräge wird einzeln (abgeschnitten) gebaut
			var partly := _is_partly_cut(start, row)
			var end := start + 1
			while not partly and end < columns and not _is_cut(end, row) \
					and not _is_partly_cut(end, row) and cell_ids[row * columns + end] == id:
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


## Fügt einen Streifen aus Feldern hinzu (an der Schräge abgeschnitten, falls nötig).
func _add_strip(tool: SurfaceTool, start: int, end: int, row: int) -> void:
	var x0 := start * _cell_size
	var x1 := end * _cell_size
	var z0 := row * _cell_size
	var z1 := (row + 1) * _cell_size
	var outline: Array[Vector2] = [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	if _corner_cut > 0.0:
		outline = _clip_at_corner(outline)
	if outline.size() < 3:
		return
	var y := -OFFSET if faces_down else OFFSET
	# Als Fächer aus Dreiecken um die erste Ecke.
	# Godot zeigt Dreiecke von der Seite, von der aus die Ecken im Uhrzeigersinn liegen.
	# Die Decke wird von unten angeschaut, deshalb dort die umgekehrte Reihenfolge.
	for i in range(1, outline.size() - 1):
		var triangle := [outline[0], outline[i + 1], outline[i]] if faces_down \
			else [outline[0], outline[i], outline[i + 1]]
		for point: Vector2 in triangle:
			var corner := Vector3(point.x, y, point.y)
			var world := to_global(corner)
			tool.set_normal(Vector3.DOWN if faces_down else Vector3.UP)
			tool.set_uv(Vector2(world.x, world.z))
			tool.add_vertex(corner)


## Schneidet ein Vieleck an der Schräge ab: Übrig bleibt nur der Teil im Raum (x + z ≥ Mass).
func _clip_at_corner(outline: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var side_a := a.x + a.y - _corner_cut
		var side_b := b.x + b.y - _corner_cut
		if side_a >= 0.0:
			result.append(a)
		# Die Kante kreuzt die Schräge: Schnittpunkt dazunehmen
		if (side_a >= 0.0) != (side_b >= 0.0):
			result.append(a.lerp(b, side_a / (side_a - side_b)))
	return result
