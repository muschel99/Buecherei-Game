class_name BuildMode
extends Node
## Der Gestaltungsmodus: Möbel platzieren, verschieben, drehen, entfernen,
## Wände streichen und Böden tauschen – alles in der Ego-Perspektive.
##
## Ein- und ausschalten mit B. Die Oberfläche (Katalog, Tastenhilfe) steckt in
## BuildUI und meldet sich über Signale, wenn etwas im Katalog gewählt wird.

## Wird gesendet, wenn der Gestaltungsmodus an- oder ausgeht.
signal active_changed(active: bool)
## Neuer Hinweistext für die Statuszeile.
signal status_changed(text: String, is_warning: bool)
## Raster an/aus.
signal grid_changed(enabled: bool)
## Das gewählte Katalog-Element hat sich geändert (null = nichts gewählt).
signal selection_changed(selected: Resource)

enum Tool { NONE, PLACE_NEW, MOVE, PAINT }

## Pfade zu Spielfigur und Raum (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath
@export var room_path: NodePath

@onready var _player: Player = get_node(player_path)
@onready var _room: Room = get_node(room_path)

var is_active: bool = false
var grid_enabled: bool = true

var _tool: Tool = Tool.NONE
var _selected_data: FurnitureData = null
var _selected_surface: SurfaceData = null
var _moving_item: PlacedFurniture = null
var _moving_extras: Array[PlacedFurniture] = []
var _rotation_degrees: float = 0.0
var _hovered: PlacedFurniture = null

var _preview: FurniturePreview
var _grid: MeshInstance3D
var _grid_material: ShaderMaterial

# Ergebnis der letzten Platzprüfung
var _placement_ok := false
var _placement_visible := false
var _placement_transform := Transform3D.IDENTITY
var _placement_support: PlacedFurniture = null
var _placement_on_floor := true
var _status_text := ""
var _flash_until_msec := 0


func _ready() -> void:
	grid_enabled = GameConfig.grid_enabled_at_start
	_preview = FurniturePreview.new()
	_preview.name = "FurniturePreview"
	_preview.visible = false
	_room.add_child(_preview)
	_create_grid()


# --- Eingabe ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		set_active(not is_active)
		get_viewport().set_input_as_handled()
		return
	if not is_active:
		return

	if event.is_action_pressed("build_catalog"):
		_toggle_catalog_cursor()
	elif event.is_action_pressed("build_toggle_grid"):
		_set_grid_enabled(not grid_enabled)
	elif event.is_action_pressed("build_delete"):
		_delete_target()
	elif event.is_action_pressed("build_rotate"):
		_rotate(1.0)
	elif event.is_action_pressed("build_rotate_back"):
		_rotate(-1.0)
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return  # Maus ist frei (Katalog): Klicks gehören der Oberfläche
	elif event.is_action_pressed("build_place"):
		_on_primary_click()
	elif event.is_action_pressed("build_cancel"):
		_cancel_tool()
	else:
		return
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	match _tool:
		Tool.NONE:
			_update_hover()
		Tool.PLACE_NEW, Tool.MOVE:
			_update_placement()
		Tool.PAINT:
			_update_paint_hint()


# --- Ein- und Ausschalten ---

func set_active(active: bool) -> void:
	if active == is_active:
		return
	is_active = active
	_player.interaction_enabled = not active
	if active:
		# Zum Start ist die Maus frei, damit man gleich im Katalog wählen kann
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_status("Wähle unten etwas aus dem Katalog – oder klicke in den Raum, um dich umzusehen.")
	else:
		_cancel_tool()
		_set_hovered(null)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		SaveManager.request_save()
	_update_grid_visibility()
	active_changed.emit(active)


