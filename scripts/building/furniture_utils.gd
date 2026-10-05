@tool
class_name FurnitureUtils
extends RefCounted
## Hilfsfunktionen rund um Möbel-Modelle (werden von mehreren Scripts genutzt).

## Physik-Ebenen als Bit-Werte (Ebene 1 = 1, Ebene 2 = 2, Ebene 3 = 4, Ebene 4 = 8, Ebene 5 = 16).
const WORLD_LAYER_BIT := 1
const PLAYER_LAYER_BIT := 4
const FURNITURE_LAYER_BIT := 8
const BUILD_BLOCKER_LAYER_BIT := 16

## Rastergröße für Ersatz-Kisten im Editor (dort gibt es GameConfig noch nicht).
const _FALLBACK_CELL := 0.25

static var _highlight_material: StandardMaterial3D


## Erzeugt das 3D-Modell eines Möbelstücks aus seinem Datenblatt.
## Fehlt eine Kollision (z. B. bei einer reinen .glb-Datei), wird eine passende Kiste ergänzt.
static func instantiate_model(data: FurnitureData) -> Node3D:
	var packed: PackedScene = null
	if not data.scene_path.is_empty() and ResourceLoader.exists(data.scene_path):
		packed = load(data.scene_path) as PackedScene
	if packed == null:
		push_warning("Möbel '%s': Szene/Modell '%s' nicht gefunden – zeige Ersatz-Kiste." % [data.display_name, data.scene_path])
		return _create_fallback_box(data)

	var instance := packed.instantiate()
	if not instance is Node3D:
		push_warning("Möbel '%s': '%s' ist keine 3D-Szene." % [data.display_name, data.scene_path])
		instance.free()
		return _create_fallback_box(data)

	if find_bodies(instance).is_empty():
		_add_box_collision(instance)
	return instance


## Alle StaticBody3D-Knoten (Kollisionskörper) unterhalb von root.
static func find_bodies(root: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for node in root.find_children("*", "StaticBody3D", true, false):
		result.append(node)
	return result


## Alle Kollisionsformen der Kollisionskörper unterhalb von root.
static func find_body_shapes(root: Node) -> Array[CollisionShape3D]:
	var result: Array[CollisionShape3D] = []
	for body in find_bodies(root):
		for node in body.find_children("*", "CollisionShape3D", true, false):
			if not node.disabled and node.shape:
				result.append(node)
	return result


## Sucht zu einem getroffenen Kollisionskörper das zugehörige platzierte Möbelstück.
static func find_placed_furniture(node: Node) -> PlacedFurniture:
	while node:
		if node is PlacedFurniture:
			return node
		node = node.get_parent()
	return null


## Legt über alle sichtbaren Teile eine zusätzliche Material-Schicht (null = entfernen).
static func set_overlay(root: Node, material: Material) -> void:
	for node in _geometry_nodes(root):
		node.material_overlay = material


## Ersetzt das Material aller sichtbaren Teile (für die halbdurchsichtige Vorschau).
static func set_override(root: Node, material: Material) -> void:
	for node in _geometry_nodes(root):
		node.material_override = material


## Gemeinsames Material für "Maus zeigt auf dieses Möbelstück".
static func get_highlight_material() -> StandardMaterial3D:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.albedo_color = Color(1.0, 0.85, 0.5, 0.22)
	return _highlight_material


## Macht aus einem Modell eine reine Vorschau: keine Kollision, kein Licht, kein Schatten.
static func make_preview_only(root: Node) -> void:
	var nodes: Array[Node] = root.find_children("*", "", true, false)
	nodes.append(root)
	for node in nodes:
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0
		if node is Interactable:
			node.is_enabled = false
		if node is Light3D or node is GPUParticles3D:
			node.visible = false
		if node is GeometryInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Umgebender Quader aller sichtbaren Teile, gemessen im Koordinatensystem von root.
static func get_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var is_first := true
	for node in _geometry_nodes(root):
		if node is GPUParticles3D:
			continue
		var relative := Transform3D.IDENTITY
		var current: Node = node
		while current and current != root:
			if current is Node3D:
				relative = current.transform * relative
			current = current.get_parent()
		var box: AABB = relative * node.get_aabb()
		result = box if is_first else result.merge(box)
		is_first = false
	return result


## Verkleinert eine Kollisionsform etwas, damit Möbel, die sich nur berühren, nicht als
## Überschneidung zählen (z. B. eine Vase, die genau auf dem Tisch steht).
static func shrink_shape(shape: Shape3D, amount: float) -> Shape3D:
	if shape is BoxShape3D:
		var box := BoxShape3D.new()
		box.size = (shape.size - Vector3.ONE * amount * 2.0).max(Vector3.ONE * 0.01)
		return box
	if shape is CylinderShape3D:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(shape.radius - amount, 0.01)
		cylinder.height = maxf(shape.height - amount * 2.0, 0.01)
		return cylinder
	if shape is SphereShape3D:
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(shape.radius - amount, 0.01)
		return sphere
	if shape is CapsuleShape3D:
		var capsule := CapsuleShape3D.new()
		capsule.radius = maxf(shape.radius - amount, 0.01)
		capsule.height = maxf(shape.height - amount * 2.0, capsule.radius * 2.0)
		return capsule
	return shape


static func _geometry_nodes(root: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		result.append(root)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		result.append(node)
	return result


## Ergänzt eine Kollisions-Kiste in Größe des Modells (für .glb-Modelle ohne eigene Kollision).
static func _add_box_collision(root: Node3D) -> void:
	var bounds := get_local_aabb(root)
	if bounds.size == Vector3.ZERO:
		bounds = AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
	var body := StaticBody3D.new()
	body.name = "Body"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size
	collision.shape = box
	collision.position = bounds.get_center()
	body.add_child(collision)
	root.add_child(body)


## Pinke Ersatz-Kiste, falls das Modell fehlt – so fällt der Fehler sofort auf.
static func _create_fallback_box(data: FurnitureData) -> Node3D:
	var root := Node3D.new()
	root.name = "MissingModel"
	var size := Vector3(data.footprint.x * _FALLBACK_CELL, 0.5, data.footprint.y * _FALLBACK_CELL)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.2, 0.7)
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = size.y / 2.0
	root.add_child(mesh_instance)
	_add_box_collision(root)
	return root
