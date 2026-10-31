class_name LibraryFacade
extends Node3D
## Die Fassade der Bücherei aus Bausteinen (seit Etappe 6b, Fenster und Türen seit Etappe 6c) – je nach
## Wahl (FacadeDesign, Datenblätter data/facade/).
##
## - Kern (assets/models/facade/core.glb, Blender): Dach, Gesimse, Sockel, Laternen, Schild-Balken mit den
##   Schildern, Ankerpunkte für Markisen und Ampeln.
## - Erdgeschoss: Holzfront (ground_*.glb, die Felder um Fenster und Tür bleiben frei) oder Mauerwerk
##   (hier gebaut, Material der Wand bzw. Naturstein).
## - Obergeschoss: Mauerwerk rundherum, hier gebaut – mit Löchern genau in der Form der gewählten Fenster.
## - Fenster und Türumrahmung: WindowUnit aus dem Umriss (FacadeLayout) – Wandausschnitt, Rahmen, Glas,
##   Gardinen passen immer zusammen. Dazu Fensterbänke, Stürze, Bögen, Ecksteine, die Briefkasten-Platte.
## - Markisen, Kästen, Ampeln an Ankerpunkten; Pflanzen aus der gewählten Mischung; Deko vor der Tür.
## - Rollen-Flächen der Modelle werden gefärbt bzw. ersetzt: facade_paint (+ _dark) = Anstrich unten,
##   facade_frame = Fensterrahmen, facade_upper_wall = Wand, facade_stone = Naturstein, facade_awning =
##   Markisenstoff, facade_quoin = Ecksteine, facade_fascia = Schild-Balken.
## - follow_design = true (die echte Fassade im Raum): folgt FacadeDesign, passt die Wandlöcher, die
##   Innenfarbe und die Fensterbänke des Ladens an und gibt Türblatt und Türfarbe an die Ladentür. Für
##   Vorschauen (Polaroid in der App) false lassen und build(wahl) aufrufen.
## Sicherheitsnetz: Fehlt ein Teil (z. B. eine Datei konnte nicht geladen werden), setzt die Fassade an
## seiner Stelle das Standardteil ein – es gibt immer eine vollständige, geschlossene Fassade.

const CORE_PATH := "res://assets/models/facade/core.glb"
const PLANT_FOLDER := "res://scenes/world/plants/"
## Große Kübel der Deko vor der Tür: Sträucher und Bäumchen
const TUB_PLANTS: Array[String] = ["pot_boxball", "pot_olive", "pot_bush", "pot_cone", "tubtree_bay", "pot_hydrangea", "pot_lavender"]
const MATERIALS := {
	"paint": "res://assets/materials/storybook/facade_paint.tres",
	"frame": "res://assets/materials/storybook/facade_frame.tres",
	"wall": "res://assets/materials/storybook/facade_upper_wall.tres",
	"quoin": "res://assets/materials/storybook/facade_quoin.tres",
	"glass": "res://assets/materials/storybook/glas.tres",
	"curtain": "res://assets/materials/storybook/vorhang_leinen.tres",
	"room": "res://assets/materials/storybook/zimmer_warm_1.tres",
	"trim": "res://assets/materials/storybook/sandstein.tres",
	"zinc": "res://assets/materials/storybook/zink.tres",
}
## Platz je Pflanze im Blumenkasten bei Fülle 1 (Meter)
const BOX_PLANT_STEP := 0.27
## Pflanzen etwas größer als ihr Platz (quellen über den Rand)
const PLANT_OVERFLOW := 1.1
## Dicke der Mauer-Haut im Erdgeschoss (vor der Ladenwand) und der Wand oben
const SKIN := 0.06
const UPPER_THICKNESS := 0.3
## Bereiche um Fenster und Tür, die die Holzfront frei lässt (halbe Breite um die Mitte)
const SHOP_ZONE_HALF := 1.3
const DOOR_ZONE_HALF := 0.82

## Folgt FacadeDesign (echte Fassade) oder wird von außen gebaut (Vorschau).
@export var follow_design := true
## Die Ladentür (nur bei follow_design): bekommt Türblatt und Türfarbe.
@export var door_path: NodePath = ^"../Door"

