class_name LibraryFacade
extends Node3D
## Die Fassade der Bücherei aus Bausteinen (seit Etappe 6b; Modelle aus
## tools/blender/build_storybook_facade.py in assets/models/facade/): Kern (Dach, Gesimse, Laternen,
## Ankerpunkte), Erdgeschoss, Obergeschoss mit Fenstern, Markisen, Blumenkästen, Ampeln und Pflanzen –
## je nach Wahl (FacadeDesign, Datenblätter data/facade/).
##
## - Rollen-Flächen der Modelle werden gefärbt bzw. ersetzt: facade_paint (+ _dark) = Anstrich unten,
##   facade_frame = Fensterrahmen, facade_upper_wall = Wand oben, facade_stone = Naturstein unten,
##   facade_awning = Markisenstoff; facade_quoin = Ecksteine (bei Holz ausgeblendet).
## - Markisen, Kästen und Ampeln hängen an leeren Knoten „Anchor_awning_…“, „Anchor_box_…“,
##   „Anchor_basket_…“ der Modelle; Pflanzen kommen auf deren Plätze „FacadeSpot_box/basket“ (Szenen aus
##   scenes/world/plants/ – Art, Farbe und Fülle aus der Wahl). Greenery bepflanzt diese Plätze nicht.
## - follow_design = true (die echte Fassade im Raum): folgt FacadeDesign und gibt Türblatt und
##   Türfarbe an die Ladentür (door_path) weiter. Für Vorschauen (Polaroid in der App) false lassen
##   und build(wahl) aufrufen.
## Die Fassade baut sich gleich beim Einhängen (vor Greenery, das den Kübel am Kern bepflanzt).

const CORE_PATH := "res://assets/models/facade/core.glb"
const PLANT_FOLDER := "res://scenes/world/plants/"
## Platz je Pflanze im Blumenkasten bei Fülle 1 (Meter)
const BOX_PLANT_STEP := 0.27
## Pflanzen etwas größer als ihr Platz (quellen über den Rand)
const PLANT_OVERFLOW := 1.1

## Folgt FacadeDesign (echte Fassade) oder wird von außen gebaut (Vorschau).
@export var follow_design := true
## Die Ladentür (nur bei follow_design): bekommt Türblatt und Türfarbe.
@export var door_path: NodePath = ^"../Door"

## Die gerade gebaute Wahl (Kategorie -> id).
var config: Dictionary = {}

var _built := false
var _scenes := {}  # Pfad -> PackedScene


func _notification(what: int) -> void:
	# Schon beim Einhängen bauen: Dann ist der Pflanzplatz am Kern da, bevor Greenery sucht
	if what == NOTIFICATION_PARENTED and not _built and not Engine.is_editor_hint():
		build(FacadeDesign.config if follow_design else FacadeDesign.DEFAULTS)


func _ready() -> void:
	if Engine.is_editor_hint() or not follow_design:
		return
	FacadeDesign.changed.connect(func() -> void: build(FacadeDesign.config))
	_apply_door()


## Baut die Fassade nach dieser Wahl (fehlende Kategorien: Standard). Teile, die gleich bleiben,
## bleiben stehen.
func build(new_config: Dictionary) -> void:
	config = FacadeDesign.normalized(new_config)
	_built = true
	_set_part("Core", CORE_PATH)
	_set_part("Ground", _scene_of("ground"))
	_set_part("Upper", _scene_of("window"))
	_place_at_anchors("Awnings", "Anchor_awning_", _scene_of("awning"))
	_place_at_anchors("Boxes", "Anchor_box_", _scene_of("box"))
	_place_at_anchors("Baskets", "Anchor_basket_", _scene_of("basket"))
	_apply_materials(self)
	_plant_all()
	if follow_design and is_inside_tree():
		_apply_door()


func option(category: String) -> FacadeOption:
	return FacadeDesign.get_option(category, config)


func _scene_of(category: String) -> String:
	var chosen := option(category)
	return chosen.scene_path if chosen else ""


# --- Teile ---

## Ein Teil (Kern, Erdgeschoss, Obergeschoss) einsetzen bzw. tauschen.
func _set_part(part_name: String, path: String) -> void:
	var old := get_node_or_null(part_name)
	if old and old.scene_file_path == path:
		return
	if old:
		remove_child(old)
		old.free()
	var model := _instantiate(path)
	if model:
		model.name = part_name
		add_child(model)
		move_child(model, mini(get_child_count() - 1, ["Core", "Ground", "Upper"].find(part_name)))


