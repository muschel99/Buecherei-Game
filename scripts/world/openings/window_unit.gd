class_name WindowUnit
extends RefCounted
## Baut Fenster und Türumrahmungen aus ihrem Umriss (seit Etappe 6c): Rahmen, Glas, Sprossen, Gardinen,
## Erker, Raum hinter dem Glas und die Seiten-/Oberlichter der Ladentür. Alles im Rahmen der Öffnung
## (FacadeLayout.opening_frame: Mitte unten auf der Außenseite der Wand, x entlang, y oben, z nach draußen).
##
## Weil Wandausschnitt, Rahmen, Glas und Gardinen denselben Umriss benutzen, passen sie bei jeder Form
## (eckig, Bogen, rund, Erker) genau zusammen.

## Rahmenbreite und Sprossenbreite (Schaufenster unten, Fenster oben)
const FRAME_SHOP := 0.09
const FRAME_UPPER := 0.07
const MUNTIN := 0.035
## Tiefe: Schaufenster reichen durch die ganze Wand (innen 2 cm vor), oben sitzen die Fenster in der Laibung
const SHOP_Z := Vector2(-0.22, 0.072)
const UPPER_Z := Vector2(-0.15, -0.035)
## Untere Füllung der Seitenlichter an der Tür (kein Glas am Boden) bis zu dieser Höhe
const DOOR_PANEL_TOP := 0.45