## Wird von der Katalog-Oberfläche aufgerufen.
func select_furniture(data: FurnitureData) -> void:
	_cancel_tool()
	_selected_data = data
	_tool = Tool.PLACE_NEW
	_preview.setup(data)
	if grid_enabled:
		_rotation_degrees = snappedf(_rotation_degrees, 90.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	selection_changed.emit(data)


## Wird von der Katalog-Oberfläche aufgerufen.
func select_surface(surface: SurfaceData) -> void:
	_cancel_tool()
	_selected_surface = surface
	_tool = Tool.PAINT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	selection_changed.emit(surface)


func _toggle_catalog_cursor() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Aktionen ---

func _on_primary_click() -> void:
	match _tool:
		Tool.NONE:
			if _hovered:
				_pick_up(_hovered)
		Tool.PLACE_NEW:
			if _placement_ok:
				_room.add_furniture(_selected_data, _placement_transform, _placement_support)
				_flash_status("%s aufgestellt. Klicke erneut für ein weiteres – Rechtsklick beendet." % _selected_data.display_name)
		Tool.MOVE:
			if _placement_ok:
				_room.move_furniture(_moving_item, _placement_transform, _placement_support)
				_finish_move()
		Tool.PAINT:
			if not _ray_from_camera(FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT).is_empty():
				_room.apply_surface(_selected_surface)
				var what := "Wände sind jetzt" if _selected_surface.kind == SurfaceData.Kind.WALL else "Der Boden ist jetzt"
				_flash_status("%s „%s“." % [what, _selected_surface.display_name])


## Hebt ein platziertes Möbelstück auf, um es neu zu platzieren.
func _pick_up(item: PlacedFurniture) -> void:
	_set_hovered(null)
	_moving_item = item
	_moving_extras = _room.get_dependents(item)
	var extras: Array[Dictionary] = []
	var inverse := item.global_transform.affine_inverse()
	for extra in _moving_extras:
		extras.append({"data": extra.data, "transform": inverse * extra.global_transform})
	for piece: PlacedFurniture in [item] + _moving_extras:
		piece.set_collision_enabled(false)
		piece.visible = false
	_rotation_degrees = rad_to_deg(item.rotation.y)
	if grid_enabled:
		_rotation_degrees = snappedf(_rotation_degrees, 90.0)
	_preview.setup(item.data, extras)
	_tool = Tool.MOVE
	selection_changed.emit(null)


## Stellt ein aufgehobenes Möbelstück wieder sichtbar hin.
func _finish_move() -> void:
	for piece: PlacedFurniture in [_moving_item] + _moving_extras:
		if is_instance_valid(piece):
			piece.set_collision_enabled(true)
			piece.visible = true
	_moving_item = null
	_moving_extras.clear()
	_clear_tool()


## Rechtsklick: Auswahl aufheben bzw. aufgehobenes Möbelstück an den alten Platz zurück.
func _cancel_tool() -> void:
	if _tool == Tool.MOVE:
		_finish_move()  # Transform wurde nicht geändert = alter Platz
	else:
		_clear_tool()


func _clear_tool() -> void:
	_tool = Tool.NONE
	_selected_data = null
	_selected_surface = null
	_preview.clear()
	_preview.visible = false
	_placement_visible = false
	_update_grid_visibility()
	selection_changed.emit(null)


func _delete_target() -> void:
	if _tool == Tool.MOVE:
		var item := _moving_item
		var item_name := item.data.display_name
		_moving_item = null
		_moving_extras.clear()
		_room.remove_furniture(item)
		_clear_tool()
		_flash_status("%s entfernt." % item_name)
	elif _tool == Tool.NONE and _hovered:
		var item := _hovered
		_set_hovered(null)
		_flash_status("%s entfernt." % item.data.display_name)
		_room.remove_furniture(item)


func _rotate(direction: float) -> void:
	if _tool != Tool.PLACE_NEW and _tool != Tool.MOVE:
		return
	var step := GameConfig.rotation_step_grid if grid_enabled else GameConfig.rotation_step_free
	_rotation_degrees = fposmod(_rotation_degrees + step * direction, 360.0)


func _set_grid_enabled(enabled: bool) -> void:
	grid_enabled = enabled
	if enabled:
		_rotation_degrees = fposmod(snappedf(_rotation_degrees, 90.0), 360.0)
	_update_grid_visibility()
	grid_changed.emit(enabled)
	_flash_status("Raster eingeschaltet." if enabled else "Raster ausgeschaltet – freies Platzieren.")


# --- Zeigen und Prüfen ---

## Ohne Auswahl: Möbelstück unter dem Fadenkreuz hervorheben.
func _update_hover() -> void:
	var hit := _ray_from_camera(FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT)
	var item: PlacedFurniture = null
	if not hit.is_empty():
		item = FurnitureUtils.find_placed_furniture(hit.collider)
	_set_hovered(item)
	if item:
		_set_status("%s – Linksklick: verschieben · Entf: entfernen" % item.data.display_name)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_set_status("Zeige auf ein Möbelstück, um es zu verschieben – oder öffne mit Tab den Katalog.")


func _set_hovered(item: PlacedFurniture) -> void:
	if item == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(false)
	_hovered = item
	if _hovered:
		_hovered.set_highlighted(true)


func _update_paint_hint() -> void:
	var where := "die Wände zu streichen" if _selected_surface.kind == SurfaceData.Kind.WALL else "den Boden zu verlegen"
	_set_status("%s: Klicke in den Raum, um %s. Rechtsklick: beenden." % [_selected_surface.display_name, where])


## Berechnet, wo die Vorschau steht und ob das Möbelstück dort passt.
func _update_placement() -> void:
	var data := _preview.data
	_placement_visible = false
	_placement_ok = false
	_placement_support = null

	var hit := _ray_from_camera(FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT)
	if hit.is_empty() or hit.normal.y < -0.5:
		_preview.visible = false
		_update_grid_visibility()
		_set_status("Schau auf den Boden oder eine Ablage, um %s hinzustellen." % data.display_name, true)
		return

	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var half := _rotated_half_size(data)

	# Zeigt man auf eine Wand oder eine Möbelseite, rückt die Vorschau davor
	if absf(normal.y) < 0.5:
		var flat := Vector3(normal.x, 0.0, normal.z).normalized()
		var reach := absf(flat.x) * half.x + absf(flat.z) * half.y
		point += flat * (reach + 0.01)

	# Höhe bestimmen: von oben nach unten auf die nächste Fläche schauen
	var start_height: float = hit.position.y + 0.1
	var down := _find_ground(point, start_height, data)
	# Auf dem Boden rastet das Möbelstück im Raster ein. Auf Tischen und Regalbrettern
	# nicht, denn deren Fächer passen selten genau zum Raster des Raums.
	if grid_enabled and FurnitureUtils.find_placed_furniture(down.get("collider")) == null:
		var cells := _rotated_cells(data)
		point.x = _snap_axis(point.x, cells.x)
		point.z = _snap_axis(point.z, cells.y)
		down = _find_ground(point, start_height, data)

	var surface_normal := Vector3.UP
	point.y = _room.floor_height
	if not down.is_empty():
		point.y = down.position.y
		surface_normal = down.normal
		_placement_support = FurnitureUtils.find_placed_furniture(down.collider)

	_placement_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(_rotation_degrees)), point)
	_placement_on_floor = _placement_support == null
	_placement_visible = true
	_preview.global_transform = _placement_transform
	_preview.visible = true

	var problem := _find_problem(surface_normal)
	_placement_ok = problem.is_empty()
	_preview.set_valid(_placement_ok)
	_update_grid_visibility()

	var price_text := "%d %s" % [data.price, GameConfig.currency_name]
	if _placement_ok:
		_set_status("%s (%s) – Linksklick: platzieren · R/Mausrad: drehen · Rechtsklick: abbrechen" % [data.display_name, price_text])
	else:
		_set_status("%s – %s" % [data.display_name, problem], true)


