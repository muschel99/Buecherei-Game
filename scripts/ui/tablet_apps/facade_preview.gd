class_name FacadePreview
extends SubViewport
## Polaroid 1 der App „Fassade“ (seit Etappe 6b): die Bücherei von der anderen Straßenseite, mit Blick
## auf die schräge Eingangswand – live mit dem Entwurf (show_design).
##
## Eine eigene kleine Welt (own_world_3d): Die Vorschau-Fassade (LibraryFacade mit follow_design = false)
## steht genau an ihrem Platz, dazu Türblatt und Einwurf nach dem Entwurf. Drumherum eine Kopie dessen,
## was man von dort sieht: Laden (Wände, Fenster, Tür, Einrichtung), Eingangstreppe, Straße, Nachbarhäuser
## und Pflanzen in der Nähe. Kopiert wird nur die Optik (die Netze teilt sie mit dem Spiel), einmal beim
## Öffnen der App (capture). Sonne, Himmelslicht und Himmel wie im Spiel. Blickpunkt: GameConfig
## (facade_preview_*). Die echte Fassade ändert sich dabei nie.

## So weit um die Tür herum wird die Umgebung kopiert (m)
const SURROUNDINGS_RADIUS := 24.0
## Instanz-Werte (instance uniform) werden nicht mitkopiert: Die Bilderbuch-Häuser tragen ihre Farben im
## Modell, und der Speicher für Instanz-Werte ist begrenzt (Kompatibilitäts-Renderer: 4096 Einträge).

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


