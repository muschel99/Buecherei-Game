@tool
class_name GatehouseFacade
extends HouseFacade
## Das Torhaus am Ende der abbiegenden Seitenstraße (seit Etappe 4f): ein Haus mit
## Durchfahrt, durch dessen Bogen die Straße hindurchläuft. Eigener Haustyp
## (scenes/world/houses/gatehouse.tscn), Platzhalter aus einfachen Formen:
## - unten gemauert, mit großem Rundbogen über der Fahrbahn (Bogensteine, Schlussstein,
##   Kämpfersteine, Ecksteine) und einer gewölbten Durchfahrt bis zur Rückseite,
## - darüber ein waagerechtes Band für ein Schild (Akzentfarbe),
## - ein Obergeschoss in Fachwerk-Optik (Balken in der Türfarbe), leicht vorkragend,
## - Satteldach mit einer mittigen Gaube mit Sprossenfenster.
## Wie bei allen Häusern: Liegt ein Knoten "Model" in der Szene, verschwindet der Platzhalter.
## Ein eigenes Modell muss die Öffnung des Bogens frei lassen – die Straße darunter baut das
## Spiel (Street). Die Kollision sind nur die beiden Mauerpfeiler links und rechts.
##
## Ursprung: unten in der Mitte der Vorderseite (Gehweg-Höhe), Vorderseite nach +Z, die
## Durchfahrt reicht bis -depth.

@export_group("Durchfahrt")
## Lichte Breite des Bogens (Fahrbahn + schmale Gehwege darunter).
@export var passage_width: float = 6.5:
	set(value):
		passage_width = value
		_queue_rebuild()
## Höhe, ab der sich der Bogen rundet (Kämpferlinie); der Scheitel liegt eine halbe
## Bogenbreite höher.
@export var arch_spring: float = 2.0:
	set(value):
		arch_spring = value
		_queue_rebuild()
## Oberkante des gemauerten Erdgeschosses (darüber das Schild-Band).
@export var masonry_height: float = 5.8:
	set(value):
		masonry_height = value
		_queue_rebuild()
## Höhe des Schild-Bands.
@export var sign_band_height: float = 0.5:
	set(value):
		sign_band_height = value
		_queue_rebuild()
## So weit kragt das Fachwerk-Obergeschoss vorn über.
@export var jetty: float = 0.25:
	set(value):
		jetty = value
		_queue_rebuild()

## Unterteilung des Bogens (mehr = runder)
const ARCH_SEGMENTS := 18
## Breite des Bogenrings (Bogensteine) und wie weit er vorsteht
const RING := 0.38
const RING_PROUD := 0.05
## Feste Farben (Alpha 1): Bogen- und Ecksteine, Putz zwischen dem Fachwerk
const STONE := Color(0.78, 0.74, 0.66, 1.0)
const STONE_DARK := Color(0.7, 0.66, 0.58, 1.0)
const INFILL := Color(0.9, 0.86, 0.76, 1.0)
const BEAM := Color(1.0, 1.0, 1.0, 0.5)
const BEAM_DARK := Color(0.75, 0.75, 0.75, 0.5)
const VAULT := Color(0.62, 0.62, 0.62, 0.75)


func _mesh_key() -> String:
	return super._mesh_key() + str([passage_width, arch_spring, masonry_height, sign_band_height, jetty])


## Nur die beiden Mauerpfeiler sind fest – die Durchfahrt bleibt frei (die unsichtbare Grenze
## davor baut die Straße). Über dem Bogen verdeckt ein Sichtblocker (Ebene "sight_blocker",
## seit Etappe 5a) die Sicht – durch die Öffnung des Bogens sieht man hindurch.
func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = _collision_layer()
	_body.collision_mask = 0
	var pier := width / 2.0 - passage_width / 2.0
	for side in [-1.0, 1.0]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(pier, eaves_height, depth)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(side * (passage_width / 2.0 + pier / 2.0), eaves_height / 2.0, -depth / 2.0)
		_body.add_child(collision)
	add_child(_body)
	var sight := StaticBody3D.new()
	sight.name = "SightBlocker"
	sight.collision_layer = SIGHT_BLOCKER_LAYER
	sight.collision_mask = 0
	var crown := arch_spring + passage_width / 2.0
	var box := BoxShape3D.new()
	box.size = Vector3(passage_width, eaves_height - crown, depth)
	var top := CollisionShape3D.new()
	top.shape = box
	top.position = Vector3(0.0, (crown + eaves_height) / 2.0, -depth / 2.0)
	sight.add_child(top)
	_body.add_child(sight)


