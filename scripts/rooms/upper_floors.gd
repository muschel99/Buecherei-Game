class_name UpperFloors
extends Node3D
## Die Obergeschosse und das Dach über dem Laden (seit Etappe 4c) – und unten der Sockel
## des Hauses (seit Etappe 4d: der Ladenboden liegt höher als der Gehweg, dazwischen sieht man
## den Sockel; Höhe GameConfig.shop_floor_rise, Überstand GameConfig.plinth_proud).
##
## Vorerst ist jedes Obergeschoss nur eine geschlossene Außenhülle mit Fenster-Platzhaltern –
## man kann es nicht betreten. Anzahl und Höhe stehen in GameConfig (upper_floor_count,
## upper_floor_height). Jedes Geschoss ist ein eigener Knoten ("Floor1", "Floor2" …), damit es
## sich später als Etage freischalten lässt: Dann tritt ein echter Raum an die Stelle der Hülle.
##
## Der Grundriss ist derselbe wie beim Laden (inklusive der abgeschrägten Ecke): die
## Außenkante der Hauswand. Die Wände der Obergeschosse liegen genau in derselben Ebene wie die
## Außenwände des Ladens, die Ecken sind wie dort auf Gehrung – von außen ist das Haus eine
## durchgehende, glatte Fläche. Der Knoten selbst liegt im Ursprung der Hauptszene.

## Innenfläche des Ladens (x und z in Metern), wie Room.build_area.
@export var inner_area: Rect2 = Rect2(-3.0, -4.0, 6.0, 8.0)
## Wanddicke des Hauses in Metern.
@export var wall_thickness: float = 0.2
## Dicke der Deckenplatte über dem Laden: Das erste Obergeschoss beginnt auf Raumhöhe plus
## dieser Dicke (dort enden die Außenwände des Ladens).
@export var ceiling_thickness: float = 0.2

@export_group("Fenster")
## Fenster-Platzhalter (Szene); Ursprung außen auf der Wand in der Fenstermitte, +Z ins Haus.
@export var window_scene: PackedScene = preload("res://scenes/objects/upper_window.tscn")
## An diesen Seiten sitzen Fenster (die übrigen Seiten grenzen an Nachbarn bzw. den Hof):
## "diagonal" (schräge Eingangswand), "front", "left", "right", "back".
@export var window_sides := PackedStringArray(["diagonal", "front", "left"])
## Etwa so viel Platz (in Metern) braucht ein Fenster an der Wand: Eine Seite bekommt
## so viele Fenster, wie hineinpassen (mindestens eins), gleichmäßig verteilt.
@export var window_spacing: float = 2.0
## Höhe der Fenstermitte über dem Fußboden des Geschosses.
@export var window_center_height: float = 1.55

@export_group("Dach")
## So weit steht das Dach über die Hauswand hinaus.
@export var roof_overhang: float = 0.25
## Höhe der weißen Dachkante (Traufbrett).
@export var fascia_height: float = 0.15
## So weit (waagerecht) laufen die Dachflächen von der Traufe nach innen bis zur flachen Oberseite.
@export var roof_inset: float = 2.2
## So hoch steigt das Dach von der Traufe bis zur flachen Oberseite.
@export var roof_rise: float = 1.4
## Seit Etappe 4g Backstein (Stil-Textur, nach der Lage in der Welt aufgetragen).
@export var wall_material: Material = preload("res://assets/materials/library_brick.tres")
@export var trim_material: Material = preload("res://assets/materials/paint_white.tres")
@export var roof_material: Material = preload("res://assets/materials/roof_slate.tres")

@export_group("Sockel")
## An diesen Seiten läuft unten der Sockel (rechts schließt das Nachbarhaus an, dort nicht).
@export var plinth_sides := PackedStringArray(["diagonal", "front", "left", "back"])
@export var plinth_material: Material = preload("res://assets/materials/plinth_stone.tres")

## Namen der Seiten des Grundrisses in der Reihenfolge der Ecken (siehe _outline).
const SIDE_NAMES := ["diagonal", "front", "right", "back", "left"]


func _ready() -> void:
	var outline := _outline()
	for index in GameConfig.upper_floor_count:
		add_child(_build_floor(index, outline))
	add_child(_build_roof(outline))
	var plinth := _build_plinth(outline)
	if plinth:
		add_child(plinth)


## Höhe des Fußbodens eines Obergeschosses (0 = erstes Obergeschoss).
func get_floor_base(index: int) -> float:
	return GameConfig.room_height + ceiling_thickness + index * GameConfig.upper_floor_height


