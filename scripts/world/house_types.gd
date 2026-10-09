class_name HouseTypes
extends RefCounted
## Die Haustypen (seit Etappe 4e): je Typ eine Szene in scenes/world/houses/<id>.tscn mit
## festen Maßen (Breite, Tiefe, Traufhöhe). Hier liest man diese Maße, ohne ein Haus zu bauen.
## Gleiche Häuser nutzen dieselbe Szene (und damit dasselbe Mesh).

const FOLDER := "res://scenes/world/houses/"

static var _cache := {}


static func scene_path(id: String) -> String:
	return FOLDER + id + ".tscn"


static func get_scene(id: String) -> PackedScene:
	return load(scene_path(id)) as PackedScene


## Breite eines Haustyps in Metern.
static func width_of(id: String) -> float:
	return float(_value(id, "width", 5.0))


## Tiefe eines Haustyps in Metern.
static func depth_of(id: String) -> float:
	return float(_value(id, "depth", 8.0))


## Wert einer Eigenschaft direkt aus der gespeicherten Szene (ohne sie zu bauen).
static func _value(id: String, property: String, fallback: Variant) -> Variant:
	var key := id + ":" + property
	if not _cache.has(key):
		var value: Variant = fallback
		var scene := get_scene(id)
		if scene:
			var state := scene.get_state()
			for i in state.get_node_property_count(0):
				if state.get_node_property_name(0, i) == property:
					value = state.get_node_property_value(0, i)
		_cache[key] = value
	return _cache[key]
