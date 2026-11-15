class_name BookLook
extends RefCounted
## Wie ein Buch aussieht: Größe, Farbe und Verzierung des Rückens.
##
## Alles steht im Titel (BookData) – so sehen alle Exemplare eines Titels gleich aus,
## auch nach dem Laden. Die Spannweiten stehen in GameConfig
## (book_height_range, book_thickness_range, book_depth_range, book_color_variation).
## Gemeinsames Material für alle Bücher: get_material() (Shader book_spine.gdshader,
## Buchrücken aus dem Atlas von BookArt).

static var _material: ShaderMaterial
static var _mesh: ArrayMesh

## Weiche Buchform (seit Etappe 8) im Würfel der Größe 1: Deckel (Stärke BOARD der Dicke) stehen über den Buchblock über
## (PAGE_INSET), der Rücken ist gewölbt (SPINE_BULGE der Tiefe), die Deckel haben vorn runde Ecken (CORNER).
const BOARD := 0.11
const PAGE_INSET := 0.03
const SPINE_BULGE := 0.075
const SPINE_SHELL := 0.06
const CORNER := 0.07
## Teile (UV2.x) für die Shader book_spine/book_loose: Rücken, vorderer Einband, hinterer Einband, Kanten, Seiten
enum Part { SPINE, FRONT, BACK, EDGE, PAGES }


## Größe in Metern: x = Dicke (Rücken), y = Höhe, z = Tiefe (steht im Titel, BookData).
static func get_size(book: Book) -> Vector3:
	return book.data.size


## Farbe des Einbands.
static func get_color(book: Book) -> Color:
	return book.data.cover_color


## Wo der Buchrücken im Atlas liegt (für den Shader, siehe BookArt.get_spine_uv).
static func get_custom(book: Book) -> Color:
	return BookArt.get_spine_uv(book.data)


## Die Buchform im Würfel der Größe 1 – jedes Buch ist diese Form, auf seine Größe gestreckt (x = Dicke, y = Höhe,
## z = Tiefe; Rücken +Z, vorderer Einband +X). UV = Lage auf der Fläche (Rücken: quer/hoch, Einband: vom Rücken zur
## Vorderkante/hoch), UV2.x = Teil (Part).
static func get_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build_mesh()
	return _mesh


static func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine_z := 0.5 - SPINE_BULGE  # hier treffen Deckel und Rücken aufeinander
	# Deckel: abgerundetes Rechteck in y/z (vorn runde Ecken), um BOARD dick in x
	var outline := PackedVector2Array()  # (z, y)
	outline.append(Vector2(spine_z, -0.5))
	for corner: Array in [[Vector2(-0.5 + CORNER, -0.5 + CORNER), PI * 1.5, PI], [Vector2(-0.5 + CORNER, 0.5 - CORNER), PI, PI * 0.5]]:
		for i in 7:
			var a: float = lerpf(corner[1], corner[2], i / 6.0)
			outline.append(corner[0] + Vector2(cos(a), sin(a)) * CORNER)
	outline.append(Vector2(spine_z, 0.5))
	for side: float in [1.0, -1.0]:
		var outer := 0.5 * side
		var inner := (0.5 - BOARD) * side
		var part := Part.FRONT if side > 0.0 else Part.BACK
		var face := func(x: float) -> PackedVector3Array:
			var pts := PackedVector3Array()
			for p in outline:
				pts.append(Vector3(x, p.y, p.x))
			return pts
		var out_pts: PackedVector3Array = face.call(outer)
		var in_pts: PackedVector3Array = face.call(inner)
		var center_out := Vector3(outer, 0.0, (spine_z - 0.5) / 2.0)
		var center_in := Vector3(inner, 0.0, (spine_z - 0.5) / 2.0)
		for i in out_pts.size():
			var j := (i + 1) % out_pts.size()  # zuletzt die Seite am Rücken (schließt die Fläche)
			_tri(st, center_out, out_pts[i], out_pts[j], Vector3(side, 0, 0), part, _cover_uv)
			_tri(st, center_in, in_pts[j], in_pts[i], Vector3(-side, 0, 0), Part.EDGE, _cover_uv)
		# Kante rundherum (nicht zum Rücken hin)
		for i in out_pts.size() - 1:
			var n := Vector3(0.0, out_pts[i + 1].y - out_pts[i].y, out_pts[i + 1].z - out_pts[i].z).cross(Vector3(side, 0, 0)).normalized()
			if n.dot(Vector3(0, out_pts[i].y + out_pts[i + 1].y, out_pts[i].z + out_pts[i + 1].z - 2.0 * center_out.z)) < 0.0:
				n = -n
			_quad(st, out_pts[i], out_pts[i + 1], in_pts[i + 1], in_pts[i], n, Part.EDGE)
	# Buchblock (Seiten) zwischen den Deckeln
	var px := 0.5 - BOARD + 0.002
	var lo := Vector3(-px, -0.5 + PAGE_INSET, -0.5 + PAGE_INSET)
	var hi := Vector3(px, 0.5 - PAGE_INSET, spine_z)
	_box(st, lo, hi, Part.PAGES)
	# gewölbter Rücken: Schale von Deckel zu Deckel
	var steps := 10
	var outer_curve: Array[Vector3] = []
	var inner_curve: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(-PI / 2.0, PI / 2.0, t)
		var x := sin(a) * 0.5
		var z := spine_z + cos(a) * SPINE_BULGE
		outer_curve.append(Vector3(x, 0.0, z))
		inner_curve.append(Vector3(x * (1.0 - SPINE_SHELL), 0.0, spine_z + cos(a) * (SPINE_BULGE - SPINE_SHELL) - 0.004))
		normals.append(Vector3(sin(a), 0.0, cos(a) * 0.5 / SPINE_BULGE).normalized())
	var y0 := Vector3(0, -0.5, 0)
	var y1 := Vector3(0, 0.5, 0)
	for i in steps:
		var a0 := outer_curve[i]
		var a1 := outer_curve[i + 1]
		# Lage auf dem Rücken nach der sichtbaren Breite (von vorn gesehen gleichmäßig) – nicht nach dem Winkel, sonst wird die
		# Schrift in der Mitte gedehnt und am Rand gestaucht (Nachtest von Etappe 8: „Titel verzerrt“)
		var u0 := 0.5 + a0.x
		var u1 := 0.5 + a1.x
		# Außenseite (weich schattiert)
		_vertex(st, a0 + y0, normals[i], Vector2(u0, 1.0), Part.SPINE)
		_vertex(st, a0 + y1, normals[i], Vector2(u0, 0.0), Part.SPINE)
		_vertex(st, a1 + y1, normals[i + 1], Vector2(u1, 0.0), Part.SPINE)
		_vertex(st, a0 + y0, normals[i], Vector2(u0, 1.0), Part.SPINE)
		_vertex(st, a1 + y1, normals[i + 1], Vector2(u1, 0.0), Part.SPINE)
		_vertex(st, a1 + y0, normals[i + 1], Vector2(u1, 1.0), Part.SPINE)
		# Deckel oben und unten (Stirnseite der Schale)
		var b0 := inner_curve[i]
		var b1 := inner_curve[i + 1]
		_quad(st, a0 + y1, a1 + y1, b1 + y1, b0 + y1, Vector3.UP, Part.EDGE)
		_quad(st, a0 + y0, b0 + y0, b1 + y0, a1 + y0, Vector3.DOWN, Part.EDGE)
	return st.commit()