## Das Obergeschoss mit dieser Nummer (0 = erstes), oder null.
func get_floor(index: int) -> Node3D:
	return get_node_or_null("Floor%d" % (index + 1)) as Node3D


## Außenkante der Hauswand von oben gesehen (x, z) – ein Fünfeck mit der abgeschrägten Ecke.
## Reihenfolge der Ecken: Anfang der Schräge links, Ende der Schräge vorn, vorn rechts,
## hinten rechts, hinten links. Die Seite von Ecke i zu Ecke i + 1 heißt SIDE_NAMES[i].
func _outline() -> PackedVector2Array:
	var left := inner_area.position.x - wall_thickness
	var right := inner_area.end.x + wall_thickness
	var front := inner_area.position.y - wall_thickness
	var back := inner_area.end.y + wall_thickness
	# Die Schräge außen ist um die Wanddicke nach außen verschoben (Linie x + z = Wert).
	var cut_line := inner_area.position.x + inner_area.position.y + GameConfig.corner_cut \
		- wall_thickness * sqrt(2.0)
	return PackedVector2Array([
		Vector2(left, cut_line - left),
		Vector2(cut_line - front, front),
		Vector2(right, front),
		Vector2(right, back),
		Vector2(left, back),
	])


## Ein Obergeschoss: Außenwände als geschlossene Hülle und Fenster-Platzhalter.
func _build_floor(index: int, outline: PackedVector2Array) -> Node3D:
	var storey := Node3D.new()
	storey.name = "Floor%d" % (index + 1)
	storey.position.y = get_floor_base(index)
	var height := GameConfig.upper_floor_height
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		_add_quad(tool, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y),
			Vector3(b.x, height, b.y), Vector3(a.x, height, a.y), _outward(a, b))
	storey.add_child(_make_mesh("Shell", tool, wall_material))
	for i in outline.size():
		if SIDE_NAMES[i] in window_sides:
			_add_windows(storey, outline[i], outline[(i + 1) % outline.size()])
	return storey


## Verteilt Fenster-Platzhalter gleichmäßig auf einer Seite (von Ecke a nach Ecke b).
func _add_windows(storey: Node3D, a: Vector2, b: Vector2) -> void:
	if window_scene == null:
		return
	var count := maxi(1, floori(a.distance_to(b) / window_spacing))
	var outward := _outward(a, b)
	var inward := -outward
	var basis := Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	for k in count:
		var spot := a.lerp(b, (k + 0.5) / count)
		var window := window_scene.instantiate() as Node3D
		window.name = "Window%d" % (storey.get_child_count())
		window.transform = Transform3D(basis, Vector3(spot.x, window_center_height, spot.y))
		storey.add_child(window)


## Schlichtes Dach: kleiner Überstand mit weißer Traufkante, rundherum gleich geneigte
## Dachflächen (auch über der Schräge) und eine flache Oberseite.
func _build_roof(outline: PackedVector2Array) -> Node3D:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.position.y = get_floor_base(GameConfig.upper_floor_count)
	var eave := _offset(outline, roof_overhang)
	var top := _offset(eave, -roof_inset)
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slopes := SurfaceTool.new()
	slopes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y := fascia_height + roof_rise
	for i in outline.size():
		var j := (i + 1) % outline.size()
		# Unterseite des Überstands (zeigt nach unten)
		_add_quad(trim, _at(outline[i], 0.0), _at(outline[j], 0.0), _at(eave[j], 0.0),
			_at(eave[i], 0.0), Vector3.DOWN)
		# Traufkante (senkrecht, zeigt nach außen)
		_add_quad(trim, _at(eave[i], 0.0), _at(eave[j], 0.0), _at(eave[j], fascia_height),
			_at(eave[i], fascia_height), _outward(eave[i], eave[j]))
		# Dachfläche von der Traufkante schräg nach innen oben
		var low_a := _at(eave[i], fascia_height)
		var low_b := _at(eave[j], fascia_height)
		var high_b := _at(top[j], top_y)
		var normal := (low_b - low_a).cross(high_b - low_a).normalized()
		if normal.y < 0.0:
			normal = -normal
		_add_quad(slopes, low_a, low_b, high_b, _at(top[i], top_y), normal)
	# Flache Oberseite (ein Fächer aus Dreiecken, der Grundriss ist überall nach außen gewölbt)
	for i in range(1, top.size() - 1):
		_add_triangle(slopes, _at(top[0], top_y), _at(top[i], top_y), _at(top[i + 1], top_y), Vector3.UP)
	roof.add_child(_make_mesh("Trim", trim, trim_material))
	roof.add_child(_make_mesh("Slopes", slopes, roof_material))
	return roof