## Ein Fenster (Schaufenster oder oben). materials: frame, glass, curtain, room, trim, zinc, base.
static func build_window(opening: Dictionary, materials: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = opening.id
	var style: FacadeOption = opening.style
	var upper: bool = opening.kind == "upper"
	var outline: PackedVector2Array = opening.outline
	var fw := FRAME_UPPER if upper else FRAME_SHOP
	var z := UPPER_Z if upper else SHOP_Z
	var frame := OpeningMesh.new()
	var glass := OpeningMesh.new()
	var bay := style.bay_depth > 0.0
	if bay:
		# Erker: Laibung als Rahmen durch die Wand, davor der Erker mit drei Fensterseiten
		frame.ring(outline, OpeningShape.offset(outline, -0.05), z.x, 0.02)
		_bay(root, outline, style, fw, upper, materials)
	else:
		var inner := OpeningShape.offset(outline, -fw)
		frame.ring(outline, inner, z.x, z.y)
		var gz := (z.x + z.y) / 2.0
		glass.face(inner, gz, 1.0)
		glass.face(inner, gz - 0.002, -1.0)
		_muntins(frame, inner, style.muntins, gz)
		if upper and style.shape != "round":
			# Kämpferholz der Fenster oben (wie bei alten Schiebefenstern)
			pass
	root.add_child(frame.instance(materials.frame, "Frame"))
	if not bay:
		root.add_child(glass.instance(materials.glass, "Glass"))
	if upper:
		if not bay:
			root.add_child(_curtains(OpeningShape.offset(outline, -fw), z.x - 0.03, materials.curtain))
		root.add_child(_room(outline, materials.room))
	return root


## Sprossen (Spalten x Reihen) innerhalb des Glases, an der Form abgeschnitten.
static func _muntins(mesh: OpeningMesh, inner: PackedVector2Array, grid: Vector2i, gz: float) -> void:
	if grid.x <= 1 and grid.y <= 1:
		return
	var b := OpeningShape.bounds(inner)
	for i in range(1, grid.x):
		var x := lerpf(b.position.x, b.end.x, float(i) / grid.x)
		var span := height_at(inner, x)
		if span.y > span.x:
			mesh.bar(Vector2(x, span.x), Vector2(x, span.y), MUNTIN, gz - 0.018, gz + 0.022)
	for j in range(1, grid.y):
		var y := lerpf(b.position.y, b.end.y, float(j) / grid.y)
		var span := OpeningShape.width_at(inner, y)
		if span.y > span.x:
			mesh.bar(Vector2(span.x, y), Vector2(span.y, y), MUNTIN, gz - 0.02, gz + 0.02)


## Höhe des Umrisses an der Stelle x: (unten, oben).
static func height_at(poly: PackedVector2Array, x: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in poly.size():
		var a := poly[i]
		var c := poly[(i + 1) % poly.size()]
		if (a.x - x) * (c.x - x) <= 0.0 and not is_equal_approx(a.x, c.x):
			var y := lerpf(a.y, c.y, (x - a.x) / (c.x - a.x))
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO


## Gardinen hinter dem Glas: zwei Bahnen an den Seiten, oben genau entlang der Fensterform (auch im
## Bogen und im Kreis), sanfte Falten.
static func _curtains(inner: PackedVector2Array, z: float, material: Material) -> MeshInstance3D:
	var mesh := OpeningMesh.new()
	var b := OpeningShape.bounds(inner)
	var panel := b.size.x * 0.26
	var steps := 10
	for side in [-1.0, 1.0]:
		var x_edge: float = b.position.x if side < 0.0 else b.end.x
		for i in steps:
			var x0: float = x_edge - side * panel * i / steps
			var x1: float = x_edge - side * panel * (i + 1) / steps
			var s0 := height_at(inner, x0 - side * 0.004)
			var s1 := height_at(inner, x1)
			if s0.y <= s0.x or s1.y <= s1.x:
				continue
			# Falten: Tiefe wechselt je Streifen, unten weiter auseinander
			var f0 := 0.025 * sin(PI * i * 0.9)
			var f1 := 0.025 * sin(PI * (i + 1) * 0.9)
			var a := Vector3(x0, s0.x + 0.03, z + f0)
			var c := Vector3(x1, s1.x + 0.03, z + f1)
			var d := Vector3(x1, s1.y - 0.01, z + f1 * 0.4)
			var e := Vector3(x0, s0.y - 0.01, z + f0 * 0.4)
			var n0 := Vector3(-0.3 * cos(PI * i * 0.9), 0.0, 1.0).normalized()
			var n1 := Vector3(-0.3 * cos(PI * (i + 1) * 0.9), 0.0, 1.0).normalized()
			mesh.tri_smooth(a, c, d, n0, n1, n1)
			mesh.tri_smooth(a, d, e, n0, n1, n0)
	return mesh.instance(material, "Curtains")


## Warmer Raum hinter einem Fenster oben (das Obergeschoss hat keine Einrichtung): offener Kasten.
static func _room(outline: PackedVector2Array, material: Material) -> MeshInstance3D:
	var b := OpeningShape.bounds(outline).grow(0.35)
	var mesh := OpeningMesh.new()
	var z0 := -0.28
	var z1 := -1.3
	var corners := [Vector2(b.position.x, b.position.y), Vector2(b.end.x, b.position.y), Vector2(b.end.x, b.end.y),
		Vector2(b.position.x, b.end.y)]
	# Rückwand (zeigt nach vorn) und vier Seiten (zeigen nach innen)
	mesh.quad(Vector3(corners[0].x, corners[0].y, z1), Vector3(corners[1].x, corners[1].y, z1),
		Vector3(corners[2].x, corners[2].y, z1), Vector3(corners[3].x, corners[3].y, z1), Vector3.BACK)
	for i in 4:
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		var mid := (p + q) / 2.0
		var n := (b.get_center() - mid).normalized()
		mesh.quad(Vector3(p.x, p.y, z0), Vector3(q.x, q.y, z0), Vector3(q.x, q.y, z1), Vector3(p.x, p.y, z1), Vector3(n.x, n.y, 0.0))
	var mi := mesh.instance(material, "Room")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Erker: drei Fensterseiten (vorn breit, seitlich schräg) vor der Öffnung, unten ein Sockel bzw.
## Konsolen, oben ein kleines Zinkdach. Grundriss ein Trapez bis bay_depth vor der Wand.
static func _bay(root: Node3D, outline: PackedVector2Array, style: FacadeOption, fw: float, upper: bool, materials: Dictionary) -> void:
	var b := OpeningShape.bounds(outline)
	var depth := style.bay_depth
	var hw := b.size.x / 2.0
	var front_hw := hw - depth * 0.62
	var y0 := b.position.y
	var y1 := b.end.y
	var plan := [Vector2(-hw, 0.0), Vector2(-front_hw, depth), Vector2(front_hw, depth), Vector2(hw, 0.0)]
	var frame := OpeningMesh.new()
	var glass := OpeningMesh.new()
	var stand := OpeningMesh.new()
	var cols := maxi(1, style.muntins.x)
	for k in 3:
		var p: Vector2 = plan[k]
		var q: Vector2 = plan[k + 1]
		var length := p.distance_to(q)
		var face_cols := cols if k == 1 else maxi(1, cols / 2)
		# Jede Seite als eigener flacher Fensterrahmen in ihrer Ebene (x quer, z = Dicke)
		var basis := Basis(Vector3(q.x - p.x, 0.0, q.y - p.y).normalized(), Vector3.UP, Vector3.ZERO)
		basis.z = basis.x.cross(Vector3.UP)
		var face_xform := Transform3D(basis, Vector3((p.x + q.x) / 2.0, 0.0, (p.y + q.y) / 2.0))
		var rect := OpeningShape.outline(OpeningShape.Kind.RECT, length + 0.02, y1 - y0)
		rect = OpeningShape.moved(rect, Vector2(0.0, y0))
		var inner := OpeningShape.offset(rect, -fw)
		var f := OpeningMesh.new()
		f.ring(rect, inner, -0.03, 0.03)
		_muntins(f, inner, Vector2i(face_cols, style.muntins.y), 0.0)
		var g := OpeningMesh.new()
		g.face(inner, 0.0, 1.0)
		g.face(inner, -0.002, -1.0)
		var fi := f.instance(materials.frame, "BayFrame%d" % k)
		fi.transform = face_xform
		root.add_child(fi)
		var gi := g.instance(materials.glass, "BayGlass%d" % k)
		gi.transform = face_xform
		root.add_child(gi)
	# Boden (innen die Ablage) und Deckel als Trapez-Platten; unten Sockel (Laden) bzw. Konsolen (oben)
	var trapezoid := PackedVector2Array()
	for p: Vector2 in plan:
		trapezoid.append(Vector2(p.x, -p.y))
	var plates := OpeningMesh.new()
	for plate_y: float in [y0 - 0.06, y1]:
		var slab := OpeningMesh.new()
		slab.slab(trapezoid, 0.0, 0.06)
		var si := slab.instance(materials.frame, "BayPlate")
		si.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, plate_y, 0.0))
		root.add_child(si)
	if not upper:
		# Sockel bis zum Gehweg in der Rahmenfarbe
		var base := OpeningMesh.new()
		base.slab(trapezoid, 0.0, y0 - 0.06 - FacadeLayout.GROUND)
		var bi := base.instance(materials.frame, "BayBase")
		bi.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, FacadeLayout.GROUND, 0.0))
		root.add_child(bi)
	else:
		for sx in [-hw + 0.08, hw - 0.08]:
			stand.box(Vector3(sx, y0 - 0.22, 0.12), Vector3(0.1, 0.3, 0.24), 0.02)
		root.add_child(stand.instance(materials.trim, "BayConsoles"))
	# Kleines Dach aus Zink über dem Erker
	var roof := OpeningMesh.new()
	roof.box(Vector3(0.0, 0.0, depth / 2.0 + 0.04), Vector3(b.size.x + 0.12, 0.035, depth + 0.16), 0.01)
	var ri := roof.instance(materials.zinc, "BayRoof")
	ri.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(18.0)), Vector3(0.0, y1 + 0.1, 0.0))
	root.add_child(ri)
	if upper:
		root.add_child(_room(outline, materials.room))


