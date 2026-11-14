class_name BackRoom
extends Node3D
## Hinterzimmer der Bücherei (seit Etappe 7): ein kleiner Raum hinter dem Laden (GameConfig.back_room_*), durch eine Holztür
## in der Rückwand erreichbar (BackRoomDoor, seit Testrunde 7b; vorher ein Vorhang). Seit Testrunde 7b ein richtiger Anbau:
## außen Backstein mit Sandsteinsockel bis unter den Boden draußen, Flachdach aus Zink mit Dachfenster-Aufsatz. Gebaut beim Start (Kind des Raums): Boden, Wände und
## Decke mit Kollision (Möbel stellen und Deko aufhängen geht wie im Laden – Room.extra_build_areas, Room.add_hang_walls),
## Sockelleiste, Stuckleiste, Dachfenster mit Tageslicht. Besucher kommen nie hinein (sie planen nur Wege im Laden).
## Umstreichen und andere Böden kommen mit den späteren Raum-Erweiterungen.

const FLOOR_MAT := preload("res://assets/materials/floor_wood.tres")
const WALL_MAT := preload("res://assets/materials/wall_plaster.tres")
const CEILING_MAT := preload("res://assets/materials/ceiling_plaster.tres")
const TRIM_MAT := preload("res://assets/materials/wood_dark.tres")
const WALL := 0.2

var room: Room


func build(owner_room: Room) -> void:
	room = owner_room
	var area := back_area()
	var height := GameConfig.room_height
	var door_x := GameConfig.back_room_door_x
	var door_w := GameConfig.back_room_door_width
	var door_h := GameConfig.back_room_door_height
	var z0 := area.position.y          # Außenseite der Ladenrückwand = Anfang des Hinterzimmers
	var z1 := area.end.y
	var x0 := area.position.x
	var x1 := area.end.x
	# 1. Durchgang in der Rückwand des Ladens
	var back_wall := room.get_node("Structure/WallBack") as CSGBox3D
	var hole := CSGBox3D.new()
	hole.name = "BackDoorHole"
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(door_w, door_h, WALL * 3.0)
	hole.position = Vector3(door_x - back_wall.position.x, door_h / 2.0 - back_wall.position.y, 0.0)
	back_wall.add_child(hole)
	# Sockelleiste des Ladens hinten: am Durchgang unterbrochen
	var old_skirting := room.get_node_or_null("Structure/SkirtingBack") as Node3D
	if old_skirting:
		old_skirting.visible = false
	var shop_back := back_wall.position.z - WALL / 2.0  # Innenseite der Ladenrückwand
	_skirting(Vector3(-3.0, 0, shop_back - 0.01), Vector3(door_x - door_w / 2.0, 0, shop_back - 0.01))
	_skirting(Vector3(door_x + door_w / 2.0, 0, shop_back - 0.01), Vector3(3.0, 0, shop_back - 0.01))
	# 2. Boden, Wände, Decke (mit Kollision)
	_box("Floor", Vector3((x0 + x1) / 2.0, -0.1, (z0 + z1) / 2.0), Vector3(x1 - x0 + WALL * 2.0, 0.2, z1 - z0 + WALL), FLOOR_MAT)
	var walls: Array[Node] = []
	walls.append(_box("WallLeft", Vector3(x0 - WALL / 2.0, height / 2.0, (z0 + z1) / 2.0), Vector3(WALL, height + 0.2, z1 - z0), WALL_MAT))
	walls.append(_box("WallRight", Vector3(x1 + WALL / 2.0, height / 2.0, (z0 + z1) / 2.0), Vector3(WALL, height + 0.2, z1 - z0), WALL_MAT))
	walls.append(_box("WallBack", Vector3((x0 + x1) / 2.0, height / 2.0, z1 + WALL / 2.0), Vector3(x1 - x0 + WALL * 2.0, height + 0.2, WALL), WALL_MAT))
	# Laibung des Durchgangs (in der Dicke der Rückwand)
	_doorway(door_x, door_w, door_h, back_wall.position.z)
	# Decke mit Dachfenster
	var ceiling := CSGCombiner3D.new()
	ceiling.name = "Ceiling"
	ceiling.use_collision = true
	add_child(ceiling)
	var slab := CSGBox3D.new()
	slab.size = Vector3(x1 - x0 + WALL * 2.0, 0.2, z1 - z0 + WALL)
	slab.position = Vector3((x0 + x1) / 2.0, height + 0.1, (z0 + z1) / 2.0)
	slab.material = CEILING_MAT
	ceiling.add_child(slab)
	var sky := GameConfig.back_room_skylight
	var sky_center := Vector3((x0 + x1) / 2.0, height, (z0 + z1) / 2.0 + 0.3)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(sky.x, 0.6, sky.y)
	cut.position = sky_center + Vector3.UP * 0.1
	cut.material = WALL_MAT
	ceiling.add_child(cut)
	_skylight(sky_center, sky)
	_exterior(x0, x1, z0, z1, height, sky_center, sky)
	# 3. Leisten
	_skirting(Vector3(x0, 0, z0), Vector3(x0, 0, z1), true)
	_skirting(Vector3(x1, 0, z1), Vector3(x1, 0, z0), true)
	_skirting(Vector3(x0, 0, z1), Vector3(x1, 0, z1), true)
	add_child(RoomTrim.build_cornice(PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]), height))
	# 4. Bauen und Aufhängen wie im Laden; vor dem Durchgang bleibt es frei
	room.add_hang_walls(walls)
	_keep_clear(door_x, door_w, shop_back - 0.45, "BackDoorKeepClear")
	_keep_clear(door_x, door_w, back_wall.position.z + WALL / 2.0 + 0.45, "BackDoorKeepClearInside")
	# Die Rückwand der Fassade (Blender-Modell, ein Stück mit dem ganzen Haus) im Durchgang nicht zeichnen
	var wall_out := back_wall.position.z + WALL / 2.0
	var cut_min := room.to_global(Vector3(door_x - door_w / 2.0, 0.0, wall_out - 0.05))
	var cut_max := room.to_global(Vector3(door_x + door_w / 2.0, door_h, wall_out + 0.3))
	RenderingServer.global_shader_parameter_set(&"library_cut_min", cut_min.min(cut_max))
	RenderingServer.global_shader_parameter_set(&"library_cut_max", cut_max.max(cut_min))