## Liefert einen Grund, warum das Möbelstück hier nicht passt (leer = passt).
func _find_problem(surface_normal: Vector3) -> String:
	var data := _preview.data
	if not _room.is_inside_build_area(_placement_transform.origin):
		return "Das muss im Raum stehen."
	if surface_normal.y < 0.7:
		return "Hier steht es nicht gerade."
	if _placement_support:
		if not _placement_support.data.has_surface:
			return "Darauf kann man nichts abstellen."

	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.PLAYER_LAYER_BIT \
		| FurnitureUtils.FURNITURE_LAYER_BIT | FurnitureUtils.BUILD_BLOCKER_LAYER_BIT
	query.collide_with_areas = true
	var shapes := _preview.get_shapes()
	for i in shapes.size():
		query.shape = _preview.get_shrunk_shape(i)
		# Etwas anheben, damit das Aufstehen auf Boden oder Tisch nicht als Überschneidung zählt
		query.transform = shapes[i].global_transform.translated(Vector3.UP * FurniturePreview.SHRINK)
		for result in space.intersect_shape(query, 4):
			var other: Object = result.collider
			if other is Area3D:
				return "Bitte den Eingang frei lassen."
			if other is Player:
				return "Du stehst im Weg – geh ein Stück zur Seite."
			if FurnitureUtils.find_placed_furniture(other):
				return "Hier steht schon etwas."
			return "Zu nah an der Wand."
	return ""