## Umrahmung der Ladentür: Rahmen um die ganze Öffnung, Pfosten/Kämpfer rund ums Türblatt, Glas in den
## Seiten- und Oberlichtern (unten Holzfüllungen), Sprossen. Das Türblatt selbst gehört zur Tür (Door).
static func build_door_surround(opening: Dictionary, materials: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "DoorSurround"
	var outline: PackedVector2Array = opening.outline
	var leaf: PackedVector2Array = opening.leaf
	var casing := FacadeLayout.CASING
	var inner := OpeningShape.offset(outline, -casing)
	var frame := OpeningMesh.new()
	frame.ring(outline, inner, -0.23, 0.072)
	# Band um das Türblatt (unten offen: Schwelle)
	var floor_cut := PackedVector2Array([Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Vector2(5.0, 10.0), Vector2(-5.0, 10.0)])
	var leaf_band := _first(Geometry2D.intersect_polygons(_offset_miter(leaf, FacadeLayout.MULLION), floor_cut))
	var glass := OpeningMesh.new()
	var panels := OpeningMesh.new()
	if not leaf_band.is_empty():
		for band: PackedVector2Array in Geometry2D.clip_polygons(leaf_band, leaf):
			if not Geometry2D.is_polygon_clockwise(band):
				frame.slab(band, -0.14, -0.06)
		for piece: PackedVector2Array in Geometry2D.clip_polygons(inner, leaf_band):
			if Geometry2D.is_polygon_clockwise(piece) or absf(_area(piece)) < 0.004:
				continue
			var pb := OpeningShape.bounds(piece)
			var low_cut := PackedVector2Array([Vector2(-5.0, -1.0), Vector2(5.0, -1.0), Vector2(5.0, DOOR_PANEL_TOP), Vector2(-5.0, DOOR_PANEL_TOP)])
			if pb.position.y < DOOR_PANEL_TOP - 0.01:
				# Seitenlicht: unten Holzfüllung, darüber Glas mit Sprossen
				for low: PackedVector2Array in Geometry2D.intersect_polygons(piece, low_cut):
					panels.slab(low, -0.13, -0.07)
				for high: PackedVector2Array in Geometry2D.clip_polygons(piece, low_cut):
					if Geometry2D.is_polygon_clockwise(high):
						continue
					_pane(glass, high)
					var hb := OpeningShape.bounds(high)
					frame.bar(Vector2(hb.position.x, DOOR_PANEL_TOP), Vector2(hb.end.x, DOOR_PANEL_TOP), 0.04, -0.13, -0.07)
					var yy := DOOR_PANEL_TOP + 0.5
					while yy < hb.end.y - 0.25:
						var span := OpeningShape.width_at(high, yy)
						if span.y > span.x:
							frame.bar(Vector2(span.x, yy), Vector2(span.y, yy), MUNTIN, -0.12, -0.08)
						yy += 0.5
			else:
				# Oberlicht: Glas mit zwei senkrechten Sprossen
				_pane(glass, piece)
				for i in [1, 2]:
					var x := lerpf(pb.position.x, pb.end.x, i / 3.0)
					var span := height_at(piece, x)
					if span.y > span.x:
						frame.bar(Vector2(x, span.x), Vector2(x, span.y), MUNTIN, -0.12, -0.08)
	root.add_child(frame.instance(materials.frame, "Frame"))
	root.add_child(glass.instance(materials.glass, "Glass"))
	root.add_child(panels.instance(materials.frame, "Panels"))
	return root


static func _pane(mesh: OpeningMesh, poly: PackedVector2Array) -> void:
	mesh.face(poly, -0.1, 1.0)
	mesh.face(poly, -0.102, -1.0)


static func _offset_miter(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	return _first(Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_MITER))


static func _first(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	for p: PackedVector2Array in polys:
		if not Geometry2D.is_polygon_clockwise(p) and p.size() > best.size():
			best = p
	return best


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0
