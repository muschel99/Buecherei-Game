extends Node
## Katalog aller Möbel, Wandfarben, Böden, Buch-Genres und Buchtitel (alles, was es im Spiel gibt).
## Was man davon besitzt, steht im Inventar (Inventory), was man kaufen kann, im Shop.
##
## Dieses Autoload liest beim Spielstart alle Datenblätter aus den Ordnern
## data/furniture/, data/surfaces/ und data/genres/ ein, dazu die Bücherlisten der Genres
## (data/books/<genre>.txt, eine Zeile pro Buch).
## Im Code: Catalog.get_furniture("armchair_velvet"), Catalog.get_genre("crime"),
## Catalog.get_book("crime/the-case-of-the-curious-cat").

const FURNITURE_FOLDER := "res://data/furniture/"
const SURFACE_FOLDER := "res://data/surfaces/"
const GENRE_FOLDER := "res://data/genres/"
const RETURN_SLOT_FOLDER := "res://data/return_slots/"

var _furniture: Dictionary = {}  # id -> FurnitureData
var _surfaces: Dictionary = {}  # id -> SurfaceData
var _genres: Dictionary = {}  # id -> GenreData
var _return_slots: Dictionary = {}  # id -> ReturnSlotData (Einwurf-Varianten des Rückgabekastens)
var _books: Dictionary = {}  # id -> BookData
var _books_by_genre: Dictionary = {}  # genre_id -> Array[BookData] (Reihenfolge wie in der Liste)


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
	for resource in _load_folder(RETURN_SLOT_FOLDER):
		if resource is ReturnSlotData:
			_register(_return_slots, resource.get_id(), resource)
	for genre in get_all_genres():
		_load_books(genre)
	print("Katalog geladen: %d Möbel, %d Oberflächen, %d Genres, %d Bücher" % [_furniture.size(),
		_surfaces.size(), _genres.size(), _books.size()])


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


## Einwurf-Variante des Rückgabekastens mit dieser id (oder null).
func get_return_slot(id: String) -> ReturnSlotData:
	return _return_slots.get(id)


## Alle Einwurf-Varianten, sortiert nach "Order" und Name.
func get_all_return_slots() -> Array[ReturnSlotData]:
	var result: Array[ReturnSlotData] = []
	result.assign(_return_slots.values())
	result.sort_custom(func(a: ReturnSlotData, b: ReturnSlotData) -> bool:
		if a.order != b.order:
			return a.order < b.order
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


## Liefert den Buchtitel mit dieser id (oder null).
func get_book(id: String) -> BookData:
	return _books.get(id)


## Alle Buchtitel eines Genres (Reihenfolge wie in der Bücherliste).
func get_books_of_genre(genre_id: String) -> Array[BookData]:
	var result: Array[BookData] = []
	result.assign(_books_by_genre.get(genre_id, []))
	return result


## Alle Buchtitel (Genre für Genre).
func get_all_books() -> Array[BookData]:
	var result: Array[BookData] = []
	for genre in get_all_genres():
		result.append_array(get_books_of_genre(genre.get_id()))
	return result


## Nimmt einen Titel auf, der nicht (mehr) in einer Bücherliste steht – z. B. aus einem
## Spielstand, nachdem eine Zeile gelöscht wurde. So geht kein Buch verloren.
func register_custom_book(data: BookData) -> void:
	if _books.has(data.id):
		return
	data.is_custom = true
	_books[data.id] = data


## Liest die Bücherliste eines Genres: eine Zeile pro Buch, "Titel | Motiv | Gestaltung | Autor".
func _load_books(genre: GenreData) -> void:
	var path := genre.get_books_path()
	var list: Array[BookData] = []
	_books_by_genre[genre.get_id()] = list
	if not FileAccess.file_exists(path):
		push_warning("Katalog: Bücherliste '%s' fehlt – das Genre %s hat noch keine Bücher." % [path, genre.display_name])
		return
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("|")
		var cells: Array[String] = []
		for part in parts:
			cells.append(part.strip_edges())
		while cells.size() < 4:
			cells.append("")
		if cells[0].is_empty():
			continue
		var data := BookData.create(genre, cells[0], cells[1], cells[2], cells[3])
		if _books.has(data.id):
			push_warning("Katalog: Das Buch '%s' steht doppelt in %s." % [cells[0], path])
			continue
		_books[data.id] = data
		list.append(data)


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