## Die gerade gebaute Wahl (Kategorie -> id).
var config: Dictionary = {}

var _built := false
var _scenes := {}  # Pfad -> PackedScene
static var _paints := {}  # Schlüssel -> eingefärbtes Material
static var _swaying := {}  # Netz (id) -> Netz mit Wind-Markierung


func _notification(what: int) -> void:
	# Schon beim Einhängen bauen: Dann ist der Pflanzplatz am Kern da, bevor Greenery sucht
	if what == NOTIFICATION_PARENTED and not _built and not Engine.is_editor_hint():
		build(FacadeDesign.config if follow_design else FacadeDesign.DEFAULTS)


func _ready() -> void:
	if Engine.is_editor_hint() or not follow_design:
		return
	FacadeDesign.changed.connect(func() -> void: build(FacadeDesign.config))
	_apply_door()
	_apply_room()


## Baut die Fassade nach dieser Wahl (fehlende Kategorien: Standard).
func build(new_config: Dictionary) -> void:
	config = FacadeDesign.normalized(new_config)
	_built = true
	var openings := FacadeLayout.openings(config)
	_set_part("Core", CORE_PATH, CORE_PATH)
	_build_ground(openings)
	_build_upper(openings)
	_build_openings(openings)
	_build_quoins()
	_place_at_anchors("Awnings", "Anchor_awning_", _scene_of("awning") if not _shop_bay() else "")
	_let_awnings_sway()
	_place_at_anchors("Boxes", "Anchor_box_", _scene_of("box"))
	_place_at_anchors("Baskets", "Anchor_basket_", _scene_of("basket"))
	_set_part("Deco", _scene_of("deco"), "")
	_deco_obstacles()
	_apply_materials(self)
	_plant_all()
	if follow_design and is_inside_tree():
		_apply_door()
		_apply_room()


func option(category: String) -> FacadeOption:
	return FacadeDesign.get_option(category, config)


func _scene_of(category: String) -> String:
	var chosen := option(category)
	return chosen.scene_path if chosen else ""


func _shop_bay() -> bool:
	var shop := option("window_ground")
	return shop != null and shop.bay_depth > 0.0


# --- Teile ---

## Ein Teil (Modell) einsetzen bzw. tauschen; fehlt die Datei, das Ersatzteil fallback.
func _set_part(part_name: String, path: String, fallback: String) -> void:
	if not path.is_empty() and not ResourceLoader.exists(path):
		push_warning("Fassade: %s fehlt (%s) – Ersatzteil." % [part_name, path])
		path = fallback
	var old := get_node_or_null(part_name)
	if old and old.scene_file_path == path and not path.is_empty():
		return
	_drop(part_name)
	var model := _instantiate(path)
	if model == null and not fallback.is_empty() and fallback != path:
		model = _instantiate(fallback)
	if model:
		model.name = part_name
		add_child(model)


func _drop(part_name: String) -> void:
	var old := get_node_or_null(part_name)
	if old:
		remove_child(old)
		old.free()


## Ein frischer Knoten für gebaute Teile (alter wird ersetzt).
func _holder(part_name: String) -> Node3D:
	_drop(part_name)
	var holder := Node3D.new()
	holder.name = part_name
	add_child(holder)
	return holder


