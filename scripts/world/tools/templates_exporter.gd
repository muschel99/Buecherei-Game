extends Node
## Erzeugt die Vorlagen-Modelle zum Modellieren (seit Etappe 4e): je Haustyp und je Möbelstück
## aus dem Katalog eine .glb-Datei in echter Größe (1 Einheit = 1 Meter), genau so gelegen wie
## im Spiel (Ursprung und Vorderseite wie in der jeweiligen Szene).
##   assets/models/templates/houses/<haustyp>.glb
##   assets/models/templates/furniture/<möbel-id>.glb
##   assets/models/templates/world/alley_end.glb, entrance_steps.glb
## Benutzen: scenes/world/tools/export_templates.tscn öffnen und mit F6 starten (schließt sich
## von selbst). Die Vorlagen sind schlichte Grundformen mit wenigen Flächen.
## Der Ordner hat eine Datei ".gdignore": Godot importiert die Vorlagen nicht (sie sind nur
## zum Öffnen in Blender oder Nomad Sculpt da).

const ROOT := "res://assets/models/templates/"
## Rundungen der Vorlagen (wenige Flächen)
const ROUND_SEGMENTS := 12
const ROUND_RINGS := 6

var _count := 0


func _ready() -> void:
	for folder in ["houses", "furniture", "world", "street_life"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + folder))
	_ensure_gdignore()
	# Ohne Bildschirm auch nur ein Teil: -- --only=street_life (bzw. houses, furniture, world)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if only in ["", "houses"]:
		await _export_houses()
	if only in ["", "furniture"]:
		await _export_furniture()
	if only in ["", "world"]:
		await _export_world()
	if only in ["", "street_life"]:
		await _export_street_life()
	print("Vorlagen erzeugt: %d Dateien in %s" % [_count, ROOT])
	get_tree().quit()


func _ensure_gdignore() -> void:
	var path := ROOT + ".gdignore"
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("")
		file.close()


## Haustypen: das Platzhalter-Mesh mit echten Farben (statt der Farb-Kennungen im Mesh).
func _export_houses() -> void:
	var dir := DirAccess.open(HouseTypes.FOLDER)
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var id := file.get_basename()
		var house := HouseTypes.get_scene(id).instantiate() as HouseFacade
		add_child(house)
		await get_tree().process_frame
		var root := Node3D.new()
		root.name = id
		_add_mesh(root, _resolve_house_colors(house.get_placeholder_mesh(), house), Transform3D.IDENTITY, null)
		_save(root, ROOT + "houses/" + id + ".glb")
		house.queue_free()


## Ersetzt im Haus-Mesh die Farb-Kennungen (Alpha) durch die Farben des Haustyps.
func _resolve_house_colors(mesh: Mesh, house: HouseFacade) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in colors.size():
		var c := colors[i]
		var base := Color(c.r, c.g, c.b)
		if c.a > 0.9:
			colors[i] = base
		elif c.a > 0.6:
			colors[i] = house.wall_color * base
		elif c.a > 0.4:
			colors[i] = house.door_color * base
		else:
			colors[i] = house.accent_color * base
		colors[i].a = 1.0
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	result.surface_set_material(0, material)
	return result


## Möbel: alle sichtbaren Teile unter "Model" (oder der ganzen Szene), in Lage zur Wurzel.
func _export_furniture() -> void:
	for data in Catalog.get_all_furniture():
		var scene := load(data.scene_path) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate() as Node3D
		add_child(instance)
		await get_tree().process_frame
		var source: Node = instance.get_node_or_null("Model")
		if source == null:
			source = instance
		var root := Node3D.new()
		root.name = data.get_id()
		for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var local := instance.global_transform.affine_inverse() * mesh.global_transform
			_add_mesh(root, _simplify(mesh.mesh), local, mesh.material_override)
		if root.get_child_count() > 0:
			_save(root, ROOT + "furniture/" + data.get_id() + ".glb")
		else:
			root.free()
		instance.queue_free()


## Gassenende und Eingangstreppe (Lage wie in ihren Szenen).
func _export_world() -> void:
	var end := (load("res://scenes/world/alley_end.tscn") as PackedScene).instantiate() as Node3D
	add_child(end)
	await get_tree().process_frame
	var root := Node3D.new()
	root.name = "alley_end"
	for mesh: MeshInstance3D in end.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent() == end:  # nur die Mauer mit Tor, nicht das Haus dahinter
			_add_mesh(root, mesh.mesh, mesh.transform, null)
	_save(root, ROOT + "world/alley_end.glb")
	end.queue_free()
	var steps := (load("res://scenes/world/entrance_steps.tscn") as PackedScene).instantiate() as Node3D
	add_child(steps)
	await get_tree().process_frame
	root = Node3D.new()
	root.name = "entrance_steps"
	for mesh: MeshInstance3D in steps.find_children("*", "MeshInstance3D", true, false):
		_add_mesh(root, mesh.mesh, mesh.transform, preload("res://assets/materials/curb_stone.tres"))
	_save(root, ROOT + "world/entrance_steps.glb")
	steps.queue_free()


