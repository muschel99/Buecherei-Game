class_name ThumbnailRenderer
extends Node
## Fotografiert Möbel für kleine Vorschaubilder (z. B. im Shop) – oder eine beliebige
## Modell-Szene (request_scene, z. B. die Einwurf-Varianten des Rückgabekastens).
##
## Jedes Modell wird einmal in einer eigenen, unsichtbaren Mini-Szene mit Licht und Kamera
## aufgenommen; das Bild bleibt bis zum Spielende gespeichert. Es wird immer nur ein Bild
## pro Bild-Durchgang gemacht, damit das Spiel dabei nicht ruckelt.
## Hat ein Datenblatt ein eigenes Bild (FurnitureData.icon), wird stattdessen dieses benutzt.
## Seit Etappe 6d bleiben Fotos von Möbeln und Modell-Szenen auch über das Spielende hinaus auf der Platte
## (user://thumbnails/): Beim nächsten Start sind sie sofort da. Ein Foto gilt, solange sich die Dateien
## des Modells (Szene, .glb, Materialien) nicht geändert haben – sonst wird es neu gemacht.

## Quadratisch (seit Etappe 6): hohe Regale und flache Teppiche füllen die Bild-Kacheln gleich gut.
const IMAGE_SIZE := Vector2i(224, 224)
## Blickrichtung der Kamera: schräg von vorn rechts oben
const VIEW_DIRECTION := Vector3(0.6, 0.5, 1.0)
const FIELD_OF_VIEW := 30.0
## Dinge in der Wand fast von vorn fotografieren
const WALL_VIEW_DIRECTION := Vector3(0.3, 0.2, 1.0)
## Putz für das Stück Hauswand hinter Dingen, die in der Wand sitzen (request_scene)
const WALL_MATERIAL := "res://assets/materials/wall_plaster.tres"

## Fertige Bilder für das ganze Spiel (id -> Texture2D)
static var _cache: Dictionary = {}

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _queue: Array = []  # [Kennung, Callable (baut das Modell), Callable (bekommt das Bild), Blickrichtung, Blickpunkt, Quellen]

## Ordner für die gespeicherten Fotos (Name = Kennung + Stand der Quelldateien)
const DISK_CACHE := "user://thumbnails/"
## Erhöhen, wenn sich Licht oder Kamera der Fotos ändern (dann werden alle neu gemacht). 2 = seit Etappe 6f:
## früher konnte ein leeres (weißes) Foto gespeichert werden – alle einmal neu machen
const CACHE_VERSION := 2
## So viel des Bildes muss das Modell mindestens bedecken (Anteil sichtbarer Bildpunkte), sonst gilt das Foto als
## leer und wird noch einmal gemacht (nie gespeichert)
const MIN_COVERAGE := 0.004
var _is_busy := false


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = IMAGE_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.95, 0.88, 0.8)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 1.3
	light.rotation_degrees = Vector3(-40, 30, 0)
	_viewport.add_child(light)

	_camera = Camera3D.new()
	_camera.fov = FIELD_OF_VIEW
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


## Liefert das Bild sofort, falls es schon fertig ist (sonst null). variant = Farbe (leer =
## Standardfarbe). Ein eigenes Bild im Datenblatt (icon) gilt nur für Objekte ohne Farben.
static func get_cached(data: FurnitureData, variant: String = "") -> Texture2D:
	if data.icon and not data.has_variants():
		return data.icon
	return _cache.get(cache_key(data, variant))


## Kennung eines Bilds: id bzw. id:farbe.
static func cache_key(data: FurnitureData, variant: String = "") -> String:
	return FurnitureData.make_key(data.get_id(), data.resolve_variant(variant))


## Bestellt ein Bild (in der Farbe variant). callback(texture: Texture2D) wird aufgerufen,
## sobald es fertig ist.
func request(data: FurnitureData, callback: Callable, variant: String = "") -> void:
	var ready_image := get_cached(data, variant)
	if ready_image:
		callback.call(ready_image)
		return
	_enqueue(cache_key(data, variant), func() -> Node3D: return FurnitureUtils.instantiate_model(data, variant), callback,
		VIEW_DIRECTION, {}, _furniture_sources(data))


## Bestellt ein Bild einer Modell-Szene (Vorderseite +Z). key muss eindeutig sein
## (z. B. "return_slot/slot_plain"); icon = eigenes Bild statt Foto (darf null sein).
## wall_size > 0: ein Stück Hauswand (Breite x Höhe in Metern) dahinter, z. B. für Dinge, die
## in der Wand sitzen.
func request_scene(key: String, scene_path: String, icon: Texture2D, callback: Callable,
		wall_size: Vector2 = Vector2.ZERO) -> void:
	var ready_image: Texture2D = icon if icon else _cache.get(key)
	if ready_image:
		callback.call(ready_image)
		return
	_enqueue(key, func() -> Node3D:
		var root := Node3D.new()
		var packed := load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
		var model := packed.instantiate() as Node3D if packed else null
		if model:
			root.add_child(model)
		if wall_size.x > 0.0 and wall_size.y > 0.0:
			var wall := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(wall_size.x, wall_size.y, 0.04)
			wall.mesh = box
			wall.material_override = load(WALL_MATERIAL)
			wall.position = Vector3(0.0, 0.0, -0.02)
			root.add_child(wall)
		return root, callback, WALL_VIEW_DIRECTION if wall_size.x > 0.0 else VIEW_DIRECTION, {}, [scene_path])