## Gemauertes Erdgeschoss mit Bogen und gewölbter Durchfahrt, Seitenwände.
func _build_body(builder: WorldMesh) -> void:
	var w := width / 2.0
	var a := passage_width / 2.0
	# Mauer bis zur Oberkante des Schild-Bands (das Band liegt vorn davor)
	var top := masonry_height + sign_band_height
	var arch := _arch_points(a)
	for face in [[0.0, Vector3.BACK], [-depth, Vector3.FORWARD]]:
		var z: float = face[0]
		var normal: Vector3 = face[1]
		# Pfeiler links und rechts, darüber die Zwickel um den Bogen
		builder.add_quad(Vector3(-w, 0.0, z), Vector3(-a, 0.0, z), Vector3(-a, top, z), Vector3(-w, top, z), normal, WALL)
		builder.add_quad(Vector3(a, 0.0, z), Vector3(w, 0.0, z), Vector3(w, top, z), Vector3(a, top, z), normal, WALL)
		for i in arch.size() - 1:
			var p := arch[i]
			var q := arch[i + 1]
			builder.add_quad(Vector3(p.x, p.y, z), Vector3(q.x, q.y, z), Vector3(q.x, top, z), Vector3(p.x, top, z), normal, WALL)
		_add_arch_ring(builder, z, normal)
	# Seitenwände
	for side in [-1.0, 1.0]:
		var x: float = side * w
		builder.add_quad(Vector3(x, 0.0, 0.0), Vector3(x, 0.0, -depth), Vector3(x, top, -depth), Vector3(x, top, 0.0),
			Vector3(side, 0.0, 0.0), WALL)
	# Durchfahrt: senkrechte Wände bis zur Kämpferlinie, darüber das Gewölbe
	for side in [-1.0, 1.0]:
		var x: float = side * a
		builder.add_quad(Vector3(x, 0.0, 0.0), Vector3(x, 0.0, -depth), Vector3(x, arch_spring, -depth),
			Vector3(x, arch_spring, 0.0), Vector3(-side, 0.0, 0.0), VAULT)
	for i in arch.size() - 1:
		var p := arch[i]
		var q := arch[i + 1]
		var mid := (p + q) / 2.0
		var inward := Vector3(-mid.x, arch_spring - mid.y, 0.0).normalized()
		builder.add_quad(Vector3(p.x, p.y, 0.0), Vector3(q.x, q.y, 0.0), Vector3(q.x, q.y, -depth),
			Vector3(p.x, p.y, -depth), inward, VAULT)
	# Sockel an den Pfeilern (vorn) und Ecksteine an den Außenkanten
	var skip := PackedStringArray(["bottom", "back"])
	builder.add_box(Vector3(-w, 0.0, 0.0), Vector3(-a, plinth_height, plinth_proud), PLINTH, skip)
	builder.add_box(Vector3(a, 0.0, 0.0), Vector3(w, plinth_height, plinth_proud), PLINTH, skip)
	var y := plinth_height
	var k := 0
	while y + 0.3 < masonry_height:
		# Nicht genau so breit wie der verdeckte Rand (0,55 m) – sonst flimmert die Kante
		var block := 0.5 if k % 2 == 0 else 0.3
		for side in [-1.0, 1.0]:
			var outer: float = side * w
			var inner: float = outer - side * block
			builder.add_box(Vector3(minf(outer, inner), y, 0.0), Vector3(maxf(outer, inner), y + 0.4, 0.03),
				STONE if k % 2 == 0 else STONE_DARK, skip)
		y += 0.43
		k += 1


## Punkte des Bogens von links (Kämpfer) über den Scheitel nach rechts (x, y).
func _arch_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ARCH_SEGMENTS + 1:
		var angle := PI - PI * i / ARCH_SEGMENTS
		points.append(Vector2(radius * cos(angle), arch_spring + radius * sin(angle)))
	return points


