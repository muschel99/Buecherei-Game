@tool
class_name CornerHouseFacade
extends HouseFacade
## Eckhaus mit abgeschrägter Ecke (seit Etappe 4f), wie die Bücherei: steht innen in einer
## Straßenkurve. Zwei Straßenfassaden treffen sich an der Ecke, die Ecke selbst ist schräg
## abgeschnitten – dort sitzt eine kleine Ladentür mit Schild darüber (gut für kleine Läden).
## Eigene Haustypen: scenes/world/houses/corner_90.tscn (90°-Kurve) und corner_30.tscn
## (sanfte 30°-Kurve). Wie bei allen Häusern: Liegt ein Knoten "Model" in der Szene,
## verschwindet der Platzhalter; die Kollision (Grundriss als Prisma) bleibt.
##
## Grundriss (von oben, Ursprung unten in der Mitte der Vorderseite, Vorderseite nach +Z):
## - Vorderseite: von x = -width/2 bis zur (gedachten) Ecke bei x = +width/2,
## - die Ecke ist um chamfer_width schräg abgeschnitten,
## - die Seitenfassade läuft ab der Ecke um corner_angle nach hinten gedreht weiter
##   (90° = rechtwinklig wie ein normales Eckhaus, 30° = sanfter Knick), side_length lang,
## - hinten schließt das Haus bei z = -depth gerade ab.
## Bei 90° ist die Seitenfassade genau depth lang.

@export_group("Ecke")
## Um so viel Grad knickt die Hausfront an der Ecke ab (90 = rechter Winkel).
@export_range(10.0, 90.0) var corner_angle: float = 90.0:
	set(value):
		corner_angle = value
		_queue_rebuild()
## Breite der abgeschrägten Wand an der Ecke (Bücherei: etwa 3 m).
@export var chamfer_width: float = 2.2:
	set(value):
		chamfer_width = value
		_queue_rebuild()
## Länge der Seitenfassade ab der gedachten Ecke (bei 90° ohne Wirkung: dann = depth).
@export var side_length: float = 5.0:
	set(value):
		side_length = value
		_queue_rebuild()

## So weit läuft das Walmdach waagerecht nach innen (oben ist es flach wie bei der Bücherei).
const ROOF_RUN := 2.0
const SIGN_COLOR := Color(1.0, 1.0, 1.0, 0.25)


func _mesh_key() -> String:
	return super._mesh_key() + str([corner_angle, chamfer_width, side_length])


## Ecken des Grundrisses (x, z), der Reihe nach rundherum.
func footprint() -> PackedVector2Array:
	var w := width / 2.0
	var corner := Vector2(w, 0.0)
	var angle := deg_to_rad(corner_angle)
	var along := Vector2(cos(angle), -sin(angle))  # Richtung der Seitenfassade
	var cut := _chamfer_cut()
	var side := depth if corner_angle >= 89.9 else side_length
	var side_end := corner + along * side
	var points := PackedVector2Array([Vector2(-w, 0.0), corner - Vector2(cut, 0.0), corner + along * cut, side_end])
	if corner_angle < 89.9:
		# Vom Ende der Seitenfassade senkrecht nach hinten bis zur Rückwand
		var back := Vector2(-sin(angle), -cos(angle))
		var t := (depth + side_end.y) / cos(angle)
		points.append(side_end + back * maxf(0.0, t))
	points.append(Vector2(-w, -depth))
	return points


## Abstand von der gedachten Ecke bis zum Beginn der Abschrägung (auf beiden Fassaden gleich).
func _chamfer_cut() -> float:
	return chamfer_width / (2.0 * cos(deg_to_rad(corner_angle) / 2.0))


## Länge der Seitenfassade (für die Aufstellung in der Straße).
func get_side_length() -> float:
	return depth if corner_angle >= 89.9 else side_length


