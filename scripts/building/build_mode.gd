class_name BuildMode
extends Node
## Der Gestaltungsmodus: Möbel platzieren, verschieben, drehen, wegräumen,
## Wände streichen und Böden tauschen – alles in der Ego-Perspektive.
##
## Unten erscheint das Inventar (Inventory): nur Dinge, die mir gehören. Platzieren nimmt
## eins aus dem Inventar, Aufheben und Wegräumen (X) legen es wieder hinein.
##
## Öffnen und schließen mit Tab, schließen auch mit Esc.
## Zwei Zustände:
## - Katalog-Zustand: Mauszeiger sichtbar. Im Inventar wählen, ein platziertes
##   Möbelstück anklicken (= aufheben). Rechte Maustaste halten = umsehen.
## - Platzier-Zustand: Mauszeiger weg, die Vorschau folgt dem Blick.
##   Linksklick platziert, Rechtsklick legt zurück – danach wieder Katalog-Zustand.
## Die Oberfläche (Katalog, Tastenhilfe) steckt in BuildUI.

## Wird gesendet, wenn der Gestaltungsmodus an- oder ausgeht.
signal active_changed(active: bool)
## Neuer Hinweistext für die Statuszeile.
signal status_changed(text: String, is_warning: bool)
## Einrasten an/aus.
signal grid_changed(enabled: bool)
## Das gewählte Katalog-Element hat sich geändert (null = nichts gewählt).
signal selection_changed(selected: Resource)
## Katalog-Zustand (true) oder Platzier-Zustand (false).
signal catalog_state_changed(in_catalog: bool)
## Symbol in der Bildmitte: "" = normaler Punkt, "roller" = Farbroller, "carpet" = Teppich.
signal cursor_icon_changed(icon: String)

enum Tool { NONE, PLACE_NEW, MOVE, PAINT }

## Pfade zu Spielfigur und Raum (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath
@export var room_path: NodePath

@onready var _player: Player = get_node(player_path)
@onready var _room: Room = get_node(room_path)

var is_active: bool = false
var grid_enabled: bool = false

var _tool: Tool = Tool.NONE
var _selected_data: FurnitureData = null
var _selected_surface: SurfaceData = null
var _moving_item: PlacedFurniture = null
var _moving_extras: Array[PlacedFurniture] = []
## Drehung des Objekts relativ zur Blickrichtung (0 = Vorderseite zeigt zu mir).
var _rotation_offset: float = 0.0
var _hovered: PlacedFurniture = null
## Rechte Maustaste im Katalog-Zustand gedrückt = umsehen
var _is_looking := false
var _cursor_position_before_look := Vector2.ZERO

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
# Streichen: Maustaste gehalten und zuletzt gestrichene Stelle (für Ziehen)
var _paint_held := false
var _last_painted := ""
var _cursor_icon := ""
var _flash_until_msec := 0


func _ready() -> void:
	grid_enabled = GameConfig.grid_enabled_at_start
	_preview = FurniturePreview.new()
	_preview.name = "FurniturePreview"
	_preview.visible = false
	_room.add_child(_preview)
	_create_grid()


## Der Raum, der gerade gestaltet wird.
func get_room() -> Room:
	return _room


## Das gerade gewählte Inventar-Element (Möbel-Datenblatt, Oberfläche oder null).
func get_selected() -> Resource:
	if _selected_data:
		return _selected_data
	return _selected_surface


## Ist gerade der Katalog-Zustand aktiv (nichts in der Hand)?
func is_in_catalog_state() -> bool:
	return is_active and _tool == Tool.NONE


# --- Eingabe ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build_mode"):
		# Ist gerade etwas anderes offen (z. B. der Shop), bleibt der Gestaltungsmodus zu
		if not is_active and MenuStack.has_open():
			return
		set_active(not is_active)
		get_viewport().set_input_as_handled()
		return
	if not is_active:
		return

	if event.is_action_pressed("build_toggle_grid"):
		_set_grid_enabled(not grid_enabled)
	elif event.is_action_pressed("build_delete"):
		_delete_target()
	elif event.is_action_pressed("build_rotate"):
		_rotate(1.0)
	elif event.is_action_pressed("build_rotate_back"):
		_rotate(-1.0)
	elif event.is_action_pressed("build_place"):
		_on_primary_click()
	elif event.is_action_released("build_place"):
		_paint_held = false
	elif event.is_action_pressed("build_cancel"):
		_on_secondary_pressed()
	elif event.is_action_released("build_cancel"):
		_stop_looking()
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
			_update_paint()


