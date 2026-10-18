@tool
class_name WorldMesh
extends RefCounted
## Kleiner Baukasten für die Kulisse draußen (seit Etappe 4d): sammelt Vierecke und Quader
## in EINEM Mesh, jedes Teil mit eigener Farbe (Vertex-Farben). So braucht ein ganzes Haus
## nur ein Material und wird in einem Rutsch gezeichnet – das spart Rechenleistung.
##
## Benutzung:
##   var builder := WorldMesh.new()
##   builder.add_box(Vector3(-1, 0, -1), Vector3(1, 2, 1), Color.WHITE)
##   add_child(builder.make_instance("Model", material))

## Alles, was ab jetzt hinzukommt, wird so verschoben/gedreht (z. B. für eine schräge
## Fassade: Teile in "Fassaden-Koordinaten" bauen, x entlang der Wand, +z nach draußen).
var xform := Transform3D.IDENTITY

var _tool := SurfaceTool.new()
var _empty := true


func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## Viereck (Ecken der Reihe nach rundherum), sichtbar in Richtung "normal".
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	add_triangle(a, b, c, normal, color)
	add_triangle(a, c, d, normal, color)


## Dreieck, sichtbar in Richtung "normal" (die Reihenfolge der Ecken wird passend gedreht).
func add_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if xform != Transform3D.IDENTITY:
		a = xform * a
		b = xform * b
		c = xform * c
		normal = (xform.basis * normal).normalized()
	var corners := [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for corner: Vector3 in corners:
		_tool.set_normal(normal)
		_tool.set_color(color)
		_tool.set_uv(Vector2(corner.x + corner.z, corner.y))
		_tool.add_vertex(corner)
	_empty = false


## Viereck mit eigener Normale je Ecke (weiche Rundungen, z. B. abgerundete Stein- und Stufen-
## kanten, seit dem Stil-Umbau). Die Reihenfolge der Ecken wird passend zur mittleren Normale gedreht.
func add_quad_smooth(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		color: Color) -> void:
	_add_smooth_triangle([a, b, c], [na, nb, nc], color)
	_add_smooth_triangle([a, c, d], [na, nc, nd], color)


func _add_smooth_triangle(points: Array, normals: Array, color: Color) -> void:
	var pts := points.duplicate()
	var nrm := normals.duplicate()
	if xform != Transform3D.IDENTITY:
		for i in 3:
			pts[i] = xform * (pts[i] as Vector3)
			nrm[i] = (xform.basis * (nrm[i] as Vector3)).normalized()
	var mean: Vector3 = (nrm[0] + nrm[1] + nrm[2]) as Vector3
	var order := [0, 1, 2] if ((pts[1] - pts[0]) as Vector3).cross(pts[2] - pts[0]).dot(mean) < 0.0 else [0, 2, 1]
	for i: int in order:
		var corner: Vector3 = pts[i]
		_tool.set_normal(nrm[i])
		_tool.set_color(color)
		_tool.set_uv(Vector2(corner.x + corner.z, corner.y))
		_tool.add_vertex(corner)
	_empty = false


## Gerundete Kante entlang a → b (Viertelkreis, segments Stücke): out = waagerechte Richtung nach
## außen (zur Kante hin), die Rundung reicht von der Oberseite (radius vor der Kante) bis zur
## senkrechten Fläche (radius unter der Oberkante). top = Höhe der Oberseite.
func add_round_edge(a: Vector2, b: Vector2, out: Vector2, top: float, radius: float, color: Color, segments: int = 3) -> void:
	var o := Vector3(out.x, 0.0, out.y).normalized()
	var pa := Vector3(a.x, top - radius, a.y) - o * radius
	var pb := Vector3(b.x, top - radius, b.y) - o * radius
	for k in segments:
		var t0 := PI / 2.0 * (1.0 - float(k) / segments)
		var t1 := PI / 2.0 * (1.0 - float(k + 1) / segments)
		var n0 := o * cos(t0) + Vector3.UP * sin(t0)
		var n1 := o * cos(t1) + Vector3.UP * sin(t1)
		add_quad_smooth(pa + n0 * radius, pb + n0 * radius, pb + n1 * radius, pa + n1 * radius, n0, n0, n1, n1, color)


## Quader zwischen zwei Ecken (achsparallel). "skip": Seiten, die man nie sieht, weglassen
## ("bottom", "top", "front" = +Z, "back" = -Z, "left" = -X, "right" = +X).
func add_box(low: Vector3, high: Vector3, color: Color, skip: PackedStringArray = PackedStringArray(["bottom"])) -> void:
	var x0 := low.x
	var x1 := high.x
	var y0 := low.y
	var y1 := high.y
	var z0 := low.z
	var z1 := high.z
	if not "top" in skip:
		add_quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, color)
	if not "bottom" in skip:
		add_quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, color)
	if not "front" in skip:
		add_quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, color)
	if not "back" in skip:
		add_quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, color)
	if not "left" in skip:
		add_quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, color)
	if not "right" in skip:
		add_quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, color)


## Flaches Vieleck auf Höhe y (Punkte x, z der Reihe nach, nach außen gewölbt oder einfach).
func add_floor(points: PackedVector2Array, y: float, color: Color) -> void:
	var triangles := Geometry2D.triangulate_polygon(points)
	for i in range(0, triangles.size(), 3):
		var a := points[triangles[i]]
		var b := points[triangles[i + 1]]
		var c := points[triangles[i + 2]]
		add_triangle(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP, color)


## Senkrechte Wand von Punkt a nach b (x, z) zwischen zwei Höhen, sichtbar in Richtung "outward".
func add_wall(a: Vector2, b: Vector2, y0: float, y1: float, outward: Vector3, color: Color) -> void:
	add_quad(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), outward, color)


func is_empty() -> bool:
	return _empty


## Fertiges Mesh (leer = null) – z. B. um es für mehrere Knoten zu teilen.
func commit(material: Material) -> ArrayMesh:
	if _empty:
		return null
	_tool.set_material(material)
	return _tool.commit()


## Fertiges Mesh als Knoten (leer = null).
func make_instance(node_name: String, material: Material, cast_shadow: bool = true) -> MeshInstance3D:
	if _empty:
		return null
	_tool.set_material(material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _tool.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Alle Modelle unter root werfen Schatten von beiden Seiten. Nötig bei Kulissen aus einseitigen
## Flächen (z. B. Gassenwände nur von innen gebaut): Godot rechnet Schatten sonst nur von den
## sichtbaren Seiten – scheint die Sonne auf die Rückseite, fehlt der Schatten.
static func cast_shadows_both_sides(root: Node) -> void:
	if root is GeometryInstance3D:
		var geometry := root as GeometryInstance3D
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	for child in root.get_children():
		cast_shadows_both_sides(child)