func _instantiate(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var packed := _scenes[path] as PackedScene
	return packed.instantiate() as Node3D if packed else null


## An jeden Ankerpunkt (Name beginnt mit prefix) ein Modell hängen – alles unter einem Knoten holder.
func _place_at_anchors(holder_name: String, prefix: String, path: String) -> void:
	_drop(holder_name)
	if path.is_empty():
		return
	var holder := _holder(holder_name)
	var anchors: Array[Node] = []
	for part_name in ["Core", "Openings"]:
		var part := get_node_or_null(part_name)
		if part:
			anchors.append_array(part.find_children(prefix + "*", "", true, false))
	for anchor: Node in anchors:
		var model := _instantiate(path)
		if model:
			model.transform = _relative(anchor as Node3D)
			holder.add_child(model)


## Markisen bewegen sich im Wind wie bei den anderen Läden: Der Stoff bekommt im Alpha der Vertex-Farbe,
## wie frei er schwingt (1 = fest am Kasten, zur Vorderkante hin frei; Shader-Wert wind_strength im Stoff).
func _let_awnings_sway() -> void:
	var holder := get_node_or_null("Awnings")
	if holder == null:
		return
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var key := mi.mesh.get_instance_id()
		if not _swaying.has(key):
			_swaying[key] = _with_wind(mi.mesh as ArrayMesh, mi.transform)
		mi.mesh = _swaying[key]


## Kopie eines Netzes, deren Stoff-Flächen (Material facade_awning) die Wind-Markierung tragen.
static func _with_wind(source: ArrayMesh, node_xform: Transform3D) -> Mesh:
	if source == null:
		return source
	var result := ArrayMesh.new()
	for i in source.get_surface_count():
		var arrays := source.surface_get_arrays(i)
		var material := source.surface_get_material(i)
		if material and material.resource_name == "facade_awning":
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var old: Variant = arrays[Mesh.ARRAY_COLOR]
			var colors := PackedColorArray()
			colors.resize(verts.size())
			for k in verts.size():
				# Im Rahmen der Markise: z = Abstand von der Wand, y = wie weit unter dem Kasten
				var v := node_xform * verts[k]
				var free := clampf(v.z / 0.9 + maxf(-v.y, 0.0) * 0.6, 0.0, 1.0)
				var tint: Color = (old as PackedColorArray)[k] if old is PackedColorArray and (old as PackedColorArray).size() == verts.size() else Color.WHITE
				colors[k] = Color(tint.r, tint.g, tint.b, 1.0 - pow(free, 1.3))
			arrays[Mesh.ARRAY_COLOR] = colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(i, material)
	return result


## Lage eines Knotens relativ zur Fassade (geht auch, solange sie noch nicht im Baum ist).
func _relative(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


## Deko vor der Tür: Passanten gehen um Bank, Kübel und Aufsteller herum (leere Objekte „Obstacle_<cm>“ im
## Modell → StreetObstacle). Nur die echte Fassade – Vorschauen dürfen das Straßenleben nicht stören.
func _deco_obstacles() -> void:
	var deco := get_node_or_null("Deco")
	if not follow_design:
		return
	if deco:
		for node in deco.find_children("Obstacle_*", "", true, false):
			var obstacle := StreetObstacle.new()
			obstacle.radius = float(String(node.name).get_slice("_", 1).to_int()) / 100.0
			(node as Node).add_child(obstacle)
	if is_inside_tree():
		var life := get_tree().get_first_node_in_group(StreetLife.GROUP)
		if life and life.has_method("refresh_static_obstacles"):
			life.call_deferred("refresh_static_obstacles")


# --- Erdgeschoss und Wand oben ---

func _build_ground(openings: Array[Dictionary]) -> void:
	var ground := option("ground")
	var wood := ground != null and ground.family == "wood"
	if wood:
		_set_part("Ground", ground.scene_path, "")
	else:
		_drop("Ground")
	var holder := _holder("GroundSkin")
	var masonry := _ground_material()
	var paint := _paint_of("ground_color", MATERIALS.paint)
	for segment in ["front", "diag", "left"]:
		var length := FacadeLayout.segment_length(segment)
		var holes := _holes_on(openings, segment, ["shop", "door"])
		var mesh := OpeningMesh.new()
		if wood:
			# Holzfront: nur die freien Felder um Fenster und Tür, als gestrichene Platte mit Loch
			for zone: Rect2 in _wood_zones(openings, segment):
				var zone_holes := holes.filter(func(h: PackedVector2Array) -> bool: return OpeningShape.bounds(h).intersects(zone))
				mesh.slab(_rect(zone), 0.0, SKIN, zone_holes)
			_add(holder, mesh, paint, segment)
		else:
			# an den Ecken etwas über das Wandende hinaus (die Haut steht vor der Wand – sonst klafft eine Kerbe)
			var face := _rect(Rect2(-0.03 if segment != "front" else 0.0, FacadeLayout.GROUND, length + 0.06 - (0.03 if segment == "front" else 0.0),
				FacadeLayout.FASCIA_BOTTOM + 0.04 - FacadeLayout.GROUND))
			mesh.slab(face, 0.0, SKIN, holes)
			_add(holder, mesh, masonry, segment)
	if not wood:
		_slot_board(holder, masonry)


## Wand oben: Mauerwerk auf allen fünf Seiten, Löcher in der Form der Fenster.
func _build_upper(openings: Array[Dictionary]) -> void:
	var holder := _holder("UpperWalls")
	var material := _material_of("wall", MATERIALS.wall)
	for segment: String in FacadeLayout.SEGMENT_INDEX:
		var length := FacadeLayout.segment_length(segment)
		var holes := _holes_on(openings, segment, ["upper"])
		var mesh := OpeningMesh.new()
		mesh.slab(_rect(Rect2(-0.002, FacadeLayout.TOP - 0.02, length + 0.004, FacadeLayout.EAVES + 0.2 - FacadeLayout.TOP)),
			-UPPER_THICKNESS, 0.0, holes)
		_add(holder, mesh, material, segment)


## Löcher der Öffnungen einer Wand (Wand-Koordinaten).
func _holes_on(openings: Array[Dictionary], segment: String, kinds: Array) -> Array:
	var holes := []
	for o: Dictionary in openings:
		if o.segment == segment and kinds.has(o.kind):
			holes.append(FacadeLayout.outline_on_wall(o))
	return holes


## Freie Felder der Holzfront auf einer Wand (um die Schaufenster und die Tür).
func _wood_zones(openings: Array[Dictionary], segment: String) -> Array[Rect2]:
	var zones: Array[Rect2] = []
	for o: Dictionary in openings:
		if o.segment != segment:
			continue
		var half := SHOP_ZONE_HALF if o.kind == "shop" else (DOOR_ZONE_HALF if o.kind == "door" else 0.0)
		if half > 0.0:
			zones.append(Rect2(o.u - half, FacadeLayout.GROUND, half * 2.0, FacadeLayout.FASCIA_BOTTOM + 0.02 - FacadeLayout.GROUND))
	return zones


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Netz in Wand-Koordinaten an seine Wand setzen.
func _add(holder: Node3D, mesh: OpeningMesh, material: Material, segment: String, node_name: String = "") -> MeshInstance3D:
	var mi := mesh.instance(material, node_name if not node_name.is_empty() else segment.capitalize())
	mi.transform = FacadeLayout.segment_frame(segment)
	holder.add_child(mi)
	return mi


## Briefkasten-Platte auf dem Mauerwerk (Holzfronten haben sie im Modell).
func _slot_board(holder: Node3D, material: Material) -> void:
	var board := OpeningMesh.new()
	var size := FacadeLayout.SLOT_BOARD
	# Platte von der Wand bis genau zur Montageebene des Einwurfs (GameConfig.facade_slot_out vor der Wand)
	board.box(Vector3(FacadeLayout.SLOT_U, FacadeLayout.SLOT_Y, GameConfig.facade_slot_out / 2.0),
		Vector3(size.x, size.y, GameConfig.facade_slot_out), 0.008)
	_add(holder, board, load(MATERIALS.trim), "diag", "SlotBoard")
	var frame := OpeningMesh.new()
	var r := Rect2(FacadeLayout.SLOT_U - size.x / 2.0 - 0.03, FacadeLayout.SLOT_Y - size.y / 2.0 - 0.03, size.x + 0.06, size.y + 0.06)
	frame.ring(_rect(r), _rect(r.grow(-0.035)), SKIN - 0.01, GameConfig.facade_slot_out + 0.012)
	_add(holder, frame, _paint_of("ground_color", MATERIALS.paint), "diag", "SlotFrame")


# --- Fenster, Tür, Zierteile ---

func _build_openings(openings: Array[Dictionary]) -> void:
	var holder := _holder("Openings")
	var shop_frame := _paint_of("ground_color", MATERIALS.paint)
	var upper_frame := _paint_of("frame_color", MATERIALS.frame)
	var common := {"glass": load(MATERIALS.glass), "curtain": load(MATERIALS.curtain), "room": load(MATERIALS.room),
		"trim": load(MATERIALS.trim), "zinc": load(MATERIALS.zinc)}
	var ground := option("ground")
	var wood := ground != null and ground.family == "wood"
	var k := 0
	for o: Dictionary in openings:
		var materials := common.duplicate()
		materials.frame = upper_frame if o.kind == "upper" else shop_frame
		var unit: Node3D
		if o.kind == "door":
			unit = WindowUnit.build_door_surround(o, materials)
		else:
			unit = WindowUnit.build_window(o, materials)
		unit.transform = FacadeLayout.opening_frame(o)
		holder.add_child(unit)
		var trims := OpeningMesh.new()
		_trims(trims, o, wood)
		var trim_material: Material = shop_frame if (wood and o.kind != "upper") else common.trim
		var ti := trims.instance(trim_material, "Trims")
		unit.add_child(ti)
		if o.kind == "upper":
			k += 1
			# Blumenkasten-Anker unter dem Fenster (beim Erker vor seinem Sockel)
			var style: FacadeOption = o.style
			var anchor := Node3D.new()
			anchor.name = "Anchor_box_%d" % k
			var low := WindowUnit.height_at(o.outline, 0.0).x if style.shape == "round" else 0.0
			anchor.position = Vector3(0.0, low - 0.16 if style.bay_depth > 0.0 else low + 0.14, style.bay_depth + 0.04 if style.bay_depth > 0.0 else 0.2)
			unit.add_child(anchor)


## Zierteile außen um eine Öffnung: Fensterbank, Sturz bzw. Bogensteine (Mauerwerk) oder Leiste und
## Brüstungsfeld (Holzfront). Im Rahmen der Öffnung.
func _trims(mesh: OpeningMesh, o: Dictionary, wood: bool) -> void:
	var outline: PackedVector2Array = o.outline
	var b := OpeningShape.bounds(outline)
	var style: FacadeOption = o.style
	var front := SKIN if o.kind != "upper" else 0.0
	if o.kind == "door":
		if not wood:
			_arch_stones(mesh, outline, front, 0.16)
		return
	if style.bay_depth > 0.0:
		return
	if wood:
		# Profilleiste um das Fenster und ein Brüstungsfeld darunter
		var band := OpeningShape.offset(outline, 0.07)
		mesh.ring(band, outline, front, front + 0.035)
		mesh.box(Vector3(0.0, -0.05, front + 0.07), Vector3(b.size.x + 0.26, 0.07, 0.14), 0.015)
		if b.position.y - FacadeLayout.GROUND > 0.5:
			var field := Rect2(-b.size.x / 2.0 + 0.15, FacadeLayout.GROUND + 0.18 - o.bottom, b.size.x - 0.3, o.bottom - FacadeLayout.GROUND - 0.42)
			if field.size.y > 0.15:
				mesh.ring(_rect(field), _rect(field.grow(-0.05)), front, front + 0.03)
		return
	# Mauerwerk: Steinbank unter dem Fenster, oben Sturz mit Schlussstein bzw. Bogensteine
	var low := WindowUnit.height_at(outline, 0.0).x
	var sill_w := b.size.x + 0.16 if style.shape != "round" else b.size.x * 0.55
	mesh.box(Vector3(0.0, low - 0.045, front + 0.05), Vector3(sill_w, 0.09, 0.12), 0.015)
	match style.shape:
		"rect":
			mesh.box(Vector3(0.0, b.end.y + 0.08, front + 0.025), Vector3(b.size.x + 0.22, 0.16, 0.06), 0.012)
			mesh.box(Vector3(0.0, b.end.y + 0.09, front + 0.04), Vector3(0.16, 0.2, 0.08), 0.015)
		_:
			_arch_stones(mesh, outline, front, 0.14 if o.kind == "upper" else 0.18)


## Bogensteine rund um den oberen Teil einer Öffnung (bzw. ganz herum beim Rundfenster).
func _arch_stones(mesh: OpeningMesh, outline: PackedVector2Array, front: float, depth: float) -> void:
	var b := OpeningShape.bounds(outline)
	var round := absf(b.size.x - b.size.y) < 0.02 and outline.size() > 30
	var outer := OpeningShape.offset(outline, depth)
	var spring := b.end.y - b.size.x / 2.0 if not round else b.position.y - 1.0
	# Ring um die Öffnung oberhalb des Kämpfers, in einzelne Steine geteilt (kleine Fugen)
	var ring_top := PackedVector2Array([Vector2(-10.0, spring), Vector2(10.0, spring), Vector2(10.0, 20.0), Vector2(-10.0, 20.0)])
	var count := 9 if not round else 12
	var center := Vector2(0.0, spring if not round else b.get_center().y)
	for i in count:
		var a0 := (PI * i / count) if not round else (TAU * i / count)
		var a1 := (PI * (i + 1) / count) if not round else (TAU * (i + 1) / count)
		var wedge := PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * 9.0, center + Vector2(cos((a0 + a1) / 2.0),
			sin((a0 + a1) / 2.0)) * 9.0, center + Vector2(cos(a1), sin(a1)) * 9.0])
		wedge = OpeningShape.offset(wedge, -0.006)
		for stone: PackedVector2Array in Geometry2D.intersect_polygons(wedge, outer):
			for piece: PackedVector2Array in Geometry2D.clip_polygons(stone, outline):
				if Geometry2D.is_polygon_clockwise(piece):
					continue
				if not round:
					for top: PackedVector2Array in Geometry2D.intersect_polygons(piece, ring_top):
						if not Geometry2D.is_polygon_clockwise(top):
							mesh.slab(top, front, front + 0.045)
				else:
					mesh.slab(piece, front, front + 0.045)


