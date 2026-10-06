class_name FurniturePreview
extends Node3D
## Die halbdurchsichtige Vorschau eines Möbelstücks im Gestaltungsmodus.
##
## Grün = passt, Rot = passt nicht. Die Vorschau hat selbst keine Kollision,
## kennt aber die Kollisionsformen des Möbelstücks, damit der Gestaltungsmodus
## prüfen kann, ob an der gewünschten Stelle Platz ist.

## So viel werden die Formen beim Prüfen verkleinert (in Metern), damit bloßes Berühren erlaubt ist.
const SHRINK := 0.02

var data: FurnitureData = null

var _material: StandardMaterial3D
var _model: Node3D = null
var _shapes: Array[CollisionShape3D] = []
var _shrunk_shapes: Array[Shape3D] = []


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.render_priority = 1
	set_valid(true)


## Baut die Vorschau für ein Möbelstück.
## extras: Dinge, die mitwandern (z. B. die Vase auf dem Tisch), als
## Liste von { "data": FurnitureData, "transform": Transform3D relativ zum Möbelstück }.
func setup(new_data: FurnitureData, extras: Array[Dictionary] = []) -> void:
	clear()
	data = new_data
	_model = FurnitureUtils.instantiate_model(data)
	add_child(_model)
	_prepare(_model)
	_shapes = FurnitureUtils.find_body_shapes(_model)
	for collision in _shapes:
		_shrunk_shapes.append(FurnitureUtils.shrink_shape(collision.shape, SHRINK))

	for extra in extras:
		var extra_model := FurnitureUtils.instantiate_model(extra["data"])
		add_child(extra_model)
		extra_model.transform = extra["transform"]
		_prepare(extra_model)


## Zeigt in der Vorschau, was im Möbelstück steckt (z. B. die Bücher eines Regals),
## damit man beim Verschieben sieht, dass sie mitwandern.
func show_contents_of(item: PlacedFurniture) -> void:
	if _model == null or item.get_model() == null:
		return
	var original := _find_shelf(item.get_model())
	var copy := _find_shelf(_model)
	if original and copy:
		copy.genre_id = original.genre_id
		copy.add_books(original.books, false)


static func _find_shelf(root: Node) -> BookShelf:
	for node in root.find_children("*", "", true, false):
		if node is BookShelf:
			return node
	return null


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_model = null
	_shapes.clear()
	_shrunk_shapes.clear()
	data = null


func set_valid(valid: bool) -> void:
	var color := GameConfig.preview_color_valid if valid else GameConfig.preview_color_invalid
	color.a = GameConfig.preview_opacity
	_material.albedo_color = color


## Kollisionsformen des Möbelstücks (für die Platzprüfung).
func get_shapes() -> Array[CollisionShape3D]:
	return _shapes


## Die etwas verkleinerte Version der Form mit gleicher Nummer.
func get_shrunk_shape(index: int) -> Shape3D:
	return _shrunk_shapes[index]


func _prepare(model: Node3D) -> void:
	FurnitureUtils.make_preview_only(model)
	FurnitureUtils.set_override(model, _material)
