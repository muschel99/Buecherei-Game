class_name BackRoom
extends Node3D
## Hinterzimmer der Bücherei (seit Etappe 7). Seit dem Nachtest von Etappe 8 (Wunsch der Entwicklerin) liegt es rechts NEBEN
## dem Laden, im hinteren Teil des Modegeschäfts: dessen Laden bleibt gleich groß, das Haus ist hinten unten ausgeschnitten
## (build_storybook_shop.py NOTCH, Kollision HouseFacade.collision_notch), das Zimmer reicht noch ein Stück hinter das Haus
## hinaus (dort Zinkdach mit Dachfenster). Hinter dem Laden bleibt so Platz für spätere Erweiterungen, und das Zimmer ist nicht
## im Weg. Erreichbar durch eine Holztür in der rechten Ladenwand hinter der Theke (BackRoomDoor).
## Gebaut beim Start (Kind des Raums): Boden, Wände und Decke mit Kollision (Möbel stellen und Deko aufhängen wie im Laden –
## Room.extra_build_areas, Room.add_hang_walls), Leisten, Holzbalken unter der Rückwand des Modegeschäfts, Dachfenster mit
## Tageslicht, Außenhaut des Teils hinter dem Modegeschäft. Besucher kommen nie hinein (sie planen nur Wege im Laden).
## Ältere Spielstände: Was im alten Hinterzimmer hinter dem Laden stand, zieht um (migrate_old_area).

const FLOOR_MAT := preload("res://assets/materials/floor_wood.tres")
const WALL_MAT := preload("res://assets/materials/wall_plaster.tres")
const CEILING_MAT := preload("res://assets/materials/ceiling_plaster.tres")
const TRIM_MAT := preload("res://assets/materials/wood_dark.tres")
const BRICK_MAT := preload("res://assets/materials/storybook/backstein_ziegelrot.tres")
const PLINTH_MAT := preload("res://assets/materials/storybook/sandstein.tres")
const ZINC_MAT := preload("res://assets/materials/storybook/zink.tres")
const WALL := 0.2
## Mitte der rechten Ladenwand (innen 3,0, außen 3,2) – dort sitzt die Tür
const SHOP_WALL_X := 3.1
## Rückseite des Modegeschäfts (bis hierher steht sein Haus über dem Zimmer) und Außenseite der Ladenrückwand
const FASHION_BACK_Z := 3.8
const LIBRARY_BACK_Z := 4.2
## Dachfenster-Aufsatz über dem Zinkdach (m)
const SKYLIGHT_CURB := 0.14
## Lage des Hinterzimmers bis zum Nachtest von Etappe 8 (hinter dem Laden) – nur noch für alte Spielstände
const OLD_AREA := Rect2(0.0, 4.2, 3.0, 4.0)
## Futter und Zierleisten der Türöffnung (m)
const LINING := 0.025
const ARCHITRAVE := 0.08

var room: Room


## Innenfläche (x/z im Raum des Ladens): rechts neben dem Laden, ab der Außenseite der rechten Ladenwand.
static func back_area() -> Rect2:
	var size: Vector2 = GameConfig.back_room_size
	return Rect2(SHOP_WALL_X + WALL / 2.0, GameConfig.back_room_front_z, size.x, size.y)


## Lage der Tür: Ursprung in der Mitte der Öffnung auf dem Boden, in der Mitte der Wand; +X entlang der Wand, +Z ins
## Hinterzimmer (Raumkoordinaten des Ladens).
static func door_frame() -> Transform3D:
	var into := Vector3.RIGHT
	var along := Vector3.UP.cross(into)
	return Transform3D(Basis(along, Vector3.UP, into), Vector3(SHOP_WALL_X, 0.0, GameConfig.back_room_door_z))