## Ecksteine an den Ecken oben (und unten beim Mauerwerk) – nur, wenn gewählt.
func _build_quoins() -> void:
	var quoins := option("quoins")
	var wall := option("wall")
	var show := quoins != null and quoins.material != null
	if wall and wall.hide_quoins:
		show = false
	_drop("Quoins")
	if not show:
		return
	var holder := _holder("Quoins")
	var ground := option("ground")
	var bottom := FacadeLayout.GROUND + 0.02 if ground and ground.family != "wood" else FacadeLayout.TOP + 0.1
	# Ecken zwischen den Wänden: [Wand davor, Wand danach]; an der Nachbarseite (rechts) nur vorn
	var corners := [["right", "front"], ["front", "diag"], ["diag", "left"], ["left", "back"]]
	for pair: Array in corners:
		for side in 2:
			var segment: String = pair[side]
			if segment == "right":
				continue
			var length := FacadeLayout.segment_length(segment)
			var mesh := OpeningMesh.new()
			var y := bottom
			var j := 0
			while y + 0.3 < FacadeLayout.EAVES - 0.35:
				if y > FacadeLayout.FASCIA_BOTTOM - 0.1 and y < FacadeLayout.TOP + 0.08:
					y = FacadeLayout.TOP + 0.1
					continue
				var w := 0.38 if j % 2 == 0 else 0.25
				var x := length - w / 2.0 + 0.004 if side == 0 else w / 2.0 - 0.004
				# unten stehen die Steine vor der Mauer-Haut des Erdgeschosses, oben vor der Wand
				var front := SKIN if y < FacadeLayout.FASCIA_BOTTOM else 0.0
				mesh.box(Vector3(x, y + 0.135, front + 0.012), Vector3(w, 0.27, 0.07), 0.018)
				y += 0.3
				j += 1
			var mi := _add(holder, mesh, null, segment, "%s_%d" % [segment, side])
			mi.set_meta("role", "quoin")