## Sperrzone vor dem Durchgang (Ebene build_blocker), damit dort nichts hingestellt wird (center_z = Mitte der Zone).
func _keep_clear(x: float, width: float, center_z: float, area_name: String) -> void:
	var area := Area3D.new()
	area.name = area_name
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("keep_clear_text", "Vor dem Durchgang zum Hinterzimmer bitte frei lassen.")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 0.4, 2.0, 0.9)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(x, 1.0, center_z)
	add_child(area)


## Nach dem Laden (alte Spielstände): Was vor dem Durchgang steht, kommt ins Lager – mit einem Hinweis.
func clear_doorway() -> void:
	var x := GameConfig.back_room_door_x
	var half := GameConfig.back_room_door_width / 2.0 + 0.1
	var wall_z := (room.get_node("Structure/WallBack") as Node3D).position.z - WALL / 2.0
	var zone := AABB(room.to_global(Vector3(x - half, 0.05, wall_z - 0.6)), Vector3(half * 2.0, 2.0, 0.6))
	var moved := 0
	for item in room.get_placed_furniture():
		if item.data == null or item.data.is_fixed or item.data.is_essential or item.support_uid > 0:
			continue
		var box := _visual_bounds(item)
		if box.size != Vector3.ZERO and box.intersects(zone):
			Inventory.add_furniture(item.data.get_id(), 1, item.variant)
			for dependent in room.get_dependents(item):
				if dependent.data:
					Inventory.add_furniture(dependent.data.get_id(), 1, dependent.variant)
			room.remove_furniture(item)
			moved += 1
	if moved > 0:
		Notice.post(self, "Für den neuen Durchgang zum Hinterzimmer ins Lager gelegt: %d" % moved)