## Sockel: ein schmaler Streifen, der unten etwas vor der Hauswand steht – vom Gehweg bis zur
## Höhe des Ladenbodens. An der schrägen Wand liegt seine Oberkante 2 mm tiefer, denn dort
## liegt das Podest der Treppe genau auf Höhe des Ladenbodens darüber (sonst flimmert es).
func _build_plinth(outline: PackedVector2Array) -> MeshInstance3D:
	var rise := GameConfig.shop_floor_rise
	var proud := GameConfig.plinth_proud
	if rise <= 0.0 or proud <= 0.0:
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	for i in count:
		if not SIDE_NAMES[i] in plinth_sides:
			continue
		var a := outline[i]
		var b := outline[(i + 1) % count]
		var start := _plinth_corner(outline, i, SIDE_NAMES[(i - 1 + count) % count] in plinth_sides, true)
		var finish := _plinth_corner(outline, i, SIDE_NAMES[(i + 1) % count] in plinth_sides, false)
		var top := -0.002 if SIDE_NAMES[i] == "diagonal" else 0.0
		var outward := _outward(a, b)
		_add_quad(tool, _at(start, -rise), _at(finish, -rise), _at(finish, top), _at(start, top), outward)
		_add_quad(tool, _at(a, top), _at(b, top), _at(finish, top), _at(start, top), Vector3.UP)
	var mesh := _make_mesh("Plinth", tool, plinth_material)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # nur ein schmaler Streifen
	return mesh


## Ecke des Sockels an Seite i (Anfang oder Ende): auf Gehrung, wenn die Nachbarseite auch
## einen Sockel hat, sonst gerade abgeschnitten (dort schließt ein Nachbarhaus an).
func _plinth_corner(outline: PackedVector2Array, i: int, neighbor_has_plinth: bool, at_start: bool) -> Vector2:
	var count := outline.size()
	var a := outline[i]
	var b := outline[(i + 1) % count]
	var corner := a if at_start else b
	var n := _outward(a, b)
	var normal := Vector2(n.x, n.z)
	var proud := GameConfig.plinth_proud
	if not neighbor_has_plinth:
		return corner + normal * proud
	var other: Vector3
	if at_start:
		other = _outward(outline[(i - 1 + count) % count], a)
	else:
		other = _outward(b, outline[(i + 2) % count])
	var other_normal := Vector2(other.x, other.z)
	return corner + (normal + other_normal) * proud / (1.0 + normal.dot(other_normal))


## Punkt des Grundrisses in einer bestimmten Höhe.
func _at(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)


## Richtung nach außen (waagerecht) für die Seite von Ecke a nach Ecke b.
func _outward(a: Vector2, b: Vector2) -> Vector3:
	var along := (b - a).normalized()
	var normal := Vector2(along.y, -along.x)
	# Nach außen = weg von der Mitte des Hauses
	if normal.dot((a + b) / 2.0 - inner_area.get_center()) < 0.0:
		normal = -normal
	return Vector3(normal.x, 0.0, normal.y)


## Verschiebt den Grundriss um eine Strecke nach außen (negativ = nach innen). Die Ecken
## bleiben auf Gehrung: Jede Ecke wandert auf der Winkelhalbierenden.
func _offset(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		var previous := points[(i - 1 + points.size()) % points.size()]
		var point := points[i]
		var next := points[(i + 1) % points.size()]
		var n1 := _outward(previous, point)
		var n2 := _outward(point, next)
		var normal_1 := Vector2(n1.x, n1.z)
		var normal_2 := Vector2(n2.x, n2.z)
		result.append(point + (normal_1 + normal_2) * distance / (1.0 + normal_1.dot(normal_2)))
	return result


## Viereck aus zwei Dreiecken (Ecken der Reihe nach rundherum).
func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_add_triangle(tool, a, b, c, normal)
	_add_triangle(tool, a, c, d, normal)


## Dreieck, das in Richtung der Normale sichtbar ist (die Reihenfolge der Ecken wird passend
## gedreht: Godot zeigt Dreiecke von der Seite, von der aus die Ecken im Uhrzeigersinn liegen).
func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var corners := [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for corner: Vector3 in corners:
		tool.set_normal(normal)
		tool.set_uv(Vector2(corner.x + corner.z, corner.y))
		tool.add_vertex(corner)


func _make_mesh(node_name: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	tool.set_material(material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	# Beidseitig Schatten werfen: Die Hülle ist unten offen (dort liegt der Laden).
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	return instance
