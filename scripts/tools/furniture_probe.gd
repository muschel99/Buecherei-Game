extends Node3D
## Prüfbilder von Möbeln in Godot ohne die ganze Welt (seit Testrunde 7b): Möbel-Szenen in einem Raster, Licht, Kamera.
## Start: xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --resolution 1600x1000 --audio-driver Dummy
##   res://scenes/tools/furniture_probe.tscn -- [seite=0] [je=12] | ids=sofa_min,pouf | theke
## theke = jede Theke mit ihrem Würfelregal und den Bücherkisten von der Seite der Spielfigur (theke_<id>.png).
## Bilder: screenshots/furniture_probe/seite_<n>.png bzw. mit ids= je Möbel <id>.png (nah, vier Blickwinkel
## nebeneinander: schräg vorn links, von der Seite, schräg von hinten, von unten vorn in Bodenhöhe – so sieht man
## schwebende Teile und Lücken).

const OUT := "res://screenshots/furniture_probe/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.78, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.5, 0.45)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var per := 12
	var pages: Array[int] = []
	for arg in args:
		if arg == "buch":
			await _books()
			get_tree().quit()
			return
		if arg == "theke":
			await _counters()
			get_tree().quit()
			return
		if arg.begins_with("ids="):
			await _close_ups(arg.trim_prefix("ids=").split(","))
			get_tree().quit()
			return
		if arg.begins_with("je="):
			per = int(arg.trim_prefix("je="))
		elif arg.begins_with("seite="):
			pages.append(int(arg.trim_prefix("seite=")))
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://data/furniture"):
		if f.ends_with(".tres"):
			files.append("res://data/furniture/" + f)
	files.sort()
	if pages.is_empty():
		for p in ceili(files.size() / float(per)):
			pages.append(p)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.make_current()
	for page in pages:
		var holder := Node3D.new()
		add_child(holder)
		var names: Array[String] = []
		for i in range(page * per, mini(files.size(), (page + 1) * per)):
			var data := load(files[i]) as FurnitureData
			if data == null:
				continue
			var model := FurnitureUtils.instantiate_model(data, "") if data else null
			if model == null:
				continue
			var k := i - page * per
			var cols := 3 if per <= 6 else 4
			model.position = Vector3((k % cols) * 1.8, 0.0, (k / cols) * 2.0)
			holder.add_child(model)
			var label := Label3D.new()
			label.text = data.get_id()
			label.font_size = 48
			label.pixel_size = 0.004
			label.position = model.position + Vector3(0, 0.02, 0.9)
			label.rotation_degrees = Vector3(-60, 0, 0)
			label.modulate = Color(0.1, 0.05, 0.02)
			holder.add_child(label)
			names.append(data.get_id())
		if per <= 6:
			cam.look_at_from_position(Vector3(1.8, 2.4, 4.6), Vector3(1.8, 0.45, 1.0))
		else:
			cam.look_at_from_position(Vector3(3.3, 5.5, 8.6), Vector3(3.3, 0.5, 2.0))
		for f in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "seite_%02d.png" % page))
		print("Bild: seite_%02d %s" % [page, names])
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## Nahaufnahmen einzelner Möbel aus vier Blickwinkeln (je ein Viertel des Bilds).
func _close_ups(ids: PackedStringArray) -> void:
	var size := get_viewport().get_visible_rect().size
	var views := [Vector3(-0.8, 0.55, 1.0), Vector3(1.0, 0.25, 0.0), Vector3(0.7, 0.6, -1.0), Vector3(-0.3, 0.02, 1.0)]
	for id in ids:
		var data := Catalog.get_furniture(id)
		if data == null:
			push_warning("Möbel '%s' gibt es nicht." % id)
			continue
		var model := FurnitureUtils.instantiate_model(data, "")
		add_child(model)
		for node in model.find_children("*", "", true, false):
			if node is BookShelf:
				node.show_sample_books()  # Regale mit Beispielbüchern (wie auf den Kacheln)
		if data.allows(FurnitureData.PLACE_CEILING):
			model.position.y = 2.6  # Ursprung oben am Aufhängepunkt
		elif data.is_wall_mounted() or data.allows(FurnitureData.PLACE_WINDOW):
			model.position.y = 1.4  # Ursprung hinten in der Mitte
		for f in 3:
			await get_tree().process_frame
		var box := _bounds(model)
		var center := box.get_center()
		var radius := maxf(box.size.length() / 2.0, 0.15)
		var tiles: Array[Image] = []
		var cam := Camera3D.new()
		cam.fov = 35
		add_child(cam)
		cam.make_current()
		for dir: Vector3 in views:
			var eye := center + dir.normalized() * radius / sin(deg_to_rad(cam.fov / 2.0)) * 1.05
			eye.y = maxf(eye.y, 0.03)
			cam.look_at_from_position(eye, center)
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(int(size.x / 2), int(size.y / 2))
			tiles.append(img)
		var sheet := Image.create(int(size.x / 2) * 2, int(size.y / 2) * 2, false, tiles[0].get_format())
		for i in tiles.size():
			sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()),
				Vector2i((i % 2) * tiles[i].get_width(), (i / 2) * tiles[i].get_height()))
		sheet.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
		print("Bild: ", id)
		cam.queue_free()
		model.queue_free()
		await get_tree().process_frame


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "GeometryInstance3D", true, false):  # ohne Lichter (riesige Hülle)
		var vis := node as GeometryInstance3D
		if vis is GPUParticles3D:
			continue
		var b := vis.global_transform * vis.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Jede Theke mit Würfelregal und Bücherkisten: von hinten (Spielfigur, Augenhöhe) und nah vor den Kisten.
