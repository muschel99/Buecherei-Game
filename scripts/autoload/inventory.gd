extends Node
## Das Inventar: alles, was mir gehört und gerade nicht im Raum steht.
##
## - Möbel und Deko werden gezählt (z. B. "Bücherregal ×2"). Platzieren nimmt eins heraus,
##   Aufheben oder Wegräumen (X) legt es wieder hinein.
## - Wandfarben, Böden und Decken werden einmal gekauft und sind danach unbegrenzt da.
##   Ein paar schlichte gibt es von Anfang an (Häkchen "Owned At Start" im Datenblatt).
## Was im Raum steht, gehört mir natürlich auch – das zählt der Raum selbst (Room).
## Im Code: Inventory.get_count("armchair_velvet"), Inventory.add_furniture(...).
## Das Inventar wird mit dem Spielstand gespeichert (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich etwas im Inventar ändert.
signal changed

## Name im Spielstand.
var save_key: String = "inventory"

var _furniture: Dictionary = {}  # id -> Anzahl (nur Einträge mit Anzahl > 0)
var _surfaces: Array[String] = []  # ids der Oberflächen, die mir gehören


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	for surface in Catalog.get_all_surfaces():
		if surface.owned_at_start:
			_surfaces.append(surface.get_id())


# --- Möbel und Deko ---

## Wie viele davon liegen im Inventar (nicht aufgestellt)?
func get_count(id: String) -> int:
	return int(_furniture.get(id, 0))


## Legt Möbel ins Inventar.
func add_furniture(id: String, amount: int = 1) -> void:
	if amount <= 0 or Catalog.get_furniture(id) == null:
		return
	_furniture[id] = get_count(id) + amount
	_changed()


## Nimmt Möbel aus dem Inventar (zum Aufstellen oder Verkaufen).
## Liefert false (und ändert nichts), wenn nicht genug da ist.
func take_furniture(id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(id) < amount:
		return false
	_furniture[id] = get_count(id) - amount
	if _furniture[id] == 0:
		_furniture.erase(id)
	_changed()
	return true


## Alle Möbel, von denen mindestens eins im Inventar liegt (sortiert wie im Katalog).
func get_stored_furniture() -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	for data in Catalog.get_all_furniture():
		if get_count(data.get_id()) > 0:
			result.append(data)
	return result


# --- Wandfarben, Böden, Decken ---

func owns_surface(id: String) -> bool:
	return _surfaces.has(id)


## Eine Oberfläche gehört ab jetzt mir (z. B. nach dem Auspacken einer Lieferung).
func add_surface(id: String) -> void:
	if owns_surface(id) or Catalog.get_surface(id) == null:
		return
	_surfaces.append(id)
	_changed()


## Alle Oberflächen einer Art, die mir gehören (sortiert wie im Katalog).
func get_owned_surfaces(kind: SurfaceData.Kind) -> Array[SurfaceData]:
	var result: Array[SurfaceData] = []
	for surface in Catalog.get_surfaces_of_kind(kind):
		if owns_surface(surface.get_id()):
			result.append(surface)
	return result


func _changed() -> void:
	changed.emit()
	SaveManager.request_save()


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	return {"furniture": _furniture.duplicate(), "surfaces": _surfaces.duplicate()}


func load_save_data(data: Dictionary) -> void:
	_furniture.clear()
	var furniture = data.get("furniture")
	if furniture is Dictionary:
		for id in furniture:
			var amount := int(furniture[id])
			if amount > 0 and Catalog.get_furniture(str(id)):
				_furniture[str(id)] = amount
	# Oberflächen kommen dazu (die Startfarben und alles, was schon im Raum zu sehen ist,
	# bleiben erhalten – auch wenn der Spielstand älter ist als dieses Inventar)
	var surfaces = data.get("surfaces")
	if surfaces is Array:
		for id in surfaces:
			if not owns_surface(str(id)) and Catalog.get_surface(str(id)):
				_surfaces.append(str(id))
	changed.emit()
