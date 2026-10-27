class_name CatalogShowroom
extends Node3D
## Übersichts-Szene des Möbelkatalogs (seit Etappe 6): alle Objekte aus dem Shop, aufgereiht nach
## Stil (je Stil eine Reihe, zuletzt die stilneutralen) und Kategorie, mit Namensschild davor.
## Stehendes steht auf dem Boden, kleine Deko auf einem Sockel, Wanddinge hängen an einer Wand
## hinter der Reihe, Deckenlampen an einem Balken darüber.
##
## Ansehen: Szene scenes/tools/catalog_showroom.tscn öffnen und mit F6 starten (Kamera mit der
## Maus: rechte Taste halten und ziehen, Mausrad = näher/weiter; Pfeiltasten = Reihe wechseln).
## Testbilder: tools/screenshots.sh catalog --scene=res://scenes/tools/catalog_showroom.tscn
## Mit dem Zusatz --variants (nach "--") stehen hinter jedem Objekt alle seine Farben.

const ROW_GAP := 7.0  ## Abstand der Stil-Reihen (m)
const ITEM_GAP := 0.45  ## Luft zwischen zwei Objekten
const WALL_BACK := 2.2  ## Wand hinter der Reihe
const BEAM_BACK := 1.1  ## Balken für Deckenlampen
const BEAM_HEIGHT := 2.7
const PLINTH_HEIGHT := 0.62
const VARIANT_GAP := 1.3

var _camera: Camera3D
var _row := 0
var _yaw := 0.0
var _pitch := -18.0
var _distance := 7.0


func _ready() -> void:
	SaveManager.saving_enabled = false
	_build_environment()
	var show_variants := OS.get_cmdline_user_args().has("--variants")
	for entry in plan(show_variants):
		_place(entry)
	for group in groups():
		_add_row_scenery(group)
	if get_viewport().get_camera_3d() == null:
		_camera = Camera3D.new()
		add_child(_camera)
		_camera.make_current()
		_update_camera()


## Gruppen in Anzeige-Reihenfolge: die Stile aus data/styles/, dann "" = stilneutral.
static func groups() -> Array[String]:
	var result: Array[String] = StyleTags.ids()
	result.append("")
	return result


static func group_name(group: String) -> String:
	return StyleTags.get_display_name(group) if not group.is_empty() else "Stilneutral"


## Alle Objekte aus dem Shop (ohne Fest-Eingebautes) in Anzeige-Reihenfolge.
static func items_of(group: String) -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	for data in Catalog.get_all_furniture():
		if not data.is_unlocked or data.is_essential or data.is_fixed:
			continue
		var styles := StyleTags.known(data.style_ids)
		var key := styles[0] if not styles.is_empty() else ""
		if key == group:
			result.append(data)
	result.sort_custom(func(a: FurnitureData, b: FurnitureData) -> bool:
		if a.category != b.category:
			return a.category < b.category
		if a.subcategory != b.subcategory:
			return a.subcategory < b.subcategory
		return a.price < b.price)
	return result