# --- Farben und Materialien ---

## Material des Mauerwerks im Erdgeschoss: Naturstein oder wie die Wand oben.
func _ground_material() -> Material:
	var ground := option("ground")
	if ground and ground.material:
		return ground.material
	return _material_of("wall", MATERIALS.wall)


func _material_of(category: String, fallback_path: String) -> Material:
	var chosen := option(category)
	if chosen and chosen.material:
		return chosen.material
	return load(fallback_path)


## Anstrich einer Kategorie (Farbe + Verwitterung) auf einem Grundmaterial.
func _paint_of(category: String, base_path: String) -> Material:
	var chosen := option(category)
	if chosen and chosen.material:
		return chosen.material
	var color := chosen.color if chosen and chosen.color.a > 0.0 else Color(0.13, 0.25, 0.18)
	return paint_material(load(base_path), color, chosen.weather if chosen else 0.0)


## Eingefärbtes (und ggf. verwittertes) Material – zwischengespeichert, für alle Teile gleich.
static func paint_material(base: Material, color: Color, weather: float) -> Material:
	if base == null:
		return null
	var key := "%d|%s|%.2f" % [base.get_instance_id(), color.to_html(), weather]
	if not _paints.has(key):
		var copy := FurnitureUtils.tinted_material(base, color).duplicate() as Material
		if copy is ShaderMaterial:
			(copy as ShaderMaterial).set_shader_parameter("weather", weather)
		_paints[key] = copy
	return _paints[key]