func _visual_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual is Light3D or not visual.is_visible_in_tree():
			continue
		var box := visual.global_transform * visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Grundfläche (x/z im Raum des Ladens): von der Außenseite der Rückwand nach hinten.
static func back_area() -> Rect2:
	var size: Vector2 = GameConfig.back_room_size
	var left := 3.0 - size.x  # an der rechten Seite (hinter der Theke; links verläuft die Gasse)
	return Rect2(left, 4.2, size.x, size.y)


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


## Holzrahmen um den Durchgang (beidseitig) und ein geteilter Vorhang, durch den man hindurchgeht.
func _doorway(x: float, width: float, height: float, wall_z: float) -> void:
	var frame := MeshInstance3D.new()
	frame.name = "DoorCasing"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := WALL + 0.04
	var t := 0.08  # Breite des Rahmens
	for piece: AABB in [
		AABB(Vector3(x - width / 2.0 - t, 0, wall_z - depth / 2.0), Vector3(t, height + t, depth)),
		AABB(Vector3(x + width / 2.0, 0, wall_z - depth / 2.0), Vector3(t, height + t, depth)),
		AABB(Vector3(x - width / 2.0 - t, height, wall_z - depth / 2.0), Vector3(width + t * 2.0, t, depth)),
	]:
		_add_box(tool, piece)
	tool.generate_normals()
	frame.mesh = tool.commit()
	frame.material_override = TRIM_MAT
	add_child(frame)
	# Holztür (seit Testrunde 7b statt des Vorhangs): geht mit E auf und schwingt ins Hinterzimmer
	var leaf := BackRoomDoor.new()
	leaf.name = "BackDoor"
	add_child(leaf)
	leaf.position = Vector3(x, 0.0, wall_z + WALL / 2.0 - BackRoomDoor.LEAF_THICKNESS / 2.0 - 0.005)
	leaf.setup(width, height)


func _add_box(tool: SurfaceTool, box: AABB) -> void:
	var p := box.position
	var s := box.size
	var c := [p, p + Vector3(s.x, 0, 0), p + Vector3(s.x, 0, s.z), p + Vector3(0, 0, s.z),
		p + Vector3(0, s.y, 0), p + Vector3(s.x, s.y, 0), p + s, p + Vector3(0, s.y, s.z)]
	for f: Array in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		tool.add_vertex(c[f[0]]); tool.add_vertex(c[f[2]]); tool.add_vertex(c[f[1]])
		tool.add_vertex(c[f[0]]); tool.add_vertex(c[f[3]]); tool.add_vertex(c[f[2]])


const BRICK_MAT := preload("res://assets/materials/storybook/backstein_ziegelrot.tres")
const PLINTH_MAT := preload("res://assets/materials/storybook/sandstein.tres")
const ZINC_MAT := preload("res://assets/materials/storybook/zink.tres")
const YARD_MAT := preload("res://assets/materials/storybook/kopfsteinpflaster.tres")
## Dachfenster-Aufsatz über dem Zinkdach (m)
const SKYLIGHT_CURB := 0.14