## Wo was steht: Liste von { data, variant, kind ("floor", "plinth", "wall", "ceiling"),
## pos (Vector3), group, width }.
static func plan(show_variants: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gi := 0
	for group in groups():
		var z := -gi * ROW_GAP * (2.4 if show_variants else 1.0)
		var x_floor := 0.0
		var x_wall := 0.0
		var x_ceiling := 0.0
		for data in items_of(group):
			var size := _size_of(data)
			var kind := "floor"
			if data.allows(FurnitureData.PLACE_CEILING) and not data.allows(FurnitureData.PLACE_FLOOR):
				kind = "ceiling"
			elif data.is_wall_mounted() and not data.allows(FurnitureData.PLACE_FLOOR):
				kind = "wall"
			elif not data.allows(FurnitureData.PLACE_FLOOR):
				kind = "plinth"
			var width := maxf(size.x, 0.25)
			var pos := Vector3.ZERO
			match kind:
				"wall":
					pos = Vector3(x_wall + width / 2.0, 1.55, z - WALL_BACK)
					x_wall += width + ITEM_GAP
				"ceiling":
					pos = Vector3(x_ceiling + width / 2.0, BEAM_HEIGHT, z - BEAM_BACK)
					x_ceiling += width + ITEM_GAP * 2.0
				_:
					pos = Vector3(x_floor + width / 2.0, PLINTH_HEIGHT if kind == "plinth" else 0.0, z)
					x_floor += maxf(width, 0.5 if kind == "plinth" else 0.0) + ITEM_GAP
			var variants: Array[String] = [""]
			if show_variants and data.has_variants():
				variants.clear()
				for variant in data.color_variants:
					variants.append(variant.id)
			for vi in variants.size():
				var p := pos
				if vi > 0 and kind != "ceiling":
					p += Vector3(0, 0, -VARIANT_GAP * vi) if kind != "wall" else Vector3(0, 0.0, 0)
				if kind == "wall" and vi > 0:
					continue
				result.append({"data": data, "variant": variants[vi], "kind": kind, "pos": p, "group": group, "width": width})
		gi += 1
	return result


## Breite x Tiefe x Höhe eines Modells (gemessen, einmal je Datenblatt).
static var _sizes := {}


static func _size_of(data: FurnitureData) -> Vector3:
	var id := data.get_id()
	if not _sizes.has(id):
		var model := FurnitureUtils.instantiate_model(data)
		_sizes[id] = FurnitureUtils.get_local_aabb(model).size
		model.free()
	return _sizes[id]


## Länge einer Reihe (für die Kamera).
static func row_length(group: String) -> float:
	var length := 0.0
	for entry in plan():
		if entry.group == group:
			length = maxf(length, entry.pos.x + entry.width / 2.0)
	return length


## Blickpunkte für die Testbilder: je Stil ein Überblick und Ausschnitte von etwa 4 m.
static func views() -> Dictionary:
	var result := {}
	var gi := 0
	for group in groups():
		var z := -gi * ROW_GAP
		var length := row_length(group)
		var slug := group if not group.is_empty() else "neutral"
		result["%s_all" % slug] = {"pos": Vector3(length / 2.0, 3.2, z + maxf(4.5, length * 0.55)),
			"target": Vector3(length / 2.0, 0.6, z - 1.0)}
		var x := 0.0
		var part := 1
		while x < length:
			var mid := x + 2.0
			result["%s_%d" % [slug, part]] = {"pos": Vector3(mid, 1.7, z + 3.3), "target": Vector3(mid, 0.8, z - 0.9)}
			x += 4.0
			part += 1
		gi += 1
	return result


## Nahaufnahme je Objekt (Name = id): schräg von vorn, Abstand nach Größe.
static func item_views() -> Dictionary:
	var result := {}
	for entry in plan():
		var data: FurnitureData = entry.data
		var size := _size_of(data)
		var reach := maxf(maxf(size.x, size.y), size.z * 0.8) * 1.6 + 0.6
		var center: Vector3 = entry.pos + Vector3(0, size.y * 0.45, 0)
		if entry.kind == "ceiling":
			center = entry.pos - Vector3(0, size.y * 0.5, 0)
		elif entry.kind == "wall":
			center = entry.pos
		result[data.get_id()] = {"pos": center + Vector3(reach * 0.45, reach * 0.35, reach), "target": center}
	return result


func _place(entry: Dictionary) -> void:
	var data: FurnitureData = entry.data
	var model := FurnitureUtils.instantiate_model(data, entry.variant)
	add_child(model)
	model.position = entry.pos
	if entry.kind == "plinth":
		var plinth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(maxf(entry.width + 0.12, 0.42), PLINTH_HEIGHT, 0.5)
		plinth.mesh = box
		plinth.material_override = _flat_material(Color(0.86, 0.8, 0.7))
		plinth.position = entry.pos - Vector3(0, PLINTH_HEIGHT / 2.0, 0)
		add_child(plinth)
	if entry.variant.is_empty() or entry.variant == data.resolve_variant(""):
		var label := Label3D.new()
		label.text = data.display_name
		label.font_size = 26
		label.pixel_size = 0.0022
		label.modulate = Color(0.25, 0.18, 0.12)
		label.outline_size = 0
		label.rotation_degrees.x = -70.0
		label.position = Vector3(entry.pos.x, 0.012, entry.pos.z + 0.75) if entry.kind != "wall" else \
			Vector3(entry.pos.x, 0.012, entry.pos.z + 0.55)
		if entry.kind == "ceiling":
			label.position = Vector3(entry.pos.x, 0.012, entry.pos.z + 0.4)
		label.width = 260.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)


func _add_row_scenery(group: String) -> void:
	var gi := groups().find(group)
	var z := -gi * ROW_GAP
	var length := maxf(row_length(group), 4.0)
	# Wand hinter der Reihe
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length + 1.0, 3.0, 0.1)
	wall.mesh = box
	wall.material_override = _flat_material(Color(0.9, 0.84, 0.72))
	wall.position = Vector3(length / 2.0, 1.5, z - WALL_BACK - 0.05)
	add_child(wall)
	# Balken für Deckenlampen
	var beam := MeshInstance3D.new()
	var beam_box := BoxMesh.new()
	beam_box.size = Vector3(length + 1.0, 0.12, 0.16)
	beam.mesh = beam_box
	beam.material_override = _flat_material(Color(0.42, 0.3, 0.2))
	beam.position = Vector3(length / 2.0, BEAM_HEIGHT + 0.06, z - BEAM_BACK)
	add_child(beam)
	# Name der Reihe groß an der Wand
	var title := Label3D.new()
	title.text = group_name(group)
	title.font_size = 64
	title.pixel_size = 0.004
	title.modulate = Color(0.3, 0.2, 0.14)
	title.position = Vector3(-0.6, 2.4, z - WALL_BACK + 0.01)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(title)


func _build_environment() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.55, 0.68, 0.85)
	sky_material.ground_bottom_color = Color(0.35, 0.3, 0.25)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-52, 32, 0)
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _flat_material(Color(0.62, 0.48, 0.34))
	add_child(floor_mesh)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


# --- Umsehen (nur beim Starten mit F6) ---

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.3
		_pitch = clampf(_pitch - event.relative.y * 0.3, -80.0, 10.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.0, _distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(40.0, _distance * 1.1)
	elif event.is_action_pressed("ui_up"):
		_row = maxi(0, _row - 1)
	elif event.is_action_pressed("ui_down"):
		_row = mini(groups().size() - 1, _row + 1)
	_update_camera()


func _update_camera() -> void:
	var group := groups()[_row]
	var center := Vector3(row_length(group) / 2.0, 0.8, -_row * ROW_GAP)
	var offset := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)) * Vector3(0, 0, _distance)
	_camera.position = center + offset
	_camera.look_at(center)
