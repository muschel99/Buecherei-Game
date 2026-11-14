extends Node3D
## Buch in der Hand der Besucher (Requisite „book“, seit Etappe 8 in der weichen Buchform BookLook): ein zufälliger Titel aus
## dem Katalog (Farbe und Rücken), Einband nach ±Z wie früher die einfache Kiste (14 x 20 x 3,2 cm).

const SIZE := Vector3(0.032, 0.2, 0.14)  # Dicke, Höhe, Tiefe der Buchform


func _ready() -> void:
	var books := Catalog.get_all_books()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BookLook.get_mesh()
	if not books.is_empty():
		mesh.material_override = BookLook.create_single_material(books[randi() % books.size()])
	else:
		mesh.material_override = BookLook.get_material()
	# Einband (+X der Buchform) nach +Z
	mesh.transform = Transform3D(Basis(Vector3.UP, -PI / 2.0).scaled_local(SIZE), Vector3.ZERO)
	add_child(mesh)