## An jeden Ankerpunkt (Name beginnt mit prefix) ein Modell hängen – alles unter einem Knoten holder.
func _place_at_anchors(holder_name: String, prefix: String, path: String) -> void:
	var old := get_node_or_null(holder_name)
	if old:
		remove_child(old)
		old.free()
	if path.is_empty():
		return
	var holder := Node3D.new()
	holder.name = holder_name
	add_child(holder)
	var anchors: Array[Node] = []
	for part_name in ["Core", "Upper"]:
		var part := get_node_or_null(part_name)
		if part:
			anchors.append_array(part.find_children(prefix + "*", "", true, false))
	for anchor: Node in anchors:
		var model := _instantiate(path)
		if model:
			model.transform = _relative(anchor as Node3D)
			holder.add_child(model)


func _instantiate(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var packed := _scenes[path] as PackedScene
	return packed.instantiate() as Node3D if packed else null


## Lage eines Knotens relativ zur Fassade (geht auch, solange sie noch nicht im Baum ist).
func _relative(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


# --- Farben und Materialien ---

## Färbt bzw. ersetzt die Rollen-Flächen aller Teile unter root (auch für eine Vorschau).
func _apply_materials(root: Node) -> void:
	var paint := _color_of("ground_color", Color(0.13, 0.25, 0.18))
	var frame := _color_of("frame_color", Color(0.9, 0.86, 0.76))
	var ground := option("ground")
	var upper := option("upper")
	var fabric := option("fabric")
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i)
			if material == null:
				continue
			var replacement: Material = null
			match material.resource_name:
				"facade_paint":
					replacement = FurnitureUtils.tinted_material(material, paint)
				"facade_paint_dark":
					replacement = FurnitureUtils.tinted_material(material, paint.darkened(0.35))
				"facade_frame":
					replacement = FurnitureUtils.tinted_material(material, frame)
				"facade_stone":
					replacement = ground.material if ground and ground.material else null
				"facade_upper_wall":
					replacement = upper.material if upper and upper.material else null
				"facade_awning":
					replacement = fabric.material if fabric and fabric.material else null
				"facade_quoin":
					mesh_instance.visible = not (upper and upper.hide_quoins)
			mesh_instance.set_surface_override_material(i, replacement)


func _color_of(category: String, fallback: Color) -> Color:
	var chosen := option(category)
	return chosen.color if chosen and chosen.color.a > 0.0 else fallback


# --- Pflanzen ---

## Pflanzen auf alle Plätze der Kästen und Ampeln (Art und Farbe aus der Wahl, Fülle = Zahl und Größe).
func _plant_all() -> void:
	var old := get_node_or_null("Plants")
	if old:
		remove_child(old)
		old.free()
	var holder := Node3D.new()
	holder.name = "Plants"
	add_child(holder)
	var fullness := option("fullness")
	var amount := fullness.amount if fullness else 1.0
	var spots := find_children("FacadeSpot_*", "", true, false)
	for k in spots.size():
		var spot := spots[k] as Node3D
		var extras: Dictionary = spot.get_meta("extras", {})
		var is_basket := spot.name.begins_with("FacadeSpot_basket")
		var chosen := option("basket_plant" if is_basket else "box_plant")
		if chosen == null or chosen.plants.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + k * 17
		var base := _relative(spot)
		var width := float(extras.get("width", 0.3))
		if is_basket:
			var piece := _plant(chosen.plants[k % chosen.plants.size()])
			if piece:
				var s := width / piece.nominal_size.x * PLANT_OVERFLOW * lerpf(0.9, 1.15, clampf(amount - 0.7, 0.0, 1.0))
				piece.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3.ZERO)
				holder.add_child(piece)
			continue
		# Blumenkasten: Pflanzen nebeneinander, Sorten der Wahl im Wechsel
		var count := maxi(2, roundi(width / BOX_PLANT_STEP * amount))
		var step := width / count
		var start := rng.randi_range(0, chosen.plants.size() - 1)
		for i in count:
			var piece := _plant(chosen.plants[(start + i) % chosen.plants.size()])
			if piece == null:
				continue
			var s := clampf(step / piece.nominal_size.x, 0.7, 1.4) * PLANT_OVERFLOW * lerpf(0.92, 1.12, clampf(amount - 0.7, 0.0, 1.0))
			s *= rng.randf_range(0.92, 1.08)
			var offset := Vector3(-width / 2.0 + step * (i + 0.5) + rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.012, 0.012))
			piece.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)).scaled(Vector3(s, s * rng.randf_range(0.92, 1.1), s)), offset)
			holder.add_child(piece)


func _plant(id: String) -> PlantPiece:
	return _instantiate(PLANT_FOLDER + id + ".tscn") as PlantPiece


# --- Tür ---

## Türblatt und Türfarbe an die Ladentür geben.
func _apply_door() -> void:
	var door := get_node_or_null(door_path)
	if door and door.has_method("set_leaf"):
		door.set_leaf(_scene_of("door"), _color_of("door_color", Color(0.13, 0.25, 0.18)))