# --- Öffnen und Schließen ---

func set_active(active: bool) -> void:
	if active == is_active:
		return
	is_active = active
	_player.interaction_enabled = not active
	if active:
		if _player.is_seated():
			_player.stand_up()  # Zum Gestalten erst aufstehen
		# Türen schließen sich – an ihnen hängt man Dinge auf, und der Raum ist wieder zu
		get_tree().call_group("doors", "close_instantly")
		MenuStack.open(self)
		_set_status("")
	else:
		MenuStack.close(self)
		_cancel_tool()
		_set_hovered(null)
		_is_looking = false
		SaveManager.request_save()
	_apply_mouse_mode()
	_update_grid_visibility()
	active_changed.emit(active)
	catalog_state_changed.emit(is_in_catalog_state())


## Esc: Gestaltungsmodus schließen (wird vom MenuStack aufgerufen).
## Was gerade in der Hand ist, wird zurückgelegt.
func close_from_escape() -> void:
	set_active(false)


## Nach dem Pausenmenü: passenden Mauszustand wiederherstellen.
func restore_mouse_mode() -> void:
	_is_looking = false
	_apply_mouse_mode()


## Katalog-Zustand = Mauszeiger sichtbar, sonst gefangen (zum Umsehen).
func _apply_mouse_mode() -> void:
	if is_active and _tool == Tool.NONE and not _is_looking:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Wird von der Katalog-Oberfläche aufgerufen.
func select_furniture(data: FurnitureData) -> void:
	_cancel_tool()
	if Inventory.get_count(data.get_id()) <= 0:
		_flash_status("%s: keins mehr im Inventar." % data.display_name)
		return
	_selected_data = data
	_tool = Tool.PLACE_NEW
	_rotation_offset = 0.0  # Vorderseite zeigt zu mir
	_preview.setup(data)
	_enter_placing_state()
	selection_changed.emit(data)


## Wird von der Katalog-Oberfläche aufgerufen.
func select_surface(surface: SurfaceData) -> void:
	_cancel_tool()
	_selected_surface = surface
	_tool = Tool.PAINT
	_enter_placing_state()
	selection_changed.emit(surface)


func _enter_placing_state() -> void:
	_set_hovered(null)
	_is_looking = false
	_apply_mouse_mode()
	catalog_state_changed.emit(false)


# --- Aktionen ---

func _on_primary_click() -> void:
	match _tool:
		Tool.NONE:
			if _hovered:
				_pick_up(_hovered)
		Tool.PLACE_NEW:
			if _placement_ok and Inventory.take_furniture(_selected_data.get_id()):
				_room.add_furniture(_selected_data, _placement_transform, _placement_support)
				var verb := "aufgehängt" if _selected_data.is_hanging() else "aufgestellt"
				_flash_status("%s %s." % [_selected_data.display_name, verb])
				_clear_tool()
		Tool.MOVE:
			if _placement_ok:
				Inventory.take_furniture(_moving_item.data.get_id())  # aus der Hand wieder in den Raum
				_room.move_furniture(_moving_item, _placement_transform, _placement_support)
				_flash_status("%s umgestellt." % _moving_item.data.display_name)
				_finish_move()
		Tool.PAINT:
			_paint_held = true
			_last_painted = ""
			_paint_at_target(Input.is_action_pressed("build_paint_all"))


## Rechte Maustaste: im Platzier-Zustand zurücklegen, im Katalog-Zustand umsehen.
func _on_secondary_pressed() -> void:
	if _tool != Tool.NONE:
		_cancel_tool()
		return
	_is_looking = true
	_cursor_position_before_look = get_viewport().get_mouse_position()
	_set_hovered(null)
	_apply_mouse_mode()


