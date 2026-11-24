extends Node
## Schreibt die Lage der Gassen (aus StreetLayout und GameConfig) nach
## assets/models/source/layout.json – das lesen die Blender-Scripts (tools/blender/build_alleys.py),
## damit die Modelle genau passen. Starten: godot --headless --path . res://scenes/tools/export_layout.tscn


func _ready() -> void:
	var first_house: String = GameConfig.alley_house_types[0] if not GameConfig.alley_house_types.is_empty() else ""
	var span := StreetLayout.opposite_alley()
	var data := {
		"library_x": StreetLayout.HOUSE_LEFT,
		"far_x": StreetLayout.alley_far_x(),
		"alley_start_z": StreetLayout.recess_z(),
		"alley_end_z": StreetLayout.alley_end_z(),
		"library_back_z": StreetLayout.HOUSE_BACK,
		"neighbor_back_z": StreetLayout.recess_z() + (HouseTypes.depth_of(first_house) if first_house != "" else 0.0),
		"garden_extra_width": GameConfig.alley_garden_extra_width,
		"garden_depth": GameConfig.alley_garden_depth,
		"wall_height": GameConfig.alley_wall_height,
		"opposite_alley_x0": span.x,
		"opposite_alley_x1": span.y,
		"opposite_front_z": StreetLayout.opposite_front_z(),
		"opposite_end_z": StreetLayout.opposite_alley_end_z(),
		"opposite_back_depth": GameConfig.opposite_alley_back_depth,
		"garden_tree": [StreetLayout.garden_tree().x, StreetLayout.garden_tree().y],
		# großer Garten (seit Etappe 8d) und die Häuser ringsum (Rückseiten mit Fenstern im Modell)
		"backyard_right_x": StreetLayout.backyard_right_x(),
		"backyard_left_x": GameConfig.backyard_left_x,
		"backyard_back_wall_z": GameConfig.backyard_back_wall_z,
		"backyard_wall_height": GameConfig.backyard_wall_height,
		"backyard_stream": _points(GameConfig.backyard_stream),
		"backyard_stream_width": GameConfig.backyard_stream_width,
		"backyard_bridge": [GameConfig.backyard_bridge_center.x, GameConfig.backyard_bridge_center.y, GameConfig.backyard_bridge_turn,
			GameConfig.backyard_bridge_size.x, GameConfig.backyard_bridge_size.y, GameConfig.backyard_bridge_size.z],
		"backyard_cottage": [GameConfig.backyard_cottage_center.x, GameConfig.backyard_cottage_center.y,
			GameConfig.backyard_cottage_size.x, GameConfig.backyard_cottage_size.y, GameConfig.backyard_cottage_turn],
		"back_room": [BackRoom.back_area().position.x, BackRoom.back_area().position.y, BackRoom.back_area().size.x,
			BackRoom.back_area().size.y],
		"house_backs": _house_backs(),
	}
	var file := FileAccess.open("res://assets/models/source/layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Lage gespeichert: ", data)
	get_tree().quit()


## Rückseiten der Nachbarhäuser in der Bücherei-Reihe: [x0, x1, Rückseite z, Traufhöhe] (von der Bücherei nach außen).
func _house_backs() -> Array:
	var result := []
	var x := StreetLayout.HOUSE_RIGHT
	for id: String in GameConfig.neighbor_house_types:
		var w := HouseTypes.width_of(id)
		result.append([x, x + w, StreetLayout.HOUSE_FRONT + HouseTypes.depth_of(id), float(HouseTypes.value_of(id, "eaves_height", 6.6))])
		x += w
	x = StreetLayout.alley_far_x()
	for id: String in GameConfig.alley_house_types:
		var w := HouseTypes.width_of(id)
		result.append([x - w, x, StreetLayout.recess_z() + HouseTypes.depth_of(id), float(HouseTypes.value_of(id, "eaves_height", 6.6))])
		x -= w
	return result


func _points(points: PackedVector2Array) -> Array:
	var result := []
	for p in points:
		result.append([p.x, p.y])
	return result
