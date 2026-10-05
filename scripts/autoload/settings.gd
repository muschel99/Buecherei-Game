extends Node
## Spieler-Einstellungen (Bildschirm, später z. B. Lautstärke und Mausempfindlichkeit).
##
## Die Einstellungen stehen in einer eigenen Datei (user://settings.cfg), getrennt vom
## Spielstand, und werden beim Spielstart automatisch geladen und angewendet.
##
## Eine neue Einstellung hinzufügen:
## 1. In DEFINITIONS einen Eintrag ergänzen (Schlüssel, Bereich, Name, Art, Standardwert).
## 2. In _apply() festlegen, was beim Ändern passieren soll.
## Der Einstellungsbereich im Pausenmenü baut sich aus DEFINITIONS selbst auf.

## Wird gesendet, wenn sich eine Einstellung geändert hat.
signal setting_changed(key: String, value: Variant)

const FILE_PATH := "user://settings.cfg"

## Gängige Auflösungen (Breite x Höhe), inklusive Ultrawide.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

## Alle Einstellungen. Arten: "choice" (Auswahlliste), "toggle" (an/aus),
## "resolution" (Auflösungsliste), später z. B. "slider" (Schieberegler).
const DEFINITIONS: Array[Dictionary] = [
	{"key": "display/window_mode", "section": "Bildschirm", "label": "Anzeige",
		"type": "choice", "options": ["Fenster", "Vollbild"], "default": 0},
	{"key": "display/resolution", "section": "Bildschirm", "label": "Auflösung (Fenster)",
		"type": "resolution", "default": "1600x900"},
	{"key": "display/vsync", "section": "Bildschirm", "label": "VSync",
		"type": "toggle", "default": true},
]

var _values := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	for definition in DEFINITIONS:
		_apply(definition.key)


## Aktueller Wert einer Einstellung.
func get_value(key: String) -> Variant:
	return _values.get(key, _definition(key).get("default"))


## Ändert eine Einstellung, wendet sie sofort an und speichert.
func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	_apply(key)
	_save()
	setting_changed.emit(key, value)


## Auflösungen, die auf diesen Bildschirm passen, als Text ("1920x1080").
func get_resolution_options() -> Array[String]:
	var screen := DisplayServer.screen_get_size()
	var options: Array[String] = []
	for resolution in RESOLUTIONS:
		if screen == Vector2i.ZERO or (resolution.x <= screen.x and resolution.y <= screen.y):
			options.append("%dx%d" % [resolution.x, resolution.y])
	var current: String = get_value("display/resolution")
	if not options.has(current):
		options.append(current)
	return options


func is_fullscreen() -> bool:
	return int(get_value("display/window_mode")) == 1


## Läuft das Spiel im Godot-Editor eingebettet (Reiter "Game")? Dann bestimmt der Editor
## Größe und Lage des Spielbilds – Vollbild und Auflösung wirken nur im eigenen Fenster.
func is_embedded() -> bool:
	return Engine.is_embedded_in_editor()


## Setzt eine Einstellung im Spiel um.
func _apply(key: String) -> void:
	match key:
		"display/window_mode", "display/resolution":
			_apply_window()
		"display/vsync":
			var vsync := DisplayServer.VSYNC_ENABLED if get_value(key) else DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(vsync)


## Vollbild nutzt die Auflösung des Bildschirms; im Fenster gilt die gewählte Auflösung.
## Alle Menüs passen sich über die Projekteinstellung "Stretch" automatisch an.
func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Im Editor eingebettet: Fenster nicht anfassen. Würde das Spiel hier Größe oder Lage
	# ändern, passten Spielbild und Mausposition nicht mehr zusammen.
	if is_embedded():
		return
	var window := get_window()
	if is_fullscreen():
		window.mode = Window.MODE_FULLSCREEN
		return
	var was_fullscreen := window.mode != Window.MODE_WINDOWED
	window.mode = Window.MODE_WINDOWED
	if was_fullscreen:
		# Manche Fenstermanager (z. B. unter Linux) übernehmen die Größe erst,
		# wenn der Wechsel aus dem Vollbild abgeschlossen ist
		await get_tree().process_frame
		await get_tree().process_frame
	var parts := str(get_value("display/resolution")).split("x")
	if parts.size() != 2:
		return
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var screen := DisplayServer.screen_get_size()
	if screen != Vector2i.ZERO:
		size = size.min(screen)
	window.size = size
	# Fenster mittig auf den Bildschirm setzen (unter Wayland legt das System die Lage
	# selbst fest, dann wird dieser Wunsch einfach ignoriert)
	var screen_position := DisplayServer.screen_get_position()
	window.position = screen_position + (screen - size) / 2


func _definition(key: String) -> Dictionary:
	for definition in DEFINITIONS:
		if definition.key == key:
			return definition
	return {}


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(FILE_PATH) != OK:
		return
	for definition in DEFINITIONS:
		var parts: PackedStringArray = definition.key.split("/")
		if file.has_section_key(parts[0], parts[1]):
			_values[definition.key] = file.get_value(parts[0], parts[1])


func _save() -> void:
	var file := ConfigFile.new()
	for key in _values:
		var parts: PackedStringArray = key.split("/")
		file.set_value(parts[0], parts[1], _values[key])
	file.save(FILE_PATH)