func _stop_looking() -> void:
	if not _is_looking:
		return
	_is_looking = false
	_apply_mouse_mode()
	# Mauszeiger dort wieder erscheinen lassen, wo er vor dem Umsehen war.
	# Gespeichert ist die Position im Spielbild (wegen der Skalierung für verschiedene
	# Auflösungen nicht gleich Fensterpixel) – warp_mouse erwartet aber Fensterpixel.
	var window_position := get_tree().root.get_final_transform() * _cursor_position_before_look
	Input.warp_mouse(window_position)


## Hebt ein platziertes Möbelstück auf, um es neu zu platzieren.
## In der Hand zählt es zum Inventar (die Anzahl steigt um eins).
func _pick_up(item: PlacedFurniture) -> void:
	_set_hovered(null)
	Inventory.add_furniture(item.data.get_id())
	_moving_item = item
	_moving_extras = _room.get_dependents(item)
	var extras: Array[Dictionary] = []
	var inverse := item.global_transform.affine_inverse()
	for extra in _moving_extras:
		extras.append({"data": extra.data, "transform": inverse * extra.global_transform})
	for piece: PlacedFurniture in [item] + _moving_extras:
		piece.set_collision_enabled(false)
		piece.visible = false
	# Bücher, die darauf liegen, verschwinden solange (sie wandern beim Abstellen mit)
	_room.loose_books.set_hidden_on(_room.get_uids(item, _moving_extras), true)
	# Die bisherige Ausrichtung bleibt relativ zu meinem Blick erhalten
	_rotation_offset = rad_to_deg(item.rotation.y) - _player_yaw_degrees()
	_preview.setup(item.data, extras)
	_preview.show_contents_of(item)  # z. B. die Bücher im Regal wandern sichtbar mit
	_tool = Tool.MOVE
	_enter_placing_state()
	selection_changed.emit(null)


## Stellt ein aufgehobenes Möbelstück wieder sichtbar hin.
func _finish_move() -> void:
	for piece: PlacedFurniture in [_moving_item] + _moving_extras:
		if is_instance_valid(piece):
			piece.set_collision_enabled(true)
			piece.visible = true
	if is_instance_valid(_moving_item):
		_room.loose_books.set_hidden_on(_room.get_uids(_moving_item, _moving_extras), false)
	_moving_item = null
	_moving_extras.clear()
	_clear_tool()


## Rechtsklick/Esc: Auswahl aufheben bzw. aufgehobenes Möbelstück an den alten Platz zurück.
func _cancel_tool() -> void:
	if _tool == Tool.MOVE:
		# Zurück an den alten Platz (die Position wurde nicht geändert) – also wieder aus
		# dem Inventar heraus
		Inventory.take_furniture(_moving_item.data.get_id())
		_finish_move()
	elif _tool != Tool.NONE:
		_clear_tool()


## Zurück in den Katalog-Zustand.
func _clear_tool() -> void:
	_tool = Tool.NONE
	_paint_held = false
	_set_cursor_icon("")
	_selected_data = null
	_selected_surface = null
	_preview.clear()
	_preview.visible = false
	_placement_visible = false
	_update_grid_visibility()
	_apply_mouse_mode()
	selection_changed.emit(null)
	catalog_state_changed.emit(is_in_catalog_state())


## Taste X: Was ich in der Hand halte bzw. worauf der Mauszeiger zeigt, wegräumen.
## Es kommt ins Inventar – samt allem, was darauf steht.
func _delete_target() -> void:
	if _tool == Tool.PLACE_NEW:
		# Neu ausgewählt und noch nicht aufgestellt: einfach zurück ins Inventar
		var item_name := _selected_data.display_name
		_clear_tool()
		_flash_status("%s zurück ins Inventar gelegt." % item_name)
	elif _tool == Tool.MOVE:
		# Das Möbelstück selbst zählt schon zum Inventar (seit dem Aufheben)
		var item := _moving_item
		_moving_item = null
		_moving_extras.clear()
		_store_in_inventory(item, false)
		_clear_tool()
	elif _tool == Tool.NONE and _hovered:
		var item := _hovered
		_set_hovered(null)
		_store_in_inventory(item, true)