## Färbt bzw. ersetzt die Rollen-Flächen aller Teile unter root (auch für eine Vorschau).
func _apply_materials(root: Node) -> void:
	var paint := _paint_of("ground_color", MATERIALS.paint)
	var paint_dark := paint_material(load(MATERIALS.paint), _color_of("ground_color", Color(0.13, 0.25, 0.18)).darkened(0.35),
		option("ground_color").weather if option("ground_color") else 0.0)
	var frame := _paint_of("frame_color", MATERIALS.frame)
	var wall := _material_of("wall", MATERIALS.wall)
	var ground := option("ground")
	var fabric := option("fabric")
	var quoin := _material_of("quoins", MATERIALS.quoin)
	var fascia := _paint_of("fascia", MATERIALS.paint)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.get_meta("role", "") == "quoin":
			mesh_instance.material_override = quoin
			continue
		if mesh_instance.mesh == null or mesh_instance.material_override:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i)
			if material == null:
				continue
			var replacement: Material = null
			match material.resource_name:
				"facade_paint":
					replacement = paint
				"facade_paint_dark":
					replacement = paint_dark
				"facade_frame":
					replacement = frame
				"facade_stone":
					replacement = ground.material if ground and ground.material else null
				"facade_upper_wall":
					replacement = wall
				"facade_awning":
					replacement = fabric.material if fabric and fabric.material else null
				"facade_quoin":
					replacement = quoin
				"facade_fascia":
					replacement = fascia
			mesh_instance.set_surface_override_material(i, replacement)


