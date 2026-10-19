class_name Plaza
extends Node3D
## Der kleine gepflasterte Platz vor der abgeschrägten Ecke und dem Eingang der Gasse
## (seit Etappe 4d). Er entsteht, weil die Häuser hinter der Gasse zurückversetzt stehen:
## von der Schräge bis zum Ende der Häuserreihe, zwischen Gehweg und Hausfronten.
## Bewusst leer und kompakt; dieselben großen Platten wie auf dem Gehweg. Liegt (wie alles unter "Outside") auf Gehweg-Höhe.
## Laufen: Die Bodenkollision baut die Straße (Street) für alles draußen.

@export var material: Material = preload("res://assets/materials/sidewalk.tres")
## Bäumchen im Kübel: (x, Abstand vor den zurückgesetzten Hausfronten nach -z) – leer = keine.
## (Die Ecke am Ende der Häuserreihe hat seit dem Stil-Umbau ein Eckbeet am Haus LibraryRow/Neighbor4.)
@export var tree_spots: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	var front := StreetLayout.HOUSE_FRONT
	var back := StreetLayout.recess_z()
	var points := PackedVector2Array([
		Vector2(StreetLayout.diagonal_front_x(), front),
		Vector2(StreetLayout.HOUSE_LEFT, back),
		Vector2(StreetLayout.alley_row_end_x(), back),
		Vector2(StreetLayout.alley_row_end_x(), front),
	])
	var builder := WorldMesh.new()
	builder.add_floor(points, 0.0, Color.WHITE)
	add_child(builder.make_instance("Paving", material, false))
	_add_plant_spots()


## Pflanzplätze für Bäumchen im Kübel (Stil-Umbau, Schritt 5): Greenery setzt dort Pflanzen mit
## eigener Kollision ein. Lage: vor dem Ende der Häuserreihe und an der Ecke des Pubs zur Gasse.
func _add_plant_spots() -> void:
	var back := StreetLayout.recess_z()
	for spot in tree_spots:
		var marker := Marker3D.new()
		marker.name = "PlantSpot_tubtree_%d" % get_child_count()
		marker.position = Vector3(spot.x, 0.0, back + spot.y)
		marker.set_meta("extras", {"kind": "tubtree", "width": 0.9, "depth": 0.9, "height": 3.0})
		add_child(marker)