## Räumt ein Möbelstück und alles, was darauf steht, ins Inventar.
func _store_in_inventory(item: PlacedFurniture, include_item: bool) -> void:
	var dependents := _room.get_dependents(item)
	if include_item:
		Inventory.add_furniture(item.data.get_id())
	for dependent in dependents:
		Inventory.add_furniture(dependent.data.get_id())
	var text := "%s ins Inventar gelegt." % item.data.display_name
	if not dependents.is_empty():
		var parts := "1 Teil" if dependents.size() == 1 else "%d Teile" % dependents.size()
		text = "%s und %s darauf ins Inventar gelegt." % [item.data.display_name, parts]
	_room.remove_furniture(item)
	_flash_status(text)


func _rotate(direction: float) -> void:
	if _tool != Tool.PLACE_NEW and _tool != Tool.MOVE:
		return
	if _preview.data and _preview.data.is_wall_mounted():
		return  # An Wand oder Tür richtet es sich nach der Fläche aus
	var step := GameConfig.rotation_step_grid if grid_enabled else GameConfig.rotation_step_free
	_rotation_offset = fposmod(_rotation_offset + step * direction, 360.0)


func _set_grid_enabled(enabled: bool) -> void:
	grid_enabled = enabled
	_update_grid_visibility()
	grid_changed.emit(enabled)
	_flash_status("Einrasten an" if enabled else "Einrasten aus")


# --- Zeigen und Prüfen ---

## Katalog-Zustand: Möbelstück unter dem Mauszeiger hervorheben.
func _update_hover() -> void:
	var item: PlacedFurniture = null
	if not _is_looking and get_viewport().gui_get_hovered_control() == null:
		var mouse := get_viewport().get_mouse_position()
		var camera := _player.camera
		var from := camera.project_ray_origin(mouse)
		var to := from + camera.project_ray_normal(mouse) * GameConfig.build_reach
		var hit := _ray(from, to, FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT)
		if not hit.is_empty():
			item = FurnitureUtils.find_placed_furniture(hit.collider)
	_set_hovered(item)
	if item:
		_set_status(item.data.display_name)
	elif not _is_looking:
		_set_status("")


func _set_hovered(item: PlacedFurniture) -> void:
	if item == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(false)
	_hovered = item
	if _hovered:
		_hovered.set_highlighted(true)


## Texte und Symbole je Art der Oberfläche
const _PAINT_TEXTS := {
	SurfaceData.Kind.WALL: {"icon": "roller", "one": "Wandabschnitt streichen", "all": "ganze Wand", "where": "eine Wand"},
	SurfaceData.Kind.FLOOR: {"icon": "carpet", "one": "Bodenabschnitt belegen", "all": "Fläche füllen", "where": "den Boden"},
	SurfaceData.Kind.CEILING: {"icon": "ceiling", "one": "Deckenabschnitt gestalten", "all": "Fläche füllen", "where": "die Decke"},
}


## Gestalten: Ziel suchen, Symbol zeigen und beim Ziehen mit gedrückter Maustaste weitermachen.
func _update_paint() -> void:
	var target := _find_paint_target()
	var texts: Dictionary = _PAINT_TEXTS[_selected_surface.kind]
	_set_cursor_icon("" if target.is_empty() else texts.icon)
	if _paint_held and not target.is_empty():
		_paint_at_target(false)
	if target.is_empty():
		_set_status("%s – %s anschauen" % [_selected_surface.display_name, texts.where])
	else:
		_set_status(_selected_surface.display_name)


## Wohin zeige ich? Ergebnis: { "wall": …, "index": … } bei Wänden, { "cell": … } bei
## Boden und Decke – leer, wenn dort nichts Passendes ist oder es zu weit weg ist.
func _find_paint_target() -> Dictionary:
	var hit := _ray_from_camera(FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT, GameConfig.paint_reach)
	if hit.is_empty():
		return {}
	match _selected_surface.kind:
		SurfaceData.Kind.WALL:
			if absf(hit.normal.y) > 0.5:
				return {}
			return _room.find_wall_segment(hit.position)
		SurfaceData.Kind.FLOOR:
			if hit.normal.y < 0.7:
				return {}
		SurfaceData.Kind.CEILING:
			if hit.normal.y > -0.7:
				return {}
	var cell := _room.find_grid_cell(_selected_surface.kind, hit.position)
	return {} if cell < 0 else {"cell": cell}