func build(owner_room: Room) -> void:
	room = owner_room
	var area := back_area()
	var height := GameConfig.room_height
	var door_w := GameConfig.back_room_door_width
	var door_h := GameConfig.back_room_door_height
	var door_z := GameConfig.back_room_door_z
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var z1 := area.end.y
	# 1. Durchgang in der rechten Ladenwand (CSG-Loch, Aussparung in den Farbflächen, Sockelleiste unterbrochen)
	var shop_wall := room.get_node("Structure/WallRight") as CSGBox3D
	var hole := CSGBox3D.new()
	hole.name = "BackDoorHole"
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(WALL * 3.0, door_h, door_w)
	hole.position = Vector3(0.0, door_h / 2.0 - shop_wall.position.y, door_z - shop_wall.position.z)
	shop_wall.add_child(hole)
	var paint := room.get_node_or_null("Walls/Right") as PaintableWall
	if paint:
		# Wand-Koordinaten: x läuft ab z = -4 die Wand entlang, y nach oben
		var u0 := paint.to_local(room.to_global(Vector3(3.0, 0.0, door_z - door_w / 2.0))).x
		var u1 := paint.to_local(room.to_global(Vector3(3.0, 0.0, door_z + door_w / 2.0))).x
		var a := minf(u0, u1)
		var b := maxf(u0, u1)
		var shapes: Array[PackedVector2Array] = [PackedVector2Array([Vector2(a, 0.0), Vector2(b, 0.0), Vector2(b, door_h), Vector2(a, door_h)])]
		paint.set_opening_shapes(shapes)
	var old_skirting := room.get_node_or_null("Structure/SkirtingRight") as Node3D
	if old_skirting:
		old_skirting.visible = false
	var shop_inner := SHOP_WALL_X - WALL / 2.0
	_skirting(Vector3(shop_inner - 0.01, 0, -4.0), Vector3(shop_inner - 0.01, 0, door_z - door_w / 2.0 - ARCHITRAVE))
	_skirting(Vector3(shop_inner - 0.01, 0, door_z + door_w / 2.0 + ARCHITRAVE), Vector3(shop_inner - 0.01, 0, 4.0))
	# 2. Boden, Wände, Decke (mit Kollision). Links ist die Ladenwand die Wand des Zimmers; sie endet an der Ladenrückwand,
	# dahinter (Teil hinter dem Laden) baut das Zimmer seine eigene linke Wand.
	_box("Floor", Vector3((x0 + x1 + WALL) / 2.0, -0.1, (z0 + z1) / 2.0), Vector3(x1 - x0 + WALL, 0.2, z1 - z0 + WALL * 2.0), FLOOR_MAT)
	var walls: Array[Node] = []
	walls.append(_box("WallFront", Vector3((x0 + x1 + WALL) / 2.0, height / 2.0 + 0.1, z0 - WALL / 2.0),
		Vector3(x1 - x0 + WALL, height + 0.2, WALL), WALL_MAT))
	walls.append(_box("WallRight", Vector3(x1 + WALL / 2.0, height / 2.0 + 0.1, (z0 + z1) / 2.0),
		Vector3(WALL, height + 0.2, z1 - z0 + WALL * 2.0), WALL_MAT))
	walls.append(_box("WallBack", Vector3((x0 - WALL + x1) / 2.0, height / 2.0 + 0.1, z1 + WALL / 2.0),
		Vector3(x1 - x0 + WALL, height + 0.2, WALL), WALL_MAT))
	if z1 > LIBRARY_BACK_Z:
		walls.append(_box("WallLeft", Vector3(x0 - WALL / 2.0, height / 2.0 + 0.1, (LIBRARY_BACK_Z + z1) / 2.0),
			Vector3(WALL, height + 0.2, z1 - LIBRARY_BACK_Z), WALL_MAT))
	# Decke mit Dachfenster (das Dachfenster liegt im Teil hinter dem Modegeschäft – darüber ist nur noch das Zinkdach)
	var ceiling := CSGCombiner3D.new()
	ceiling.name = "Ceiling"
	ceiling.use_collision = true
	add_child(ceiling)
	var slab := CSGBox3D.new()
	slab.size = Vector3(x1 - x0 + WALL, 0.2, z1 - z0 + WALL * 2.0)
	slab.position = Vector3((x0 + x1 + WALL) / 2.0, height + 0.1, (z0 + z1) / 2.0)
	slab.material = CEILING_MAT
	ceiling.add_child(slab)
	var sky := GameConfig.back_room_skylight
	var sky_center := Vector3((x0 + x1) / 2.0, height, (FASHION_BACK_Z + z1) / 2.0 + 0.03)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(sky.x, 0.6, sky.y)
	cut.position = sky_center + Vector3.UP * 0.1
	cut.material = WALL_MAT
	ceiling.add_child(cut)
	_skylight(sky_center, sky)
	_beam(x0, x1, height)
	_exterior(x0, x1, z0, z1, height, sky_center, sky)
	# 3. Tür mit Futter und Zierleisten; die linke Wand (Außenseite der Ladenwände) bekommt eine durchgehende Putzschicht –
	# dort stoßen rechte Wand und Rückwand des Ladens aneinander, sonst sähe man die Fuge als Linie
	_doorway(door_w, door_h)
	_left_lining(x0, z0, z1, height, door_z, door_w, door_h)
	# 4. Leisten
	_skirting(Vector3(x0, 0, z0), Vector3(x1, 0, z0), true)
	_skirting(Vector3(x1, 0, z0), Vector3(x1, 0, z1), true)
	_skirting(Vector3(x1, 0, z1), Vector3(x0, 0, z1), true)
	_skirting(Vector3(x0, 0, z1), Vector3(x0, 0, door_z + door_w / 2.0 + ARCHITRAVE), true)
	_skirting(Vector3(x0, 0, door_z - door_w / 2.0 - ARCHITRAVE), Vector3(x0, 0, z0), true)
	add_child(RoomTrim.build_cornice(PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]), height))
	# 5. Bauen und Aufhängen wie im Laden; vor der Tür bleibt es auf beiden Seiten frei
	room.add_hang_walls(walls)
	_keep_clear(-0.45, "BackDoorKeepClear")
	_keep_clear(0.45, "BackDoorKeepClearInside")
	# Fassaden-Haut (gemeinsames Material storybook.gdshaderinc) im Durchgang nicht zeichnen – auch nicht das Modegeschäft
	var frame := door_frame()
	var cut_a := room.to_global(frame * Vector3(-door_w / 2.0, 0.0, -WALL))
	var cut_b := room.to_global(frame * Vector3(door_w / 2.0, door_h, WALL * 2.5))
	RenderingServer.global_shader_parameter_set(&"library_cut_min", cut_a.min(cut_b))
	RenderingServer.global_shader_parameter_set(&"library_cut_max", cut_a.max(cut_b))


