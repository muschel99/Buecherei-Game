extends CanvasLayer
## Pausenmenü: öffnet sich mit Esc.
##
## Hält das Spiel an, gibt die Maus frei und bietet Weiter, Steuerung und Beenden.
## Dieser Knoten läuft auch bei pausiertem Spiel weiter (Process Mode "Always").

@onready var _main_panel: Control = $MainPanel
@onready var _controls_panel: Control = $ControlsPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _controls_back_button: Button = %BackButton


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not visible:
		open()
	elif _controls_panel.visible:
		_show_main_panel()  # Esc in der Tastenübersicht = zurück
	else:
		resume()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Spiel anhalten, wenn man zu einem anderen Fenster wechselt
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameConfig.pause_on_focus_loss and not visible:
		open()


func open() -> void:
	show()
	_show_main_panel()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_main_panel() -> void:
	_main_panel.show()
	_controls_panel.hide()
	_resume_button.grab_focus()


func _on_resume_button_pressed() -> void:
	resume()


func _on_controls_button_pressed() -> void:
	_main_panel.hide()
	_controls_panel.show()
	_controls_back_button.grab_focus()


func _on_back_button_pressed() -> void:
	_show_main_panel()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
