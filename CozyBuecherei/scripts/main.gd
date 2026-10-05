extends Node3D
## Hauptszene. Lädt beim Start den gespeicherten Spielstand (falls vorhanden).


func _ready() -> void:
	# Alle Knoten der Szene sind jetzt bereit – also können sie ihre Daten übernehmen
	SaveManager.load_game()
