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
## Anschlag der Ladentür: so weit greift die Leiste über das Türblatt, Tiefe (außen vor dem Blatt, das in
## der Mitte des Rahmens bei z = -0,1 sitzt und 5 cm dick ist)
const DOOR_STOP := 0.03
const DOOR_STOP_Z := Vector2(-0.073, -0.06)


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
		_muntins(frame, inner, style, gz)
		if upper and style.shape != "round":
			# Kämpferholz der Fenster oben (wie bei alten Schiebefenstern)
			pass
	root.add_child(frame.instance(materials.frame, "Frame"))
	if not bay:
		root.add_child(glass.instance(materials.glass, "Glass"))
	if upper:
		if not bay:
			root.add_child(_curtains(outline, materials.curtain, materials.frame))
		root.add_child(_room(outline, materials.room))
	return root


## Sprossen innerhalb des Glases, an der Form abgeschnitten (Bild siehe muntin_bars).
static func _muntins(mesh: OpeningMesh, inner: PackedVector2Array, style: FacadeOption, gz: float) -> void:
	for bar: Array in muntin_bars(inner, style.muntins, style.pattern):
		var z: Vector2 = bar[3]
		mesh.bar(bar[0], bar[1], bar[2], gz + z.x, gz + z.y)


## Breite der kräftigen Pfosten und Kämpfer (Sprossenbilder "transom" und "tripartite")
const MULLION_BAR := 0.06
## Höhe des Kämpfers ("transom") als Anteil der Glashöhe
const TRANSOM_AT := 0.72

## Alle Sprossen eines Fensters als [von, bis, Breite, Tiefe (vorn/hinten relativ zur Glasmitte)] – für das
## Modell und für die gezeichnete Kachel in der App „Fassade“. Senkrechte und waagerechte Stäbe haben
## leicht verschiedene Tiefen, damit sich ihre Vorderseiten an Kreuzungen nie genau überdecken.
static func muntin_bars(inner: PackedVector2Array, grid: Vector2i, pattern: String = "grid") -> Array:
	var bars := []
	var b := OpeningShape.bounds(inner)
	var vz := Vector2(-0.018, 0.022)
	var hz := Vector2(-0.02, 0.02)
	var heavy := Vector2(-0.024, 0.026)
	match pattern:
		"transom":
			# kräftiger Kämpfer, darüber kleine Scheiben, darunter wenige große
			var yt := lerpf(b.position.y, b.end.y, TRANSOM_AT)
			var span := OpeningShape.width_at(inner, yt)
			bars.append([Vector2(span.x, yt), Vector2(span.y, yt), MULLION_BAR, heavy])
			for i in range(1, grid.x):
				var x := lerpf(b.position.x, b.end.x, float(i) / grid.x)
				var top := height_at(inner, x).y
				if top > yt + 0.05:
					bars.append([Vector2(x, yt), Vector2(x, top), MUNTIN, vz])
			for i in range(1, grid.y):
				var x := lerpf(b.position.x, b.end.x, float(i) / grid.y)
				var low := height_at(inner, x).x
				bars.append([Vector2(x, low), Vector2(x, yt), MULLION_BAR * 0.8, vz])
		"tripartite":
			# große Mittelscheibe, schmale Seitenfelder mit Sprossen
			var side_w := b.size.x * 0.22
			for x: float in [b.position.x + side_w, b.end.x - side_w]:
				var span := height_at(inner, x)
				bars.append([Vector2(x, span.x), Vector2(x, span.y), MULLION_BAR, heavy])
			for j in range(1, grid.y):
				var y := lerpf(b.position.y, b.end.y, float(j) / grid.y)
				var span := OpeningShape.width_at(inner, y)
				if span.y <= span.x:
					continue
				bars.append([Vector2(span.x, y), Vector2(b.position.x + side_w, y), MUNTIN, hz])
				bars.append([Vector2(b.end.x - side_w, y), Vector2(span.y, y), MUNTIN, hz])
		_:
			for i in range(1, grid.x):
				var x := lerpf(b.position.x, b.end.x, float(i) / grid.x)
				var span := height_at(inner, x)
				if span.y > span.x:
					bars.append([Vector2(x, span.x), Vector2(x, span.y), MUNTIN, vz])
			for j in range(1, grid.y):
				var y := lerpf(b.position.y, b.end.y, float(j) / grid.y)
				var span := OpeningShape.width_at(inner, y)
				if span.y > span.x:
					bars.append([Vector2(span.x, y), Vector2(span.y, y), MUNTIN, hz])
	return bars


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