## Sperrzone vor der Tür (Ebene build_blocker), damit dort nichts hingestellt wird; offset = Abstand der Mitte von der Wand
## (negativ = im Laden, positiv = im Hinterzimmer).
func _keep_clear(offset: float, area_name: String) -> void:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("keep_clear_text", "Vor der Tür zum Hinterzimmer bitte frei lassen.")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GameConfig.back_room_door_width + 0.4, 2.0, 0.9)
	shape.shape = box
	area.add_child(shape)
	area.transform = door_frame() * Transform3D(Basis(), Vector3(0.0, 1.0, offset + signf(offset) * WALL / 2.0))
	add_child(area)


## Nach dem Laden: Was vor der Tür steht, kommt ins Lager – mit einem Hinweis.
func clear_doorway() -> void:
	var frame := room.global_transform * door_frame()
	var half := GameConfig.back_room_door_width / 2.0 + 0.1
	var moved := 0
	for item in room.get_placed_furniture():
		if item.data == null or item.data.is_fixed or item.data.is_essential or item.support_uid > 0:
			continue
		var box := _visual_bounds(item)
		if box.size == Vector3.ZERO:
			continue
		var blocked := false
		for side: float in [-1.0, 1.0]:
			var a := frame * Vector3(-half, 0.05, side * WALL / 2.0)
			var b := frame * Vector3(half, 2.0, side * (WALL / 2.0 + 0.6))
			if box.intersects(AABB(a.min(b), (a.max(b) - a.min(b)))):
				blocked = true
		if blocked:
			_to_storage(item)
			moved += 1
	if moved > 0:
		Notice.post(self, "Für die Tür zum Hinterzimmer ins Lager gelegt: %d" % moved)