## Gestaltet die Stelle, auf die ich schaue. whole = ganze Wand bzw. bei Boden und Decke
## das Füllwerkzeug (alle zusammenhängenden Abschnitte mit gleichem Belag).
func _paint_at_target(whole: bool) -> void:
	var target := _find_paint_target()
	if target.is_empty():
		return
	var key := str(target.get("wall", "grid")) + ":" + str(target.get("index", target.get("cell")))
	if key == _last_painted:
		return  # diese Stelle wurde gerade schon gestaltet
	_last_painted = key
	if target.has("wall"):
		if whole:
			_room.paint_wall(target.wall, _selected_surface)
			_paint_held = false
		else:
			_room.paint_wall_segment(target.wall, target.index, _selected_surface)
	else:
		if whole:
			_room.fill_grid(target.cell, _selected_surface)
			_paint_held = false
		else:
			_room.paint_grid_cell(target.cell, _selected_surface)


func _set_cursor_icon(icon: String) -> void:
	if icon != _cursor_icon:
		_cursor_icon = icon
		cursor_icon_changed.emit(icon)


## Drehung in der Welt (Grad): Blickrichtung + eigene Drehung, beim Einrasten in 15°-Schritten.
func _placement_yaw_degrees() -> float:
	var yaw := _player_yaw_degrees() + _rotation_offset
	if grid_enabled:
		yaw = snappedf(yaw, GameConfig.rotation_step_grid)
	return fposmod(yaw, 360.0)


func _player_yaw_degrees() -> float:
	return rad_to_deg(_player.rotation.y)


## Berechnet, wo die Vorschau steht und ob das Möbelstück dort passt.
func _update_placement() -> void:
	var data := _preview.data
	_placement_visible = false
	_placement_ok = false
	_placement_support = null
	_placement_on_floor = false

	# Ablageflächen sind nur für Dinge sichtbar, die darauf stehen dürfen
	var mask := FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.FURNITURE_LAYER_BIT
	if data.allows(FurnitureData.PLACE_SURFACE):
		mask |= FurnitureUtils.SURFACE_LAYER_BIT
	var hit := _ray_from_camera(mask)

	var problem := ""
	var hang_kind := Room.HangKind.NONE
	if not hit.is_empty():
		hang_kind = _room.get_hang_kind(hit.collider)
	if not hit.is_empty() and hang_kind == Room.HangKind.CEILING and data.allows(hang_kind) \
			and hit.normal.y < -0.5:
		problem = _place_on_ceiling(hit)
	elif not hit.is_empty() and hang_kind != Room.HangKind.NONE and data.allows(hang_kind) \
			and absf(hit.normal.y) < 0.5:
		problem = _place_on_wall(hit)
	elif not hit.is_empty() and hit.normal.y > -0.5 and \
			(data.allows(FurnitureData.PLACE_FLOOR) or data.allows(FurnitureData.PLACE_SURFACE)):
		problem = _place_standing(hit)
	else:
		_preview.visible = false
		_update_grid_visibility()
		var where := "den Boden oder eine Ablage"
		if data.allows(FurnitureData.PLACE_CEILING):
			where = "die Decke"
		elif data.allows(FurnitureData.PLACE_WALL):
			where = "eine Wand"
		elif data.allows(FurnitureData.PLACE_DOOR):
			where = "die Tür"
		_set_status("%s – %s anschauen" % [data.display_name, where], true)
		return

	_placement_visible = true
	_preview.global_transform = _placement_transform
	_preview.visible = true
	_placement_ok = problem.is_empty()
	_preview.set_valid(_placement_ok)
	_update_grid_visibility()

	if _placement_ok:
		# Nur der Name (die Tasten stehen in der Tastenhilfe rechts)
		var name_text := data.display_name
		if _tool == Tool.PLACE_NEW:
			name_text += " ×%d" % Inventory.get_count(data.get_id())
		_set_status(name_text)
	else:
		_set_status("%s – %s" % [data.display_name, problem], true)