func _counters() -> void:
	var size := get_viewport().get_visible_rect().size
	var counter := (load("res://scenes/furniture/counter.tscn") as PackedScene).instantiate() as Node3D
	add_child(counter)
	GenreCrates.attach(counter)
	for genre in Catalog.get_all_genres():  # alle Genres frei: so sieht man das volle Regal
		BookStock.unlock_genre(genre.get_id())
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.make_current()
	for style in CounterStyle.get_all_styles():
		CounterStyle.set_style(style.get_id())
		for f in 6:
			await get_tree().process_frame
		var tiles: Array[Image] = []
		for view: Array in [[Vector3(0.3, 1.55, -1.25), Vector3(0.0, 0.45, 0.0)], [Vector3(-0.35, 0.75, -0.75), Vector3(-0.35, 0.5, 0.0)],
				[Vector3(1.6, 1.0, -1.4), Vector3(0.2, 0.5, 0.0)], [Vector3(0.0, 1.3, 1.6), Vector3(0.0, 0.6, 0.0)]]:
			cam.look_at_from_position(view[0], view[1])
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(int(size.x / 2), int(size.y / 2))
			tiles.append(img)
		var sheet := Image.create(int(size.x / 2) * 2, int(size.y / 2) * 2, false, tiles[0].get_format())
		for i in tiles.size():
			sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()),
				Vector2i((i % 2) * tiles[i].get_width(), (i / 2) * tiles[i].get_height()))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "theke_" + style.get_id() + ".png"))
		print("Bild: theke_", style.get_id())


## Nahaufnahme der Bücher: ein Regalfach mit Beispielbüchern von vorn und schräg, dazu einzelne Bücher mit Cover.
func _books() -> void:
	var size := get_viewport().get_visible_rect().size
	var data := Catalog.get_furniture("bookshelf_oak")
	var shelf := FurnitureUtils.instantiate_model(data, "")
	add_child(shelf)
	for node in shelf.find_children("*", "", true, false):
		if node is BookShelf:
			node.show_sample_books()
	# einzelne Bücher liegend und stehend (MultiMesh wie ausgelegte Bücher wäre aufwendiger: Einzelmaterial mit Rücken)
	var books := Catalog.get_all_books()
	for i in 4:
		var b: BookData = books[i * 37 % books.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = BookLook.get_mesh()
		mi.material_override = BookLook.create_single_material(b)
		var basis := Basis(Vector3.FORWARD, PI / 2.0) if i < 2 else Basis(Vector3.UP, 0.5 * i)
		mi.transform = Transform3D(basis.scaled_local(b.size), Vector3(1.0 + i * 0.3, b.size.x / 2.0 if i < 2 else b.size.y / 2.0, 0.6))
		add_child(mi)
	for f in 20:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	var tiles: Array[Image] = []
	for view: Array in [[Vector3(0.0, 1.1, 0.9), Vector3(0.0, 1.05, 0.0)], [Vector3(0.45, 0.75, 0.55), Vector3(0.0, 0.62, 0.0)],
			[Vector3(1.4, 0.7, 1.3), Vector3(1.45, 0.05, 0.6)], [Vector3(-0.2, 1.6, 0.7), Vector3(0.0, 1.4, 0.0)]]:
		cam.look_at_from_position(view[0], view[1])
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(int(size.x / 2), int(size.y / 2))
		tiles.append(img)
	var sheet := Image.create(int(size.x / 2) * 2, int(size.y / 2) * 2, false, tiles[0].get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i((i % 2) * tiles[i].get_width(), (i / 2) * tiles[i].get_height()))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "buecher.png"))
	print("Bild: buecher")
