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
	}
	var file := FileAccess.open("res://assets/models/source/layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Lage gespeichert: ", data)
	get_tree().quit()
