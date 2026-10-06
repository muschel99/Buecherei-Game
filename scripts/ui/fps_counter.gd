extends CanvasLayer
## Kleine Anzeige der Bilder pro Sekunde (FPS) oben rechts – zum Testen, wie flüssig
## das Spiel läuft. Ein- und ausschalten mit F3 oder unter Esc → Einstellungen.

@onready var _label: Label = %FpsLabel

var _time_since_update := 0.0


func _ready() -> void:
	visible = bool(Settings.get_value("graphics/show_fps"))
	Settings.setting_changed.connect(_on_setting_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		Settings.set_value("graphics/show_fps", not bool(Settings.get_value("graphics/show_fps")))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	# Nur zweimal pro Sekunde auffrischen, damit die Zahl ruhig lesbar bleibt
	_time_since_update += delta
	if _time_since_update >= 0.5:
		_time_since_update = 0.0
		_label.text = "%d FPS" % Engine.get_frames_per_second()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "graphics/show_fps":
		visible = bool(value)