## Lage auf dem Einband: u vom Rücken (0) zur Vorderkante (1), v von oben (0) nach unten (1).
static func _cover_uv(p: Vector3) -> Vector2:
	var spine_z := 0.5 - SPINE_BULGE
	return Vector2((spine_z - p.z) / (spine_z + 0.5), 0.5 - p.y)


static func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, part: int) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.set_uv2(Vector2(float(part), 0.0))
	st.add_vertex(p)


## Dreieck mit Vorderseite in Richtung n (Godot zeichnet Dreiecke im Uhrzeigersinn als Vorderseite).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, part: int, uv_of: Callable = Callable()) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var swap := b
		b = c
		c = swap
	for p in [a, b, c]:
		_vertex(st, p, n, uv_of.call(p) if uv_of.is_valid() else Vector2(p.z + 0.5, 0.5 - p.y), part)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, part: int) -> void:
	_tri(st, a, b, c, n, part)
	_tri(st, a, c, d, n, part)


static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, part: int) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	_quad(st, c[0], c[1], c[2], c[3], Vector3.BACK * -1.0, part)   # vorn (Vorderkante, -z)
	_quad(st, c[4], c[7], c[6], c[5], Vector3.BACK, part)          # hinten (+z, unter dem Rücken)
	_quad(st, c[0], c[4], c[5], c[1], Vector3.DOWN, part)
	_quad(st, c[3], c[2], c[6], c[7], Vector3.UP, part)
	_quad(st, c[0], c[3], c[7], c[4], Vector3.LEFT, part)
	_quad(st, c[1], c[5], c[6], c[2], Vector3.RIGHT, part)


## Gemeinsames Material aller Bücher (Farbe kommt je Buch aus dem MultiMesh).
static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://assets/shaders/book_spine.gdshader")
		_material.set_shader_parameter("spine_atlas", BookArt.get_spine_atlas())
		_material.set_shader_parameter("page_tint", GameConfig.book_page_tint)
	return _material


## Eigenes Material für ein einzelnes Buch mit Cover-Bild (z. B. das Buch in der Hand).
static func create_cover_material() -> ShaderMaterial:
	var material := get_material().duplicate() as ShaderMaterial
	material.set_shader_parameter("use_cover", true)
	return material


## Eigenes Material für ein einzelnes Buch ohne Cover-Bild (Farbe und Rücken eines Titels; Kisten, Requisiten).
static func create_single_material(data: BookData) -> ShaderMaterial:
	var material := get_material().duplicate() as ShaderMaterial
	material.set_shader_parameter("use_single", true)
	material.set_shader_parameter("single_color", data.cover_color)
	var rect := BookArt.get_spine_uv(data)
	material.set_shader_parameter("single_spine_rect", Vector4(rect.r, rect.g, rect.b, rect.a))
	return material


## Ein neues MultiMesh für viele Bücher (Farbe und Verzierung je Buch).
static func create_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = get_mesh()
	return multimesh

