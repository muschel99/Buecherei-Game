extends Node
## Testtasten zum Ausprobieren während der Entwicklung (Autoload "DebugKeys").
##
## F9  (Aktion "debug_fill_return_box"): ein paar Bücher in den Rückgabekasten legen,
##      solange es noch keine Besucher gibt.
## F10 (Aktion "debug_add_money"): Testgeld (GameConfig.debug_money_amount) dazubekommen.
##
## Alle Testtasten auf einmal abschalten: in GameConfig debug_keys_enabled = false setzen.


func _unhandled_input(event: InputEvent) -> void:
	if not GameConfig.debug_keys_enabled:
		return
	if event.is_action_pressed("debug_fill_return_box"):
		BookStock.fill_return_box_for_testing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_add_money"):
		Wallet.earn(GameConfig.debug_money_amount, "Testgeld")
		get_viewport().set_input_as_handled()
