extends Node
## Das Inventar: alles, was mir gehört und gerade nicht im Raum steht.
##
## - Möbel und Deko werden gezählt (z. B. "Bücherregal ×2"). Platzieren nimmt eins heraus,
##   Aufnehmen oder Weglegen (Mausrad-Klick) legt es wieder hinein.
## - Wandfarben, Böden und Decken werden einmal gekauft und sind danach unbegrenzt da.
##   Ein paar schlichte gibt es von Anfang an (Häkchen "Owned At Start" im Datenblatt).
## Was im Raum steht, gehört mir natürlich auch – das zählt der Raum selbst (Room).
## Im Code: Inventory.get_count("armchair_velvet", "bordeaux"), Inventory.add_furniture(id, 1, farbe).
## Jede Farbvariante eines Möbelstücks ist ein eigener Eintrag (seit Etappe 6).
## Das Inventar wird mit dem Spielstand gespeichert (Gruppe "persist", siehe SaveManager).

## Wird gesendet, wenn sich etwas im Inventar ändert.
signal changed

## Name im Spielstand.
var save_key: String = "inventory"

## Schlüssel -> Anzahl (nur Einträge mit Anzahl > 0). Schlüssel = "id" oder bei Möbeln mit
## Farbvarianten "id:farbe" (FurnitureData.make_key) – jede Farbe ist ein eigener Eintrag.
var _furniture: Dictionary = {}
var _surfaces: Array[String] = []  # ids der Oberflächen, die mir gehören


func _ready() -> void:
	add_to_group(SaveManager.PERSIST_GROUP)
	for surface in Catalog.get_all_surfaces():
		if surface.owned_at_start:
			_surfaces.append(surface.get_id())


# --- Möbel und Deko ---

## Wie viele davon liegen im Inventar (nicht aufgestellt)? Bei Möbeln mit Farben zählt nur die
## angegebene Farbe (leer = Standardfarbe).
func get_count(id: String, variant: String = "") -> int:
	return int(_furniture.get(_key(id, variant), 0))


## Wie viele liegen im Inventar, alle Farben zusammen?
func get_total_count(id: String) -> int:
	var total := 0
	for key in _furniture:
		if FurnitureData.split_key(key)[0] == id:
			total += int(_furniture[key])
	return total


## Legt Möbel ins Inventar (in der Farbe variant, leer = Standardfarbe).
func add_furniture(id: String, amount: int = 1, variant: String = "") -> void:
	if amount <= 0 or Catalog.get_furniture(id) == null:
		return
	var key := _key(id, variant)
	_furniture[key] = int(_furniture.get(key, 0)) + amount
	_changed()


## Nimmt Möbel aus dem Inventar (zum Aufstellen oder Verkaufen).
## Liefert false (und ändert nichts), wenn nicht genug da ist.
func take_furniture(id: String, amount: int = 1, variant: String = "") -> bool:
	var key := _key(id, variant)
	if amount <= 0 or int(_furniture.get(key, 0)) < amount:
		return false
	_furniture[key] = int(_furniture[key]) - amount
	if _furniture[key] == 0:
		_furniture.erase(key)
	_changed()
	return true


## Alle Möbel, von denen mindestens eins im Inventar liegt (egal in welcher Farbe, sortiert
## wie im Katalog).
func get_stored_furniture() -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	for data in Catalog.get_all_furniture():
		if get_total_count(data.get_id()) > 0:
			result.append(data)
	return result


## Alle Einträge im Inventar – jede Farbe einzeln – als Liste von
## { "data": FurnitureData, "variant": Farb-id, "count": Anzahl }, sortiert wie im Katalog und
## in der Reihenfolge der Farben im Datenblatt.
func get_stored_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data in get_stored_furniture():
		var variants: Array[String] = [""]
		if data.has_variants():
			variants.clear()
			for variant in data.color_variants:
				if variant:
					variants.append(variant.id)
		for variant in variants:
			var count := get_count(data.get_id(), variant)
			if count > 0:
				result.append({"data": data, "variant": variant, "count": count})
	return result


## Schlüssel für ein Möbelstück in einer Farbe (unbekannte oder leere Farbe = Standardfarbe).
func _key(id: String, variant: String) -> String:
	var data := Catalog.get_furniture(id)
	return FurnitureData.make_key(id, data.resolve_variant(variant) if data else variant)


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
		for saved_key in furniture:
			var amount := int(furniture[saved_key])
			var parts := FurnitureData.split_key(str(saved_key))
			if amount > 0 and Catalog.get_furniture(parts[0]):
				# Ältere Spielstände ohne Farbe: Standardfarbe; verschwundene Farben ebenso
				var key := _key(parts[0], parts[1])
				_furniture[key] = int(_furniture.get(key, 0)) + amount
			elif amount > 0 and parts[0] == ReturnBox.LEGACY_FURNITURE_ID:
				ReturnBox.refund_legacy(amount, false)  # alter Spielstand: Kasten ist jetzt fest eingebaut
	# Oberflächen kommen dazu (die Startfarben und alles, was schon im Raum zu sehen ist,
	# bleiben erhalten – auch wenn der Spielstand älter ist als dieses Inventar)
	var surfaces = data.get("surfaces")
	if surfaces is Array:
		for id in surfaces:
			if not owns_surface(str(id)) and Catalog.get_surface(str(id)):
				_surfaces.append(str(id))
	changed.emit()