## Gardinen innen vor dem Fenster oben (seit Etappe 6d bei jeder Fensterform gerade): eine gerade Stange mit
## Haltern über dem Fenster, zwei Bahnen hängen gerade herunter (sanfte Falten) – vor der Innenseite der
## 30 cm dicken Wand, nie in der Laibung.
const CURTAIN_Z := -0.34
static func _curtains(outline: PackedVector2Array, material: Material, rod_material: Material) -> Node3D:
	var node := Node3D.new()
	node.name = "Curtains"
	var mesh := OpeningMesh.new()
	var rod := OpeningMesh.new()
	var b := OpeningShape.bounds(outline)
	var panel := b.size.x * 0.3
	var top := b.end.y + 0.08
	var bottom := b.position.y + 0.02
	var steps := 10
	for side in [-1.0, 1.0]:
		var x_edge: float = (b.position.x - 0.06) if side < 0.0 else (b.end.x + 0.06)
		for i in steps:
			var x0: float = x_edge - side * panel * i / steps
			var x1: float = x_edge - side * panel * (i + 1) / steps
			# Falten: Tiefe wechselt je Streifen, unten etwas weiter auseinander
			var f0 := 0.025 * sin(PI * i * 0.9)
			var f1 := 0.025 * sin(PI * (i + 1) * 0.9)
			var a := Vector3(x0, bottom, CURTAIN_Z - f0)
			var c := Vector3(x1, bottom, CURTAIN_Z - f1)
			var d := Vector3(x1, top, CURTAIN_Z - f1 * 0.4)
			var e := Vector3(x0, top, CURTAIN_Z - f0 * 0.4)
			var n0 := Vector3(-0.3 * cos(PI * i * 0.9), 0.0, 1.0).normalized()
			var n1 := Vector3(-0.3 * cos(PI * (i + 1) * 0.9), 0.0, 1.0).normalized()
			mesh.tri_smooth(a, c, d, n0, n1, n1)
			mesh.tri_smooth(a, d, e, n0, n1, n0)
	var x_lo := b.position.x - 0.14
	var x_hi := b.end.x + 0.14
	rod.bar(Vector2(x_lo, top + 0.02), Vector2(x_hi, top + 0.02), 0.025, CURTAIN_Z - 0.012, CURTAIN_Z + 0.012)
	for x in [x_lo + 0.03, x_hi - 0.03]:
		rod.bar(Vector2(x, top + 0.008), Vector2(x, top + 0.032), 0.02, CURTAIN_Z - 0.01, -0.295)
	node.add_child(mesh.instance(material, "Cloth"))
	node.add_child(rod.instance(rod_material, "Rod"))
	return node


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
		for bar: Array in muntin_bars(inner, Vector2i(face_cols, style.muntins.y)):
			f.bar(bar[0], bar[1], bar[2], (bar[3] as Vector2).x, (bar[3] as Vector2).y)
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
		# Anschlag (seit Etappe 6f): außen eine schmale Leiste, die 3 cm über den Rand des Türblatts greift –
		# das Blatt (98 x 218 cm) schließt dagegen, und durch die Fuge sieht man nicht mehr hindurch. Die Tür
		# geht nach innen auf, die Leiste außen stört dabei nicht. Unten bleibt die Schwelle frei.
		var above_floor := PackedVector2Array([Vector2(-5.0, 0.03), Vector2(5.0, 0.03), Vector2(5.0, 10.0), Vector2(-5.0, 10.0)])
		var leaf_inner := _offset_miter(leaf, -DOOR_STOP)
		if not leaf_inner.is_empty():
			# innen nach unten verlängert: so wird der Rest ein unten offenes U (ein Ring käme als Außenform +
			# Loch zurück, und die Außenform allein würde das ganze Blatt zudecken)
			var ib := OpeningShape.bounds(leaf_inner)
			var down := PackedVector2Array([Vector2(ib.position.x, -1.0), Vector2(ib.end.x, -1.0),
				Vector2(ib.end.x, ib.position.y + 0.1), Vector2(ib.position.x, ib.position.y + 0.1)])
			leaf_inner = _first(Geometry2D.merge_polygons(leaf_inner, down))
			for ring: PackedVector2Array in Geometry2D.clip_polygons(leaf, leaf_inner):
				if Geometry2D.is_polygon_clockwise(ring):
					continue
				for stop: PackedVector2Array in Geometry2D.intersect_polygons(ring, above_floor):
					if not Geometry2D.is_polygon_clockwise(stop):
						frame.slab(stop, DOOR_STOP_Z.x, DOOR_STOP_Z.y)
		# Seit Etappe 6d: das Glas um das Türblatt in linkes und rechtes Seitenlicht und das Oberlicht teilen
		# (vorher hing es U-förmig zusammen, und die Sprossen liefen quer durch die Türöffnung)
		var lb := OpeningShape.bounds(leaf_band)
		var zones := [_zone(-5.0, lb.position.x), _zone(lb.end.x, 5.0), _zone(lb.position.x, lb.end.x)]
		var parts: Array[PackedVector2Array] = []
		for whole: PackedVector2Array in Geometry2D.clip_polygons(inner, leaf_band):
			if Geometry2D.is_polygon_clockwise(whole):
				continue
			for zone: PackedVector2Array in zones:
				for part: PackedVector2Array in Geometry2D.intersect_polygons(whole, zone):
					if not Geometry2D.is_polygon_clockwise(part):
						parts.append(part)
		# Pfosten zwischen Seitenlicht und Oberlicht (über dem Türblatt, nie in der Öffnung): genau die
		# Verlängerung des Rahmens ums Türblatt – gleiche Breite, gleiche Tiefe, bündig ohne Versatz
		for side: float in [-1.0, 1.0]:
			var outer_x: float = lb.position.x if side < 0.0 else lb.end.x
			var x := outer_x - side * FacadeLayout.MULLION / 2.0
			# unten bis in den Rahmen hinein (beim Rundbogen ist er schräg – nie eine schwebende Ecke)
			var half := FacadeLayout.MULLION / 2.0 - 0.001
			var above := minf(height_at(leaf_band, x - half).y, height_at(leaf_band, x + half).y)
			var top := height_at(inner, x).y
			if top > above + 0.05:
				frame.bar(Vector2(x, above), Vector2(x, top + 0.002), FacadeLayout.MULLION, -0.14, -0.06)
		for piece: PackedVector2Array in parts:
			if absf(_area(piece)) < 0.004:
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


## Senkrechter Streifen von x0 bis x1 (zum Zerlegen des Glases um die Tür).
static func _zone(x0: float, x1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, -1.0), Vector2(x1, -1.0), Vector2(x1, 10.0), Vector2(x0, 10.0)])


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
