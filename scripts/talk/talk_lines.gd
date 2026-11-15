class_name TalkLines
extends RefCounted
## Sätze für Gespräche (seit Etappe 8) aus data/talk/talk.txt (Aufbau steht oben in der Datei). Abschnitte gruss, plaudern,
## frage, tschuess; Zeilen mit @morgen/@mittag/@abend/@nacht gelten nur zu dieser Tageszeit; bei „frage“ folgen Antworten
## (> Antwort | Satz). Gelesen wird einmal beim ersten Gespräch.

const PATH := "res://data/talk/talk.txt"
const TIMES := {"morgen": Vector2(5, 11), "mittag": Vector2(11, 17), "abend": Vector2(17, 22), "nacht": Vector2(22, 5)}

static var _sections: Dictionary = {}  # Abschnitt → Array[{text, time, answers: Array[{text, reply}]}]


static func _load() -> void:
	if not _sections.is_empty():
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var current := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			current = line.trim_prefix("==").strip_edges()
			_sections[current] = []
			continue
		if current.is_empty():
			continue
		var entries: Array = _sections[current]
		if line.begins_with(">"):
			if entries.is_empty():
				continue
			var parts := line.trim_prefix(">").split("|", true, 1)
			(entries.back().answers as Array).append({"text": parts[0].strip_edges(),
				"reply": parts[1].strip_edges() if parts.size() > 1 else ""})
			continue
		var time := ""
		if line.begins_with("@"):
			var space := line.find(" ")
			time = line.substr(1, space - 1) if space > 0 else line.substr(1)
			line = line.substr(space + 1).strip_edges() if space > 0 else ""
		entries.append({"text": line, "time": time, "answers": []})


## Ein zufälliger Eintrag aus dem Abschnitt, der zur Uhrzeit passt (leer, wenn es keinen gibt).
static func pick(section: String, hour: float, rng: RandomNumberGenerator) -> Dictionary:
	_load()
	var fitting: Array = []
	for entry: Dictionary in _sections.get(section, []):
		var time: String = entry.time
		if time.is_empty() or _in_time(time, hour):
			fitting.append(entry)
	if fitting.is_empty():
		return {}
	return fitting[rng.randi() % fitting.size()]


static func _in_time(time: String, hour: float) -> bool:
	var span: Vector2 = TIMES.get(time, Vector2(0, 24))
	if span.x <= span.y:
		return hour >= span.x and hour < span.y
	return hour >= span.x or hour < span.y
