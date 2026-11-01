class_name FacadePreview
extends SubViewport
## Polaroid der App „Fassade“ (seit Etappe 6d ein ruhiges Modell): nur das Bücherei-Haus mit seiner
## Eingangstreppe auf dem Gehweg unter blauem Himmel (seit Etappe 6f) – keine Nachbarhäuser, keine Straßenlaterne, keine
## Bewegung, die Tür immer geschlossen (so erkennt man die gewählte Tür gut). Gezeichnet wird nur, wenn sich
## am Entwurf etwas ändert (show_design → ein Bild).
##
## Eine eigene kleine Welt (own_world_3d): die Vorschau-Fassade (LibraryFacade mit follow_design = false)
## an ihrem Platz, Türblatt und Einwurf nach dem Entwurf, dahinter ein warmer Innenraum (die Fenster sind
## nicht leer), darunter der Gehweg (Material wie auf der Straße). Kopiert wird nur die Treppe (Optik, einmal
## bei prepare).
## Blickpunkt: GameConfig (facade_preview_*). Die echte Fassade ändert sich dabei nie.

## Himmel (oben kräftiger, zum Horizont heller), Boden = Gehweg, Innenraum warm
const SKY_TOP := Color(0.33, 0.55, 0.86)
const SKY_HORIZON := Color(0.74, 0.85, 0.95)
const GROUND_MATERIAL := preload("res://assets/materials/sidewalk.tres")
const GROUND_DARKEN := 0.18
const INSIDE_COLOR := Color(0.38, 0.29, 0.21)

var _stage: Node3D
var _surroundings: Node3D
var _facade: LibraryFacade
var _camera: Camera3D
var _leaf_holder: Node3D
var _slot_holder: Node3D
var _slot_path := ""
var _leaf_key := ""
var _shown_design := {}


func _init() -> void:
	own_world_3d = true
	size = GameConfig.facade_preview_size
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_camera = Camera3D.new()
	_camera.fov = GameConfig.facade_preview_fov
	_camera.far = 400.0
	add_child(_camera)


## true = das aktuelle Bild einmal neu zeichnen (z. B. wenn das Polaroid wieder erscheint).
func set_active(active: bool) -> void:
	if active:
		render_target_update_mode = SubViewport.UPDATE_ONCE


## Ist schon ein Modell gebaut (das Polaroid zeigt ein Bild)?
func is_ready() -> bool:
	return _facade != null


## Baut die ruhige Bühne (einmal je Öffnen der App, schnell): Licht und Hintergrund, Boden, Innenraum,
## eine Kopie der Treppe, Halter für Türblatt (geschlossen) und Einwurf an ihren Plätzen.
## room = der Laden (GroundFloorRoom), sein Elternknoten ist die Hauptszene.
func prepare(room: Node3D) -> void:
	if _surroundings:
		_stage.remove_child(_surroundings)
		_surroundings.queue_free()
	_surroundings = Node3D.new()
	_surroundings.name = "Surroundings"
	_stage.add_child(_surroundings)
	_place_camera()
	_setup_lights()
	var game := room.get_parent()
	var steps := game.get_node_or_null("EntranceSteps") if game else null
	if steps:
		_copy_visuals(steps)
	_surroundings.add_child(_ground())
	_surroundings.add_child(_inside(room))
	var door_node := room.get_node_or_null("Door")
	if door_node:
		_leaf_holder_at((door_node.get_node("Hinge") as Node3D).global_transform)
	var box := room.get_node_or_null("ReturnBox") as Node3D
	var slot_point := box.get_node_or_null("SlotPoint") as Node3D if box else null
	if slot_point:
		if _slot_holder == null:
			_slot_holder = Node3D.new()
			_slot_holder.name = "Slot"
			_stage.add_child(_slot_holder)
		_slot_holder.transform = slot_point.global_transform
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Zeigt den Entwurf (Wahl wie FacadeDesign.get_draft: Fassade, "slot" …). Gleiche Teile bleiben stehen;
## danach wird genau ein Bild gezeichnet.
func show_design(design: Dictionary) -> void:
	if design == _shown_design and _facade:
		return
	_shown_design = design.duplicate()
	if _facade == null:
		_facade = LibraryFacade.new()
		_facade.name = "Facade"
		_facade.follow_design = false
		_facade.build(design)  # vor dem Einhängen bauen (sonst baut sie sich erst mit dem Standard)
		_stage.add_child(_facade)
	else:
		_facade.build(design)
	# Türblatt in der Türfarbe (immer geschlossen)
	var door := FacadeDesign.get_option("door", design)
	var color := FacadeDesign.get_option("door_color", design)
	var leaf_path := door.scene_path if door else ""
	var leaf_color: Color = color.color if color else Color(0.13, 0.25, 0.18)
	var weather := color.weather if color else 0.0
	var key := leaf_path + str(leaf_color) + str(weather)
	if _leaf_holder and key != _leaf_key:
		_leaf_key = key
		TabletApp.clear(_leaf_holder)
		if not leaf_path.is_empty() and ResourceLoader.exists(leaf_path):
			_leaf_holder.add_child(Door.make_leaf_model(leaf_path, leaf_color, weather))
	# Einwurf auf der Fassade
	var slot := Catalog.get_return_slot(str(design.get("slot", "")))
	var slot_path := slot.scene_path if slot else ""
	if _slot_holder and slot_path != _slot_path:
		_slot_path = slot_path
		TabletApp.clear(_slot_holder)
		if not slot_path.is_empty() and ResourceLoader.exists(slot_path):
			var model := (load(slot_path) as PackedScene).instantiate() as Node3D
			model.position = Vector3(0.0, 0.0, GameConfig.facade_slot_out)
			_slot_holder.add_child(model)
	# nur jetzt ein neues Bild (das Modell steht still)
	render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Aufbau ---

