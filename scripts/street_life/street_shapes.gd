class_name StreetShapes
extends RefCounted
## Baukasten für die Platzhalter auf der Straße (seit Etappe 5a): sammelt runde Formen
## (abgerundete Kästen, Kugeln, Zylinder, Reifen) in EINEM Mesh, jede mit eigener Farbe
## (Vertex-Farbe, Bedeutung des Alpha-Werts: assets/shaders/street_figure.gdshader).
## So braucht z. B. ein ganzes Auto nur einen Zeichenaufruf.
##
## Benutzung:
##   var shapes := StreetShapes.new()
##   shapes.add_round_box(Vector3(0, 0.6, 0), Vector3(1.6, 0.8, 3.4), StreetShapes.TINT)
##   mesh_instance.mesh = shapes.commit()

## Farbe "tint" (Instanz-Wert) mit voller Helligkeit.
const TINT := Color(1.0, 1.0, 1.0, 0.75)
const MATERIAL := preload("res://assets/materials/street_figure.tres")

## Alles, was ab jetzt hinzukommt, wird so verschoben/gedreht.
var xform := Transform3D.IDENTITY

var _tool := SurfaceTool.new()
var _empty := true


func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## Farbe mit fester Bedeutung (siehe Shader): fest matt, glänzend oder leuchtend.
static func solid(color: Color) -> Color:
	return Color(color.r, color.g, color.b, 1.0)


static func glossy(color: Color) -> Color:
	return Color(color.r, color.g, color.b, 0.5)


static func glowing(color: Color) -> Color:
	return Color(color.r, color.g, color.b, 0.25)


## Farbe "tint" etwas heller oder dunkler (shade = Helligkeit, 1 = wie tint).
static func tinted(shade: float) -> Color:
	return Color(shade, shade, shade, 0.75)


## Abgerundeter Kasten (Superellipsoid): roundness 1 = Ei/Kugel, klein = fast eckig.
func add_round_box(center: Vector3, size: Vector3, color: Color, roundness: float = 0.35,
		segments: int = 16, rings: int = 10) -> void:
	var half := size / 2.0
	var e := clampf(roundness, 0.05, 1.0)
	var grid: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i in rings + 1:
		var u := lerpf(-PI / 2.0, PI / 2.0, float(i) / rings)
		var row := PackedVector3Array()
		var row_n := PackedVector3Array()
		for j in segments + 1:
			var v := lerpf(-PI, PI, float(j) / segments)
			var p := Vector3(_c(u, e) * _c(v, e) * half.x, _s(u, e) * half.y, _c(u, e) * _s(v, e) * half.z)
			var n := Vector3(_c(u, 2.0 - e) * _c(v, 2.0 - e) / half.x, _s(u, 2.0 - e) / half.y,
				_c(u, 2.0 - e) * _s(v, 2.0 - e) / half.z)
			row.append(center + p)
			row_n.append(n.normalized() if n.length_squared() > 0.0 else Vector3(0.0, signf(u), 0.0))
		grid.append(row)
		normals.append(row_n)
	for i in rings:
		for j in segments:
			var a := [grid[i][j], normals[i][j]]
			var b := [grid[i][j + 1], normals[i][j + 1]]
			var c := [grid[i + 1][j + 1], normals[i + 1][j + 1]]
			var d := [grid[i + 1][j], normals[i + 1][j]]
			_triangle(a, c, b, color)
			_triangle(a, d, c, color)


## Kugel bzw. Ei (size = Durchmesser je Achse).
func add_ellipsoid(center: Vector3, size: Vector3, color: Color, segments: int = 14, rings: int = 8) -> void:
	add_round_box(center, size, color, 1.0, segments, rings)


## Zylinder zwischen zwei Punkten (mit Deckeln).
func add_cylinder(from: Vector3, to: Vector3, radius: float, color: Color, segments: int = 12) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	for j in segments:
		var a0 := TAU * j / segments
		var a1 := TAU * (j + 1) / segments
		var n0 := side * cos(a0) + up * sin(a0)
		var n1 := side * cos(a1) + up * sin(a1)
		var p0 := from + n0 * radius
		var p1 := from + n1 * radius
		var q0 := to + n0 * radius
		var q1 := to + n1 * radius
		_triangle([p0, n0], [q1, n1], [q0, n0], color)
		_triangle([p0, n0], [p1, n1], [q1, n1], color)
		_triangle([from, -axis], [p0, -axis], [p1, -axis], color)
		_triangle([to, axis], [q1, axis], [q0, axis], color)


## Reifen (Ring um die Achse "axis" durch center).
func add_torus(center: Vector3, axis: Vector3, radius: float, tube: float, color: Color,
		segments: int = 18, sides: int = 8) -> void:
	axis = axis.normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var grid: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for j in segments + 1:
		var a := TAU * j / segments
		var ring_dir := side * cos(a) + up * sin(a)
		var ring_center := center + ring_dir * radius
		var row := PackedVector3Array()
		var row_n := PackedVector3Array()
		for k in sides + 1:
			var b := TAU * k / sides
			var n := ring_dir * cos(b) + axis * sin(b)
			row.append(ring_center + n * tube)
			row_n.append(n)
		grid.append(row)
		normals.append(row_n)
	for j in segments:
		for k in sides:
			var p := [grid[j][k], normals[j][k]]
			var q := [grid[j + 1][k], normals[j + 1][k]]
			var r := [grid[j + 1][k + 1], normals[j + 1][k + 1]]
			var t := [grid[j][k + 1], normals[j][k + 1]]
			_triangle(p, r, q, color)
			_triangle(p, t, r, color)


func is_empty() -> bool:
	return _empty


## Fertiges Mesh (mit dem gemeinsamen Material der Straße).
func commit(material: Material = MATERIAL) -> ArrayMesh:
	var mesh := _tool.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
	return mesh


## Dreieck aus [Punkt, Normale]-Paaren; die Reihenfolge wird passend zur Normalen gedreht.
func _triangle(a: Array, b: Array, c: Array, color: Color) -> void:
	var pa: Vector3 = xform * (a[0] as Vector3)
	var pb: Vector3 = xform * (b[0] as Vector3)
	var pc: Vector3 = xform * (c[0] as Vector3)
	var na: Vector3 = (xform.basis * (a[1] as Vector3)).normalized()
	var nb: Vector3 = (xform.basis * (b[1] as Vector3)).normalized()
	var nc: Vector3 = (xform.basis * (c[1] as Vector3)).normalized()
	var face := (pb - pa).cross(pc - pa)
	if face.length_squared() < 1e-12:
		return  # an den Polen fallen Dreiecke zu Strichen zusammen
	var corners := [[pa, na], [pb, nb], [pc, nc]]
	# Godot zeichnet Dreiecke im Uhrzeigersinn als Vorderseite
	if face.dot(na + nb + nc) > 0.0:
		corners = [[pa, na], [pc, nc], [pb, nb]]
	for corner in corners:
		_tool.set_normal(corner[1])
		_tool.set_color(color)
		_tool.add_vertex(corner[0])
	_empty = false


static func _c(w: float, m: float) -> float:
	var c := cos(w)
	return signf(c) * pow(absf(c), m)


static func _s(w: float, m: float) -> float:
	var s := sin(w)
	return signf(s) * pow(absf(s), m)