## Ältere Spielstände (bis zum Nachtest von Etappe 8 lag das Hinterzimmer hinter dem Laden): Das Bett zieht an seinen neuen
## Platz, alles andere von dort kommt ins Lager (ausgelegte Bücher in den Bestand) – mit einem Hinweis.
func migrate_old_area() -> void:
	var moved := 0
	for item in room.get_placed_furniture():
		if item.data == null or not is_instance_valid(item):
			continue
		var local := room.to_local(item.global_position)
		if not OLD_AREA.grow(0.05).has_point(Vector2(local.x, local.z)):
			continue
		if item.data.is_essential or item.data.is_fixed:
			# fest dazugehörig (Bett): an den Platz aus der Szene (liegt jetzt im neuen Zimmer)
			var spot := room.essential_spot(item.data.get_id())
			if not spot.is_empty() and str(spot.support_id).is_empty():
				room.move_furniture(item, spot.transform, null)
			continue
		if item.support_uid > 0:
			continue  # zieht mit seinem Träger ins Lager
		_to_storage(item)
		moved += 1
	var books := room.loose_books.release_in_area(OLD_AREA)
	if moved + books > 0:
		Notice.post(self, "Das Hinterzimmer ist umgezogen (Tür rechts hinter der Theke) – Möbel von dort liegen im Lager: %d"
			% (moved + books))


func _to_storage(item: PlacedFurniture) -> void:
	Inventory.add_furniture(item.data.get_id(), 1, item.variant)
	for dependent in room.get_dependents(item):
		if dependent.data:
			Inventory.add_furniture(dependent.data.get_id(), 1, dependent.variant)
	room.remove_furniture(item)


func _visual_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		var box := visual.global_transform * visual.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _box(box_name: String, center: Vector3, size: Vector3, material: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.position = center
	box.material = material
	box.use_collision = true
	add_child(box)
	return box


## Sockelleiste von a nach b (Höhe 10 cm, 2 cm dick, zur Raumseite hin versetzt, wenn inward).
func _skirting(a: Vector3, b: Vector3, inward: bool = false) -> void:
	var dir := (b - a)
	var length := dir.length()
	if length < 0.05:
		return
	dir /= length
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.1, 0.02)
	mesh.mesh = box
	mesh.material_override = TRIM_MAT
	var center := (a + b) / 2.0 + Vector3.UP * 0.05
	if inward:
		# zur Mitte des Hinterzimmers hin, die Leiste liegt vor der Wand (nie halb darin – sonst flimmert es)
		var area := back_area()
		var middle := Vector3(area.get_center().x, 0.05, area.get_center().y)
		var side := Vector3(-dir.z, 0, dir.x)
		if side.dot(middle - center) < 0.0:
			side = -side
		center += side * 0.011
	mesh.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), center)
	add_child(mesh)


