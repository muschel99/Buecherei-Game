class_name PersonNames
extends RefCounted
## Namen für Gäste mit Leseausweis (seit dem Nachtest von Etappe 8, Wunsch der Entwicklerin: „Namen passen nicht zur Figur“):
## Vornamen getrennt nach Frauen und Männern aus data/visitors/names.txt (Aufbau oben in der Datei), dazu Nachnamen. Der Name
## eines neuen Ausweises passt immer zur Figur (Passerby.is_female). gender_of erkennt außerdem die alten, ausgedachten Namen
## früherer Spielstände (damals ohne Frau/Mann gewählt).

const PATH := "res://data/visitors/names.txt"
## Vornamen der alten Ausweise (BookData.FIRST_NAMES, bis zum Nachtest von Etappe 8): welche davon Frauennamen sind
const OLD_FEMALE := ["Hattie", "Elsa", "Ada", "Ruth", "Ingrid", "Greta", "Mabel", "Juno", "Lotte", "Clara", "Ivy", "Nell", "Rosa",
	"Frieda", "Wilma", "Tilda", "Agnes", "Paula", "Pippa", "Ottilie", "Marlene", "Hedda", "Imogen"]

static var _lists: Dictionary = {}  # "frauen" / "maenner" / "nachnamen" → PackedStringArray


static func _load() -> void:
	if not _lists.is_empty():
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	var current := ""
	while file and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			current = line.trim_prefix("==").strip_edges()
			_lists[current] = PackedStringArray()
			continue
		if not current.is_empty():
			(_lists[current] as PackedStringArray).append(line)
	for key in ["frauen", "maenner", "nachnamen"]:
		if not _lists.has(key) or (_lists[key] as PackedStringArray).is_empty():
			_lists[key] = PackedStringArray(["Anna"] if key == "frauen" else (["Karl"] if key == "maenner" else ["Sommer"]))


## Ein Vor- und Nachname, passend zur Figur.
static func random_name(female: bool, rng: RandomNumberGenerator) -> String:
	_load()
	var first: PackedStringArray = _lists["frauen" if female else "maenner"]
	var last: PackedStringArray = _lists["nachnamen"]
	return "%s %s" % [first[rng.randi() % first.size()], last[rng.randi() % last.size()]]


## Frau (1), Mann (0) oder unbekannt (-1) nach dem Vornamen (Liste, alte ausgedachte Namen).
static func gender_of(full_name: String) -> int:
	_load()
	var first: String = full_name.strip_edges().split(" ", false)[0] if not full_name.strip_edges().is_empty() else ""
	if first in (_lists["frauen"] as PackedStringArray) or first in OLD_FEMALE:
		return 1
	if first in (_lists["maenner"] as PackedStringArray) or first in BookData.FIRST_NAMES:
		return 0
	return -1