## Bogensteine (abwechselnd hell und etwas dunkler), Schlussstein oben, Kämpfersteine.
func _add_arch_ring(builder: WorldMesh, z: float, normal: Vector3) -> void:
	var a := passage_width / 2.0
	var proud := normal.z * RING_PROUD
	var inner := _arch_points(a)
	var outer := _arch_points(a + RING)
	for i in inner.size() - 1:
		var color := STONE if i % 2 == 0 else STONE_DARK
		var p0 := Vector3(inner[i].x, inner[i].y, z + proud)
		var p1 := Vector3(inner[i + 1].x, inner[i + 1].y, z + proud)
		var q0 := Vector3(outer[i].x, outer[i].y, z + proud)
		var q1 := Vector3(outer[i + 1].x, outer[i + 1].y, z + proud)
		builder.add_quad(p0, p1, q1, q0, normal, color)
		# Kanten des vorstehenden Rings (innen zum Gewölbe, außen zur Wand)
		var mid := (inner[i] + inner[i + 1]) / 2.0
		var inward := Vector3(-mid.x, arch_spring - mid.y, 0.0).normalized()
		builder.add_quad(p0, p1, Vector3(p1.x, p1.y, z), Vector3(p0.x, p0.y, z), inward, color)
		builder.add_quad(q0, q1, Vector3(q1.x, q1.y, z), Vector3(q0.x, q0.y, z), -inward, color)
	# Schlussstein (etwas größer) und Kämpfersteine an der Kämpferlinie
	var crown := arch_spring + a
	var key_low := Vector3(-0.24, crown - 0.06, z)
	var key_high := Vector3(0.24, crown + RING + 0.14, z + normal.z * (RING_PROUD + 0.04))
	builder.add_box(Vector3(key_low.x, key_low.y, minf(key_low.z, key_high.z)),
		Vector3(key_high.x, key_high.y, maxf(key_low.z, key_high.z)), STONE, PackedStringArray(["bottom", "back"] if normal.z > 0.0 else ["bottom", "front"]))
	for side in [-1.0, 1.0]:
		var x0: float = side * a
		var x1: float = side * (a + RING + 0.14)
		var z1: float = z + normal.z * (RING_PROUD + 0.03)
		builder.add_box(Vector3(minf(x0, x1), arch_spring - 0.22, minf(z, z1)), Vector3(maxf(x0, x1), arch_spring, maxf(z, z1)),
			STONE_DARK, PackedStringArray(["back"] if normal.z > 0.0 else ["front"]))


## Schild-Band und Fachwerk-Obergeschoss mit zwei Fenstern.
func _build_front(builder: WorldMesh) -> void:
	var w := width / 2.0
	var band_top := masonry_height + sign_band_height
	var skip := PackedStringArray(["bottom", "back"])
	# Schild-Band mit schmalen Leisten darüber und darunter
	builder.add_box(Vector3(-w, masonry_height, 0.0), Vector3(w, band_top, 0.07), ACCENT,
		PackedStringArray(["back", "top", "bottom"]))
	builder.add_box(Vector3(-w, masonry_height - 0.07, 0.0), Vector3(w, masonry_height, 0.11), TRIM,
		PackedStringArray(["back"]))
	# Obergeschoss: Putz zwischen dem Fachwerk, vorn auskragend
	builder.add_box(Vector3(-w, band_top, -depth), Vector3(w, eaves_height, jetty), INFILL, PackedStringArray(["top"]))
	var z := jetty
	var beam_z := jetty + 0.035
	var low := band_top
	var high := eaves_height
	# Schwelle und Rähm (waagerecht unten und oben), Riegel in Brüstungshöhe
	builder.add_box(Vector3(-w, low, z), Vector3(w, low + 0.2, beam_z), BEAM, skip)
	builder.add_box(Vector3(-w, high - 0.2, z), Vector3(w, high, beam_z), BEAM, skip)
	var sill := low + 0.85
	var window_top := sill + 1.15
	# Ständer (senkrecht) und Fenster zwischen den Ständern bei ±(1.9 … 3.3)
	var posts: Array[float] = [-w + 0.1, -3.3, -1.9, -0.6, 0.6, 1.9, 3.3, w - 0.1]
	for x in posts:
		builder.add_box(Vector3(x - 0.09, low + 0.2, z), Vector3(x + 0.09, high - 0.2, beam_z), BEAM, skip)
	for side in [-1.0, 1.0]:
		var x0: float = side * 1.99
		var x1: float = side * 3.21
		var left := minf(x0, x1)
		var right := maxf(x0, x1)
		builder.add_box(Vector3(left, sill - 0.12, z), Vector3(right, sill, beam_z), BEAM, skip)
		builder.add_box(Vector3(left, window_top, z), Vector3(right, window_top + 0.12, beam_z), BEAM, skip)
		_add_sash_window(builder, Vector2((left + right) / 2.0, sill), Vector2(right - left - 0.12, window_top - sill - 0.06), z, 2, 3)
		# Riegel und Streben in den Feldern ohne Fenster
		for panel in [[side * 0.69, side * 1.81], [side * 3.39, side * (w - 0.19)]]:
			var p0 := minf(panel[0], panel[1])
			var p1 := maxf(panel[0], panel[1])
			builder.add_box(Vector3(p0, sill - 0.12, z), Vector3(p1, sill, beam_z), BEAM, skip)
			_add_brace(builder, Vector2(p0, low + 0.2), Vector2(p1, sill - 0.12), z, side < 0.0)
			_add_brace(builder, Vector2(p0, sill), Vector2(p1, high - 0.2), z, side > 0.0)
	# Mittelfeld unter der Gaube: Andreaskreuz
	_add_brace(builder, Vector2(-0.51, low + 0.2), Vector2(0.51, high - 0.2), z, true)
	_add_brace(builder, Vector2(-0.51, low + 0.2), Vector2(0.51, high - 0.2), z, false)
	# Unterseite der Auskragung: Balkenköpfe
	var count := int(width / 0.6)
	for i in count + 1:
		var x := -w + 0.1 + (width - 0.2) * i / count
		builder.add_box(Vector3(x - 0.06, band_top - 0.1, 0.0), Vector3(x + 0.06, band_top, jetty), BEAM_DARK,
			PackedStringArray(["back", "top"]))


