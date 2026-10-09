extends Node
## Speichert und lädt den Spielstand.
##
## So funktioniert es: Jeder Knoten, der etwas speichern möchte, kommt in die
## Gruppe "persist" und hat
##   - eine Variable save_key (eindeutiger Name im Spielstand),
##   - eine Funktion get_save_data() -> Dictionary,
##   - eine Funktion load_save_data(data: Dictionary).
## Der SaveManager sammelt diese Daten ein und schreibt sie in eine JSON-Datei.
## In Etappe 5 kommen so z. B. Geld und Tageszeit einfach als weitere Knoten dazu.
##
## Gespeichert wird automatisch kurz nach jeder Änderung und beim Beenden.

const PERSIST_GROUP := "persist"
## Version des Speicherformats (hochzählen, wenn sich das Format grundlegend ändert).
## Etappe 4a: Der Laden wurde zum Eckladen umgebaut und startet fast leer – alte Spielstände
## (Version 1) passen nicht mehr zur neuen Raumform und werden deshalb ignoriert (siehe
## load_game). Es beginnt dann ein frisches Spiel; die alte Datei wird beim nächsten
## Speichern einfach überschrieben.
const SAVE_VERSION := 2

var _autosave_timer: Timer
var _is_loading := false


func _ready() -> void:
	# Auch im Pausenmenü weiterlaufen, damit dort ebenfalls gespeichert werden kann
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Beim Schließen des Fensters erst speichern, dann beenden
	get_tree().auto_accept_quit = false
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Speichert und beendet das Spiel.
func quit_game() -> void:
	save_game()
	get_tree().quit()


## Merkt vor, bald zu speichern (mehrere Änderungen kurz hintereinander = ein Speichervorgang).
func request_save() -> void:
	if _is_loading:
		return
	_autosave_timer.start(GameConfig.autosave_delay)


func has_save() -> bool:
	return FileAccess.file_exists(GameConfig.save_file_path)


func save_game() -> void:
	_autosave_timer.stop()
	var nodes := {}
	for node in get_tree().get_nodes_in_group(PERSIST_GROUP):
		nodes[node.save_key] = node.get_save_data()
	var save_data := {
		"version": SAVE_VERSION,
		"nodes": nodes,
	}
	var file := FileAccess.open(GameConfig.save_file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(save_data, "\t"))


## Lädt den Spielstand (falls vorhanden) in alle Knoten der Gruppe "persist".
## Wird von der Hauptszene aufgerufen, sobald alles bereit ist.
func load_game() -> void:
	if not has_save():
		return
	var text := FileAccess.get_file_as_string(GameConfig.save_file_path)
	var save_data = JSON.parse_string(text)
	if not save_data is Dictionary or not save_data.get("nodes") is Dictionary:
		push_warning("Spielstand ist beschädigt und wird ignoriert: %s" % GameConfig.save_file_path)
		return

	# Passt der Spielstand nicht mehr zum aktuellen Format (z. B. ein alter Rechteck-Laden von
	# vor dem Eckladen-Umbau), wird er ignoriert – es beginnt ein frisches Spiel.
	var version := int(save_data.get("version", 1))
	if version != SAVE_VERSION:
		push_warning("Spielstand hat eine ältere Version (%d statt %d) und wird ignoriert – es beginnt ein frisches Spiel." % [version, SAVE_VERSION])
		return

	_is_loading = true
	var nodes: Dictionary = save_data["nodes"]
	for node in get_tree().get_nodes_in_group(PERSIST_GROUP):
		if nodes.has(node.save_key) and nodes[node.save_key] is Dictionary:
			node.load_save_data(nodes[node.save_key])
	_is_loading = false


## Löscht den Spielstand (beim nächsten Start ist alles wieder wie am Anfang).
func delete_save() -> void:
	_autosave_timer.stop()
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameConfig.save_file_path))