## Stehende Dinge: auf dem Boden oder auf einer Ablagefläche.
## Setzt _placement_transform und liefert einen Grund, falls es nicht passt.
func _place_standing(hit: Dictionary) -> String:
	var data := _preview.data
	var yaw := _placement_yaw_degrees()
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal

	# Zeigt man auf eine Wand oder eine Möbelseite, rückt die Vorschau davor
	if absf(normal.y) < 0.5:
		var half := _rotated_half_size(data, yaw)
		var flat := Vector3(normal.x, 0.0, normal.z).normalized()
		var reach := absf(flat.x) * half.x + absf(flat.z) * half.y
		point += flat * (reach + 0.01)

	# Von oben nach unten schauen: Worauf würde es stehen?
	var start_height: float = hit.position.y + 0.1
	var ground := _find_ground(point, start_height, data)
	# Auf dem Boden rastet es ein (wenn Einrasten an ist). Auf Ablagen nicht,
	# denn deren Fächer passen selten genau zum Raster des Raums.
	if grid_enabled and not ground.get("collider") is PlacementSurface:
		point = _snap_to_grid(point, data, yaw)
		ground = _find_ground(point, start_height, data)

	var surface_normal := Vector3.UP
	point.y = _room.floor_height
	var on_surface := false
	if not ground.is_empty():
		surface_normal = ground.normal
		if ground.collider is PlacementSurface:
			on_surface = true
			point.y = (ground.collider as PlacementSurface).get_surface_height()
			_placement_support = FurnitureUtils.find_placed_furniture(ground.collider)
		else:
			point.y = ground.position.y
	_placement_on_floor = not on_surface
	_placement_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), point)

	if not _room.is_inside_build_area(point):
		return "Das muss im Raum stehen."
	if not on_surface and not data.allows(FurnitureData.PLACE_FLOOR):
		return "Das gehört auf eine Ablage (Tisch, Regal, Sessel, Fensterbank)."
	if surface_normal.y < 0.7:
		return "Hier steht es nicht gerade."
	if on_surface:
		var problem := _check_surface_fit(ground.collider as PlacementSurface)
		if not problem.is_empty():
			return problem
	return _find_overlap(Vector3.UP, true)


## Passt es auf diese Ablage? Prüft die Höhe (z. B. bis zum nächsten Regalbrett) und im
## Bücherregal, ob dort Bücher stehen (Deko nur auf freie Stellen).
func _check_surface_fit(surface: PlacementSurface) -> String:
	_preview.global_transform = _placement_transform
	var corners := _preview.get_world_corners()
	if surface.max_height > 0.0:
		var top := -INF
		for corner in corners:
			top = maxf(top, corner.y)
		if top - surface.get_surface_height() > surface.max_height + 0.002:
			return "Zu hoch für dieses Fach."
	var shelf := BookShelf.find_for_surface(surface)
	if shelf and not shelf.is_free_for_deco(surface, corners):
		return "Hier stehen Bücher."
	return ""


## Hängende Dinge: an der Wand oder an der Tür. Die Rückseite liegt an der Fläche.
func _place_on_wall(hit: Dictionary) -> String:
	var normal: Vector3 = Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	var point: Vector3 = hit.position
	if grid_enabled:
		var cell := GameConfig.grid_cell_size
		point.y = snappedf(point.y, cell)
		# entlang der Wand einrasten
		if absf(normal.x) > absf(normal.z):
			point.z = snappedf(point.z, cell)
		else:
			point.x = snappedf(point.x, cell)
	point += normal * 0.002
	var yaw := atan2(normal.x, normal.z)
	_placement_transform = Transform3D(Basis(Vector3.UP, yaw), point)
	_placement_on_floor = false
	# Vor der Eingangstür darf etwas hängen – die Sperrzone gilt nur für den Boden
	return _find_overlap(normal, false)