## Türöffnung: Futter (kleidet die Laibung aus, liegt 2,5 cm in der Öffnung – nie Fläche auf Fläche mit dem CSG-Loch, sonst
## flimmert es), Zierleisten auf beiden Wandseiten (1,5 cm vor der Wand), Schwelle, und die Holztür.
func _doorway(width: float, height: float) -> void:
	var casing := MeshInstance3D.new()
	casing.name = "DoorCasing"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width / 2.0
	var depth := WALL / 2.0
	var a := ARCHITRAVE
	var pieces: Array[AABB] = [
		# Futter links, rechts, oben (über die ganze Wandstärke)
		AABB(Vector3(-half - 0.004, 0.0, -depth - 0.004), Vector3(LINING + 0.004, height, WALL + 0.008)),
		AABB(Vector3(half - LINING, 0.0, -depth - 0.004), Vector3(LINING + 0.004, height, WALL + 0.008)),
		AABB(Vector3(-half - 0.004, height - LINING, -depth - 0.004), Vector3(width + 0.008, LINING + 0.004, WALL + 0.008)),
		# Schwelle
		AABB(Vector3(-half - 0.004, 0.0, -depth - 0.02), Vector3(width + 0.008, 0.012, WALL + 0.04)),
	]
	for side: float in [-1.0, 1.0]:
		var z := side * depth
		var z_from := z - (0.006 if side > 0.0 else 0.015)
		pieces.append(AABB(Vector3(-half - a + 0.005, 0.0, z_from), Vector3(a, height + 0.005, 0.021)))
		pieces.append(AABB(Vector3(half - 0.005, 0.0, z_from), Vector3(a, height + 0.005, 0.021)))
		pieces.append(AABB(Vector3(-half - a + 0.005, height - 0.005, z_from), Vector3(width + a * 2.0 - 0.01, a, 0.021)))
	for piece in pieces:
		_add_box(tool, piece)
	tool.generate_normals()
	casing.mesh = tool.commit()
	casing.material_override = TRIM_MAT
	casing.transform = door_frame()
	add_child(casing)
	# Holztür: geht mit E auf und schwingt ins Hinterzimmer
	var leaf := BackRoomDoor.new()
	leaf.name = "BackDoor"
	add_child(leaf)
	leaf.transform = door_frame() * Transform3D(Basis(), Vector3(0.0, 0.0, depth - BackRoomDoor.LEAF_THICKNESS / 2.0 - 0.012))
	leaf.setup(width - LINING * 2.0, height - LINING)


## Dünne Putzschicht 3 mm vor der linken Wand (nie Fläche auf Fläche), ausgespart um die Tür samt Zierleisten.
func _left_lining(x0: float, z0: float, z1: float, height: float, door_z: float, door_w: float, door_h: float) -> void:
	var gap_a := door_z - door_w / 2.0 - ARCHITRAVE + 0.01
	var gap_b := door_z + door_w / 2.0 + ARCHITRAVE - 0.01
	var top := door_h + ARCHITRAVE - 0.01
	var x := x0 + 0.003 + 0.002
	for piece: Array in [[z0, gap_a, 0.0, height], [gap_b, z1, 0.0, height], [gap_a, gap_b, top, height]]:
		var length: float = piece[1] - piece[0]
		var h: float = piece[3] - piece[2]
		if length <= 0.01 or h <= 0.01:
			continue
		_mesh_box("LeftLining", Vector3(x, (piece[2] + piece[3]) / 2.0, (piece[0] + piece[1]) / 2.0), Vector3(0.004, h, length), WALL_MAT)


func _add_box(tool: SurfaceTool, box: AABB) -> void:
	var p := box.position
	var s := box.size
	var c := [p, p + Vector3(s.x, 0, 0), p + Vector3(s.x, 0, s.z), p + Vector3(0, 0, s.z),
		p + Vector3(0, s.y, 0), p + Vector3(s.x, s.y, 0), p + s, p + Vector3(0, s.y, s.z)]
	for f: Array in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		tool.add_vertex(c[f[0]]); tool.add_vertex(c[f[2]]); tool.add_vertex(c[f[1]])
		tool.add_vertex(c[f[0]]); tool.add_vertex(c[f[3]]); tool.add_vertex(c[f[2]])