## Bestellt ein Bild eines selbst gebauten Modells (make_model liefert einen Node3D) aus der
## Blickrichtung view_direction (zum Modell hin gesehen von dort) – z. B. Teile der Fassade.
func request_model(key: String, make_model: Callable, callback: Callable,
		view_direction: Vector3 = VIEW_DIRECTION) -> void:
	var ready_image: Texture2D = _cache.get(key)
	if ready_image:
		callback.call(ready_image)
		return
	_enqueue(key, make_model, callback, view_direction)


## Bestellt ein Bild aus einem festen Blickpunkt (Kamera bei eye, Blick auf target, Bildwinkel fov;
## Koordinaten des Modells) – z. B. eine Nahaufnahme eines Teils der Fassade.
func request_view(key: String, make_model: Callable, callback: Callable, eye: Vector3, target: Vector3,
		fov: float = 40.0) -> void:
	var ready_image: Texture2D = _cache.get(key)
	if ready_image:
		callback.call(ready_image)
		return
	_enqueue(key, make_model, callback, VIEW_DIRECTION, {"eye": eye, "target": target, "fov": fov})


func _enqueue(key: String, make_model: Callable, callback: Callable,
		view_direction: Vector3 = VIEW_DIRECTION, view: Dictionary = {}, sources: Array = []) -> void:
	_queue.append([key, make_model, callback, view_direction, view, sources])
	if not _is_busy:
		_work()


func _work() -> void:
	_is_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var key: String = job[0]
		var texture: Texture2D = _cache.get(key)
		var disk := _disk_path(key, job[5])
		if texture == null and not disk.is_empty() and FileAccess.file_exists(disk):
			var stored := Image.load_from_file(disk)
			if stored:
				texture = ImageTexture.create_from_image(stored)
				_cache[key] = texture
		if texture == null:
			texture = await _photograph(job[1].call(), job[3], job[4])
			if not is_inside_tree():
				return
			if _covered(texture.get_image()) < MIN_COVERAGE:
				# leer (Modell noch nicht fertig gezeichnet): einmal nachfotografieren, nie leer speichern
				texture = await _photograph(job[1].call(), job[3], job[4], 4)
				if not is_inside_tree():
					return
			_cache[key] = texture
			if not disk.is_empty() and _covered(texture.get_image()) >= MIN_COVERAGE:
				DirAccess.make_dir_recursive_absolute(DISK_CACHE)
				texture.get_image().save_png(disk)
		if job[2].is_valid():
			job[2].call(texture)
	_is_busy = false


## Datei des gespeicherten Fotos (leer = nicht speichern: ohne bekannte Quelldateien, z. B. Fassaden-Teile
## mit gewähltem Stoff). Im Namen steckt der Stand aller Quelldateien – ändert sich eine, gilt das Foto nicht mehr.
func _disk_path(key: String, sources: Array) -> String:
	if sources.is_empty():
		return ""
	var stamp := "%d|%s" % [CACHE_VERSION, key]
	for path: String in sources:
		stamp += "|%s:%d" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0]
	return DISK_CACHE + stamp.md5_text() + ".png"


## Quelldateien eines Möbelstücks: Datenblatt, Szene, Modell (.glb) und seine Materialien.
static func _furniture_sources(data: FurnitureData) -> Array:
	var sources := [data.resource_path]
	if not data.scene_path.is_empty():
		sources.append(data.scene_path)
	var id := data.get_id()
	for path in ["res://assets/models/furniture/%s.glb" % id]:
		if FileAccess.file_exists(path):
			sources.append(path)
	var folder := "res://assets/materials/furniture/%s/" % id
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".tres"):
				sources.append(folder + file)
	return sources


## Stellt das Modell auf, richtet die Kamera aus und macht ein Foto.
## Anteil der Bildpunkte, die nicht durchsichtig sind (grob, jeder vierte Punkt).
static func _covered(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var hits := 0
	var total := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			total += 1
			if image.get_pixel(x, y).a > 0.1:
				hits += 1
	return float(hits) / maxf(float(total), 1.0)


func _photograph(model: Node3D, view_direction: Vector3, view: Dictionary = {}, settle_frames := 2) -> Texture2D:
	_stage.add_child(model)
	FurnitureUtils.make_preview_only(model)
	# Bücherregale bekommen fürs Foto ein paar Beispielbücher
	for node in model.find_children("*", "", true, false):
		if node is BookShelf:
			node.show_sample_books()
	if view.is_empty():
		var bounds := FurnitureUtils.get_local_aabb(model)
		var center := bounds.get_center()
		var radius := maxf(bounds.size.length() / 2.0, 0.05)
		var distance := radius / sin(deg_to_rad(FIELD_OF_VIEW / 2.0)) * 0.95
		_camera.fov = FIELD_OF_VIEW
		_camera.position = center + view_direction.normalized() * distance
		_camera.look_at(center)
		_camera.near = maxf(distance - radius * 2.0, 0.01)
		_camera.far = distance + radius * 2.0
	else:
		# Fester Blickpunkt (Nahaufnahme)
		var eye: Vector3 = view.eye
		_camera.fov = view.fov
		_camera.transform = Transform3D(Basis.looking_at(view.target - eye, Vector3.UP), eye)
		_camera.near = 0.05
		_camera.far = 60.0

	# ein paar Bilder lang zeichnen (neue Materialien und Shader brauchen manchmal einen Moment), dann das Foto
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in settle_frames:
		await RenderingServer.frame_post_draw
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var image := _viewport.get_texture().get_image()
	_stage.remove_child(model)
	model.queue_free()
	return ImageTexture.create_from_image(image)
