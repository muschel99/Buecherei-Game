@tool
class_name StyleTags
extends RefCounted
## Die Einrichtungs-Stile des Spiels (Hilfsfunktionen rund um die Stil-Datenblätter).
##
## Die Stile selbst sind Datenblätter in data/styles/ (StyleData) – ein neuer Stil ist eine
## neue Datei, kein Code. Möbel, Wandfarben, Böden und Genres tragen ihre Stile als Liste von
## ids (Feld "style_ids", z. B. ["dark_academia"]). Leere Liste = stilneutral.
## Der Stil dient nur dem Einrichten: Filter in Shop und Gestaltungsmodus, Stilanzeige.
## Diese Klasse liest den Ordner selbst ein, damit sie auch im Editor (Inspektor) funktioniert.

const FOLDER := "res://data/styles/"

## Alte Spielstände und Datenblätter speicherten Stile als Zahl (1 Botanisch, 2 Modern,
## 4 Dark Academia). So werden sie auf die heutigen Stile übertragen.
const LEGACY_FLAGS := {
	1: "country",
	2: "minimalist",
	4: "dark_academia",
}

static var _styles: Array[StyleData] = []
static var _by_id: Dictionary = {}


## Alle Stile, sortiert nach "Order" und Name.
static func all() -> Array[StyleData]:
	_ensure_loaded()
	return _styles


## Alle Stil-ids in Anzeige-Reihenfolge.
static func ids() -> Array[String]:
	var result: Array[String] = []
	for style in all():
		result.append(style.get_id())
	return result


## Datenblatt eines Stils (oder null).
static func get_style(id: String) -> StyleData:
	_ensure_loaded()
	return _by_id.get(id)


## Anzeigename, z. B. "Dark Academia" (unbekannte id: die id selbst).
static func get_display_name(id: String) -> String:
	var style := get_style(id)
	return style.display_name if style else id


static func get_color(id: String) -> Color:
	var style := get_style(id)
	return style.color if style else Color.WHITE


## Nur die ids, die es wirklich gibt (in Anzeige-Reihenfolge).
static func known(style_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in ids():
		if style_ids.has(id):
			result.append(id)
	return result


## Wandelt die alte Zahl (Häkchen-Liste) in Stil-ids um, z. B. 5 -> ["country", "dark_academia"].
static func from_legacy_flags(flags: int) -> Array[String]:
	var result: Array[String] = []
	for bit in LEGACY_FLAGS:
		if flags & bit:
			result.append(LEGACY_FLAGS[bit])
	return result


## Berechnet, wie stark jeder Stil vertreten ist.
## Erwartet eine Liste von Stil-Listen (z. B. von allen platzierten Möbeln).
## Jedes Objekt zählt einen Punkt; hat es mehrere Stile, wird der Punkt aufgeteilt.
## Ergebnis: Stil-id -> Anteil zwischen 0.0 und 1.0 (zusammen 1.0, oder alles 0 ohne Möbel).
static func calculate_shares(style_lists: Array) -> Dictionary:
	var shares := {}
	for id in ids():
		shares[id] = 0.0
	var total := 0.0
	for list in style_lists:
		var styles := known(list)
		if styles.is_empty():
			continue
		total += 1.0
		for id in styles:
			shares[id] += 1.0 / styles.size()
	if total > 0.0:
		for id in shares:
			shares[id] /= total
	return shares


## Für den Inspektor: Hinweis-Text, mit dem eine Liste von Stil-ids als Auswahlfelder erscheint.
static func inspector_hint_string() -> String:
	return "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(ids())]


## Liest data/styles/ neu ein (z. B. nachdem im Editor ein Stil dazugekommen ist).
static func reload() -> void:
	_styles.clear()
	_by_id.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if not _styles.is_empty():
		return
	# list_directory funktioniert auch im fertig exportierten Spiel
	for file_name in ResourceLoader.list_directory(FOLDER):
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var style := load(FOLDER + file_name) as StyleData
		if style == null or _by_id.has(style.get_id()):
			continue
		_styles.append(style)
		_by_id[style.get_id()] = style
	_styles.sort_custom(func(a: StyleData, b: StyleData) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return a.display_name < b.display_name)
