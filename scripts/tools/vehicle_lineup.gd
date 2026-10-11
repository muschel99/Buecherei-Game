extends Node3D
## Ansicht aller Fahrzeuge (scenes/tools/vehicle_lineup.tscn): Farben wie auf der Straße setzen
## (Taxi schwarz, die anderen eine Farbe aus GameConfig.car_colors).


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	var colors := GameConfig.car_colors
	var i := 0
	for child in get_children():
		if child is StreetVehicle:
			var color: Color = GameConfig.delivery_van_color if child is DeliveryVan else colors[(i * 2 + 1) % colors.size()]
			(child as StreetVehicle).randomize_look(rng, color)
			# Straßenfahrzeuge sind versteckt, bis das Straßenleben sie losschickt – hier sichtbar
			child.visible = true
			i += 1
