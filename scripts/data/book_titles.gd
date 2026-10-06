class_name BookTitles
extends RefCounted
## Erfindet Buchtitel aus Wortlisten – zu jedem Genre passend, keine echten Titel.
##
## Die Wortlisten stehen in Textdateien in data/book_titles/ (eine Datei je Genre, z. B.
## crime.txt). Aufbau einer Datei:
##   # Zeilen mit # am Anfang sind Kommentare
##   [Vorlagen]
##   Mord {Wo}
##   {Ding} von {Ort}
##   [Wo]
##   im Pfarrgarten
##   [Ding]
##   Die stille Uhr
##   [Ort]
##   Ashcombe
## Unter [Vorlagen] stehen Satzmuster. Jedes {Name} wird durch einen zufälligen Eintrag
## aus der Liste [Name] ersetzt. Neue Einträge = einfach neue Zeilen; neue Listen = eine
## neue Überschrift in eckigen Klammern.

const PATTERN_SECTION := "Vorlagen"
## So oft darf ein Eintrag selbst wieder {Platzhalter} enthalten (Schutz vor Endlosschleifen)
const MAX_DEPTH := 4

## Bereits gelesene Dateien: Pfad -> { Listenname: Array[String] }
static var _cache: Dictionary = {}


## Ein erfundener Titel für dieses Genre.
static func generate(genre: GenreData) -> String:
	if genre == null:
		return "Ein Buch ohne Titel"
	var lists := _load_lists(genre.get_title_words_path())
	var patterns: Array = lists.get(PATTERN_SECTION, [])
	if patterns.is_empty():
		return "Ein %s-Buch" % genre.display_name
	return _fill(patterns.pick_random(), lists, 0)


## Ersetzt alle {Platzhalter} durch zufällige Einträge der passenden Liste.
static func _fill(text: String, lists: Dictionary, depth: int) -> String:
	var result := text
	var start := result.find("{")
	while start >= 0 and depth < MAX_DEPTH:
		var end := result.find("}", start)
		if end < 0:
			break
		var list_name := result.substr(start + 1, end - start - 1).strip_edges()
		var words: Array = lists.get(list_name, [])
		var word: String = _fill(words.pick_random(), lists, depth + 1) if not words.is_empty() else list_name
		result = result.substr(0, start) + word + result.substr(end + 1)
		start = result.find("{", start + word.length())
	return result


## Liest eine Wortlisten-Datei (einmal, danach aus dem Zwischenspeicher).
static func _load_lists(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var lists := {}
	if FileAccess.file_exists(path):
		var current := ""
		for raw_line in FileAccess.get_file_as_string(path).split("\n"):
			var line := raw_line.strip_edges()
			if line.is_empty() or line.begins_with("#"):
				continue
			if line.begins_with("[") and line.ends_with("]"):
				current = line.substr(1, line.length() - 2).strip_edges()
				if not lists.has(current):
					lists[current] = []
			elif not current.is_empty():
				lists[current].append(line)
	else:
		push_warning("Buchtitel: Wortliste '%s' nicht gefunden – Bücher bekommen einen schlichten Titel." % path)
	_cache[path] = lists
	return lists