## Schaut senkrecht nach unten: Worauf würde das Möbelstück hier stehen?
## Möbel ohne "can_stand_on_surfaces" sehen dabei nur den Boden.
func _find_ground(point: Vector3, start_height: float, data: FurnitureData) -> Dictionary:
	var mask := FurnitureUtils.WORLD_LAYER_BIT
	if data.can_stand_on_surfaces:
		mask |= FurnitureUtils.FURNITURE_LAYER_BIT
	var from := Vector3(point.x, start_height, point.z)
	return _ray(from, Vector3(point.x, _room.floor_height - 1.0, point.z), mask)


# --- Raster ---

## Grundfläche in Rasterfeldern nach dem Drehen (bei 90°/270° vertauscht).
func _rotated_cells(data: FurnitureData) -> Vector2i:
	var quarter := int(roundf(_rotation_degrees / 90.0)) % 2
	return Vector2i(data.footprint.y, data.footprint.x) if quarter == 1 else data.footprint


## Halbe Grundfläche in Metern (x, z) nach dem Drehen.
func _rotated_half_size(data: FurnitureData) -> Vector2:
	var size := data.get_footprint_size()
	var angle := deg_to_rad(_rotation_degrees)
	var c := absf(cos(angle))
	var s := absf(sin(angle))
	return Vector2(size.x * c + size.y * s, size.x * s + size.y * c) / 2.0


## Rastet einen Wert ein: Bei ungerader Feldzahl liegt die Mitte in einem Feld,
## bei gerader Feldzahl auf einer Rasterlinie – so liegen die Kanten immer auf Linien.
func _snap_axis(value: float, cells: int) -> float:
	var cell := GameConfig.grid_cell_size
	if cells % 2 == 1:
		return (floorf(value / cell) + 0.5) * cell
	return roundf(value / cell) * cell


func _create_grid() -> void:
	var area := _room.build_area
	var plane := PlaneMesh.new()
	plane.size = area.size
	_grid_material = ShaderMaterial.new()
	_grid_material.shader = load("res://assets/shaders/build_grid.gdshader")
	_grid_material.set_shader_parameter("cell_size", GameConfig.grid_cell_size)
	_grid = MeshInstance3D.new()
	_grid.name = "BuildGrid"
	_grid.mesh = plane
	_grid.material_override = _grid_material
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.position = Vector3(area.get_center().x, _room.floor_height + 0.004, area.get_center().y)
	_grid.visible = false
	_room.add_child(_grid)


func _update_grid_visibility() -> void:
	var show := is_active and grid_enabled and _placement_visible and _placement_on_floor \
		and (_tool == Tool.PLACE_NEW or _tool == Tool.MOVE)
	_grid.visible = show
	if show:
		_grid_material.set_shader_parameter("focus_point", _placement_transform.origin)


# --- Hilfsfunktionen ---

func _ray_from_camera(mask: int) -> Dictionary:
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * GameConfig.build_reach
	return _ray(from, to, mask)


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [_player.get_rid()])
	return _player.get_world_3d().direct_space_state.intersect_ray(query)


## Normale Statuszeile (wird laufend aktualisiert).
func _set_status(text: String, is_warning := false) -> void:
	if Time.get_ticks_msec() < _flash_until_msec or text == _status_text:
		return
	_status_text = text
	status_changed.emit(text, is_warning)


## Kurze Rückmeldung, die ein paar Sekunden stehen bleibt (z. B. "Sessel entfernt.").
func _flash_status(text: String) -> void:
	_flash_until_msec = 0
	_set_status(text)
	_flash_until_msec = Time.get_ticks_msec() + 2200
