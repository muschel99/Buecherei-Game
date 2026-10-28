class_name TurntablePreview
extends SubViewport
## Polaroid 2 der App „Fassade“ (seit Etappe 6b): ein Modell dreht sich langsam auf einem runden Sockel
## – die gewählte Theke (show_counter) oder ein Stück Hauswand mit dem Briefkasten (show_letterbox):
## außen der Einwurf auf der Fassade (Anstrich bzw. Stein des Erdgeschosses), innen das Gegenstück.
## Eigene kleine Welt mit warmem Licht wie im Fotostudio; eine Umdrehung dauert
## GameConfig.facade_turntable_period Sekunden.

const BACKGROUND := Color(0.84, 0.78, 0.69)
const PLINTH_COLOR := Color(0.42, 0.3, 0.22)
## Innen: warmer Putz wie im Laden
const INSIDE_PLASTER := Color(0.74, 0.65, 0.53)
const FACADE_PAINT := "res://assets/materials/storybook/facade_paint.tres"
## Wandstück: Breite, Höhe (unten, oben) und Dicke wie die Hauswand am Rückgabekasten (m)
const WALL_WIDTH := 0.72
const WALL_BOTTOM := 0.45
const WALL_TOP := 1.5
const WALL_THICKNESS := 0.2
## Blickrichtung der Kamera (leicht von oben)
const VIEW_DIRECTION := Vector3(0.0, 0.32, 1.0)
const FIELD_OF_VIEW := 32.0

var _pivot: Node3D
var _camera: Camera3D
var _plinth: MeshInstance3D
var _key := ""


func _init() -> void:
	own_world_3d = true
	size = GameConfig.facade_preview_size
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.95, 0.88, 0.8)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	# Warmes Hauptlicht mit Schatten von links oben, sanftes Gegenlicht
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.92, 0.8)
	key_light.light_energy = 0.85
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = FIELD_OF_VIEW
	add_child(_camera)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_plinth = MeshInstance3D.new()
	_plinth.name = "Plinth"
	var disc := CylinderMesh.new()
	disc.height = 0.06
	disc.radial_segments = 64
	_plinth.mesh = disc
	var plinth_material := StandardMaterial3D.new()
	plinth_material.albedo_color = PLINTH_COLOR
	plinth_material.roughness = 0.7
	_plinth.material_override = plinth_material
	add_child(_plinth)
	set_process(false)


## Läuft die Vorschau (dreht sich und wird gezeichnet) oder steht sie?
func set_active(active: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	set_process(active)


func _process(delta: float) -> void:
	_pivot.rotate_y(TAU / maxf(GameConfig.facade_turntable_period, 1.0) * delta)


## Zeigt eine Theke.
func show_counter(counter: CounterData) -> void:
	var path := counter.scene_path if counter else ""
	if path == _key:
		return
	_key = path
	_clear()
	if not path.is_empty() and ResourceLoader.exists(path):
		_pivot.add_child((load(path) as PackedScene).instantiate() as Node3D)
	_frame_camera()


## Zeigt ein Stück Hauswand mit dem Briefkasten: außen der Einwurf auf der Fassade (outside_material =
## Anstrich bzw. Stein des Erdgeschosses), innen das Gegenstück (inside_path).
func show_letterbox(slot: ReturnSlotData, inside_path: String, outside_material: Material) -> void:
	var key := "%s|%s|%s" % [slot.scene_path if slot else "", inside_path, outside_material.get_instance_id() if outside_material else 0]
	if key == _key:
		return
	_key = key
	_clear()
	# Lage wie am Rückgabekasten: Ursprung in der Mitte der Wand am Boden, +Z = innen, -Z = Straße
	var middle := (WALL_BOTTOM + WALL_TOP) / 2.0
	var height := WALL_TOP - WALL_BOTTOM
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = INSIDE_PLASTER
	plaster.roughness = 0.95
	_pivot.add_child(_box(Vector3(WALL_WIDTH, height, WALL_THICKNESS), Vector3(0.0, middle, 0.0), plaster))
	var cladding := GameConfig.facade_slot_out
	_pivot.add_child(_box(Vector3(WALL_WIDTH + 0.02, height + 0.02, cladding),
		Vector3(0.0, middle, -WALL_THICKNESS / 2.0 - cladding / 2.0 + 0.002), outside_material))
	if slot and not slot.scene_path.is_empty() and ResourceLoader.exists(slot.scene_path):
		var outside := (load(slot.scene_path) as PackedScene).instantiate() as Node3D
		# wie SlotPoint im Rückgabekasten: zur Straße gedreht, 1 m hoch, auf der Fassade
		outside.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.0, -WALL_THICKNESS / 2.0 - cladding))
		_pivot.add_child(outside)
	if not inside_path.is_empty() and ResourceLoader.exists(inside_path):
		var inside := (load(inside_path) as PackedScene).instantiate() as Node3D
		inside.position = Vector3(0.0, 0.0, WALL_THICKNESS / 2.0)
		_pivot.add_child(inside)
	_frame_camera()


## Material für die Außenseite aus dem Entwurf: Naturstein oder der Anstrich des Erdgeschosses.
static func outside_material_for(design: Dictionary) -> Material:
	var ground := FacadeDesign.get_option("ground", design)
	if ground and ground.material:
		return ground.material
	var paint := FacadeDesign.get_option("ground_color", design)
	var base := load(FACADE_PAINT) as Material if ResourceLoader.exists(FACADE_PAINT) else StandardMaterial3D.new()
	return FurnitureUtils.tinted_material(base, paint.color if paint else Color(0.13, 0.25, 0.18))


func _clear() -> void:
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.queue_free()
	_pivot.rotation = Vector3.ZERO


func _box(box_size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = center
	return mesh_instance


## Kamera so, dass das Modell beim Drehen nie aus dem Bild ragt; der Sockel liegt darunter.
func _frame_camera() -> void:
	var bounds := FurnitureUtils.get_local_aabb(_pivot)
	if bounds.size == Vector3.ZERO:
		bounds = AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	# Drehung um die Mitte: Radius in der Waagerechten, Höhe bleibt
	var flat := maxf(Vector2(bounds.position.x, bounds.position.z).length(), Vector2(bounds.end.x, bounds.end.z).length())
	flat = maxf(flat, Vector2(bounds.position.x, bounds.end.z).length())
	flat = maxf(flat, Vector2(bounds.end.x, bounds.position.z).length())
	var bottom := bounds.position.y
	var top := bounds.end.y
	var plinth_mesh := _plinth.mesh as CylinderMesh
	plinth_mesh.top_radius = flat * 0.82
	plinth_mesh.bottom_radius = flat * 0.84
	_plinth.position = Vector3(0.0, bottom - plinth_mesh.height / 2.0 - 0.005, 0.0)
	var center := Vector3(0.0, (bottom + top) / 2.0 - 0.03, 0.0)
	var radius := Vector2(flat, (top - bottom) / 2.0).length()
	var distance := radius / sin(deg_to_rad(FIELD_OF_VIEW / 2.0)) * 0.98
	var eye := center + VIEW_DIRECTION.normalized() * distance
	_camera.transform = Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye)
	_camera.near = maxf(distance - radius * 2.5, 0.05)
	_camera.far = distance + radius * 3.0
