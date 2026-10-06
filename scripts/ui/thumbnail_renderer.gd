class_name ThumbnailRenderer
extends Node
## Fotografiert Möbel für kleine Vorschaubilder (z. B. im Shop).
##
## Jedes Modell wird einmal in einer eigenen, unsichtbaren Mini-Szene mit Licht und Kamera
## aufgenommen; das Bild bleibt bis zum Spielende gespeichert. Es wird immer nur ein Bild
## pro Bild-Durchgang gemacht, damit das Spiel dabei nicht ruckelt.
## Hat ein Datenblatt ein eigenes Bild (FurnitureData.icon), wird stattdessen dieses benutzt.

const IMAGE_SIZE := Vector2i(256, 176)
## Blickrichtung der Kamera: schräg von vorn rechts oben
const VIEW_DIRECTION := Vector3(0.6, 0.5, 1.0)
const FIELD_OF_VIEW := 30.0

## Fertige Bilder für das ganze Spiel (id -> Texture2D)
static var _cache: Dictionary = {}

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _queue: Array = []  # [FurnitureData, Callable]
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


## Liefert das Bild sofort, falls es schon fertig ist (sonst null).
static func get_cached(data: FurnitureData) -> Texture2D:
	if data.icon:
		return data.icon
	return _cache.get(data.get_id())


## Bestellt ein Bild. callback(texture: Texture2D) wird aufgerufen, sobald es fertig ist.
func request(data: FurnitureData, callback: Callable) -> void:
	var ready_image := get_cached(data)
	if ready_image:
		callback.call(ready_image)
		return
	_queue.append([data, callback])
	if not _is_busy:
		_work()


func _work() -> void:
	_is_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var data: FurnitureData = job[0]
		var texture := get_cached(data)
		if texture == null:
			texture = await _photograph(data)
			if not is_inside_tree():
				return
			_cache[data.get_id()] = texture
		if job[1].is_valid():
			job[1].call(texture)
	_is_busy = false


## Stellt das Modell auf, richtet die Kamera aus und macht ein Foto.
func _photograph(data: FurnitureData) -> Texture2D:
	var model := FurnitureUtils.instantiate_model(data)
	_stage.add_child(model)
	FurnitureUtils.make_preview_only(model)
	# Bücherregale bekommen fürs Foto ein paar Beispielbücher
	for node in model.find_children("*", "", true, false):
		if node is BookShelf:
			node.show_sample_books()
	var bounds := FurnitureUtils.get_local_aabb(model)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() / 2.0, 0.05)
	var distance := radius / sin(deg_to_rad(FIELD_OF_VIEW / 2.0)) * 0.95
	_camera.position = center + VIEW_DIRECTION.normalized() * distance
	_camera.look_at(center)
	_camera.near = maxf(distance - radius * 2.0, 0.01)
	_camera.far = distance + radius * 2.0

	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	_stage.remove_child(model)
	model.queue_free()
	return ImageTexture.create_from_image(image)
