extends Node
## Katalog aller Möbel, Wandfarben, Böden und Buch-Genres (alles, was es im Spiel gibt).
## Was man davon besitzt, steht im Inventar (Inventory), was man kaufen kann, im Shop.
##
## Dieses Autoload liest beim Spielstart alle Datenblätter aus den Ordnern
## data/furniture/, data/surfaces/ und data/genres/ ein.
## Im Code: Catalog.get_furniture("armchair_velvet"), Catalog.get_genre("crime").

const FURNITURE_FOLDER := "res://data/furniture/"
const SURFACE_FOLDER := "res://data/surfaces/"
const GENRE_FOLDER := "res://data/genres/"

var _furniture: Dictionary = {}  # id -> FurnitureData
var _surfaces: Dictionary = {}  # id -> SurfaceData
var _genres: Dictionary = {}  # id -> GenreData


func _ready() -> void:
	for resource in _load_folder(FURNITURE_FOLDER):
		if resource is FurnitureData:
			_register(_furniture, resource.get_id(), resource)
	for resource in _load_folder(SURFACE_FOLDER):
		if resource is SurfaceData:
			_register(_surfaces, resource.get_id(), resource)
	for resource in _load_folder(GENRE_FOLDER):
		if resource is GenreData:
			_register(_genres, resource.get_id(), resource)
	print("Katalog geladen: %d Möbel, %d Oberflächen, %d Genres" % [_furniture.size(), _surfaces.size(), _genres.size()])


## Liefert das Möbel-Datenblatt mit dieser id (oder null, wenn es keins gibt).
func get_furniture(id: String) -> FurnitureData:
	return _furniture.get(id)


func get_surface(id: String) -> SurfaceData:
	return _surfaces.get(id)


## Liefert das Genre-Datenblatt mit dieser id (oder null).
func get_genre(id: String) -> GenreData:
	return _genres.get(id)


## Alle Genres (auch gesperrte), sortiert nach "Sort Order" und Name.
## Welche freigeschaltet sind, weiß BookStock (BookStock.get_unlocked_genres()).
func get_all_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	result.assign(_genres.values())
	result.sort_custom(func(a: GenreData, b: GenreData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name)
	return result


## Alle Möbel-Datenblätter (auch gesperrte), sortiert nach Preis und Name.
func get_all_furniture() -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	result.assign(_furniture.values())
	result.sort_custom(_sort_by_price_then_name)
	return result


## Alle Oberflächen-Datenblätter (auch gesperrte), sortiert nach Preis und Name.
func get_all_surfaces() -> Array[SurfaceData]:
	var result: Array[SurfaceData] = []
	result.assign(_surfaces.values())
	result.sort_custom(_sort_by_price_then_name)
	return result


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