## Deckenlampen: Der Aufhängepunkt (Ursprung) liegt an der Decke, die Lampe hängt nach unten.
## Drehen mit dem Mausrad geht wie bei stehenden Möbeln.
func _place_on_ceiling(hit: Dictionary) -> String:
	var point: Vector3 = hit.position
	if grid_enabled:
		var cell := GameConfig.grid_cell_size
		point.x = snappedf(point.x, cell)
		point.z = snappedf(point.z, cell)
	point.y -= 0.002
	_placement_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(_placement_yaw_degrees())), point)
	_placement_on_floor = false
	if not _room.is_inside_build_area(point):
		return "Das muss im Raum hängen."
	return _find_overlap(Vector3.DOWN, false)


## Prüft, ob die Vorschau etwas anderes berührt (leer = frei).
## lift: in diese Richtung wird etwas abgerückt, damit bloßes Anliegen erlaubt ist.
func _find_overlap(lift: Vector3, check_entrance: bool) -> String:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = FurnitureUtils.WORLD_LAYER_BIT | FurnitureUtils.PLAYER_LAYER_BIT \
		| FurnitureUtils.FURNITURE_LAYER_BIT
	if check_entrance:
		query.collision_mask |= FurnitureUtils.BUILD_BLOCKER_LAYER_BIT
	query.collide_with_areas = true
	_preview.global_transform = _placement_transform
	var shapes := _preview.get_shapes()
	for i in shapes.size():
		query.shape = _preview.get_shrunk_shape(i)
		query.transform = shapes[i].global_transform.translated(lift * FurniturePreview.SHRINK)
		for result in space.intersect_shape(query, 4):
			var other: Object = result.collider
			if other is Area3D:
				return "Bitte den Eingang frei lassen."
			if other is Player:
				return "Du stehst im Weg – geh ein Stück zur Seite."
			if FurnitureUtils.find_placed_furniture(other):
				return "Hier ist schon etwas."
			return "Zu nah an der Wand."
		# Ausgelegte Bücher haben keine Kollision – sie werden extra geprüft
		if _room.loose_books and _room.loose_books.overlaps_shape(query.shape, query.transform):
			return "Hier liegen Bücher."
	return ""


## Schaut senkrecht nach unten: Worauf würde das Ding hier stehen?
## Ablageflächen zählen nur für Dinge, die dort stehen dürfen.
func _find_ground(point: Vector3, start_height: float, data: FurnitureData) -> Dictionary:
	var mask := FurnitureUtils.WORLD_LAYER_BIT
	if data.allows(FurnitureData.PLACE_SURFACE):
		mask |= FurnitureUtils.SURFACE_LAYER_BIT
	var from := Vector3(point.x, start_height, point.z)
	return _ray(from, Vector3(point.x, _room.floor_height - 1.0, point.z), mask)


# --- Raster ---

## Rastet die Position ein. Steht das Möbelstück gerade (Vielfaches von 90°), liegen
## seine Kanten genau auf Rasterlinien; bei schrägen Winkeln rastet nur die Mitte ein.
func _snap_to_grid(point: Vector3, data: FurnitureData, yaw: float) -> Vector3:
	var quarter := roundf(yaw / 90.0)
	if absf(yaw - quarter * 90.0) > 0.5:
		var cell := GameConfig.grid_cell_size
		return Vector3(snappedf(point.x, cell), point.y, snappedf(point.z, cell))
	var cells := data.footprint
	if int(quarter) % 2 == 1:
		cells = Vector2i(cells.y, cells.x)
	return Vector3(_snap_axis(point.x, cells.x), point.y, _snap_axis(point.z, cells.y))


## Halbe Grundfläche in Metern (x, z) nach dem Drehen.
func _rotated_half_size(data: FurnitureData, yaw: float) -> Vector2:
	var size := data.get_footprint_size()
	var angle := deg_to_rad(yaw)
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

func _ray_from_camera(mask: int, reach: float = GameConfig.build_reach) -> Dictionary:
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * reach
	return _ray(from, to, mask)


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [_player.get_rid()])
	# Ablageflächen sind Area3D-Knoten und werden nur so gefunden
	query.collide_with_areas = (mask & FurnitureUtils.SURFACE_LAYER_BIT) != 0
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