## Schräge Strebe in einem Feld (flach aufgesetzt), von unten links nach oben rechts oder
## gespiegelt.
func _add_brace(builder: WorldMesh, low: Vector2, high: Vector2, z: float, rising: bool) -> void:
	var t := 0.08
	var a := Vector2(low.x, low.y) if rising else Vector2(high.x, low.y)
	var b := Vector2(high.x, high.y) if rising else Vector2(low.x, high.y)
	var across := (b - a).orthogonal().normalized() * t
	var bz := z + 0.03
	builder.add_quad(Vector3(a.x - across.x, a.y - across.y, bz), Vector3(b.x - across.x, b.y - across.y, bz),
		Vector3(b.x + across.x, b.y + across.y, bz), Vector3(a.x + across.x, a.y + across.y, bz), Vector3.BACK, BEAM)


## Sprossenfenster (Glas, weißer Rahmen, Sprossen): unten mittig bei bottom, Größe size.
func _add_sash_window(builder: WorldMesh, bottom: Vector2, size: Vector2, z: float, columns: int, rows: int) -> void:
	var x0 := bottom.x - size.x / 2.0
	var x1 := bottom.x + size.x / 2.0
	var y0 := bottom.y
	var y1 := bottom.y + size.y
	var skip := PackedStringArray(["bottom", "back"])
	builder.add_quad(Vector3(x0, y0, z + 0.008), Vector3(x1, y0, z + 0.008), Vector3(x1, y1, z + 0.008),
		Vector3(x0, y1, z + 0.008), Vector3.BACK, GLASS)
	var f := 0.06
	builder.add_box(Vector3(x0, y0, z), Vector3(x0 + f, y1, z + 0.04), TRIM, skip)
	builder.add_box(Vector3(x1 - f, y0, z), Vector3(x1, y1, z + 0.04), TRIM, skip)
	builder.add_box(Vector3(x0 + f, y0, z), Vector3(x1 - f, y0 + f, z + 0.04), TRIM, skip)
	builder.add_box(Vector3(x0 + f, y1 - f, z), Vector3(x1 - f, y1, z + 0.04), TRIM, skip)
	for c in range(1, columns):
		var x := x0 + (x1 - x0) * c / columns
		builder.add_box(Vector3(x - 0.02, y0 + f, z), Vector3(x + 0.02, y1 - f, z + 0.025), TRIM, skip)
	for r in range(1, rows):
		var y := y0 + (y1 - y0) * r / rows
		builder.add_box(Vector3(x0 + f, y - 0.02, z), Vector3(x1 - f, y + 0.02, z + 0.022), TRIM, skip)


