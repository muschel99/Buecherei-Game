@tool
class_name PlacedFurniture
extends Node3D
## Ein Möbelstück, das im Raum steht.
##
## Im Inspektor wird nur das Datenblatt ("Data") eingetragen, das Modell erzeugt
## dieser Knoten selbst. Dadurch sieht man die Möbel auch im Editor und kann
## sie dort verschieben. Im Spiel verschiebt man sie im Gestaltungsmodus (Taste B).

## Das Datenblatt aus data/furniture/.
@export var data: FurnitureData:
	set(value):
		data = value
		if is_node_ready():
			_rebuild_model()

## Laufende Nummer im Raum (für den Spielstand, wird automatisch vergeben).
var uid: int = 0
## Nummer des Möbelstücks, auf dem dieses steht (0 = steht auf dem Boden).
var support_uid: int = 0

var _model: Node3D = null
var _bodies: Array[StaticBody3D] = []
var _surfaces: Array[PlacementSurface] = []


func _ready() -> void:
	_rebuild_model()


## Das erzeugte Modell (z. B. für die Vorschau beim Verschieben).
func get_model() -> Node3D:
	return _model


## Schaltet die Kollision und die Ablageflächen ein oder aus
## (aus = beim Verschieben "in der Hand").
func set_collision_enabled(enabled: bool) -> void:
	for body in _bodies:
		body.collision_layer = FurnitureUtils.FURNITURE_LAYER_BIT if enabled else 0
	for surface in _surfaces:
		surface.collision_layer = FurnitureUtils.SURFACE_LAYER_BIT if enabled else 0


## Leichtes Aufleuchten, wenn man im Gestaltungsmodus darauf zeigt.
func set_highlighted(highlighted: bool) -> void:
	if _model:
		FurnitureUtils.set_overlay(_model, FurnitureUtils.get_highlight_material() if highlighted else null)


func _rebuild_model() -> void:
	if _model:
		remove_child(_model)
		_model.queue_free()
		_model = null
	_bodies.clear()
	_surfaces.clear()
	if data == null:
		return

	_model = FurnitureUtils.instantiate_model(data)
	# "Intern" heißt: Das Modell wird nicht in die Szenendatei gespeichert und
	# taucht nicht im Szenenbaum auf – es entsteht immer frisch aus dem Datenblatt.
	add_child(_model, false, Node.INTERNAL_MODE_FRONT)

	if Engine.is_editor_hint():
		return
	_bodies = FurnitureUtils.find_bodies(_model)
	for body in _bodies:
		body.collision_layer = FurnitureUtils.FURNITURE_LAYER_BIT
		body.collision_mask = 0
	_surfaces = FurnitureUtils.find_surfaces(_model)
