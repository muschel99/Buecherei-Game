class_name OpeningMesh
extends RefCounted
## Baut Netze aus Umrissen (seit Etappe 6c): Wandflächen mit Löchern, Rahmen-Ringe, Glas, Sprossen,
## Leisten und kleine Kästen – für Fenster, Türen und die Fassade.
##
## Koordinaten: x entlang der Wand, y nach oben, z aus der Wand heraus (wie OpeningShape). Godot zeichnet
## nur Vorderseiten (im Uhrzeigersinn, vom Betrachter aus gesehen) – tri() dreht jedes Dreieck passend
## zu seiner Normale. Die Vertex-Farbe ist weiß (der Bilderbuch-Shader nimmt sie als Farbton, Alpha 1 =
## nichts weht im Wind).

## Kanten flacher als dieser Winkel werden weich schattiert (Kreise, Bögen)
const SMOOTH_ANGLE := deg_to_rad(40.0)

var st := SurfaceTool.new()


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Ein Dreieck mit gemeinsamer Normale n (die Reihenfolge wird passend gedreht).
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	tri_smooth(a, b, c, n, n, n)


## Ein Dreieck mit eigener Normale je Ecke (weiche Rundungen).
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face_n := na + nb + nc
	# Vorderseite = im Uhrzeigersinn, von der Normalen-Seite aus gesehen
	if (b - a).cross(c - a).dot(face_n) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	for v: Array in [[a, na], [b, nb], [c, nc]]:
		st.set_color(Color.WHITE)
		st.set_normal(v[1])
		st.add_vertex(v[0])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(a, b, c, n)
	tri(a, c, d, n)


## Ebene Fläche (beliebiges Vieleck) auf der Höhe z, sichtbar nach +z (facing 1) oder -z (-1).
func face(poly: PackedVector2Array, z: float, facing: float = 1.0) -> void:
	face_with_holes(poly, [], z, facing)


## Ebene Fläche mit Löchern.
func face_with_holes(outer: PackedVector2Array, holes: Array, z: float, facing: float = 1.0) -> void:
	var n := Vector3(0.0, 0.0, signf(facing))
	for piece in OpeningShape.pieces(outer, holes):
		var idx := Geometry2D.triangulate_polygon(piece)
		for i in range(0, idx.size(), 3):
			var a := piece[idx[i]]
			var b := piece[idx[i + 1]]
			var c := piece[idx[i + 2]]
			tri(Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), n)


## Seitenflächen entlang eines geschlossenen Umrisses von z0 bis z1. into = true: Normalen zeigen ins
## Innere des Umrisses (Laibung eines Lochs), false: nach außen (Rand einer Platte).
func loop_sides(loop: PackedVector2Array, z0: float, z1: float, into: bool = false) -> void:
	var count := loop.size()
	if count < 2:
		return
	var ccw := not Geometry2D.is_polygon_clockwise(loop)
	var edge_n: Array[Vector2] = []
	for i in count:
		var d := (loop[(i + 1) % count] - loop[i]).normalized()
		var out := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		edge_n.append(-out if into else out)
	for i in count:
		var j := (i + 1) % count
		var a := loop[i]
		var b := loop[j]
		var n := edge_n[i]
		# weiche Normalen, wo der Nachbar fast in derselben Richtung liegt
		var na := n
		var nb := n
		var prev := edge_n[(i - 1 + count) % count]
		var nxt := edge_n[j]
		if absf(prev.angle_to(n)) < SMOOTH_ANGLE:
			na = (prev + n).normalized()
		if absf(nxt.angle_to(n)) < SMOOTH_ANGLE:
			nb = (nxt + n).normalized()
		var n3a := Vector3(na.x, na.y, 0.0)
		var n3b := Vector3(nb.x, nb.y, 0.0)
		tri_smooth(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), n3a, n3b, n3b)
		tri_smooth(Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), n3a, n3b, n3a)


## Geschlossener Körper aus einem Umriss (Platte) von z0 bis z1, Löcher durchgehend.
func slab(outer: PackedVector2Array, z0: float, z1: float, holes: Array = []) -> void:
	face_with_holes(outer, holes, z1, 1.0)
	face_with_holes(outer, holes, z0, -1.0)
	loop_sides(outer, z0, z1, false)
	for hole: PackedVector2Array in holes:
		loop_sides(hole, z0, z1, true)


## Rahmen: Ring zwischen äußerem und innerem Umriss (inner liegt ganz in outer).
func ring(outer: PackedVector2Array, inner: PackedVector2Array, z0: float, z1: float) -> void:
	slab(outer, z0, z1, [inner])


## Sprosse/Leiste als Kasten zwischen zwei Punkten (Breite quer, Tiefe von z0 bis z1).
func bar(a: Vector2, b: Vector2, width: float, z0: float, z1: float) -> void:
	var d := (b - a)
	if d.length() < 0.001:
		return
	var side := Vector2(-d.y, d.x).normalized() * width / 2.0
	slab(PackedVector2Array([a - side, b - side, b + side, a + side]), z0, z1)


## Kasten (Mitte, Größe) – z. B. Fensterbank, Sturz, Eckstein. bevel = abgeschrägte Kanten vorn.
func box(center: Vector3, size: Vector3, bevel: float = 0.0) -> void:
	var h := size / 2.0
	var b := minf(bevel, minf(h.x, h.y) * 0.8)
	var front := PackedVector2Array([Vector2(-h.x + b, -h.y), Vector2(h.x - b, -h.y), Vector2(h.x, -h.y + b), Vector2(h.x, h.y - b),
		Vector2(h.x - b, h.y), Vector2(-h.x + b, h.y), Vector2(-h.x, h.y - b), Vector2(-h.x, -h.y + b)]) if b > 0.0 \
		else PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	var moved := OpeningShape.moved(front, Vector2(center.x, center.y))
	if b > 0.0:
		# vorn eine kleinere Fläche, dazwischen eine Schräge (weiche Kante)
		var inner := OpeningShape.moved(OpeningShape.offset(front, -b), Vector2(center.x, center.y))
		slab(moved, center.z - h.z, center.z + h.z - b)
		var top_z := center.z + h.z
		face(inner, top_z, 1.0)
		_bevel_band(moved, inner, center.z + h.z - b, top_z)
	else:
		slab(moved, center.z - h.z, center.z + h.z)


## Schräge zwischen zwei gleich langen Umrissen (außen auf z0, innen auf z1).
func _bevel_band(outer: PackedVector2Array, inner: PackedVector2Array, z0: float, z1: float) -> void:
	if outer.size() != inner.size():
		loop_sides(outer, z0, z1, false)
		return
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var a := Vector3(outer[i].x, outer[i].y, z0)
		var b := Vector3(outer[j].x, outer[j].y, z0)
		var c := Vector3(inner[j].x, inner[j].y, z1)
		var d := Vector3(inner[i].x, inner[i].y, z1)
		var n := (b - a).cross(d - a).normalized()
		if n.z < 0.0:
			n = -n
		quad(a, b, c, d, n)


func mesh() -> ArrayMesh:
	return st.commit()


## Ein fertiges Teil (Netz + Material) als Knoten.
func instance(material: Material, node_name: String = "Part") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh()
	mi.material_override = material
	return mi