func _leaf_holder_at(hinge_transform: Transform3D) -> void:
	if _leaf_holder == null:
		_leaf_holder = Node3D.new()
		_leaf_holder.name = "DoorLeaf"
		_stage.add_child(_leaf_holder)
	_leaf_holder.transform = hinge_transform


## Von der anderen Straßenseite schräg auf die Eingangswand.
func _place_camera() -> void:
	var door := StreetLayout.door_center()
	var out := Vector3(-1.0, 0.0, -1.0).normalized()
	_camera.fov = GameConfig.facade_preview_fov
	var eye := door + out * GameConfig.facade_preview_distance + Vector3(0.0, GameConfig.facade_preview_eye, 0.0)
	var target := door + Vector3(0.0, GameConfig.facade_preview_target_height, 0.0)
	_camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


## Ruhiges Licht: helle, warme Sonne schräg von vorn links, weiches Umgebungslicht, heller Hintergrund.
func _setup_lights() -> void:
	for child in _stage.get_children():
		if child is Light3D or child is WorldEnvironment:
			_stage.remove_child(child)
			child.queue_free()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = SKY_HORIZON
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.84, 0.8)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	var door := StreetLayout.door_center()
	var from := door + Vector3(-6.0, 9.0, -3.0)
	sun.transform = Transform3D(Basis.looking_at(door - from, Vector3.UP), from)
	_stage.add_child(sun)


## Gehweg unter dem Haus (fängt die Schatten; Platten wie auf der Straße).
func _ground() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	# etwas dunkler als auf der Straße: in der hellen Sonne der Vorschau wären die Platten sonst fast weiß
	var material := GROUND_MATERIAL.duplicate() as ShaderMaterial
	for key in ["color_a", "color_b", "color_c", "color_accent", "joint_color"]:
		var color: Variant = material.get_shader_parameter(key)
		if color is Color:
			material.set_shader_parameter(key, (color as Color).darkened(GROUND_DARKEN))
	mi.material_override = material
	mi.position = StreetLayout.door_center() * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, StreetLayout.ground_y() - 0.01, 0.0)
	return mi


## Warmer Innenraum hinter den Fenstern: Grundriss des Ladens (30 cm nach innen), so hoch wie das
## Erdgeschoss – damit die Fenster nicht leer wirken.
func _inside(room: Node3D) -> MeshInstance3D:
	var outline := PackedVector2Array()
	for p: Vector2 in FacadeLayout.OUTLINE:
		outline.append(Vector2(p.x, -p.y))
	var inner := OpeningShape.offset(outline, -0.3)
	# Wände, Boden und Decke zeigen nach innen: durch die Fenster sieht man in einen Raum
	var mesh := OpeningMesh.new()
	mesh.loop_sides(inner, 0.0, FacadeLayout.TOP - 0.1, true)
	mesh.face(inner, 0.02, 1.0)
	mesh.face(inner, FacadeLayout.TOP - 0.1, -1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = INSIDE_COLOR
	material.emission_enabled = true
	material.emission = INSIDE_COLOR * 0.6
	material.roughness = 1.0
	var mi := mesh.instance(material, "Inside")
	# Umriss lag in der Bodenebene (x, -z); lokal z (Dicke) wird zur Höhe
	mi.transform = room.global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	return mi


## Kopiert die Optik aller sichtbaren Teile unter source (Treppe).
func _copy_visuals(source: Node) -> void:
	if source is Node3D and not (source as Node3D).visible:
		return
	if source is GeometryInstance3D:
		var instance := source as GeometryInstance3D
		var copy := _visual_copy(instance)
		if copy:
			copy.transform = instance.global_transform
			_surroundings.add_child(copy)
	for child in source.get_children():
		_copy_visuals(child)


## Eine Kopie nur der Optik (oder null).
func _visual_copy(source: GeometryInstance3D) -> Node3D:
	if not source is MeshInstance3D:
		return null
	var mesh_instance := source as MeshInstance3D
	if mesh_instance.mesh == null or mesh_instance.skin:
		return null
	var copy := MeshInstance3D.new()
	copy.mesh = mesh_instance.mesh
	for i in mesh_instance.get_surface_override_material_count():
		copy.set_surface_override_material(i, mesh_instance.get_surface_override_material(i))
	copy.material_override = source.material_override
	copy.cast_shadow = source.cast_shadow
	return copy