func _color_of(category: String, fallback: Color) -> Color:
	var chosen := option(category)
	return chosen.color if chosen and chosen.color.a > 0.0 else fallback


# --- Pflanzen ---

## Pflanzen auf alle Plätze der Kästen, Ampeln und Deko-Töpfe – bunt gemischt aus der gewählten
## Mischung: jeder Kasten und jeder Korb etwas anders (Arten, Blattformen, Blütenfarben im Wechsel).
func _plant_all() -> void:
	var holder := _holder("Plants")
	var mix := option("plants")
	var fullness := option("fullness")
	var amount := fullness.amount if fullness else 1.0
	var box_plants: PackedStringArray = mix.plants if mix else PackedStringArray()
	var basket_plants: PackedStringArray = mix.basket_plants if mix and not mix.basket_plants.is_empty() else box_plants
	var rims: Array = Array(mix.rim_plants) if mix and not mix.rim_plants.is_empty() else ["rim_ivy", "rim_bacopa"]
	var spots := find_children("FacadeSpot_*", "", true, false)
	for k in spots.size():
		var spot := spots[k] as Node3D
		var extras: Dictionary = spot.get_meta("extras", {})
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + k * 17
		var base := _relative(spot)
		var width := float(extras.get("width", 0.3))
		if spot.name.begins_with("FacadeSpot_tub"):
			var tub := _plant(TUB_PLANTS[(k * 3 + (mix.order if mix else 0)) % TUB_PLANTS.size()])
			if tub:
				var ts := clampf(width / tub.nominal_size.x, 0.6, 1.8)
				tub.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * ts), Vector3.ZERO)
				holder.add_child(tub)
			continue
		if spot.name.begins_with("FacadeSpot_basket") or spot.name.begins_with("FacadeSpot_pot"):
			if basket_plants.is_empty():
				continue
			# Korb/Topf: eine Hauptpflanze, dazu eine Ranke über den Rand
			var piece := _plant(basket_plants[rng.randi_range(0, basket_plants.size() - 1)])
			if piece:
				var s := width / piece.nominal_size.x * PLANT_OVERFLOW * lerpf(0.9, 1.15, clampf(amount - 0.7, 0.0, 1.0))
				piece.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)
				holder.add_child(piece)
			_rim(holder, rims, rng, base, width / 0.4)
			continue
		if box_plants.is_empty():
			continue
		# Blumenkasten: verschiedene Arten im Wechsel (nie zweimal dieselbe nebeneinander), mal größer, mal
		# kleiner, vorn ranken einzelne Pflanzen über den Rand
		var count := maxi(2, roundi(width / BOX_PLANT_STEP * amount))
		var step := width / count
		var prev := -1
		for i in count:
			var pick := rng.randi_range(0, box_plants.size() - 1)
			if box_plants.size() > 1 and pick == prev:
				pick = (pick + 1 + rng.randi_range(0, box_plants.size() - 2)) % box_plants.size()
			prev = pick
			var piece := _plant(box_plants[pick])
			if piece == null:
				continue
			var s := clampf(step / piece.nominal_size.x, 0.7, 1.4) * PLANT_OVERFLOW * lerpf(0.92, 1.12, clampf(amount - 0.7, 0.0, 1.0))
			s *= rng.randf_range(0.85, 1.12)
			var offset := Vector3(-width / 2.0 + step * (i + 0.5) + rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.012, 0.012))
			piece.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)).scaled(Vector3(s, s * rng.randf_range(0.88, 1.14), s)), offset)
			holder.add_child(piece)
		for i in maxi(1, roundi(width / 0.5 * amount * 0.6)):
			var x := rng.randf_range(-width / 2.0 + 0.08, width / 2.0 - 0.08)
			_rim(holder, rims, rng, base * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, float(extras.get("depth", 0.16)) * 0.35)), 0.55)