## Außenhaut des Anbaus (seit Testrunde 7b – vorher hing ein heller Kasten ohne Dach hinten an der Bücherei): Backstein auf den
## drei Außenwänden bis unter den Boden draußen, Sandsteinsockel, Flachdach aus Zink mit Überstand und Tropfkante, Aufsatz
## um das Dachfenster.
func _exterior(x0: float, x1: float, z0: float, z1: float, height: float, sky_center: Vector3, sky: Vector2) -> void:
	var ground := -GameConfig.shop_floor_rise - 0.12
	var top := height + 0.2
	var skin := 0.03
	var outer_x0 := x0 - WALL
	var outer_x1 := x1 + WALL
	var outer_z1 := z1 + WALL
	var wall_h := top - ground
	# Backstein: links, rechts, hinten
	_mesh_box("BrickLeft", Vector3(outer_x0 - skin / 2.0, ground + wall_h / 2.0, (z0 + outer_z1) / 2.0),
		Vector3(skin, wall_h, outer_z1 - z0), BRICK_MAT)
	_mesh_box("BrickRight", Vector3(outer_x1 + skin / 2.0, ground + wall_h / 2.0, (z0 + outer_z1) / 2.0),
		Vector3(skin, wall_h, outer_z1 - z0), BRICK_MAT)
	_mesh_box("BrickBack", Vector3((outer_x0 + outer_x1) / 2.0, ground + wall_h / 2.0, outer_z1 + skin / 2.0),
		Vector3(outer_x1 - outer_x0 + skin * 2.0, wall_h, skin), BRICK_MAT)
	# Sockel (etwas dicker, bis knapp über den Boden draußen)
	var plinth_h := GameConfig.shop_floor_rise + 0.12 + 0.35
	var p := 0.06
	_mesh_box("PlinthLeft", Vector3(outer_x0 - p / 2.0, ground + plinth_h / 2.0, (z0 + outer_z1 + p) / 2.0),
		Vector3(p, plinth_h, outer_z1 + p - z0), PLINTH_MAT)
	_mesh_box("PlinthRight", Vector3(outer_x1 + p / 2.0, ground + plinth_h / 2.0, (z0 + outer_z1 + p) / 2.0),
		Vector3(p, plinth_h, outer_z1 + p - z0), PLINTH_MAT)
	_mesh_box("PlinthBack", Vector3((outer_x0 + outer_x1) / 2.0, ground + plinth_h / 2.0, outer_z1 + p / 2.0),
		Vector3(outer_x1 - outer_x0 + p * 2.0, plinth_h, p), PLINTH_MAT)
	# kleiner gepflasterter Hof unter und um den Anbau (dahinter war vorher nichts – nur von weit oben zu sehen)
	_mesh_box("Yard", Vector3(0.0, -GameConfig.shop_floor_rise - 0.06, (z0 + outer_z1) / 2.0 + 0.8),
		Vector3(6.6, 0.1, outer_z1 - z0 + 1.6), YARD_MAT)
	# Zinkdach mit Überstand (vorn stößt es an die Rückwand des Ladens), Loch fürs Dachfenster
	var over := 0.14
	var roof := CSGCombiner3D.new()
	roof.name = "Roof"
	add_child(roof)
	var cover := CSGBox3D.new()
	cover.size = Vector3(outer_x1 - outer_x0 + over * 2.0, 0.05, outer_z1 + over - z0)
	cover.position = Vector3((outer_x0 + outer_x1) / 2.0, top + 0.025, (z0 + outer_z1 + over) / 2.0)
	cover.material = ZINC_MAT
	roof.add_child(cover)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(sky.x, 0.3, sky.y)
	hole.position = Vector3(sky_center.x, top, sky_center.z)
	hole.material = ZINC_MAT
	roof.add_child(hole)
	# Tropfkante rundherum (außer vorn)
	for edge: Array in [[Vector3(outer_x0 - over + 0.01, top - 0.02, (z0 + outer_z1 + over) / 2.0), Vector3(0.02, 0.09, outer_z1 + over - z0)],
			[Vector3(outer_x1 + over - 0.01, top - 0.02, (z0 + outer_z1 + over) / 2.0), Vector3(0.02, 0.09, outer_z1 + over - z0)],
			[Vector3((outer_x0 + outer_x1) / 2.0, top - 0.02, outer_z1 + over - 0.01), Vector3(outer_x1 - outer_x0 + over * 2.0, 0.09, 0.02)]]:
		_mesh_box("Drip", edge[0], edge[1], ZINC_MAT)
	# Aufsatz ums Dachfenster
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
	pane.size = Vector3(size.x - t * 2.0, 0.01, size.y - t * 2.0)
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
	light.add_to_group(RoomOpenings.DAYLIGHT_GROUP)
	add_child(light)