## Straßenleben (seit Etappe 5a): Lieferwagen, Auto, Fahrrad und Passant – der Platzhalter in
## echter Größe, Vorderseite nach +Z, Räder bzw. Füße auf y = 0. Beim Lieferwagen ist die Tür
## dabei (geschlossen); die Farben stehen in den Vertex-Farben.
func _export_street_life() -> void:
	for item in [["delivery_van", GameConfig.delivery_van_scene, GameConfig.delivery_van_color],
			["car", GameConfig.car_scene, Color(0.55, 0.68, 0.62)], ["cyclist", GameConfig.bike_scene, Color(0.3, 0.45, 0.55)],
			["passerby", "res://scenes/street_life/passerby.tscn", Color.WHITE]]:
		var instance := (load(item[1]) as PackedScene).instantiate() as Node3D
		add_child(instance)
		await get_tree().process_frame
		var model := instance.get_node_or_null("Model")
		if model and model.has_method("build"):
			model.call("build", RandomNumberGenerator.new(), item[2])
		await get_tree().process_frame
		var root := Node3D.new()
		root.name = item[0]
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null or mesh.name == "Far":
				continue
			var local := instance.global_transform.affine_inverse() * mesh.global_transform
			_add_mesh(root, _resolve_tint(mesh.mesh, item[2]), local, null)
		_save(root, ROOT + "street_life/" + item[0] + ".glb")
		instance.queue_free()


## Ersetzt im Mesh die Farb-Kennungen (Alpha, siehe street_figure.gdshader) durch echte Farben.
func _resolve_tint(mesh: Mesh, tint: Color) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in colors.size():
		var c := colors[i]
		var base := Color(c.r, c.g, c.b)
		colors[i] = tint * base if c.a > 0.6 and c.a < 0.9 else base
		colors[i].a = 1.0
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	result.surface_set_material(0, material)
	return result


## Runde Grundformen mit weniger Flächen (Vorlagen sollen schlicht sein).
func _simplify(mesh: Mesh) -> Mesh:
	if mesh is SphereMesh or mesh is CylinderMesh or mesh is CapsuleMesh or mesh is TorusMesh:
		var copy: Mesh = mesh.duplicate()
		if copy is SphereMesh:
			copy.radial_segments = ROUND_SEGMENTS
			copy.rings = ROUND_RINGS
		elif copy is CylinderMesh:
			copy.radial_segments = ROUND_SEGMENTS
			copy.rings = 0
		elif copy is CapsuleMesh:
			copy.radial_segments = ROUND_SEGMENTS
			copy.rings = 2
		elif copy is TorusMesh:
			copy.rings = ROUND_SEGMENTS
			copy.ring_segments = 8
		return copy
	return mesh


func _add_mesh(root: Node3D, mesh: Mesh, local: Transform3D, override: Material) -> void:
	# Als einfaches ArrayMesh mit einem schlichten Material (das versteht jedes Programm)
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
		var source: Material = override if override else mesh.surface_get_material(surface)
		result.surface_set_material(surface, _plain_material(source))
	var node := MeshInstance3D.new()
	node.name = "Part%d" % root.get_child_count()
	node.mesh = result
	node.transform = local
	root.add_child(node)
	node.owner = root


func _plain_material(source: Material) -> Material:
	if source is StandardMaterial3D:
		var copy := StandardMaterial3D.new()
		copy.albedo_color = (source as StandardMaterial3D).albedo_color
		copy.vertex_color_use_as_albedo = (source as StandardMaterial3D).vertex_color_use_as_albedo
		copy.vertex_color_is_srgb = (source as StandardMaterial3D).vertex_color_is_srgb
		copy.roughness = 0.9
		return copy
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.75, 0.73, 0.7)
	if source is ShaderMaterial:
		for parameter in ["base_color", "albedo", "albedo_color", "color"]:
			var value: Variant = (source as ShaderMaterial).get_shader_parameter(parameter)
			if value is Color:
				plain.albedo_color = value
				break
	plain.roughness = 0.9
	return plain


func _save(root: Node3D, path: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Vorlage %s konnte nicht gespeichert werden (Fehler %d)" % [path, error])
	else:
		_count += 1
	root.free()
