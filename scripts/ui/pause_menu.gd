extends CanvasLayer
## Pausenmenü: öffnet sich mit Esc – aber nur, wenn nichts anderes offen ist.
##
## Esc schließt immer zuerst das, was gerade offen ist (Gestaltungsmodus, Menüs …,
## siehe MenuStack). Erst wenn nichts offen ist, öffnet Esc dieses Menü.
## Hält das Spiel an, gibt die Maus frei und bietet Weiter, Steuerung, Einstellungen
## und Beenden.
## Dieser Knoten läuft auch bei pausiertem Spiel weiter (Process Mode "Always").

@onready var _main_panel: Control = $MainPanel
@onready var _controls_panel: Control = $ControlsPanel
@onready var _settings_panel: Control = $SettingsPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _controls_back_button: Button = %BackButton


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible and (_controls_panel.visible or _settings_panel.visible):
		_show_main_panel()  # Esc in einem Unterbereich = zurück
	elif visible:
		resume()
	elif not MenuStack.close_top():
		open()  # Nichts anderes war offen
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Spiel anhalten, wenn man zu einem anderen Fenster wechselt
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameConfig.pause_on_focus_loss and not visible:
		open()


func open() -> void:
	show()
	_show_main_panel()
	get_tree().paused = true
	Settings.apply_frame_limit()  # im Pausenmenü weniger Bilder pro Sekunde (spart Strom)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	hide()
	get_tree().paused = false
	Settings.apply_frame_limit()
	# Maus so einstellen, wie es das gerade Geöffnete braucht (z. B. Katalog = Mauszeiger sichtbar)
	MenuStack.restore_mouse_mode()


func _show_main_panel() -> void:
	_main_panel.show()
	_controls_panel.hide()
	_settings_panel.hide()
	_resume_button.grab_focus()


func _on_resume_button_pressed() -> void:
	resume()


func _on_controls_button_pressed() -> void:
	_main_panel.hide()
	_controls_panel.show()
	_controls_back_button.grab_focus()


func _on_settings_button_pressed() -> void:
	_main_panel.hide()
	_settings_panel.open()


func _on_back_button_pressed() -> void:
	_show_main_panel()


func _on_quit_button_pressed() -> void:
	# Vor dem Beenden die Einrichtung speichern
	SaveManager.quit_game()