## Holzbalken unter der Rückwand des Modegeschäfts: Er trägt die Wand darüber (das Haus ist dort unten ausgeschnitten).
func _beam(x0: float, x1: float, height: float) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var box := BoxMesh.new()
	box.size = Vector3(x1 - x0 - 0.004, 0.2, 0.3)
	beam.mesh = box
	beam.material_override = TRIM_MAT
	beam.position = Vector3((x0 + x1) / 2.0, height - 0.1, FASHION_BACK_Z - 0.15)
	add_child(beam)


## Außenhaut des Teils hinter dem Modegeschäft (von außen sieht man ihn kaum, aber er soll wie gebaut sein): Backstein bis
## unter den Boden draußen, Sandsteinsockel, Flachdach aus Zink mit Tropfkante, Aufsatz um das Dachfenster. Vorn stößt das
## Dach an die Rückwand des Modegeschäfts.
func _exterior(x0: float, x1: float, _z0: float, z1: float, height: float, sky_center: Vector3, sky: Vector2) -> void:
	var ground := -GameConfig.shop_floor_rise - 0.12
	var top := height + 0.2
	var skin := 0.03
	var outer_x0 := x0 - WALL
	var outer_x1 := x1 + WALL
	var outer_z1 := z1 + WALL
	var front := FASHION_BACK_Z
	var wall_h := top - ground
	# Backstein: hinten, rechts (ab der Rückseite des Modegeschäfts), links (ab der Rückseite des Ladens)
	_mesh_box("BrickBack", Vector3((outer_x0 + outer_x1) / 2.0, ground + wall_h / 2.0, outer_z1 + skin / 2.0),
		Vector3(outer_x1 - outer_x0 + skin * 2.0, wall_h, skin), BRICK_MAT)
	_mesh_box("BrickRight", Vector3(outer_x1 + skin / 2.0, ground + wall_h / 2.0, (front + outer_z1) / 2.0),
		Vector3(skin, wall_h, outer_z1 - front), BRICK_MAT)
	_mesh_box("BrickLeft", Vector3(outer_x0 - skin / 2.0, ground + wall_h / 2.0, (LIBRARY_BACK_Z + outer_z1) / 2.0),
		Vector3(skin, wall_h, outer_z1 - LIBRARY_BACK_Z), BRICK_MAT)
	var plinth_h := GameConfig.shop_floor_rise + 0.12 + 0.35
	var p := 0.06
	_mesh_box("PlinthBack", Vector3((outer_x0 + outer_x1) / 2.0, ground + plinth_h / 2.0, outer_z1 + p / 2.0),
		Vector3(outer_x1 - outer_x0 + p * 2.0, plinth_h, p), PLINTH_MAT)
	_mesh_box("PlinthRight", Vector3(outer_x1 + p / 2.0, ground + plinth_h / 2.0, (front + outer_z1 + p) / 2.0),
		Vector3(p, plinth_h, outer_z1 + p - front), PLINTH_MAT)
	_mesh_box("PlinthLeft", Vector3(outer_x0 - p / 2.0, ground + plinth_h / 2.0, (LIBRARY_BACK_Z + outer_z1 + p) / 2.0),
		Vector3(p, plinth_h, outer_z1 + p - LIBRARY_BACK_Z), PLINTH_MAT)
	# Zinkdach mit Überstand (vorn stößt es an die Rückwand des Modegeschäfts), Loch fürs Dachfenster
	var over := 0.14
	var roof := CSGCombiner3D.new()
	roof.name = "Roof"
	add_child(roof)
	var cover := CSGBox3D.new()
	cover.size = Vector3(outer_x1 - outer_x0 + over * 2.0, 0.05, outer_z1 + over - front)
	cover.position = Vector3((outer_x0 + outer_x1) / 2.0, top + 0.025, (front + outer_z1 + over) / 2.0)
	cover.material = ZINC_MAT
	roof.add_child(cover)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(sky.x, 0.3, sky.y)
	hole.position = Vector3(sky_center.x, top, sky_center.z)
	hole.material = ZINC_MAT
	roof.add_child(hole)
	for edge: Array in [[Vector3(outer_x0 - over + 0.01, top - 0.02, (front + outer_z1 + over) / 2.0), Vector3(0.02, 0.09, outer_z1 + over - front)],
			[Vector3(outer_x1 + over - 0.01, top - 0.02, (front + outer_z1 + over) / 2.0), Vector3(0.02, 0.09, outer_z1 + over - front)],
			[Vector3((outer_x0 + outer_x1) / 2.0, top - 0.02, outer_z1 + over - 0.01), Vector3(outer_x1 - outer_x0 + over * 2.0, 0.09, 0.02)]]:
		_mesh_box("Drip", edge[0], edge[1], ZINC_MAT)
	var t := 0.06
	var cy := top + 0.05 + SKYLIGHT_CURB / 2.0
	for curb: Array in [[Vector3(sky_center.x, cy, sky_center.z - sky.y / 2.0 - t / 2.0), Vector3(sky.x + t * 2.0, SKYLIGHT_CURB, t)],
			[Vector3(sky_center.x, cy, sky_center.z + sky.y / 2.0 + t / 2.0), Vector3(sky.x + t * 2.0, SKYLIGHT_CURB, t)],
			[Vector3(sky_center.x - sky.x / 2.0 - t / 2.0, cy, sky_center.z), Vector3(t, SKYLIGHT_CURB, sky.y)],
			[Vector3(sky_center.x + sky.x / 2.0 + t / 2.0, cy, sky_center.z), Vector3(t, SKYLIGHT_CURB, sky.y)]]:
		_mesh_box("SkylightCurb", curb[0], curb[1], ZINC_MAT)


