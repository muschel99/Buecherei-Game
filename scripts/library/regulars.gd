class_name Regulars
extends RefCounted
## Stammgäste der Bücherei (seit Etappe 8) aus data/visitors/regulars.txt: Name, Lieblingsgenre, Art des Besuchs. Jeder hat
## einen festen Ausweis (Kennung "stamm_<n>" in Lending.readers – Stempel, Besuche, Freundschaft) und sieht immer gleich aus
## (Aussehen aus dem Namen ausgewürfelt). LibraryVisits macht aus manchen Passanten auf dem Weg zur Bücherei einen Stammgast.

const PATH := "res://data/visitors/regulars.txt"
## Arten des Besuchs (auch für Unbekannte, mit Gewichten in GameConfig.visit_style_weights)
const STYLES := ["zielstrebig", "stoebert", "liest", "zurueck"]

static var _list: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _list.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file:
			while not file.eof_reached():
				var line := file.get_line().strip_edges()
				if line.is_empty() or line.begins_with("#"):
					continue
				var parts := line.split("|")
				if parts.size() < 3:
					continue
				var style := parts[2].strip_edges()
				_list.append({"id": "stamm_%d" % (_list.size() + 1), "name": parts[0].strip_edges(),
					"genre": parts[1].strip_edges(), "style": style if style in STYLES else "stoebert",
					"seed": hash(parts[0].strip_edges())})
	return _list


static func find(id: String) -> Dictionary:
	for entry in all():
		if entry.id == id:
			return entry
	return {}
