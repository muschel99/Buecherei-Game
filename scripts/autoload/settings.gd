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
	{"key": "display/max_fps", "section": "Bildschirm", "label": "Bildrate begrenzen",
		"type": "choice", "options": ["30", "60", "120", "unbegrenzt"], "default": 1},
	{"key": "graphics/quality", "section": "Grafik", "label": "Grafikqualität",
		"type": "choice", "options": ["Niedrig", "Mittel", "Hoch"], "default": 1},
	{"key": "graphics/show_fps", "section": "Grafik", "label": "Bilder pro Sekunde anzeigen (F3)",
		"type": "toggle", "default": false},
]

## Bildraten zur Auswahl "Bildrate begrenzen" (0 = unbegrenzt).
const MAX_FPS_OPTIONS: Array[int] = [30, 60, 120, 0]

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
		"display/max_fps":
			apply_frame_limit()
		"graphics/quality":
			_apply_graphics_quality()


## Bildrate begrenzen. Im Pausenmenü zusätzlich auf GameConfig.paused_max_fps.
func apply_frame_limit() -> void:
	var limit := MAX_FPS_OPTIONS[clampi(int(get_value("display/max_fps")), 0, MAX_FPS_OPTIONS.size() - 1)]
	if get_tree().paused and GameConfig.paused_max_fps > 0:
		limit = GameConfig.paused_max_fps if limit == 0 else mini(limit, GameConfig.paused_max_fps)
	Engine.max_fps = limit


## Werte der gewählten Grafikstufe (siehe GameConfig.graphics_presets).
func get_graphics_preset() -> Dictionary:
	var level := clampi(int(get_value("graphics/quality")), 0, GameConfig.graphics_presets.size() - 1)
	return GameConfig.graphics_presets[level]


## Alles, was nicht zu einer bestimmten Szene gehört: Schattenauflösung, Kantenglättung,
## 3D-Auflösung. Umgebung (SSAO, Nebel …) und Lampen reagieren selbst auf setting_changed.
func _apply_graphics_quality() -> void:
	var preset := get_graphics_preset()
	var viewport := get_tree().root
	var size: int = preset.shadow_size
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	viewport.positional_shadow_atlas_size = size
	var filter: int = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][clampi(preset.soft_shadows, 0, 2)]
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	viewport.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}.get(int(preset.msaa), Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.scaling_3d_scale = preset.render_scale


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
