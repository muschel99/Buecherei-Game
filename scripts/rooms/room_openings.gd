class_name RoomOpenings
extends RefCounted
## Passt den Laden an die gewählten Fenster und die Tür an (seit Etappe 6c): die Löcher in den Wänden
## (CSG), die Aussparungen der Innenfarbe (PaintableWall) und die Fensterbänke (ShopWindow). Alles aus
## denselben Umrissen wie die Fassade (FacadeLayout) – so passen innen und außen genau zusammen.

## Wand → [CSG-Wand, Farbfläche innen, Schaufenster-Szene]
const WALLS := {
	"front": ["Structure/WallFront", "Walls/Front", "WindowFront"],
	"left": ["Structure/WallLeft", "Walls/Left", "WindowLeft"],
	"diag": ["Structure/WallDiagonal", "Walls/Diagonal", ""],
}


static func apply(room: Node, openings: Array[Dictionary]) -> void:
	for segment: String in WALLS:
		var paths: Array = WALLS[segment]
		var here := openings.filter(func(o: Dictionary) -> bool: return o.segment == segment and o.kind != "upper")
		_cut_wall(room, room.get_node_or_null(paths[0]) as Node3D, here)
		var wall := room.get_node_or_null(paths[1]) as PaintableWall
		if wall:
			var shapes: Array[PackedVector2Array] = []
			for o: Dictionary in here:
				shapes.append(_to_local_2d(room, wall, o, -FacadeLayout.WALL_THICKNESS))
			wall.set_opening_shapes(shapes)
		if not String(paths[2]).is_empty():
			var window := room.get_node_or_null(paths[2])
			if window and window.has_method("configure"):
				for o: Dictionary in here:
					if o.kind == "shop":
						window.configure(o, _relative(window as Node3D, room).affine_inverse() * FacadeLayout.opening_frame(o))
	# Laibungen wieder in der Farbe der Wand (die Aussparungen sind neu)
	if room.is_inside_tree() and room.has_method("_update_reveals"):
		room.call("_update_reveals")


## Ersetzt die Löcher einer CSG-Wand durch Formen in der Gestalt der Öffnungen.
static func _cut_wall(room: Node, combiner: Node3D, here: Array) -> void:
	if combiner == null:
		return
	for child in combiner.get_children():
		if child.name.begins_with("WindowHole") or child.name.begins_with("DoorHole") or child.has_meta("opening"):
			combiner.remove_child(child)
			child.free()
	var to_local := _relative(combiner, room).affine_inverse()
	for o: Dictionary in here:
		var hole := CSGPolygon3D.new()
		hole.name = "OpeningHole_" + String(o.id)
		hole.set_meta("opening", o.id)
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		hole.polygon = o.outline
		hole.depth = 0.6
		# Das Vieleck wird entlang -Z hochgezogen: 20 cm vor der Außenseite beginnen, durch die ganze Wand
		hole.transform = to_local * FacadeLayout.opening_frame(o) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.2))
		combiner.add_child(hole)


## Umriss einer Öffnung in den Koordinaten eines Knotens (x, y), auf der Wandtiefe z (Außenseite = 0).
static func _to_local_2d(room: Node, node: Node3D, o: Dictionary, z: float) -> PackedVector2Array:
	var xform := _relative(node, room).affine_inverse() * FacadeLayout.opening_frame(o)
	var points := PackedVector2Array()
	for p: Vector2 in o.outline:
		var q := xform * Vector3(p.x, p.y, z)
		points.append(Vector2(q.x, q.y))
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	return points


## Lage eines Knotens relativ zum Raum (geht auch, solange der Raum noch nicht im Baum ist).
static func _relative(node: Node3D, room: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current and current != room:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