## Satteldach (First parallel zur Vorderseite) und mittige Gaube mit Sprossenfenster.
func _build_roof(builder: WorldMesh) -> void:
	var w := width / 2.0
	var base := eaves_height
	var ridge_y := base + roof_rise
	var front := jetty + OVERHANG
	var back := -depth - OVERHANG
	var ridge_z := (jetty - depth) / 2.0
	var front_normal := Vector3(0.0, front - ridge_z, roof_rise).normalized()
	var back_normal := Vector3(0.0, ridge_z - back, -roof_rise).normalized()
	builder.add_quad(Vector3(-w, base, front), Vector3(w, base, front), Vector3(w, ridge_y, ridge_z),
		Vector3(-w, ridge_y, ridge_z), front_normal, ROOF)
	builder.add_quad(Vector3(-w, base, back), Vector3(w, base, back), Vector3(w, ridge_y, ridge_z),
		Vector3(-w, ridge_y, ridge_z), back_normal, ROOF)
	for side in [-1.0, 1.0]:
		var x: float = side * w
		builder.add_triangle(Vector3(x, base, jetty), Vector3(x, base, -depth), Vector3(x, ridge_y, ridge_z),
			Vector3(side, 0.0, 0.0), INFILL)
	builder.add_box(Vector3(-w, base - 0.16, jetty), Vector3(w, base, front), TRIM, PackedStringArray(["top"]))
	builder.add_box(Vector3(-w, base - 0.16, back), Vector3(w, base, -depth), TRIM, PackedStringArray(["top"]))
	_add_dormer(builder, front, ridge_z, ridge_y)


## Gaube: kleine Giebelwand mit Sprossenfenster, Seitenwangen und eigenem Satteldach, das in
## das Hauptdach läuft.
func _add_dormer(builder: WorldMesh, roof_front: float, ridge_z: float, ridge_y: float) -> void:
	var half := 0.85
	var face_z := jetty - 0.3
	var eave := eaves_height + 1.5
	var peak := eave + 0.6
	# Höhe des Hauptdachs an einer Stelle z (vorn an der Traufe bis hinten am First)
	var roof_at := func(z: float) -> float:
		return eaves_height + roof_rise * (roof_front - z) / (roof_front - ridge_z)
	var z_for := func(y: float) -> float:
		return roof_front - (y - eaves_height) / roof_rise * (roof_front - ridge_z)
	var back_z: float = z_for.call(peak) - 0.1
	var low: float = roof_at.call(face_z) - 0.2
	# Giebelwand mit Fenster und Eckständern
	builder.add_quad(Vector3(-half, low, face_z), Vector3(half, low, face_z), Vector3(half, eave, face_z),
		Vector3(-half, eave, face_z), Vector3.BACK, INFILL)
	builder.add_triangle(Vector3(-half, eave, face_z), Vector3(half, eave, face_z), Vector3(0.0, peak, face_z),
		Vector3.BACK, INFILL)
	var skip := PackedStringArray(["bottom", "back"])
	for x in [-half, half - 0.14]:
		builder.add_box(Vector3(x, low, face_z), Vector3(x + 0.14, eave, face_z + 0.035), BEAM, skip)
	builder.add_box(Vector3(-half, eave - 0.14, face_z), Vector3(half, eave, face_z + 0.035), BEAM, skip)
	var sill: float = roof_at.call(face_z) + 0.12
	_add_sash_window(builder, Vector2(0.0, sill), Vector2(0.95, eave - 0.2 - sill), face_z, 2, 3)
	builder.add_box(Vector3(-0.56, sill - 0.06, face_z), Vector3(0.56, sill, face_z + 0.09), TRIM, PackedStringArray(["back"]))
	# Seitenwangen (unter dem Hauptdach verschwinden sie)
	for side in [-1.0, 1.0]:
		var x: float = side * half
		builder.add_quad(Vector3(x, low, face_z), Vector3(x, low, back_z), Vector3(x, eave, back_z),
			Vector3(x, eave, face_z), Vector3(side, 0.0, 0.0), INFILL)
	# Dach der Gaube: zwei Flächen vom First zur Traufe, läuft hinten ins Hauptdach
	var over := 0.14
	var front_z := face_z + 0.18
	for side in [-1.0, 1.0]:
		var x: float = side * (half + over)
		var edge_y := eave - over * (peak - eave) / half
		var normal := Vector3(side * (peak - eave), half, 0.0).normalized()
		builder.add_quad(Vector3(0.0, peak, front_z), Vector3(0.0, peak, back_z), Vector3(x, edge_y, back_z),
			Vector3(x, edge_y, front_z), normal, ROOF)
		builder.add_quad(Vector3(0.0, peak, front_z), Vector3(0.0, peak, back_z), Vector3(x, edge_y, back_z),
			Vector3(x, edge_y, front_z), -normal, ROOF)
		# Stirnbrett vorn
		builder.add_quad(Vector3(0.0, peak + 0.06, front_z + 0.01), Vector3(x, edge_y + 0.06, front_z + 0.01),
			Vector3(x, edge_y - 0.06, front_z + 0.01), Vector3(0.0, peak - 0.06, front_z + 0.01), Vector3.BACK, TRIM)