## Kollision: der Grundriss, so hoch wie die Traufe.
func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = _collision_layer()
	_body.collision_mask = 0
	var points := PackedVector3Array()
	for p in footprint():
		points.append(Vector3(p.x, 0.0, p.y))
		points.append(Vector3(p.x, eaves_height, p.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body.add_child(collision)
	add_child(_body)


## Wände rundherum.
func _build_body(builder: WorldMesh) -> void:
	var points := footprint()
	var clockwise := _is_clockwise(points)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var outward := _outward(a, b, clockwise)
		builder.add_wall(a, b, 0.0, eaves_height, Vector3(outward.x, 0.0, outward.y), WALL)


## Die drei Straßenfassaden: Vorderseite, Abschrägung (Ladentür), Seitenfassade – je mit
## Fenstern, Sockel und Gesims. Teile werden in Fassaden-Koordinaten gebaut (x entlang der
## Wand, +z nach draußen) und von WorldMesh.xform an ihren Platz gedreht.
func _build_front(builder: WorldMesh) -> void:
	var points := footprint()
	var storey_height := eaves_height / maxf(1.0, storeys)
	var facades := [[points[0], points[1], false], [points[1], points[2], true], [points[2], points[3], false]]
	for facade in facades:
		var a: Vector2 = facade[0]
		var b: Vector2 = facade[1]
		var length := a.distance_to(b)
		var along := (b - a).normalized()
		var out := Vector2(-along.y, along.x)  # nach draußen (vom Haus weg)
		var middle := (a + b) / 2.0
		builder.xform = Transform3D(Basis(Vector3(along.x, 0.0, along.y), Vector3.UP, Vector3(out.x, 0.0, out.y)),
			Vector3(middle.x, 0.0, middle.y))
		var skip := PackedStringArray(["bottom", "back"])
		var half := length / 2.0
		if facade[2]:
			# Abschrägung: Ladentür mit Schild darüber, darüber je Geschoss ein Fenster
			_add_door(builder, 0.0)
			builder.add_box(Vector3(-minf(half - 0.08, 0.9), DOOR_HEIGHT + 0.6, 0.0),
				Vector3(minf(half - 0.08, 0.9), DOOR_HEIGHT + 0.95, 0.08), SIGN_COLOR, skip)
			for side in [-1.0, 1.0]:
				var x0: float = side * (DOOR_WIDTH / 2.0 + FRAME)
				var x1: float = side * (half - 0.01)
				if absf(x1) > absf(x0) + 0.05:
					builder.add_box(Vector3(minf(x0, x1), 0.0, 0.0), Vector3(maxf(x0, x1), plinth_height, plinth_proud), PLINTH, skip)
			for storey in range(1, storeys):
				_add_window(builder, 0.0, storey * storey_height + storey_height * 0.5)
		else:
			builder.add_box(Vector3(-half + 0.01, 0.0, 0.0), Vector3(half - 0.01, plinth_height, plinth_proud), PLINTH, skip)
			var columns := maxi(1, floori((length - 0.4) / 1.7))
			for storey in storeys:
				var center_y := storey * storey_height + storey_height * 0.5 + (0.1 if storey == 0 else 0.0)
				for column in columns:
					var x := -half + length * (column + 0.5) / columns
					_add_window(builder, x, center_y)
		# Gesims unter der Traufe
		builder.add_box(Vector3(-half, eaves_height - 0.35, 0.0), Vector3(half, eaves_height - 0.25, 0.06), TRIM,
			PackedStringArray(["back"]))
	builder.xform = Transform3D.IDENTITY


## Walmdach, rundherum gleich geneigt und oben flach (wie bei der Bücherei), mit Traufkante.
func _build_roof(builder: WorldMesh) -> void:
	var points := footprint()
	var outer := _offset_polygon(points, OVERHANG)
	var inner := _offset_polygon(points, -ROOF_RUN)
	var base := eaves_height
	var top := base + roof_rise
	var clockwise := _is_clockwise(points)
	for i in points.size():
		var j := (i + 1) % points.size()
		var a := outer[i]
		var b := outer[j]
		var out := _outward(points[i], points[j], clockwise)
		var normal := Vector3(out.x * roof_rise, ROOF_RUN + OVERHANG, out.y * roof_rise).normalized()
		builder.add_quad(Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(inner[j].x, top, inner[j].y),
			Vector3(inner[i].x, top, inner[i].y), normal, ROOF)
		# Traufkante (außen senkrecht, unten waagerecht bis zur Wand)
		builder.add_wall(a, b, base - 0.16, base, Vector3(out.x, 0.0, out.y), TRIM)
		builder.add_quad(Vector3(a.x, base - 0.16, a.y), Vector3(b.x, base - 0.16, b.y),
			Vector3(points[j].x, base - 0.16, points[j].y), Vector3(points[i].x, base - 0.16, points[i].y), Vector3.DOWN, TRIM)
	builder.add_floor(inner, top, ROOF)


## Grundriss nach außen (positiv) oder innen (negativ) versetzt – jede Kante parallel
## verschoben, Ecken neu geschnitten (der Grundriss ist konvex, die Ecken bleiben dieselben).
func _offset_polygon(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var clockwise := _is_clockwise(points)
	var count := points.size()
	var result := PackedVector2Array()
	for i in count:
		var prev := points[(i - 1 + count) % count]
		var here := points[i]
		var next := points[(i + 1) % count]
		var n0 := _outward(prev, here, clockwise) * distance
		var n1 := _outward(here, next, clockwise) * distance
		result.append(StreetLayout.line_intersection(prev + n0, here - prev, here + n1, next - here))
	return result


func _is_clockwise(points: PackedVector2Array) -> bool:
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	return area < 0.0


## Nach außen zeigende Senkrechte der Kante a–b.
func _outward(a: Vector2, b: Vector2, clockwise: bool) -> Vector2:
	var along := (b - a).normalized()
	var right := Vector2(along.y, -along.x)  # rechts der Kante = außen bei Umlauf gegen den Uhrzeigersinn
	return -right if clockwise else right