func _mesh_box(box_name: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = center
	mesh.material_override = material
	add_child(mesh)
	return mesh


## Dachfenster: Holzrahmen in der Deckenöffnung, Glas obendrauf, ein weiches Tageslicht darunter (folgt dem Tag, DayCycle).
func _skylight(center: Vector3, size: Vector2) -> void:
	var frame := MeshInstance3D.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t := 0.06
	var y0 := center.y - 0.01
	for piece: AABB in [
		AABB(Vector3(center.x - size.x / 2.0, y0, center.z - size.y / 2.0), Vector3(size.x, 0.22, t)),
		AABB(Vector3(center.x - size.x / 2.0, y0, center.z + size.y / 2.0 - t), Vector3(size.x, 0.22, t)),
		AABB(Vector3(center.x - size.x / 2.0, y0, center.z - size.y / 2.0), Vector3(t, 0.22, size.y)),
		AABB(Vector3(center.x + size.x / 2.0 - t, y0, center.z - size.y / 2.0), Vector3(t, 0.22, size.y)),
		AABB(Vector3(center.x - 0.02, y0 + 0.17, center.z - size.y / 2.0), Vector3(0.04, 0.04, size.y)),
	]:
		_add_box(tool, piece)
	tool.generate_normals()
	frame.mesh = tool.commit()
	frame.material_override = TRIM_MAT
	add_child(frame)
	var glass := MeshInstance3D.new()
	var pane := BoxMesh.new()
	glass.mesh = pane
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.85, 0.92, 0.95, 0.18)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = center + Vector3.UP * (0.25 + SKYLIGHT_CURB)
	pane.size = Vector3(size.x + 0.08, 0.012, size.y + 0.08)  # liegt auf dem Aufsatz
	add_child(glass)
	var light := OmniLight3D.new()
	light.name = "SkylightDaylight"
	light.shadow_enabled = false
	light.light_color = GameConfig.window_daylight_color
	light.light_energy = GameConfig.window_daylight_energy * 1.2
	light.light_specular = 0.0
	light.omni_range = 4.5
	light.omni_attenuation = 1.3
	light.light_cull_mask = 1 << (GameConfig.INDOOR_RENDER_LAYER - 1)
	light.position = center - Vector3.UP * 0.6
	light.light_volumetric_fog_energy = 0.0
	light.add_to_group(RoomOpenings.DAYLIGHT_GROUP)
	add_child(light)
