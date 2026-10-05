extends PanelContainer
## Einstellungsbereich im Pausenmenü.
##
## Baut sich aus Settings.DEFINITIONS selbst auf: Für jede Einstellung entsteht eine
## Zeile mit Namen und passendem Bedienelement. Neue Einstellungen erscheinen hier
## also automatisch, sobald sie in scripts/autoload/settings.gd eingetragen sind.

## Wird gesendet, wenn "Zurück" gedrückt wurde.
signal back_requested

const SECTION_COLOR := Color(0.96, 0.78, 0.48)
const HINT_COLOR := Color(0.85, 0.78, 0.68, 0.8)

@onready var _rows: VBoxContainer = %Rows
@onready var _back_button: Button = %SettingsBackButton

var _resolution_button: OptionButton
var _window_mode_button: OptionButton
var _resolution_hint: Label


func _ready() -> void:
	_build()
	_back_button.pressed.connect(func() -> void: back_requested.emit())


## Beim Öffnen: Werte auffrischen und den Zurück-Knopf auswählen.
func open() -> void:
	show()
	_refresh_resolution()
	_back_button.grab_focus()


func _build() -> void:
	var current_section := ""
	var grid: GridContainer = null
	for definition in Settings.DEFINITIONS:
		if definition.section != current_section:
			current_section = definition.section
			var header := Label.new()
			header.text = current_section
			header.add_theme_color_override("font_color", SECTION_COLOR)
			_rows.add_child(header)
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 32)
			grid.add_theme_constant_override("v_separation", 12)
			_rows.add_child(grid)
		var label := Label.new()
		label.text = definition.label
		grid.add_child(label)
		grid.add_child(_create_control(definition))
	_resolution_hint = Label.new()
	_resolution_hint.add_theme_font_size_override("font_size", 16)
	_resolution_hint.add_theme_color_override("font_color", HINT_COLOR)
	_rows.add_child(_resolution_hint)


## Passendes Bedienelement je Art der Einstellung.
func _create_control(definition: Dictionary) -> Control:
	var key: String = definition.key
	match definition.type:
		"choice":
			var choice := OptionButton.new()
			for option in definition.options:
				choice.add_item(option)
			choice.select(int(Settings.get_value(key)))
			if key == "display/window_mode":
				_window_mode_button = choice
			choice.item_selected.connect(func(index: int) -> void:
				Settings.set_value(key, index)
				_refresh_resolution())
			return _sized(choice)
		"toggle":
			var toggle := CheckButton.new()
			toggle.button_pressed = bool(Settings.get_value(key))
			toggle.text = "an" if toggle.button_pressed else "aus"
			toggle.toggled.connect(func(on: bool) -> void:
				toggle.text = "an" if on else "aus"
				Settings.set_value(key, on))
			return _sized(toggle)
		"resolution":
			_resolution_button = OptionButton.new()
			_resolution_button.item_selected.connect(func(index: int) -> void:
				Settings.set_value(key, _resolution_button.get_item_text(index)))
			return _sized(_resolution_button)
	return Label.new()


func _sized(control: Control) -> Control:
	control.custom_minimum_size = Vector2(240, 0)
	return control


## Auflösungsliste füllen; im Vollbild gilt die Bildschirmauflösung.
## Läuft das Spiel im Editor eingebettet, sind Anzeige und Auflösung gesperrt.
func _refresh_resolution() -> void:
	if _resolution_button == null:
		return
	_resolution_button.clear()
	var current: String = Settings.get_value("display/resolution")
	var options := Settings.get_resolution_options()
	for i in options.size():
		_resolution_button.add_item(options[i])
		if options[i] == current:
			_resolution_button.select(i)
	_resolution_button.disabled = Settings.is_fullscreen() or Settings.is_embedded()
	if _window_mode_button:
		_window_mode_button.disabled = Settings.is_embedded()
	if Settings.is_embedded():
		_resolution_hint.text = "Das Spiel läuft im Godot-Editor eingebettet. Vollbild und Auflösung\nwirken nur, wenn das Spiel in einem eigenen Fenster läuft."
	elif Settings.is_fullscreen():
		_resolution_hint.text = "Im Vollbild wird die Auflösung des Bildschirms verwendet."
	else:
		_resolution_hint.text = ""
