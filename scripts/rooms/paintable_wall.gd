class_name PaintableWall
extends Node3D
## Eine Wand, die in senkrechten Abschnitten (vom Boden bis zur Decke) gestrichen wird.
##
## Der Knoten liegt an der unteren Ecke der Wand-Innenseite:
## +X läuft an der Wand entlang, +Y nach oben, +Z zeigt in den Raum.
## Vor die eigentliche Wand legt er dünne Farbflächen – eine Gruppe pro Abschnitt.
## Die Breite der Abschnitte steht in GameConfig.wall_segment_width.

## Länge der Wand in Metern.
@export var length: float = 6.0
## Höhe der Wand (Boden bis Decke) in Metern. 0 = Raumhöhe aus GameConfig.room_height.
@export var height: float = 0.0
## Öffnungen wie Fenster und Tür, gemessen vom Wandanfang (x) und vom Boden (y).
@export var openings: Array[Rect2] = []

## So weit liegen die Farbflächen vor der Wand (verhindert Flackern).
const OFFSET := 0.003

## Oberfläche (id) je Abschnitt.
var segment_ids: Array[String] = []
var _segment_width: float = 1.0
var _segment_parts: Array = []  # je Abschnitt: Array[MeshInstance3D]


func _ready() -> void:
	if height <= 0.0:
		height = GameConfig.room_height
	var count := maxi(1, roundi(length / GameConfig.wall_segment_width))
	_segment_width = length / count
	for i in count:
		segment_ids.append("")
		_segment_parts.append(_build_segment(i))


func get_segment_count() -> int:
	return segment_ids.size()


## Welcher Abschnitt liegt an diesem Punkt? (-1 = der Punkt liegt nicht auf dieser Wand)
func get_segment_at(world_point: Vector3) -> int:
	var local := to_local(world_point)
	if absf(local.z) > 0.03 or local.x < -0.01 or local.x > length + 0.01:
		return -1
	if local.y < -0.01 or local.y > height + 0.01:
		return -1
	return get_segment_index_at_x(local.x)


## Nummer des Abschnitts an dieser Stelle entlang der Wand (in Metern ab Wandanfang).
func get_segment_index_at_x(x: float) -> int:
	return clampi(int(x / _segment_width), 0, segment_ids.size() - 1)


## Streicht einen Abschnitt mit einer Oberfläche.
func paint_segment(index: int, surface: SurfaceData) -> void:
	segment_ids[index] = surface.get_id()
	for part: MeshInstance3D in _segment_parts[index]:
		part.material_override = surface.material


## Mitte eines Abschnitts auf halber Höhe (in Weltkoordinaten).
func get_segment_center(index: int) -> Vector3:
	return to_global(Vector3((index + 0.5) * _segment_width, height / 2.0, 0.0))


## Baut die Farbflächen eines Abschnitts – mit Aussparungen für Fenster und Tür.
func _build_segment(index: int) -> Array[MeshInstance3D]:
	var pieces: Array[Rect2] = [Rect2(index * _segment_width, 0.0, _segment_width, height)]
	for opening in openings:
		var remaining: Array[Rect2] = []
		for piece in pieces:
			remaining.append_array(_subtract(piece, opening))
		pieces = remaining

	var parts: Array[MeshInstance3D] = []
	for piece in pieces:
		var quad := QuadMesh.new()
		quad.size = piece.size
		var part := MeshInstance3D.new()
		part.name = "Segment%dPart%d" % [index + 1, parts.size() + 1]
		part.mesh = quad
		part.position = Vector3(piece.get_center().x, piece.get_center().y, OFFSET)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
		parts.append(part)
	return parts


## Schneidet ein Loch aus einem Rechteck; übrig bleiben bis zu vier Rechtecke.
func _subtract(piece: Rect2, hole: Rect2) -> Array[Rect2]:
	if not piece.intersects(hole):
		return [piece]
	var result: Array[Rect2] = []
	var cut := piece.intersection(hole)
	# links und rechts vom Loch (volle Höhe)
	if cut.position.x > piece.position.x:
		result.append(Rect2(piece.position, Vector2(cut.position.x - piece.position.x, piece.size.y)))
	if cut.end.x < piece.end.x:
		result.append(Rect2(Vector2(cut.end.x, piece.position.y), Vector2(piece.end.x - cut.end.x, piece.size.y)))
	# unter und über dem Loch (nur so breit wie das Loch)
	if cut.position.y > piece.position.y:
		result.append(Rect2(Vector2(cut.position.x, piece.position.y), Vector2(cut.size.x, cut.position.y - piece.position.y)))
	if cut.end.y < piece.end.y:
		result.append(Rect2(Vector2(cut.position.x, cut.end.y), Vector2(cut.size.x, piece.end.y - cut.end.y)))
	return result
