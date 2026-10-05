extends Node
## Katalog aller Möbel, Wandfarben und Böden.
##
## Dieses Autoload liest beim Spielstart alle Datenblätter aus den Ordnern
## data/furniture/ und data/surfaces/ ein. Im Code: Catalog.get_furniture("armchair_velvet").

const FURNITURE_FOLDER := "res://data/furniture/"
const SURFACE_FOLDER := "res://data/surfaces/"

var _furniture: Dictionary = {}  # id -> FurnitureData
var _surfaces: Dictionary = {}  # id -> SurfaceData


func _ready() -> void:
	for resource in _load_folder(FURNITURE_FOLDER):
		if resource is FurnitureData:
			_register(_furniture, resource.get_id(), resource)
	for resource in _load_folder(SURFACE_FOLDER):
		if resource is SurfaceData:
			_register(_surfaces, resource.get_id(), resource)
	print("Katalog geladen: %d Möbel, %d Oberflächen" % [_furniture.size(), _surfaces.size()])


## Liefert das Möbel-Datenblatt mit dieser id (oder null, wenn es keins gibt).
func get_furniture(id: String) -> FurnitureData:
	return _furniture.get(id)


func get_surface(id: String) -> SurfaceData:
	return _surfaces.get(id)


## Alle freigeschalteten Möbel einer Kategorie, sortiert nach Preis und Name.
func get_furniture_in_category(category: FurnitureData.Category) -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	for data: FurnitureData in _furniture.values():
		if data.is_unlocked and data.category == category:
			result.append(data)
	result.sort_custom(_sort_by_price_then_name)
	return result


## Alle freigeschalteten Wandfarben bzw. Böden.
func get_surfaces_of_kind(kind: SurfaceData.Kind) -> Array[SurfaceData]:
	var result: Array[SurfaceData] = []
	for data: SurfaceData in _surfaces.values():
		if data.is_unlocked and data.kind == kind:
			result.append(data)
	result.sort_custom(_sort_by_price_then_name)
	return result


func _sort_by_price_then_name(a: Resource, b: Resource) -> bool:
	if a.price != b.price:
		return a.price < b.price
	return a.display_name < b.display_name


func _register(target: Dictionary, id: String, resource: Resource) -> void:
	if target.has(id):
		push_warning("Katalog: Die id '%s' gibt es doppelt (%s). Bitte eine andere id wählen." % [id, resource.resource_path])
		return
	target[id] = resource


## Lädt alle .tres-Dateien eines Ordners.
func _load_folder(folder: String) -> Array[Resource]:
	var result: Array[Resource] = []
	# list_directory funktioniert auch im fertig exportierten Spiel
	for file_name in ResourceLoader.list_directory(folder):
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := load(folder + file_name)
			if resource:
				result.append(resource)
	return result