## Eine Ranke bzw. ein Grasbüschel über den Rand.
func _rim(holder: Node3D, rims: Array, rng: RandomNumberGenerator, base: Transform3D, scale: float) -> void:
	if rims.is_empty():
		return
	var piece := _plant(rims[rng.randi_range(0, rims.size() - 1)])
	if piece:
		piece.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)).scaled(Vector3.ONE * scale), Vector3.ZERO)
		holder.add_child(piece)


func _plant(id: String) -> PlantPiece:
	return _instantiate(PLANT_FOLDER + id + ".tscn") as PlantPiece


# --- Tür und Laden ---

## Türblatt und Türfarbe an die Ladentür geben, die einfachen Teile der Tür-Szene ausblenden.
func _apply_door() -> void:
	var door := get_node_or_null(door_path)
	if door == null:
		return
	if door.has_method("set_leaf"):
		var color := option("door_color")
		door.set_leaf(_scene_of("door"), _color_of("door_color", Color(0.13, 0.25, 0.18)), color.weather if color else 0.0)
	for part in ["FrameLeft", "FrameRight", "FrameTop", "MullionLeft", "MullionRight", "TransomBar", "SidePanelLeft",
			"SidePanelRight", "SideGlassLeft", "SideGlassRight", "SideMuntinLeft", "SideMuntinRight", "TransomGlass", "TransomMuntin"]:
		var node := door.get_node_or_null(part) as Node3D
		if node:
			node.visible = false


## Wandlöcher, Innenfarbe und Fensterbänke des Ladens passend zu Fenstern und Tür.
func _apply_room() -> void:
	var room := get_parent()
	if room == null:
		return
	RoomOpenings.apply(room, FacadeLayout.openings(config))
