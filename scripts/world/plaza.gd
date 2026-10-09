class_name Plaza
extends Node3D
## Der kleine gepflasterte Platz vor der abgeschrägten Ecke und dem Eingang der Gasse
## (seit Etappe 4d). Er entsteht, weil die Häuser hinter der Gasse zurückversetzt stehen:
## von der Schräge bis zum Ende der Häuserreihe, zwischen Gehweg und Hausfronten.
## Bewusst leer und kompakt; dieselben großen Platten wie auf dem Gehweg. Liegt (wie alles unter "Outside") auf Gehweg-Höhe.
## Laufen: Die Bodenkollision baut die Straße (Street) für alles draußen.

@export var material: Material = preload("res://assets/materials/sidewalk.tres")


func _ready() -> void:
	var front := StreetLayout.HOUSE_FRONT
	var back := StreetLayout.recess_z()
	var points := PackedVector2Array([
		Vector2(StreetLayout.diagonal_front_x(), front),
		Vector2(StreetLayout.HOUSE_LEFT, back),
		Vector2(StreetLayout.west_end_x(), back),
		Vector2(StreetLayout.west_end_x(), front),
	])
	var builder := WorldMesh.new()
	builder.add_floor(points, 0.0, Color.WHITE)
	add_child(builder.make_instance("Paving", material, false))