## Läuft die Vorschau (true) oder steht sie (false, spart Rechenzeit)?
func set_active(active: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


## Kopiert die Umgebung aus dem Spiel (einmal beim Öffnen der App; ein zweiter Aufruf erneuert sie).
## room = der Laden (GroundFloorRoom), sein Elternknoten ist die Hauptszene. Die Vorschau muss dafür
## nicht im Baum hängen: Bühne und Welt liegen im Ursprung, Lagen werden direkt als transform gesetzt.
func capture(room: Node3D) -> void:
	if _surroundings:
		_stage.remove_child(_surroundings)
		_surroundings.queue_free()
	_surroundings = Node3D.new()
	_surroundings.name = "Surroundings"
	_stage.add_child(_surroundings)
	var game := room.get_parent()
	var door := StreetLayout.door_center()
	var area := AABB(door - Vector3.ONE * SURROUNDINGS_RADIUS, Vector3.ONE * SURROUNDINGS_RADIUS * 2.0)
	# Nicht kopieren: die echte Fassade, Türblatt-Modell, Rückgabekasten (Einwurf zeigt die Vorschau selbst)
	# und alles, was sich bewegt (Passanten, Fahrzeuge)
	var skip: Array[Node] = []
	for path in ["Facade", "ReturnBox", "Door/Hinge/LeafModel"]:
		var node := room.get_node_or_null(path)
		if node:
			skip.append(node)
	var door_node := room.get_node_or_null("Door")
	if door_node:
		for part in Door.BUILTIN_LEAF_PARTS:
			var node := door_node.get_node_or_null("Hinge/" + part)
			if node:
				skip.append(node)
	var street_life := game.get_node_or_null("Outside/StreetLife") if game else null
	if street_life:
		skip.append(street_life)
	var sources: Array[Node] = [room]
	for path in ["EntranceSteps", "Outside", "UpperFloors"]:
		var node := game.get_node_or_null(path) if game else null
		if node:
			sources.append(node)
	_place_camera()
	for source in sources:
		_copy_visuals(source, area, skip)
	_copy_lights(game)
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


## Zeigt den Entwurf (Wahl wie FacadeDesign.get_draft: Fassade, "slot" …). Gleiche Teile bleiben stehen.
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
	_mark_outdoor(_facade)
	# Türblatt in der Türfarbe
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


## Himmel, Sonne und Himmelslicht wie im Spiel.
func _copy_lights(game: Node) -> void:
	for child in _stage.get_children():
		if child is Light3D or child is WorldEnvironment:
			_stage.remove_child(child)
			child.queue_free()
	var world_environment := game.get_node_or_null("WorldEnvironment") as WorldEnvironment if game else null
	if world_environment and world_environment.environment:
		var copy := WorldEnvironment.new()
		var environment := world_environment.environment.duplicate() as Environment
		# Nebel mit Lichtstrahlen kostet viel und ist von draußen kaum zu sehen
		environment.volumetric_fog_enabled = false
		copy.environment = environment
		copy.camera_attributes = world_environment.camera_attributes
		_stage.add_child(copy)
	for light_name in ["Sun", "SkyFill"]:
		var light := game.get_node_or_null(light_name) as DirectionalLight3D if game else null
		if light == null or not light.visible:
			continue
		var copy := DirectionalLight3D.new()
		copy.name = light_name
		copy.light_color = light.light_color
		copy.light_energy = light.light_energy
		copy.light_cull_mask = light.light_cull_mask
		copy.shadow_enabled = light.shadow_enabled
		copy.shadow_blur = light.shadow_blur
		copy.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		copy.directional_shadow_max_distance = 40.0
		copy.transform = light.global_transform
		_stage.add_child(copy)


## Kopiert die Optik aller sichtbaren Teile unter source, die im Bereich area liegen (ohne skip).
func _copy_visuals(source: Node, area: AABB, skip: Array[Node]) -> void:
	if skip.has(source):
		return
	if source is Node3D and not (source as Node3D).visible:
		return
	if source is GeometryInstance3D:
		var instance := source as GeometryInstance3D
		var bounds := instance.global_transform * instance.get_aabb()
		if bounds.intersects(area) and _in_view(bounds):
			var copy := _visual_copy(instance)
			if copy:
				copy.transform = instance.global_transform
				_surroundings.add_child(copy)
	for child in source.get_children():
		_copy_visuals(child, area, skip)


## Liegt etwas (ungefähr) im Blickfeld der Kamera? Kegel um die Blickrichtung, etwas weiter als das
## Bild (die Ecken sind breiter als der senkrechte Bildwinkel).
func _in_view(bounds: AABB) -> bool:
	var eye := _camera.transform.origin
	var forward := -_camera.transform.basis.z
	var to_center := bounds.get_center() - eye
	var radius := bounds.size.length() / 2.0
	var distance := to_center.length()
	if distance <= radius:
		return true
	var angle := forward.angle_to(to_center) - asin(clampf(radius / distance, 0.0, 1.0))
	return angle <= deg_to_rad(_camera.fov * 0.5 * 1.7)


## Eine Kopie nur der Optik (oder null für Dinge, die nicht in ein Foto gehören). Bei CSG ein Halter mit
## dem fertig berechneten Netz darin.
func _visual_copy(source: GeometryInstance3D) -> Node3D:
	var copy: GeometryInstance3D = null
	var result: Node3D = null
	if source is MeshInstance3D:
		var mesh_instance := source as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.skin:
			return null
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = mesh_instance.mesh
		for i in mesh_instance.get_surface_override_material_count():
			mesh_copy.set_surface_override_material(i, mesh_instance.get_surface_override_material(i))
		copy = mesh_copy
		result = copy
	elif source is MultiMeshInstance3D:
		var multi := source as MultiMeshInstance3D
		if multi.multimesh == null:
			return null
		var multi_copy := MultiMeshInstance3D.new()
		multi_copy.multimesh = multi.multimesh
		copy = multi_copy
		result = copy
	elif source is CSGShape3D and (source as CSGShape3D).is_root_shape():
		# get_meshes: [Lage relativ zum CSG-Knoten, Netz]
		var meshes := (source as CSGShape3D).get_meshes()
		if meshes.size() < 2 or meshes[1] == null:
			return null
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = meshes[1]
		mesh_copy.transform = meshes[0]
		copy = mesh_copy
		result = Node3D.new()
		result.add_child(mesh_copy)
	else:
		return null
	copy.material_override = source.material_override
	copy.cast_shadow = source.cast_shadow
	copy.layers = source.layers
	copy.transparency = source.transparency
	return result


## Wie im Spiel (main.gd): Alles draußen bekommt das Himmelslicht (Render-Ebene OUTDOOR_RENDER_LAYER).
static func _mark_outdoor(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).set_layer_mask_value(GameConfig.OUTDOOR_RENDER_LAYER, true)
	for child in node.get_children():
		_mark_outdoor(child)
